import { useState, type FormEvent } from 'react';

import { streamSimulation } from '../api';

type Props = {
  sessionId: string;
  onFileUpdated: (path: string) => void;
};

type ChatMessage = {
  id: string;
  role: 'user' | 'assistant';
  content: string;
};

const MAX_TURNS = 5;

/**
 * The candidate's channel to the Simulation Engine. Each send streams one turn: token events grow
 * the live assistant bubble; file_updated tells the parent to refetch the edited file. Hard-capped
 * at 5 prompts to match the backend's per-session limit.
 */
export function SimulationChat({ sessionId, onFileUpdated }: Props) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [prompt, setPrompt] = useState('');
  const [turns, setTurns] = useState(0);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');

  const atLimit = turns >= MAX_TURNS;

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const text = prompt.trim();
    if (!text || sending || atLimit) return;

    const assistantId = crypto.randomUUID();
    setMessages((current) => [
      ...current,
      { id: crypto.randomUUID(), role: 'user', content: text },
      { id: assistantId, role: 'assistant', content: '' },
    ]);
    setPrompt('');
    setError('');
    setSending(true);
    setTurns((count) => count + 1);

    const append = (delta: string) =>
      setMessages((current) =>
        current.map((message) =>
          message.id === assistantId ? { ...message, content: message.content + delta } : message,
        ),
      );

    try {
      await streamSimulation(sessionId, text, (evt) => {
        if (evt.event === 'token') append(evt.data.text);
        else if (evt.event === 'file_updated') onFileUpdated(evt.data.path);
        else if (evt.event === 'error') append(`\n\n[${evt.data.code}] ${evt.data.message}`);
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Simulation request failed.');
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="pane sandbox-chat" aria-label="AI copilot">
      <p className="panel-kicker panel-kicker-violet">
        Copilot ({turns}/{MAX_TURNS} prompts)
      </p>
      <div className="chat-feed" aria-live="polite">
        {messages.map((message) => (
          <article key={message.id} className={`message-card ${message.role}`}>
            <span className="message-author">{message.role === 'user' ? 'You' : 'Copilot'}</span>
            <p>{message.content || (message.role === 'assistant' && sending ? '…' : '')}</p>
          </article>
        ))}
      </div>
      {error ? <p className="chat-error">{error}</p> : null}
      <form className="prompt-row" onSubmit={submit}>
        <textarea
          rows={2}
          value={prompt}
          onChange={(event) => setPrompt(event.target.value)}
          placeholder={
            atLimit
              ? 'Prompt limit reached (5 per session).'
              : 'Ask the copilot to inspect or fix the workspace code…'
          }
          disabled={sending || atLimit}
        />
        <button type="submit" disabled={sending || atLimit || !prompt.trim()}>
          {sending ? 'Sending…' : 'Send'}
        </button>
      </form>
    </div>
  );
}
