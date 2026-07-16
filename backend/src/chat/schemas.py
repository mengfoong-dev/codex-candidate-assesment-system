"""Request/response models for the candidate prompting chat endpoint."""

from pydantic import BaseModel, ConfigDict, Field


class ChatRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    sessionId: str = Field(min_length=1)
    message: str = Field(min_length=1)

    @property
    def session_id(self) -> str:
        return self.sessionId


class ChatResponse(BaseModel):
    reply: str
