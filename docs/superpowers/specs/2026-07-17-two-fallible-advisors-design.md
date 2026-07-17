# Two Fallible Advisors — assessment redesign

**Date:** 2026-07-17
**App:** `apps/incident-room` (Godot 4.7 web) + `backend` (FastAPI grader) + scenario JSON

## Thesis

The candidate must reach the truth when **neither the senior nor the AI is fully right**, by
gathering the right information and verifying it against evidence. Three skills, three stages:

1. **Gather from a fallible senior** — Sam (the task delegator) gives a plausible-but-wrong
   steer and only reveals key context when asked good questions. Tests whether the candidate
   knows how to gather info by questioning, instead of taking the delegator at face value.
2. **Separate signal from noise** — the desktop offers several diagnostic tools, some genuine
   decoys. Tests discernment: what to open, and what to correctly dismiss.
3. **Synthesize, fix, verify** — use Codex (also fallible) or fix by hand, then validate that
   it actually resolves the incident.

## Hard design constraints (carried from prior decisions)

- **Deterministic scoring only.** The graded signal comes from *structured* candidate actions
  (recorded facts, case-board tags, AI disposition, evidence viewed, validation), never from
  judging free LLM chat text. Keeps the score reproducible/defensible.
- **Sam and Codex are live LLM proxies.** Their fallibility is shaped through the proxy
  system prompts + task context, not hardcoded replies. Their transcripts are **Layer-2**
  (human review), logged but not auto-scored.
- **Don't force gates that erase the signal.** Verifying, tagging, and question-asking are
  *rewarded when done*, not mandatory walls — otherwise everyone looks identical and the
  senior-vs-blind variance vanishes.
- **No live oracle.** Metrics/ticker never react to raw code edits; the p95 flips on a
  discrete validated fix. (Already built.)

## The connective mechanic: the Case Board

A single board captures gathering **and** discernment deterministically:
- As the candidate learns facts — from Sam **or** from a metric tool — they add a card and tag
  it **supports / contradicts / irrelevant** to their current hypothesis.
- Cards come from a scenario-defined fact pool that mixes **real facts** and **decoys**.
- The board is what the Submit form draws "supporting evidence" from.
- **Gradeable:** did they capture the real facts, correctly tag the decoys as irrelevant, and
  not build their case on noise? This is the structured signal behind both "gathered well"
  and "discerned signal from noise" — no LLM judging required.
- Non-blocking, never auto-filled (auto-fill leaks the answer).

## Features by thread

