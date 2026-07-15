# VibeProof Documentation Organization Design

## Purpose

Reorganize the repository documentation so that VibeProof is the only active product direction. Preserve superseded KerjaProof, Unity/Godot, Miro, and debate material in a dated archive instead of deleting research history.

The active documentation must answer six questions quickly:

1. What is VibeProof?
2. Who uses it and where does it fit in hiring?
3. What does the candidate and recruiter experience look like?
4. What is included in the MVP?
5. What evidence is captured and how is it scored?
6. Which product decisions, assumptions, and limitations are current?

## Scope

This change covers Markdown documents and research PDFs under `docs/`, plus the repository root `README.md`.

It does not change:

- application code or runtime behavior;
- session logging scripts or generated usage data;
- assessment implementation;
- source research content inside archived PDFs;
- Git history.

## Chosen approach

Use a small canonical documentation set and a dated archive.

This approach was selected over:

- leaving all current documents active and adding deprecation notices, which would preserve conflicting navigation and duplicated claims;
- combining everything into one large document, which would be difficult to maintain and review;
- permanently deleting old material, which would remove useful research provenance and design history.

## Canonical information architecture

```text
README.md

docs/
|-- README.md
|-- product/
|   |-- product-brief.md
|   |-- user-scenario.md
|   `-- mvp-scope.md
|-- assessment/
|   `-- evidence-and-scoring.md
|-- research/
|   `-- validation-and-market.md
|-- decisions.md
|-- hackathon/
|   `-- codex-usage/
|-- archive/
|   `-- 2026-07-pre-vibeproof/
|       |-- README.md
|       |-- kerjaproof/
|       |-- miro/
|       `-- product-debates/
`-- superpowers/
    `-- specs/
```

### Root `README.md`

Provide a concise repository landing page with:

- VibeProof name and positioning;
- the problem and product promise;
- the core candidate-to-recruiter flow;
- current MVP summary;
- links to the canonical documents;
- the responsible-assessment boundary.

Remove time-sensitive hackathon schedules and the superseded KerjaProof narrative from the active landing page.

### `docs/README.md`

Serve as the only documentation index. Describe which files are canonical, which folder contains generated operational records, and where historical research is archived.

### `docs/product/product-brief.md`

Define:

- the problem;
- target buyer and user;
- product statement;
- hiring-funnel position;
- competitive wedge;
- non-goals;
- responsible positioning.

Use VibeProof and the current tagline consistently.

### `docs/product/user-scenario.md`

Describe the end-to-end candidate and recruiter journeys using the homepage-latency scenario:

- invitation and consent;
- mission briefing;
- metrics, logs, traces, code, and AI tools;
- hypothesis formation and revision;
- verification and final submission;
- Proof Replay and human review.

Godot or a 3D office may be described only as a replaceable presentation experiment. It must not be presented as part of the engineering signal or required MVP.

### `docs/product/mvp-scope.md`

Define one complete vertical slice:

- one controlled homepage-latency incident;
- one candidate workspace;
- five evidence and assistance tools;
- hypothesis capture;
- structured submission;
- deterministic scoring;
- one recruiter Proof Replay;
- explicit build and defer lists;
- success criteria.

### `docs/assessment/evidence-and-scoring.md`

Define:

- observable event schema;
- assessment dimensions;
- deterministic scoring principles;
- treatment of time, prompts, tokens, and tool counts as context rather than direct competence measures;
- recruiter report contents;
- constrained use of LLM analysis;
- privacy, fairness, accessibility, and human-review boundaries.

### `docs/research/validation-and-market.md`

Consolidate current research and market evidence:

- work-sample and game-based assessment rationale;
- automation-bias and metacognition relevance;
- Malaysian market hypothesis;
- Codility and CodeSignal comparison;
- validation plan;
- unvalidated assumptions;
- regulatory and fairness considerations;
- external source links.

Clearly separate supplied evidence, external research, product hypotheses, and claims requiring future validation.

### `docs/decisions.md`

Maintain a concise current decision record:

- VibeProof is the canonical name;
- AI use is allowed;
- ownership and verification are assessed;
- the product complements existing screening tools and human interviews;
- observable evidence is reported without claiming access to private thoughts;
- a focused engineering workspace is the baseline MVP;
- Godot/3D is optional and must not affect the engineering score;
- automatic hiring and rejection are out of scope;
- open decisions remain visibly separate from settled decisions.

## Source-to-destination mapping

