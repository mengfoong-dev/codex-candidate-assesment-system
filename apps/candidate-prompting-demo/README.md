# Candidate Prompting Demo

A React + TypeScript mock of the VibeProof candidate workspace. It uses fixed Homepage Latency Spike data, a scripted assistant response, and an explicitly unscored mock validation flow.

## View locally

From the repository root:

```powershell
cd apps/candidate-prompting-demo
npm.cmd install
npm.cmd run dev
```

Open the localhost address Vite prints in the terminal (normally `http://localhost:5173`).

## Boundary

This is a presentation-only mock. It does not call a model, persist candidate data, calculate a score, or make a hiring recommendation.
