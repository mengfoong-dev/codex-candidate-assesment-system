"""FROZEN scenario registry — the single source of truth the whole backend consumes.

Codex HIGH finding #1: the backend must NOT re-type criterion IDs/points/dimensions. It reads them
from the scenario JSON (`scoring.criteria`). The detection *predicates* are the only backend logic
(they live in evaluation/rules.py). Everything ID-shaped — artifacts, hypotheses, dispositions,
tests, submission options, scoring criteria — is validated against the sets exposed here.

Source of truth: config.scenario_data_dir prefers the shared Godot copy
(apps/incident-room/data/scenarios) when the checkout has it, falling back to the bundled backend
mirror for standalone deploys. The two are no longer required to be byte-identical — the mirror is a
deploy fallback that may lag. Purely backend-side policy the Godot JSON never had — relevant-evidence
tags, seeded workspace files, the Layer-2 rubric — lives here as code, layered on top.
"""
import json
from functools import lru_cache
from pathlib import Path, PurePosixPath

from src.config import get_settings
from src.models import Scenario as ScenarioRow

settings = get_settings()

_KEY = f"{settings.default_scenario_id}:{settings.default_scenario_version}"

# --- Backend-only extensions (brief 03 §extensions; not present in the shared Godot JSON) ---

# EC rule (brief 04): the pre-tagged relevant-evidence set for premature-closure detection.
RELEVANT_ARTIFACT_IDS: dict[str, list[str]] = {
    _KEY: ["metrics_overview", "homepage_trace", "homepage_orchestrator"],
}

# Virtual Workspace seed (decision B4): the faulty app the candidate/AI investigates. Stored on
# disk under workspace_data_dir/<scenario_id>/ with a _manifest.json declaring each file's POSIX
# path + a neutral role label. We LOAD the manifest-declared paths (never os.walk), so DB keys stay
# forward-slash on any OS — a raw walk on Windows would seed backslash keys and re-break read_file's
# exact-match (session_id, path) lookup. The manifest's role labels feed the system-prompt file
# manifest (the model's only discovery channel, since Cohere is not given list_files).
@lru_cache
def _load_workspace(scenario_id: str) -> tuple[dict, ...]:
    base = settings.workspace_data_dir / scenario_id
    manifest_path = base / "_manifest.json"
    if not manifest_path.exists():
        return ()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files: list[dict] = []
    for entry in manifest["files"]:
        rel = PurePosixPath(entry["path"]).as_posix()
        content = (base / rel).read_text(encoding="utf-8")
        files.append({"path": rel, "content": content, "role": entry["role"]})
    return tuple(files)

DURATION_MINUTES: dict[str, int] = {_KEY: 30}

# Layer 2 rubric (brief 04): scored 1-5 dimensions with 1/3/5 anchors, plus one narrative dimension.
RUBRIC_VERSION = "rubric_v1"
RUBRIC_DIMENSIONS: list[dict] = [
    {"dimension": "problem_framing", "anchors": {1: "restates the symptom number", 3: "separates symptom from constraint", 5: "frames symptoms, constraints, and success criteria before investigating"}},
    {"dimension": "investigation_strategy", "anchors": {1: "random panel-opening", 3: "mostly purposeful sequence", 5: "each evidence choice follows from the previous finding (eliminate-the-healthy-first)"}},
    {"dimension": "hypothesis_quality", "anchors": {1: "unsupported leap to a cause", 3: "plausible but untested", 5: "plausible, testable, explicitly tied to observed evidence"}},
    {"dimension": "evidence_use", "anchors": {1: "lists observations", 3: "links some evidence to the diagnosis", 5: "builds a connected chain: trace + code + metrics -> conclusion"}},
    {"dimension": "prompt_precision", "anchors": {1: "vague 'fix this' prompts", 3: "some context given", 5: "context-rich prompts with explicit constraints and expected form"}},
    {"dimension": "problem_decomposition", "anchors": {1: "one monolithic ask", 3: "partial breakdown", 5: "goal decomposed into 3-5 verifiable sub-asks"}},
    {"dimension": "communication_clarity", "anchors": {1: "conclusion without reasoning", 3: "reasoning without risks", 5: "evidence, risks, uncertainty, and rollback explained for a non-author reader"}},
]
NARRATIVE_DIMENSION = "thinking_style"  # never scored — a 3-5 sentence style description

