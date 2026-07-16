"""Virtual Workspace: seeded files + scripted test lookups (decision D006 — nothing executes)."""


async def test_seeded_file_appears_in_listing_and_content(new_session, client):
    session_id = new_session["session_id"]

    listing = await client.get(f"/api/sessions/{session_id}/files")
    assert listing.status_code == 200
    paths = [f["path"] for f in listing.json()]
    assert "src/homepage_orchestrator.ts" in paths

    content_resp = await client.get(f"/api/sessions/{session_id}/files/src/homepage_orchestrator.ts")
    assert content_resp.status_code == 200
    body = content_resp.json()
    assert body["source"] == "seeded"
    assert "renderHomepageForUser" in body["content"]


async def test_unknown_file_404(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.get(f"/api/sessions/{session_id}/files/does/not/exist.ts")
    assert resp.status_code == 404


async def test_unknown_session_files_listing_404(client):
    resp = await client.get("/api/sessions/does-not-exist/files")
    assert resp.status_code == 404


async def test_scripted_test_passes_for_matching_remediation(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/tests/p95_latency",
        json={"remediation_id": "parallelize_confirmed_independent_calls"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "passed"
    assert body["scripted"] is True


async def test_scripted_test_unavailable_for_unscripted_remediation(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/tests/p95_latency",
        json={"remediation_id": "scale_cpu"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "unavailable"


async def test_unknown_test_id_404(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/tests/not_a_real_test",
        json={"remediation_id": "scale_cpu"},
    )
    assert resp.status_code == 404


async def test_unknown_remediation_id_422(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/tests/p95_latency",
        json={"remediation_id": "not_a_real_remediation"},
    )
    assert resp.status_code == 422
