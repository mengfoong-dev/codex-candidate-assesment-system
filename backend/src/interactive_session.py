"""Five-turn, in-process candidate-session runner used by the local interactive CLI."""

from __future__ import annotations

import json
from collections.abc import AsyncIterator, Callable, Iterable, Mapping
from dataclasses import dataclass
from typing import Any

from httpx import AsyncClient
from src.simulation.service import MAX_CANDIDATE_TURNS


Emit = Callable[[str], None]
PromptReader = Callable[[int, int], str]
SubmissionReader = Callable[[dict[str, Any]], Mapping[str, Any]]


@dataclass(frozen=True)
class GuidedSessionResult:
    """Observable output from one interactive candidate-session run."""

    session_id: str
    turns_completed: int
    sandbox_files: list[str]
    scripted_tests: dict[str, dict[str, Any]]
    report: dict[str, Any]


def _response_json(response, *, expected_status: int, action: str) -> dict[str, Any]:
    if response.status_code != expected_status:
        raise RuntimeError(
            f"{action} failed: expected HTTP {expected_status}, got {response.status_code}: {response.text}"
        )
    return response.json()


def _parse_sse(body: str) -> list[tuple[str, dict[str, Any]]]:
    """Decode the endpoint's compact Server-Sent Event format for terminal display."""
    events: list[tuple[str, dict[str, Any]]] = []
    for block in body.strip().split("\n\n"):
        lines = [line for line in block.split("\n") if line]
        if len(lines) != 2 or not lines[0].startswith("event: ") or not lines[1].startswith("data: "):
            continue
        events.append((lines[0][7:], json.loads(lines[1][6:])))
    return events


def _validate_prompt_source(*, prompts: Iterable[str] | None, prompt_reader: PromptReader | None) -> None:
    if (prompts is None) == (prompt_reader is None):
        raise ValueError("Provide exactly one of prompts or prompt_reader.")


def _next_prompt_from_reader(prompt_reader: PromptReader, *, turn_number: int) -> str:
    """Read one non-empty candidate turn only after the previous SSE stream has closed."""
    while True:
        prompt = prompt_reader(turn_number, MAX_CANDIDATE_TURNS).strip()
        if prompt:
            return prompt


async def _stream_sse_events(response) -> AsyncIterator[tuple[str, dict[str, Any]]]:
    """Incrementally decode the small SSE contract consumed by the terminal and TSX clients."""
    event_name: str | None = None
    data_lines: list[str] = []

    async for line in response.aiter_lines():
        if not line:
            if event_name is not None and data_lines:
                yield event_name, json.loads("\n".join(data_lines))
            event_name = None
            data_lines = []
            continue
        if line.startswith("event: "):
            event_name = line[7:]
        elif line.startswith("data: "):
            data_lines.append(line[6:])

    if event_name is not None and data_lines:
        yield event_name, json.loads("\n".join(data_lines))


def _emit_scenario_start(*, scenario: Mapping[str, Any], sandbox_files: list[str], emit: Emit) -> None:
    """Show only the candidate-safe problem returned by POST /sessions before prompt one."""
    emit("\n=== Scenario problem ===")
    emit(f"{scenario['title']} — {scenario['role']}")
    emit(str(scenario["brief"]))
    emit("[Assessment capture started: candidate actions and AI exchanges are being recorded.]")
    emit(f"Sandbox created for {scenario['scenario_id']}@{scenario['scenario_version']}.")
    emit(f"Workspace files: {', '.join(sandbox_files) or '(none)'}")


def _submission_payload(
    *, scenario: dict[str, Any], submission: Mapping[str, Any] | None, submission_reader: SubmissionReader | None
) -> dict[str, Any]:
    if (submission is None) == (submission_reader is None):
        raise ValueError("Provide exactly one of submission or submission_reader.")
    return dict(submission if submission is not None else submission_reader(scenario))


def format_three_layer_summary(report: Mapping[str, Any]) -> str:
    """Render the stable, human-readable portion of a completed Proof Replay report."""
    scores = report["scores"]
    deterministic = scores["deterministic"]
    lines = [
        "=== Three-layer result ===",
        f"Layer 1 deterministic: {deterministic['total']}/{deterministic['max']}",
        "Layer 2 Cohere rubric:",
    ]
    dimensions = scores["ai_analysis"]["dimensions"]
    if dimensions:
        lines.extend(
            f"  - {dimension['dimension']}: {dimension['score']} ({dimension['consensus']})"
            for dimension in dimensions
        )
    else:
        lines.append("  - unavailable: the Cohere rubric did not return scored dimensions")

    lines.append("Layer 3 context indices:")
    lines.extend(
        f"  - {index['index_id']}: {index['value']}" for index in scores["context_indices"]["indices"]
    )
    return "\n".join(lines)


