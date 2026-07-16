"""The Virtual Workspace tool surface (brief 02): list_files/read_file/write_file over
`session_files` rows for one session. Nothing here ever executes — these are plain DB reads
and an upsert (decision D006). `service.py` owns the tool-loop, SSE emission, and event
recording; this module is pure DB I/O plus the Anthropic tool schemas that describe it.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.event_log import now_iso
from src.models import SessionFile

# Anthropic tool definitions (brief 02: the whole "codex" surface — no delete, no execute,
# no network tool). Passed straight through to `tools=` on the Messages API.
TOOL_SCHEMAS: list[dict] = [
    {
        "name": "list_files",
        "description": (
            "List every file currently in the candidate's Virtual Workspace, with its path "
            "and source (seeded/ai/user)."
        ),
        "input_schema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "read_file",
        "description": "Read the full content of one file in the candidate's Virtual Workspace by path.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path, e.g. src/homepage_orchestrator.ts"}
            },
            "required": ["path"],
            "additionalProperties": False,
        },
    },
    {
        "name": "write_file",
        "description": (
            "Write (create or overwrite) a file in the candidate's Virtual Workspace. Nothing "
            "executes — this only updates the stored file content."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "The file path to write."},
                "content": {"type": "string", "description": "The full new content of the file."},
            },
            "required": ["path", "content"],
            "additionalProperties": False,
        },
    },
]


async def list_files(db: AsyncSession, session_id: str) -> str:
    result = await db.execute(select(SessionFile).where(SessionFile.session_id == session_id))
    files = result.scalars().all()
    if not files:
        return "No files in the workspace."
    return "\n".join(f"{f.path} (source={f.source})" for f in files)


async def read_file(db: AsyncSession, session_id: str, path: str) -> str:
    file = await db.get(SessionFile, (session_id, path))
    if file is None:
        return f"File not found: {path}"
    return file.content


async def write_file(db: AsyncSession, session_id: str, path: str, content: str) -> SessionFile:
    """Upsert with source='ai' (decision B4/brief 03: session_files rows mutated only by the
    Simulation Engine's write_file or an explicit candidate save). Caller (service.py) emits
    the SSE `file_updated` event and records the write in `ai_response_received.payload`."""
    file = await db.get(SessionFile, (session_id, path))
    if file is None:
        file = SessionFile(session_id=session_id, path=path, content=content, source="ai", updated_at=now_iso())
        db.add(file)
    else:
        file.content = content
        file.source = "ai"
        file.updated_at = now_iso()
    await db.commit()
    return file
