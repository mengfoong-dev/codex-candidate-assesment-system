"""Request/response models for the sessions domain (create, snapshot).

Kept separate from the shared `src.schemas` (event envelope + payload vocabulary, owned by the
lead) since these shapes are specific to the sessions endpoints, not the event log.
"""
from pydantic import BaseModel


class CreateSessionIn(BaseModel):
    display_name: str = "Anonymous"
    scenario_id: str | None = None  # None -> settings.default_scenario_id


class SessionFileRef(BaseModel):
    path: str
    source: str


class CreateSessionOut(BaseModel):
    session_id: str
    scenario: dict  # candidate-safe scenario view (Scenario.candidate_safe_view())
    files: list[SessionFileRef]


class SessionFileSnapshot(BaseModel):
    path: str
    source: str
    updated_at: str


class CurrentHypothesis(BaseModel):
    hypothesis_id: str
    version: int
    confidence: int


class ChatMessage(BaseModel):
    role: str  # "candidate" | "assistant"
    text: str


class SessionSnapshotOut(BaseModel):
    session_id: str
    status: str
    display_name: str
    scenario_id: str
    scenario_version: str
    current_hypothesis: CurrentHypothesis | None
    viewed_artifact_ids: list[str]
    files: list[SessionFileSnapshot]
    chat_history: list[ChatMessage]
