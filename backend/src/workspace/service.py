"""Virtual Workspace (decision B4: DB rows, nothing ever executes) + scripted test results
(decision D006: "running tests" looks up a pre-authored table, no code runs)."""
from sqlalchemy import select

from src.event_log import append_event
from src.exceptions import AppError
from src.models import Session, SessionFile
from src.registry import Scenario
from src.schemas import TestExecutedPayload

_UNAVAILABLE_MESSAGE = (
    "No scripted result is available for this proposal; select or describe an appropriate "
    "validation plan."
)

# Write->validate loop: the file whose rewritten content the two required tests grade against, and
# the tests that support content-aware validation. Scoped to the homepage_latency scenario.
_ORCHESTRATOR_PATH = "src/homepage_orchestrator.ts"
_CONTENT_VALIDATED_TESTS = {"correctness_regression", "p95_latency"}


async def list_files(db, session_id: str) -> list[dict]:
    result = await db.execute(select(SessionFile).where(SessionFile.session_id == session_id))
    return [
        {"path": f.path, "source": f.source, "updated_at": f.updated_at}
        for f in result.scalars().all()
    ]


async def get_file(db, session_id: str, path: str) -> dict:
    f = await db.get(SessionFile, (session_id, path))
    if f is None:
        raise AppError("file_not_found", f"Unknown file {path!r} for session {session_id}", 404)
    return {"path": f.path, "source": f.source, "updated_at": f.updated_at, "content": f.content}


async def save_candidate_file(db, *, session_id: str, path: str, content: str) -> dict:
    """Persist a candidate/AI-applied edit to a workspace file so the content-aware rewrite grading
    (run_scripted_test) evaluates the real edited code, not the seed. Upserts with source='ai' (the
    edit came from the AI copilot), and refuses writes once the session is submitted (409), matching
    the event log's post-submit lockout. Column-only status read — no ORM hydration."""
    row = (await db.execute(select(Session.status).where(Session.id == session_id))).first()
    if row is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    if row.status != "active":
        raise AppError("session_not_active", "Session no longer accepts writes", 409)

    from src.simulation.tools import write_file  # lazy: avoids a workspace<->simulation import cycle

    f = await write_file(db, session_id, path, content)
    await db.commit()
    return {"path": f.path, "source": f.source, "updated_at": f.updated_at}


async def run_scripted_test(
    db, *, session_id: str, scenario: Scenario, test_id: str, remediation_id: str
) -> dict:
    if test_id not in scenario.test_ids:
        raise AppError("test_not_found", f"Unknown test_id {test_id!r}", 404)
    if remediation_id not in scenario.submission_options["remediation_id"]:
        raise AppError("invalid_remediation_id", f"Unknown remediation_id {remediation_id!r}", 422)

    expected_result = next(
        t["expected_result"] for t in scenario.definition["tests"] if t["test_id"] == test_id
    )

    from src.workspace import sandbox

    if sandbox.enabled():
        # ADR 0001: real execution. Run the actual `vitest run` against the session's on-disk files
        # (the AI/candidate edits), so the result is genuine test output, not a scripted lookup.
        import anyio

        sandbox_result = await anyio.to_thread.run_sync(sandbox.run_tests, session_id, test_id)
        status, actual_result, scripted = (
            sandbox_result["status"],
            sandbox_result["actual_result"],
            False,
        )
    else:
        scripted = True
        result = scenario.results_by_remediation(test_id, remediation_id)
        if result is None:
            status, actual_result = "unavailable", _UNAVAILABLE_MESSAGE
        else:
            status, actual_result = result["status"], result["actual_result"]

        # Write->validate loop (D006-safe, static): if the candidate/AI actually rewrote the
        # orchestrator, grade the two required validation tests against the FILE CONTENT instead of
        # the remediation-id table, so a genuine written fix earns the pass. Nothing executes here.
        if scenario.scenario_id == "homepage_latency" and test_id in _CONTENT_VALIDATED_TESTS:
            orchestrator = await db.get(SessionFile, (session_id, _ORCHESTRATOR_PATH))
            if orchestrator is not None and orchestrator.source in ("ai", "user"):
                from src.evaluation.rewrite_check import evaluate_orchestrator_rewrite

                verdict = evaluate_orchestrator_rewrite(orchestrator.content)
                status = "passed" if verdict["passed"] else "failed"
                actual_result = f"Validated against your edited {_ORCHESTRATOR_PATH}: {verdict['reason']}"

    await append_event(
        db,
        session_id=session_id,
        scenario_id=scenario.scenario_id,
        scenario_version=scenario.version,
        event_type="test_executed",
        payload=TestExecutedPayload(
            test_id=test_id,
            remediation_id=remediation_id,
            expected_result=expected_result,
            actual_result=actual_result,
            status=status,
        ).model_dump(),
        actor="system",
    )

    return {
        "test_id": test_id,
        "expected_result": expected_result,
        "actual_result": actual_result,
        "status": status,
        # True = scripted lookup (D006 default); False = real vitest execution (ADR 0001 sandbox).
        "scripted": scripted,
    }
