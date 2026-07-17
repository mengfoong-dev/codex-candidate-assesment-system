const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';

export type ChatErrorEnvelope = {
  error?: {
    code?: string;
    message?: string;
  };
};

export type SessionFileRef = {
  path: string;
  source: string;
};

export type ScenarioFact = {
  fact_id: string;
  label: string;
};

export type ScenarioArtifact = {
  artifact_id: string;
  station_id: string;
  evidence_type: string;
  title: string;
  content: string[];
  facts?: ScenarioFact[];
};

export type ScenarioPrompt = {
  prompt_id: string;
  text: string;
  referenced_context_ids: string[];
};

export type ScenarioResponse = {
  response_id: string;
  model_label: string;
  latency_ms: number;
  status: string;
  text: string;
};

export type ScenarioNotices = {
  human_review?: string;
  limitations?: string;
  navigation?: string;
};

export type ScenarioTest = {
  test_id: string;
  expected_result: string;
};

export type SubmissionOption = {
  option_id: string;
  label?: string;
  description?: string;
};

export type SubmissionOptions = {
  remediations: SubmissionOption[];
  required_validation_test_ids: string[];
};

export type Scenario = {
  scenario_id: string;
  scenario_version: string;
  title: string;
  role: string;
  brief: string;
  artifacts: ScenarioArtifact[];
  tests?: ScenarioTest[];
  submission_options?: SubmissionOptions;
  ai_interaction?: {
    prompt?: ScenarioPrompt;
    response?: ScenarioResponse;
  };
  notices?: ScenarioNotices;
};

export type SessionFileContent = {
  path: string;
  source: string;
  content: string;
  updated_at?: string;
};

export type TestResult = {
  test_id: string;
  expected_result: string;
  actual_result: string;
  status: string;
  scripted: boolean;
};

export type SimulationEvent =
  | { event: 'token'; data: { text: string } }
  | { event: 'tool_use'; data: { tool: string; path: string } }
  | { event: 'file_updated'; data: { path: string; source: string } }
  | { event: 'done'; data: { turn_limit: number } }
  | { event: 'error'; data: { code: string; message: string } };

export type CreateSessionResponse = {
  session_id: string;
  scenario: Scenario;
  files: SessionFileRef[];
};

type ChatSuccess = {
  reply: string;
};

async function readErrorMessage(response: Response): Promise<string> {
  const body = (await response.json().catch(() => null)) as ChatErrorEnvelope | null;
  return body?.error?.message?.trim() || `Request failed with status ${response.status}.`;
}

export async function createSession(): Promise<CreateSessionResponse> {
  const response = await fetch(`${API_BASE_URL}/api/sessions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      display_name: 'Anonymous',
    }),
  });

  if (!response.ok) {
    throw new Error(await readErrorMessage(response));
  }

  return (await response.json()) as CreateSessionResponse;
}

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: { Accept: 'application/json' },
  });
  if (!response.ok) {
    throw new Error(await readErrorMessage(response));
  }
  return (await response.json()) as T;
}

async function postJson<T>(path: string, body: unknown): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(await readErrorMessage(response));
  }
  return (await response.json()) as T;
}

export const listFiles = (sessionId: string) =>
  getJson<SessionFileRef[]>(`/api/sessions/${sessionId}/files`);

export const getFile = (sessionId: string, path: string) =>
  getJson<SessionFileContent>(`/api/sessions/${sessionId}/files/${path}`);

export const runTest = (sessionId: string, testId: string, remediationId: string) =>
  postJson<TestResult>(`/api/sessions/${sessionId}/tests/${testId}`, {
    remediation_id: remediationId,
  });

/**
 * Stream one Simulation-Engine turn. The endpoint is a POST that returns Server-Sent Events, so
 * the browser's native EventSource (GET-only) cannot drive it — we read response.body directly,
 * exactly as the frozen API contract (docs/backend/00-api-contract.md) specifies.
 */
export async function streamSimulation(
  sessionId: string,
  content: string,
  onEvent: (event: SimulationEvent) => void,
): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/api/sessions/${sessionId}/messages`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'text/event-stream' },
    body: JSON.stringify({ content }),
  });
  if (!response.ok || !response.body) {
    throw new Error(await readErrorMessage(response));
  }

  const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = '';
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += value;
    // SSE records are separated by a blank line; keep the trailing partial in the buffer.
    const records = buffer.split('\n\n');
    buffer = records.pop() ?? '';
    for (const record of records) {
      const eventName = record.match(/^event: (.+)$/m)?.[1];
      const data = record.match(/^data: (.+)$/m)?.[1];
      if (eventName && data) {
        onEvent({ event: eventName, data: JSON.parse(data) } as SimulationEvent);
      }
    }
  }
}

export async function sendChatMessage(sessionId: string, message: string): Promise<string> {
  const response = await fetch(`${API_BASE_URL}/api/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sessionId,
      message,
    }),
  });

  if (!response.ok) {
    throw new Error(await readErrorMessage(response));
  }

  const body = (await response.json().catch(() => null)) as ChatSuccess | null;
  const reply = body?.reply?.trim();
  if (!reply) {
    throw new Error('Backend response did not contain a reply.');
  }

  return reply;
}
