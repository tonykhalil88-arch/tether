"""SQLite persistence for obligations.

The store keys rows by fingerprint, so re-scanning a folder is idempotent: an
obligation that is seen again simply has its ``last_seen`` timestamp bumped while
``first_seen`` is preserved.
"""

from __future__ import annotations

import sqlite3
from datetime import date, datetime, timedelta

from .models import Obligation

_SCHEMA = """
CREATE TABLE IF NOT EXISTS obligations (
    fingerprint TEXT PRIMARY KEY,
    kind        TEXT NOT NULL,
    due_date    TEXT NOT NULL,
    source_file TEXT NOT NULL,
    context     TEXT,
    confidence  REAL,
    title       TEXT,
    first_seen  TEXT NOT NULL,
    last_seen   TEXT NOT NULL
)
"""


class Store:
    """A thin SQLite-backed store for obligations."""

    def __init__(self, path: str = ":memory:") -> None:
        self.conn = sqlite3.connect(path)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute(_SCHEMA)
        self.conn.commit()

    def upsert(self, obligation: Obligation, now: str | None = None) -> None:
        """Insert an obligation, or refresh ``last_seen`` if already present."""

        now = now or datetime.now().isoformat(timespec="seconds")
        self.conn.execute(
            """
            INSERT INTO obligations
                (fingerprint, kind, due_date, source_file, context,
                 confidence, title, first_seen, last_seen)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(fingerprint) DO UPDATE SET
                last_seen  = excluded.last_seen,
                confidence = excluded.confidence,
                context    = excluded.context,
                title      = excluded.title
            """,
            (
                obligation.fingerprint,
                obligation.kind,
                obligation.due_date.isoformat(),
                obligation.source_file,
                obligation.context,
                obligation.confidence,
                obligation.title,
                now,
                now,
            ),
        )
        self.conn.commit()

    def upcoming(self, within_days: int = 30, today: date | None = None) -> list[Obligation]:
        """Return obligations due between today and ``within_days`` from now."""

        today = today or date.today()
        end = today + timedelta(days=within_days)
        rows = self.conn.execute(
            """
            SELECT * FROM obligations
            WHERE due_date >= ? AND due_date <= ?
            ORDER BY due_date, kind
            """,
            (today.isoformat(), end.isoformat()),
        ).fetchall()
        return [self._to_obligation(row) for row in rows]

    def all(self) -> list[Obligation]:
        rows = self.conn.execute(
            "SELECT * FROM obligations ORDER BY due_date, kind"
        ).fetchall()
        return [self._to_obligation(row) for row in rows]

    def count(self) -> int:
        return self.conn.execute("SELECT COUNT(*) FROM obligations").fetchone()[0]

    @staticmethod
    def _to_obligation(row: sqlite3.Row) -> Obligation:
        return Obligation(
            kind=row["kind"],
            due_date=date.fromisoformat(row["due_date"]),
            source_file=row["source_file"],
            context=row["context"] or "",
            confidence=row["confidence"] or 0.0,
            title=row["title"] or "",
        )

    def close(self) -> None:
        self.conn.close()

    def __enter__(self) -> Store:
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()
