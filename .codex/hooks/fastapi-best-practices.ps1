$inputText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputText)) {
    return
}

try {
    $event = $inputText | ConvertFrom-Json
} catch {
    return
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\\..'))

function Test-BackendPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $candidate = $Path.Trim().Trim('"').Trim("'") -replace '/', '\\'
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $repoRoot $candidate
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($candidate)
        $backendRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'backend'))
    } catch {
        return $false
    }

    return $fullPath.StartsWith(
        $backendRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

$toolInput = $event.tool_input
$paths = [System.Collections.Generic.List[string]]::new()

foreach ($property in @('file_path', 'path', 'notebook_path')) {
    if ($null -ne $toolInput -and $toolInput.PSObject.Properties.Name -contains $property) {
        $paths.Add([string]$toolInput.$property)
    }
}

# Codex's apply_patch tool sends one patch string rather than one file path.
if ($null -ne $toolInput -and $toolInput.PSObject.Properties.Name -contains 'patch') {
    $patchText = [string]$toolInput.patch
    foreach ($match in [regex]::Matches($patchText, '(?m)^\*\*\* (?:Add|Update|Delete) File:\s*(.+)$')) {
        $paths.Add($match.Groups[1].Value)
    }
}

$isBackendEdit = $false
foreach ($path in $paths) {
    if (Test-BackendPath $path) {
        $isBackendEdit = $true
        break
    }
}

if (-not $isBackendEdit) {
    return
}

$message = @'
FastAPI architecture advisory for this backend edit (non-blocking):
- Preserve the existing `src/` app-level modules (`main`, `config`, `database`, shared `models`, and shared `exceptions`).
- Put substantial new bounded contexts in `src/<domain>/`; keep route handlers in `router.py`, request/response Pydantic models in `schemas.py`, ORM models in `models.py`, business logic in `service.py`, and reusable route validation in `dependencies.py`. Add only the domain files that the feature needs.
- Prefer explicit cross-domain module imports (for example, `from src.sessions import service as session_service`), not wildcard or deep implementation imports.
- Match the async stack: async SQLAlchemy sessions, awaitable I/O in `async def`, and `run_in_threadpool` only when a sync dependency is unavoidable. Move CPU-heavy work to a worker process.
- Use Pydantic v2 validation/serializers, `Annotated[..., Depends(...)]`, and `httpx.AsyncClient` + `ASGITransport` for async endpoint tests.
- This is guidance, not a required rigid layout. Favor the smallest coherent change and the current project conventions when they conflict.
'@

# Codex and Claude Code accept different non-blocking context response shapes.
if ($event.PSObject.Properties.Name -contains 'model') {
    @{ systemMessage = $message } | ConvertTo-Json -Compress
} else {
    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            additionalContext = $message
        }
    } | ConvertTo-Json -Compress -Depth 4
}
