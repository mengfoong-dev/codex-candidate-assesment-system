import { useEffect, useMemo, useState, type FormEvent } from 'react';

import {
  createSession,
  sendChatMessage,
  type CreateSessionResponse,
  type Scenario,
  type ScenarioArtifact,
} from './api';

type ChatMessage = {
  id: string;
  role: 'user' | 'assistant';
  author: string;
  content: string;
  thinking?: boolean;
};

function buildInitialMessages(scenario: Scenario): ChatMessage[] {
  const prompt = scenario.ai_interaction?.prompt?.text?.trim();
  const response = scenario.ai_interaction?.response?.text?.trim();

  return [
    {
      id: 'seed-user',
      role: 'user',
      author: 'You',
      content: prompt || 'Ask the copilot about this incident.',
    },
    {
      id: 'seed-assistant',
      role: 'assistant',
      author: 'Copilot',
      content:
        response ||
        'I am ready to help you investigate the incident using the evidence in this workspace.',
    },
  ];
}

function splitSummaryLine(line: string): { label: string; value: string } {
  const index = line.indexOf(':');
  if (index === -1) {
    return { label: line.trim(), value: '' };
  }

  return {
    label: line.slice(0, index).trim(),
    value: line.slice(index + 1).trim(),
  };
}

function getDisplayTitle(scenario: Scenario | null): string {
  if (!scenario) return 'Loading incident...';
  return `${scenario.title} - ${scenario.role}`;
}

function getSignalRows(metricsArtifact: ScenarioArtifact | undefined): Array<{ label: string; value: string }> {
  if (!metricsArtifact) return [];
  return metricsArtifact.content.slice(0, 3).map(splitSummaryLine);
}

function getEvidenceArtifacts(scenario: Scenario | null): ScenarioArtifact[] {
  if (!scenario) return [];
  return scenario.artifacts.filter(artifact => artifact.artifact_id !== 'metrics_overview');
}

