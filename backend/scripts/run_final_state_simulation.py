"""Run the documented final-state API flow against an isolated SQLite database.

This is an executable, no-network simulation. It drives the FastAPI application in
process through HTTPX ASGI transport, so no port, API key, external service, or
production database is required.
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


def require_status(response: Any, expected: int, step: str) -> dict[str, Any]:
    """Return an HTTP response JSON body or stop with a useful assertion message."""
    assert response.status_code == expected, (
        f"{step}: expected HTTP {expected}, got {response.status_code}: {response.text}"
    )
    return response.json()


async def run_simulation() -> dict[str, Any]:
    """Drive the complete documented final-state flow and return an observed summary."""
    # These explicit empty values override a developer .env file for this subprocess.
    # The panel therefore degrades gracefully and never makes a vendor network call.
    os.environ["GROQ_API_KEY"] = ""
    os.environ["NIM_API_KEY"] = ""

    with tempfile.TemporaryDirectory(prefix="vibeproof-final-state-") as temp_dir:
        database_path = Path(temp_dir) / "simulation.db"
        os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{database_path.as_posix()}"

        from httpx import ASGITransport, AsyncClient

        from src.database import AsyncSessionLocal, Base, engine
        from src.main import create_app
        from src.registry import seed_scenarios

        try:
            async with engine.begin() as connection:
                await connection.run_sync(Base.metadata.drop_all)
                await connection.run_sync(Base.metadata.create_all)
            async with AsyncSessionLocal() as database_session:
                await seed_scenarios(database_session)

            app = create_app()
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://simulation") as client:
                created = require_status(
                    await client.post("/api/sessions", json={"display_name": "Final-State Simulation"}),
                    201,
                    "create session",
                )
                session_id = created["session_id"]

                snapshot = require_status(
                    await client.get(f"/api/sessions/{session_id}"),
                    200,
                    "read initial snapshot",
                )
                assert snapshot["status"] == "active"

                files = require_status(
                    await client.get(f"/api/sessions/{session_id}/files"),
                    200,
                    "list virtual workspace files",
                )
                assert any(file["path"] == "src/homepage_orchestrator.ts" for file in files)

                source = require_status(
                    await client.get(
                        f"/api/sessions/{session_id}/files/src/homepage_orchestrator.ts"
                    ),
                    200,
                    "read orchestrator source",
                )
                assert source["source"] == "seeded"
                assert "renderHomepageForUser" in source["content"]

                forged_event = await client.post(
                    f"/api/sessions/{session_id}/events",
                    json={
                        "event_type": "evidence_viewed",
                        "payload": {"artifact_id": "forged_artifact"},
                    },
                )
                require_status(forged_event, 422, "reject forged artifact")

                for artifact_id in (
                    "metrics_overview",
                    "homepage_trace",
                    "homepage_orchestrator",
                ):
                    require_status(
                        await client.post(
                            f"/api/sessions/{session_id}/events",
                            json={
                                "event_type": "evidence_viewed",
                                "payload": {"artifact_id": artifact_id},
                            },
                        ),
                        201,
                        f"record evidence view for {artifact_id}",
                    )

                test_results: dict[str, dict[str, Any]] = {}
                for test_id in ("correctness_regression", "p95_latency"):
                    test_results[test_id] = require_status(
                        await client.post(
                            f"/api/sessions/{session_id}/tests/{test_id}",
                            json={
                                "remediation_id": (
                                    "parallelize_confirmed_independent_calls"
                                )
                            },
                        ),
                        200,
                        f"run scripted test {test_id}",
                    )
                    assert test_results[test_id]["status"] == "passed"
                    assert test_results[test_id]["scripted"] is True

                submission = {
                    "root_cause_id": "sequential_independent_calls",
                    "supporting_evidence_ids": [
                        "homepage_trace",
                        "homepage_orchestrator",
                    ],
                    "remediation_id": "parallelize_confirmed_independent_calls",
                    "expected_impact_id": "lower_p95_preserve_correctness",
                    "risk_ids": ["dependency_order"],
                    "assumption_ids": ["calls_are_independent"],
                    "validation_test_ids": [
                        "correctness_regression",
                        "p95_latency",
                    ],
                    "rollback_id": "restore_sequential_orchestration",
                    "final_confidence": 85,
                    "rationale": (
                        "Sequential awaits of independent lookups accumulate latency; "
                        "parallelize them while preserving required ordering."
                    ),
                }
                submitted = require_status(
                    await client.post(f"/api/sessions/{session_id}/submit", json=submission),
                    200,
                    "submit final conclusion",
                )
                assert submitted["status"] == "graded"

                report = require_status(
                    await client.get(f"/api/sessions/{session_id}/report"),
                    200,
                    "read Proof Replay report",
                )
                deterministic = report["scores"]["deterministic"]
                criteria = {
                    criterion["criterion_id"]: criterion
                    for criterion in deterministic["criteria"]
                }
                assert deterministic["total"] == 60
                assert deterministic["max"] == 70
                assert criteria["verification_discipline"]["status"] == "excluded"
                for criterion_id in (
                    "trace_before_change",
                    "healthy_signals_used",
                    "sequential_source_identified",
                    "independence_checked",
                    "dual_validation_selected",
                    "evidence_coverage",
                ):
                    assert criteria[criterion_id]["status"] == "met"
                    assert criteria[criterion_id]["evidence_refs"]

                duplicate_submit = await client.post(
                    f"/api/sessions/{session_id}/submit", json=submission
                )
                require_status(duplicate_submit, 409, "reject duplicate submit")

                return {
                    "session_status": submitted["status"],
                    "scenario": "homepage_latency@1.0.0",
                    "workspace_file_verified": source["path"],
                    "evidence_views_recorded": 3,
                    "scripted_tests": {
                        test_id: {
                            "status": result["status"],
                            "actual_result": result["actual_result"],
                        }
                        for test_id, result in test_results.items()
                    },
                    "deterministic_score": {
                        "total": deterministic["total"],
                        "max": deterministic["max"],
                        "verification_discipline": criteria[
                            "verification_discipline"
                        ]["status"],
                    },
                    "ai_analysis_dimension_count": len(
                        report["scores"]["ai_analysis"]["dimensions"]
                    ),
                    "context_indices_count": len(
                        report["scores"]["context_indices"]["indices"]
                    ),
                    "notices_present": sorted(report["notices"].keys()),
                    "negative_controls": {
                        "forged_artifact_rejected": forged_event.status_code,
                        "duplicate_submit_rejected": duplicate_submit.status_code,
                    },
                }
        finally:
            await engine.dispose()


if __name__ == "__main__":
    observed = asyncio.run(run_simulation())
    print("FINAL_STATE_SIMULATION_RESULT")
    print(json.dumps(observed, indent=2, sort_keys=True))
