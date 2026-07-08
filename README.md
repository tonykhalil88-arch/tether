# Tether

**Find the deadlines hiding in your documents.**

Insurance renewals, rego, warranty windows, subscription rebills, lease
end-dates, payment due dates — the obligations that cost you money when they
slip past are scattered across PDFs and notes you'll never re-read. Tether scans
a folder of documents locally, pulls out the future-dated obligations, and hands
you an `.ics` file you can drop into any calendar. **Your documents never leave
your machine** — no upload, no account, no cloud.

## How it works

```
folder → text (pdfplumber / txt / md) → dates (regex) → classify (keywords) → SQLite → .ics
```

Everything is transparent and inspectable:

- **Date detection** understands day-first `DD/MM/YYYY` (with a `--monthfirst`
  flag for the US reading), `12 July 2026`, `July 12, 2026`, and ISO
  `YYYY-MM-DD`. Two-digit years are handled and impossible dates are skipped.
- **Classification** is a plain keyword table — no model, no training. Each date
  gets a *kind* (expiry, payment due, renewal, insurance, rego, warranty,
  subscription, lease, appointment) and a confidence score. Noise hints like
  *invoice date* or *date of birth* are penalised, and past dates are dropped.
- **Storage** is a local SQLite file. Re-scanning is idempotent: obligations are
  keyed by a sha256 fingerprint, so nothing is ever duplicated.
- **Export** is a zero-dependency iCalendar writer producing all-day events with
  a reminder alarm N days before, and stable UIDs so calendars update in place.

## Quick start

```bash
pip install -e ".[dev]"        # or: pip install .

# 1. Scan a folder (or a single file) of documents
tether scan examples/

# 2. See what's coming up
tether upcoming --days 365

# 3. Export to a calendar file with a 14-day reminder
tether export -o obligations.ics --reminder-days 14
```

Import `obligations.ics` into Google Calendar, Apple Calendar, Outlook — anything
that speaks iCalendar.

### Docker

```bash
docker build -t tether .
docker run --rm -v "$PWD:/data" tether scan /data/docs
docker run --rm -v "$PWD:/data" tether export -o /data/obligations.ics
```

## Commands

| Command | What it does |
| --- | --- |
| `tether scan PATH [--monthfirst] [--db FILE]` | Walk a folder/file, extract obligations, store them. |
| `tether upcoming [--days N] [--db FILE]` | List obligations due within the next N days. |
| `tether export -o FILE [--reminder-days N] [--db FILE]` | Write all stored obligations to an `.ics` file. |

The database defaults to `tether.db` in the working directory.

## Development

```bash
pip install -e ".[dev]"
ruff check .
pytest
```

## Roadmap

Tether v0.1 is deliberately small. Planned next:

- **OCR** for scanned/image PDFs (Tesseract) so photographed documents work too.
- **Watch daemon** that re-scans a folder on change and keeps the calendar fresh.
- **Amount extraction** — capture the dollar figure attached to a payment due date.
- **Optional local-LLM pass** to catch obligations the keyword rules miss, kept
  fully offline and strictly opt-in.
- **Hosted email ingestion** (optional, opt-in) to pull obligations straight from
  receipts and renewal notices.

## License

MIT — see [LICENSE](LICENSE).
