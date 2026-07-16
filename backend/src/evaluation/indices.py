"""Layer 3 — ContextIndices: pure formulas over the event log, NEVER scored (D009: efficiency is
not competence). `compute_indices(events, Q, scenario=None) -> list[dict]`. Exact formulas from
brief 04. Zero-safety (Codex MEDIUM finding): every index guards its own division and NEVER emits
NaN/inf — a missing prerequisite produces `available: false` + a `reason`, not a crash or a bogus
number.

`scenario` is accepted (beyond the orchestrator's 2-arg pseudocode in brief 01) so entropy can read
the artifact_id -> evidence_type map already authored once in the scenario JSON (`registry.py`'s
`Scenario.evidence_type_by_artifact`) instead of re-typing it here (the same "don't re-type
scenario data" principle as Codex finding #1). It stays pure — no I/O, deterministic — and falls
back to the one shipped scenario's known mapping when omitted (e.g. in unit tests).
"""
import math

# Fallback for callers that don't pass `scenario` (unit tests exercising indices.py in isolation).
# Mirrors the one MVP scenario's artifact_id -> evidence_type map (homepage_latency_v1.json).
_FALLBACK_EVIDENCE_TYPES = {
    "metrics_overview": "metrics",
    "application_logs": "logs",
    "homepage_trace": "trace",
    "homepage_orchestrator": "source_code",
}
_EVIDENCE_TYPES = ("metrics", "logs", "trace", "source_code")


def _unavailable(index_id: str, formula: str, inputs: dict, reason: str) -> dict:
    return {"index_id": index_id, "value": None, "formula": formula, "inputs": inputs, "available": False, "reason": reason}


def _available(index_id: str, value: float, formula: str, inputs: dict) -> dict:
    return {"index_id": index_id, "value": value, "formula": formula, "inputs": inputs, "available": True}


def _evidence_type_counts(views: list[dict], scenario) -> dict[str, int]:
    mapping = scenario.evidence_type_by_artifact if scenario is not None else _FALLBACK_EVIDENCE_TYPES
    counts = {t: 0 for t in _EVIDENCE_TYPES}
    for v in views:
        etype = mapping.get(v["payload"].get("artifact_id"))
        if etype in counts:
            counts[etype] += 1
    return counts


def _distinct_hypothesis_order(events: list[dict]) -> list[str]:
    order: list[str] = []
    seen: set[str] = set()
    for e in events:
        if e["event_type"] in ("hypothesis_recorded", "hypothesis_revised"):
            hid = e["payload"].get("hypothesis_id")
            if hid and hid not in seen:
                seen.add(hid)
                order.append(hid)
    return order


def compute_indices(events: list[dict], q: float, scenario=None) -> list[dict]:
    prompts = [e for e in events if e["event_type"] == "ai_prompt_submitted"]
    responses = [e for e in events if e["event_type"] == "ai_response_received"]
    dispositions = [e for e in events if e["event_type"] == "ai_suggestion_dispositioned"]
    tests = [e for e in events if e["event_type"] == "test_executed"]
    views = [e for e in events if e["event_type"] == "evidence_viewed"]
    hyp_events = [e for e in events if e["event_type"] in ("hypothesis_recorded", "hypothesis_revised")]

    p_total = len(prompts)
    ai_used = p_total > 0

    failed_tests = sum(1 for t in tests if t["payload"].get("status") == "failed")
    rejected = sum(1 for d in dispositions if d["payload"].get("option_id") == "reject_suggestion")
    r_fail = (failed_tests + rejected) / max(1, p_total)

    total_tokens = sum(
        r["payload"].get("usage", {}).get("input_tokens", 0) + r["payload"].get("usage", {}).get("output_tokens", 0)
        for r in responses
    )

    n_disp_total = len(dispositions)
    accept_immediately = sum(1 for d in dispositions if d["payload"].get("option_id") == "accept_immediately")

    out: list[dict] = []

    # 1. Prompt Efficiency Index
    ep_inputs = {"Q": q, "P_total": p_total, "R_fail": r_fail}
    if not ai_used:
        out.append(_unavailable("e_p", "Q / (1 + 0.05*P_total*(1+R_fail))", ep_inputs, "no AI used"))
    else:
        e_p = q / (1 + 0.05 * p_total * (1 + r_fail))
        out.append(_available("e_p", e_p, "Q / (1 + 0.05*P_total*(1+R_fail))", ep_inputs))

    # 2. Economical Prompting Index
    epi_inputs = {"Q": q, "T": total_tokens}
    if not ai_used:
        out.append(_unavailable("epi", "(Q/100) / (T/1000)", epi_inputs, "no AI used"))
    elif total_tokens == 0:
        out.append(_unavailable("epi", "(Q/100) / (T/1000)", epi_inputs, "no token usage recorded"))
    else:
        epi = (q / 100) / (total_tokens / 1000)
        out.append(_available("epi", epi, "(Q/100) / (T/1000)", epi_inputs))

    # 3. Investigation Entropy
    type_counts = _evidence_type_counts(views, scenario)
    total_views = sum(type_counts.values())
    entropy_inputs = {"counts": type_counts}
    if total_views == 0:
        out.append(_unavailable("investigation_entropy", "-sum(p*log2(p)) / log2(4)", entropy_inputs, "no evidence viewed"))
    else:
        h = 0.0
        for count in type_counts.values():
            if count == 0:
                continue
            p = count / total_views
            h -= p * math.log2(p)
        h_norm = h / math.log2(len(_EVIDENCE_TYPES))
        out.append(_available("investigation_entropy", h_norm, "-sum(p*log2(p)) / log2(4)", entropy_inputs))

    # 4. Hypothesis Convergence — absent correct hypothesis is a real value (0), not "unavailable".
    hyp_order = _distinct_hypothesis_order(events)
    if "sequential_independent_calls" in hyp_order:
        r = hyp_order.index("sequential_independent_calls") + 1
        out.append(_available("hypothesis_convergence", 1 / r, "1/r", {"r": r, "hypothesis_order": hyp_order}))
    else:
        out.append(_available("hypothesis_convergence", 0.0, "1/r", {"r": None, "hypothesis_order": hyp_order}))

    # 5. AI Reliance Ratio
    ar_inputs = {"N_accept_immediately": accept_immediately, "N_disp_total": n_disp_total}
    if n_disp_total == 0:
        out.append(_unavailable("ai_reliance", "N_accept_immediately / N_disp_total", ar_inputs, "no AI suggestions dispositioned"))
    else:
        out.append(_available("ai_reliance", accept_immediately / n_disp_total, "N_accept_immediately / N_disp_total", ar_inputs))

    # 6. Raw counts — displayed as timeline context, never scored in isolation.
    distinct_artifacts = {v["payload"].get("artifact_id") for v in views if v["payload"].get("artifact_id")}
    raw_counts = {
        "prompts": p_total,
        "total_tokens": total_tokens,
        "tool_calls": sum(1 for e in events if e["event_type"] == "tool_invoked"),
        "distinct_evidence_artifacts": len(distinct_artifacts),
        "investigation_order": [v["payload"].get("artifact_id") for v in views],
        "hypothesis_count": len(hyp_order),
        "iterations": len(hyp_events),
        "elapsed_active_ms": max((e.get("elapsed_active_ms", 0) for e in events), default=0),
    }
    out.append({
        "index_id": "raw_counts",
        "value": None,
        "formula": "plain aggregations — not a formula",
        "inputs": raw_counts,
        "available": True,
        "ai_used": ai_used,
    })

    return out
