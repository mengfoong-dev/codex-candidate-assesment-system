# Candidate Prompting Demo

A dependency-free browser mock of the VibeProof candidate workspace. It uses fixed Homepage Latency Spike data, a scripted assistant response, and an explicitly unscored mock validation flow.

## View locally

From the repository root:

```powershell
python -m http.server 8080 --directory apps/candidate-prompting-demo
```

Open `http://localhost:8080` in a browser. You can also open `index.html` directly, but the local server mirrors a normal web-preview workflow.

## Boundary

This is a presentation-only mock. It does not call a model, persist candidate data, calculate a score, or make a hiring recommendation.