# Candidate-safe redaction: these never leave the API or reach the simulation assistant's context.
_HIDDEN_TOP_LEVEL_KEYS = ("scoring",)          # scoring config
_HIDDEN_TEST_KEYS = ("results_by_remediation",) # reveals which remediation passes = the answer


class Scenario:
    """Wraps one scenario definition dict with validated ID sets and a candidate-safe view."""

    def __init__(self, definition: dict):
        self.definition = definition

    @property
    def scenario_id(self) -> str:
        return self.definition["scenario_id"]

    @property
    def version(self) -> str:
        return self.definition["scenario_version"]

    @property
    def key(self) -> str:
        return f"{self.scenario_id}:{self.version}"

    # --- ID sets used for anti-forgery validation (finding #2) ---
    @property
    def artifact_ids(self) -> set[str]:
        return {a["artifact_id"] for a in self.definition["artifacts"]}

    @property
    def evidence_type_by_artifact(self) -> dict[str, str]:
        return {a["artifact_id"]: a["evidence_type"] for a in self.definition["artifacts"]}

    @property
    def fact_ids(self) -> set[str]:
        return {f["fact_id"] for a in self.definition["artifacts"] for f in a.get("facts", [])}

    @property
    def hypothesis_ids(self) -> set[str]:
        return {h["hypothesis_id"] for h in self.definition["hypotheses"]}

    @property
    def dispositions(self) -> dict[str, dict]:
        return {d["option_id"]: d for d in self.definition["ai_interaction"]["dispositions"]}

    @property
    def response_ids(self) -> set[str]:
        return {self.definition["ai_interaction"]["response"]["response_id"]}

    @property
    def test_ids(self) -> set[str]:
        return {t["test_id"] for t in self.definition["tests"]}

    @property
    def submission_options(self) -> dict[str, set[str]]:
        opts = self.definition["submission_options"]
        return {
            "root_cause_id": {o["option_id"] for o in opts["root_causes"]},
            "remediation_id": {o["option_id"] for o in opts["remediations"]},
            "expected_impact_id": {o["option_id"] for o in opts["expected_impacts"]},
            "risk_ids": {o["option_id"] for o in opts["risks"]},
            "assumption_ids": {o["option_id"] for o in opts["assumptions"]},
            "rollback_id": {o["option_id"] for o in opts["rollbacks"]},
        }

    @property
    def required_validation_test_ids(self) -> set[str]:
        return set(self.definition["submission_options"]["required_validation_test_ids"])

    # --- scoring (finding #1: read, don't re-type) ---
    @property
    def criteria(self) -> list[dict]:
        return self.definition["scoring"]["criteria"]

    @property
    def relevant_artifact_ids(self) -> list[str]:
        return RELEVANT_ARTIFACT_IDS.get(self.key, [])

    @property
    def seeded_files(self) -> list[dict]:
        # Fresh dict copies so callers never mutate the lru_cache'd tuple. Each item: path, content, role.
        return [dict(f) for f in _load_workspace(self.scenario_id)]

    def results_by_remediation(self, test_id: str, remediation_id: str) -> dict | None:
        for t in self.definition["tests"]:
            if t["test_id"] == test_id:
                return t.get("results_by_remediation", {}).get(remediation_id)
        return None

    # --- candidate-safe view (redaction anti-cheat) ---
    def candidate_safe_view(self) -> dict:
        d = json.loads(json.dumps(self.definition))  # deep copy
        for k in _HIDDEN_TOP_LEVEL_KEYS:
            d.pop(k, None)
        for t in d.get("tests", []):
            for k in _HIDDEN_TEST_KEYS:
                t.pop(k, None)
        d["duration_minutes"] = DURATION_MINUTES.get(self.key, 30)
        return d


# --- loading / caching -------------------------------------------------------

