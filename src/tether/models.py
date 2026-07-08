"""Core data model for a detected obligation."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from datetime import date


@dataclass
class Obligation:
    """A future obligation extracted from a document.

    The ``fingerprint`` is a stable sha256 over ``kind``, ``due_date`` and
    ``source_file``. It is used both for deduplication and to mint stable
    calendar UIDs, so re-scanning the same document never produces a duplicate.
    """

    kind: str
    due_date: date
    source_file: str
    context: str = ""
    confidence: float = 0.0
    title: str = ""
    matched_text: str = field(default="", repr=False)

    @property
    def fingerprint(self) -> str:
        raw = f"{self.kind}|{self.due_date.isoformat()}|{self.source_file}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()
