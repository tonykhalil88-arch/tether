# WILDMIGRATION — Rules Engine

A **headless** digital TCG rules engine for WILDMIGRATION, built in Godot 4.5 /
GDScript. Engine-only: pure logic, zero rendering, everything testable and
runnable from the command line. Presentation comes later.

Two players duel with a 50-card deck plus a single Vanguard. Card types are
**Vanguard**, **Banner** (creature), **Technique** (one-shot) and **Stage**
(persistent field). The engine runs the real **WM01 "The First Stampede"** set
— 88 cards across five tribes (Redgale, Runner, Pact, Consortium, Bulwark).

**Phase 3 adds a playable human-vs-AI 3D client** on top of this frozen engine
(`client/`, main scene `client/main.tscn`). The client is a pure consumer: it
drives the engine through the same public API the AI policies use and renders by
translating the public `state.log` into presentation beats — **zero rules in
presentation code, engine untouched.** See **[SCREENS.md](SCREENS.md)** for a
board capture, the mouse controls, and run notes.

---

## Requirements

- **Godot 4.5** (headless — no GPU needed).
- **GUT 9.5.0**, the Godot Unit Test framework, vendored under `addons/gut/`
  (the release that targets Godot 4.5). No other third-party dependencies.

Godot resolves `class_name` globals during an editor import scan. After adding
or renaming a script, run one import pass before testing:

```bash
godot --headless --editor --quit
```

---

## Project structure

```
wildmigration/
├── project.godot
├── engine/                       # rules engine — pure logic, no rendering
│   ├── game_engine.gd            # turn structure, combat, freeze, passives (core)
│   ├── cards/
│   │   ├── card_enums.gd         # canonical vocab (types, keywords, triggers, actions)
│   │   └── card_data.gd          # immutable printed card definition (Resource)
│   ├── state/
│   │   ├── game_state.gd         # per-game container (players, turn, rng, log, watch)
│   │   ├── player_state.gd       # zones + Aura economy + freeze / cost bookkeeping
│   │   ├── card_instance.gd      # a physical card in play (runtime state)
│   │   └── event_bus.gd          # synchronous publish/subscribe hub
│   └── effects/
│       ├── effect_engine.gd      # data-driven effect resolver (WM01 schema)
│       └── hooks.gd              # GDScript hook escape hatch for bespoke effects
├── data/cards/
│   └── wildmigration_set1.json   # WM01 — 88 cards
├── tools/importer.gd             # JSON <-> CardData importer (lossless)
├── sim/
│   ├── ai_policy.gd              # two AI policies (aggro / guard), Rush + Freeze aware
│   ├── match_runner.gd           # AI-vs-AI game loop, batch runner, watch-list
│   └── run.gd                    # headless CLI entry point
├── client/                       # Phase 3 — playable human-vs-AI 3D client
│   ├── main.gd / main.tscn       # app root: menu -> table -> win/loss
│   ├── assets/asset_manifest.gd  # 4-channel art resolver (sprite/SFX/VFX/voice)
│   ├── present/                  # CardFrame, PixelFont, PresentationQueue, SummonStateMachine, vfx_burst
│   ├── match/match_controller.gd # drives the frozen engine via its public API
│   ├── board/                    # 3D table + unit/hand card views + input
│   └── ui/                       # HUD, main menu, win/loss
├── assets/cards/<id>/            # per-card art drop (2 fully-wired examples)
├── tools/gen_client_assets.gd    # procedural placeholder-asset generator
├── tools/gen_screens.gd          # board-schematic capture for SCREENS.md
├── tests/                        # GUT suites + helpers (engine + client smoke)
└── addons/gut/                   # vendored GUT 9.5.0
```

---

