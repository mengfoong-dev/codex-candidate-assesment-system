import { useState, type FormEvent, type ReactNode } from 'react';

type ArtifactId = 'metrics_overview' | 'homepage_trace' | 'homepage_orchestrator';
type Message = { id: string; role: 'user' | 'assistant'; content?: string; thinking?: boolean };

const artifacts: Record<ArtifactId, { label: string; content: ReactNode }> = {
  metrics_overview: { label: 'Metrics', content: <><span className="muted">Homepage p95 latency</span>  <strong>850 ms</strong>{'\n'}<span className="muted">Baseline p95 latency</span>   <b>180 ms</b>{'\n'}<span className="muted">CPU utilization</span>         <b>35% (healthy)</b>{'\n'}<span className="muted">Database</span>                <b>Healthy</b>{'\n\n'}Latency increased without CPU saturation.</> },
  homepage_trace: { label: 'Trace', content: <><span className="muted">GET / homepage</span>{'\n'}|- auth.check <b>120ms</b>{'\n'}|- user.load <b>190ms</b>{'\n'}|- feed.fetch <b>210ms</b>{'\n'}\- ads.fetch <strong>330ms</strong>{'\n\n'}Calls accumulate on the critical path.</> },
  homepage_orchestrator: { label: 'Code', content: <><span className="muted">async function buildHomepage(userId) {'{'}</span>{'\n'}  const auth = await checkAuth();{'\n'}  const user = await loadUser(userId);{'\n'}  const feed = await fetchFeed(userId);{'\n'}  const ads = await fetchAds();{'\n'}<span className="muted">{'}'}</span>{'\n\n'}Confirm calls are independent before parallelizing.</> },
};

const assistantReply = 'Mock response: compare the trace with the orchestration code, confirm the calls do not depend on one another, then validate both latency and correctness before changing concurrency.';

