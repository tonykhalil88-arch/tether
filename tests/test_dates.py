from datetime import date

from tether.extract.dates import CONTEXT_WINDOW, find_dates


def _dates(text, **kwargs):
    return [m.date for m in find_dates(text, **kwargs)]


def test_day_first_numeric_is_default():
    assert _dates("Renew by 03/04/2026.") == [date(2026, 4, 3)]


def test_monthfirst_flag_reads_us_order():
    assert _dates("Renew by 03/04/2026.", monthfirst=True) == [date(2026, 3, 4)]


def test_textual_day_month_year():
    assert _dates("Expires 12 July 2026 sharp.") == [date(2026, 7, 12)]


def test_textual_month_day_year_with_ordinal():
    assert _dates("Due on July 12th, 2026.") == [date(2026, 7, 12)]


def test_iso_format():
    assert _dates("valid until 2026-07-12") == [date(2026, 7, 12)]


def test_iso_not_double_counted_as_numeric():
    matches = find_dates("2026-07-12")
    assert [m.date for m in matches] == [date(2026, 7, 12)]


def test_two_digit_year_pivots_to_2000s():
    assert _dates("renews 01/01/30") == [date(2030, 1, 1)]


def test_invalid_calendar_date_is_skipped():
    assert _dates("bogus 31/02/2026 date") == []


def test_abbreviated_month_with_dot():
    assert _dates("Expires 5 Dec. 2026.") == [date(2026, 12, 5)]


def test_context_window_is_bounded():
    text = "x" * 500 + " 12/12/2026 " + "y" * 500
    match = find_dates(text)[0]
    assert "12/12/2026" in match.context
    assert len(match.context) <= 2 * CONTEXT_WINDOW + len(match.matched_text)