## Running the tests

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs=true -gexit
```

All suites report **All tests passed!** (155 tests: 139 engine + 16 client).
The client suites (`test_client_smoke.gd`, `test_readability_smoke.gd`) cover the
Phase 3 presentation layer and the Brief 10 readability pass (card-text
synthesis, inspector data binding, deterministic placeholder art). Coverage:

| Suite | Covers |
|-------|--------|
| `test_importer.gd` | round-trip over all 88 cards, validation, power ceiling |
| `test_setup.gd` | opening hand, 5-mono / 4-dual Life, free mulligan |
| `test_turn_flow.gd` | phase order, Refresh, turn/battle buff expiry, no hand cap |
| `test_first_player.gd` | first-player skip-draw + 1-Aura asymmetries |
| `test_aura.gd` | Aura gain / spend / refresh and the cap of 10 |
| `test_combat.gd` | power math, KO, attach-Aura, counters, Blocker, When-Attacking |
| `test_rush.gd` | summoning sickness and the Rush exception |
| `test_freeze.gd` | freeze persistence, Banner-freeze cap, uncapped Aura freeze |
| `test_life_trigger.gd` | Life-to-hand flip, `play_self` life triggers |
| `test_win_condition.gd` | lethal hit at 0 Life |
| `test_zones_limits.gd` | Battle Area cap of 5, Stage uniqueness |
| `test_cost_reduction.gd` | Vale + Canyon stack to -2, floored at cost 1 |
| `test_passives.gd` | Dreyse dynamic threshold, Siegeworks, Old Hollow |
| `test_effects.gd` | event bus, WM01 actions, hook escape hatch |
| `test_watch.gd` | balance watch-list counters increment on resolution |
| `test_ai_behavior.gd` | AI understands Rush and Freeze |
| `test_policies.gd` | each archetype's signature line (incl. Stampede loops) |
| `test_deck_validator.gd` | 50-card / max-4-copies / colour-legality rules |
| `test_ablations.gd` | ablation flags (A1–A5) + defence-economy metrics |
| `test_patch02.gd` | Patch 0.2 values + the Stampede `refreshed` rider |
| `test_patch03.gd` | Patch 0.3 values + the `defender_has_rested_banner` line |
| `test_patch04.gd` | Patch 0.4 uncapped refresh (Bram/Stampede) + Kaya rest-5 |
| `test_patch05.gd` | Patch 0.5 uncapped rest package + biggest-threat targeting |
| `test_sim.gd` | simulator determinism + batch integrity |

---

## Running the simulator

`sim/run.gd` plays AI-vs-AI games headlessly, rotating through every Vanguard
match-up, and prints a per-game summary plus an aggregate report. With `--out`
it writes a structured JSON log per game.

```bash
# 100 games, seeded, logs written to ./sim_logs/
godot --headless -s sim/run.gd -- --games=100 --seed=1 --out=sim_logs

# quick, quiet smoke run
godot --headless -s sim/run.gd -- --games=10 --seed=1 --quiet
```

Flags (after `--`): `--games=N` (default 10), `--seed=S` (default 1; game `i`
uses `S+i`), `--out=DIR`, `--quiet`.

### Archetype-aware pilots

Each Vanguard is piloted toward its own gameplan — `AIPolicy.for_vanguard(id)`
maps the Vanguard to one of eight deterministic policies (`sim/ai_policy.gd`):

| Vanguard | Archetype | Plan |
|----------|-----------|------|
| Sora (001) | `rush` | convert the Vanguard buff into Rush damage, swing wide |
| Kaya (012) | `rest_punish` | rest a target, then attack rested Banners |
| Bram (023) | `refresh_tempo` | field the biggest Pact bodies, loop them via Korgan / Bram / Stampede refreshes |
| Neza (034) | `lockdown` | rest + freeze the biggest threat, hold Blockers |
| Averil (045) | `filter_control` | filter every turn, hold counters, bounce, win late |
| Vale (056) | `discount_deploy` | Canyon + discount, then the biggest Bulwark |
| Rue (067) | `drain` | maximise Aura frozen per turn, trade evenly |
| Dreyse (078) | `threshold_ramp` | ramp to 8+ Aura, leverage the threshold, drop Walkbreaker |

Every policy understands **Rush** and **Freeze**.

### Balance matrix

`sim/balance.gd` runs the full 8×8 Vanguard matchup matrix (64 ordered
matchups × 50 games, first player split 25/25 = 3200 games) and writes
`balance_report.json` + `balance_report.md`:

```bash
godot --headless -s sim/balance.gd -- --games=50 --seed=1
```

Flags: `--games=N` per matchup (default 50), `--seed=S` (default 1), `--out=DIR`
(default: project root). The report contains the 8×8 win-rate matrix (row =
Player A's Vanguard), per-Vanguard overall win rate and average game length, the
first-player win rate (overall and per matchup), the watch-list normalised per
game, the **defence economy** (connect rate, counters per Life lost, avg
attacker vs defender power), the exact decklists, and **REVIEW** flags for any
matchup outside 35–65% or Vanguard outside 45–55%. Results reflect both card
balance *and* pilot skill — first-pass evidence, not a verdict.

### Isolation pass (ablations + control)

`sim/isolation.gd` separates card power from pilot skill. It runs the full
matrix once per scenario on the *same* seed blocks as the baseline, so
per-Vanguard win-rate deltas are apples-to-apples:

- **A0** new-rules baseline · **A1** Sora Rush rider off · **A2** Total
  Mobilisation blanked · **A3** Canyon discount off (Vale passive stays) ·
  **A4** Verdigris rests 1 · **A5** Korgan self-refresh off · **C0** every deck
  piloted by one shared generic pilot.

Each scenario writes a partial, then a consolidation step produces
`isolation_report.md`:

```bash
for S in A0 A1 A2 A3 A4 A5 C0; do
  godot --headless -s sim/isolation.gd -- --scenario=$S --games=50 --seed=1
