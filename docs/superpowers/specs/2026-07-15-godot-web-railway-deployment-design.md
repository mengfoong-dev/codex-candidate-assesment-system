# Godot Web Railway Deployment Design

**Date:** 2026-07-15

**Status:** Approved direction; awaiting written-spec review

## Goal

Publish the existing Godot 4.7.1 VibeProof Incident Room as a browser application in Railway project `0f3b65eb-b5c4-4d06-8c46-4fcebf870674` while preserving the tested Windows build and the intentionally unscored product boundary.

## Decisions

- Keep `apps/incident-room` as the single game source for Windows and Web.
- Add a `Web` export preset that emits `dist/web/index.html` and its same-base-name Godot assets.
- Use the existing Compatibility renderer, WebAssembly, and WebGL 2.0.
- Use the official single-threaded Godot Web template. This avoids requiring cross-origin isolation headers and keeps static hosting simple.
- Do not enable PWA behavior in this milestone.
- Serve the export from a minimal Caddy container on Railway's injected `PORT`.
- Deploy to a dedicated `vibeproof-web` service inside the supplied Railway project. Do not modify or replace an existing service.
- Keep generated Web files and deployment staging ignored by Git. Commit only the export preset, server configuration, scripts, tests, and documentation.
- Keep candidate sessions browser-local. No backend, account, centralized event collection, or scoring is introduced.

## Components

### Godot Web preset

The new export preset uses `index.html`, excludes tests and development scripts, includes scenario and notice files, and uses the no-thread Web template. The current Windows preset remains unchanged.

### Build and staging script

A PowerShell script will:

1. verify the pinned Godot executable and Web template;
2. run the existing headless test suite;
3. export the Web build to `apps/incident-room/dist/web`;
4. assert required HTML, JavaScript, WebAssembly, and pack files are nonempty;
5. assemble an ignored Railway staging directory with the static files, `Dockerfile`, and `Caddyfile`.

The script must fail before deployment when any prerequisite or artifact is missing.

### Railway service

The Railway CLI will link to the supplied project ID and create or select only the dedicated `vibeproof-web` service. `railway up` will upload the staged static site. Caddy will bind to Railway's `PORT`, serve `index.html`, provide the correct WebAssembly MIME type through its built-in file server, and fall back to `index.html` only for routes that do not match an exported asset.

### Documentation

The application README will document local Web export, local HTTP serving, Railway deployment, the public URL, browser requirements, browser-local persistence, and rollback/redeploy commands.

## Data and privacy boundary

`events.jsonl` and `summary.json` continue to use Godot's `user://` APIs. In a Web export, this data belongs to that browser origin and is not uploaded to Railway as candidate evidence. Clearing browser site data may remove it. The Web build must show the same persistence warning if writes are unavailable.

This milestone does not add scoring, recruiter APIs, cloud storage, authentication, analytics, or a live model.

## Error handling

- Missing Web templates stop the build with an installation message.
- Export errors stop deployment.
- Missing or empty output files stop deployment.
- Railway authentication, project-link, service-creation, build, or health-check failures are reported without deleting an existing service.
- A failed deployment leaves the previous healthy Railway deployment untouched where Railway supports atomic replacement.

## Verification

- Existing Godot tests remain green.
- A clean Godot Web export exits successfully.
- Exported HTML references existing JavaScript, WebAssembly, and pack files.
- A local static-server check returns `200` for `/`, the WebAssembly asset with a WebAssembly content type, and the pack asset.
- Railway deployment reaches a healthy state.
- The public Railway URL returns `200` and the expected VibeProof/Godot page.
- Browser-interaction testing will use the in-app browser when available. If it remains unavailable, automated HTTP checks will be recorded and a human visual/control check will remain explicit.

## Acceptance criteria

1. The Windows export still works.
2. The Web export builds from the same game source with Godot 4.7.1.
3. Railway hosts the Web build at a public HTTPS URL.
4. Existing Railway services are not replaced or reconfigured.
5. A candidate can reach the title screen in a Chromium-based browser or Firefox.
6. The application remains explicitly unscored and offline except for downloading its static assets.
7. Repository instructions reproduce build and deployment without committing generated Web artifacts.

## Deferred work

- Automatic GitHub-to-Railway continuous deployment
- Progressive Web App installation and offline service worker
- Cloud candidate-session storage
- Backend scoring and recruiter results
- Custom domain and analytics
