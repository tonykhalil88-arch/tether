"""A tiny, zero-dependency iCalendar (RFC 5545) writer.

Each obligation becomes an all-day ``VEVENT`` with a ``VALARM`` that fires a
configurable number of days beforehand. UIDs are derived from the obligation
fingerprint, so re-exporting produces the same UIDs and calendar clients update
events in place instead of duplicating them.
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime, timedelta

from ..models import Obligation

PRODID = "-//Tether//Obligation Scanner//EN"


def escape_text(value: str) -> str:
    """Escape a value for an iCalendar TEXT field (RFC 5545 §3.3.11)."""

    return (
        value.replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\r\n", "\\n")
        .replace("\n", "\\n")
        .replace("\r", "\\n")
    )


def _fold(line: str) -> str:
    """Fold a content line to 75 octets with leading-space continuations."""

    if len(line) <= 75:
        return line
    chunks = [line[:75]]
    rest = line[75:]
    while rest:
        chunks.append(" " + rest[:74])
        rest = rest[74:]
    return "\r\n".join(chunks)


def _trigger(reminder_days: int) -> str:
    if reminder_days <= 0:
        return "TRIGGER:-PT0S"
    return f"TRIGGER:-P{reminder_days}D"


def build_ics(
    obligations: Iterable[Obligation],
    reminder_days: int = 7,
    now: datetime | None = None,
) -> str:
    """Render ``obligations`` as an iCalendar document."""

    stamp = (now or datetime.now()).strftime("%Y%m%dT%H%M%SZ")
    lines: list[str] = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        f"PRODID:{PRODID}",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
    ]

    for obligation in obligations:
        due = obligation.due_date
        summary = escape_text(obligation.title or obligation.kind)
        lines += [
            "BEGIN:VEVENT",
            f"UID:{obligation.fingerprint}@tether",
            f"DTSTAMP:{stamp}",
            f"DTSTART;VALUE=DATE:{due.strftime('%Y%m%d')}",
            f"DTEND;VALUE=DATE:{(due + timedelta(days=1)).strftime('%Y%m%d')}",
            f"SUMMARY:{summary}",
            f"CATEGORIES:{escape_text(obligation.kind)}",
        ]
        if obligation.context:
            lines.append(f"DESCRIPTION:{escape_text(obligation.context)}")
        lines += [
            "BEGIN:VALARM",
            "ACTION:DISPLAY",
            f"DESCRIPTION:{summary}",
            _trigger(reminder_days),
            "END:VALARM",
            "END:VEVENT",
        ]

    lines.append("END:VCALENDAR")
    return "\r\n".join(_fold(line) for line in lines) + "\r\n"
