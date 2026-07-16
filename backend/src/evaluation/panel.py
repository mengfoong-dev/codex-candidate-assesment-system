"""Layer 2 rubric analysis with Cohere Command A+ as the sole primary grader.

Groq and NVIDIA NIM remain implemented as an explicitly enabled, panel-level fallback. This
preserves their prior provenance and median/single consensus semantics without letting their
presence turn them into concurrent live graders.
"""
import asyncio
import inspect
import json
from dataclasses import dataclass

from src.config import get_settings
from src.registry import NARRATIVE_DIMENSION, RUBRIC_DIMENSIONS, RUBRIC_VERSION

_RETRY_ATTEMPTS = 2
_COHERE_BASE_URL = "https://api.cohere.com"


@dataclass(frozen=True)
class GraderConfig:
    vendor: str
    api_key: str | None
    base_url: str
    model: str


def _primary_grader_config() -> GraderConfig:
    settings = get_settings()
    return GraderConfig("cohere", settings.cohere_api_key, _COHERE_BASE_URL, settings.cohere_model)


def _fallback_grader_configs() -> list[GraderConfig]:
    """Fallback vendors are deliberately unavailable until the operator enables the flag."""
    settings = get_settings()
    if not settings.ai_panel_fallback_enabled:
        return []
    return [
        GraderConfig("groq", settings.groq_api_key, settings.groq_base_url, settings.groq_grader_model),
        GraderConfig("nim", settings.nim_api_key, settings.nim_base_url, settings.nim_grader_model),
    ]


def _grader_configs() -> list[GraderConfig]:
    """Compatibility helper for diagnostics; the rubric flow does not fan out by default."""
    return [_primary_grader_config(), *_fallback_grader_configs()]


def _build_digest(events: list[dict], submission: dict) -> str:
    """A compact evidence digest, never the entire raw event log."""
    lines: list[str] = []
    for event in events:
        event_type, payload = event["event_type"], event["payload"]
        if event_type == "ai_prompt_submitted":
            lines.append(f'[{event["event_id"]}] prompt: {payload.get("prompt", "")!r}')
        elif event_type == "evidence_viewed":
            lines.append(f'[{event["event_id"]}] evidence_viewed: {payload.get("artifact_id")}')
        elif event_type == "hypothesis_recorded":
            lines.append(
                f'[{event["event_id"]}] hypothesis_recorded: {payload.get("hypothesis_id")} '
                f'(confidence {payload.get("confidence")})'
            )
        elif event_type == "hypothesis_revised":
            lines.append(
                f'[{event["event_id"]}] hypothesis_revised: {payload.get("hypothesis_id")} '
                f'triggered_by={payload.get("trigger_evidence_ids")}'
            )
        elif event_type == "ai_suggestion_dispositioned":
            lines.append(f'[{event["event_id"]}] disposition: {payload.get("option_id")}')
        elif event_type == "decision_recorded":
            lines.append(f'[{event["event_id"]}] decision: {payload.get("action")} - {payload.get("rationale")}')
        elif event_type == "test_executed":
            lines.append(f'[{event["event_id"]}] test_executed: {payload.get("test_id")} -> {payload.get("status")}')
    lines.append(
        f'[submission] root_cause={submission.get("root_cause_id")} remediation={submission.get("remediation_id")} '
        f'confidence={submission.get("final_confidence")} rationale={submission.get("rationale", "")!r}'
    )
    return "\n".join(lines)


def _dimension_prompt(dimension: dict, digest: str) -> str:
    anchors = dimension["anchors"]
    return (
        f"You are grading a candidate's engineering-incident investigation on ONE dimension: "
        f"'{dimension['dimension']}'. Use only the recorded evidence digest below - never invent "
        f"events. Score 1-5 using these anchors: 1 = {anchors[1]}; 3 = {anchors[3]}; 5 = {anchors[5]}.\n\n"
        f"Evidence digest:\n{digest}\n\n"
        'Return only one JSON object with exactly these keys: "score" (integer 1-5), '
        '"justification" (string), and "cited_event_ids" (array of strings). Only cite event IDs '
        "that appear in the digest above."
    )


