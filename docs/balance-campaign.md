# WILDMIGRATION — Set 1 Balance Campaign

How Set 1 ("The First Stampede", WM01) was balanced with the headless engine,
from the first baseline to the alpha freeze at Patch 0.5. This document is both
the record of what happened and the **template for how Set 2 balance will run**.

---

## TL;DR

- We balanced with **AI-vs-AI simulation**, not intuition: one deterministic
  archetype pilot per Vanguard, a full 8×8 matchup matrix (64 matchups × 50
  games = 3200 games) at a fixed seed, re-run identically after every change.
- Before touching a single card we ran an **isolation pass** (ablations + a
  shared-pilot control) to separate *card power* from *pilot skill* and to prove
  which cards actually drove win rates.
- Five patches followed, each **buffs-only**, each **measured on matched seeds**
  against the same baseline, each **reported not tuned** — we never adjusted a
  pilot to flatter a number.
- Result: two of the three under-decks recovered on the strength of the cards
  alone (Bram 15→28%, Rue 34→42%); the rest is handed to human playtesting.

---

## The method

Everything below is reproducible from the repo (`sim/*.gd`, run under
`godot --headless`).

**Fixed baseline, matched seeds.** Matchup *i* of matchup-block *(A,B)* always
uses `seed = base + (A_index·8 + B_index)·games + i`. Every scenario — ablations,
control runs, all five patches — reuses that exact scheme, so any two runs differ
*only* by the thing under test. Deltas are apples-to-apples, not noise.

**Archetype pilots.** Each Vanguard is piloted toward its real gameplan
(`AIPolicy.for_vanguard`): rush races Life, lockdown rests+freezes, drain freezes
Aura, refresh_tempo loops big bodies, etc. A pilot is a lower bound on a deck's
strength — if the pilot can't win with it, that's evidence, but not proof the
deck is weak.

**The pilot-skill control (C0).** The same matrix run with **one shared generic
pilot** driving every deck. A win-rate gap that *persists* under one pilot is
attributable to **cards**; a gap that *collapses toward 50%* is **pilot skill**.
This is the single most important guard against over-reading the archetype
numbers.

**Ablations.** A runtime config layer (`GameState.ablations`) can disable or
weaken one card/effect with **no card-data change**. Re-running the full matrix
per ablation and reading the owning Vanguard's win-rate delta tells us whether a
suspect card is `REAL` (>5 pts) or `acquit` (<2 pts). This is how we knew *what
to patch* before writing any patch.

**Instrumentation.** Two always-on measurements:
- **Watch-list** — flags when specific cards resolve (Sora Rush grants, Stampede
  refreshes, Rue Aura frozen, …), normalised per game, so we can see whether a
  card is even being *used* before asking whether it's *good*.
- **Defence economy** — per-Vanguard connect rate (attacks that won / declared),
  counters spent per Life lost, and average attacker-vs-defender power at declare.
  This is what let us diagnose "small bodies bouncing off 5000-power Vanguards"
  as a mechanism, not a guess.

**Tolerances.** A matchup is a REVIEW item outside 35–65%; a Vanguard outside
45–55% overall. These are review triggers, not hard targets — a first set is not
expected to be flat.

---

## The narrative

### Baseline (Brief 3) + isolation (Brief 4)

The first full matrix, under real deckbuilding rules (50 + 1 Vanguard, ≤4 copies,
colour-legal, per-archetype decks), gave a wide spread: rush/discount/threshold
70–83%, and three clear under-decks — **refresh_tempo 15%, rest_punish 23%,
drain 34%**. The isolation pass then did the crucial work *before* any change:

