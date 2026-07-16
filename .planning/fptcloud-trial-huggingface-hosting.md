# Handoff — FPT Cloud trial Hugging Face hosting

## Last action

Installed the Hugging Face CLI as an isolated `uv` tool, verified that
`beratdgan/Qwen3-14B-Interview-Coach` is a 9.0 GB Q4 GGUF with no Hugging Face
Inference Provider mapping, and opened FPT AI Factory's Google sign-in flow in
Playwright. The named `fpttrial` browser session reset to `about:blank` and was
closed; Google authentication did **not** complete.

## Next action

Run `playwright-cli -s=fpttrial open --browser=chrome --persistent
'https://ai.fptcloud.jp/?ref=AI-KGQCJ4S11'`, choose **Continue with Google**, then
wait for the account holder to complete Google sign-in/MFA. After the FPT dashboard
loads, inspect the deployment options and stop before submitting the required card
and $1 verification top-up.

## Why

No project credential file exists, so account-holder authentication cannot be
automated safely. FPT's 30-day trial has a card-verification charge, while the
selected model has a CC BY-NC 4.0 licence that excludes commercial/corporate
interview platforms without the author's permission.

## Open threads

- Obtain explicit approval before entering card details or submitting the $1 top-up.
- Obtain the model author's commercial permission before deploying it for VibeProof.
- If a non-commercial proof of concept is approved, use an FPT GPU Container with
  llama.cpp or vLLM; do not expect the Hugging Face router to host this model.
- The working tree contains unrelated Cohere-milestone edits. This workflow also
  left `.playwright-cli/` and `fpt-landing.yaml` local browser artifacts; do not commit them.

## Do not

- Do **not** request, print, or store Google, FPT, Hugging Face, payment, or API credentials.
- Do **not** submit the trial top-up or create a billable GPU deployment without explicit approval.
- Do **not** use this non-commercial model for a corporate interview platform without written permission.
- Do **not** reset or overwrite the existing Cohere milestone changes.
