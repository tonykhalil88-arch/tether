"""Folder-scanning pipeline: files -> text -> dates -> obligations -> store.

Errors are collected per file rather than aborting the whole run, so a single
unreadable PDF never stops the rest of a folder from being scanned.
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

from .db import Store
from .extract.classify import classify
from .extract.dates import find_dates

TEXT_SUFFIXES = {".txt", ".md"}
SUPPORTED_SUFFIXES = TEXT_SUFFIXES | {".pdf"}


def extract_text(path: Path) -> str:
    """Read a supported document into plain text."""

    suffix = path.suffix.lower()
    if suffix in TEXT_SUFFIXES:
        return path.read_text(encoding="utf-8", errors="replace")
    if suffix == ".pdf":
        import pdfplumber  # imported lazily so text-only scans need no PDF stack

        pages: list[str] = []
        with pdfplumber.open(str(path)) as pdf:
            for page in pdf.pages:
                pages.append(page.extract_text() or "")
        return "\n".join(pages)
    raise ValueError(f"unsupported file type: {suffix or '(none)'}")


@dataclass
class ScanResult:
    files_scanned: int = 0
    obligations_found: int = 0
    errors: list[tuple[str, str]] = field(default_factory=list)


def iter_documents(root: Path) -> Iterator[Path]:
    """Yield supported documents under ``root`` (or ``root`` itself if a file)."""

    if root.is_file():
        if root.suffix.lower() in SUPPORTED_SUFFIXES:
            yield root
        return
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in SUPPORTED_SUFFIXES:
            yield path


def scan_folder(
    path: str | Path,
    store: Store,
    monthfirst: bool = False,
    today: date | None = None,
) -> ScanResult:
    """Scan a folder (or single file) and upsert every obligation found."""

    result = ScanResult()
    for document in iter_documents(Path(path)):
        try:
            text = extract_text(document)
            matches = find_dates(text, monthfirst=monthfirst)
            obligations = classify(matches, str(document), today=today)
            for obligation in obligations:
                store.upsert(obligation)
            result.obligations_found += len(obligations)
            result.files_scanned += 1
        except Exception as exc:  # noqa: BLE001 - report, never abort the run
            result.errors.append((str(document), str(exc)))
    return result
