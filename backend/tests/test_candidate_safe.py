"""Candidate-safe scenario view: scoring config and remediation answers must never leak.
This is a Definition-of-Done item (docs/backend/00-api-contract.md) — assert key ABSENCE, not
just that the response is 201.
"""


async def test_session_scenario_view_hides_scoring_and_remediation_answers(client):
    resp = await client.post("/api/sessions", json={"display_name": "Candidate"})
    assert resp.status_code == 201, resp.text
    scenario = resp.json()["scenario"]

    assert "scoring" not in scenario
    assert scenario["tests"], "fixture should still have tests to check"
    for test in scenario["tests"]:
        assert "results_by_remediation" not in test
