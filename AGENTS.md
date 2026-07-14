# Repository Agent Instructions

For substantive repository tasks, follow `skills/agent-session-tracking/SKILL.md`.

Codex project hooks in `.codex/hooks.json` start sessions on prompt submission and require
the session logger to be stopped before a response can finish. Review and trust them with
`/hooks` when Codex asks.

- Check or start an agent-labelled session before doing repository work.
- Stop the session with a concrete outcome before the final response.
- Do not fabricate usage, spend, duration, or logging success.
- Skip session logging for short informational answers with no repository changes.