- **Ablations** acquitted several suspects (Verdigris's 2nd rest, Korgan's
  self-refresh, Canyon's discount all moved their owners ≈0 pts) and flagged one
  as REAL (blanking Total Mobilisation cost threshold_ramp −17 pts).
- **C0** showed rush's and threshold's dominance largely *collapsed* under the
  generic pilot (much of it was pilot skill), while the under-decks stayed weak
  under both pilots (their weakness was *cards*).
- The **defence economy** table showed refresh_tempo connecting only 63% at 3920
  average attacker power against 5047 defender power — the "bounce" thesis.

So we entered the patch cycle knowing *which* decks were card-weak (the three
under-decks) and *why* (their bodies couldn't convert to damage).

### Patch 0.2 — economy

Six buffs making the under-decks' abilities cheaper / bigger. **Result: drain
34→44%** (and the C0 control showed the same +12, confirming it was the cards —
Rue's free-freeze economy — not the pilot). **Kaya and Bram stayed flat**: cheaper
abilities didn't help decks whose problem was conversion, not affordability.

### Patch 0.3 — conversion

Four buffs aimed at *converting* board presence to damage — headlined by widening
Bo & Lantern so its +3000 lands when swinging the **Vanguard** (not only a rested
Banner). **Result: Kaya 23→27%** — the widened line converts a rested board into
face damage. **Bram still flat**: its combo (Stampede loops) fired too rarely for
per-body power to matter.

### Patch 0.4 — structural (refresh)

The diagnosis turned structural: Bram's refresh package was **cost-capped** and
so could only ever refresh chaff — his Vanguard refresh was `max_cost 5` (Korgan,
his 8000 payoff at cost 7, was ineligible) and Stampede was `max_cost 3`.
Removing the caps let the refresh tools reach the deck's actual finishers.
**Result: Bram 14→29% (+15) — the biggest single move of the campaign.** The
`OVERSHOOT` check (a knowingly-accepted risk for the uncapped Korgan loop) did
**not** trigger — 29% overall, no matchup over 65%.

### Patch 0.5 — structural (rest) + freeze

The same structural lens on Kaya's rest package (Verdigris/Toll/Twilight
uncapped). **Result: Kaya 24→25% — marginal.** The finding: Kaya's rest reach was
*not* the bottleneck. She rests the biggest threat fine (auto-targeting is
power-sorted); her 4-Life, small-body clock simply loses the race. That is a
structural/archetype question a pilot can't safely arbitrate — so it goes to
playtesting, and Set 1 balance is **frozen** here.

---

## Headline lessons (carry these into Set 2)

1. **Separate card power from pilot skill first.** The C0 control changed how we
   read every subsequent number. Without it we'd have "buffed" decks that were
   only badly piloted.
2. **Ablate before you patch.** Knowing a card is `REAL` vs `acquit` stopped us
   from wasting patches on cards that didn't move win rate.
3. **Cheaper ≠ stronger.** Economy buffs (0.2) helped the deck whose problem was
   economy (drain) and no one else. Match the buff to the *mechanism* of the
   weakness — read the defence-economy table.
4. **Caps are silent balance.** The two biggest structural wins (0.4, 0.5) were
   just *removing `max_cost`* — a tool that can only touch the worst cards is a
   dead tool. Watch for reach-capped effects in Set 2.
5. **Know when to stop.** A simulator has a skill ceiling. When a deck resists
   every card-honest buff (Kaya), that's the signal to hand it to humans, not to
   keep buffing until the AI happens to win.
6. **Report, don't tune.** Every patch was measured on matched seeds and reported
   as-is, including the flat and the failed. Tuning the pilot to hit a target
   would have destroyed the measurement.

---

## What's handed to playtesting (Phase 3)

- The **high-end trio** (rush 77%, threshold 70%, discount 67%): strong under the
  archetype pilots but partly pilot-driven per C0. Whether their edge is real
  needs human play.
- **Kaya's residual weakness** (25%): buff-resistant in simulation; likely a
  Life-total / clock-speed question.
- The **matchup web**: 44/64 matchups still outside 35–65%. Many are the strong
  decks beating the weak ones — a spread that only real play can confirm or deny.

Balance work **resumes in the playable client**, not in the simulator.

---

## Reproducing / running it again (Set 2 template)

```bash
# Baseline + full matrix
godot --headless -s sim/balance.gd -- --games=50 --seed=1

# Isolation pass (per scenario, then consolidate)
for S in A0 A1 A2 A3 A4 A5 C0; do
  godot --headless -s sim/isolation.gd -- --scenario=$S --games=50 --seed=1
done
godot --headless -s sim/isolation.gd -- --consolidate

# A patch measurement (cached phases; matched seeds)
godot --headless -s sim/patch_report.gd -- --phase=archetype --games=50 --seed=1
godot --headless -s sim/patch_report.gd -- --phase=c0        --games=50 --seed=1
godot --headless -s sim/patch_report.gd -- --phase=consolidate5   # or 3 / 4
```

For Set 2: add the new archetype pilots, extend the ablation scenario list to
the new suspect cards, and keep the same discipline — **isolate, patch one lever,
measure on matched seeds, run the C0 control, report as-is.**

---

## Addendum — v1.1 baseline reset (Strict Purity)

*Added for patch 1.1. Everything above documents the 0.5 alpha campaign; this
note explains why those numbers are now VOID and what replaced them.*

**Why the baseline was reset.** Patch 1.1 made two changes that invalidate the
0.5 measurement rather than continue it:

1. **A legality rule change — Strict Purity.** Deck legality went from
   *share-a-colour* to **subset** (a deck card's colours must be a subset of the
   Vanguard's). This is not a card tweak; it changes *which decks exist*. Mono
   Vanguards lose every off-colour splash they previously ran, and dual
   Vanguards' legal pool shifts. The decks the pilots fly are materially
   different, so a win rate measured before the rule cannot be compared to one
   after it.
2. **A larger card pool — the Purity Twelve** (wm01-089..100). New staples enter
   the legal pools (e.g. Elder Grovetusk into red/green filler, Drillmaster into
   Dreyse's mono pool), again changing deck composition.

A balance number is only meaningful relative to a fixed set of decks and rules.
Change the decks or the rules and the old number measures a game that no longer
exists. So rather than diff against 0.5, we **struck 0.5 VOID** and re-measured
from scratch, on the *same seed protocol*, producing
[`revalidation_report.md`](../revalidation_report.md).

**What we did NOT do.** No card was patched and no pilot logic changed — the new
cards use only existing effect types, and the pilots pick them up through the
same archetype heuristics. This brief **re-measured**; it did not tune. Any
imbalance the 1.1 baseline shows (rush still high; rest_punish / refresh_tempo
still card-weak under both pilots) is reported as-is for human playtesting, in
keeping with rule 6 above (*report, don't tune*).

**Method unchanged.** The revalidation is the same discipline this document
prescribes for Set 2: full 8×8 matrix, C0 shared-pilot control, matched seeds,
defence-economy and watch-list instrumentation, REVIEW tolerances — just re-run
because the ground under the old baseline moved.
