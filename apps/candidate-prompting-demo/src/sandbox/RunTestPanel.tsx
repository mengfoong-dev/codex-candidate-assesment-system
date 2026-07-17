import { useState } from 'react';

import { runTest, type CreateSessionResponse } from '../api';

type Props = {
  session: CreateSessionResponse;
};

/**
 * Runs the scenario's required validation tests against the current on-disk workspace. In fs mode
 * the backend runs real vitest (scripted=false); the remediation_id is required by the endpoint
 * but ignored by real execution, so we send the first valid option.
 */
export function RunTestPanel({ session }: Props) {
  const options = session.scenario.submission_options;
  const remediationId = options?.remediations?.[0]?.option_id ?? '';
  const testIds = options?.required_validation_test_ids ?? [];
  const [output, setOutput] = useState('');
  const [running, setRunning] = useState('');

  const run = async (testId: string) => {
    setRunning(testId);
    setOutput(`Running ${testId}…`);
    try {
      const result = await runTest(session.session_id, testId, remediationId);
      const mode = result.scripted ? 'scripted' : 'real vitest';
      setOutput(`${testId}: ${result.status} (${mode})\n\n${result.actual_result}`);
    } catch (err) {
      setOutput(err instanceof Error ? err.message : 'Test run failed.');
    } finally {
      setRunning('');
    }
  };

  return (
    <div className="run-panel" aria-label="Run tests">
      <div className="run-buttons">
        {testIds.map((testId) => (
          <button
            key={testId}
            type="button"
            className="run-btn"
            disabled={!!running || !remediationId}
            onClick={() => run(testId)}
          >
            {running === testId ? 'Running…' : `Run ${testId}`}
          </button>
        ))}
      </div>
      <pre className="run-console">
        {output || 'No test run yet. Ask the copilot to fix the code, then run a validation test.'}
      </pre>
    </div>
  );
}
