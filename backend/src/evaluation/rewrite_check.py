"""Static (D006-safe) validation of a candidate/AI-written homepage orchestrator.

Nothing executes. This is a pure string inspection of the rewritten `src/homepage_orchestrator.ts`
content: it checks whether the three independent lookups were made to run at the same time while
authentication still precedes them and rendering still follows. It powers the write->validate loop
so a written fix is graded on its actual content, not only on the submitted remediation id.
"""

# The three lookups the orchestrator awaits one after another in the seeded (buggy) version.
_LOOKUPS = ("getProfile", "getRecommendations", "getNotices")


def evaluate_orchestrator_rewrite(content: str) -> dict:
    """Return {"passed": bool, "reason": str} for a rewritten orchestrator file.

    # ponytail: substring heuristic, per-scenario, gameable (e.g. a comment mentioning Promise.all
    # would fool it). Enough for the demo's write->validate signal; upgrade to a real TypeScript AST
    # parse if candidates start gaming it.
    """
    grouped_markers = ("Promise.all", "Promise.allSettled")
    group_idx = min((content.find(m) for m in grouped_markers if m in content), default=-1)
    if group_idx == -1:
        return {
            "passed": False,
            "reason": "The three lookups are still awaited one after another; run the confirmed-independent lookups together in a single grouped await.",
        }

    if not all(name in content for name in _LOOKUPS):
        return {
            "passed": False,
            "reason": "The grouped await must include all three lookups (profile, recommendations, notices).",
        }

    auth_idx = content.find("requireAuthenticatedUser")
    if auth_idx == -1 or auth_idx > group_idx:
        return {
            "passed": False,
            "reason": "Authentication must still complete before the lookups run.",
        }

    if content.rfind("renderHomepage") <= group_idx:
        return {
            "passed": False,
            "reason": "The page must still be rendered after the lookups resolve.",
        }

    return {
        "passed": True,
        "reason": "The three independent lookups now run together, with authentication before and rendering after.",
    }
