from datetime import date

from tether.extract.classify import MIN_CONFIDENCE, classify
from tether.extract.dates import find_dates

TODAY = date(2026, 1, 1)


def _classify(text, **kwargs):
    matches = find_dates(text)
    return classify(matches, "doc.txt", today=TODAY, **kwargs)


def test_expiry_keyword_scores_highest():
    obls = _classify("This policy expires on 01/08/2026.")
    assert len(obls) == 1
    assert obls[0].kind == "expiry"
    assert obls[0].confidence == 0.9


def test_payment_due_keyword():
    obls = _classify("Payment due date: 15/03/2026.")
    assert obls[0].kind == "payment_due"
    assert obls[0].confidence == 0.9


def test_appointment_is_lowest_confidence():
    obls = _classify("Appointment scheduled for 10/05/2026.")
    assert obls[0].kind == "appointment"
    assert obls[0].confidence == 0.7


def test_noise_hint_penalises_and_can_drop():
    # "date of birth" plus "issued" push a bare date below threshold.
    obls = _classify("Date of birth 05/05/2026, issued today.")
    assert obls == []


def test_past_dates_are_dropped():
    obls = classify(find_dates("Expired 01/01/2020."), "doc.txt", today=TODAY)
    assert obls == []


def test_unmatched_dates_produce_no_obligation():
    assert _classify("A random 09/09/2026 with no keyword.") == []


def test_dedupe_by_fingerprint_keeps_one():
    text = "Insurance expires 01/08/2026. The insurance policy expires 01/08/2026."
    obls = _classify(text)
    kinds_dates = {(o.kind, o.due_date) for o in obls}
    assert len(obls) == len(kinds_dates)


def test_noise_penalty_lowers_but_may_survive():
    obls = _classify("Warranty valid until 01/08/2026, issued last week.")
    assert obls[0].confidence >= MIN_CONFIDENCE
    assert obls[0].confidence < 0.9
