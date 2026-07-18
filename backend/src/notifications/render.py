"""Report email rendering — the (subject, html, text) template, transport-free.

Gmail-safe HTML rules (Gmail strips <style>/<head>, CSS :hover, <script>, class-based CSS, and
proxies external assets): every style is INLINE, layout is nested <table>s, colors are inline
backgrounds, there are no images and no hover tooltips. React/shadcn/Tailwind are unusable in
email for exactly these reasons — this is hand-built inline CSS on purpose. The palette matches
the Godot "Incident Room" app (navy + cream) so the report reads as the same product.

Assessment boundaries are visible in the email itself (D007/D009, docs/decisions.md):
  Layer 1 is the ONLY scored layer (green chip); Layer 2 prints its label verbatim with an amber
  "not scored" chip and leads with the AI's descriptive judgement (score demoted to a chip, not a
  headline); Layer 3 shows a slate "context only" chip AND each index's formula + inputs so the
  arithmetic is auditable, never a hidden grade.

Kept transport-free (no smtplib/urllib) so notifications/service.py can send the html/text over
either the Brevo HTTP API (htmlContent) or SMTP (add_alternative), and so it is unit-testable
without a network.
"""
from html import escape

# Layman one-liners, sourced from docs/backend/04-metrics-rubrics.md. Static: the metric IDs are
# frozen, so this never needs a computed input and can't drift from a value.
_GLOSSARY: dict[str, str] = {
    "evidence_coverage": "Did they check the key evidence before concluding?",
    "verification_discipline": "Did they test/verify AI suggestions instead of accepting them blindly?",
    "problem_framing": "How clearly the problem was defined before investigating.",
    "investigation_strategy": "Whether each step followed logically from the last finding.",
    "hypothesis_quality": "Whether their theories were testable and tied to evidence.",
    "evidence_use": "How well clues were connected into a conclusion.",
    "prompt_precision": "How specific and context-rich their AI requests were.",
    "problem_decomposition": "Whether the problem was broken into clear sub-tasks.",
    "communication_clarity": "Whether reasoning, risks and rollback were explained plainly.",
    "e_p": "Quality achieved relative to how many prompts were used.",
    "epi": "Quality per 1,000 AI tokens — a rough cost-efficiency view.",
    "investigation_entropy": "How evenly attention was spread across evidence (breadth vs tunnel vision).",
    "hypothesis_convergence": "How quickly they reached the correct theory.",
    "ai_reliance": "How often AI output was accepted unchanged.",
}

_INDEX_NAMES = {
    "e_p": "Prompt Efficiency (E_p)",
    "epi": "Economical Prompting (EPI)",
    "investigation_entropy": "Investigation Entropy",
    "hypothesis_convergence": "Hypothesis Convergence",
    "ai_reliance": "AI Reliance",
}

# --- palette: matched to the Godot Incident Room app (navy header/accents, cream body/cards) ---
_BG, _CARD, _BORDER = "#f1e9d8", "#fdfaf3", "#e6dcc6"
_INK, _MUTED, _NAVY = "#1f2a44", "#7a7460", "#1c2b4d"
_ROW_ALT, _HEAD_BG = "#f7f1e3", "#f3ecdb"
_SCORED, _AI, _CTX = "#2f7d4f", "#b8791f", "#5b6472"
_STATUS = {"met": "#2f7d4f", "missed": "#b23b3b", "excluded": "#94a3b8", "partial": "#b8791f"}
_MONO = "Consolas,Menlo,'Courier New',monospace"


def _fmt(value: object) -> str:
    if isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        return str(int(value)) if value.is_integer() else f"{value:.2f}"
    return str(value)


def _human(key: str) -> str:
    return _INDEX_NAMES.get(key, key.replace("_", " ").title())


def _pill(text: str, color: str) -> str:
    return (f"<span style=\"display:inline-block;padding:2px 9px;border-radius:11px;"
            f"background:{color};color:#fff;font-size:11px;font-weight:600;letter-spacing:.3px\">"
            f"{escape(text)}</span>")


