from datetime import date

from tether.db import Store
from tether.models import Obligation


def _obl(kind="expiry", day=1, source="a.txt"):
    return Obligation(
        kind=kind,
        due_date=date(2026, 8, day),
        source_file=source,
        context="ctx",
        confidence=0.9,
        title=f"{kind} ({day})",
    )


def test_upsert_is_idempotent():
    store = Store(":memory:")
    store.upsert(_obl(), now="2026-01-01T00:00:00")
    store.upsert(_obl(), now="2026-02-02T00:00:00")
    assert store.count() == 1

    row = store.conn.execute(
        "SELECT first_seen, last_seen FROM obligations"
    ).fetchone()
    assert row["first_seen"] == "2026-01-01T00:00:00"
    assert row["last_seen"] == "2026-02-02T00:00:00"
    store.close()


def test_upcoming_respects_window():
    store = Store(":memory:")
    store.upsert(_obl(day=5, source="soon.txt"))
    store.upsert(_obl(day=25, source="later.txt"))
    today = date(2026, 8, 1)

    soon = store.upcoming(within_days=10, today=today)
    assert [o.source_file for o in soon] == ["soon.txt"]

    both = store.upcoming(within_days=40, today=today)
    assert len(both) == 2
    store.close()
