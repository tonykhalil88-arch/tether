"""Command-line interface for Tether."""

from __future__ import annotations

from pathlib import Path

import click

from . import __version__
from .db import Store
from .export.ics import build_ics
from .scan import scan_folder

DEFAULT_DB = "tether.db"

_db_option = click.option(
    "--db",
    default=DEFAULT_DB,
    show_default=True,
    help="Path to the SQLite database.",
)


@click.group()
@click.version_option(version=__version__, prog_name="tether")
def main() -> None:
    """Tether — find the deadlines hiding in your documents."""


@main.command()
@click.argument("path", type=click.Path(exists=True, path_type=Path))
@_db_option
@click.option(
    "--monthfirst",
    is_flag=True,
    help="Read ambiguous numeric dates as US month-first (MM/DD/YYYY).",
)
def scan(path: Path, db: str, monthfirst: bool) -> None:
    """Scan PATH (a file or folder) for future obligations."""

    with Store(db) as store:
        result = scan_folder(path, store, monthfirst=monthfirst)

    click.echo(
        f"Scanned {result.files_scanned} file(s); "
        f"found {result.obligations_found} obligation(s)."
    )
    for source, error in result.errors:
        click.echo(f"  ! {source}: {error}", err=True)


@main.command()
@click.option("--days", default=30, show_default=True, help="Look-ahead window in days.")
@_db_option
def upcoming(days: int, db: str) -> None:
    """List obligations due within the next --days days."""

    with Store(db) as store:
        obligations = store.upcoming(days)

    if not obligations:
        click.echo("No upcoming obligations.")
        return
    for obligation in obligations:
        click.echo(
            f"{obligation.due_date.isoformat()}  "
            f"[{obligation.kind}]  {obligation.title}  "
            f"(conf {obligation.confidence:.2f})  <- {obligation.source_file}"
        )


@main.command()
@click.option("-o", "--output", required=True, type=click.Path(path_type=Path))
@click.option(
    "--reminder-days",
    default=7,
    show_default=True,
    help="Fire a reminder this many days before each obligation.",
)
@_db_option
def export(output: Path, reminder_days: int, db: str) -> None:
    """Export all stored obligations to an .ics calendar file."""

    with Store(db) as store:
        obligations = store.all()

    output.write_text(build_ics(obligations, reminder_days=reminder_days), encoding="utf-8")
    click.echo(f"Wrote {len(obligations)} event(s) to {output}")


if __name__ == "__main__":
    main()
