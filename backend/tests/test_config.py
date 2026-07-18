"""Trust-boundary cleaning of credentials pasted into a hosting UI (Railway).

Regression guard for the hackathon incident where the deployed COHERE_API_KEY was ~7 chars
longer than the working key (quote/whitespace contamination) and every Cohere grader call 401'd
into a silently-degraded, empty Layer-2 panel.
"""
from src.config import Settings


def test_secret_fields_stripped_of_quotes_and_whitespace():
    s = Settings(
        cohere_api_key='  "cohere_realkey123"  ',
        groq_api_key="'gsk_abc'",
        email_password=" xsmtpsib-abc\n",
    )
    assert s.cohere_api_key == "cohere_realkey123"
    assert s.groq_api_key == "gsk_abc"
    assert s.email_password == "xsmtpsib-abc"


def test_blank_secret_becomes_none():
    assert Settings(cohere_api_key='   ""  ').cohere_api_key is None
    assert Settings(cohere_api_key="").cohere_api_key is None


def test_clean_key_passes_through_unchanged():
    assert Settings(cohere_api_key="cohere_y7J2fySkjWoar").cohere_api_key == "cohere_y7J2fySkjWoar"
