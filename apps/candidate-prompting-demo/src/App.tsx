import { useEffect, useState } from 'react';

import { createSession, type CreateSessionResponse } from './api';
import { SandboxView } from './sandbox/SandboxView';

/**
 * The mini sandbox app: creates one assessment session on load, then hands it to SandboxView
 * (file list + read-only code viewer + run-test + streaming Simulation-Engine chat). This replaces
 * the earlier prompting-only demo — the app is now the sandbox layer for the Simulation Engine.
 */
export default function App() {
  const [session, setSession] = useState<CreateSessionResponse | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    createSession()
      .then((created) => {
        if (active) setSession(created);
      })
      .catch((err) => {
        if (active) setError(err instanceof Error ? err.message : 'Failed to start session.');
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  const scenario = session?.scenario ?? null;

  return (
    <main className="app-shell">
      <header className="sandbox-header">
        <p className="panel-kicker panel-kicker-amber">Simulation sandbox</p>
        <h1>{scenario ? `${scenario.title} — ${scenario.role}` : 'Loading incident…'}</h1>
        {scenario ? <p className="sandbox-brief">{scenario.brief}</p> : null}
        <p className="sandbox-note">
          Prompt the copilot to inspect and fix the workspace code, then run the validation tests.
          Your prompts and actions are recorded.
        </p>
      </header>

      {loading ? <p className="sandbox-status">Starting session…</p> : null}
      {error ? <p className="sandbox-status sandbox-error">{error}</p> : null}
      {session ? <SandboxView session={session} /> : null}
    </main>
  );
}
