"""End-to-end contract for the five-turn interactive candidate-session runner."""

import pytest

from src.evaluation import panel as panel_module
from src.simulation import service as simulation_service
from src.simulation.service import ToolCallChunk, TokenChunk, TokenUsage, TurnDone


class ScriptedCodingAgent:
    """Complete provider-boundary double; application routes, DB, SSE, and scoring stay real."""

    def __init__(self, responses: list[str]) -> None:
        self._responses = list(responses)
        self.prompts: list[str] = []

    async def stream_turn(self, *, system, messages, tools):
        self.prompts.append(str(messages[-1]["content"]))
        text = self._responses.pop(0)
        yield TokenChunk(text=text)
        yield TurnDone(
            stop_reason="end_turn",
            usage=TokenUsage(input_tokens=11, output_tokens=7),
            tool_calls=[],
            raw_content={
                "role": "assistant",
                "content": [{"type": "text", "text": text}],
                "tool_calls": [],
            },
        )


class SandboxEditingAgent:
    """Provider double that performs one write_file round trip, then answers four more turns."""

    def __init__(self) -> None:
        self._calls = 0
        self.candidate_prompts: list[str] = []

    async def stream_turn(self, *, system, messages, tools):
        self._calls += 1
        if messages[-1]["role"] == "user":
            self.candidate_prompts.append(str(messages[-1]["content"]))

        if self._calls == 1:
            yield TurnDone(
                stop_reason="tool_use",
                usage=TokenUsage(input_tokens=9, output_tokens=5),
                tool_calls=[
                    ToolCallChunk(
                        id="edit-homepage",
                        name="write_file",
                        input={
                            "path": "src/homepage_orchestrator.ts",
                            "content": "// candidate-safe concurrent orchestration\n",
                        },
                    )
                ],
                raw_content={
                    "role": "assistant",
                    "content": [],
                    "tool_calls": [
                        {
                            "id": "edit-homepage",
                            "type": "function",
                            "function": {
                                "name": "write_file",
                                "arguments": '{"path":"src/homepage_orchestrator.ts","content":"// candidate-safe concurrent orchestration\\n"}',
                            },
                        }
                    ],
                },
            )
            return

        reply = "Sandbox edit complete." if self._calls == 2 else f"agent reply {self._calls - 1}"
        yield TokenChunk(text=reply)
        yield TurnDone(
            stop_reason="end_turn",
            usage=TokenUsage(input_tokens=8, output_tokens=4),
            tool_calls=[],
            raw_content={"role": "assistant", "content": [{"type": "text", "text": reply}], "tool_calls": []},
        )


def _submission() -> dict:
    return {
        "root_cause_id": "sequential_independent_calls",
        "supporting_evidence_ids": ["homepage_trace", "homepage_orchestrator"],
        "remediation_id": "parallelize_confirmed_independent_calls",
        "expected_impact_id": "lower_p95_preserve_correctness",
        "risk_ids": ["dependency_order"],
        "assumption_ids": ["calls_are_independent"],
        "validation_test_ids": ["correctness_regression", "p95_latency"],
        "rollback_id": "restore_sequential_orchestration",
        "final_confidence": 85,
        "rationale": "The independent calls are sequential; parallelize them while preserving dependencies.",
    }


@pytest.mark.asyncio
async def test_five_turn_runner_creates_sandbox_and_returns_all_score_layers(client, monkeypatch):
    from src.interactive_session import format_three_layer_summary, run_guided_session

    coding_agent = ScriptedCodingAgent([f"agent reply {turn}" for turn in range(1, 6)])
    monkeypatch.setattr(simulation_service, "get_llm", lambda: coding_agent)

    async def fake_cohere_json_once(vendor_cfg, prompt, schema, *, temperature):
        if schema == panel_module._SCORE_SCHEMA:
            return {"score": 4, "justification": "Evidence-led", "cited_event_ids": []}
        if schema == panel_module._NARRATIVE_SCHEMA:
            return {"text": "The candidate iterated on the workspace evidence."}
        if schema == panel_module._QUESTIONS_SCHEMA:
            return {"questions": ["Which calls can safely run concurrently?"]}
        raise AssertionError("Unexpected Cohere response schema")

    monkeypatch.setattr(panel_module, "_cohere_json_once", fake_cohere_json_once)

    output: list[str] = []
    prompts = [
        "Inspect the homepage orchestration.",
        "Read the relevant workspace file.",
        "Explain the latency bottleneck.",
        "Propose a safe change.",
        "Summarize risks and validation.",
        "This sixth prompt must never reach the coding agent.",
    ]

    result = await run_guided_session(
        client,
        display_name="Interactive Test Candidate",
        prompts=prompts,
        submission=_submission(),
        emit=output.append,
    )

    assert result.turns_completed == 5
    assert coding_agent.prompts == prompts[:5]
    assert "src/homepage_orchestrator.ts" in result.sandbox_files
    assert set(result.scripted_tests) == {"correctness_regression", "p95_latency"}
    assert all(test["status"] == "passed" for test in result.scripted_tests.values())
    assert result.report["session"]["completed"] is True
    assert result.report["scores"]["deterministic"]["criteria"]
    assert len(result.report["scores"]["ai_analysis"]["dimensions"]) == 7
    assert result.report["scores"]["context_indices"]["indices"]
    assert any("Sandbox created" in line for line in output)
    assert any("Turn limit reached" in line for line in output)

    summary = format_three_layer_summary(result.report)
    assert "Layer 1 deterministic:" in summary
    assert "Layer 2 Cohere rubric:" in summary
    assert "Layer 3 context indices:" in summary


