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

export type Scenario = {
  scenario_id: string;
  scenario_version: string;
  title: string;
  role: string;
  brief: string;
  artifacts: ScenarioArtifact[];
  ai_interaction?: {
    prompt?: ScenarioPrompt;
    response?: ScenarioResponse;
  };
  notices?: ScenarioNotices;
};

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
