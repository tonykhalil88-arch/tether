# WILDMIGRATION — Set 1 Balance Report

Archetype-aware pilots, pure-kit decks. **50** games per ordered matchup (first player split evenly), **3200** total games, base seed **1**.

Tolerances: matchup 35–65%, per-Vanguard overall 45–55%. Cells/rows outside tolerance are flagged **REVIEW**.

## Win-rate matrix (row = Player A's Vanguard, cell = A's win rate vs column B)

| A \ B | 001(rush) | 012(rest_punish) | 023(refresh_tempo) | 034(lockdown) | 045(filter_control) | 056(discount_deploy) | 067(drain) | 078(threshold_ramp) |
|---|---|---|---|---|---|---|---|---|
| **001(rush)** | 50% | 96%⚠ | 100%⚠ | 72%⚠ | 78%⚠ | 72%⚠ | 94%⚠ | 64% |
| **012(rest_punish)** | 0%⚠ | 54% | 68%⚠ | 10%⚠ | 12%⚠ | 6%⚠ | 38% | 4%⚠ |
| **023(refresh_tempo)** | 0%⚠ | 36% | 60% | 4%⚠ | 12%⚠ | 4%⚠ | 12%⚠ | 0%⚠ |
| **034(lockdown)** | 26%⚠ | 92%⚠ | 96%⚠ | 60% | 54% | 24%⚠ | 72%⚠ | 10%⚠ |
| **045(filter_control)** | 12%⚠ | 90%⚠ | 100%⚠ | 26%⚠ | 60% | 30%⚠ | 74%⚠ | 18%⚠ |
| **056(discount_deploy)** | 32%⚠ | 94%⚠ | 98%⚠ | 70%⚠ | 84%⚠ | 46% | 98%⚠ | 50% |
| **067(drain)** | 6%⚠ | 62% | 64% | 32%⚠ | 34%⚠ | 6%⚠ | 42% | 18%⚠ |
| **078(threshold_ramp)** | 34%⚠ | 94%⚠ | 98%⚠ | 96%⚠ | 78%⚠ | 40% | 96%⚠ | 54% |

## Per-Vanguard overall

| Vanguard | Archetype | Overall win rate | Avg game length (turns) |
|---|---|---|---|
| 001(rush) | rush | 79% **REVIEW** | 7.3 |
| 012(rest_punish) | rest_punish | 23% **REVIEW** | 8.3 |
| 023(refresh_tempo) | refresh_tempo | 15% **REVIEW** | 8.0 |
| 034(lockdown) | lockdown | 54% | 15.5 |
| 045(filter_control) | filter_control | 50% | 9.7 |
| 056(discount_deploy) | discount_deploy | 72% **REVIEW** | 7.2 |
| 067(drain) | drain | 34% **REVIEW** | 9.1 |
| 078(threshold_ramp) | threshold_ramp | 73% **REVIEW** | 7.7 |

## Defence economy (per Vanguard)

Connect rate = attacks that won / attacks declared. A low connect rate with avg attacker power well under avg defender power means small bodies bouncing off big Vanguards.

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

## First-player advantage

Overall first-player win rate: **55%**.

## Balance watch-list (resolutions per game, set-wide average)

| Flag | Per game |
|---|---|
| sora_rush_grants | 0.080 |
| verdigris_double_rest | 0.104 |
| korgan_repeat_attacks | 0.002 |
| stampede_multi_refresh | 0.031 |
| averil_cards_seen | 1.110 |
| rue_aura_frozen | 0.231 |

Per-matchup watch normals are in `balance_report.json` (`watch_per_game_by_matchup`).

## REVIEW items

**Vanguards outside 45–55%:**

- 001(rush): 79%
- 012(rest_punish): 23%
- 023(refresh_tempo): 15%
- 056(discount_deploy): 72%
- 067(drain): 34%
- 078(threshold_ramp): 73%