@pytest.mark.asyncio
async def test_prompt_reader_waits_for_each_streamed_agent_reply_and_shows_the_problem(client, monkeypatch):
    """The interactive runner must alternate candidate input and agent output, never queue input."""
    from src.interactive_session import run_guided_session

    coding_agent = ScriptedCodingAgent([f"agent reply {turn}" for turn in range(1, 6)])
    monkeypatch.setattr(simulation_service, "get_llm", lambda: coding_agent)

    async def fake_cohere_json_once(vendor_cfg, prompt, schema, *, temperature):
        if schema == panel_module._SCORE_SCHEMA:
            return {"score": 4, "justification": "Evidence-led", "cited_event_ids": []}
        if schema == panel_module._NARRATIVE_SCHEMA:
            return {"text": "The candidate iterated on the workspace evidence."}
        if schema == panel_module._QUESTIONS_SCHEMA:
            return {"questions": ["Which calls can safely run concurrently?"]}
        raise AssertionError("Unexpected Cohere response schema")

    monkeypatch.setattr(panel_module, "_cohere_json_once", fake_cohere_json_once)

    output: list[str] = []

    def prompt_reader(turn_number: int, total_turns: int) -> str:
        assert total_turns == 5
        # This assertion fails if the runner gathers all prompts before opening the first SSE stream.
        assert coding_agent.prompts == [f"candidate prompt {turn}" for turn in range(1, turn_number)]
        assert any("Homepage Latency Incident" in line for line in output)
        assert any("Assessment capture started" in line for line in output)
        return f"candidate prompt {turn_number}"

    result = await run_guided_session(
        client,
        display_name="Interactive Test Candidate",
        prompt_reader=prompt_reader,
        submission=_submission(),
        emit=output.append,
    )

    assert result.turns_completed == 5
    assert coding_agent.prompts == [f"candidate prompt {turn}" for turn in range(1, 6)]
    assert sum("Agent feedback: agent reply" in line for line in output) == 5
    assert any("Scoring and grading complete" in line for line in output)


@pytest.mark.asyncio
async def test_five_turn_runner_persists_a_streamed_sandbox_edit_before_scoring(client, monkeypatch):
    from src.interactive_session import run_guided_session

    coding_agent = SandboxEditingAgent()
    monkeypatch.setattr(simulation_service, "get_llm", lambda: coding_agent)

    async def fake_cohere_json_once(vendor_cfg, prompt, schema, *, temperature):
        if schema == panel_module._SCORE_SCHEMA:
            return {"score": 4, "justification": "Evidence-led", "cited_event_ids": []}
        if schema == panel_module._NARRATIVE_SCHEMA:
            return {"text": "The candidate reviewed the sandbox edit."}
        if schema == panel_module._QUESTIONS_SCHEMA:
            return {"questions": ["How did you validate the concurrent calls?"]}
        raise AssertionError("Unexpected Cohere response schema")

    monkeypatch.setattr(panel_module, "_cohere_json_once", fake_cohere_json_once)
    output: list[str] = []
    prompts = [f"candidate prompt {turn}" for turn in range(1, 6)]

    result = await run_guided_session(
        client,
        display_name="Interactive Test Candidate",
        prompts=prompts,
        submission=_submission(),
        emit=output.append,
    )

    workspace_file = await client.get(f"/api/sessions/{result.session_id}/files/src/homepage_orchestrator.ts")
    assert workspace_file.status_code == 200
    assert workspace_file.json()["source"] == "ai"
    assert workspace_file.json()["content"] == "// candidate-safe concurrent orchestration\n"
    assert coding_agent.candidate_prompts == prompts
    assert any("sandbox updated: src/homepage_orchestrator.ts" in line for line in output)
    assert result.report["session"]["completed"] is True
