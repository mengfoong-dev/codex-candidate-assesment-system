---
name: agent-session-tracking
description: Use when an AI coding agent begins, continues, or completes a repository task and should record its identity, duration, goal, outcome, and usage in the local session log.
---

# Agent Session Tracking

Record AI-assisted repository work with the project logger at `tools/codex-session.ps1`.
The logger is local and manual: it does not observe agent activity, infer completion, or
read account billing data. Run the commands explicitly and only claim a session was logged
after the command succeeds.

Each teammate's sessions are appended to their own `docs/hackathon/codex-usage/sessions-<git-account>.csv`,
keyed by `git config user.name`, so concurrent contributors never collide in a shared file.
The legacy `sessions.csv` is kept as history. As a safety net, `.gitattributes` marks these
logs `merge=union`, so any residual overlap auto-concatenates instead of conflicting.

Codex also has a project hook at `.codex/hooks.json`. It starts a session when a prompt is
submitted and blocks the final response until an active session is stopped. Review and trust
the hook with `/hooks` in Codex before relying on it. The manual workflow below remains the
fallback for hook failures, Claude Code, and interrupted sessions. Sessions left active for
more than two hours are automatically closed as stale; their elapsed time may include idle time.

## Required workflow

1. At the start of the first substantive repository task, check for an active session:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 status
   ```

2. If no session is active, start one using the actual agent name and a concise goal:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 start -Agent "<Codex or Claude Code>" -Goal "<task goal>"
   ```

3. Before sending the final response for the task, stop the session with a concrete outcome:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 stop -Outcome "<completed work and verification>"
   ```

4. If the stop command fails, report that logging failed. Do not fabricate a session ID,
   duration, spend, or usage value.

## Active-session rules

- Do not overwrite or delete `active-session.json` to start a second session.
- If `status` shows a session for the same task, continue it and stop it at completion.
- If it belongs to an interrupted or different task, preserve it and ask the human whether
  to close it before starting another session.
- If an agent exits unexpectedly, the session may remain active; the human can run `status`
  and then `stop -Outcome "Recovered after interrupted task"`.

## Usage and outcomes

- Use the agent label exactly as it appears in the runtime: `Codex`, `Claude Code`, or another
  tool name.
- Describe observable work in the outcome: files changed, behavior implemented, and checks run.
- Leave `usage_spend` and `usage_units` as `MANUAL_ENTRY_REQUIRED` unless the human provides
  verified account-level values. Never estimate cost from elapsed time.
- Do not start a session for a short informational answer that does not involve repository work.

## Final-response checklist

- [ ] The task session was started or an existing session was verified.
- [ ] The agent name was recorded.
- [ ] The stop command succeeded before the final response.
- [ ] The outcome states what changed and how it was verified.
- [ ] No account-level usage or spend was guessed.
