# Backend Brief 01 — Evaluation Engine

> **For the executing agent:** runs exactly once, triggered by `POST /submit`. Three layers computed concurrently with `asyncio.gather`, results written to `grading_results`, then the report assembles from those rows + events. No LangGraph, no queues, no background workers — the demo can wait the ~10 s grading takes inline.

Depends on: briefs 00, 03; formulas and rubric anchors in brief 04. Terminology: `UBIQUITOUS_LANGUAGE.md`.

## Flow

```text
submit → load events + final_submission + scenario
       → asyncio.gather(
           rule_grader(events, submission, scenario),      # pure function
           rubric_panel(events, submission, scenario),     # 14 LLM calls, parallel
           context_indices(events, layer1_total)           # pure functions *
         )
       → write grading_results rows → status = graded
```

\* `context_indices` needs the Layer 1 total as input `Q`; run `rule_grader` first (it is microseconds), then gather the panel and indices together.

## Layer 1 — RuleGrader (deterministic, scored)

Pure function: `(events, submission, scenario) -> list[CriterionResult]`. Each result: `criterion_id`, `points`, `status` (met/missed/excluded), `evidence_refs` (event IDs — mandatory for met/missed).

Rules 1–9 are the canonical set from `docs/assessment/evidence-and-scoring.md`; rules 10–11 are the research-promoted deterministic measures. Detection conditions:

| # | criterion_id | Points | Detection over events |
|---|---|---|---|
| 1 | `trace_before_change` | +10 | first `evidence_viewed(homepage_trace)` precedes the first fix-proposing action (first `test_executed`, `decision_recorded`, or submission) |
| 2 | `narrowed_by_healthy_signals` | +10 | viewed `metrics_overview` AND no submission/hypothesis blaming `cpu_saturation` or `database_slowdown` after that view |
| 3 | `found_sequential_code` | +10 | `evidence_viewed(homepage_orchestrator)` before submission |
| 4 | `confirmed_independence` | +10 | `ai_suggestion_dispositioned` with option `verify_then_adapt` including `calls_independent`, OR submission assumptions include `calls_are_independent` with the code artifact viewed |
| 5 | `both_validations` | +10 | `validation_test_ids ⊇ {correctness_regression, p95_latency}` |
| 6 | `revised_on_contradiction` | +10 | any `hypothesis_revised` whose `trigger_evidence_ids` is non-empty |
| 7 | `cpu_scaling_unsupported` | −10 | `remediation_id == scale_cpu` |
| 8 | `blind_ai_acceptance` | −10 | any `ai_suggestion_dispositioned` with `accept_immediately` |
| 9 | `uncited_diagnosis` | −15 | `supporting_evidence_ids` empty |
| 10 | `evidence_coverage` | 0–10 | `round(10 × EC)` — formula in brief 04 |
| 11 | `verification_discipline` | 0–10 | `round(10 × VD)`; `excluded` when no AI suggestions were dispositioned — formula in brief 04 |

Max = 80 (six +10 rules plus EC and VD at 0–10 each; the negative rules subtract from the total but not the max). `layer1_normalized = max(0, total) / 80 × 100` — this is `Q` for Layer 3. Criteria whose evidence was unavailable (`technical_error.excluded_criterion_ids`) are `excluded` and removed from the max before normalizing (never penalize outages).

Equivalent-order fairness: conditions test *precedence and presence*, never a specific station order (D-rule from evidence-and-scoring.md).

## Layer 2 — RubricPanel (LLM, labeled AI analysis)

7 dimensions × 2 vendors = 14 parallel calls; plus 1 thinking-style narrative (single call, cheaper vendor). Dimensions and rubric anchors: brief 04.

- **Vendors:** Groq and NVIDIA NIM, both via the `openai` SDK with per-vendor `base_url`/`api_key` (env: `GROQ_API_KEY`, `NIM_API_KEY`, model IDs `GROQ_GRADER_MODEL`, `NIM_GRADER_MODEL`). One thin `Grader` dataclass, two configs — no LiteLLM.
- **Input per call:** the dimension's rubric + a compact evidence digest (relevant event excerpts only — prompts, hypotheses, dispositions, submission rationale), never the full raw log.
- **Output:** forced JSON: `{"score": 1-5, "justification": str, "cited_event_ids": [str]}`. Non-parsing output → one retry → that grader's row dropped.
- **Consensus:** median of available scores (with 2 vendors = their mean); `|a−b| ≥ 2` sets `flagged: true` (human review). One vendor down → `consensus: "single"`. Both down → layer omitted, report notes deterministic-only fallback (D007).
- **Provenance stored per row:** vendor, model ID, `rubric_version`, justification, cited events. LLM boundary rules apply: graders judge recorded evidence only, never invent events, never output an employment recommendation.

## Layer 3 — ContextIndices (pure formulas, never scored)

Compute E_p, EPI, Investigation Entropy, Hypothesis Convergence, AI Reliance Ratio + raw counts, exactly as specified in brief 04. Store with `layer='context_index'`, `detail` = `{formula, inputs}`. If no AI was used (`P_total == 0`): store `ai_used: false` and skip prompt/token indices.

## Interview-question suggestions

One additional LLM call (either vendor) generating 3–5 targeted follow-up questions from missed criteria and flagged dimensions — the D007-sanctioned LLM use. Stored in `detail` of a `layer='llm_rubric'`, `criterion_id='interview_questions'` row; failures are silent (nice-to-have).

## Definition of done

- Golden-path test: scripted event fixture of a strong session → rules 1–6 met, 10–11 high, no negatives.
- Contrast test: blind-acceptance fixture → rule 8 fires with the disposition event cited.
- Outage test: excluded criteria drop from max; normalization stays correct.
- Panel test with faked vendors: median, single-vendor, both-down, and flag paths all covered.
- Every `grading_results` row has non-empty `evidence_refs` for Layer 1 met/missed.