def _section(title: str, chip: str, chip_color: str, body: str) -> str:
    return (
        f"<tr><td style=\"padding:24px 28px 0\">"
        f"<div style=\"border-left:4px solid {chip_color};padding-left:11px\">"
        f"<span style=\"font-size:16px;font-weight:700;color:{_INK}\">{escape(title)}</span>&nbsp;&nbsp;"
        f"{_pill(chip, chip_color)}</div></td></tr>"
        f"<tr><td style=\"padding:12px 28px 0\">{body}</td></tr>"
    )


def _table(head: list[str], rows: list[list[str]]) -> str:
    ths = "".join(
        f"<td style=\"padding:8px 10px;background:{_HEAD_BG};border-bottom:2px solid {_BORDER};"
        f"font-size:11px;text-transform:uppercase;letter-spacing:.4px;color:{_MUTED};"
        f"font-weight:700\">{escape(h)}</td>" for h in head
    )
    trs = ""
    for i, row in enumerate(rows):
        bg = _CARD if i % 2 == 0 else _ROW_ALT
        tds = "".join(
            f"<td style=\"padding:9px 10px;border-bottom:1px solid {_BORDER};font-size:13px;"
            f"color:{_INK};vertical-align:top\">{cell}</td>" for cell in row  # cell is pre-escaped HTML
        )
        trs += f"<tr style=\"background:{bg}\">{tds}</tr>"
    return (f"<table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" "
            f"style=\"border-collapse:collapse;border:1px solid {_BORDER};border-radius:8px\">"
            f"<tr>{ths}</tr>{trs}</table>")


def _layer1(det: dict) -> str:
    rows = [
        [escape(c.get("label", c["criterion_id"])), f"<b>{_fmt(c['points'])}</b>",
         _pill(str(c.get("status", "")), _STATUS.get(c.get("status", ""), _CTX))]
        for c in det.get("criteria", [])
    ]
    caption = f"<p style=\"margin:0 0 10px;color:{_MUTED};font-size:12px\">The only scored layer — every point cites logged evidence.</p>"
    return _section("Layer 1 — Deterministic score", "SCORED", _SCORED, caption + _table(["Criterion", "Points", "Status"], rows))


def _hypotheses(hyps: list[dict]) -> str:
    if not hyps:
        return ""
    rows = [
        [escape(str(h.get("hypothesis_id", ""))), f"v{h.get('version', '')}",
         f"{h.get('confidence', '')}%"]
        for h in hyps
    ]
    head = (f"<p style=\"margin:18px 0 6px;font-size:13px;font-weight:700;color:{_INK}\">"
            f"Hypotheses recorded</p>")
    return head + _table(["Hypothesis", "Version", "Confidence"], rows)


def _layer2(ai: dict, hyps: list[dict]) -> str:
    # Description-led: lead with each dimension's justification (the AI's judgement); the x/5 is a
    # demoted chip, NOT a headline, so Layer 2 doesn't read as grading (it is labeled "not scored").
    blocks = ""
    for d in ai.get("dimensions", []):
        chip = _pill(f"{_fmt(d.get('score'))}/{d.get('scale', 5)}", _CTX)
        flag = _pill("⚑ flagged", _STATUS["missed"]) if d.get("flagged") else ""
        just = escape(d.get("justification", "") or "—")
        blocks += (
            f"<p style=\"margin:12px 0 2px;font-size:14px;color:{_INK}\"><b>{escape(_human(str(d.get('dimension', ''))))}</b> {chip} {flag}</p>"
            f"<p style=\"margin:0;font-size:13px;color:{_MUTED}\">{just}</p>"
        )
    narrative = escape(ai.get("narrative", {}).get("text", ""))
    narr = (f"<p style=\"margin:16px 0 0;padding:12px 14px;background:#fbf4e3;border-radius:8px;"
            f"font-size:13px;color:#6f5a2c;font-style:italic\">{narrative}</p>") if narrative else ""
    # Label shown VERBATIM — it is what makes the non-scoring visible (D007/D009).
    caption = (f"<p style=\"margin:0 0 4px;color:{_MUTED};font-size:12px\">{escape(ai.get('label', ''))} "
               f"— the model's qualitative judgement; scores are shown only as small chips, for human interpretation.</p>")
    return _section("Layer 2 — AI analysis", "AI OPINION · NOT SCORED", _AI,
                    caption + blocks + _hypotheses(hyps) + narr)


