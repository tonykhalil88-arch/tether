# WILDMIGRATION — Patch 0.4 (Apply + Measure)

Structural redesign of Bram's refresh package (uncapped: Bram Vanguard and Stampede can now refresh *any* Banner, Korgan included; the +2000 rider is gone) plus a Kaya rest nudge (max_cost 4→5). Everyone else untouched. Full 8×8 archetype + C0 matrices, 50 games/matchup, on the A0 seed blocks.

## Per-Vanguard win rate — archetype pilots

| Vanguard | A0 | 0.2 | 0.3 | 0.4 | Δ 0.4 vs A0 | Δ 0.4 vs 0.3 |
|---|---|---|---|---|---|---|
| 001(rush) | 79% | 79% | 78% | 78% | -2 | -1 |
| 012(rest_punish) | 23% | 22% | 27% | 24% | +1 | -3 |
| 023(refresh_tempo) | 15% | 14% | 14% | 29% | +13 | +15 |
| 034(lockdown) | 54% | 52% | 51% | 47% | -8 | -4 |
| 045(filter_control) | 50% | 47% | 47% | 45% | -5 | -3 |
| 056(discount_deploy) | 72% | 70% | 69% | 67% | -4 | -2 |
| 067(drain) | 34% | 44% | 43% | 42% | +8 | -2 |
| 078(threshold_ramp) | 73% | 72% | 71% | 70% | -4 | -1 |

## Per-Vanguard win rate — C0 shared generic pilot

| Vanguard | A0-C0 | 0.2-C0 | 0.3-C0 | 0.4-C0 | Δ 0.4 vs A0 |
|---|---|---|---|---|---|
| 001(rush) | 60% | 59% | 59% | 59% | -1 |
| 012(rest_punish) | 23% | 21% | 23% | 23% | -1 |
| 023(refresh_tempo) | 26% | 25% | 25% | 25% | -1 |
| 034(lockdown) | 66% | 63% | 62% | 62% | -4 |
| 045(filter_control) | 74% | 72% | 72% | 72% | -2 |
| 056(discount_deploy) | 61% | 60% | 60% | 60% | -1 |
| 067(drain) | 37% | 49% | 49% | 49% | +12 |
| 078(threshold_ramp) | 53% | 51% | 51% | 51% | -2 |

## Bram (refresh_tempo) — connect rate & attacker power (A0 → 0.4)

The redesign should raise attacker power — big bodies attacking repeatedly.

| Metric | A0 | 0.2 | 0.3 | 0.4 |
|---|---|---|---|---|
| Connect rate | 63% | 64% | 64% | 60% |
| Avg attacker power | 3920 | 3968 | 4002 | 4019 |

## Stability / trend (untouched or nudge decks)

- **Rue (drain, untouched)**: 0.3 43% → 0.4 42% (-2) — stable
- **Kaya (rest_punish, nudge)**: 0.3 27% → 0.4 24% (-3)

## ⚠ OVERSHOOT check (the accepted Korgan-loop risk)

Not triggered. refresh_tempo overall = **29%** (threshold 55%). Bram matchups over 65%: none.

## Remaining REVIEW flags (Patch 0.4)

Vanguards outside 45–55%: 001(rush) (78%), 012(rest_punish) (24%), 023(refresh_tempo) (29%), 045(filter_control) (45%), 056(discount_deploy) (67%), 067(drain) (42%), 078(threshold_ramp) (70%)

Matchups outside 35–65%: **43 / 64** cells.