done
godot --headless -s sim/isolation.gd -- --consolidate
```

Ablations are pure runtime config (`GameState.ablations`) — **no card data is
changed**. A suspect card is `REAL` if its owning Vanguard shifts >5 points,
`acquit` if <2. C0 shows which win rates are cards (persist under one pilot) vs
pilot skill (collapse toward 50%).

### Patch measurement

`sim/patch_report.gd` reruns the archetype matrix and the C0 matrix under the
current card data on the baseline seed blocks, then compares against the
isolation A0/C0 baselines, writing `patch02_report.md` (per-Vanguard before/
after for both pilots, connect-rate deltas for the buffed decks, remaining
REVIEW flags):

```bash
godot --headless -s sim/patch_report.gd -- --phase=archetype --games=50 --seed=1
godot --headless -s sim/patch_report.gd -- --phase=c0 --games=50 --seed=1
godot --headless -s sim/patch_report.gd -- --phase=consolidate
```

---

## Balance status: FROZEN at v1.1 (Strict Purity baseline)

Set 1 balance is **re-frozen at patch 1.1**. The **Strict Purity** rule change
(§ *Deckbuilding*: a deck card's colour set must be a **subset** of the
Vanguard's) together with the **Purity Twelve** (wm01-089..100, three mono
Banners per colour) changed both deck legality *and* the card pool. That resets
the measurement: the old Patch 0.5 alpha baseline is **VOID** — measured under
the previous *share-a-colour* legality and a smaller pool, so it is not
comparable, only historical. A fresh full 8×8 matrix + C0 control was re-run on
the same seed protocol → [`revalidation_report.md`](revalidation_report.md).

**Baseline commit:** the v1.1 Strict-Purity baseline is commit `4cc2dea`
(the "re-freeze at v1.1" commit that records this section). Check it
out directly to reproduce; the environment's git proxy blocks tag pushes
(feature-branch pushes only), so a `v1.1-strict-purity-baseline` tag may need to
be created on that SHA from an environment with tag-push permission — same
practice as the 0.5 baseline (`54cbe82`).

**New per-Vanguard standings** (patch 1.1, archetype pilots, 50 games × 64
matchups; C0 = shared generic pilot; ~~struck~~ = old 0.5, **VOID**):

| Vanguard | Archetype | 1.1 win rate | 1.1 C0 | ~~0.5 (VOID)~~ | Status |
|----------|-----------|--------------|--------|----------------|--------|
| Sora (001) | rush | 81% | 68% | ~~77%~~ | over — for playtesting |
| Threshold (078) | threshold_ramp | 70% | 52% | ~~70%~~ | over — mostly pilot (C0 −18) |
| Discount (056) | discount_deploy | 63% | 56% | ~~67%~~ | over — for playtesting |
| Filter (045) | filter_control | 46% | 69% | ~~45%~~ | in tolerance (strong under C0) |
| Drain (067) | drain | 45% | 54% | ~~42%~~ | in tolerance |
| Lockdown (034) | lockdown | 40% | 54% | ~~46%~~ | under — pilot-driven dip |
| Rest-punish (012) | rest_punish | 28% | 25% | ~~25%~~ | under — card-weak, persists in C0 |
| Refresh-tempo (023) | refresh_tempo | 28% | 22% | ~~28%~~ | under — card-weak, persists in C0 |

**Reading:** under Strict Purity the mono decks lose their off-colour splashes
and the dual decks gain a wider legal pool, which is exactly where the numbers
moved. rush stays dominant and pilot-independent; **threshold's 70% is now
mostly pilot** (C0 collapses it to 52%); the two persistent under-decks
(rest_punish, refresh_tempo) stay weak under *both* pilots, so their weakness is
**cards, not piloting**. 6/8 Vanguards and 45/64 matchups sit outside tolerance
— a first-set spread, handed to **human playtesting in the client**, not tuned
here. This brief only **re-measured** the new rules; it applied no card patches.

The prior five-patch alpha campaign (Patches 0.2–0.5) remains documented in
[`docs/balance-campaign.md`](docs/balance-campaign.md) and `patch0{2..5}_report.md`
as history — its numbers are **VOID** under Strict Purity but its *method* is the
template this revalidation followed.

---

## Changelog

### Patch 1.1 — Strict Purity + the Purity Twelve (baseline reset)

A **rule change** and a **12-card addition**, no card patches. This resets the
balance baseline (see *Balance status* above); the 0.5 campaign numbers are VOID
under the new legality.

**Rule change — Strict Purity.** Deck legality was *share-a-colour* (a deck card
had to share ≥1 colour with the Vanguard). It is now **subset**: a deck card is
legal iff its colour set is a subset of the Vanguard's. A mono-red Vanguard
admits only mono-red cards; a red/green Vanguard admits mono-red, mono-green and
red/green — but never a card carrying a colour the Vanguard lacks. Deck size
(50 + Vanguard) and the 4-copy cap are unchanged.

**The Purity Twelve** — twelve new mono-colour Banners, three per colour, all
using existing effect types (data-only), so no engine or pilot logic changed:

| Colour | New Banners |
|--------|-------------|
| red | wm01-089 Redgale Duelist Hana · 090 Ashvane Skirmishers (Rush) · 091 Ragnir's Brood (KO ≤3000) |
| green | wm01-092 Pact Shieldwall (Blocker) · 093 Waystone Sentry (rest ≤3) · 094 Elder Grovetusk (8000) |
| blue | wm01-095 Junior Actuary (Life: draw) · 096 Consortium Archivist (draw-then-bottom) · 097 Repossession Officer (bounce ≤3) |
| purple | wm01-098 Supply Column (gain Aura) · 099 Garrison Drillmaster (threshold self-buff) · 100 Rampart Colossus (8000) |

**Deck construction under Strict Purity.** Mono Vanguards now have exactly 13
subset-legal uniques (kit 10 + the 3 mono staples): 13×4 = 52, trimmed to 50 by
dropping one copy each off the two lowest archetype-ranked cards (documented per
deck in `revalidation_report.md`). Dual Vanguards keep kit ×4 (40) + 10 filler
drawn from their now-larger subset-legal pool (both mono pools + both dual kits),
ranked by the existing archetype heuristic. Set size 88 → **100**.

### Patch 0.5 — "the last structural uncap" (evidence: Patch 0.4 measurement)

Patch 0.4's uncap fixed Bram; Patch 0.5 applies the same structural lens to
Kaya's rest package, whose reach was capped so it could only rest chaff. Three
changes, buffs only, everyone else untouched:

| # | Card | Change | Rationale |
|---|------|--------|-----------|
| 1 | Verdigris (wm01-013) | double-rest `max_cost` removed | rest any two enemy Banners (Walkbreaker-class included) |
| 2 | Toll of the Quiet Road (wm01-020) | both modes `max_cost` 4 → 6 | reach the big attackers |
| 3 | The Twilight Road (wm01-022) | `max_cost` 3 → 4 | reach Greatox-class bodies |

No engine or pilot change was needed: rest effects already auto-target the
**highest-power** eligible Banner (verified by test), so the widened reach flows
straight into "rest the biggest legal threat."

**Measured outcome** (`patch05_report.md`): **Kaya/rest_punish 24 → 25%** — the
rest uncap barely moved it (connect rate ticked 83→84%). The finding is that
Kaya's weakness is **not** rest reach — she resets bodies fine but her 4-Life,
small-body clock loses the race. That is exactly the kind of structural question
handed to playtesting. Rue and Bram held (stable, untouched controls); no new
Vanguard overshoots from this patch.

### Patch 0.4 — "refresh tools could only touch the worst cards" (evidence: Patch 0.3 measurement)

Patches 0.2–0.3 showed Bram/refresh_tempo stuck at ~14% despite cheaper and
higher-value refresh effects. The diagnosis was structural: the refresh package
was *cost-capped* and so could only ever touch chaff — Bram's Vanguard refresh
was `max_cost 5` (Korgan, his 8000 payoff at cost 7, was ineligible) and
Stampede was `max_cost 3` (only the smallest bodies). Patch 0.4 removes those
caps so the tools reach the deck's actual finishers. Three changes, buffs only:

| # | Card | Change | Rationale |
|---|------|--------|-----------|
| 1 | Bram Vanguard (wm01-023) | refresh `max_cost` removed | can refresh Korgan (cost 7) for a repeat swing |
| 2 | Stampede Doctrine (wm01-032) | `max_cost` removed, +2000 rider removed | refresh two of *any* Pact Banners — big bodies, not chaff |
| 3 | Kaya Vanguard (wm01-012) | rest `max_cost` 4 → 5 | reach Greatox-class Banners |

No engine change was needed (a removed `max_cost` defaults to uncapped; a
removed rider is a no-op — the engine's rider support is retained and covered by
a synthetic test). The `refresh_tempo` pilot was rebuilt to the new plan: field
the **biggest** Pact bodies (no Aura reserve) and loop them via Korgan's
self-refresh + Bram + Stampede on later turns.

**Measured outcome** (`patch04_report.md`, matched seeds): **Bram/refresh_tempo
14% → 29% (+15 pts)** — the biggest single-patch move so far; the structural fix
did what the cost/value tweaks couldn't. The **OVERSHOOT check was not
triggered** (29% overall < 55%, no Bram matchup > 65%), so the knowingly-accepted
Korgan-loop risk did not materialise. Rue held (43→42%, untouched control); the
Kaya rest nudge was inert (27→24%); the field drifted down 2–8 pts as a stronger
Bram takes points off everyone (zero-sum). Reported, not tuned.

### Patch 0.3 — "conversion, not cost" (evidence: Patch 0.2 measurement)

Patch 0.2 showed cheaper abilities alone didn't move Kaya or Bram — their
problem is *converting* board presence into damage, not affording it. Patch 0.3
is four **buffs only**, aimed at conversion (Rue is deliberately untouched as a
measurement-stability control):

| # | Card | Change | Rationale |
|---|------|--------|-----------|
| 1 | Bo & Lantern (wm01-015) | condition `target_is_rested` → `defender_has_rested_banner` | the +3000 now lands when swinging the **Vanguard**, not only a rested Banner — so a rested board converts to face damage |
| 2 | Smuggler's Debt (wm01-014) | power 4000 → 5000 | a Kaya body that connects with a 5000 Vanguard |
| 3 | Stampede Doctrine (wm01-032) | rider +1000 → +2000 | refreshed Pact bodies swing over 5000 defenders |
| 4 | Rhoswen (wm01-028) | power 5000 → 6000 | a Bram body that trades up |

The new `defender_has_rested_banner` condition (true when the defending player
controls ≥1 rested Banner, regardless of the attack target) is implemented in
`EffectEngine`; the `rest_punish` pilot now swings Bo & Lantern at the Vanguard
once that line is live.

**Measured outcome** (`patch03_report.md`, matched seeds): **Kaya/rest_punish
moved up, 23% → 27% (+3, connect rate 81→83%)** — the widened line converts.
**Bram/refresh_tempo stayed flat (15→14%)**: the Stampede/Rhoswen buffs did not
move it (refresh_tempo rarely assembles the combo). **Rue held 44→43%**, so the
control is sound and nobody overshot 55%. Reported, not tuned — Bram is still
open for the next pass.

### Patch 0.2 — "buffs to the under-decks" (evidence: Brief 4 isolation pass)

The isolation pass flagged three decks well under tolerance at the A0 baseline —
Bram/refresh_tempo (15%), Kaya/rest_punish (23%), Rue/drain (34%) — and its
defence-economy table showed the under-decks' small bodies bouncing off
5000-power Vanguards (refresh_tempo connected 63% at 3920 avg attacker power vs
5047 defender). Patch 0.2 is six **buffs only** aimed at those three kits:

| # | Card | Change | Rationale |
|---|------|--------|-----------|
| 1 | Kaya Morrow (wm01-012) | rest Aura cost 2 → 1 | fire the rest line more often |
| 2 | Bo & Lantern (wm01-015) | rested-target bonus 2000 → 3000 | help the punish body connect |
| 3 | Bram Oxhart (wm01-023) | refresh Aura cost 2 → 1 | more extra-attack tempo |
| 4 | Stampede Doctrine (wm01-032) | new rider: each refreshed Banner +1000 until end of turn | let refreshed small bodies connect |
| 5 | Rue (wm01-067) | freeze-on-attack Aura cost removed (still 1×/turn) | free the drain engine |
| 6 | Field Vivisector (wm01-069) | power 3000 → 4000 | a Rue body that trades up |

The `rider.applies_to: "refreshed"` mechanic is implemented in `EffectEngine`:
after a refresh resolves, the rider's `power_buff` is applied to exactly the
Banners it refreshed.

**Measured outcome** (`patch02_report.md`, matched seeds): **Rue/drain moved
meaningfully, +10 pts (34→44%)** — and the C0 control shows the same +12
independent of pilot, so it's a genuine card swing. **Kaya and Bram stayed
flat** (within ±2 pts under both pilots): their buffs did not, on this evidence,
move those decks — a finding for the next patch pass, reported not tuned.

### Balance watch-list

Each game log carries a `watch` object, aggregated per batch, flagging when the
cards under balance review resolve:

| Flag | Fires when |
|------|-----------|
| `sora_rush_grants` | Sora's buff grants Rush to a Banner played this turn |
| `verdigris_double_rest` | Verdigris rests two enemy Banners on entry |
| `korgan_repeat_attacks` | Korgan refreshes itself at end of battle |
| `stampede_multi_refresh` | Stampede Doctrine refreshes two Banners |
| `averil_cards_seen` | cards seen through Averil's draw/bottom filtering |
| `rue_aura_frozen` | total enemy Aura frozen by Rue |

---

## The rules

**Zones (per player):** Deck, Hand, Life (face-down), Battle Area (max 5
Banners), Stage slot (max 1), Aura pool, Trash, Vanguard zone.

**Setup:** draw 5, one free mulligan. Place the top *N* cards face-down as Life,
where *N* is the Vanguard's printed life — **5** mono-colour, **4** dual-colour.

**Turn:** 1) **Refresh** — unexhaust your cards (frozen ones skip this once);
2) **Draw** — draw 1 (first player skips on turn 1 only); 3) **Aura** — gain 2
(first player gains 1 on turn 1), pool capped at 10, frozen Aura stays
unavailable this turn; 4) **Main** — plays, activations, attach Aura, attacks;
5) **End** — turn-duration effects expire, no hand-size cap.

**Combat:** attackers are your unexhausted Vanguard or Banners (a Banner needs
**Rush** to attack the turn it's played). Legal targets: the enemy Vanguard or a
**rested** (exhausted/frozen) enemy Banner. Resolution: declare → attacker may
attach Aura → defender may play [Counter] Techniques and discard counter-value
cards → compare power. Attacker wins on **≥**: vs a Banner it is KO'd; vs the
Vanguard the defender flips 1 Life to hand (or resolves its life-trigger). A hit
at 0 Life ends the game. **Blocker** Banners may exhaust to become the new
target.

**Freeze** (WM01): *a frozen card does not refresh during its owner's next
Refresh Phase.*

- Applies to **Banners** and **Aura**. Frozen Banners stay rested (still legal
  attack targets); frozen Aura is unavailable for one turn, reducing spendable
  Aura.
- **Cap (engine-enforced):** each player may freeze at most **1 Banner per
  turn** across all sources; additional Banner-freezes that turn are ignored.
  **Aura freezing is uncapped.**

**Keywords:** Rush, Blocker, Freeze (status). **Power ceiling:** 9000.

### Deckbuilding rules

Enforced by `DeckValidator` (used by `DeckFactory`, the tests, and available to
the engine) — an illegal deck is a hard failure with a reason:

1. A deck is **exactly 50 cards** plus 1 Vanguard.
2. At most **4 copies** of any card id.
3. **Colour legality:** every deck card shares at least one colour with the
   Vanguard.

Sim decks are built per archetype as **kit ×4 (40) + 10 filler** drawn from
colour-legal neighbour kits by a simple heuristic (aggro bodies for aggressive
kits, Blockers/counters for control kits — e.g. Neza fills with Pact Blockers
from Bram). Every balance/isolation report lists the exact 50-card decklists so
runs are reproducible.

### House rule: deck-out

The printed rules end a game only via a lethal Vanguard hit. To guarantee
simulations terminate, a player who must draw from an **empty deck loses**. This
is the only rule not drawn from the card game itself.

---

## Card data & the effect system

Cards are authored as JSON (`data/cards/*.json`) and imported to `CardData`
Resources by `tools/importer.gd`. The file may be a bare array of cards or an
object with a `"cards"` array (WM01 uses the latter, alongside `set` /
`rules_addenda` metadata the importer ignores). The importer is **lossless**:
`dict → CardData → dict` is a stable fixed point over all 88 cards. Malformed
rows are skipped into `CardImporter.last_issues`; cards over the power ceiling
are flagged there too.

Card schema (lower-case, matching the set exactly):

```json
{
  "id": "wm01-024", "name": "Korgan, Iron-Hided",
  "type": "banner",                     // vanguard | banner | technique | stage
  "colors": ["red", "green"], "faction": "The Old Pact", "tribe": "Pact",
  "cost": 7, "power": 8000, "counter": 0, "life": 0,
  "keywords": [], "effects": [ /* see below */ ], "flavor": "..."
}
```

**Effects** are event-driven. Each names a `trigger`, an optional `cost`,
`condition` and `once_per_turn` latch, and an `action` object whose `type`
selects the behaviour:

```json
{
  "trigger": "activate_main", "once_per_turn": true,
  "cost": { "aura": 1 },
  "condition": { "min_aura_total": 8 },
  "action": { "type": "power_buff", "amount": 2000, "target": "own_banner",
              "filter_tribe": "Redgale", "duration": "turn",
              "rider": { "if": "played_this_turn", "grant_keyword": "rush" } }
}
```

Triggers: `on_play`, `main` (Technique in Main), `counter` (defensive
Technique), `life_trigger` (revealed from Life), `when_attacking`,
`activate_main`, `passive` (continuous while in play).

Action types implemented: `power_buff` (duration `battle`/`turn`, multi-target,
`rider`), `ko`, `rest`, `refresh` (incl. `end_of_battle` timing), `freeze`
(Banner or Aura), `rest_and_freeze`, `bounce`, `draw`, `draw_then_bottom`,
`gain_aura`, `cost_reduction` (stacking, floored at a minimum), `search_top`,
`play_self`, and `hook`.

The **hook escape hatch** covers anything the data vocabulary can't express:

```json
{ "trigger": "on_play", "action": { "type": "hook", "hook": "my_bespoke_id" } }
```

Register it in GDScript — `EffectHooks.register("my_bespoke_id", cb)` — where
`cb(game, source, ctx)` runs the bespoke logic.

**Passive, conditional power** (Marshal Dreyse's +1000 to Bulwark Banners at 8+
Aura, Siegeworks, Old Hollow) is recomputed on demand via
`GameEngine.effective_power()`, so thresholds apply and unapply the instant Aura
crosses them.

---

## Design notes

- Built from plain `RefCounted` / `Resource` classes, never `Node`s — no scene
  tree, no rendering, no input. `GameEngine` exposes the full public API; the AI
  policies call only that API, so they double as usage documentation.
- All randomness flows through one seeded `RandomNumberGenerator`, so any game
  is exactly reproducible from its seed — essential for the balance harness.
- Combat decisions are passed in as plain choice dictionaries
  (`atk_choices` / `def_choices`), keeping resolution deterministic and letting
  tests drive every branch (attach-Aura, counters, Blocker, Trigger) directly.
- `EffectEngine` is pure interpretation: every mutation and target selection
  goes through `GameEngine`, so effects stay data-driven and testable.
```
