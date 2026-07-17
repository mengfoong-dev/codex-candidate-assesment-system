"""Guard over the Virtual Workspace seed — the ONLY protection over seed content.

`candidate_safe_view()` redacts the scenario JSON, but seeded file content and manifest role labels
are injected verbatim (into read_file results and the system prompt). This is where the answer could
leak. These tests fail the build if a seed file or role label states the diagnosis in words or reuses
a scoring/answer id, if the manifest and on-disk files drift apart, if a leaf service takes anything
other than userId, or if the frozen seed file set changes without an intentional snapshot edit.
"""
from pathlib import PurePosixPath

from src.config import get_settings
from src.registry import get_default_scenario

# Frozen seed contract (closed reference graph). Editing the seed file set is a deliberate one-line
# change here — behavioral tests use membership so only this snapshot churns.
EXPECTED_SEED = sorted(
    [
        "package.json",
        "src/homepage_orchestrator.ts",
        "src/renderHomepage.ts",
        "src/services/getNotices.ts",
        "src/services/getProfile.ts",
        "src/services/getRecommendations.ts",
        "src/services/requireAuthenticatedUser.ts",
    ]
)

# The answer stated in prose. The buggy PATTERN (sequential awaits) is kept discoverable; only the
# answer-in-words is banned. "sequential" is intentionally NOT here — it describes the bug, not the fix.
_BANNED_PROSE = ("independent", "parallelize", "parallel", "concurrent", "concurrency", "promise.all")

_LEAF_SERVICES = {
    "src/services/requireAuthenticatedUser.ts": "requireAuthenticatedUser",
    "src/services/getProfile.ts": "getProfile",
    "src/services/getRecommendations.ts": "getRecommendations",
    "src/services/getNotices.ts": "getNotices",
}


def _banned_ids() -> set[str]:
    """Scoring/answer ids pulled from the scenario (not hardcoded) so the guard tracks id changes."""
    scenario = get_default_scenario()
    opts = scenario.submission_options
    ids = set(opts["root_cause_id"]) | set(opts["remediation_id"])
    ids |= {c["criterion_id"] for c in scenario.criteria}
    return {i.lower() for i in ids}


def test_seed_file_set_matches_frozen_snapshot():
    paths = sorted(f["path"] for f in get_default_scenario().seeded_files)
    assert paths == EXPECTED_SEED


def test_manifest_and_disk_are_one_to_one():
    settings = get_settings()
    base = settings.workspace_data_dir / "homepage_latency"
    on_disk = {
        PurePosixPath(p.relative_to(base).as_posix()).as_posix()
        for p in base.rglob("*")
        # `.harness/` is the ADR 0001 sandbox grading harness (tsconfig + the vitest test). It lives
        # on disk but is DELIBERATELY absent from _manifest.json so it never seeds into session_files
        # or list_files — the candidate/AI must not see the test that grades them.
        if p.is_file() and p.name != "_manifest.json" and ".harness" not in p.parts
    }
    declared = {f["path"] for f in get_default_scenario().seeded_files}
    assert on_disk == declared
    # And the hidden harness must never sneak into the seeded set.
    assert not any(".harness" in path for path in declared)


def test_every_seed_file_has_a_nonempty_role():
    for f in get_default_scenario().seeded_files:
        assert f.get("role", "").strip(), f"missing role for {f['path']}"


def test_seed_content_and_roles_do_not_leak_the_answer():
    banned_ids = _banned_ids()
    for f in get_default_scenario().seeded_files:
        haystacks = {"content": f["content"].lower(), "role": f["role"].lower()}
        for where, text in haystacks.items():
            for token in _BANNED_PROSE:
                assert token not in text, f"answer prose {token!r} leaked in {f['path']} {where}"
            for bad_id in banned_ids:
                assert bad_id not in text, f"scoring id {bad_id!r} leaked in {f['path']} {where}"


def test_leaf_services_take_only_userid():
    by_path = {f["path"]: f["content"] for f in get_default_scenario().seeded_files}
    for path, fn in _LEAF_SERVICES.items():
        assert f"{fn}(userId: string)" in by_path[path], f"{fn} must take only userId"


# --- write->validate detector (static, D006-safe) ---------------------------

def test_rewrite_detector_fails_on_the_seeded_sequential_body():
    from src.evaluation.rewrite_check import evaluate_orchestrator_rewrite

    seeded = next(
        f["content"] for f in get_default_scenario().seeded_files
        if f["path"] == "src/homepage_orchestrator.ts"
    )
    assert evaluate_orchestrator_rewrite(seeded)["passed"] is False


def test_rewrite_detector_passes_on_a_grouped_rewrite():
    from src.evaluation.rewrite_check import evaluate_orchestrator_rewrite

    fixed = (
        "export async function renderHomepageForUser(userId: string) {\n"
        "  await requireAuthenticatedUser(userId);\n"
        "  const [profile, recommendations, notices] = await Promise.all([\n"
        "    getProfile(userId), getRecommendations(userId), getNotices(userId),\n"
        "  ]);\n"
        "  return renderHomepage({ profile, recommendations, notices });\n"
        "}\n"
    )
    assert evaluate_orchestrator_rewrite(fixed)["passed"] is True


def test_rewrite_detector_rejects_reordered_auth():
    from src.evaluation.rewrite_check import evaluate_orchestrator_rewrite

    broken = (
        "export async function renderHomepageForUser(userId: string) {\n"
        "  const [profile, recommendations, notices] = await Promise.all([\n"
        "    getProfile(userId), getRecommendations(userId), getNotices(userId),\n"
        "  ]);\n"
        "  await requireAuthenticatedUser(userId);\n"
        "  return renderHomepage({ profile, recommendations, notices });\n"
        "}\n"
    )
    assert evaluate_orchestrator_rewrite(broken)["passed"] is False
