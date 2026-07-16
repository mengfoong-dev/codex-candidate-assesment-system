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


# --- write->validate loop: the scripted test grades against the rewritten file content ------------

_CONCURRENT_REWRITE = (
    "export async function renderHomepageForUser(userId: string) {\n"
    "  await requireAuthenticatedUser(userId);\n"
    "  const [profile, recommendations, notices] = await Promise.all([\n"
    "    getProfile(userId), getRecommendations(userId), getNotices(userId),\n"
    "  ]);\n"
    "  return renderHomepage({ profile, recommendations, notices });\n"
    "}\n"
)

_STILL_SEQUENTIAL = (
    "export async function renderHomepageForUser(userId: string) {\n"
    "  await requireAuthenticatedUser(userId);\n"
    "  const profile = await getProfile(userId);\n"
    "  const recommendations = await getRecommendations(userId);\n"
    "  const notices = await getNotices(userId);\n"
    "  return renderHomepage({ profile, recommendations, notices });\n"
    "}\n"
)


async def _write_orchestrator(session_id: str, content: str) -> None:
    from src.database import AsyncSessionLocal
    from src.simulation.tools import write_file  # upserts with source="ai"

    async with AsyncSessionLocal() as db:
        await write_file(db, session_id, "src/homepage_orchestrator.ts", content)


async def test_write_validate_passes_on_concurrent_rewrite_even_without_matching_remediation(new_session, client):
    session_id = new_session["session_id"]
    await _write_orchestrator(session_id, _CONCURRENT_REWRITE)

    # remediation_id would normally be "unavailable" — the written fix content overrides it to passed.
    resp = await client.post(
        f"/api/sessions/{session_id}/tests/p95_latency",
        json={"remediation_id": "scale_cpu"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "passed"
    assert "Validated against your edited" in body["actual_result"]


async def test_write_validate_fails_when_rewrite_is_still_sequential(new_session, client):
    session_id = new_session["session_id"]
    await _write_orchestrator(session_id, _STILL_SEQUENTIAL)

    # remediation_id would normally pass — the still-sequential content overrides it to failed.
    resp = await client.post(
        f"/api/sessions/{session_id}/tests/p95_latency",
        json={"remediation_id": "parallelize_confirmed_independent_calls"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "failed"
