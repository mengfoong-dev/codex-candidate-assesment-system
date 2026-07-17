"""True on-disk sandbox backend for the Virtual Workspace (ADR 0001 — an opt-in override of
decision D006 "nothing ever executes").

Default stays DB-rows: with WORKSPACE_BACKEND unset/"db", `enabled()` is False and nothing here
runs, so the web MVP keeps its D006 behavior byte-for-byte. The interactive CLI sets
WORKSPACE_BACKEND=fs to get a REAL per-session directory on disk: the AI's write_file lands as a
real file, and `run test` runs a real `vitest run` (real test output, not a scripted lookup table).

Isolation model (ADR 0001): a dedicated per-session directory under a sandbox root, path-contained
writes (no ../ escapes), a hard wall-clock timeout on execution, and captured+truncated output.
A single shared node_modules at the sandbox root is discovered by every session dir via Node's
native upward module resolution, so the toolchain installs once, not once per session.

ponytail: no container/seccomp isolation — the executor is the developer running the local CLI
against their own AI/hand edits, so temp-dir + timeout is the right ceiling. Upgrade path if this
ever runs untrusted candidate code server-side: Node 22 `--permission` flags, or a gVisor/
Firecracker microVM sandbox (see the ADR's research note). These functions are intentionally sync;
async callers offload them with anyio.to_thread.run_sync so subprocess.run never blocks the loop.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from src.config import get_settings

# Grading harness (tsconfig + the vitest test). Kept OUT of _manifest.json so it never seeds into
# session_files or list_files — the candidate/AI must not see the test that grades them. Copied
# straight into each sandbox at materialize time.
_HARNESS_DIRNAME = ".harness"
_TEST_TIMEOUT_SECONDS = 120
_INSTALL_TIMEOUT_SECONDS = 600
_MAX_OUTPUT_CHARS = 4000

# The one tool the sandbox needs to EXECUTE tests. Installed once at the sandbox root; every
# session dir under the root resolves it by walking parent dirs (Node's native module resolution).
_ROOT_PACKAGE_JSON = (
    '{\n  "name": "vibeproof-sandbox-root",\n  "private": true,\n'
    '  "devDependencies": { "vitest": "^1.6.0" }\n}\n'
)


def enabled() -> bool:
    return get_settings().workspace_backend.lower() == "fs"


def _root() -> Path:
    configured = get_settings().workspace_sandbox_root
    root = Path(configured) if configured else Path(tempfile.gettempdir()) / "vibeproof-sandboxes"
    root.mkdir(parents=True, exist_ok=True)
    return root


def session_dir(session_id: str) -> Path:
    return _root() / session_id


def _safe_path(session_id: str, rel_path: str) -> Path:
    """Resolve rel_path under the session dir and refuse anything that escapes it. This is a trust
    boundary (candidate/AI-supplied paths), so it is never simplified away."""
    base = session_dir(session_id).resolve()
    target = (base / rel_path).resolve()
    if target != base and base not in target.parents:
        raise ValueError(f"Path escapes the sandbox: {rel_path!r}")
    return target


def _vitest_bin() -> Path:
    # npm installs a launcher into node_modules/.bin (a .cmd shim on Windows). Call it directly so
    # we never depend on npx being on PATH or on the shell.
    name = "vitest.cmd" if os.name == "nt" else "vitest"
    return _root() / "node_modules" / ".bin" / name


def _ensure_toolchain() -> None:
    """Install vitest once at the sandbox root. Idempotent: a fast existence check on reruns."""
    root = _root()
    if (root / "node_modules" / "vitest").exists():
        return
    (root / "package.json").write_text(_ROOT_PACKAGE_JSON, encoding="utf-8")
    npm = shutil.which("npm") or "npm"
    subprocess.run(
        [npm, "install", "--no-audit", "--no-fund", "--loglevel=error"],
        cwd=str(root),
        capture_output=True,
        # Force UTF-8: npm/vitest emit UTF-8 (✓/✗), but Windows subprocess defaults to the locale
        # codec (cp1252) and would crash the reader thread on those bytes. errors="replace" makes
        # decoding total.
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=_INSTALL_TIMEOUT_SECONDS,
        check=True,
    )


def materialize(session_id: str, *, scenario_id: str, seeded_files: list[dict]) -> Path:
    """Create the session's real directory: the seeded files (identical to the DB seed) plus the
    hidden grading harness, and ensure the shared toolchain is installed."""
    _ensure_toolchain()
    d = session_dir(session_id)
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)

    for f in seeded_files:
        target = _safe_path(session_id, f["path"])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(f["content"], encoding="utf-8")

    harness = get_settings().workspace_data_dir / scenario_id / _HARNESS_DIRNAME
    if harness.is_dir():
        for item in harness.iterdir():
            dest = d / item.name
            if item.is_dir():
                shutil.copytree(item, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(item, dest)
    return d


def write(session_id: str, rel_path: str, content: str) -> None:
    """Land a real file on disk (the AI's write_file / a candidate save)."""
    target = _safe_path(session_id, rel_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def run_tests(session_id: str, test_id: str) -> dict:
    """Run the real `vitest run` for one test id against the session's on-disk files. Returns the
    same shape as the scripted path but with scripted=False and real captured output."""
    d = session_dir(session_id)
    vitest = _vitest_bin()
    if not d.is_dir() or not vitest.exists():
        return {
            "status": "unavailable",
            "actual_result": "Sandbox is not materialized or the toolchain is not installed.",
            "scripted": False,
        }
    try:
        proc = subprocess.run(
            # -t filters by test name; our tests are named exactly after their test_id.
            [str(vitest), "run", "-t", test_id, "--reporter=dot"],
            cwd=str(d),
            capture_output=True,
            # UTF-8 with errors="replace": vitest prints ✓/✗ etc.; the Windows locale codec would
            # otherwise crash the output reader thread and lose the result.
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=_TEST_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return {
            "status": "failed",
            "actual_result": f"Test run timed out after {_TEST_TIMEOUT_SECONDS}s.",
            "scripted": False,
        }

    output = ((proc.stdout or "") + (proc.stderr or "")).strip()
    if len(output) > _MAX_OUTPUT_CHARS:
        output = output[:_MAX_OUTPUT_CHARS] + "\n...[truncated]"
    status = "passed" if proc.returncode == 0 else "failed"
    return {
        "status": status,
        "actual_result": output or f"vitest exited {proc.returncode}",
        "scripted": False,
    }
