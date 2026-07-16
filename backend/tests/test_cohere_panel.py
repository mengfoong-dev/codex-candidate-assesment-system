"""Cohere-primary configuration contract for the LLM grading panel."""
from types import SimpleNamespace

from src.evaluation import panel


def test_cohere_is_the_command_a_plus_primary_grader(monkeypatch):
    primary = getattr(panel, "_primary_grader_config", None)
    assert primary is not None, "The grading panel needs a Cohere primary configuration"
    monkeypatch.setattr(
        panel,
        "get_settings",
        lambda: SimpleNamespace(
            cohere_api_key="cohere-key",
            cohere_model="command-a-plus-05-2026",
            ai_panel_fallback_enabled=False,
            groq_api_key="groq-key",
            groq_base_url="https://groq.example",
            groq_grader_model="groq-model",
            nim_api_key="nim-key",
            nim_base_url="https://nim.example",
            nim_grader_model="nim-model",
        ),
    )

    assert primary() == panel.GraderConfig(
        "cohere", "cohere-key", "https://api.cohere.com", "command-a-plus-05-2026"
    )
