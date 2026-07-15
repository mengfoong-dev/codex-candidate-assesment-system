# Godot Web Railway Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export the existing Godot 4.7.1 Incident Room for browsers and deploy it as an isolated static service in Railway project `0f3b65eb-b5c4-4d06-8c46-4fcebf870674`.

**Architecture:** The Godot project gains a no-thread Web export preset that produces ignored static artifacts. A deterministic PowerShell script verifies and stages those artifacts with a tracked Caddy container definition; Railway receives only the staged static site and creates a dedicated `vibeproof-web` service.

**Tech Stack:** Godot 4.7.1 Compatibility renderer, WebAssembly/WebGL 2.0, PowerShell, Caddy 2 Alpine, Railway CLI 4.44.0, first-party Godot tests.

**Outcome:** Implemented on `main` and deployed on 2026-07-16 at [vibeproof-web-production.up.railway.app](https://vibeproof-web-production.up.railway.app). Automated local and public HTTP checks passed; a human browser visual/control pass remains appropriate before a judged demo.

## Global Constraints

- Keep Windows and Web exports sourced from `apps/incident-room`.
- Keep the Web export single-threaded and PWA-disabled.
- Do not commit `dist/` or generated Web output.
- Do not modify or replace an existing Railway service.
- Keep `events.jsonl` and `summary.json` browser-local through `user://`.
- Do not add backend scoring, authentication, analytics, cloud evidence storage, or a live model.
- Commit every generated `*.gd.uid` sidecar.

---

### Task 1: Define the Web export contract

**Files:**
- Modify: `apps/incident-room/export_presets.cfg`
- Create: `apps/incident-room/tests/test_web_export_contract.gd`

**Interfaces:**
- Consumes: the existing Godot project and installed `web_nothreads_release.zip` template.
- Produces: a `Web` preset exporting `dist/web/index.html` without threads or PWA behavior.

- [ ] **Step 1: Write the failing contract test**

Load `res://export_presets.cfg` and assert it contains all exact fragments:

```gdscript
const REQUIRED_WEB_PRESET_FRAGMENTS: Array[String] = [
    "name=\"Web\"",
    "platform=\"Web\"",
    "export_path=\"dist/web/index.html\"",
    "variant/thread_support=false",
    "progressive_web_app/enabled=false",
]
```

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
```

Expected: failure because no Web preset exists.

- [ ] **Step 3: Add preset 1**

Append a `Web` preset using `export_filter="all_resources"`, the current include/exclude filters, `script_export_mode=2`, `variant/extensions_support=false`, `variant/thread_support=false`, desktop texture compression, `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true`, and `progressive_web_app/enabled=false`.

- [ ] **Step 4: Run GREEN**

Expected: every discovered Godot suite passes.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/export_presets.cfg apps/incident-room/tests/test_web_export_contract.gd*
git commit -m "feat: define the Godot Web export"
```

---

### Task 2: Build and validate a Railway staging bundle

**Files:**
- Create: `apps/incident-room/deploy/railway-web/Dockerfile`
- Create: `apps/incident-room/deploy/railway-web/Caddyfile`
- Create: `apps/incident-room/deploy/railway-web/railway.json`
- Create: `apps/incident-room/scripts/development/build_web.ps1`
- Modify: `apps/incident-room/tests/test_web_export_contract.gd`

**Interfaces:**
- Consumes: `Godot_v4.7.1-stable_win64_console.exe`, `web_nothreads_release.zip`, and the `Web` preset.
- Produces: ignored `dist/web` and `dist/railway-web` directories.

- [ ] **Step 1: Extend the failing contract test**

Assert the three tracked deployment files exist and contain:

```text
Dockerfile: FROM caddy:2-alpine; COPY site /srv
Caddyfile: :{$PORT:8080}; root * /srv; try_files {path} /index.html; file_server
railway.json: DOCKERFILE builder; healthcheckPath "/"
```

- [ ] **Step 2: Run RED**

Expected: missing deployment files.

- [ ] **Step 3: Add static-server configuration**

Use this container boundary:

```dockerfile
FROM caddy:2-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY site /srv
```

Configure Caddy to bind Railway's `PORT`, compress responses, serve exact assets before the HTML fallback, and set `X-Content-Type-Options: nosniff`.

- [ ] **Step 4: Add `build_web.ps1`**

The script resolves paths beneath `apps/incident-room`, runs `verify_project.ps1`, exports preset `Web`, requires one nonempty `.html`, `.js`, `.wasm`, and `.pck`, safely recreates only `dist/railway-web`, copies the export to `site/`, copies the three deployment files, and prints `WEB_EXPORT=` and `RAILWAY_STAGE=` paths.

- [ ] **Step 5: Run GREEN and build**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/build_web.ps1
```

Expected: tests pass and both ignored output directories contain nonempty artifacts.

- [ ] **Step 6: Commit**

```powershell
git add apps/incident-room/deploy/railway-web apps/incident-room/scripts/development/build_web.ps1 apps/incident-room/tests/test_web_export_contract.gd*
git commit -m "build: stage the Godot Web app for Railway"
```

---

### Task 3: Verify the static site locally

**Files:**
- Modify: `apps/incident-room/README.md`

**Interfaces:**
- Consumes: `dist/railway-web/site`.
- Produces: HTTP evidence for HTML, WebAssembly, and PCK assets.

- [ ] **Step 1: Start a hidden local static server**

Use Python's HTTP server only as a local smoke surface:

```powershell
Start-Process python -ArgumentList '-m','http.server','8060','--directory','apps/incident-room/dist/railway-web/site' -PassThru -WindowStyle Hidden
```

- [ ] **Step 2: Verify HTTP contracts**

Request `/`, the discovered `.wasm`, and `.pck` paths. Require status `200`, HTML containing Godot bootstrap content, and the WebAssembly response content type containing `application/wasm`.

- [ ] **Step 3: Stop only the captured server process**

Use `Stop-Process -Id $server.Id` after the checks, including in `finally`.

- [ ] **Step 4: Document local Web use**

Document the build command, required HTTP serving, Chromium/Firefox recommendation, WebGL 2.0 requirement, and browser-local persistence limitation.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/README.md
git commit -m "docs: explain the local Godot Web build"
```

---

### Task 4: Deploy an isolated Railway service

**Files:**
- Modify: `apps/incident-room/README.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: authenticated Railway CLI, project ID, and `dist/railway-web`.
- Produces: dedicated `vibeproof-web` service and public HTTPS domain.

- [ ] **Step 1: Link and inspect the supplied project**

```powershell
railway link -p 0f3b65eb-b5c4-4d06-8c46-4fcebf870674
railway status --json
railway service list
```

Record existing service names before mutation.

- [ ] **Step 2: Create only the dedicated service when absent**

```powershell
railway add --service vibeproof-web --json
railway service link vibeproof-web
```

If `vibeproof-web` already exists, link it rather than creating another service.

- [ ] **Step 3: Upload the staged site**

```powershell
railway up apps/incident-room/dist/railway-web --path-as-root --no-gitignore --service vibeproof-web --environment production --ci
```

Expected: Railway reports a successful deployment.

- [ ] **Step 4: Generate or read the public domain**

```powershell
railway domain --service vibeproof-web --port 8080 --json
```

Create a Railway-provided domain only when none exists.

- [ ] **Step 5: Verify the public deployment**

Require HTTPS `/` status `200`, HTML bootstrap content, `.wasm` status `200` with `application/wasm`, and `.pck` status `200`. Record deployment status and logs if any check fails.

- [ ] **Step 6: Document and commit**

Add the public URL, Railway project ID, service name, build/deploy commands, and browser-local evidence boundary to both READMEs.

```powershell
git add README.md apps/incident-room/README.md
git commit -m "docs: publish the Godot Web deployment"
```

---

## Final verification gate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/build_web.ps1
git diff --check
git status --short
```

Required evidence:

- Godot 4.7.1 reports every suite passing.
- Web export contains nonempty HTML, JS, WASM, and PCK files.
- Local and public HTTP checks pass.
- Railway service `vibeproof-web` is healthy at a public HTTPS URL.
- Pre-existing Railway services remain present.
- The generated `dist/` content remains ignored and uncommitted.
