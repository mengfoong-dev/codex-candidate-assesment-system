"""GET /api/scenarios: the candidate-safe catalog."""


async def test_list_scenarios(client):
    resp = await client.get("/api/scenarios")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1

    scenario = body[0]
    assert scenario["scenario_id"] == "homepage_latency"
    assert scenario["version"] == "1.0.0"
    assert scenario["title"] == "Homepage Latency Incident"
    assert scenario["duration_minutes"] == 30
    # Catalog view is intentionally thin — no scoring/answer-revealing keys here either.
    assert set(scenario.keys()) == {"scenario_id", "version", "title", "role", "duration_minutes"}
