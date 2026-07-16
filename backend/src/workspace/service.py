"""Virtual Workspace (decision B4: DB rows, nothing ever executes) + scripted test results
(decision D006: "running tests" looks up a pre-authored table, no code runs)."""
from sqlalchemy import select

from src.event_log import append_event
from src.exceptions import AppError
from src.models import SessionFile
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
    result = scenario.results_by_remediation(test_id, remediation_id)
    if result is None:
        status, actual_result = "unavailable", _UNAVAILABLE_MESSAGE
    else:
        status, actual_result = result["status"], result["actual_result"]

    # Write->validate loop (D006-safe, static): if the candidate/AI actually rewrote the orchestrator,
    # grade the two required validation tests against the FILE CONTENT instead of the remediation-id
    # table, so a genuine written fix is what earns the pass. Nothing executes — see rewrite_check.
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
        "scripted": True,  # always true — this is a scripted test result, never real execution
    }
