"""Session lifecycle: create (seed Virtual Workspace + assessment_opened), snapshot (state derived
entirely from the event log — no separate presentation table), and final submission.

Snapshot derivation rules (brief 00): current_hypothesis is the *latest* hypothesis_recorded/revised
event in sequence order (revised versions are validated strictly increasing by the events domain, so
"latest by sequence" and "highest version" agree); viewed_artifact_ids is the distinct set of
evidence_viewed artifact_ids in first-seen order; chat_history interleaves ai_prompt_submitted
(candidate) and ai_response_received (assistant) in sequence order.
"""
from uuid import uuid4

from sqlalchemy import select

from src.config import get_settings
from src.event_log import append_event, load_events, now_iso
from src.event_log import submit_session as commit_final_submission
from src.exceptions import AppError
from src.models import Session, SessionFile
from src.registry import get_scenario, validate_submission
from src.schemas import AssessmentOpenedPayload

settings = get_settings()


async def _load_session(db, session_id: str) -> Session:
    session = await db.get(Session, session_id)
    if session is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    return session


async def create_session(db, *, display_name: str, scenario_id: str | None) -> dict:
    scenario = get_scenario(
        scenario_id or settings.default_scenario_id, settings.default_scenario_version
    )
    session_id = str(uuid4())
    started_at = now_iso()

    db.add(
        Session(
            id=session_id,
            scenario_id=scenario.scenario_id,
            scenario_version=scenario.version,
            display_name=display_name,
            status="active",
            started_at=started_at,
        )
    )

    files_out = []
    for f in scenario.seeded_files:
        db.add(
            SessionFile(
                session_id=session_id,
                path=f["path"],
                content=f["content"],
                source="seeded",
                updated_at=started_at,
            )
        )
        files_out.append({"path": f["path"], "source": "seeded"})
    await db.commit()

    # Recorded through the shared event-log primitive (never a hand-inserted Event row) so sequence
    # allocation and the active-session lock apply uniformly, same as every other domain.
    await append_event(
        db,
        session_id=session_id,
        scenario_id=scenario.scenario_id,
        scenario_version=scenario.version,
        event_type="assessment_opened",
        payload=AssessmentOpenedPayload(
            scenario_id=scenario.scenario_id,
            scenario_version=scenario.version,
            attempt=1,
        ).model_dump(),
        actor="system",
    )

    # ADR 0001: when the on-disk sandbox is enabled (interactive CLI), materialize the same seed
    # files as REAL files on disk so the AI's edits and `run test` operate on a real workspace.
    # Default ("db") backend skips this entirely — D006 behavior is unchanged. Offloaded to a
    # thread because materialize() may run a blocking `npm install` on the first session.
    from src.workspace import sandbox

    if sandbox.enabled():
        import functools

        import anyio

        await anyio.to_thread.run_sync(
            functools.partial(
                sandbox.materialize,
                session_id,
                scenario_id=scenario.scenario_id,
                seeded_files=scenario.seeded_files,
            )
        )

    return {
        "session_id": session_id,
        "scenario": scenario.candidate_safe_view(),
        "files": files_out,
    }


async def get_session_snapshot(db, session_id: str) -> dict:
    session = await _load_session(db, session_id)

    result = await db.execute(select(SessionFile).where(SessionFile.session_id == session_id))
    files = [
        {"path": f.path, "source": f.source, "updated_at": f.updated_at}
        for f in result.scalars().all()
    ]

    events = await load_events(db, session_id)

    current_hypothesis = None
    for e in events:
        if e["event_type"] in ("hypothesis_recorded", "hypothesis_revised"):
            current_hypothesis = {
                "hypothesis_id": e["payload"].get("hypothesis_id"),
                "version": e["payload"].get("version"),
                "confidence": e["payload"].get("confidence"),
            }

    viewed_artifact_ids: list[str] = []
    seen: set[str] = set()
    for e in events:
        if e["event_type"] == "evidence_viewed":
            artifact_id = e["payload"].get("artifact_id")
            if artifact_id and artifact_id not in seen:
                seen.add(artifact_id)
                viewed_artifact_ids.append(artifact_id)

    chat_history: list[dict] = []
    for e in events:
        if e["event_type"] == "ai_prompt_submitted":
            chat_history.append({"role": "candidate", "text": e["payload"].get("prompt", "")})
        elif e["event_type"] == "ai_response_received":
            # Best-effort: AiResponseReceivedPayload (src.schemas) has no "text" field today — see
            # contract-gap note in the implementer report. Falls back to "" until that's resolved.
            chat_history.append({"role": "assistant", "text": e["payload"].get("text", "")})

    return {
        "session_id": session.id,
        "status": session.status,
        "display_name": session.display_name,
        "scenario_id": session.scenario_id,
        "scenario_version": session.scenario_version,
        "current_hypothesis": current_hypothesis,
        "viewed_artifact_ids": viewed_artifact_ids,
        "files": files,
        "chat_history": chat_history,
    }


async def submit_final_submission(db, *, session_id: str, submission: dict) -> dict:
    # Column-only lookup (never hydrates a Session ORM object into this request's identity map).
    # commit_final_submission below re-loads the Session via db.get() under its per-session lock to
    # check status == "active" — if we'd ORM-loaded the row here first, that lock-protected re-check
    # would see this stale cached object instead of re-querying, letting a losing concurrent submit
    # slip past the 409 (Codex HIGH finding #5). See implementer report for the failure this caught.
    result = await db.execute(
        select(Session.scenario_id, Session.scenario_version).where(Session.id == session_id)
    )
    row = result.first()
    if row is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    scenario = get_scenario(row.scenario_id, row.scenario_version)

    errs = validate_submission(scenario, submission)
    if errs:
        raise AppError("invalid_submission", "Submission failed validation", 422, details=errs)

    # Atomic write-final_submission + flip-to-submitted (raises 409 on double submit).
    await commit_final_submission(db, session_id=session_id, submission=submission)

    # Lazy import: evaluation is a sibling domain built in parallel; importing it at module load
    # time would create sessions <-> evaluation circular import and also crash this whole domain's
    # tests before evaluation exists. Any failure here (including evaluation not existing yet)
    # degrades to manual review rather than losing the candidate's submission.
    from src.evaluation.service import run_evaluation

    try:
        await run_evaluation(db, session_id)
        return {"session_id": session_id, "status": "graded"}
    except Exception:
        # First ORM load of this PK on this request's session — fresh by construction, and safe to
        # mutate: this request already won the submit race (commit_final_submission didn't raise),
        # so no other submit on this session_id can still be in flight.
        session = await db.get(Session, session_id)
        session.manual_review = True
        await db.commit()
        return {
            "session_id": session_id,
            "status": "submitted",
            "grading": "failed_pending_manual_review",
        }
