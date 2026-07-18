"""Email the graded report to the candidate — optional and strictly best-effort.

Transport: prefer the Brevo HTTP API over HTTPS/443 (email_api_key). PaaS hosts block outbound
SMTP ports (Railway times out on 25/465/587/2525), so smtplib works locally but never in
production; SMTP is kept only as a local-dev fallback used when no API key is set. If neither is
configured, or the recipient is not an email address, this is a no-op.

Sending is never allowed to block or fail a submission: grading already degrades gracefully, and
report delivery is a nice-to-have layered on top. Callers wrap this so any exception is swallowed.

Both transports are synchronous (smtplib / urllib), so the blocking send runs in a threadpool.
"""
import json
import logging
import smtplib
import urllib.request
from email.message import EmailMessage

from starlette.concurrency import run_in_threadpool

from src.config import get_settings
from src.notifications.render import render_report_email

logger = logging.getLogger("vibeproof.notifications")

_BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"


def _looks_like_email(value: str) -> bool:
    return bool(value) and "@" in value and "." in value.rsplit("@", 1)[-1]


def _build_message(to_email: str, sender: str, subject: str, html: str, text: str) -> EmailMessage:
    """Multipart message: text/plain fallback + the styled text/html template."""
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to_email
    msg.set_content(text)                      # text/plain part (clients without HTML)
    msg.add_alternative(html, subtype="html")  # richer text/html part
    return msg


def _send_sync(host: str, port: int, user: str, password: str, msg: EmailMessage) -> None:
    with smtplib.SMTP(host, port, timeout=15) as smtp:
        smtp.starttls()
        smtp.login(user, password)
        smtp.send_message(msg)


def _send_via_api_sync(api_key: str, sender: str, to_email: str, subject: str, html: str, text: str) -> None:
    """POST the report to Brevo's transactional-email REST API over HTTPS/443. Raises on non-2xx."""
    payload = json.dumps(
        {
            "sender": {"email": sender},
            "to": [{"email": to_email}],
            "subject": subject,
            "htmlContent": html,   # styled 3-layer template (Gmail-safe inline CSS)
            "textContent": text,   # plain-text fallback
        }
    ).encode()
    req = urllib.request.Request(
        _BREVO_API_URL,
        data=payload,
        headers={"api-key": api_key, "content-type": "application/json", "accept": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:  # HTTPError raised for 4xx/5xx
        resp.read()


async def send_report_email(*, to_email: str, report: dict) -> bool:
    """Send the report to the candidate. Returns True if sent, False if skipped or failed.

    Prefers the Brevo HTTP API (works from PaaS); falls back to SMTP only when no API key is set.
    Skips (no-op) when nothing is configured or the recipient is not an email address. Never raises.
    """
    s = get_settings()
    smtp_ready = bool(s.email_smtp_host and s.email_smtp_user and s.email_password)
    if not s.email_address or not (s.email_api_key or smtp_ready):
        logger.info("report email skipped: not configured (need email_api_key or SMTP creds + sender)")
        return False
    if not _looks_like_email(to_email):
        logger.info("report email skipped: recipient %r is not an email address", to_email)
        return False  # display_name is not an email (e.g. "Anonymous" / "candidate")
    try:
        subject, html, text = render_report_email(report)  # styled 3-layer template (subject/html/text)
        if s.email_api_key:
            await run_in_threadpool(
                _send_via_api_sync, s.email_api_key, s.email_address, to_email, subject, html, text
            )
            logger.info("report email sent to %s via Brevo API (from %s)", to_email, s.email_address)
        else:
            msg = _build_message(to_email, s.email_address, subject, html, text)
            await run_in_threadpool(
                _send_sync, s.email_smtp_host, s.email_smtp_port, s.email_smtp_user, s.email_password, msg
            )
            logger.info("report email sent to %s via SMTP %s (from %s)", to_email, s.email_smtp_host, s.email_address)
        return True
    except Exception as exc:
        # Best-effort: a delivery failure must never surface to the caller — but log it, or a
        # misconfigured key/sender looks identical to "email feature is off".
        transport = "Brevo API" if s.email_api_key else "SMTP"
        logger.warning("report email send failed (%s, from %s): %s", transport, s.email_address, exc)
        return False


if __name__ == "__main__":
    # ponytail: one runnable check of the pure logic (no network) — the send path is covered by
    # tests/test_notifications.py which mocks smtplib.
    assert _looks_like_email("a@b.com") and not _looks_like_email("Anonymous")
    print("notifications self-check ok")
