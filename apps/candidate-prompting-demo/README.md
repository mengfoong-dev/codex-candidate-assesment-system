# Candidate Prompting Demo

A React + TypeScript candidate prompting screen for VibeProof. It renders the incident brief, evidence workspace, and copilot conversation, then relays prompts to the backend chat endpoint.

## View locally

From the repository root:

```powershell
cd apps/candidate-prompting-demo
npm.cmd install
npm.cmd run dev
```

Open the localhost address Vite prints in the terminal (normally `http://localhost:5173`).

## Backend

The screen calls `POST /api/chat` on `http://localhost:8000` by default.

If the backend runs elsewhere, create `apps/candidate-prompting-demo/.env` and set:

```text
VITE_API_BASE_URL=http://localhost:8000
```

## Boundary

This screen does not implement authentication, scoring, persistence, replay, or analytics.
