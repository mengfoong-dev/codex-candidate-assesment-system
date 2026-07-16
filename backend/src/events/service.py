"""POST /sessions/{id}/events service — the anti-forgery gate (Codex HIGH finding #2).

Four layers, each closing a way a candidate could fabricate progress:
  1. whitelist       — event_type must be one of FRONTEND_EVENT_TYPES (also rejects backend-only
                        types like ai_response_received, which a candidate could otherwise forge).
  2. typed shape      — the matching Pydantic payload model (schemas.FRONTEND_PAYLOAD_MODELS).
  3. ID membership    — every artifact/hypothesis/response/option ID must exist in the scenario
                        (registry.validate_event_ids); a fabricated ID fails closed.
  4. state checks     — dispositioning a response the session never saw, or resubmitting a
                        hypothesis version that doesn't move forward, are rejected even though
                        they're shape- and ID-valid.
Only after all four pass does this hand off to append_event, the single writer for the log.
"""
from pydantic import ValidationError

from src.event_log import append_event, load_events
from src.exceptions import AppError
from src.registry import Scenario, validate_event_ids
from src.schemas import FRONTEND_EVENT_TYPES, FRONTEND_PAYLOAD_MODELS


async def record_frontend_event(
    db, *, session_id: str, scenario: Scenario, event_type: str, payload: dict
):
    if event_type not in FRONTEND_EVENT_TYPES:
        raise AppError(
            "event_type_not_allowed", f"Event type not allowed from the frontend: {event_type!r}", 422
        )

    model = FRONTEND_PAYLOAD_MODELS[event_type]
    try:
        validated_dict = model.model_validate(payload).model_dump()
    except ValidationError as exc:
        raise AppError("invalid_payload", "Payload failed validation", 422, details=exc.errors()) from exc

    id_errors = validate_event_ids(scenario, event_type, validated_dict)
    if id_errors:
        raise AppError(
            "invalid_event_ids", "Payload references unknown scenario IDs", 422, details=id_errors
        )

    if event_type == "ai_suggestion_dispositioned":
        response_id = validated_dict["response_id"]
        history = await load_events(db, session_id)
        seen = any(
            e["event_type"] == "ai_response_received" and e["payload"].get("response_id") == response_id
            for e in history
        )
        if not seen:
            raise AppError(
                "response_not_seen",
                f"response_id {response_id!r} was not seen in this session",
                422,
            )

    if event_type == "hypothesis_revised":
        history = await load_events(db, session_id)
        max_version = 0
        for e in history:
            if e["event_type"] in ("hypothesis_recorded", "hypothesis_revised"):
                max_version = max(max_version, e["payload"].get("version", 0))
        if validated_dict["version"] <= max_version:
            raise AppError(
                "stale_hypothesis_version",
                f"version {validated_dict['version']} must exceed the current max ({max_version})",
                422,
            )

    return await append_event(
        db,
        session_id=session_id,
        scenario_id=scenario.scenario_id,
        scenario_version=scenario.version,
        event_type=event_type,
        payload=validated_dict,
        actor="candidate",
    )
