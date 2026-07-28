# WILDMIGRATION — Set 1 Balance Report

Archetype-aware pilots, pure-kit decks. **50** games per ordered matchup (first player split evenly), **3200** total games, base seed **1**.

Tolerances: matchup 35–65%, per-Vanguard overall 45–55%. Cells/rows outside tolerance are flagged **REVIEW**.

## Win-rate matrix (row = Player A's Vanguard, cell = A's win rate vs column B)

| A \ B | 001(rush) | 012(rest_punish) | 023(refresh_tempo) | 034(lockdown) | 045(filter_control) | 056(discount_deploy) | 067(drain) | 078(threshold_ramp) |
|---|---|---|---|---|---|---|---|---|
| **001(rush)** | 42% | 98%⚠ | 100%⚠ | 88%⚠ | 90%⚠ | 72%⚠ | 100%⚠ | 64% |
| **012(rest_punish)** | 0%⚠ | 44% | 58% | 8%⚠ | 10%⚠ | 2%⚠ | 42% | 0%⚠ |
| **023(refresh_tempo)** | 0%⚠ | 38% | 48% | 6%⚠ | 10%⚠ | 0%⚠ | 18%⚠ | 0%⚠ |
| **034(lockdown)** | 4%⚠ | 90%⚠ | 94%⚠ | 58% | 44% | 10%⚠ | 84%⚠ | 4%⚠ |
| **045(filter_control)** | 12%⚠ | 90%⚠ | 94%⚠ | 58% | 50% | 22%⚠ | 88%⚠ | 26%⚠ |
| **056(discount_deploy)** | 26%⚠ | 98%⚠ | 98%⚠ | 94%⚠ | 86%⚠ | 42% | 96%⚠ | 40% |
| **067(drain)** | 0%⚠ | 60% | 78%⚠ | 14%⚠ | 18%⚠ | 10%⚠ | 50% | 2%⚠ |
| **078(threshold_ramp)** | 38% | 94%⚠ | 98%⚠ | 92%⚠ | 82%⚠ | 40% | 94%⚠ | 52% |

## Per-Vanguard overall

| Vanguard | Archetype | Overall win rate | Avg game length (turns) |
|---|---|---|---|
| 001(rush) | rush | 83% **REVIEW** | 7.1 |
| 012(rest_punish) | rest_punish | 22% **REVIEW** | 8.1 |
| 023(refresh_tempo) | refresh_tempo | 16% **REVIEW** | 8.0 |
| 034(lockdown) | lockdown | 48% | 12.5 |
| 045(filter_control) | filter_control | 53% | 9.0 |
| 056(discount_deploy) | discount_deploy | 74% **REVIEW** | 7.1 |
| 067(drain) | drain | 29% **REVIEW** | 8.5 |
| 078(threshold_ramp) | threshold_ramp | 75% **REVIEW** | 7.3 |

## First-player advantage

Overall first-player win rate: **55%**.

## Balance watch-list (resolutions per game, set-wide average)

| Flag | Per game |
|---|---|
| sora_rush_grants | 0.075 |
| verdigris_double_rest | 0.093 |
| korgan_repeat_attacks | 0.000 |
| stampede_multi_refresh | 0.039 |
| averil_cards_seen | 1.005 |
| rue_aura_frozen | 0.169 |

Per-matchup watch normals are in `balance_report.json` (`watch_per_game_by_matchup`).

## REVIEW items

**Vanguards outside 45–55%:**

- 001(rush): 83%
- 012(rest_punish): 22%
- 023(refresh_tempo): 16%
- 056(discount_deploy): 74%
- 067(drain): 29%
- 078(threshold_ramp): 75%

