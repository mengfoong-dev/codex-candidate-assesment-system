"""Report email renderer: the D007/D009 layer boundaries must be visible in the HTML. Pure, no network."""
from src.notifications.render import render_report_email

_SAMPLE_REPORT = {
    "session": {"display_name": "Ada", "session_id": "s1"},
    "scores": {
        "deterministic": {
            "total": 60.0, "max": 70.0,  # Float columns -> _fmt must render "60/70"
            "criteria": [{"criterion_id": "evidence_coverage", "label": "Evidence coverage",
                          "points": 10, "status": "met", "evidence_refs": ["s1:1"]}],
        },
        "ai_analysis": {
            "label": "AI analysis — model opinion, human review required",
            "dimensions": [{"dimension": "problem_framing", "score": 4, "scale": 5, "flagged": False,
                            "justification": "Framed symptom vs constraint before investigating.",
                            "cited_event_ids": [], "graders": ["g"]}],
            "narrative": {"text": "Depth-first.", "scored": False},
        },
        "context_indices": {
            "scored": False, "ai_used": True,
            "indices": [
                {"index_id": "e_p", "value": 42.5, "available": True,
                 "formula": "Q / (1 + 0.05*P_total*(1+R_fail))",
                 "inputs": {"Q": 60, "P_total": 5, "R_fail": 0.0}},
                {"index_id": "epi", "value": None, "formula": "(Q/100) / (T/1000)",
                 "inputs": {"Q": 60, "T": 0}, "available": False},
            ],
        },
    },
    "interview_questions": ["Why rule out CPU?"],
    "hypotheses": [{"version": 1, "hypothesis_id": "sequential_independent_calls",
                    "confidence": 80, "trigger_evidence_ids": ["homepage_trace"]}],
}


def test_render_makes_layer_boundaries_visible():
    subject, html, _text = render_report_email(_SAMPLE_REPORT)
    low = html.lower()
    assert "60/70" in subject
    assert "ai analysis — model opinion, human review required" in low  # Layer 2 label verbatim
    assert "never scored" in low        # Layer 3 disclaimer
    assert "n/a" in low                 # unavailable index degrades to n/a
    assert "prompt efficiency" in low   # glossary appendix present
    for phrase in ("should be hired", "should not be hired", "do not hire", "recommend hir"):
        assert phrase not in low        # no employment verdict


def test_render_shows_layer3_formula_and_inputs():
    _subject, html, _text = render_report_email(_SAMPLE_REPORT)
    assert "Q / (1 + 0.05*P_total*(1+R_fail))" in html  # formula rendered verbatim
    assert "Q=60" in html and "P_total=5" in html        # scalar inputs rendered


def test_render_uses_app_navy_palette():
    _subject, html, _text = render_report_email(_SAMPLE_REPORT)
    assert "#1c2b4d" in html  # navy matching the Godot app


def test_render_no_ai_used_path():
    report = {**_SAMPLE_REPORT}
    report["scores"] = {**report["scores"],
                        "context_indices": {"scored": False, "ai_used": False, "indices": []}}
    _subject, html, _text = render_report_email(report)
    assert "no ai assistance used" in html.lower()
