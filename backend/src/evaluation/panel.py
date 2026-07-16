"""Layer 2 — RubricPanel: labeled AI analysis, never mixed into Layer 1 points. `rubric_panel(events,
submission, scenario, layer1=None) -> list[dict]`.

7 scored dimensions (RUBRIC_DIMENSIONS) x 2 vendors (Groq + NVIDIA NIM) = 14 parallel calls via
asyncio.gather, plus 1 thinking_style narrative (never scored) + 1 interview_questions call (silent
on failure). One `Grader`-shaped config per vendor, both driven through the `openai` async SDK with
only base_url/api_key/model swapped — no LiteLLM (both vendors are OpenAI-compatible).

Testability seam: every vendor call is a small, separately monkeypatchable module-level function
(`_grade_once`, `_grade_narrative_once`, `_grade_questions_once`). Tests replace these with fakes —
`rubric_panel` never constructs a network client itself outside of them, so patching the module
attribute is enough to run the whole panel with zero network access.

`layer1` (optional) is accepted beyond brief 01's `rubric_panel(events, submission, scenario)`
sketch because the interview-question call needs missed criteria (brief 01: "3-5 targeted
follow-up questions from missed criteria and flagged dimensions") and only the Layer 1 result
carries that — the orchestrator (service.py) has it in scope and passes it through.
"""
import asyncio
import json
from dataclasses import dataclass

from src.config import get_settings
from src.registry import NARRATIVE_DIMENSION, RUBRIC_DIMENSIONS, RUBRIC_VERSION

_RETRY_ATTEMPTS = 2  # one try + one retry, per brief 01


@dataclass(frozen=True)
class GraderConfig:
    vendor: str
    api_key: str | None
    base_url: str
    model: str


def _grader_configs() -> list[GraderConfig]:
    s = get_settings()
    return [
        GraderConfig("groq", s.groq_api_key, s.groq_base_url, s.groq_grader_model),
        GraderConfig("nim", s.nim_api_key, s.nim_base_url, s.nim_grader_model),
    ]


def _build_digest(events: list[dict], submission: dict) -> str:
    """A compact evidence digest — prompts, hypotheses, dispositions, submission rationale — never
    the full raw log (brief 01)."""
    lines: list[str] = []
    for e in events:
        etype, payload = e["event_type"], e["payload"]
        if etype == "ai_prompt_submitted":
            lines.append(f'[{e["event_id"]}] prompt: {payload.get("prompt", "")!r}')
        elif etype == "evidence_viewed":
            lines.append(f'[{e["event_id"]}] evidence_viewed: {payload.get("artifact_id")}')
        elif etype == "hypothesis_recorded":
            lines.append(f'[{e["event_id"]}] hypothesis_recorded: {payload.get("hypothesis_id")} (confidence {payload.get("confidence")})')
        elif etype == "hypothesis_revised":
            lines.append(f'[{e["event_id"]}] hypothesis_revised: {payload.get("hypothesis_id")} triggered_by={payload.get("trigger_evidence_ids")}')
        elif etype == "ai_suggestion_dispositioned":
            lines.append(f'[{e["event_id"]}] disposition: {payload.get("option_id")}')
        elif etype == "decision_recorded":
            lines.append(f'[{e["event_id"]}] decision: {payload.get("action")} — {payload.get("rationale")}')
        elif etype == "test_executed":
            lines.append(f'[{e["event_id"]}] test_executed: {payload.get("test_id")} -> {payload.get("status")}')
    lines.append(
        f'[submission] root_cause={submission.get("root_cause_id")} remediation={submission.get("remediation_id")} '
        f'confidence={submission.get("final_confidence")} rationale={submission.get("rationale", "")!r}'
    )
    return "\n".join(lines)


def _dimension_prompt(dimension: dict, digest: str) -> str:
    anchors = dimension["anchors"]
    return (
        f"You are grading a candidate's engineering-incident investigation on ONE dimension: "
        f"'{dimension['dimension']}'. Use only the recorded evidence digest below — never invent "
        f"events. Score 1-5 using these anchors: 1 = {anchors[1]}; 3 = {anchors[3]}; 5 = {anchors[5]}.\n\n"
        f"Evidence digest:\n{digest}\n\n"
        'Respond with strict JSON only: {"score": <int 1-5>, "justification": "<1-2 sentences>", '
        '"cited_event_ids": ["<event_id>", ...]}. Only cite event IDs that appear in the digest above.'
    )


async def _grade_once(vendor_cfg: GraderConfig, dimension: dict, digest: str) -> dict | None:
    """One (vendor, dimension) grading call. Returns {"score","justification","cited_event_ids"} or
    None if the vendor is unconfigured or the call/parse fails after one retry. This is the seam
    tests monkeypatch to avoid any network access."""
    if not vendor_cfg.api_key:
        return None
    from openai import AsyncOpenAI  # imported lazily so tests never need the package configured

    client = AsyncOpenAI(api_key=vendor_cfg.api_key, base_url=vendor_cfg.base_url)
    prompt = _dimension_prompt(dimension, digest)
    for _ in range(_RETRY_ATTEMPTS):
        try:
            resp = await client.chat.completions.create(
                model=vendor_cfg.model,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=0.2,
            )
            data = json.loads(resp.choices[0].message.content)
            score = int(data["score"])
            if not (1 <= score <= 5):
                raise ValueError(f"score out of range: {score}")
            return {
                "score": score,
                "justification": str(data.get("justification", "")),
                "cited_event_ids": list(data.get("cited_event_ids", [])),
            }
        except Exception:
            continue
    return None


