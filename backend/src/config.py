"""Application settings, loaded from environment / .env via pydantic-settings.

Why pydantic-settings over os.getenv: it validates types (int/list/bool) at startup and gives
one typed object instead of scattered string lookups — a misconfigured value fails loudly on
boot, not mid-request.
"""
import json
from functools import lru_cache
from pathlib import Path
from typing import Annotated

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


# The scenario JSON has a single source of truth: the Godot copy the candidate actually sees
# (apps/incident-room/data/scenarios). We prefer it when the checkout has it, and fall back to the
# bundled backend mirror for standalone deploys (Railway service root = backend/, where the sibling
# app dir is absent from the build context). SCENARIO_DATA_DIR env still overrides either default.
_GODOT_SCENARIOS = Path(__file__).resolve().parents[2] / "apps" / "incident-room" / "data" / "scenarios"
_BACKEND_SCENARIOS = Path(__file__).resolve().parent.parent / "data" / "scenarios"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", case_sensitive=False
    )

    # --- HTTP / CORS ---
    # NoDecode: parse the raw env string ourselves so a misquoted value (comma-separated,
    # or "[https://a]" with the quotes stripped by a shell/CLI) can't crash startup.
    cors_origins: Annotated[list[str], NoDecode] = ["http://localhost:5173", "http://localhost:3000"]

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _parse_cors_origins(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        text = value.strip()
        if not text:
            return []
        try:
            parsed = json.loads(text)
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
            text = str(parsed)
        except (json.JSONDecodeError, ValueError):
            pass
        text = text.strip().lstrip("[").rstrip("]")
        return [part.strip().strip('"').strip("'") for part in text.split(",") if part.strip()]

    # --- Database (Postgres later = swap this string only, per decision B5) ---
    database_url: str = "sqlite+aiosqlite:///./vibeproof.db"

    # --- Scenario data ---
    scenario_data_dir: Path = _GODOT_SCENARIOS if _GODOT_SCENARIOS.exists() else _BACKEND_SCENARIOS
    # Virtual Workspace seed apps: one directory per scenario_id, each with a _manifest.json.
    workspace_data_dir: Path = Path(__file__).resolve().parent.parent / "data" / "workspaces"
    default_scenario_id: str = "homepage_latency"
    default_scenario_version: str = "1.0.0"

    # --- Workspace backend (ADR 0001 — opt-in override of decision D006 "nothing executes") ---
    # "db" (default): Virtual Workspace = session_files rows, no code ever runs (D006 intact — this
    #   is what the web MVP always uses). "fs": a real per-session directory on disk where the AI's
    #   write_file lands as a real file and `run test` runs a real `vitest run`. Only the local
    #   interactive CLI sets this; leaving it unset keeps production behavior byte-for-byte.
    workspace_backend: str = "db"
    # Where the on-disk sandboxes live when workspace_backend="fs". None -> a stable folder under
    # the OS temp dir, so the Node toolchain is installed once and reused across CLI runs.
    workspace_sandbox_root: Path | None = None

    # --- Cohere Command A+ (simulation + primary grading panel) ---
    cohere_api_key: str | None = None
    cohere_model: str = "command-a-plus-05-2026"
    sim_max_tokens: int = 1024
    sim_temperature: float = 0.2

    # --- Opt-in grading fallback: Groq + NVIDIA NIM, both OpenAI-compatible ---
    ai_panel_fallback_enabled: bool = False
    groq_api_key: str | None = None
    groq_base_url: str = "https://api.groq.com/openai/v1"
    groq_grader_model: str = "llama-3.3-70b-versatile"
    nim_api_key: str | None = None
    nim_base_url: str = "https://integrate.api.nvidia.com/v1"
    nim_grader_model: str = "meta/llama-3.1-70b-instruct"


@lru_cache
def get_settings() -> Settings:
    """Cached singleton — Settings reads the env once; every caller shares the same object."""
    return Settings()