export default function App() {
  const [workspace, setWorkspace] = useState<CreateSessionResponse | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [prompt, setPrompt] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;

    const loadWorkspace = async () => {
      setIsLoading(true);
      setError('');

      try {
        const session = await createSession();
        if (!active) return;

        setWorkspace(session);
        setMessages(buildInitialMessages(session.scenario));
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : 'Failed to load incident data.');
      } finally {
        if (active) {
          setIsLoading(false);
        }
      }
    };

    void loadWorkspace();

    return () => {
      active = false;
    };
  }, []);

  const scenario = workspace?.scenario ?? null;
  const metricsArtifact = scenario?.artifacts.find(artifact => artifact.artifact_id === 'metrics_overview');
  const signalRows = useMemo(() => getSignalRows(metricsArtifact), [metricsArtifact]);
  const evidenceArtifacts = useMemo(() => getEvidenceArtifacts(scenario), [scenario]);

  const statusText = useMemo(() => {
    if (isLoading) return 'Loading incident data...';
    if (isSending) return 'Contacting backend...';
    return 'Copilot ready - prompts stay in this assessment session.';
  }, [isLoading, isSending]);

  const resultCopy = scenario?.notices;
  const sessionId = workspace?.session_id ?? '';

  const sendPrompt = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const message = prompt.trim();
    if (!message || isSending || !sessionId) {
      return;
    }

    const userMessage: ChatMessage = {
      id: crypto.randomUUID(),
      role: 'user',
      author: 'You',
      content: message,
    };
    const thinkingId = crypto.randomUUID();

    setMessages(current => [
      ...current,
      userMessage,
      {
        id: thinkingId,
        role: 'assistant',
        author: 'Copilot',
        content: 'Thinking...',
        thinking: true,
      },
    ]);
    setPrompt('');
    setIsSending(true);

    try {
      const reply = await sendChatMessage(sessionId, message);
      setMessages(current =>
        current.map(item =>
          item.id === thinkingId
            ? {
                ...item,
                thinking: false,
                content: reply,
              }
            : item,
        ),
      );
    } catch (err) {
      const messageText = err instanceof Error ? err.message : 'Backend request failed.';
      setMessages(current =>
        current.map(item =>
          item.id === thinkingId
            ? {
                ...item,
                thinking: false,
                content: messageText,
              }
            : item,
        ),
      );
    } finally {
      setIsSending(false);
    }
  };

  return (
    <main className="app-shell">
      <section className="workspace-shell" aria-label="VibeProof candidate prompting screen">
        <p className="workspace-banner">
          Use the copilot alongside the evidence workspace. Your prompts and actions are recorded.
        </p>

        <section className="workspace-grid">
          <aside className="panel panel-incident" aria-label="Incident brief">
            <p className="panel-kicker panel-kicker-amber">Incident brief</p>
            <h1>{getDisplayTitle(scenario)}</h1>
            <p className="panel-intro">
              {scenario?.brief ?? 'Loading the incident brief from the backend...'}
            </p>

            <hr />

            <p className="panel-kicker panel-kicker-amber">Assessment flow</p>
            <p className="panel-copy">
              {scenario?.notices?.human_review ??
                'Your initial hypothesis is recorded. Use this screen to investigate it with the copilot and the evidence below.'}
            </p>

            {error ? (
              <>
                <hr />
                <p className="panel-copy">{error}</p>
              </>
            ) : null}
          </aside>

          <section className="panel panel-conversation" aria-label="Conversation">
            <div className="panel-heading">
              <p className="panel-kicker panel-kicker-violet">Conversation</p>
              <h2>Engineering copilot</h2>
              <p className="panel-subtitle">{statusText}</p>
            </div>

            <div className="conversation-feed" aria-live="polite">
              {messages.map(message => (
                <article
                  className={`message-card ${message.role}${message.thinking ? ' thinking' : ''}`}
                  key={message.id}
                >
                  <span className="message-author">{message.author}</span>
                  {message.thinking ? (
                    <div className="thinking-dots" aria-hidden="true">
                      <i />
                      <i />
                      <i />
                    </div>
                  ) : (
                    <p>{message.content}</p>
                  )}
                </article>
              ))}
            </div>

            <form className="prompt-row" onSubmit={sendPrompt}>
              <label className="sr-only" htmlFor="prompt">
                Ask the copilot about this incident
              </label>
              <textarea
                id="prompt"
                rows={2}
                value={prompt}
                onChange={event => setPrompt(event.target.value)}
                onKeyDown={event => {
                  if (
                    event.key === 'Enter' &&
                    !event.shiftKey &&
                    !event.nativeEvent.isComposing
                  ) {
                    event.preventDefault();
                    event.currentTarget.form?.requestSubmit();
                  }
                }}
                placeholder="Ask the copilot about this incident"
                disabled={isLoading}
              />
              <button type="submit" disabled={isLoading || isSending || !prompt.trim() || !sessionId}>
                {isSending ? 'Sending' : 'Send'}
              </button>
            </form>
          </section>

          <section className="panel panel-evidence" aria-label="Evidence and output">
            <div className="panel-heading">
              <p className="panel-kicker panel-kicker-cyan">Evidence and output</p>
              <h2>Homepage signals</h2>
            </div>

            <div className="signal-grid" aria-label="Homepage signals summary">
              {signalRows.map(signal => (
                <div className="signal-row" key={signal.label}>
                  <span>{signal.label}</span>
                  <strong>{signal.value}</strong>
                </div>
              ))}
            </div>

            <hr />

            <div className="evidence-scroll">
              <p className="panel-kicker panel-kicker-cyan">Evidence</p>

              {evidenceArtifacts.map(artifact => (
                <section className="evidence-section" key={artifact.artifact_id}>
                  <h3>{artifact.title}</h3>
                  <pre>{artifact.content.join('\n')}</pre>
                </section>
              ))}
            </div>

            <hr />

            <section className="result-block" aria-label="Result guidance">
              <p className="panel-kicker panel-kicker-result">Result</p>
              <p>
                {resultCopy?.human_review ??
                  'Build an evidence-backed diagnosis, then state a safe remediation, validation plan, and rollback condition in your submission.'}
              </p>
              <p>{resultCopy?.limitations ?? ''}</p>
              <p>{resultCopy?.navigation ?? ''}</p>
            </section>
          </section>
        </section>
      </section>
    </main>
  );
}
