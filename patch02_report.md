# WILDMIGRATION — Patch 0.2 (Apply + Measure)

Six buffs applied (see the changelog in the README). The full 8×8 matrix (50 games/matchup, 3200 games) and the C0 shared-generic-pilot matrix were rerun on the **same seed blocks** as Brief 4's A0 baseline, so before/after is like-for-like.

## Per-Vanguard win rate — archetype pilots (A0 → Patch 0.2)

| Vanguard | A0 baseline | Patch 0.2 | Delta |
|---|---|---|---|
| 001(rush) | 79% | 79% | -0 pts |
| 012(rest_punish) | 23% | 22% | -1 pts |
| 023(refresh_tempo) | 15% | 14% | -1 pts |
| 034(lockdown) | 54% | 52% | -3 pts |
| 045(filter_control) | 50% | 47% | -3 pts |
| 056(discount_deploy) | 72% | 70% | -1 pts |
| 067(drain) | 34% | 44% | +10 pts |
| 078(threshold_ramp) | 73% | 72% | -1 pts |

## Per-Vanguard win rate — C0 shared generic pilot (baseline → patched)

| Vanguard | C0 baseline | C0 patched | Delta |
|---|---|---|---|
| 001(rush) | 60% | 59% | -1 pts |
| 012(rest_punish) | 23% | 21% | -2 pts |
| 023(refresh_tempo) | 26% | 25% | -1 pts |
| 034(lockdown) | 66% | 63% | -3 pts |
| 045(filter_control) | 74% | 72% | -2 pts |
| 056(discount_deploy) | 61% | 60% | -1 pts |
| 067(drain) | 37% | 49% | +12 pts |
| 078(threshold_ramp) | 53% | 51% | -2 pts |

## Defence economy — connect rate (buffed decks, before → after)

| Vanguard | Connect A0 | Connect Patch 0.2 | Avg atk pow A0 | Avg atk pow Patch 0.2 |
|---|---|---|---|---|
| 012(rest_punish) | 81% | 81% | 4663 | 4722 |
| 023(refresh_tempo) | 63% | 64% | 3920 | 3968 |
| 067(drain) | 72% | 74% | 4316 | 4429 |

## Patch success check

Target: Bram / Kaya / Rue all move toward tolerance without any overshooting >55%.

- **012(rest_punish)**: 23% → 22% (-1 pts) — ✗ did not improve
- **023(refresh_tempo)**: 15% → 14% (-1 pts) — ✗ did not improve
- **067(drain)**: 34% → 44% (+10 pts) — ✓ moved up

## Remaining REVIEW flags (Patch 0.2)

Vanguards outside 45–55%: 001(rush) (79%), 012(rest_punish) (22%), 023(refresh_tempo) (14%), 056(discount_deploy) (70%), 067(drain) (44%), 078(threshold_ramp) (72%)

Matchups outside 35–65%: **46 / 64** cells.