def _l3_meaning(i: dict) -> str:
    formula = (f"<div style=\"font-family:{_MONO};font-size:12px;color:{_INK};margin-top:3px\">"
               f"{escape(i.get('formula', ''))}</div>")
    scalars = ", ".join(
        f"{k}={_fmt(v)}" for k, v in (i.get("inputs") or {}).items()
        if isinstance(v, (int, float)) and not isinstance(v, bool)
    )
    inputs = f"<div style=\"font-size:11px;color:{_MUTED}\">{escape(scalars)}</div>" if scalars else ""
    return f"<span style=\"color:{_MUTED}\">{escape(_GLOSSARY[i['index_id']])}</span>{formula}{inputs}"


def _layer3(ctx: dict) -> str:
    if not ctx.get("ai_used", True):
        body = (f"<p style=\"margin:0;padding:12px 14px;background:{_ROW_ALT};border:1px solid {_BORDER};"
                f"border-radius:8px;font-size:13px;color:{_MUTED}\">No AI assistance used in this session.</p>")
    else:
        rows = [
            [escape(_human(i["index_id"])),
             f"<b>{_fmt(i['value']) if i.get('available', True) else 'n/a'}</b>",
             _l3_meaning(i)]
            for i in ctx.get("indices", [])
            if i["index_id"] in _GLOSSARY  # skip raw_counts (timeline aggregates, not a single-value index)
        ]
        body = _table(["Index", "Value", "Meaning & formula"], rows)
    caption = f"<p style=\"margin:0 0 10px;color:{_MUTED};font-size:12px\">Context only — never scored (D009). Efficiency numbers are not competence.</p>"
    return _section("Layer 3 — Context indices", "CONTEXT ONLY", _CTX, caption + body)


def _questions(questions: list[str]) -> str:
    if not questions:
        return ""
    items = "".join(f"<li style=\"margin:0 0 6px\">{escape(q)}</li>" for q in questions)
    return _section("Suggested interview questions", "FOLLOW-UP", _NAVY,
                    f"<ul style=\"margin:0;padding-left:20px;font-size:13px;color:{_INK}\">{items}</ul>")


def _appendix(report: dict) -> str:
    groups = [
        ("Scored (Layer 1)", [c["criterion_id"] for c in report["scores"]["deterministic"].get("criteria", [])]),
        ("AI opinion, not scored (Layer 2)", [d.get("dimension") for d in report["scores"]["ai_analysis"].get("dimensions", [])]),
        ("Context only, never scored (Layer 3)", [i["index_id"] for i in report["scores"]["context_indices"].get("indices", [])]),
    ]
    blocks = ""
    for title, ids in groups:
        items = "".join(
            f"<li style=\"margin:0 0 4px\"><b>{escape(_human(i))}</b> — {escape(_GLOSSARY[i])}</li>"
            for i in ids if i in _GLOSSARY
        )
        if items:
            blocks += (f"<p style=\"margin:10px 0 2px;font-size:12px;font-weight:700;color:{_INK}\">{escape(title)}</p>"
                       f"<ul style=\"margin:0;padding-left:18px;font-size:12px;color:{_MUTED}\">{items}</ul>")
    body = f"<div style=\"padding:14px 16px;background:{_ROW_ALT};border:1px solid {_BORDER};border-radius:8px\">{blocks}</div>"
    return _section("Appendix — what these mean", "GLOSSARY", _CTX, body)


