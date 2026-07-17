# Handoff — FPT Cloud trial Hugging Face hosting

## Last action

Signed in to FPT AI Factory via **Continue with Google** (account holder completed
sign-in/MFA in a headed `fpttrial` Chrome). Landed on workspace **`AI-KQU32F5YA`**,
region **Japan (JPN01)**, **Total Balance $101.00** (the $1 card verification appears
already applied — the $100 grant + $1 = $101). Inspected both deployment paths and
stopped at the GPU Container "Create Container" button without clicking it.

Deployment options observed:

- **Model Hub / serverless Inference API** serves the **base `Qwen/Qwen3-14B`**
  (Apache-2.0) plus ~50 Qwen variants — API-key + Inference API, no GPU to manage.
  Does **not** carry the fine-tune `beratdgan/Qwen3-14B-Interview-Coach`.
- **GPU Container (self-host)**: only in-stock instance is **1×H200, 141 GB VRAM,
  $6.60/hour** (On-Demand, billed every 15 min, tax incl.). 2×–8×H200 all Out of
  Stock. Defaults: Jupyter template (changeable to custom), HTTP port 8000 (vLLM).
  $101 balance ≈ ~15 hours. The 9 GB Q4 GGUF fits trivially in one H200.

## Next action

Decide the path (see Open threads): (a) call base `Qwen/Qwen3-14B` via FPT's
serverless Inference API — clean Apache-2.0 licence, cheapest; or (b) self-host the
fine-tune on a 1×H200 GPU Container — needs the author's commercial permission first
(CC BY-NC 4.0) and explicit spend approval ($6.60/hr). Do not click "Create
Container" or add credits without explicit approval.

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
