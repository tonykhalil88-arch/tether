from datetime import date, datetime

from tether.export.ics import build_ics, escape_text
from tether.models import Obligation

NOW = datetime(2026, 1, 1, 9, 0, 0)


def _obl(title="Insurance (2026-08-01)", kind="insurance", context="context"):
    return Obligation(
        kind=kind,
        due_date=date(2026, 8, 1),
        source_file="policy.txt",
        context=context,
        confidence=0.9,
        title=title,
    )


def test_calendar_envelope_and_allday_event():
    ics = build_ics([_obl()], now=NOW)
    assert ics.startswith("BEGIN:VCALENDAR\r\n")
    assert ics.rstrip().endswith("END:VCALENDAR")
    assert "BEGIN:VEVENT" in ics
    assert "DTSTART;VALUE=DATE:20260801" in ics
    assert "DTEND;VALUE=DATE:20260802" in ics


def test_text_escaping():
    assert escape_text("a,b;c\\d\ne") == "a\\,b\\;c\\\\d\\ne"
    ics = build_ics([_obl(title="Rent, due; now")], now=NOW)
    assert "SUMMARY:Rent\\, due\\; now" in ics


def test_valarm_reminder_days_before():
    ics = build_ics([_obl()], reminder_days=10, now=NOW)
    assert "BEGIN:VALARM" in ics
    assert "TRIGGER:-P10D" in ics
    assert "ACTION:DISPLAY" in ics


def test_uid_is_stable_from_fingerprint():
    obl = _obl()
    ics = build_ics([obl], now=NOW)
    assert f"UID:{obl.fingerprint}@tether" in ics


def test_crlf_line_endings():
    ics = build_ics([_obl()], now=NOW)
    assert "\r\n" in ics
    # every logical line should terminate with CRLF, never a bare LF
    assert "\n" not in ics.replace("\r\n", "")