async def _grade_narrative_once(vendor_cfg: GraderConfig, digest: str) -> str | None:
    """Single-call thinking_style narrative — never scored, no right/wrong answer."""
    if not vendor_cfg.api_key:
        return None
    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=vendor_cfg.api_key, base_url=vendor_cfg.base_url)
    prompt = (
        "Write a 3-5 sentence description of this candidate's investigation style (breadth-first vs "
        "depth-first, evidence-led vs AI-led). This is a descriptive profile only — never a score, "
        "ranking, or right/wrong judgment.\n\n"
        f"Evidence digest:\n{digest}\n\nRespond with strict JSON only: {{\"text\": \"<narrative>\"}}."
    )
    try:
        resp = await client.chat.completions.create(
            model=vendor_cfg.model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.3,
        )
        data = json.loads(resp.choices[0].message.content)
        text = str(data.get("text", "")).strip()
        return text or None
    except Exception:
        return None


async def _grade_questions_once(
    vendor_cfg: GraderConfig, digest: str, missed_labels: list[str], flagged_dimensions: list[str]
) -> list[str] | None:
    """D007-sanctioned interview-question suggestions. Silent on failure (brief 01: nice-to-have)."""
    if not vendor_cfg.api_key:
        return None
    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=vendor_cfg.api_key, base_url=vendor_cfg.base_url)
    prompt = (
        "Suggest 3-5 targeted human-interview follow-up questions for this candidate, drawn from the "
        "criteria they missed and any flagged rubric dimensions below. Ask about their reasoning — "
        "never phrase these as a verdict or recommendation.\n"
        f"Missed criteria: {missed_labels}\nFlagged dimensions: {flagged_dimensions}\n\n"
        f"Evidence digest:\n{digest}\n\n"
        'Respond with strict JSON only: {"questions": ["...", ...]}.'
    )
    try:
        resp = await client.chat.completions.create(
            model=vendor_cfg.model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.3,
        )
        data = json.loads(resp.choices[0].message.content)
        questions = [str(q) for q in data.get("questions", [])]
        return questions[:5] or None
    except Exception:
        return None


def _consensus(scores: list[dict]) -> dict:
    """Median of available scores; with exactly 2 vendors that IS their mean. |a-b| >= 2 -> flagged.
    One vendor down -> consensus:"single". (Both down means the dimension isn't called here at all —
    the caller omits it before reaching consensus.)"""
    values = [s["score"] for s in scores]
    if len(values) >= 2:
        a, b = values[0], values[1]
        return {"score": (a + b) / 2, "consensus": "median", "flagged": abs(a - b) >= 2}
    return {"score": float(values[0]), "consensus": "single", "flagged": False}


def _pick_vendor(configs: list[GraderConfig]) -> GraderConfig | None:
    """First configured vendor — Groq listed first as the cheaper default for the single-call
    narrative/interview-question asks (brief 01: "single call, cheaper vendor")."""
    return next((c for c in configs if c.api_key), None)


async def rubric_panel(events: list[dict], submission: dict, scenario, layer1=None) -> list[dict]:
    configs = _grader_configs()
    digest = _build_digest(events, submission)

    calls = [(dim, cfg) for dim in RUBRIC_DIMENSIONS for cfg in configs]
    results = await asyncio.gather(*(_grade_once(cfg, dim, digest) for dim, cfg in calls))

    by_dimension: dict[str, list[tuple[GraderConfig, dict]]] = {}
    for (dim, cfg), result in zip(calls, results):
        if result is not None:
            by_dimension.setdefault(dim["dimension"], []).append((cfg, result))

    rows: list[dict] = []
    flagged_dimensions: list[str] = []
    for dim in RUBRIC_DIMENSIONS:
        available = by_dimension.get(dim["dimension"])
        if not available:
            continue  # both vendors down (or unconfigured) -> omit; report notes the fallback
        graders = [{"vendor": cfg.vendor, "model": cfg.model, "score": r["score"]} for cfg, r in available]
        cited = sorted({eid for _, r in available for eid in r.get("cited_event_ids", [])})
        justification = " | ".join(f'{cfg.vendor}: {r["justification"]}' for cfg, r in available)
        consensus = _consensus([r for _, r in available])
        if consensus["flagged"]:
            flagged_dimensions.append(dim["dimension"])
        rows.append({
            "dimension": dim["dimension"],
            "score": consensus["score"],
            "consensus": consensus["consensus"],
            "flagged": consensus["flagged"],
            "justification": justification,
            "cited_event_ids": cited,
            "graders": graders,
            "rubric_version": RUBRIC_VERSION,
        })

    narrative_vendor = _pick_vendor(configs)
    narrative_text = await _grade_narrative_once(narrative_vendor, digest) if narrative_vendor else None
    if narrative_text is not None:
        rows.append({
            "dimension": NARRATIVE_DIMENSION,
            "text": narrative_text,
            "scored": False,
            "rubric_version": RUBRIC_VERSION,
        })

    missed_labels = []
    if layer1 is not None:
        missed_labels = [c.criterion_id for c in layer1.criteria if c.kind == "positive" and c.status == "missed"]
    questions_vendor = _pick_vendor(configs)
    questions = (
        await _grade_questions_once(questions_vendor, digest, missed_labels, flagged_dimensions)
        if questions_vendor
        else None
    )
    rows.append({"dimension": "interview_questions", "questions": questions or [], "scored": False})

    return rows
