"""Cohere-primary rubric-panel behavior, using no-network provider doubles."""
import sys
from types import SimpleNamespace
import pytest

from src.evaluation import panel as panel_module
from src.evaluation.rules import CriterionResult, Layer1Result
from src.registry import RUBRIC_DIMENSIONS

COHERE = panel_module.GraderConfig(
    "cohere", "fake-cohere-key", "https://api.cohere.com", "command-a-plus-05-2026"
)
FALLBACKS = [
    panel_module.GraderConfig("groq", "fake-groq-key", "http://fake-groq", "fake-groq-model"),
    panel_module.GraderConfig("nim", "fake-nim-key", "http://fake-nim", "fake-nim-model"),
]


def _scored_rows(rows):
    return [row for row in rows if row["dimension"] not in ("thinking_style", "interview_questions")]


async def _no_narrative(vendor_cfg, digest):
    return None


async def _no_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
    return None


@pytest.mark.asyncio
async def test_cohere_structured_request_uses_the_score_schema(monkeypatch):
    """The real Cohere boundary sends V2 JSON mode and returns parsed rubric data."""
    captured = {}

    class FakeClient:
        def __init__(self, *, api_key):
            captured["api_key"] = api_key

        def chat(self, **kwargs):
            captured.update(kwargs)
            return SimpleNamespace(
                message=SimpleNamespace(
                    content=[
                        SimpleNamespace(text=None, thinking="internal reasoning"),
                        SimpleNamespace(text='{"score":4,"justification":"Evidence-led","cited_event_ids":["e1"]}'),
                    ]
                )
            )

    monkeypatch.setitem(sys.modules, "cohere", SimpleNamespace(AsyncClientV2=FakeClient))
    result = await panel_module._cohere_json_once(
        COHERE, "Generate a JSON object with score.", panel_module._SCORE_SCHEMA, temperature=0.2
    )

    assert result == {"score": 4, "justification": "Evidence-led", "cited_event_ids": ["e1"]}
    assert captured["api_key"] == "fake-cohere-key"
    assert captured["model"] == "command-a-plus-05-2026"
    assert captured["response_format"] == {"type": "json_object"}
    assert "thinking" not in captured


def test_cohere_score_schema_avoids_unsupported_numeric_ranges():
    assert "minimum" not in panel_module._SCORE_SCHEMA["properties"]["score"]
    assert "maximum" not in panel_module._SCORE_SCHEMA["properties"]["score"]


@pytest.mark.asyncio
async def test_cohere_primary_records_single_consensus_and_provenance(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        assert vendor_cfg.vendor == "cohere"
        return {"score": 4, "justification": "Cohere says so", "cited_event_ids": ["cohere-cite"]}

    async def fake_narrative(vendor_cfg, digest):
        return "Breadth-first, evidence-led investigation."

    async def fake_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
        return ["Why did you choose this remediation over the alternatives?"]

    monkeypatch.setattr(panel_module, "_primary_grader_config", lambda: COHERE)
    monkeypatch.setattr(panel_module, "_fallback_grader_configs", lambda: [])
    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", fake_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", fake_questions)

    rows = await panel_module.rubric_panel([], {"root_cause_id": "x", "remediation_id": "y"}, scenario=None)

    scored = _scored_rows(rows)
    assert len(scored) == len(RUBRIC_DIMENSIONS)
    for row in scored:
        assert row["consensus"] == "single"
        assert row["score"] == 4.0
        assert row["flagged"] is False
        assert row["graders"] == [
            {"vendor": "cohere", "model": "command-a-plus-05-2026", "score": 4}
        ]
        assert row["cited_event_ids"] == ["cohere-cite"]

    narrative = next(row for row in rows if row["dimension"] == "thinking_style")
    assert narrative["text"] == "Breadth-first, evidence-led investigation."
    assert narrative["scored"] is False
    questions = next(row for row in rows if row["dimension"] == "interview_questions")
    assert questions["questions"] == ["Why did you choose this remediation over the alternatives?"]


@pytest.mark.asyncio
async def test_disabled_fallback_does_not_call_groq_or_nim_when_cohere_is_unavailable(monkeypatch):
    calls = []

    async def fake_grade_once(vendor_cfg, dimension, digest):
        calls.append(vendor_cfg.vendor)
        return None

    monkeypatch.setattr(panel_module, "_primary_grader_config", lambda: COHERE)
    monkeypatch.setattr(panel_module, "_fallback_grader_configs", lambda: [])
    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", _no_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", _no_questions)

    rows = await panel_module.rubric_panel([], {}, scenario=None)

    assert _scored_rows(rows) == []
    assert calls == ["cohere"] * len(RUBRIC_DIMENSIONS)
    assert next(row for row in rows if row["dimension"] == "interview_questions")["questions"] == []


@pytest.mark.asyncio
async def test_enabled_fallback_retains_median_semantics_and_vendor_provenance(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        if vendor_cfg.vendor == "cohere":
            return None
        score = 3 if vendor_cfg.vendor == "groq" else 5
        return {"score": score, "justification": vendor_cfg.vendor, "cited_event_ids": [vendor_cfg.vendor]}

    monkeypatch.setattr(panel_module, "_primary_grader_config", lambda: COHERE)
    monkeypatch.setattr(panel_module, "_fallback_grader_configs", lambda: FALLBACKS)
    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", _no_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", _no_questions)

    rows = await panel_module.rubric_panel([], {}, scenario=None)

    scored = _scored_rows(rows)
    assert len(scored) == len(RUBRIC_DIMENSIONS)
    for row in scored:
        assert row["consensus"] == "median"
        assert row["score"] == pytest.approx(4.0)
        assert row["flagged"] is True
        assert [grader["vendor"] for grader in row["graders"]] == ["groq", "nim"]


@pytest.mark.asyncio
async def test_interview_questions_keep_missed_criteria_and_human_review_context(monkeypatch):
    captured = {}

    async def fake_grade_once(vendor_cfg, dimension, digest):
        if vendor_cfg.vendor == "cohere":
            return None
        score = 2 if vendor_cfg.vendor == "groq" else 5
        return {"score": score, "justification": "x", "cited_event_ids": []}

    async def fake_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
        captured["vendor"] = vendor_cfg.vendor
        captured["missed"] = missed_labels
        captured["flagged"] = flagged_dimensions
        return ["q"]

    monkeypatch.setattr(panel_module, "_primary_grader_config", lambda: COHERE)
    monkeypatch.setattr(panel_module, "_fallback_grader_configs", lambda: FALLBACKS)
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

    assert captured["vendor"] == "groq"
    assert captured["missed"] == ["trace_before_change"]
    assert len(captured["flagged"]) == len(RUBRIC_DIMENSIONS)
