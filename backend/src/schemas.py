"""Shared Pydantic models: the event envelope + one typed payload model per event type.

Codex HIGH finding #2: `POST /events` must not accept an arbitrary JSON blob. Each event type has a
typed payload model here (shape/range validation); registry.validate_event_ids adds membership
validation; the events service adds state validation (version monotonicity, post-submit rejection).
Together those three layers make a fabricated event fail closed.

Actor + event-type vocabulary is frozen (evidence-and-scoring.md). `decision_recorded` and
`tool_invoked` are restored here (finding #2 noted they were missing): decision_recorded is a
candidate action referenced by the trace rule; tool_invoked is recorded by the Simulation Engine.
"""
from typing import Literal

from pydantic import BaseModel, Field

# --- vocabulary ---
Actor = Literal["candidate", "system", "scripted_assistant"]

FRONTEND_EVENT_TYPES: frozenset[str] = frozenset(
    {
        "evidence_viewed",
        "hypothesis_recorded",
        "hypothesis_revised",
        "search_performed",
        "ai_suggestion_dispositioned",
        "decision_recorded",  # candidate judgment; establishes the change boundary for rule 1
        "candidate_ai_prompt",  # raw prompt text the candidate sent the AI copilot; feeds the Layer-2 rubric
        "station_visited",  # Layer-3 CONTEXT only (D009) — which investigation station the candidate opened
        "candidate_senior_question",  # raw prompt text to the in-scenario senior engineer; parallels candidate_ai_prompt
    }
)

BACKEND_EVENT_TYPES: frozenset[str] = frozenset(
    {
        "assessment_opened",
        "ai_prompt_submitted",
        "ai_response_received",
        "tool_invoked",       # Simulation Engine file-tool calls
        "test_executed",
        "final_submission",
        "technical_error",
    }
)


# --- envelope (stored form; also the /events 201 response) ---
class EventEnvelope(BaseModel):
    event_schema_version: str = "1.0.0"
    event_id: str
    session_id: str
    sequence: int
    scenario_id: str
    scenario_version: str
    event_type: str
    actor: Actor
    occurred_at: str
    elapsed_active_ms: int = 0
    payload: dict


# --- frontend-reported payloads (typed) ---
class EvidenceViewedPayload(BaseModel):
    artifact_id: str
    # Optional Godot-side context (which station/evidence-type it was viewed from). Layer-3 CONTEXT
    # only — artifact_id is still the sole field validate_event_ids checks against the scenario.
    station_id: str | None = None
    evidence_type: str | None = None


class HypothesisRecordedPayload(BaseModel):
    version: int = Field(ge=1)
    hypothesis_id: str
    confidence: int = Field(ge=0, le=100)
    trigger_evidence_ids: list[str] = []


class HypothesisRevisedPayload(BaseModel):
    previous_version: int = Field(ge=1)
    version: int = Field(ge=2)
    hypothesis_id: str
    confidence: int = Field(ge=0, le=100)
    # Non-empty trigger is what rule 6 (revised_after_contradiction) keys on.
    trigger_evidence_ids: list[str] = Field(min_length=1)


class SearchPerformedPayload(BaseModel):
    query: str
    scope: str | None = None
    result_count: int = Field(ge=0, default=0)


class AiSuggestionDispositionedPayload(BaseModel):
    response_id: str
    option_id: str  # accept_immediately | verify_then_adapt | reject_suggestion (validated vs scenario)


class DecisionRecordedPayload(BaseModel):
    action: str
    rationale: str
    risk: str | None = None


class CandidateAiPromptPayload(BaseModel):
    # The candidate's raw free-text prompt to the AI copilot. Not scored deterministically (carries no
    # scenario IDs), but the Layer-2 rubric reads it to judge prompt_precision / problem_decomposition.
    text: str


class StationVisitedPayload(BaseModel):
    # Godot presentation layer only: which investigation station the candidate walked into. Carries no
    # scenario IDs, so validate_event_ids has no branch for it — it is Layer-3 CONTEXT (D009), never scored.
    station_id: str
    station_kind: Literal["investigation", "assistant", "senior", "desk"] = "investigation"
    title: str | None = None


class CandidateSeniorQuestionPayload(BaseModel):
    # The candidate's raw free-text question to the in-scenario senior engineer. Same shape/purpose as
    # CandidateAiPromptPayload, just a different conversational partner for the Layer-2 rubric digest.
    text: str


# event_type -> payload model, for the events service to dispatch typed validation.
FRONTEND_PAYLOAD_MODELS: dict[str, type[BaseModel]] = {
    "evidence_viewed": EvidenceViewedPayload,
    "hypothesis_recorded": HypothesisRecordedPayload,
    "hypothesis_revised": HypothesisRevisedPayload,
    "search_performed": SearchPerformedPayload,
    "ai_suggestion_dispositioned": AiSuggestionDispositionedPayload,
    "candidate_ai_prompt": CandidateAiPromptPayload,
    "decision_recorded": DecisionRecordedPayload,
    "station_visited": StationVisitedPayload,
    "candidate_senior_question": CandidateSeniorQuestionPayload,
}


# --- /events request body ---
class FrontendEventIn(BaseModel):
    event_type: str  # must be in FRONTEND_EVENT_TYPES (checked in service -> 422 with envelope)
    payload: dict = {}


# --- backend-recorded payloads (for the producing engines/services) ---
class TokenUsage(BaseModel):
    input_tokens: int = 0
    output_tokens: int = 0


class AssessmentOpenedPayload(BaseModel):
    scenario_id: str
    scenario_version: str
    attempt: int = 1


class AiPromptSubmittedPayload(BaseModel):
    turn_id: str
    prompt: str
    referenced_context_ids: list[str] = []


class AiResponseReceivedPayload(BaseModel):
    turn_id: str
    response_id: str
    model_label: str
    status: Literal["ok", "error"] = "ok"
    latency_ms: int = 0
    usage: TokenUsage = TokenUsage()
    text: str = ""                       # rendered assistant text — feeds snapshot chat_history
    files_written: list[str] = []        # workspace paths the tool loop wrote this turn


class ToolInvokedPayload(BaseModel):
    turn_id: str
    tool: str
    path: str | None = None
    outcome: str = "ok"


class TestExecutedPayload(BaseModel):
    test_id: str
    remediation_id: str
    expected_result: str
    actual_result: str
    status: Literal["passed", "failed", "unavailable"]


class FinalSubmissionPayload(BaseModel):
    root_cause_id: str
    supporting_evidence_ids: list[str] = []
    remediation_id: str
    expected_impact_id: str
    risk_ids: list[str] = []
    assumption_ids: list[str] = []
    validation_test_ids: list[str] = []
    rollback_id: str
    final_confidence: int = Field(ge=0, le=100)
    rationale: str = ""


class TechnicalErrorPayload(BaseModel):
    source: str                       # e.g. "simulation" | "grading"
    message: str
    excluded_criterion_ids: list[str] = []  # criteria to drop from the Layer-1 max (never penalize outages)
