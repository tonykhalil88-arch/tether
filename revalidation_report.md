# WILDMIGRATION — Patch 1.1 Revalidation (Strict Purity)

Full 8×8 matchup matrix + the C0 pilot-skill control, re-run after the **Strict Purity** rule change and the **Purity Twelve** (wm01-089..100). **50** games per ordered matchup (first player split evenly), **3200** total archetype games + the same again for C0, base seed **1**, matched seed blocks.

> **The old 0.5 baseline is VOID.** It was measured under the previous legality (*share-a-colour*) and a smaller card pool. Strict Purity gives mono Vanguards a different 13-card pool and dual Vanguards a larger one, so the two baselines are **not comparable** — the 0.5 numbers below are shown for orientation only, struck as VOID. **This 1.1 run is the new baseline.**

## Per-Vanguard standings (archetype pilots)

| Vanguard | Archetype | 1.1 win rate | ~~0.5 (VOID)~~ | Avg turns |
|---|---|---|---|---|
| 001(rush) | rush | 81% **REVIEW** | ~~77%~~ | 7.1 |
| 012(rest_punish) | rest_punish | 28% **REVIEW** | ~~25%~~ | 8.0 |
| 023(refresh_tempo) | refresh_tempo | 28% **REVIEW** | ~~28%~~ | 7.8 |
| 034(lockdown) | lockdown | 40% **REVIEW** | ~~46%~~ | 11.2 |
| 045(filter_control) | filter_control | 46% | ~~45%~~ | 9.0 |
| 056(discount_deploy) | discount_deploy | 63% **REVIEW** | ~~67%~~ | 7.1 |
| 067(drain) | drain | 45% | ~~42%~~ | 8.8 |
| 078(threshold_ramp) | threshold_ramp | 70% **REVIEW** | ~~70%~~ | 7.5 |

## C0 — pilot-skill control (shared generic pilot)

A gap that persists under one shared pilot is attributable to **cards**; a gap that collapses toward 50% is **pilot skill**.

| Vanguard | 1.1 archetype | 1.1 C0 | Shift | ~~0.5 C0 (VOID)~~ |
|---|---|---|---|---|
| 001(rush) | 81% | 68% | -13 | ~~60%~~ |
| 012(rest_punish) | 28% | 25% | -3 | ~~23%~~ |
| 023(refresh_tempo) | 28% | 22% | -6 | ~~24%~~ |
| 034(lockdown) | 40% | 54% | +14 | ~~61%~~ |
| 045(filter_control) | 46% | 69% | +23 | ~~72%~~ |
| 056(discount_deploy) | 63% | 56% | -7 | ~~60%~~ |
| 067(drain) | 45% | 54% | +9 | ~~50%~~ |
| 078(threshold_ramp) | 70% | 52% | -18 | ~~51%~~ |

## Win-rate matrix (row = A's Vanguard, cell = A's win rate vs column B)

| A \ B | 001(rush) | 012(rest_punish) | 023(refresh_tempo) | 034(lockdown) | 045(filter_control) | 056(discount_deploy) | 067(drain) | 078(threshold_ramp) |
|---|---|---|---|---|---|---|---|---|
| **001(rush)** | 42% | 98%⚠ | 92%⚠ | 90%⚠ | 82%⚠ | 74%⚠ | 98%⚠ | 56% |
| **012(rest_punish)** | 10%⚠ | 52% | 52% | 24%⚠ | 22%⚠ | 20%⚠ | 40% | 20%⚠ |
| **023(refresh_tempo)** | 0%⚠ | 48% | 58% | 32%⚠ | 34%⚠ | 20%⚠ | 26%⚠ | 14%⚠ |
| **034(lockdown)** | 8%⚠ | 82%⚠ | 64% | 44% | 34%⚠ | 24%⚠ | 44% | 10%⚠ |
| **045(filter_control)** | 16%⚠ | 72%⚠ | 76%⚠ | 56% | 50% | 32%⚠ | 38% | 30%⚠ |
| **056(discount_deploy)** | 28%⚠ | 78%⚠ | 84%⚠ | 74%⚠ | 76%⚠ | 48% | 72%⚠ | 38% |
| **067(drain)** | 8%⚠ | 80%⚠ | 70%⚠ | 66%⚠ | 54% | 18%⚠ | 50% | 30%⚠ |
| **078(threshold_ramp)** | 32%⚠ | 82%⚠ | 90%⚠ | 88%⚠ | 76%⚠ | 60% | 86%⚠ | 56% |