export default function App() {
  const [artifact, setArtifact] = useState<ArtifactId>('homepage_trace');
  const [confidence, setConfidence] = useState(65);
  const [prompt, setPrompt] = useState('');
  const [validated, setValidated] = useState(false);
  const [approval, setApproval] = useState<'awaiting' | 'allowed' | 'denied'>('awaiting');
  const [toast, setToast] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    { id: 'first-user', role: 'user', content: 'Where should I start looking?' },
    { id: 'first-assistant', role: 'assistant', content: 'CPU is low, so it is likely waiting on something. Open the homepage trace and check whether calls run one after another.' },
    { id: 'second-user', role: 'user', content: 'Found 4 API calls in a row.' },
    { id: 'starter-thinking', role: 'assistant', thinking: true },
  ]);

  const notify = (message: string) => {
    setToast(message);
    window.setTimeout(() => setToast(''), 3200);
  };

  const sendPrompt = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const question = prompt.trim();
    if (!question) return;
    const thinkingId = crypto.randomUUID();
    setMessages(current => [...current.filter(message => message.id !== 'starter-thinking'), { id: crypto.randomUUID(), role: 'user', content: question }, { id: thinkingId, role: 'assistant', thinking: true }]);
    setPrompt('');
    notify('Your message appeared immediately. Assistant is thinking...');
    window.setTimeout(() => setMessages(current => current.map(message => message.id === thinkingId ? { ...message, thinking: false, content: assistantReply } : message)), 650);
  };

  const runValidation = () => {
    setValidated(true);
    setApproval('allowed');
    notify('Mock validation completed.');
  };

  return <main className="app-shell"><section className="assessment-screen" aria-label="VibeProof candidate assessment">
    <header className="challenge-bar"><div className="challenge-title"><span>Homepage latency spike</span><span className="difficulty">Intermediate</span></div><div className="challenge-actions"><span className="timer">Time <strong>18:42</strong></span><button className="run-button" onClick={runValidation}>Run</button><button className="submit-button" onClick={() => notify('Mock submission saved as an unscored candidate summary.')}>Submit</button></div></header>
    <p className="prototype-notice"><span />Mock workspace: actions are demonstrative and the result is explicitly unscored.</p>
    <section className="workspace">
      <aside className="incident-panel panel"><h1>Incident brief</h1><p>Users report the homepage feels slow. Engineering metrics show:</p><div className="signals"><div>p95 latency <span>180ms to</span> <strong>850ms</strong></div><div>CPU usage <b>35%</b></div></div><p>Your task is not to rewrite the system, but to find the bottleneck and propose a fix.</p><div className="hypothesis-card"><label htmlFor="hypothesis">Current hypothesis</label><select id="hypothesis" defaultValue="Sequential independent API calls"><option>Redis cache degradation</option><option>CPU saturation</option><option>Sequential independent API calls</option><option>Database slowdown</option></select><div><span>Confidence</span><strong>{confidence}%</strong></div><input aria-label="Confidence" type="range" min="0" max="100" value={confidence} onChange={event => setConfidence(Number(event.target.value))} /></div></aside>
      <section className="conversation-panel panel" aria-label="Conversation"><h2>Conversation <span>Scripted assistant</span></h2><div className="conversation-workspace"><div className="chat-thread"><div className="conversation" aria-live="polite">{messages.map(message => <article className={`message ${message.role}${message.thinking ? ' thinking' : ''}`} key={message.id}>{message.thinking ? <><i /><i /><i /></> : <p>{message.content}</p>}</article>)}</div><form className="prompt-box" onSubmit={sendPrompt}><label className="sr-only" htmlFor="prompt">Write a message</label><textarea id="prompt" rows={1} value={prompt} onChange={event => setPrompt(event.target.value)} onKeyDown={event => { if (event.key === 'Enter' && !event.shiftKey && !event.nativeEvent.isComposing) { event.preventDefault(); event.currentTarget.form?.requestSubmit(); } }} placeholder="Write a message... Press Enter to send, or Shift+Enter for a new line." /><button type="submit">Send</button></form></div><aside className="activity-panel" aria-label="Assistant activity"><div className="activity-heading"><h3>Assistant activity</h3><span>Live</span></div><ol className="activity-list"><li><span className="activity-dot complete" /><div><strong>Context loaded</strong><p>Homepage trace and metrics</p></div></li><li><span className="activity-dot complete" /><div><strong>Trace reviewed</strong><p>Sequential waits detected</p></div></li><li><span className="activity-dot active" /><div><strong>Reasoning</strong><p>Checking call independence</p></div></li></ol><section className={`permission-card ${approval}`}><p className="permission-label">Permission required</p><strong>Run scripted validation?</strong><span>Checks p95 latency and correctness using mock data.</span>{approval === 'awaiting' ? <div><button onClick={() => { setApproval('allowed'); notify('Validation permission allowed.'); }}>Allow</button><button className="deny" onClick={() => { setApproval('denied'); notify('Validation permission denied.'); }}>Deny</button></div> : <p className="permission-result">{approval === 'allowed' ? 'Allowed by candidate' : 'Denied by candidate'}</p>}</section></aside></div></section>
      <section className="right-column"><section className="output-panel panel"><div className="panel-title"><h2>Output</h2><div className="tabs" role="tablist">{(Object.keys(artifacts) as ArtifactId[]).map(id => <button key={id} className={`tab ${artifact === id ? 'active' : ''}`} onClick={() => { setArtifact(id); notify(`Opened ${artifacts[id].label} evidence (mock event recorded).`); }}>{artifacts[id].label}</button>)}</div></div><pre><code>{artifacts[artifact].content}</code></pre></section><section className="result-panel"><div><h2>Result</h2><p>{validated ? 'Mock validation selected latency and correctness checks. Parallelize only confirmed independent calls.' : 'Submit your diagnosis to see the unscored session summary.'}</p></div><button className="text-button" onClick={runValidation}>{validated ? 'Ready' : 'Use safe remediation'}</button></section></section>
    </section>
  </section><div className={`toast ${toast ? 'show' : ''}`} role="status">{toast}</div></main>;
}
