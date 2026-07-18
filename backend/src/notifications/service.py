"""Email the graded report to the candidate — optional and strictly best-effort.

If SMTP is not configured (no creds) or the recipient is not an email address, this is a no-op.
Sending is never allowed to block or fail a submission: grading already degrades gracefully, and
report delivery is a nice-to-have layered on top. Callers wrap this so any exception is swallowed.

smtplib is synchronous, so the blocking send runs in a threadpool (the one place the async stack
hands off to a sync library).
"""
import smtplib
from email.message import EmailMessage

from starlette.concurrency import run_in_threadpool

from src.config import get_settings


def _looks_like_email(value: str) -> bool:
    return bool(value) and "@" in value and "." in value.rsplit("@", 1)[-1]


def _format_body(report: dict) -> str:
    scores = report.get("scores", {})
    det = scores.get("deterministic", {})
    lines = ["Your VibeProof assessment report", ""]
    total, maxv = det.get("total"), det.get("max")
    if total is not None and maxv:
        pct = round(total / maxv * 100) if maxv else 0
        lines.append(f"Deterministic score: {total} / {maxv}  ({pct}%)")
    dims = scores.get("ai_analysis", {}).get("dimensions", [])
    if dims:
        lines += ["", "AI analysis (model opinion — human review required):"]
        lines += [f"  - {d.get('dimension')}: {d.get('score')}/5" for d in dims]
    lines += ["", "This is decision-support evidence, not an employment decision."]
    return "\n".join(lines)


def _build_message(to_email: str, sender: str, report: dict) -> EmailMessage:
    msg = EmailMessage()
    msg["Subject"] = "Your VibeProof assessment report"
    msg["From"] = sender
    msg["To"] = to_email
    msg.set_content(_format_body(report))
    return msg


def _send_sync(host: str, port: int, user: str, password: str, msg: EmailMessage) -> None:
    with smtplib.SMTP(host, port, timeout=15) as smtp:
        smtp.starttls()
        smtp.login(user, password)
        smtp.send_message(msg)


async def send_report_email(*, to_email: str, report: dict) -> bool:
    """Send the report to the candidate. Returns True if sent, False if skipped or failed.

    Skips (no-op) when SMTP is unconfigured or the recipient is not an email address. Never raises.
    """
    s = get_settings()
    if not (s.email_smtp_host and s.email_smtp_user and s.email_password and s.email_address):
        return False  # not configured — feature is off
    if not _looks_like_email(to_email):
        return False  # display_name is not an email (e.g. "Anonymous" / "candidate")
    msg = _build_message(to_email, s.email_address, report)
    try:
        await run_in_threadpool(
            _send_sync, s.email_smtp_host, s.email_smtp_port, s.email_smtp_user, s.email_password, msg
        )
        return True
    except Exception:
        return False  # best-effort: a delivery failure must never surface to the caller


if __name__ == "__main__":
    # ponytail: one runnable check of the pure logic (no network) — the send path is covered by
    # tests/test_notifications.py which mocks smtplib.
    assert _looks_like_email("a@b.com") and not _looks_like_email("Anonymous")
    body = _format_body({"scores": {"deterministic": {"total": 60, "max": 80},
                                    "ai_analysis": {"dimensions": [{"dimension": "evidence_use", "score": 4}]}}})
    assert "60 / 80  (75%)" in body and "evidence_use: 4/5" in body
    print("notifications self-check ok")