## Defence economy (per Vanguard)

| Vanguard | Connect rate | Counters / Life lost | Avg attacker pow | Avg defender pow |
|---|---|---|---|---|
| 001(rush) | 72% | 0.08 | 4590 | 5179 |
| 012(rest_punish) | 85% | 0.16 | 4745 | 4756 |
| 023(refresh_tempo) | 62% | 0.20 | 4005 | 5152 |
| 034(lockdown) | 65% | 0.39 | 4541 | 5356 |
| 045(filter_control) | 72% | 0.32 | 4030 | 4742 |
| 056(discount_deploy) | 69% | 0.09 | 4335 | 5179 |
| 067(drain) | 75% | 0.32 | 4371 | 4644 |
| 078(threshold_ramp) | 66% | 0.12 | 4753 | 5332 |

## Balance watch-list (total resolutions across the matrix)

| Flag | Total |
|---|---|
| sora_rush_grants | 216 |
| verdigris_double_rest | 185 |
| korgan_repeat_attacks | 1 |
| stampede_multi_refresh | 37 |
| averil_cards_seen | 3312 |
| rue_aura_frozen | 3116 |

## REVIEW flags

Tolerances: matchup 35–65%, per-Vanguard 45–55%.

- Vanguards outside 45–55%: **6 / 8** — 001(rush) (81%), 012(rest_punish) (28%), 023(refresh_tempo) (28%), 034(lockdown) (40%), 056(discount_deploy) (63%), 078(threshold_ramp) (70%)
- Matchups outside 35–65%: **45 / 64** cells.
- Overall first-player win rate: **58%**.

## Decklists under Strict Purity

**001(rush)** (Sora Akaza, Redgale Captain, red) — 13 uniques. 13 legal uniques (kit 10 + 3 staples) at 4 copies = 52, trimmed 2: one copy each off **wm01-011, wm01-010** (lowest archetype-ranked).

**012(rest_punish)** (Kaya Morrow, Twilight Courier, red/green) — 13 uniques. kit ×4 (40) + 10 filler: **wm01-035, wm01-094, wm01-002**.

**023(refresh_tempo)** (Bram Oxhart, Warband Chief, red/green) — 13 uniques. kit ×4 (40) + 10 filler: **wm01-035, wm01-094, wm01-002**.

**034(lockdown)** (Elder Neza, Route-Keeper, green) — 13 uniques. 13 legal uniques (kit 10 + 3 staples) at 4 copies = 52, trimmed 2: one copy each off **wm01-043, wm01-044** (lowest archetype-ranked).

**045(filter_control)** (Director Averil Cros, the Kind Face, blue) — 13 uniques. 13 legal uniques (kit 10 + 3 staples) at 4 copies = 52, trimmed 2: one copy each off **wm01-054, wm01-055** (lowest archetype-ranked).

**056(discount_deploy)** (Commander Idris Vale, the Liaison, blue/purple) — 13 uniques. kit ×4 (40) + 10 filler: **wm01-100, wm01-046, wm01-068**.

**067(drain)** (Dr. Halcyon Rue, Chief Harvester, blue/purple) — 13 uniques. kit ×4 (40) + 10 filler: **wm01-049, wm01-082, wm01-058**.

**078(threshold_ramp)** (Marshal Goran Dreyse, the Siegebreaker, purple) — 13 uniques. 13 legal uniques (kit 10 + 3 staples) at 4 copies = 52, trimmed 2: one copy each off **wm01-088, wm01-087** (lowest archetype-ranked).