| Current source | Canonical content destination | Historical file destination |
|---|---|---|
| Root `README.md` | New root `README.md` | Git history; no duplicate archive required |
| `01-problem-and-research-validation.md` | Product brief and validation document | `archive/.../kerjaproof/` |
| `02-product-concept-and-mvp.md` | Product brief, user scenario, and MVP scope | `archive/.../kerjaproof/` |
| `03-vibe-coding-assessment.md` | Assessment and scoring document | `archive/.../kerjaproof/` |
| `04-psychology-and-neuroscience.md` | Validation and responsible-assessment sections | `archive/.../kerjaproof/` |
| `05-unity-3d-feasibility.md` | Current 3D decision summary | `archive/.../kerjaproof/` |
| `06-branding-and-positioning.md` | VibeProof product brief where still relevant | `archive/.../kerjaproof/` |
| `07-hackathon-delivery-plan.md` | MVP success criteria where current | `archive/.../kerjaproof/` |
| `08-pitch-and-claims.md` | Product brief and responsible-assessment boundaries | `archive/.../kerjaproof/` |
| `09-miro-board-synthesis.md` | User scenario, event model, and assessment document | `archive/.../miro/` |
| `My First Board.pdf` | Source only | `archive/.../miro/` |
| `Research Validation & Industry Evidence (1).pdf` | Source only | `archive/.../kerjaproof/` |
| `ideas/01-decision-log.md` | `docs/decisions.md` | `archive/.../product-debates/` |
| `ideas/02-market-and-competitor-debate.md` | Validation and market document | `archive/.../product-debates/` |
| `ideas/03-ownership-challenge-concept.md` | Product brief, user scenario, assessment, and MVP scope | `archive/.../product-debates/` |
| `ideas/04-objections-and-responses.md` | Product brief and decision record | `archive/.../product-debates/` |
| `ideas/05-open-questions-and-validation.md` | Validation document and decision record | `archive/.../product-debates/` |

The existing `docs/research/meng/README.md` and `ideas/README.md` become unnecessary after canonical navigation is established. Their historical context will be summarized in the archive README; Git history continues to preserve their exact prior versions.

## Archive policy

The archive is read-only historical context, not canonical guidance.

`docs/archive/2026-07-pre-vibeproof/README.md` must explain:

- why the material was archived;
- the date of the reorganization;
- which product directions are superseded;
- that active decisions live in `docs/decisions.md`;
- that archived claims and implementation recommendations may conflict with the current product.

No source PDF or substantive historical document will be permanently deleted. Index-only files made redundant by the move may be removed because Git history preserves them and the archive README replaces their navigational purpose.

## Naming and language rules

- Use `VibeProof` for the product.
- Use `Build with AI. Prove you know why it works.` as the primary tagline.
- Use `Ownership Challenge` for the assessment format.
- Use `Proof Replay` for the recruiter evidence report.
- Describe actions as observable evidence, not private thought extraction.
- Describe AI use as allowed and evaluated through verification and ownership.
- Do not claim predictive validity, psychometric validation, cheating detection, or automatic hiring suitability.
- Fix mojibake and corrupted punctuation in active documents.
- Prefer short, direct sentences and stable relative links.

## Migration sequence

1. Create canonical directories and documents from the approved sources.
2. Rewrite the root README and create `docs/README.md`.
3. Create the archive README and archive directories.
4. Move superseded source documents and PDFs into the archive.
5. Remove redundant old index files and empty directories.
6. Update all repository-local Markdown links.
7. Search active documentation for conflicting brand and platform language.
8. Validate Markdown structure and local links.
9. Review the final Git diff to ensure operational logs and unrelated user changes were preserved.

## Error handling and preservation

- Do not overwrite unrelated working-tree changes.
- Use explicit file mappings rather than wildcard moves.
- Create destination directories before moving files.
- Verify every source exists before moving any group.
- Stop if a destination already contains a conflicting file.
- Keep generated session logs in `docs/hackathon/codex-usage/`.
- Do not modify the contents of archived PDFs.
- If a local link cannot be mapped confidently, retain the source path in the archive README and report the unresolved link.

## Verification

Completion requires all of the following:

1. `git diff --check` returns no errors.
2. Every relative Markdown link in active documents resolves to a file or heading where applicable.
3. Active documents contain no `KerjaProof` references except an intentional historical note.
4. Active documents do not present Unity, Godot, or 3D navigation as required for the MVP.
5. Active documents do not claim thought reading, AI-use detection, automatic hiring, or validated job-performance prediction.
6. The archived PDFs and substantive source Markdown files exist at their mapped destinations.
7. The old `docs/research/meng/` active tree no longer appears in canonical navigation.
8. Session-logging files and unrelated working-tree changes remain preserved.
9. `git status --short` contains only intended documentation changes and pre-existing unrelated changes.

## Completion outcome

After implementation, a new contributor should be able to start at the root README, understand VibeProof in under two minutes, follow one canonical path through the product and assessment documents, and find historical research only when intentionally entering the archive.
