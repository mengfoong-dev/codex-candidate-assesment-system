# VibeProof Documentation Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the conflicting active KerjaProof and VibeProof documentation trees with one concise VibeProof documentation set and a dated, non-canonical archive.

**Architecture:** The root README links to six canonical Markdown documents grouped by product, assessment, research, and decisions. Historical Markdown and PDFs move to `docs/archive/2026-07-pre-vibeproof/`, while generated agent-usage records remain untouched. Validation scripts check local links, active vocabulary, archive completeness, and diff hygiene.

**Tech Stack:** Markdown, PDF source files, Git, PowerShell, ripgrep (`rg`)

## Global Constraints

- Use `VibeProof` for the active product name.
- Use `Build with AI. Prove you know why it works.` as the primary tagline.
- Use `Ownership Challenge` for the assessment format.
- Use `Proof Replay` for the recruiter evidence report.
- Preserve all substantive historical Markdown and both source PDFs in the dated archive.
- Do not modify `docs/hackathon/codex-usage/` except through the repository session logger.
- Do not overwrite or discard unrelated working-tree changes.
- Do not present Godot, Unity, Phaser, or 3D navigation as required for the MVP.
- Do not claim thought reading, AI-use detection, automatic hiring suitability, predictive validity, or completed psychometric validation.
- Treat time, token counts, prompt counts, and tool-call counts as context, not direct measures of competence.
- Keep final hiring decisions with a human reviewer.

---

## File Structure

### Canonical files

- Modify: `README.md` - repository landing page and VibeProof summary.
- Create: `docs/README.md` - canonical documentation index.
- Create: `docs/product/product-brief.md` - problem, users, positioning, hiring-funnel role, and non-goals.
- Create: `docs/product/user-scenario.md` - candidate and recruiter journeys for the homepage-latency scenario.
- Create: `docs/product/mvp-scope.md` - one complete vertical slice, build/defer lists, and success criteria.
- Create: `docs/assessment/evidence-and-scoring.md` - observable events, scoring principles, Proof Replay, and responsible-assessment boundaries.
- Create: `docs/research/validation-and-market.md` - evidence, market hypothesis, competitors, assumptions, and validation roadmap.
- Create: `docs/decisions.md` - settled product decisions and open questions.

### Archive files

- Create: `docs/archive/2026-07-pre-vibeproof/README.md` - archive purpose and provenance.
- Move: `docs/research/meng/01-problem-and-research-validation.md` through `08-pitch-and-claims.md` to `docs/archive/2026-07-pre-vibeproof/kerjaproof/`.
- Move: `docs/research/meng/Research Validation & Industry Evidence (1).pdf` to `docs/archive/2026-07-pre-vibeproof/kerjaproof/`.
- Move: `docs/research/meng/09-miro-board-synthesis.md` and `docs/research/meng/My First Board.pdf` to `docs/archive/2026-07-pre-vibeproof/miro/`.
- Move: `docs/research/meng/ideas/01-decision-log.md` through `05-open-questions-and-validation.md` to `docs/archive/2026-07-pre-vibeproof/product-debates/`.
- Remove after migration: `docs/research/meng/README.md` and `docs/research/meng/ideas/README.md`; their exact prior content remains in Git history and their navigation role moves to the archive README.

### Preserved files

- Preserve: `docs/hackathon/codex-usage/README.md`.
- Preserve: `docs/hackathon/codex-usage/outcomes.md`.
- Preserve: `docs/hackathon/codex-usage/sessions.csv`.
- Preserve: `docs/superpowers/specs/2026-07-15-vibeproof-documentation-organization-design.md`.
- Preserve: `docs/superpowers/plans/2026-07-15-vibeproof-documentation-migration.md`.

---

### Task 1: Create the canonical navigation and product landing page

**Files:**
- Modify: `README.md`
- Create: `docs/README.md`

**Interfaces:**
- Consumes: the approved design specification and current VibeProof decisions.
- Produces: stable navigation links used by all contributors and later validation steps.

- [ ] **Step 1: Record the current working-tree state**

Run:

```powershell
git status --short
git diff -- README.md docs/research/meng/README.md
```

Expected: existing session-log edits, the previously created Miro synthesis, and the source Miro PDF remain visible; no files are reset or discarded.

