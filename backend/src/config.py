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
    scenario_data_dir: Path = Path(__file__).resolve().parent.parent / "data" / "scenarios"
    # Virtual Workspace seed apps: one directory per scenario_id, each with a _manifest.json.
    workspace_data_dir: Path = Path(__file__).resolve().parent.parent / "data" / "workspaces"
    default_scenario_id: str = "homepage_latency"
    default_scenario_version: str = "1.0.0"

    # --- Cohere Command A+ (simulation + primary grading panel) ---
    cohere_api_key: str | None = None
    cohere_model: str = "command-a-plus-05-2026"
    sim_max_tokens: int = 1024
    sim_temperature: float = 0.2

    # --- Candidate chat provider (Gemini) ---
    gemini_api_key: str | None = None
    gemini_chat_model: str = "gemini-2.5-flash-lite"

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
