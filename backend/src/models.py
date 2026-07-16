"""The 5 tables (design doc data model). Kept in one module per brief 03 — they form one tight
aggregate (scenarios → sessions → events/session_files/scoring_results) and are always used
together. JSON columns are TEXT holding json.dumps(...) strings (SQLite has no native JSON type
we need here; the service layer (de)serializes)."""
from sqlalchemy import Float, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from src.database import Base


class Scenario(Base):
    __tablename__ = "scenarios"
    # Composite PK: scenario versions must coexist without disturbing prior sessions' history.
    scenario_id: Mapped[str] = mapped_column(String, primary_key=True)
    version: Mapped[str] = mapped_column(String, primary_key=True)
    definition: Mapped[str] = mapped_column(Text)  # full scenario JSON document


class Session(Base):
    __tablename__ = "sessions"
    id: Mapped[str] = mapped_column(String, primary_key=True)  # UUID4
    scenario_id: Mapped[str] = mapped_column(String)
    scenario_version: Mapped[str] = mapped_column(String)
    display_name: Mapped[str] = mapped_column(String, default="Anonymous")
    status: Mapped[str] = mapped_column(String, default="active")  # active | submitted | graded
    manual_review: Mapped[bool] = mapped_column(default=False)     # grading crashed / both graders down
    started_at: Mapped[str] = mapped_column(String)               # ISO-8601 UTC
    submitted_at: Mapped[str | None] = mapped_column(String, nullable=True)


class Event(Base):
    """Append-only source of truth. No UPDATE/DELETE exists for this table anywhere (brief 03)."""
    __tablename__ = "events"
    event_id: Mapped[str] = mapped_column(String, primary_key=True)          # "<session_id>:000042"
    session_id: Mapped[str] = mapped_column(String, index=True)
    sequence: Mapped[int] = mapped_column(Integer)
    event_schema_version: Mapped[str] = mapped_column(String, default="1.0.0")
    scenario_id: Mapped[str] = mapped_column(String)
    scenario_version: Mapped[str] = mapped_column(String)
    event_type: Mapped[str] = mapped_column(String, index=True)
    actor: Mapped[str] = mapped_column(String)                                # candidate | system | scripted_assistant
    occurred_at: Mapped[str] = mapped_column(String)
    elapsed_active_ms: Mapped[int] = mapped_column(Integer, default=0)
    payload: Mapped[str] = mapped_column(Text, default="{}")                  # JSON
    # Sequence uniqueness per session is the hard backstop for the concurrency lock (finding #5).
    __table_args__ = (UniqueConstraint("session_id", "sequence"),)


class SessionFile(Base):
    """Virtual Workspace = DB rows (decision B4). Nothing ever executes."""
    __tablename__ = "session_files"
    session_id: Mapped[str] = mapped_column(String, primary_key=True)
    path: Mapped[str] = mapped_column(String, primary_key=True)
    content: Mapped[str] = mapped_column(Text)
    source: Mapped[str] = mapped_column(String)   # seeded | ai | user
    updated_at: Mapped[str] = mapped_column(String)


class ScoringResult(Base):
    """One row per criterion × layer; written once at submit. Re-grade rewrites only these rows."""
    __tablename__ = "scoring_results"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(String, index=True)
    layer: Mapped[str] = mapped_column(String)             # deterministic | llm_rubric | context_index
    criterion_id: Mapped[str] = mapped_column(String)
    dimension: Mapped[str | None] = mapped_column(String, nullable=True)
    value: Mapped[float] = mapped_column(Float)
    max_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    evidence_refs: Mapped[str] = mapped_column(Text, default="[]")   # JSON list of event IDs
    grader_label: Mapped[str] = mapped_column(String)               # rules_v1 | vendor/model
    rubric_version: Mapped[str | None] = mapped_column(String, nullable=True)
    detail: Mapped[str] = mapped_column(Text, default="{}")          # JSON: justification/formula/inputs/flags
