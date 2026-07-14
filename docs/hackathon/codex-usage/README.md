# AI Agent Hackathon Usage Log

This folder records how AI-agent time and usage contribute to the VibeProof hackathon project.

## What is tracked

- Session start and end time
- Duration in minutes
- Agent name, such as Codex or Claude Code
- Goal for the session
- Concrete outcome or artifact produced
- Agent spend or usage units, when copied from the account usage/billing view

The workspace cannot read account-level agent credit prices, so the `usage_spend` and `usage_units` fields are intentionally marked for manual entry. No cost is guessed.

## Start and stop a session

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 start -Agent "Codex" -Goal "Build the candidate journey demo"
powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 stop -Outcome "Completed the candidate journey and scoring design"
```

Claude Code can use the same logger:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 start -Agent "Claude Code" -Goal "Implement the assessment flow"
powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 stop -Outcome "Implemented and verified the assessment flow"
```

Codex uses the project hook in `.codex/hooks.json` to start a session when a prompt is submitted and require an explicit stop command before the final response. Sessions left active for more than two hours are automatically closed as stale; their elapsed time may include idle time. Review and trust the hook with `/hooks` in Codex. Use the manual commands if the hook is unavailable or a session is interrupted.

The completed session is appended to `sessions.csv`. If the agent shows usage or credit cost separately, copy it into the matching row after stopping the session.

## Current project goal

Build a feasible hackathon prototype of VibeProof: an AI-allowed technical work simulation that shows how candidates investigate incidents, verify AI-generated code, manage risk, and explain engineering decisions.

## Important reporting boundary

This log reports time spent and project outcomes. It must not claim that VibeProof reads thoughts or directly measures brain activity. The prototype collects observable work behavior and candidate explanations; perceived workload can be collected separately as a self-report for future validation.
