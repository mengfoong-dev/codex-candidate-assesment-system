"""HTTP route for the candidate prompting MVP chat endpoint."""

from fastapi import APIRouter

from src.chat.schemas import ChatRequest, ChatResponse
from src.chat.service import generate_reply

router = APIRouter(tags=["chat"])


@router.post(
    "/chat",
    response_model=ChatResponse,
    responses={
        400: {"description": "Invalid chat request"},
        500: {"description": "Unexpected backend failure"},
        502: {"description": "Upstream AI provider failure"},
    },
)
async def post_chat(body: ChatRequest) -> ChatResponse:
    reply = await generate_reply(session_id=body.session_id, message=body.message)
    return ChatResponse(reply=reply)