- [ ] **Step 2: Rewrite the root README**

Replace the active KerjaProof and dated hackathon narrative with these sections:

```markdown
# VibeProof

> Build with AI. Prove you know why it works.

## What we are building
## User scenario
## What VibeProof measures
## MVP
## Documentation
## Responsible-assessment boundary
```

The summary must describe VibeProof as a short AI-allowed engineering Ownership Challenge that produces a human-reviewable Proof Replay.

- [ ] **Step 3: Create the documentation index**

Create `docs/README.md` with links to:

```markdown
- [Product brief](product/product-brief.md)
- [User scenario](product/user-scenario.md)
- [MVP scope](product/mvp-scope.md)
- [Evidence and scoring](assessment/evidence-and-scoring.md)
- [Research, validation, and market](research/validation-and-market.md)
- [Product decisions](decisions.md)
- [Historical archive](archive/2026-07-pre-vibeproof/README.md)
- [Agent usage records](hackathon/codex-usage/README.md)
```

- [ ] **Step 4: Verify navigation copy and vocabulary**

Run:

```powershell
rg -n "KerjaProof|Unity|Godot|Phaser|automatic.*(hire|reject)|read.*thought" README.md docs/README.md
```

Expected: no matches except an intentional archive description if one is included.

- [ ] **Step 5: Commit the canonical navigation**

Run:

```powershell
git add -- README.md docs/README.md
git diff --cached --check
git commit -m "docs: make VibeProof the canonical product"
```

Expected: commit succeeds with only `README.md` and `docs/README.md` staged.

---

### Task 2: Create the canonical product documents

**Files:**
- Create: `docs/product/product-brief.md`
- Create: `docs/product/user-scenario.md`
- Create: `docs/product/mvp-scope.md`

**Interfaces:**
- Consumes: `docs/research/meng/02-product-concept-and-mvp.md`, `docs/research/meng/09-miro-board-synthesis.md`, and `docs/research/meng/ideas/03-ownership-challenge-concept.md` before they move to the archive.
- Produces: the canonical product definition referenced by the root README and assessment documents.

- [ ] **Step 1: Create `product-brief.md`**

Include these sections:

```markdown
# VibeProof Product Brief
## Product statement
## Problem
## Target users
## Position in the hiring journey
## Value proposition
## Competitive wedge
## Non-goals
## Responsible positioning
```

The active product position is a verification layer between a portfolio, take-home, or baseline assessment and a human technical interview.

- [ ] **Step 2: Create `user-scenario.md`**

Include these sections:

```markdown
# VibeProof User Scenario
## Actors
## Scenario: Homepage Latency Spike
## Candidate journey
## Investigation workspace
## Submission
## Recruiter journey
## Proof Replay example
## Optional presentation experiments
```

Use the seeded signals from the Miro synthesis: p95 latency of 850 ms, CPU of 35%, healthy database and recommendation service, Redis hit rate of 42%, and sequential API calls as the hidden root cause.

- [ ] **Step 3: Create `mvp-scope.md`**

Include:

```markdown
# VibeProof MVP Scope
## MVP outcome
## Build
## Defer
## Data flow
## Failure handling
## Demo success criteria
## Post-MVP validation
```

The MVP must remain usable without 3D navigation and must produce one complete candidate session and one recruiter Proof Replay.

- [ ] **Step 4: Check cross-document consistency**

Run:

```powershell
rg -n "KerjaProof|Patch & Ship|Unity|required 3D|detect.*AI|read.*thought" docs/product
```

Expected: no conflicting brand, assessment-format, platform, or prohibited-claim matches.

- [ ] **Step 5: Commit the canonical product documents**

Run:

```powershell
git add -- docs/product/product-brief.md docs/product/user-scenario.md docs/product/mvp-scope.md
git diff --cached --check
git commit -m "docs: define the VibeProof product and user journey"
```

Expected: commit succeeds with the three product documents only.

---

### Task 3: Create assessment, research, and decision documents

**Files:**
- Create: `docs/assessment/evidence-and-scoring.md`
- Create: `docs/research/validation-and-market.md`
- Create: `docs/decisions.md`

**Interfaces:**
- Consumes: the current KerjaProof research files, VibeProof debate records, Miro synthesis, and approved design specification.
- Produces: the canonical evidence model, defensible claims, research basis, and product decision record.

