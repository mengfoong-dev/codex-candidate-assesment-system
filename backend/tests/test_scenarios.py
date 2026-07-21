"""GET /api/scenarios: the candidate-safe catalog."""


async def test_list_scenarios(client):
    resp = await client.get("/api/scenarios")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1

    scenario = body[0]
    assert scenario["scenario_id"] == "homepage_latency"
    assert scenario["version"] == "1.0.0"
    # Backend now reads the shared Godot scenario copy (apps/incident-room/data/scenarios), which
    # carries the VibeTube rebrand; the drifted "Homepage" mirror is only a standalone-deploy fallback.
    assert scenario["title"] == "VibeTube Watch-Page Latency Incident"
    assert scenario["duration_minutes"] == 30
    # Catalog view is intentionally thin — no scoring/answer-revealing keys here either.
    assert set(scenario.keys()) == {"scenario_id", "version", "title", "role", "duration_minutes"}


async def test_tts_route_is_not_exposed(client):
    resp = await client.post("/api/tts", json={"text": "status check"})
    assert resp.status_code == 404
