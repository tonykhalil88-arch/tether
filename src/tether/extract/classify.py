"""Transparent keyword classifier.

Each date match is mapped to an obligation *kind* by looking for keywords in its
surrounding context window. The rules are plain data — no model, no training —
so a human can read exactly why a given date was labelled the way it was.

Confidence runs from ``0.9`` for the strongest signals (an explicit expiry or a
payment due date) down to ``0.7`` for a bare appointment. Noise hints such as
``invoice date`` or ``date of birth`` subtract from the score, and anything that
falls below :data:`MIN_CONFIDENCE` is dropped. Past-dated matches are discarded,
and the surviving obligations are de-duplicated by fingerprint.
"""

from __future__ import annotations

from datetime import date

from ..models import Obligation
from .dates import DateMatch

# (kind, base confidence, keywords) — evaluated top to bottom. On a tie the
# earlier rule wins, so ordering encodes priority.
RULES: list[tuple[str, float, tuple[str, ...]]] = [
    ("expiry", 0.9, (
        "expiry", "expires", "expire", "expiration",
        "valid until", "valid to", "valid through", "use by", "best before",
    )),
    ("payment_due", 0.9, (
        "payment due", "amount due", "due date", "due by", "pay by",
        "balance due", "total due", "please pay",
    )),
    ("renewal", 0.85, (
        "renewal", "renew", "renews", "auto-renew", "auto renew",
    )),
    ("insurance", 0.8, (
        "insurance", "policy period", "period of insurance", "cover period",
        "coverage", "insured", "policy",
    )),
    ("rego", 0.8, (
        "rego", "registration", "registered until", "vehicle registration",
        "number plate", "licence plate", "license plate",
    )),
    ("warranty", 0.8, (
        "warranty", "guarantee", "guaranteed", "warranted",
    )),
    ("subscription", 0.75, (
        "subscription", "subscribe", "billing period", "next billing", "billing date",
    )),
    ("lease", 0.75, (
        "lease", "tenancy", "rental agreement", "lease term",
    )),
    ("appointment", 0.7, (
        "appointment", "booking", "scheduled for", "reserved for",
    )),
]

# Phrases that suggest a date is *not* a future obligation.
NOISE_HINTS: tuple[str, ...] = (
    "invoice date", "date of birth", "d.o.b", "dob", "date issued",
    "issued", "issue date", "printed", "statement date", "as of",
)

NOISE_PENALTY = 0.3
MIN_CONFIDENCE = 0.5


def _classify_one(match: DateMatch, source_file: str) -> Obligation | None:
    context = match.context.lower()
    noise = sum(1 for hint in NOISE_HINTS if hint in context)

    best: tuple[str, float] | None = None
    for kind, base, keywords in RULES:
        if any(keyword in context for keyword in keywords):
            score = round(base - NOISE_PENALTY * noise, 3)
            # Strictly greater keeps the earlier (higher-priority) rule on ties.
            if best is None or score > best[1]:
                best = (kind, score)

    if best is None:
        return None
    kind, score = best
    if score < MIN_CONFIDENCE:
        return None

    title = f"{kind.replace('_', ' ').title()} ({match.date.isoformat()})"
    return Obligation(
        kind=kind,
        due_date=match.date,
        source_file=source_file,
        context=match.context,
        confidence=score,
        title=title,
        matched_text=match.matched_text,
    )


def _dedupe(obligations: list[Obligation]) -> list[Obligation]:
    by_fingerprint: dict[str, Obligation] = {}
    for obligation in obligations:
        existing = by_fingerprint.get(obligation.fingerprint)
        if existing is None or obligation.confidence > existing.confidence:
            by_fingerprint[obligation.fingerprint] = obligation
    return list(by_fingerprint.values())


def classify(
    matches: list[DateMatch],
    source_file: str,
    today: date | None = None,
) -> list[Obligation]:
    """Turn raw date matches into de-duplicated, future-dated obligations."""

    today = today or date.today()
    obligations: list[Obligation] = []
    for match in matches:
        if match.date < today:
            continue
        obligation = _classify_one(match, source_file)
        if obligation is not None:
            obligations.append(obligation)
    return _dedupe(obligations)
