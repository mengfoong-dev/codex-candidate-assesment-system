"""Run a five-turn Cohere-backed candidate session against an isolated local database."""

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
os.chdir(PROJECT_ROOT)


def _read_required(prompt: str, valid_ids: set[str]) -> str:
    while True:
        value = input(prompt).strip()
        if value in valid_ids:
            return value
        print(f"Enter one of: {', '.join(sorted(valid_ids))}")


def _read_optional_ids(prompt: str, valid_ids: set[str]) -> list[str]:
    while True:
        raw = input(prompt).strip()
        if not raw:
            return []
        values = [value.strip() for value in raw.split(",") if value.strip()]
        invalid = sorted(set(values) - valid_ids)
        if not invalid:
            return values
        print(f"Unknown IDs: {', '.join(invalid)}. Valid IDs: {', '.join(sorted(valid_ids))}")


def _show_options(title: str, options: list[dict[str, Any]]) -> set[str]:
    print(f"\n{title}:")
    for option in options:
        print(f"  - {option['option_id']}: {option.get('label', option.get('description', ''))}")
    return {str(option["option_id"]) for option in options}


def _collect_submission(scenario: dict[str, Any]) -> dict[str, Any]:
    """Collect a candidate-authored submission using only candidate-safe options."""
    options = scenario["submission_options"]
    root_causes = _show_options("Root causes", options["root_causes"])
    remediations = _show_options("Remediations", options["remediations"])
    impacts = _show_options("Expected impacts", options["expected_impacts"])
    risks = _show_options("Risks", options["risks"])
    assumptions = _show_options("Assumptions", options["assumptions"])
    rollbacks = _show_options("Rollbacks", options["rollbacks"])
    artifact_ids = {str(artifact["artifact_id"]) for artifact in scenario["artifacts"]}
    required_tests = {str(test_id) for test_id in options["required_validation_test_ids"]}

    print(f"\nSupporting evidence IDs: {', '.join(sorted(artifact_ids))}")
    return {
        "root_cause_id": _read_required("Root cause ID: ", root_causes),
        "supporting_evidence_ids": _read_optional_ids("Evidence IDs (comma-separated): ", artifact_ids),
        "remediation_id": _read_required("Remediation ID: ", remediations),
        "expected_impact_id": _read_required("Expected impact ID: ", impacts),
        "risk_ids": _read_optional_ids("Risk IDs (comma-separated, optional): ", risks),
        "assumption_ids": _read_optional_ids("Assumption IDs (comma-separated, optional): ", assumptions),
        "validation_test_ids": sorted(required_tests),
        "rollback_id": _read_required("Rollback ID: ", rollbacks),
        "final_confidence": int(_read_required("Confidence (0-100): ", {str(value) for value in range(101)})),
        "rationale": input("Final rationale: ").strip(),
    }


def _read_prompt(turn_number: int, total_turns: int) -> str:
    return input(f"\nYour prompt ({turn_number}/{total_turns}): ")


def _print_report(report: dict[str, Any]) -> None:
    from src.interactive_session import format_three_layer_summary

    print(f"\n{format_three_layer_summary(report)}")
    print("\nFull report JSON:")
    print(json.dumps(report, indent=2, sort_keys=True))


async def _run() -> int:
    from src.config import get_settings

    # ADR 0001: this interactive tool runs against the TRUE on-disk sandbox (real files, real
    # `vitest run`), not the default DB-rows workspace. setdefault so `WORKSPACE_BACKEND=db` can
    # still force the old behavior. The sandbox root defaults to a stable OS-temp folder, so the
    # Node toolchain is installed once and reused across runs.
    os.environ.setdefault("WORKSPACE_BACKEND", "fs")
    get_settings.cache_clear()
    if not get_settings().cohere_api_key:
        print("COHERE_API_KEY is empty. Add a rotated key to backend/.env, then rerun this command.")
        return 2

    with tempfile.TemporaryDirectory(prefix="vibeproof-interactive-") as temp_dir:
        os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{(Path(temp_dir) / 'interactive.db').as_posix()}"
        get_settings.cache_clear()

        from httpx import ASGITransport, AsyncClient

        from src.database import AsyncSessionLocal, Base, engine
        from src.interactive_session import run_guided_session
        from src.main import create_app
        from src.registry import seed_scenarios

        try:
            async with engine.begin() as connection:
                await connection.run_sync(Base.metadata.drop_all)
                await connection.run_sync(Base.metadata.create_all)
            async with AsyncSessionLocal() as database_session:
                await seed_scenarios(database_session)

            async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://interactive") as client:
                result = await run_guided_session(
                    client,
                    display_name=input("Candidate display name [Local Tester]: ").strip() or "Local Tester",
                    prompt_reader=_read_prompt,
                    submission_reader=_collect_submission,
                )
                _print_report(result.report)
                return 0
        finally:
            await engine.dispose()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run()))
