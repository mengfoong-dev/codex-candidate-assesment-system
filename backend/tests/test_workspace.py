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


async def test_post_file_endpoint_persists_edit_and_feeds_content_aware_grading(new_session, client):
    """The write endpoint the Godot copilot POSTs its edited orchestrator to: it persists as source
    'ai' and makes content-aware grading evaluate the real code (not the seed)."""
    session_id = new_session["session_id"]

    write_resp = await client.post(
        f"/api/sessions/{session_id}/files/src/homepage_orchestrator.ts",
        json={"content": _CONCURRENT_REWRITE},
    )
    assert write_resp.status_code == 200, write_resp.text
    assert write_resp.json()["source"] == "ai"

    got = await client.get(f"/api/sessions/{session_id}/files/src/homepage_orchestrator.ts")
    assert got.json()["content"] == _CONCURRENT_REWRITE
    assert got.json()["source"] == "ai"

    graded = await client.post(
        f"/api/sessions/{session_id}/tests/p95_latency", json={"remediation_id": "scale_cpu"}
    )
    assert graded.status_code == 200, graded.text
    assert graded.json()["status"] == "passed"
    assert "Validated against your edited" in graded.json()["actual_result"]


# --- run the sandbox app + per-session revert to base -------------------------------------------
# "Revert to base state for every session" is NOT a reset action (that would break the locked
# orphan-never-delete rule — old edited rows must survive for Proof Replay). The base seed lives
# immutably on disk; each NEW session re-seeds from it. This test runs the sandbox app in one
# session (read real content -> edit it -> validate the edit) and proves the next session is back
# to the pristine base, and that the on-disk source of truth was never mutated by the edit.
async def test_sandbox_app_runs_and_each_new_session_reverts_to_base(client):
    from src.registry import get_default_scenario

    base = {f["path"]: f["content"] for f in get_default_scenario().seeded_files}
    orchestrator = "src/homepage_orchestrator.ts"
    assert orchestrator in base  # sanity: the seed loaded at all

    # --- session A: run the sandbox app end-to-end ---
    a = (await client.post("/api/sessions", json={"display_name": "A"})).json()["session_id"]

    read_a = await client.get(f"/api/sessions/{a}/files/{orchestrator}")
    assert read_a.status_code == 200
    assert read_a.json()["content"] == base[orchestrator]  # real seed, never "File not found"
    assert read_a.json()["source"] == "seeded"

    await _write_orchestrator(a, _CONCURRENT_REWRITE)  # candidate/AI edits the app in-session

    edited = (await client.get(f"/api/sessions/{a}/files/{orchestrator}")).json()
    assert edited["content"] == _CONCURRENT_REWRITE
    assert edited["source"] == "ai"  # A now diverges from base

    ran = await client.post(
        f"/api/sessions/{a}/tests/p95_latency", json={"remediation_id": "scale_cpu"}
    )
    assert ran.json()["status"] == "passed"  # the edited app validates (write->validate loop)

    # --- session B: a brand-new session is back to the pristine base ---
    b = (await client.post("/api/sessions", json={"display_name": "B"})).json()["session_id"]

    read_b = (await client.get(f"/api/sessions/{b}/files/{orchestrator}")).json()
    assert read_b["content"] == base[orchestrator]  # reverted to base — A's edit is not visible
    assert read_b["source"] == "seeded"

    listing_b = {
        f["path"]: f["source"] for f in (await client.get(f"/api/sessions/{b}/files")).json()
    }
    assert listing_b == {path: "seeded" for path in base}  # every base file re-seeded verbatim

    # --- the on-disk base was never mutated by A's edit ---
    assert {f["path"]: f["content"] for f in get_default_scenario().seeded_files} == base
