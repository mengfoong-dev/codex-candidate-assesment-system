"""ADR 0001 on-disk sandbox: path containment, materialize, and (opt-in) real vitest execution.

The default suite stays offline and fast by monkeypatching the toolchain install. The real
`npm install` + `vitest run` round trip is gated behind RUN_SANDBOX_E2E=1 so CI never needs Node.
"""
import os

import pytest

from src.workspace import sandbox

_CONCURRENT_FIX = (
    'import { requireAuthenticatedUser } from "./services/requireAuthenticatedUser";\n'
    'import { getProfile } from "./services/getProfile";\n'
    'import { getRecommendations } from "./services/getRecommendations";\n'
    'import { getNotices } from "./services/getNotices";\n'
    'import { renderHomepage } from "./renderHomepage";\n\n'
    "export async function renderHomepageForUser(userId: string) {\n"
    "  await requireAuthenticatedUser(userId);\n"
    "  const [profile, recommendations, notices] = await Promise.all([\n"
    "    getProfile(userId), getRecommendations(userId), getNotices(userId),\n"
    "  ]);\n"
    "  return renderHomepage({ profile, recommendations, notices });\n"
    "}\n"
)


@pytest.fixture
def fs_sandbox(tmp_path, monkeypatch):
    """Enable the fs backend against a throwaway root; restore the settings cache afterward."""
    from src.config import get_settings

    monkeypatch.setenv("WORKSPACE_BACKEND", "fs")
    monkeypatch.setenv("WORKSPACE_SANDBOX_ROOT", str(tmp_path))
    get_settings.cache_clear()
    yield tmp_path
    # Pop BEFORE clearing so the rebuilt settings are db-mode again — monkeypatch reverts env only
    # after this finalizer, so clearing first would re-cache fs mode and leak into later tests.
    os.environ.pop("WORKSPACE_BACKEND", None)
    os.environ.pop("WORKSPACE_SANDBOX_ROOT", None)
    get_settings.cache_clear()


def test_enabled_only_in_fs_mode(fs_sandbox):
    assert sandbox.enabled() is True


def test_safe_path_rejects_traversal(fs_sandbox):
    with pytest.raises(ValueError):
        sandbox._safe_path("s1", "../../etc/passwd")
    resolved = sandbox._safe_path("s1", "src/x.ts")
    assert str(sandbox.session_dir("s1").resolve()) in str(resolved)


def test_write_lands_a_real_file(fs_sandbox):
    sandbox.session_dir("s1").mkdir(parents=True)
    sandbox.write("s1", "src/a.ts", "hello")
    assert (sandbox.session_dir("s1") / "src" / "a.ts").read_text(encoding="utf-8") == "hello"


def test_materialize_writes_seed_and_hidden_harness(fs_sandbox, monkeypatch):
    monkeypatch.setattr(sandbox, "_ensure_toolchain", lambda: None)  # skip npm install
    from src.registry import get_default_scenario

    scenario = get_default_scenario()
    d = sandbox.materialize(
        "s1", scenario_id=scenario.scenario_id, seeded_files=scenario.seeded_files
    )

    assert (d / "src" / "homepage_orchestrator.ts").is_file()  # seed present on disk
    assert (d / "tests" / "homepage.test.ts").is_file()  # hidden grading harness copied in

    # ...but the harness must never be part of the candidate-visible seed (no leak to list_files).
    seed_paths = {f["path"] for f in scenario.seeded_files}
    assert "tests/homepage.test.ts" not in seed_paths
    assert not any(".harness" in p for p in seed_paths)


@pytest.mark.skipif(os.getenv("RUN_SANDBOX_E2E") != "1", reason="does a real npm install; opt-in")
def test_real_vitest_seed_fails_then_fix_passes(fs_sandbox):
    from src.registry import get_default_scenario

    scenario = get_default_scenario()
    sandbox.materialize("s1", scenario_id=scenario.scenario_id, seeded_files=scenario.seeded_files)

    # Seed orchestrator awaits the three lookups sequentially: correctness holds, latency fails.
    assert sandbox.run_tests("s1", "correctness_regression")["status"] == "passed"
    assert sandbox.run_tests("s1", "p95_latency")["status"] == "failed"

    # Apply the concurrent fix as a real edit -> the real vitest run now passes.
    sandbox.write("s1", "src/homepage_orchestrator.ts", _CONCURRENT_FIX)
    passed = sandbox.run_tests("s1", "p95_latency")
    assert passed["status"] == "passed", passed["actual_result"]
    assert passed["scripted"] is False
