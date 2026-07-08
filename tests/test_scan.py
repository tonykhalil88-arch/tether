from datetime import date
from pathlib import Path

from tether.db import Store
from tether.scan import extract_text, scan_folder

TODAY = date(2026, 1, 1)


def _write(folder: Path) -> None:
    (folder / "policy.txt").write_text(
        "Home insurance policy expires 01/08/2026.\n"
        "Date of birth: 01/01/1990.\n",
        encoding="utf-8",
    )
    (folder / "invoice.txt").write_text(
        "Water bill.\nPayment due date: 15/03/2026.\nPlease pay the amount owing.\n",
        encoding="utf-8",
    )
    (folder / "notes.md").write_text(
        "# Notes\nCar rego registration: 30/09/2026.\n",
        encoding="utf-8",
    )


def test_scan_finds_obligations_and_collects_errors(tmp_path):
    _write(tmp_path)
    (tmp_path / "ignore.csv").write_text("not,scanned,01/01/2026\n", encoding="utf-8")

    store = Store(":memory:")
    result = scan_folder(tmp_path, store, today=TODAY)

    assert result.files_scanned == 3
    assert result.obligations_found >= 3
    assert result.errors == []
    kinds = {o.kind for o in store.all()}
    assert {"expiry", "payment_due", "rego"} <= kinds
    store.close()


def test_rescan_is_idempotent(tmp_path):
    _write(tmp_path)
    store = Store(":memory:")

    first = scan_folder(tmp_path, store, today=TODAY)
    count_after_first = store.count()
    second = scan_folder(tmp_path, store, today=TODAY)

    assert first.obligations_found == second.obligations_found
    assert store.count() == count_after_first
    store.close()


def test_unsupported_file_raises_from_extract(tmp_path):
    bad = tmp_path / "data.csv"
    bad.write_text("x", encoding="utf-8")
    try:
        extract_text(bad)
    except ValueError as exc:
        assert "unsupported" in str(exc)
    else:  # pragma: no cover
        raise AssertionError("expected ValueError")
