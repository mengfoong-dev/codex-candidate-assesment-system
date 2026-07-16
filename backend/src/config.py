"""Application settings, loaded from environment / .env via pydantic-settings.

Why pydantic-settings over os.getenv: it validates types (int/list/bool) at startup and gives
one typed object instead of scattered string lookups — a misconfigured value fails loudly on
boot, not mid-request.
"""
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", case_sensitive=False
    )

    # --- HTTP / CORS ---
    cors_origins: list[str] = ["http://localhost:5173", "http://localhost:3000"]

    # --- Database (Postgres later = swap this string only, per decision B5) ---
    database_url: str = "sqlite+aiosqlite:///./vibeproof.db"

    # --- Scenario data ---
    scenario_data_dir: Path = Path(__file__).resolve().parent.parent / "data" / "scenarios"
    default_scenario_id: str = "homepage_latency"
    default_scenario_version: str = "1.0.0"

    # --- Simulation Engine (Anthropic Sonnet) ---
    anthropic_api_key: str | None = None
    # Model ID is config, not a hard-coded constant (Codex MEDIUM finding). Startup health-check
    # in the simulation engine validates it and records the resolved label on each response event.
    sim_model: str = "claude-sonnet-5"
    sim_max_tokens: int = 1024
    sim_temperature: float = 0.2

    # --- Candidate chat provider (Gemini) ---
    gemini_api_key: str | None = None
    gemini_chat_model: str = "gemini-2.5-flash-lite"

    # --- Grading panel: Groq + NVIDIA NIM, both OpenAI-compatible (one client, base-URL swap) ---
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