@lru_cache
def _load_all() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for path in sorted(settings.scenario_data_dir.glob("*.json")):
        definition = json.loads(path.read_text(encoding="utf-8"))
        out[f"{definition['scenario_id']}:{definition['scenario_version']}"] = definition
    return out


def get_scenario(scenario_id: str, version: str) -> Scenario:
    definition = _load_all().get(f"{scenario_id}:{version}")
    if definition is None:
        from src.exceptions import AppError

        raise AppError("scenario_not_found", f"Unknown scenario {scenario_id}@{version}", 404)
    return Scenario(definition)


def get_default_scenario() -> Scenario:
    return get_scenario(settings.default_scenario_id, settings.default_scenario_version)


def list_public_scenarios() -> list[dict]:
    """Candidate-safe list view for GET /api/scenarios."""
    out = []
    for definition in _load_all().values():
        s = Scenario(definition)
        out.append(
            {
                "scenario_id": s.scenario_id,
                "version": s.version,
                "title": definition["title"],
                "role": definition["role"],
                "duration_minutes": DURATION_MINUTES.get(s.key, 30),
            }
        )
    return out


# --- validation helpers (consumed by events/sessions services) ---------------

def validate_event_ids(scenario: Scenario, event_type: str, payload: dict) -> list[str]:
    """Return human-readable errors for any ID in `payload` not defined by the scenario. Empty = ok.
    Shape (types/ranges) is validated separately by the Pydantic payload models in schemas.py."""
    errors: list[str] = []
    valid_refs = scenario.artifact_ids | scenario.fact_ids

    if event_type == "evidence_viewed":
        if payload.get("artifact_id") not in scenario.artifact_ids:
            errors.append(f"unknown artifact_id: {payload.get('artifact_id')!r}")
    elif event_type in ("hypothesis_recorded", "hypothesis_revised"):
        if payload.get("hypothesis_id") not in scenario.hypothesis_ids:
            errors.append(f"unknown hypothesis_id: {payload.get('hypothesis_id')!r}")
        for ref in payload.get("trigger_evidence_ids", []):
            if ref not in valid_refs:
                errors.append(f"unknown trigger_evidence_id: {ref!r}")
    elif event_type == "ai_suggestion_dispositioned":
        if payload.get("response_id") not in scenario.response_ids:
            errors.append(f"unknown response_id: {payload.get('response_id')!r}")
        if payload.get("option_id") not in scenario.dispositions:
            errors.append(f"unknown disposition option_id: {payload.get('option_id')!r}")
    return errors


def validate_submission(scenario: Scenario, submission: dict) -> list[str]:
    """Validate a final_submission against the scenario's option sets (single-value + list fields)."""
    errors: list[str] = []
    opts = scenario.submission_options
    # Slim form: only root cause + remediation are required.
    for field in ("root_cause_id", "remediation_id"):
        val = submission.get(field)
        if val not in opts[field]:
            errors.append(f"invalid {field}: {val!r}")
    # Optional legacy single-value fields: validate only when actually provided.
    for field in ("expected_impact_id", "rollback_id"):
        val = submission.get(field)
        if val and val not in opts[field]:
            errors.append(f"invalid {field}: {val!r}")
    for field in ("risk_ids", "assumption_ids"):
        for val in submission.get(field) or []:
            if val not in opts[field]:
                errors.append(f"invalid {field} entry: {val!r}")
    for val in submission.get("validation_test_ids") or []:
        if val not in scenario.test_ids:
            errors.append(f"invalid validation_test_id: {val!r}")
    for val in submission.get("supporting_evidence_ids") or []:
        if val not in (scenario.artifact_ids | scenario.fact_ids):
            errors.append(f"invalid supporting_evidence_id: {val!r}")
    return errors


# --- seeding + sync check ----------------------------------------------------

async def seed_scenarios(db) -> None:
    """Idempotent startup seed: insert any scenario file not already in the scenarios table."""
    for definition in _load_all().values():
        sid, ver = definition["scenario_id"], definition["scenario_version"]
        if await db.get(ScenarioRow, (sid, ver)) is None:
            db.add(ScenarioRow(scenario_id=sid, version=ver, definition=json.dumps(definition)))
    await db.commit()
