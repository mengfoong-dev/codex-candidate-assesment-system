# Streamlined "fix-first" flow — design (supersedes the flow in two-fallible-advisors)

**Date:** 2026-07-17
**App:** `apps/incident-room` (Godot 4.7 web) + `backend` (FastAPI grader) + scenario JSON
**Supersedes:** the Case Board / Brief / conclusion-form flow in
`2026-07-17-two-fallible-advisors-design.md`. The *thesis* there is unchanged; the *flow*
is simplified per product-owner direction.

## Thesis (unchanged)

Reach the truth when **neither the senior nor the AI is fully right**, by gathering the right
info and verifying it against evidence. What changed: express it through a **simpler, more
realistic loop** instead of a structured briefing → tagging → conclusion-form wizard.

## The core loop (new)

```
Sign in → office
  → Sam (fallible delegator): gather the task by asking questions; he gives a
    plausible-but-incomplete/biased steer, never the answer. (free chat, logged)
  → desk → PC:
      [ Metrics ] [ Server logs ] [ Request trace ] [ Source ]   ← ALL OPEN, self-directed
        (some screens are genuine decoys / noise — discernment)
      [ Codex ]  ← prompt the AI to fix (your prompt reveals understanding) OR write it by hand;
                   the AI's suggestion carries one plausible-WRONG assumption to catch (logged)
      [ Submit the fix ] ← when confident; it validates (correctness + p95) → red→green ticker
  → Report
```

## What this REMOVES vs today
- **Brief tab** and the **initial-hypothesis gate** (briefing → room no longer requires it).
- **The 9-field conclusion form** — Submit becomes "submit the fix."
- **Case Board / evidence tagging** — dropped entirely (product owner: don't make them tag).
- **No investigate-first gate** — tools + Codex are open from the start *on purpose*: so we can
  observe whether the candidate goes for facts or jumps straight to the AI. (That choice is
  already captured — evidence_viewed vs candidate_ai_prompt timestamps in the Proof Replay.)

## What this KEEPS / reuses
- The 3D office + Sam handoff, the Investigate visual tools (metrics spike, trace waterfall,
  terminal logs), the Codex console, the p95 ticker, and prompt/question logging (Phase 1a).
- Sam and Codex remain **live LLM proxies**; their fallibility is shaped via proxy prompts,
  transcripts are **Layer-2** (human review), not auto-scored.

## Fallible advisors + noisy evidence
- **Sam (senior-proxy prompt):** holds a plausible-wrong prior ("probably the DB, it bit us
  last month"), reveals real context only when asked good questions, refuses to name the root
  cause. Moderate, not adversarial — beatable by verifying.
- **Codex (assistant-proxy):** proposes the parallelize fix but asserts one confident, checkable
  **wrong** assumption re-targeted to `no_required_ordering` (NOT independence, the true cause).
- **Decoy screens:** Redis cache dashboard (tempting-wrong), autoscaler/CPU (healthy → rules out
  scaling); the deploy changelog is the real clue. Discernment = what they open and act on.

## Scoring (reworked — details to finalize with product owner)

The graded submission stops being the structured conclusion; the new deterministic signals:
1. **Fix validates** — the submitted fix is correct-shaped (parallel + preserved auth/render
   ordering) and passes the scenario's correctness + p95 tests. Primary objective signal.
2. **Investigated before acting** — did they open key evidence (trace/source) *before* prompting
   the AI / submitting? Derivable from event timestamps → a deterministic criterion.
3. **Verified the AI** — did they catch/flag the AI's wrong assumption (kept from the disposition
   mechanic, possibly lighter).
- **Layer-2 (human review):** the Sam + Codex transcripts — quality of gathering and AI use.

**Grader-compatibility path (keeps backend change modest):** keep the grader's existing
submission shape, but *derive* it from the new UX instead of form fields —
`remediation_id` from the validated fix shape (the Run-check already detects `Promise.all` +
ordering), `evidence_ids` from screens viewed, `validation_test_ids` from tests run,
`root_cause_id` inferred from the remediation. Criteria with no input (risks/rollback/assumptions)
simply don't score. This avoids a from-scratch grader rewrite.

## Phase machine change
Today: `title → briefing → room → summary`, where `briefing → room` is gated on the initial
hypothesis (recorded on Brief). New: entering the desk/PC advances to `room` directly (no
hypothesis required); tools are open. Simplify the coordinator's phase logic accordingly and
update the affected tests (`test_main_flow`, `test_candidate_session`, `test_workspace_contract`).

## Sequencing (each phase verified + committed)
1. **Flow reshape (frontend):** remove Brief + the gate; open all tools; auto-advance to room;
   Submit becomes "submit the fix" (derive the remediation from the fix). Update tests. This is
   the big structural pass — scoring inputs change, so the grader derivation lands with it.
2. **Fallible advisors (proxies + scenario):** Sam's wrong steer + Codex's wrong assumption via
   proxy prompts; re-target the overclaim to `no_required_ordering`.
3. **Decoys + discernment:** add decoy screens; add an "investigated-first" / "acted-on-decoy"
   scoring criterion.
4. **Backend grader:** finalize the reworked criteria in the deployed FastAPI grader in lockstep.

## What each phase touches
- **Frontend:** `main.gd` phase machine, `browser_workspace.gd` tabs + Submit, `ide_console.gd`
  (submit-the-fix + Run-check), Investigate decoys.
- **Scenario JSON:** decoy artifacts, re-targeted AI assumption, new/removed criteria (stable IDs).
- **Backend grader:** derive-submission + reworked criteria — riskiest surface, do in lockstep.
- **Proxies:** senior-proxy + assistant-proxy system prompts for the fallible behavior.

## Risks
- **Removing the hypothesis gate + conclusion form deletes several current criteria**
  (`revised_after_contradiction`, articulated root cause/risks/rollback). The reworked score is
  simpler and more realistic but **measures less breadth** — an explicit product tradeoff.
- **Backend drift:** frontend submission shape and grader must stay in lockstep; stage behind
  the derived-submission mapping and test the grader independently.
- **LLM proxies are non-deterministic:** keep the *score* on the objective fix-validates +
  timestamps, never on judging chat text.
- **No gate means a candidate can go straight to the AI** — that's intended (it's the signal),
  but ensure the score/review clearly distinguishes fact-gatherers from blind-prompters.
- Still one scenario → low reliability for real hiring; parallel variants remain the fast-follow.

## Open questions for the product owner
1. **Finalize scoring** (deferred): confirm the fix-validates + investigate-first + verify-AI
   model, and how much of the old structured score (if any) to retain.
2. **Sam aggressiveness:** moderate wrong steer (recommended) vs strong confident-wrong.
3. **Backend timing:** rework the deployed grader in this pass, or capture the new signals in the
   frontend first and score once the grader is updated together?