### Thread 1 — Fallible senior + question-gathering
- **Scenario:** add a `senior` block: a plausible-wrong opening steer (e.g. "probably the DB,
  it bit us last month"), a set of `facts` (real + decoy) with the *question intent* that
  surfaces each, and which facts are "key."
- **Proxy:** feed the senior-proxy a system prompt that (a) holds the wrong prior unless
  challenged, (b) reveals a specific fact when the candidate's question targets it, (c) refuses
  to name the root cause ("that's your job — here's what I saw").
- **Frontend:** Sam chat logs the candidate's actual questions (Layer-2). An **"Open questions"**
  panel shows unknowns that resolve as facts get added to the board — progress feedback without
  revealing answers.
- **Scoring (new criterion):** `senior_guess_not_blindly_adopted` — parallel to the AI one;
  reward when the final root cause differs from the senior's steer OR the contradicting evidence
  was viewed/tagged before concluding.

### Thread 2 — Noisy metrics + decoys
- **Scenario:** add decoy artifacts with real `evidence_type`s: a Redis cache dashboard
  (tempting-wrong), an autoscaler/CPU panel (healthy → rules out scaling), and a **deploy
  changelog** (the real clue: the new sequential call was added this release). Mark each fact
  `relevant: true|false`.
- **Frontend:** the Investigate tab already renders per-type; decoys slot in. Viewing a tool
  offers its facts as case-board cards to tag.
- **Scoring (new criterion):** `discernment` — reward correctly tagging decoys irrelevant and
  key facts as supporting; penalize a diagnosis that cites a decoy as support. (Extends the
  existing `diagnosis_without_evidence`.)

### Thread 3 — Fallible AI + verify-revise
- **Scenario/proxy:** Codex proposes the parallelize fix but asserts one confident, checkable
  **overclaim** re-targeted to the genuinely-false `no_required_ordering` assumption (NOT
  independence, which is the true answer). Logged; caught via the disposition + trace.
- **Frontend:** reward feeding gathered evidence into the prompt (the console already has brief
  + source; add the tagged case-board facts to its context). Bounded **submit → validate →
  revise once** loop with honest feedback ("p95 still red — ordering broke").
- **Scoring:** existing `independence_checked` / `unverified_ai_acceptance` / `dual_validation`
  / `revised_after_contradiction` already cover this; verify they fire with the re-targeted
  overclaim.

### Enablers (foundation for the above)
- **Prompt/question logging:** persist the candidate's real Codex + Sam prompts as
  `ai_prompt_submitted` / `senior_question_asked` events (with text) so the Proof Replay shows
  their whole AI/human conversation for Layer-2 review. (Today only a scripted `prompt_id` is
  logged.)
- **Case board data model:** a recorded `evidence_tagged{fact_id, stance}` event stream.

## Suggested sequencing (each phase verified + committed)
1. **Enablers** — prompt/question logging + case-board data model & UI. Unlocks everything;
   frontend + light domain changes; no scoring change yet.
2. **Thread 2 (decoys + discernment)** — scenario decoys + board tagging + `discernment`
   criterion. Mostly scenario + frontend + one grader rule.
3. **Thread 1 (fallible senior)** — senior scenario block + proxy prompt + open-questions panel
   + `senior_guess_not_blindly_adopted` criterion. Touches the senior-proxy service.
4. **Thread 3 (fallible AI + verify-revise)** — re-target the overclaim, feed evidence to the
   console, verify-revise loop. Touches the assistant-proxy + confirm existing criteria fire.

## What each phase touches (flag for coordination)
- **Frontend (`apps/incident-room`):** case board, Investigate decoys, open-questions panel,
  console evidence context, verify-revise UI, prompt logging.
- **Scenario JSON:** decoy artifacts + facts, senior block, re-targeted AI overclaim, new
  criteria. *All new IDs; keep existing IDs stable so the deployed grader keeps working.*
- **Backend grader (`backend`):** new criteria (`discernment`, `senior_guess_not_blindly_adopted`)
  and the `evidence_tagged` replay. **This is the riskiest surface** — the deployed FastAPI
  grader must be updated in lockstep or scores break. Needs its own verification.
- **Proxies (senior-proxy, assistant-proxy):** system-prompt engineering for the fallible steer
  + hidden facts + AI overclaim.

## Risks
- **Backend/scoring drift:** frontend and grader must agree on new criteria + event shapes.
  Stage scoring changes behind the structured events; test the grader independently.
- **LLM proxies are non-deterministic:** the senior's "hidden facts" behavior can't be perfectly
  guaranteed from a prompt. Keep the *gradeable* signal on the case board (what the candidate
  recorded), not on whether the LLM happened to reveal something.
- **Over-gating fatigue:** tagging must be one light gesture per card, optional reason,
  non-blocking. If it becomes mandatory per-fact classification it reproduces the tedium it was
  meant to fix.
- **Reliability:** still one scenario; decoys + fallible advisors raise the bar but a single
  planted set is low-reliability for real hiring. Parallel scenario variants remain the
  fast-follow; disclose the gap to the buyer.

## Open questions for the product owner
1. Is updating the **backend grader** in scope now, or should Threads 2–3's new criteria be
   staged (frontend captures the events; scoring added once the grader is updated together)?
2. How **aggressive** should Sam's wrong steer be — a gentle "my guess is…" (safer, less unfair)
   or a strong confident wrong claim (higher signal, risk of feeling adversarial)?
3. Keep the free-form LLM senior/Codex chats, or move to a **more scripted** senior for
   reliability of the "hidden facts" behavior?
