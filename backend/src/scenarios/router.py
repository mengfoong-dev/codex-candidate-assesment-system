"""GET /scenarios — the candidate-safe scenario catalog (no session required).

Candidate-safe redaction (scoring config, results_by_remediation) already happens inside
list_public_scenarios(); this route is a thin pass-through by design.
"""
from fastapi import APIRouter

from src.registry import list_public_scenarios

router = APIRouter(tags=["scenarios"])


@router.get("/scenarios")
async def get_scenarios() -> list[dict]:
    return list_public_scenarios()
