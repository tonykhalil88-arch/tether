# WILDMIGRATION — Patch 1.2 Revalidation (Mono Recolour)

Full 8×8 matchup matrix + the C0 pilot-skill control, re-run after the **mono recolour** (40 cards recoloured so only Vanguards are multi-coloured; colour pools grew to Red 18 / Green 28 / Blue 21 / Purple 25). **50** games per ordered matchup (first player split evenly), **3200** total archetype games + the same again for C0, base seed **1**, matched seed blocks.

> **The v1.1 baseline is VOID.** It was measured before the recolour changed which decks exist — mono Vanguards now shop a much larger single-colour pool (real cross-kit tech), and dual Vanguards see both full mono pools. The v1.1 numbers below are shown for orientation only, struck as VOID. **This 1.2 run is the new baseline.**

## Per-Vanguard standings (archetype pilots)

| Vanguard | Archetype | 1.2 win rate | ~~1.1 (VOID)~~ | Avg turns |
|---|---|---|---|---|
| 001(rush) | rush | 78% **REVIEW** | ~~81%~~ | 7.3 |
| 012(rest_punish) | rest_punish | 26% **REVIEW** | ~~28%~~ | 8.0 |
| 023(refresh_tempo) | refresh_tempo | 27% **REVIEW** | ~~28%~~ | 7.9 |
| 034(lockdown) | lockdown | 48% | ~~40%~~ | 15.4 |
| 045(filter_control) | filter_control | 48% | ~~46%~~ | 9.4 |
| 056(discount_deploy) | discount_deploy | 63% **REVIEW** | ~~63%~~ | 7.2 |
| 067(drain) | drain | 43% **REVIEW** | ~~45%~~ | 9.0 |
| 078(threshold_ramp) | threshold_ramp | 69% **REVIEW** | ~~70%~~ | 7.6 |

## C0 — pilot-skill control (shared generic pilot)

A gap that persists under one shared pilot is attributable to **cards**; a gap that collapses toward 50% is **pilot skill**.

| Vanguard | 1.2 archetype | 1.2 C0 | Shift | ~~1.1 C0 (VOID)~~ |
|---|---|---|---|---|
| 001(rush) | 78% | 63% | -15 | ~~68%~~ |
| 012(rest_punish) | 26% | 26% | -1 | ~~25%~~ |
| 023(refresh_tempo) | 27% | 21% | -5 | ~~22%~~ |
| 034(lockdown) | 48% | 61% | +14 | ~~54%~~ |
| 045(filter_control) | 48% | 75% | +27 | ~~69%~~ |
| 056(discount_deploy) | 63% | 55% | -8 | ~~56%~~ |
| 067(drain) | 43% | 52% | +9 | ~~54%~~ |
| 078(threshold_ramp) | 69% | 48% | -21 | ~~52%~~ |

## Win-rate matrix (row = A's Vanguard, cell = A's win rate vs column B)

| A \ B | 001(rush) | 012(rest_punish) | 023(refresh_tempo) | 034(lockdown) | 045(filter_control) | 056(discount_deploy) | 067(drain) | 078(threshold_ramp) |
|---|---|---|---|---|---|---|---|---|
| **001(rush)** | 52% | 94%⚠ | 96%⚠ | 80%⚠ | 80%⚠ | 74%⚠ | 94%⚠ | 66%⚠ |
| **012(rest_punish)** | 4%⚠ | 52% | 52% | 22%⚠ | 14%⚠ | 20%⚠ | 40% | 10%⚠ |
| **023(refresh_tempo)** | 4%⚠ | 48% | 58% | 34%⚠ | 18%⚠ | 20%⚠ | 26%⚠ | 20%⚠ |
| **034(lockdown)** | 24%⚠ | 74%⚠ | 68%⚠ | 60% | 56% | 40% | 52% | 18%⚠ |
| **045(filter_control)** | 28%⚠ | 84%⚠ | 80%⚠ | 30%⚠ | 48% | 34%⚠ | 56% | 20%⚠ |
| **056(discount_deploy)** | 32%⚠ | 78%⚠ | 84%⚠ | 62% | 72%⚠ | 48% | 72%⚠ | 48% |
| **067(drain)** | 12%⚠ | 80%⚠ | 70%⚠ | 52% | 54% | 18%⚠ | 50% | 18%⚠ |
| **078(threshold_ramp)** | 34%⚠ | 86%⚠ | 92%⚠ | 92%⚠ | 74%⚠ | 42% | 80%⚠ | 52% |

## Defence economy (per Vanguard)

| Vanguard | Connect rate | Counters / Life lost | Avg attacker pow | Avg defender pow |
|---|---|---|---|---|
| 001(rush) | 74% | 0.09 | 4708 | 5260 |
| 012(rest_punish) | 84% | 0.17 | 4779 | 4759 |
| 023(refresh_tempo) | 60% | 0.20 | 4033 | 5152 |
| 034(lockdown) | 51% | 0.40 | 4481 | 5892 |
| 045(filter_control) | 65% | 0.38 | 3804 | 4764 |
| 056(discount_deploy) | 67% | 0.09 | 4369 | 5211 |
| 067(drain) | 74% | 0.33 | 4424 | 4642 |
| 078(threshold_ramp) | 66% | 0.12 | 4869 | 5322 |

## Balance watch-list (total resolutions across the matrix)

| Flag | Total |
|---|---|
| sora_rush_grants | 247 |
| verdigris_double_rest | 177 |
| korgan_repeat_attacks | 1 |
| stampede_multi_refresh | 39 |
| averil_cards_seen | 3429 |
| rue_aura_frozen | 3165 |

## REVIEW flags

Tolerances: matchup 35–65%, per-Vanguard 45–55%.

- Vanguards outside 45–55%: **6 / 8** — 001(rush) (78%), 012(rest_punish) (26%), 023(refresh_tempo) (27%), 056(discount_deploy) (63%), 067(drain) (43%), 078(threshold_ramp) (69%)
- Matchups outside 35–65%: **44 / 64** cells.
- Overall first-player win rate: **58%**.

## Decklists under the mono recolour

Every Vanguard builds the same way now: own kit ×4 (40) + 10 ranked filler (4+4+2) from its subset-legal pool.

**001(rush)** (Sora Akaza, Redgale Captain, red) — kit ×4 (40) + filler **wm01-019, wm01-091, wm01-027** (4+4+2).

**012(rest_punish)** (Kaya Morrow, Twilight Courier, red/green) — kit ×4 (40) + filler **wm01-035, wm01-094, wm01-002** (4+4+2).

**023(refresh_tempo)** (Bram Oxhart, Warband Chief, red/green) — kit ×4 (40) + filler **wm01-035, wm01-094, wm01-002** (4+4+2).

**034(lockdown)** (Elder Neza, Route-Keeper, green) — kit ×4 (40) + filler **wm01-017, wm01-029, wm01-025** (4+4+2).

**045(filter_control)** (Director Averil Cros, the Kind Face, blue) — kit ×4 (40) + filler **wm01-071, wm01-074, wm01-095** (4+4+2).

**056(discount_deploy)** (Commander Idris Vale, the Liaison, blue/purple) — kit ×4 (40) + filler **wm01-100, wm01-046, wm01-068** (4+4+2).

**067(drain)** (Dr. Halcyon Rue, Chief Harvester, blue/purple) — kit ×4 (40) + filler **wm01-049, wm01-082, wm01-058** (4+4+2).

**078(threshold_ramp)** (Marshal Goran Dreyse, the Siegebreaker, purple) — kit ×4 (40) + filler **wm01-100, wm01-068, wm01-060** (4+4+2).