**Matchups outside 35–65% (A's win rate vs B):**

- 001(rush) vs 012(rest_punish): 98%
- 001(rush) vs 023(refresh_tempo): 100%
- 001(rush) vs 034(lockdown): 88%
- 001(rush) vs 045(filter_control): 90%
- 001(rush) vs 056(discount_deploy): 72%
- 001(rush) vs 067(drain): 100%
- 012(rest_punish) vs 001(rush): 0%
- 012(rest_punish) vs 034(lockdown): 8%
- 012(rest_punish) vs 045(filter_control): 10%
- 012(rest_punish) vs 056(discount_deploy): 2%
- 012(rest_punish) vs 078(threshold_ramp): 0%
- 023(refresh_tempo) vs 001(rush): 0%
- 023(refresh_tempo) vs 034(lockdown): 6%
- 023(refresh_tempo) vs 045(filter_control): 10%
- 023(refresh_tempo) vs 056(discount_deploy): 0%
- 023(refresh_tempo) vs 067(drain): 18%
- 023(refresh_tempo) vs 078(threshold_ramp): 0%
- 034(lockdown) vs 001(rush): 4%
- 034(lockdown) vs 012(rest_punish): 90%
- 034(lockdown) vs 023(refresh_tempo): 94%
- 034(lockdown) vs 056(discount_deploy): 10%
- 034(lockdown) vs 067(drain): 84%
- 034(lockdown) vs 078(threshold_ramp): 4%
- 045(filter_control) vs 001(rush): 12%
- 045(filter_control) vs 012(rest_punish): 90%
- 045(filter_control) vs 023(refresh_tempo): 94%
- 045(filter_control) vs 056(discount_deploy): 22%
- 045(filter_control) vs 067(drain): 88%
- 045(filter_control) vs 078(threshold_ramp): 26%
- 056(discount_deploy) vs 001(rush): 26%
- 056(discount_deploy) vs 012(rest_punish): 98%
- 056(discount_deploy) vs 023(refresh_tempo): 98%
- 056(discount_deploy) vs 034(lockdown): 94%
- 056(discount_deploy) vs 045(filter_control): 86%
- 056(discount_deploy) vs 067(drain): 96%
- 067(drain) vs 001(rush): 0%
- 067(drain) vs 023(refresh_tempo): 78%
- 067(drain) vs 034(lockdown): 14%
- 067(drain) vs 045(filter_control): 18%
- 067(drain) vs 056(discount_deploy): 10%
- 067(drain) vs 078(threshold_ramp): 2%
- 078(threshold_ramp) vs 012(rest_punish): 94%
- 078(threshold_ramp) vs 023(refresh_tempo): 98%
- 078(threshold_ramp) vs 034(lockdown): 92%
- 078(threshold_ramp) vs 045(filter_control): 82%
- 078(threshold_ramp) vs 067(drain): 94%

## Decklists (reproducible)

Each deck is a pure kit: the Vanguard's ten non-Vanguard cards, **5 copies of each = 50** (4× core + 1× same-kit filler; hybrids out of scope).

- **Sora Akaza, Redgale Captain** (001(rush)): wm01-002, wm01-003, wm01-004, wm01-005, wm01-006, wm01-007, wm01-008, wm01-009, wm01-010, wm01-011
- **Kaya Morrow, Twilight Courier** (012(rest_punish)): wm01-013, wm01-014, wm01-015, wm01-016, wm01-017, wm01-018, wm01-019, wm01-020, wm01-021, wm01-022
- **Bram Oxhart, Warband Chief** (023(refresh_tempo)): wm01-024, wm01-025, wm01-026, wm01-027, wm01-028, wm01-029, wm01-030, wm01-031, wm01-032, wm01-033
- **Elder Neza, Route-Keeper** (034(lockdown)): wm01-035, wm01-036, wm01-037, wm01-038, wm01-039, wm01-040, wm01-041, wm01-042, wm01-043, wm01-044
- **Director Averil Cros, the Kind Face** (045(filter_control)): wm01-046, wm01-047, wm01-048, wm01-049, wm01-050, wm01-051, wm01-052, wm01-053, wm01-054, wm01-055
- **Commander Idris Vale, the Liaison** (056(discount_deploy)): wm01-057, wm01-058, wm01-059, wm01-060, wm01-061, wm01-062, wm01-063, wm01-064, wm01-065, wm01-066
- **Dr. Halcyon Rue, Chief Harvester** (067(drain)): wm01-068, wm01-069, wm01-070, wm01-071, wm01-072, wm01-073, wm01-074, wm01-075, wm01-076, wm01-077
- **Marshal Goran Dreyse, the Siegebreaker** (078(threshold_ramp)): wm01-079, wm01-080, wm01-081, wm01-082, wm01-083, wm01-084, wm01-085, wm01-086, wm01-087, wm01-088