_SCORE_SCHEMA = {
    "type": "object",
    "properties": {
        # Cohere's JSON Schema subset does not support numeric minimum/maximum. The range is
        # enforced by _grade_once after parsing instead.
        "score": {"type": "integer"},
        "justification": {"type": "string"},
        "cited_event_ids": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["score", "justification", "cited_event_ids"],
}
_NARRATIVE_SCHEMA = {
    "type": "object",
    "properties": {"text": {"type": "string"}},
    "required": ["text"],
}
_QUESTIONS_SCHEMA = {
    "type": "object",
    "properties": {"questions": {"type": "array", "items": {"type": "string"}}},
    "required": ["questions"],
}


def _first_text_content(content_blocks: object) -> str:
    """Extract the visible text block while safely ignoring any Cohere thinking blocks."""
    for block in content_blocks or []:
        text = block.get("text") if isinstance(block, dict) else getattr(block, "text", None)
        if isinstance(text, str) and text:
            return text
    return ""


async def _cohere_json_once(
    vendor_cfg: GraderConfig, prompt: str, schema: dict, *, temperature: float
) -> dict | None:
    """One structured Cohere V2 request. Kept separate so tests can replace the network edge."""
    if not vendor_cfg.api_key:
        return None
    try:
        import cohere

        client = cohere.AsyncClientV2(api_key=vendor_cfg.api_key)
        response = client.chat(
            model=vendor_cfg.model,
            messages=[{"role": "user", "content": prompt}],
            # Command A+ currently rejects JSON Schema mode at this endpoint. JSON object mode
            # still guarantees valid JSON; _grade_once and the narrative/question parsers retain
            # the application-side shape and value validation.
            response_format={"type": "json_object"},
            thinking={"type": "disabled"},
            temperature=temperature,
        )
        if inspect.isawaitable(response):
            response = await response
        content = _first_text_content(response.message.content)
        return json.loads(content)
    except Exception:
        return None


async def _openai_json_once(
    vendor_cfg: GraderConfig, prompt: str, *, temperature: float
) -> dict | None:
    """Existing Groq/NIM implementation retained only for an operator-enabled fallback."""
    if not vendor_cfg.api_key:
        return None
    try:
        from openai import AsyncOpenAI

        client = AsyncOpenAI(api_key=vendor_cfg.api_key, base_url=vendor_cfg.base_url)
        response = await client.chat.completions.create(
            model=vendor_cfg.model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=temperature,
        )
        return json.loads(response.choices[0].message.content)
    except Exception:
        return None


async def _json_once(vendor_cfg: GraderConfig, prompt: str, schema: dict, *, temperature: float) -> dict | None:
    if vendor_cfg.vendor == "cohere":
        return await _cohere_json_once(vendor_cfg, prompt, schema, temperature=temperature)
    return await _openai_json_once(vendor_cfg, prompt, temperature=temperature)


async def _grade_once(vendor_cfg: GraderConfig, dimension: dict, digest: str) -> dict | None:
    prompt = _dimension_prompt(dimension, digest)
    for _ in range(_RETRY_ATTEMPTS):
        data = await _json_once(vendor_cfg, prompt, _SCORE_SCHEMA, temperature=0.2)
        if data is None:
            continue
        try:
            score = int(data["score"])
            if not 1 <= score <= 5:
                raise ValueError("score out of range")
            return {
                "score": score,
                "justification": str(data.get("justification", "")),
                "cited_event_ids": [str(value) for value in data.get("cited_event_ids", [])],
            }
        except (KeyError, TypeError, ValueError):
            continue
    return None


async def _grade_narrative_once(vendor_cfg: GraderConfig, digest: str) -> str | None:
    prompt = (
        "Write a 3-5 sentence description of this candidate's investigation style (breadth-first vs "
        "depth-first, evidence-led vs AI-led). This is descriptive only - never a score, ranking, or "
        f"right/wrong judgment.\n\nEvidence digest:\n{digest}\n\n"
        'Return only one JSON object with exactly one key: "text".'
    )
    data = await _json_once(vendor_cfg, prompt, _NARRATIVE_SCHEMA, temperature=0.3)
    text = str(data.get("text", "")).strip() if data else ""
    return text or None


async def _grade_questions_once(
    vendor_cfg: GraderConfig, digest: str, missed_labels: list[str], flagged_dimensions: list[str]
) -> list[str] | None:
    prompt = (
        "Suggest 3-5 targeted human-interview follow-up questions for this candidate, drawn from the "
        "criteria they missed and any flagged rubric dimensions below. Ask about reasoning - never phrase "
        "these as a verdict or recommendation.\n"
        f"Missed criteria: {missed_labels}\nFlagged dimensions: {flagged_dimensions}\n\n"
        f"Evidence digest:\n{digest}\n\n"
        'Return only one JSON object with exactly one key: "questions", an array of strings.'
    )
    data = await _json_once(vendor_cfg, prompt, _QUESTIONS_SCHEMA, temperature=0.3)
    questions = [str(question) for question in data.get("questions", [])] if data else []
    return questions[:5] or None


def _consensus(scores: list[dict]) -> dict:
    values = [score["score"] for score in scores]
    if len(values) >= 2:
        first, second = values[0], values[1]
        return {"score": (first + second) / 2, "consensus": "median", "flagged": abs(first - second) >= 2}
    return {"score": float(values[0]), "consensus": "single", "flagged": False}


def _pick_vendor(configs: list[GraderConfig]) -> GraderConfig | None:
    return next((config for config in configs if config.api_key), None)


def _rows_from_results(
    calls: list[tuple[dict, GraderConfig]], results: list[dict | None]
) -> tuple[list[dict], list[str]]:
    by_dimension: dict[str, list[tuple[GraderConfig, dict]]] = {}
    for (dimension, config), result in zip(calls, results):
        if result is not None:
            by_dimension.setdefault(dimension["dimension"], []).append((config, result))

    rows: list[dict] = []
    flagged_dimensions: list[str] = []
    for dimension in RUBRIC_DIMENSIONS:
        available = by_dimension.get(dimension["dimension"])
        if not available:
            continue
        consensus = _consensus([result for _, result in available])
        if consensus["flagged"]:
            flagged_dimensions.append(dimension["dimension"])
        rows.append(
            {
                "dimension": dimension["dimension"],
                "score": consensus["score"],
                "consensus": consensus["consensus"],
                "flagged": consensus["flagged"],
                "justification": " | ".join(
                    f'{config.vendor}: {result["justification"]}' for config, result in available
                ),
                "cited_event_ids": sorted(
                    {event_id for _, result in available for event_id in result.get("cited_event_ids", [])}
                ),
                "graders": [
                    {"vendor": config.vendor, "model": config.model, "score": result["score"]}
                    for config, result in available
                ],
                "rubric_version": RUBRIC_VERSION,
            }
        )
    return rows, flagged_dimensions


async def rubric_panel(events: list[dict], submission: dict, scenario, layer1=None) -> list[dict]:
    digest = _build_digest(events, submission)
    primary = _primary_grader_config()
    primary_calls = [(dimension, primary) for dimension in RUBRIC_DIMENSIONS]
    primary_results = await asyncio.gather(*(_grade_once(config, dimension, digest) for dimension, config in primary_calls))

    calls, results = primary_calls, primary_results
    narrative_vendor: GraderConfig | None = primary if any(result is not None for result in primary_results) else None
    if narrative_vendor is None:
        fallback_configs = _fallback_grader_configs()
        calls = [(dimension, config) for dimension in RUBRIC_DIMENSIONS for config in fallback_configs]
        results = await asyncio.gather(*(_grade_once(config, dimension, digest) for dimension, config in calls))
        narrative_vendor = _pick_vendor(fallback_configs) if any(result is not None for result in results) else None

    rows, flagged_dimensions = _rows_from_results(calls, results)
    if narrative_vendor is not None:
        narrative = await _grade_narrative_once(narrative_vendor, digest)
        if narrative is not None:
            rows.append(
                {
                    "dimension": NARRATIVE_DIMENSION,
                    "text": narrative,
                    "scored": False,
                    "rubric_version": RUBRIC_VERSION,
                }
            )

    missed_labels = []
    if layer1 is not None:
        missed_labels = [
            criterion.criterion_id
            for criterion in layer1.criteria
            if criterion.kind == "positive" and criterion.status == "missed"
        ]
    questions = (
        await _grade_questions_once(narrative_vendor, digest, missed_labels, flagged_dimensions)
        if narrative_vendor is not None
        else None
    )
    rows.append({"dimension": "interview_questions", "questions": questions or [], "scored": False})
    return rows