async def run_guided_session(
    client: AsyncClient,
    *,
    display_name: str,
    prompts: Iterable[str] | None = None,
    prompt_reader: PromptReader | None = None,
    submission: Mapping[str, Any] | None = None,
    submission_reader: SubmissionReader | None = None,
    emit: Emit = print,
) -> GuidedSessionResult:
    """Exercise the frontend HTTP/SSE contract with exactly five alternating candidate turns."""
    _validate_prompt_source(prompts=prompts, prompt_reader=prompt_reader)
    created = _response_json(
        await client.post("/api/sessions", json={"display_name": display_name}),
        expected_status=201,
        action="Create candidate session",
    )
    session_id = str(created["session_id"])
    scenario = dict(created["scenario"])
    sandbox_files = [str(file["path"]) for file in created["files"]]
    _emit_scenario_start(scenario=scenario, sandbox_files=sandbox_files, emit=emit)

    # ADR 0001: when the true on-disk sandbox is active, tell the operator where the real files
    # live so they can open/edit them directly between turns (a genuine modification the next
    # `run test` will grade). No-op under the default DB backend.
    from src.workspace import sandbox as _sandbox

    if _sandbox.enabled():
        emit(f"True sandbox directory (real files — edit them directly between turns): {_sandbox.session_dir(session_id)}")

    prompt_iterator = iter(prompts) if prompts is not None else None
    completed_turns = 0
    for turn_number in range(1, MAX_CANDIDATE_TURNS + 1):
        if prompt_reader is not None:
            prompt = _next_prompt_from_reader(prompt_reader, turn_number=turn_number)
        else:
            assert prompt_iterator is not None
            prompt = ""
            while not prompt:
                try:
                    prompt = str(next(prompt_iterator)).strip()
                except StopIteration as exc:
                    raise ValueError(f"Exactly {MAX_CANDIDATE_TURNS} non-empty prompts are required.") from exc

        emit(f"\nCandidate turn {turn_number}/{MAX_CANDIDATE_TURNS}: {prompt}")
        agent_text: list[str] = []
        async with client.stream(
            "POST",
            f"/api/sessions/{session_id}/messages",
            json={"content": prompt},
            headers={"Accept": "text/event-stream"},
        ) as response:
            if response.status_code != 200:
                body = (await response.aread()).decode("utf-8", errors="replace")
                raise RuntimeError(f"Coding-agent turn {turn_number} failed: HTTP {response.status_code}: {body}")

            async for event_name, event_payload in _stream_sse_events(response):
                if event_name == "token":
                    agent_text.append(str(event_payload["text"]))
                elif event_name == "tool_use":
                    emit(f"  sandbox tool: {event_payload['tool']} {event_payload.get('path', '')}".rstrip())
                elif event_name == "file_updated":
                    emit(f"  sandbox updated: {event_payload['path']} (refetch this file from the workspace API)")
                elif event_name == "error":
                    raise RuntimeError(f"Coding agent unavailable: {event_payload.get('message', 'unknown error')}")

        emit(f"Agent feedback: {''.join(agent_text) or '(no text response)'}")
        completed_turns += 1

    emit(f"\nTurn limit reached: the session accepts no more than {MAX_CANDIDATE_TURNS} candidate prompts.")
    emit("[Assessment capture complete. Computing the three-layer score...]")
    payload = _submission_payload(scenario=scenario, submission=submission, submission_reader=submission_reader)

    for artifact_id in dict.fromkeys(payload.get("supporting_evidence_ids", [])):
        _response_json(
            await client.post(
                f"/api/sessions/{session_id}/events",
                json={"event_type": "evidence_viewed", "payload": {"artifact_id": artifact_id}},
            ),
            expected_status=201,
            action=f"Record selected evidence {artifact_id}",
        )

    scripted_tests: dict[str, dict[str, Any]] = {}
    for test_id in dict.fromkeys(payload.get("validation_test_ids", [])):
        scripted_tests[str(test_id)] = _response_json(
            await client.post(
                f"/api/sessions/{session_id}/tests/{test_id}",
                json={"remediation_id": payload["remediation_id"]},
            ),
            expected_status=200,
            action=f"Run scripted test {test_id}",
        )
        emit(
            f"Scripted test {test_id}: {scripted_tests[str(test_id)]['status']} - "
            f"{scripted_tests[str(test_id)]['actual_result']}"
        )

    submitted = _response_json(
        await client.post(f"/api/sessions/{session_id}/submit", json=payload),
        expected_status=200,
        action="Submit final conclusion",
    )
    if submitted["status"] != "graded":
        raise RuntimeError(f"Scoring did not complete: {submitted}")

    report = _response_json(
        await client.get(f"/api/sessions/{session_id}/report"),
        expected_status=200,
        action="Read three-layer score report",
    )
    emit("[Scoring and grading complete.]")
    return GuidedSessionResult(
        session_id=session_id,
        turns_completed=completed_turns,
        sandbox_files=sandbox_files,
        scripted_tests=scripted_tests,
        report=report,
    )
