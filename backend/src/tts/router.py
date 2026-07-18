"""Text-to-speech proxy so Sam (the senior) can speak his replies in-game.

Keeps the ElevenLabs key server-side: the Godot web client POSTs the reply text and gets back
audio/mpeg, never a secret. Best-effort — if TTS is unconfigured or ElevenLabs errors, we return
204 (silence) so the dialogue is never blocked by a failed voice call.
"""
import httpx
from fastapi import APIRouter, Response
from pydantic import BaseModel

from src.config import get_settings

router = APIRouter()

_ELEVEN_TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
_MAX_CHARS = 800  # Sam's replies are 1-2 sentences; cap so a runaway reply can't rack up TTS cost.


class TTSRequest(BaseModel):
    text: str


@router.post("/tts")
async def synthesize(body: TTSRequest) -> Response:
    settings = get_settings()
    text = body.text.strip()
    if not settings.elevenlabs_api_key or not text:
        return Response(status_code=204)  # not configured / nothing to say -> silence
    url = _ELEVEN_TTS_URL.format(voice_id=settings.elevenlabs_voice_id)
    payload = {"text": text[:_MAX_CHARS], "model_id": "eleven_flash_v2_5"}
    headers = {"xi-api-key": settings.elevenlabs_api_key, "Content-Type": "application/json"}
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(url, headers=headers, json=payload)
    except httpx.HTTPError:
        return Response(status_code=204)
    if r.status_code != 200:
        return Response(status_code=204)  # best-effort: a voice failure must not break the chat
    return Response(content=r.content, media_type="audio/mpeg")