- [ ] **Step 1: Create `evidence-and-scoring.md`**

Include:

```markdown
# Evidence and Scoring
## Measurement boundary
## Observable event model
## Assessment dimensions
## Deterministic scoring principles
## Contextual metrics
## Proof Replay
## LLM usage boundary
## Privacy, fairness, and accessibility
## Human review
```

The event model must include evidence viewed, searches, AI prompts and responses, tool invocations, hypothesis versions, confidence, tests, and final submission.

- [ ] **Step 2: Create `validation-and-market.md`**

Include:

```markdown
# Research, Validation, and Market
## Research rationale
## Psychology-informed design
## Market hypothesis
## Competitor context
## Unvalidated assumptions
## Validation plan
## Regulatory and fairness considerations
## Sources
```

Preserve direct external links from the current research and competitor documents, and label market and product-demand statements as hypotheses where evidence is incomplete.

- [ ] **Step 3: Create `decisions.md`**

Include:

```markdown
# VibeProof Product Decisions
## Settled decisions
## Presentation-layer decision
## Assessment boundaries
## Open decisions
## Change policy
```

Record a focused web engineering workspace as the baseline. Record Godot/3D as an optional presentation experiment that cannot affect the engineering score or become an MVP dependency.

- [ ] **Step 4: Scan for unsafe or contradictory claims**

Run:

```powershell
rg -n -i "read(s|ing)? (the )?(candidate'?s )?(mind|thought)|detect(s|ing)? (AI|cheat)|predict(s|ing)? job performance|automatic(ally)? (hire|reject)|validated psychometric" docs/assessment docs/research docs/decisions.md
```

Expected: matches appear only in explicit `do not claim` or limitation statements.

- [ ] **Step 5: Commit assessment, research, and decisions**

Run:

```powershell
git add -- docs/assessment/evidence-and-scoring.md docs/research/validation-and-market.md docs/decisions.md
git diff --cached --check
git commit -m "docs: consolidate VibeProof assessment and research"
```

Expected: commit succeeds with the three canonical documents only.

---

### Task 4: Archive superseded research and source material

**Files:**
- Create: `docs/archive/2026-07-pre-vibeproof/README.md`
- Move: the exact historical files listed in the File Structure section.
- Remove: `docs/research/meng/README.md`
- Remove: `docs/research/meng/ideas/README.md`

**Interfaces:**
- Consumes: all source documents after their canonical content has been consolidated.
- Produces: a complete, dated, non-canonical history with unmodified source PDFs.

- [ ] **Step 1: Verify every archive source before moving files**

Run a PowerShell list containing every expected source path and fail if any are absent:

```powershell
$sources = @(
  'docs/research/meng/01-problem-and-research-validation.md',
  'docs/research/meng/02-product-concept-and-mvp.md',
  'docs/research/meng/03-vibe-coding-assessment.md',
  'docs/research/meng/04-psychology-and-neuroscience.md',
  'docs/research/meng/05-unity-3d-feasibility.md',
  'docs/research/meng/06-branding-and-positioning.md',
  'docs/research/meng/07-hackathon-delivery-plan.md',
  'docs/research/meng/08-pitch-and-claims.md',
  'docs/research/meng/09-miro-board-synthesis.md',
  'docs/research/meng/My First Board.pdf',
  'docs/research/meng/Research Validation & Industry Evidence (1).pdf',
  'docs/research/meng/ideas/01-decision-log.md',
  'docs/research/meng/ideas/02-market-and-competitor-debate.md',
  'docs/research/meng/ideas/03-ownership-challenge-concept.md',
  'docs/research/meng/ideas/04-objections-and-responses.md',
  'docs/research/meng/ideas/05-open-questions-and-validation.md'
)
$missing = $sources | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missing) { throw "Missing archive sources: $($missing -join ', ')" }
```

Expected: no output and exit code 0.

- [ ] **Step 2: Create explicit archive directories and move each file**

Create:

```text
docs/archive/2026-07-pre-vibeproof/kerjaproof/
docs/archive/2026-07-pre-vibeproof/miro/
docs/archive/2026-07-pre-vibeproof/product-debates/
```

Use `Move-Item -LiteralPath` with explicit source and destination values. Do not use wildcard moves or recursive deletion.