def render_report_email(report: dict) -> tuple[str, str, str]:
    """(subject, html, text) from a build_report() dict. Layers stay visually separated and labeled."""
    scores = report["scores"]
    det = scores["deterministic"]
    hyps = report.get("hypotheses", [])
    name = escape(report.get("session", {}).get("display_name") or "Candidate")
    total, mx = _fmt(det.get("total")), _fmt(det.get("max"))
    subject = f"Your VibeProof assessment result ({total}/{mx})"

    header = (
        f"<tr><td style=\"background:{_NAVY};border-radius:12px 12px 0 0;padding:24px 28px\">"
        f"<div style=\"color:#ffffff;font-size:21px;font-weight:800;letter-spacing:.2px\">VibeProof</div>"
        f"<div style=\"color:#c9d4ea;font-size:13px;margin-top:2px\">Incident Room — assessment result</div>"
        f"</td></tr>"
    )
    hero = (
        f"<tr><td style=\"padding:22px 28px 0\">"
        f"<p style=\"margin:0 0 14px;font-size:14px;color:{_INK}\">Hi {name}, here is your Proof Replay summary. "
        f"<b>This is an assessment aid, not an employment decision.</b></p>"
        f"<table cellspacing=\"0\" cellpadding=\"0\"><tr>"
        f"<td style=\"background:{_NAVY};border-radius:10px;padding:12px 20px\">"
        f"<span style=\"color:#ffffff;font-size:26px;font-weight:800\">{total} / {mx}</span>"
        f"<span style=\"color:#c9d4ea;font-size:12px;display:block\">deterministic score</span></td>"
        f"</tr></table></td></tr>"
    )
    footer = (
        f"<tr><td style=\"padding:24px 28px 26px\">"
        f"<hr style=\"border:0;border-top:1px solid {_BORDER};margin:0 0 12px\">"
        f"<p style=\"margin:0;font-size:11px;color:{_MUTED}\">Only Layer 1 is scored. Layer 2 is labeled AI opinion "
        f"requiring human review; Layer 3 is context, never a grade. Generated by the VibeProof Evaluation Engine.</p>"
        f"</td></tr>"
    )

    inner = (
        f"<table width=\"640\" cellspacing=\"0\" cellpadding=\"0\" "
        f"style=\"max-width:640px;width:100%;background:{_CARD};border:1px solid {_BORDER};"
        f"border-radius:12px;border-collapse:separate\">"
        f"{header}{hero}"
        f"{_layer1(det)}{_layer2(scores['ai_analysis'], hyps)}{_layer3(scores['context_indices'])}"
        f"{_questions(report.get('interview_questions', []))}{_appendix(report)}{footer}"
        f"</table>"
    )
    html = (
        f"<div style=\"background:{_BG};padding:24px 12px;"
        f"font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif\">"
        f"<table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr>"
        f"<td align=\"center\">{inner}</td></tr></table></div>"
    )

    # text/plain fallback — same order, no styling.
    lines = [
        "VibeProof — assessment result (assessment aid, not an employment decision)",
        f"\nLayer 1 (SCORED): {total}/{mx}",
        *[f"  - {c.get('label', c['criterion_id'])}: {_fmt(c['points'])} ({c.get('status', '')})"
          for c in det.get("criteria", [])],
        f"\nLayer 2 ({scores['ai_analysis'].get('label', '')}):",
        *[f"  - {_human(str(d.get('dimension')))} ({_fmt(d.get('score'))}/{d.get('scale', 5)}): {d.get('justification', '')}"
          for d in scores["ai_analysis"].get("dimensions", [])],
    ]
    if hyps:
        lines.append("  Hypotheses recorded:")
        lines += [f"    - {h.get('hypothesis_id')} v{h.get('version')} ({h.get('confidence')}%)" for h in hyps]
    lines.append("\nLayer 3 (context only, never scored):")
    ctx = scores["context_indices"]
    if not ctx.get("ai_used", True):
        lines.append("  - No AI assistance used.")
    else:
        lines += [f"  - {_human(i['index_id'])}: {_fmt(i['value']) if i.get('available', True) else 'n/a'}  [{i.get('formula', '')}]"
                  for i in ctx.get("indices", []) if i["index_id"] in _GLOSSARY]
    text = "\n".join(lines)
    return subject, html, text
