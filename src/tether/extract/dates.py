"""Regex date detection.

Supports several everyday date shapes and returns each match together with an
80-character context window on either side, which the classifier uses to decide
what kind of obligation the date belongs to.

Formats handled:

* Numeric ``DD/MM/YYYY`` (day-first by default; pass ``monthfirst=True`` for the
  US ``MM/DD/YYYY`` reading). ``/``, ``-`` and ``.`` separators are accepted.
* ``12 July 2026`` and ``July 12, 2026`` (with optional ordinal suffixes and an
  abbreviated month such as ``Jul.``).
* ISO ``YYYY-MM-DD``.

Two-digit years are pivoted at 70 (``00``–``69`` -> ``2000``–``2069``,
``70``–``99`` -> ``1970``–``1999``). Impossible dates such as ``31/02/2026`` are
skipped rather than raising.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date

CONTEXT_WINDOW = 80

MONTHS = {
    "jan": 1, "january": 1,
    "feb": 2, "february": 2,
    "mar": 3, "march": 3,
    "apr": 4, "april": 4,
    "may": 5,
    "jun": 6, "june": 6,
    "jul": 7, "july": 7,
    "aug": 8, "august": 8,
    "sep": 9, "sept": 9, "september": 9,
    "oct": 10, "october": 10,
    "nov": 11, "november": 11,
    "dec": 12, "december": 12,
}

_MONTH_ALT = "|".join(sorted(MONTHS, key=len, reverse=True))

ISO_RE = re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b")
NUMERIC_RE = re.compile(r"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\b")
DMY_TEXT_RE = re.compile(
    rf"\b(\d{{1,2}})(?:st|nd|rd|th)?\s+({_MONTH_ALT})\.?\s+(\d{{4}})\b",
    re.IGNORECASE,
)
MDY_TEXT_RE = re.compile(
    rf"\b({_MONTH_ALT})\.?\s+(\d{{1,2}})(?:st|nd|rd|th)?,?\s+(\d{{4}})\b",
    re.IGNORECASE,
)


@dataclass
class DateMatch:
    """A single date found in a block of text."""

    date: date
    matched_text: str
    start: int
    end: int
    context: str


def _pivot_year(year: int) -> int:
    if year >= 100:
        return year
    return 2000 + year if year < 70 else 1900 + year


def _safe_date(year: int, month: int, day: int) -> date | None:
    try:
        return date(year, month, day)
    except ValueError:
        return None


def _context(text: str, start: int, end: int) -> str:
    lo = max(0, start - CONTEXT_WINDOW)
    hi = min(len(text), end + CONTEXT_WINDOW)
    return text[lo:hi].strip()


def find_dates(text: str, monthfirst: bool = False) -> list[DateMatch]:
    """Return all recognised dates in ``text``, ordered by position.

    Overlapping matches are resolved on a first-claimed basis, with the more
    specific formats (ISO, then textual) evaluated before the ambiguous numeric
    form so that ``2026-07-12`` is never also read as a slash date.
    """

    claimed: list[tuple[int, int]] = []
    results: list[DateMatch] = []

    def overlaps(start: int, end: int) -> bool:
        return any(not (end <= cs or start >= ce) for cs, ce in claimed)

    def add(start: int, end: int, value: date | None, matched: str) -> None:
        if value is None or overlaps(start, end):
            return
        claimed.append((start, end))
        results.append(DateMatch(value, matched, start, end, _context(text, start, end)))

    for m in ISO_RE.finditer(text):
        add(m.start(), m.end(), _safe_date(int(m[1]), int(m[2]), int(m[3])), m[0])

    for m in DMY_TEXT_RE.finditer(text):
        month = MONTHS[m[2].lower()]
        add(m.start(), m.end(), _safe_date(int(m[3]), month, int(m[1])), m[0])

    for m in MDY_TEXT_RE.finditer(text):
        month = MONTHS[m[1].lower()]
        add(m.start(), m.end(), _safe_date(int(m[3]), month, int(m[2])), m[0])

    for m in NUMERIC_RE.finditer(text):
        first, second = int(m[1]), int(m[2])
        year = _pivot_year(int(m[3]))
        month, day = (first, second) if monthfirst else (second, first)
        add(m.start(), m.end(), _safe_date(year, month, day), m[0])

    results.sort(key=lambda r: r.start)
    return results
