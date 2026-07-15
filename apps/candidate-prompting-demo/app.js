const artifacts = {
  metrics_overview: `<span class="muted">Homepage p95 latency</span>  <strong>850 ms</strong>\n<span class="muted">Baseline p95 latency</span>   <b>180 ms</b>\n<span class="muted">CPU utilization</span>         <b>35% (healthy)</b>\n<span class="muted">Database</span>                <b>Healthy</b>\n\nLatency increased without CPU saturation.`,
  homepage_trace: `<span class="muted">GET / homepage</span>\n├─ auth.check <b>120ms</b>\n├─ user.load <b>190ms</b>\n├─ feed.fetch <b>210ms</b>\n└─ ads.fetch <strong>330ms</strong>\n\nCalls accumulate on the critical path.`,
  homepage_orchestrator: `<span class="muted">async function buildHomepage(userId) {</span>\n  const auth = await checkAuth();\n  const user = await loadUser(userId);\n  const feed = await fetchFeed(userId);\n  const ads = await fetchAds();\n<span class="muted">}</span>\n\nConfirm calls are independent before parallelizing.`
};

const output = document.querySelector('#evidence-output code');
const toast = document.querySelector('#toast');
const conversation = document.querySelector('#conversation');
const showToast = text => {
  toast.textContent = text;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3200);
};

document.querySelectorAll('.tab').forEach(tab => tab.addEventListener('click', () => {
  document.querySelector('.tab.active').classList.remove('active');
  tab.classList.add('active');
  output.innerHTML = artifacts[tab.dataset.artifact];
  showToast(`Opened ${tab.textContent} evidence (mock event recorded).`);
}));

document.querySelector('#confidence').addEventListener('input', event => {
  document.querySelector('#confidence-value').textContent = `${event.target.value}%`;
});

document.querySelector('#prompt-form').addEventListener('submit', event => {
  event.preventDefault();
  const input = document.querySelector('#prompt');
  const question = input.value.trim();
  if (!question) return;

  document.querySelector('#starter-thinking')?.remove();
  const safeQuestion = question.replace(/[<>&]/g, character => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' })[character]);
  conversation.insertAdjacentHTML('beforeend', `<article class="message user"><p>${safeQuestion}</p></article><article class="message assistant thinking" id="active-thinking" aria-label="Assistant is thinking"><i></i><i></i><i></i></article>`);
  input.value = '';
  conversation.scrollTop = conversation.scrollHeight;
  showToast('Your message appeared immediately. Assistant is thinking…');

  setTimeout(() => {
    const response = document.createElement('article');
    response.className = 'message assistant';
    response.innerHTML = '<p>Mock response: compare the trace with the orchestration code, confirm the calls do not depend on one another, then validate both latency and correctness before changing concurrency.</p>';
    document.querySelector('#active-thinking')?.replaceWith(response);
    conversation.scrollTop = conversation.scrollHeight;
  }, 650);
});

const showValidation = () => {
  document.querySelector('#validation-result').innerHTML = '<div><h2>Result</h2><p>Mock validation selected latency and correctness checks. Parallelize only confirmed independent calls.</p></div><button class="text-button">Ready</button>';
  showToast('Mock validation completed.');
};

document.querySelector('#run-button').addEventListener('click', showValidation);
document.querySelector('#use-recommendation').addEventListener('click', showValidation);
document.querySelector('#submit-button').addEventListener('click', () => {
  showToast('Mock submission saved as an unscored candidate summary.');
});
