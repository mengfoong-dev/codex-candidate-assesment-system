"""POST /api/sessions (create) and GET /api/sessions/{id} (snapshot)."""


async def test_create_session_seeds_files_and_returns_candidate_safe_scenario(client):
    resp = await client.post("/api/sessions", json={"display_name": "Ada"})
    assert resp.status_code == 201, resp.text
    body = resp.json()

    assert body["session_id"]
    assert body["files"] == [{"path": "src/homepage_orchestrator.ts", "source": "seeded"}]
    assert body["scenario"]["scenario_id"] == "homepage_latency"


async def test_create_session_defaults_display_name_and_scenario(client):
    resp = await client.post("/api/sessions", json={})
    assert resp.status_code == 201, resp.text
    session_id = resp.json()["session_id"]

    # display_name isn't echoed back by POST /sessions; confirm the default landed via the snapshot.
    snap = (await client.get(f"/api/sessions/{session_id}")).json()
    assert snap["display_name"] == "Anonymous"
    assert snap["scenario_id"] == "homepage_latency"


async def test_get_session_snapshot_of_fresh_session(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.get(f"/api/sessions/{session_id}")
    assert resp.status_code == 200
    body = resp.json()

    assert body["session_id"] == session_id
    assert body["status"] == "active"
    assert body["current_hypothesis"] is None
    assert body["viewed_artifact_ids"] == []
    assert body["chat_history"] == []
    assert body["files"][0]["path"] == "src/homepage_orchestrator.ts"


async def test_get_session_unknown_id_404(client):
    resp = await client.get("/api/sessions/does-not-exist")
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "session_not_found"
