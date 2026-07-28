# WILDMIGRATION — Isolation Pass (Ablations + Control)

Separates card power from pilot skill under the real deckbuilding rules (50 + 1 Vanguard, max 4 copies, colour-legal). Every scenario runs the full 8×8 matrix (50 games/matchup, 3200 games) on the same seed blocks as A0.

## A0 — new-rules baseline

| Vanguard | Archetype | Win rate | Avg length |
|---|---|---|---|
| 001(rush) | rush | 79% | 7.3 |
| 012(rest_punish) | rest_punish | 23% | 8.3 |
| 023(refresh_tempo) | refresh_tempo | 15% | 8.0 |
| 034(lockdown) | lockdown | 54% | 15.5 |
| 045(filter_control) | filter_control | 50% | 9.7 |
| 056(discount_deploy) | discount_deploy | 72% | 7.2 |
| 067(drain) | drain | 34% | 9.1 |
| 078(threshold_ramp) | threshold_ramp | 73% | 7.7 |

First-player win rate (A0): **55%**.

## Ablation deltas vs A0 (percentage points)

Row = scenario, column = Vanguard. `REAL` if the suspect's owner shifts >5 pts; `acquit` if <2 pts.

| Scenario | 001(rush) | 012(rest_punish) | 023(refresh_tempo) | 034(lockdown) | 045(filter_control) | 056(discount_deploy) | 067(drain) | 078(threshold_ramp) | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| A1 | **-3** | +0 | +0 | +1 | +1 | +1 | +0 | +0 | inconclusive (001(rush) -3) |
| A2 | +3 | +2 | +1 | +4 | +4 | +2 | +2 | **-17** | REAL (078(threshold_ramp) -17) |
| A3 | +1 | +0 | +0 | +0 | +0 | **-1** | +0 | +0 | acquit (056(discount_deploy) -1) |
| A4 | -0 | **+0** | -0 | +0 | -0 | +0 | +0 | +0 | acquit (012(rest_punish) +0) |
| A5 | -0 | +0 | **+0** | +0 | +0 | +0 | +0 | +0 | acquit (023(refresh_tempo) +0) |

_Bold cell = the ablated card's own Vanguard (the suspect)._

Scenario legend: A1 = Sora Vanguard Rush rider disabled, A2 = Total Mobilisation blanked, A3 = Vale discount Vanguard-only (Canyon disabled), A4 = Verdigris rests 1 instead of 2, A5 = Korgan self-refresh disabled.

## C0 — pilot-skill control (shared generic pilot)

Gap that persists under one shared pilot = **cards**; gap that collapses toward 50% = **pilot skill**.

| Vanguard | A0 (archetype) | C0 (generic) | Shift | Reading |
|---|---|---|---|---|
| 001(rush) | 79% | 60% | -20 | pilot skill (collapses) |
| 012(rest_punish) | 23% | 23% | -0 | cards (persists) |
| 023(refresh_tempo) | 15% | 26% | +11 | cards (persists) |
| 034(lockdown) | 54% | 66% | +12 | — |
| 045(filter_control) | 50% | 74% | +24 | — |
| 056(discount_deploy) | 72% | 61% | -10 | cards (persists) |
| 067(drain) | 34% | 37% | +3 | cards (persists) |
| 078(threshold_ramp) | 73% | 53% | -20 | pilot skill (collapses) |

## Defence economy (A0, per Vanguard)

Connect rate = attacks that won / attacks declared. Low connect + low attacker-vs-defender power = small bodies bouncing off big Vanguards.

| Vanguard | Connect rate | Counters / Life lost | Avg attacker pow | Avg defender pow |
|---|---|---|---|---|
| 001(rush) | 74% | 0.07 | 4662 | 5213 |
| 012(rest_punish) | 81% | 0.13 | 4663 | 4656 |
| 023(refresh_tempo) | 63% | 0.24 | 3920 | 5047 |
| 034(lockdown) | 53% | 0.37 | 4520 | 5833 |
| 045(filter_control) | 67% | 0.43 | 3965 | 4782 |
| 056(discount_deploy) | 70% | 0.06 | 4420 | 5174 |
| 067(drain) | 72% | 0.36 | 4316 | 4701 |
| 078(threshold_ramp) | 67% | 0.10 | 4936 | 5310 |