- [ ] **Step 3: Create the archive README**

Document:

- the 15 July 2026 reorganization date;
- the superseded KerjaProof, Unity/3D, Miro, and debate explorations;
- the path to `docs/decisions.md` for current decisions;
- the rule that archived claims and recommendations are not canonical;
- a categorized inventory of every archived file.

- [ ] **Step 4: Remove redundant old indexes and empty directories**

Remove only:

```text
docs/research/meng/README.md
docs/research/meng/ideas/README.md
```

After confirming the directories are empty, remove `docs/research/meng/ideas/` and `docs/research/meng/`. Do not recursively remove a directory containing any unexpected file.

- [ ] **Step 5: Verify archive completeness**

Run:

```powershell
rg --files docs/archive/2026-07-pre-vibeproof | Sort-Object
Get-ChildItem -Recurse -File docs/archive/2026-07-pre-vibeproof | Measure-Object
```

Expected: one archive README plus 16 substantive historical source files, for 17 files total.

- [ ] **Step 6: Commit the archive migration**

Run:

```powershell
git add -A -- docs/research/meng docs/archive/2026-07-pre-vibeproof
git diff --cached --check
git diff --cached --summary
git commit -m "docs: archive pre-VibeProof research"
```

Expected: Git reports historical Markdown and PDFs as renames where detectable, redundant indexes as deletions, and the archive README as a new file.

---

### Task 5: Validate the complete documentation migration

**Files:**
- Modify only if validation finds a defect: canonical Markdown documents created in Tasks 1-3 or the archive README.

**Interfaces:**
- Consumes: the complete active documentation and archive.
- Produces: evidence that the repository has one navigable VibeProof direction and preserved historical sources.

- [ ] **Step 1: Validate whitespace and Git state**

Run:

```powershell
git diff --check HEAD~4..HEAD
git status --short
```

Expected: no whitespace errors; only pre-existing session-log modifications or unrelated user changes remain uncommitted.

- [ ] **Step 2: Validate all relative Markdown file links**

Run a Python or PowerShell link checker over active Markdown files that:

- ignores `http://`, `https://`, `mailto:`, and in-page `#anchor` links;
- URL-decodes relative paths;
- resolves them relative to the containing Markdown file;
- fails when a target does not exist.

Expected: zero broken local file links.

- [ ] **Step 3: Validate active vocabulary**

Run:

```powershell
rg -n "KerjaProof|Unity 3D|Patch & Ship" README.md docs/README.md docs/product docs/assessment docs/research docs/decisions.md
```

Expected: zero matches except an intentional historical comparison explicitly marked as superseded.

- [ ] **Step 4: Validate platform and claim boundaries**

Run:

```powershell
rg -n -i "required.*(Godot|Unity|Phaser|3D)|detect.*AI|automatic.*(hire|reject)|read.*thought|predict.*job performance" README.md docs/README.md docs/product docs/assessment docs/research docs/decisions.md
```

Expected: no required-platform matches; prohibited claims occur only inside explicit limitation language.

- [ ] **Step 5: Validate archive source count and PDF preservation**

Run:

```powershell
$archive = 'docs/archive/2026-07-pre-vibeproof'
$files = Get-ChildItem -Recurse -File -LiteralPath $archive
if ($files.Count -ne 17) { throw "Expected 17 archive files, found $($files.Count)" }
$pdfs = $files | Where-Object Extension -eq '.pdf'
if ($pdfs.Count -ne 2) { throw "Expected 2 archived PDFs, found $($pdfs.Count)" }
```

Expected: exit code 0.

- [ ] **Step 6: Review the final documentation surface**

Run:

```powershell
rg --files docs | Sort-Object
git log -5 --oneline --decorate
git status --short
```

Expected: active documentation contains only the canonical VibeProof files, operational logs, the archive, and Superpowers design/plan records.

- [ ] **Step 7: Commit validation fixes only if needed**

If any validation defect required edits, run:

```powershell
git add -- README.md docs/README.md docs/product docs/assessment docs/research docs/decisions.md docs/archive/2026-07-pre-vibeproof/README.md
git diff --cached --check
git commit -m "docs: fix VibeProof documentation links"
```

Expected: no commit is created when validation required no fixes.