**Matchups outside 35–65% (A's win rate vs B):**

- 001(rush) vs 012(rest_punish): 96%
- 001(rush) vs 023(refresh_tempo): 100%
- 001(rush) vs 034(lockdown): 72%
- 001(rush) vs 045(filter_control): 78%
- 001(rush) vs 056(discount_deploy): 72%
- 001(rush) vs 067(drain): 94%
- 012(rest_punish) vs 001(rush): 0%
- 012(rest_punish) vs 023(refresh_tempo): 68%
- 012(rest_punish) vs 034(lockdown): 10%
- 012(rest_punish) vs 045(filter_control): 12%
- 012(rest_punish) vs 056(discount_deploy): 6%
- 012(rest_punish) vs 078(threshold_ramp): 4%
- 023(refresh_tempo) vs 001(rush): 0%
- 023(refresh_tempo) vs 034(lockdown): 4%
- 023(refresh_tempo) vs 045(filter_control): 12%
- 023(refresh_tempo) vs 056(discount_deploy): 4%
- 023(refresh_tempo) vs 067(drain): 12%
- 023(refresh_tempo) vs 078(threshold_ramp): 0%
- 034(lockdown) vs 001(rush): 26%
- 034(lockdown) vs 012(rest_punish): 92%
- 034(lockdown) vs 023(refresh_tempo): 96%
- 034(lockdown) vs 056(discount_deploy): 24%
- 034(lockdown) vs 067(drain): 72%
- 034(lockdown) vs 078(threshold_ramp): 10%
- 045(filter_control) vs 001(rush): 12%
- 045(filter_control) vs 012(rest_punish): 90%
- 045(filter_control) vs 023(refresh_tempo): 100%
- 045(filter_control) vs 034(lockdown): 26%
- 045(filter_control) vs 056(discount_deploy): 30%
- 045(filter_control) vs 067(drain): 74%
- 045(filter_control) vs 078(threshold_ramp): 18%
- 056(discount_deploy) vs 001(rush): 32%
- 056(discount_deploy) vs 012(rest_punish): 94%
- 056(discount_deploy) vs 023(refresh_tempo): 98%
- 056(discount_deploy) vs 034(lockdown): 70%
- 056(discount_deploy) vs 045(filter_control): 84%
- 056(discount_deploy) vs 067(drain): 98%
- 067(drain) vs 001(rush): 6%
- 067(drain) vs 034(lockdown): 32%
- 067(drain) vs 045(filter_control): 34%
- 067(drain) vs 056(discount_deploy): 6%
- 067(drain) vs 078(threshold_ramp): 18%
- 078(threshold_ramp) vs 001(rush): 34%
- 078(threshold_ramp) vs 012(rest_punish): 94%
- 078(threshold_ramp) vs 023(refresh_tempo): 98%
- 078(threshold_ramp) vs 034(lockdown): 96%
- 078(threshold_ramp) vs 045(filter_control): 78%
- 078(threshold_ramp) vs 067(drain): 96%

## Decklists (reproducible)

Each deck is **kit ×4 (40)** — the Vanguard's ten non-Vanguard cards, 4 copies each — **plus 10 filler** from colour-legal neighbour kits (4/4/2 of the top-ranked picks). All decks are 50 cards, ≤4 copies, colour-legal.

- **Sora Akaza, Redgale Captain** (001(rush)): kit wm01-002, wm01-003, wm01-004, wm01-005, wm01-006, wm01-007, wm01-008, wm01-009, wm01-010, wm01-011 ×4 + filler wm01-024, wm01-013, wm01-019
- **Kaya Morrow, Twilight Courier** (012(rest_punish)): kit wm01-013, wm01-014, wm01-015, wm01-016, wm01-017, wm01-018, wm01-019, wm01-020, wm01-021, wm01-022 ×4 + filler wm01-035, wm01-002, wm01-024
- **Bram Oxhart, Warband Chief** (023(refresh_tempo)): kit wm01-024, wm01-025, wm01-026, wm01-027, wm01-028, wm01-029, wm01-030, wm01-031, wm01-032, wm01-033 ×4 + filler wm01-035, wm01-002, wm01-013
- **Elder Neza, Route-Keeper** (034(lockdown)): kit wm01-035, wm01-036, wm01-037, wm01-038, wm01-039, wm01-040, wm01-041, wm01-042, wm01-043, wm01-044 ×4 + filler wm01-017, wm01-029, wm01-025
- **Director Averil Cros, the Kind Face** (045(filter_control)): kit wm01-046, wm01-047, wm01-048, wm01-049, wm01-050, wm01-051, wm01-052, wm01-053, wm01-054, wm01-055 ×4 + filler wm01-071, wm01-058, wm01-063
- **Commander Idris Vale, the Liaison** (056(discount_deploy)): kit wm01-057, wm01-058, wm01-059, wm01-060, wm01-061, wm01-062, wm01-063, wm01-064, wm01-065, wm01-066 ×4 + filler wm01-046, wm01-068, wm01-079
- **Dr. Halcyon Rue, Chief Harvester** (067(drain)): kit wm01-068, wm01-069, wm01-070, wm01-071, wm01-072, wm01-073, wm01-074, wm01-075, wm01-076, wm01-077 ×4 + filler wm01-049, wm01-082, wm01-058
- **Marshal Goran Dreyse, the Siegebreaker** (078(threshold_ramp)): kit wm01-079, wm01-080, wm01-081, wm01-082, wm01-083, wm01-084, wm01-085, wm01-086, wm01-087, wm01-088 ×4 + filler wm01-057, wm01-068, wm01-072

