"""Layer 2 (RubricPanel) tests. Every vendor call goes through the monkeypatchable seams
(`_grade_once`, `_grade_narrative_once`, `_grade_questions_once`) — no network access anywhere in
this file. `_grader_configs` is also patched to return fake, always-configured vendors so
`_pick_vendor` (used for the narrative/interview-question single calls) never falls back to "no
vendor configured" just because GROQ_API_KEY/NIM_API_KEY aren't set in the test environment.
"""
import pytest

from src.evaluation import panel as panel_module
from src.evaluation.rules import CriterionResult, Layer1Result
from src.registry import RUBRIC_DIMENSIONS

FAKE_CONFIGS = [
    panel_module.GraderConfig("groq", "fake-groq-key", "http://fake-groq", "fake-groq-model"),
    panel_module.GraderConfig("nim", "fake-nim-key", "http://fake-nim", "fake-nim-model"),
]


@pytest.fixture(autouse=True)
def _fake_vendor_configs(monkeypatch):
    monkeypatch.setattr(panel_module, "_grader_configs", lambda: FAKE_CONFIGS)


async def _no_narrative(vendor_cfg, digest):
    return None


async def _no_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
    return None


def _scored_rows(rows):
    return [r for r in rows if r["dimension"] not in ("thinking_style", "interview_questions")]


async def test_median_consensus_when_both_vendors_available(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        score = 4 if vendor_cfg.vendor == "groq" else 5
        return {"score": score, "justification": f"{vendor_cfg.vendor} says so", "cited_event_ids": [f"{vendor_cfg.vendor}-cite"]}

    async def fake_narrative(vendor_cfg, digest):
        return "Breadth-first, evidence-led investigation."

    async def fake_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
        return ["Why did you choose this remediation over the alternatives?"]

    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", fake_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", fake_questions)

    rows = await panel_module.rubric_panel([], {"root_cause_id": "x", "remediation_id": "y"}, scenario=None)

    scored = _scored_rows(rows)
    assert len(scored) == len(RUBRIC_DIMENSIONS)
    for r in scored:
        assert r["consensus"] == "median"
        assert r["score"] == pytest.approx(4.5)  # 2 vendors -> median == mean
        assert r["flagged"] is False  # |4-5| == 1 < 2
        assert len(r["graders"]) == 2
        assert set(r["cited_event_ids"]) == {"groq-cite", "nim-cite"}

    narrative = next(r for r in rows if r["dimension"] == "thinking_style")
    assert narrative["text"] == "Breadth-first, evidence-led investigation."
    assert narrative["scored"] is False

    questions = next(r for r in rows if r["dimension"] == "interview_questions")
    assert questions["questions"] == ["Why did you choose this remediation over the alternatives?"]


async def test_single_vendor_consensus_when_one_vendor_down(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        if vendor_cfg.vendor == "nim":
            return None  # NIM down for every dimension
        return {"score": 3, "justification": "groq only", "cited_event_ids": ["e1"]}

    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", _no_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", _no_questions)

    rows = await panel_module.rubric_panel([], {}, scenario=None)

    scored = _scored_rows(rows)
    assert len(scored) == len(RUBRIC_DIMENSIONS)
    for r in scored:
        assert r["consensus"] == "single"
        assert r["score"] == 3.0
        assert r["flagged"] is False
        assert len(r["graders"]) == 1
        assert r["graders"][0]["vendor"] == "groq"


async def test_both_vendors_down_omits_all_dimensions(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        return None

    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", _no_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", _no_questions)

    rows = await panel_module.rubric_panel([], {}, scenario=None)

    assert _scored_rows(rows) == []
    assert not any(r["dimension"] == "thinking_style" for r in rows)
    questions_row = next(r for r in rows if r["dimension"] == "interview_questions")
    assert questions_row["questions"] == []  # silent failure, not an exception


async def test_flagged_when_scores_diverge_by_two_or_more(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        score = 2 if vendor_cfg.vendor == "groq" else 5
        return {"score": score, "justification": "x", "cited_event_ids": []}

    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", _no_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", _no_questions)

    rows = await panel_module.rubric_panel([], {}, scenario=None)

    scored = _scored_rows(rows)
    assert all(r["flagged"] for r in scored)
    assert all(r["consensus"] == "median" for r in scored)
    assert all(r["score"] == pytest.approx(3.5) for r in scored)


async def test_interview_questions_receive_missed_criteria_and_flagged_dimensions(monkeypatch):
    captured = {}

    async def fake_grade_once(vendor_cfg, dimension, digest):
        score = 2 if vendor_cfg.vendor == "groq" else 5  # forces every dimension to flag
        return {"score": score, "justification": "x", "cited_event_ids": []}

    async def fake_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
        captured["missed"] = missed_labels
        captured["flagged"] = flagged_dimensions
        return ["q"]

    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", _no_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", fake_questions)

    layer1 = Layer1Result(
        criteria=[
            CriterionResult("trace_before_change", "investigation_strategy", "positive", 0, 10, "missed", []),
            CriterionResult("healthy_signals_used", "evidence_use", "positive", 10, 10, "met", ["e1"]),
        ],
        positive_points_available=20,
        total=10,
        normalized_q=50.0,
    )

    await panel_module.rubric_panel([], {}, scenario=None, layer1=layer1)

    assert captured["missed"] == ["trace_before_change"]
    assert len(captured["flagged"]) == len(RUBRIC_DIMENSIONS)
