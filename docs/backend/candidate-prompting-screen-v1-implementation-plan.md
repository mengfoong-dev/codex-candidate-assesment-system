# Candidate Prompting Screen v1 Implementation Plan

## Goal
Implement `POST /api/chat` for the candidate prompting screen MVP.

The endpoint should:
- accept a candidate message and `sessionId`;
- send the message to the project's configured AI provider;
- return the assistant reply as JSON;
- fail cleanly without adding auth, persistence, scoring, replay, or analytics.

## Current Architecture
The backend already provides:
- `src/main.py` for app wiring and router registration;
- `src/config.py` for environment-driven settings;
- `src/exceptions.py` for the shared `{"error": {"code", "message"}}` envelope;
- `src/simulation/service.py` for the existing AI provider seam and Anthropic streaming client;
- `src/sessions/`, `src/events/`, `src/workspace/`, and `src/evaluation/` as separate domain packages.

## Integration Plan
1. Add a thin `src/chat/` domain package for the new endpoint.
2. Reuse the existing AI provider seam from `src.simulation.service` instead of introducing a second provider abstraction.
3. Keep the chat route non-streaming for now and return the complete reply body.
4. Use the existing error envelope and map upstream AI failures to `502`.
5. Map invalid chat input to `400` for this endpoint only.
6. Cover the success, validation, and provider-failure paths with tests.

## Files Expected To Change
- `backend/src/main.py`
- `backend/src/exceptions.py`
- `backend/src/chat/router.py`
- `backend/src/chat/schemas.py`
- `backend/src/chat/service.py`
- `backend/src/chat/__init__.py`
- `backend/tests/test_chat.py`
- `backend/README.md` if the layout summary needs to mention the new domain

## Non-goals
- No streaming response.
- No session persistence.
- No scoring or replay logic.
- No auth or user management.
- No duplicate AI client or parallel backend architecture.
