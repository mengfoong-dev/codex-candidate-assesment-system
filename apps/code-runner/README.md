# VibeProof code runner

This image runs the hidden tests for the watch-page latency challenge. It reads one candidate
source file from standard input, executes it inside the container, and prints one JSON result.
The senior proxy creates a fresh container for every test run.

## Build

```powershell
docker build -t vibeproof-code-runner:latest apps/code-runner
```

## Smoke tests

The parallel fixture should pass:

```powershell
Get-Content -Raw apps/code-runner/fixtures/parallel.js |
  docker run --rm -i --network none --read-only --tmpfs /tmp:rw,noexec,nosuid,size=32m vibeproof-code-runner:latest
```

The sequential fixture should fail only the concurrency test:

```powershell
Get-Content -Raw apps/code-runner/fixtures/sequential.js |
  docker run --rm -i --network none --read-only --tmpfs /tmp:rw,noexec,nosuid,size=32m vibeproof-code-runner:latest
```

## Run on another machine

Install Docker on the remote machine, copy this repository there, then build the worker image:

```bash
docker build -t vibeproof-code-runner:latest apps/code-runner
```

Run the senior proxy on that same machine. The proxy invokes the local Docker Engine and creates
a disposable worker for each `POST /api/assistant/test` request:

```bash
export PROVIDER=deepseek
export DEEPSEEK_API_KEY=your-key
export TEST_RUNNER_IMAGE=vibeproof-code-runner:latest
export ALLOWED_ORIGINS=https://your-game.example
node apps/senior-proxy/server.js
```

Expose the proxy through HTTPS using Caddy, nginx, Railway, or another reverse proxy. Point the
Godot `assistant_proxy_url` at:

```text
https://your-proxy.example/api/assistant/chat
```

The terminal derives the test URL as `https://your-proxy.example/api/assistant/test`.

Do not expose the Docker daemon or its socket over the public network. If the senior proxy stays
on Railway, this local-Docker design requires deploying the runner image there as part of the same
Docker-capable service; otherwise deploy both components together on the remote machine.

## Security boundary

The proxy starts workers with no network, a read-only filesystem, a temporary `/tmp`, a non-root
user, dropped Linux capabilities, no-new-privileges, and CPU/memory/process/time/output limits.
No API keys are passed into the worker. This is suitable for a controlled prototype; a public
multi-tenant product should use a stronger isolation boundary such as gVisor or microVMs.
