# WILDMIGRATION — Rules Engine (Phase 2)

A **headless** digital TCG rules engine for WILDMIGRATION, built in Godot 4.5 /
GDScript. This phase is engine-only: pure logic, zero rendering, everything
testable and runnable from the command line. Presentation comes later.

Two players duel with a 50-card deck plus a single Vanguard. Card types are
**Vanguard**, **Banner** (creature), **Technique** (one-shot) and **Stage**
(persistent field). See [The rules](#the-rules) below for the full model.

---

## Requirements

- **Godot 4.5** (headless is fine — no GPU needed).
- **GUT 9.5.0** — the Godot Unit Test framework, vendored under `addons/gut/`.
  9.5.0 is the release that targets Godot 4.5 (it uses the 4.5 `Logger` API but
  none of the newer editor-only APIs). No other third-party dependencies.

Godot resolves `class_name` globals during an editor import scan. If you add or
rename a script, run one import pass before testing:

```bash
godot --headless --editor --quit
```

---

## Project structure

```
wildmigration/
├── project.godot            # Godot project (headless)
├── engine/                  # rules engine — pure logic, no rendering
│   ├── game_engine.gd       # turn structure + combat orchestration (the core)
│   ├── cards/
│   │   ├── card_enums.gd     # canonical type/keyword/zone/event vocabularies
│   │   └── card_data.gd      # immutable printed card definition (Resource)
│   ├── state/
│   │   ├── game_state.gd     # per-game container (players, turn, rng, log)
│   │   ├── player_state.gd   # zones + the Aura economy
│   │   ├── card_instance.gd  # a physical card in play (runtime state)
│   │   └── event_bus.gd      # synchronous publish/subscribe hub
│   └── effects/
│       ├── effect_engine.gd  # data-driven effect resolver
│       └── hooks.gd          # GDScript hook escape hatch for bespoke effects
├── data/cards/
│   └── sora_akaza.json       # seed kit: 1 Vanguard, 7 Banners, 2 Techniques, 1 Stage
├── tools/
│   └── importer.gd           # JSON <-> CardData importer (lossless)
├── sim/
│   ├── ai_policy.gd          # two scripted AI policies (aggro / guard)
│   ├── match_runner.gd       # AI-vs-AI game loop + batch runner (reusable)
│   └── run.gd                # headless CLI entry point (`godot -s sim/run.gd`)
├── tests/
│   ├── deck_factory.gd       # loads the kit, builds decks
│   ├── scenario.gd           # builds controlled states for deterministic tests
│   └── unit/                 # GUT suites (see coverage below)
└── addons/gut/               # vendored GUT 9.5.0
```

---

## Running the tests

The engine is validated by the GUT command-line runner (the in-editor GUT panel
is not needed for headless use):

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs=true -gexit
```

All suites should report **All tests passed!**. Coverage maps directly to the
Definition of Done:

| Suite | Covers |
|-------|--------|
| `test_importer.gd` | JSON round-trip losslessness, validation, dir import |
| `test_setup.gd` | opening hand, 5-mono / 4-dual Life, free mulligan |
| `test_turn_flow.gd` | phase order, Refresh unexhausts, no hand cap |
| `test_first_player.gd` | first-player skip-draw + 1-Aura asymmetries |
| `test_aura.gd` | Aura gain / spend / refresh and the cap of 10 |
| `test_combat.gd` | power math, KO, attach-Aura, counters, Blocker, targeting |
| `test_rush.gd` | summoning sickness and the Rush exception |
| `test_life_trigger.gd` | Life-to-hand flip and [Trigger] resolution |
| `test_win_condition.gd` | lethal hit at 0 Life |
| `test_zones_limits.gd` | Battle Area cap of 5, Stage uniqueness |
| `test_effects.gd` | event bus, data-driven actions, hook escape hatch |
| `test_sim.gd` | simulator determinism + batch integrity |

---

## Running the simulator

`sim/run.gd` runs AI-vs-AI games headlessly and prints a per-game summary plus
an aggregate report. With `--out` it also writes a structured JSON log per game
(the balance-testing harness for later phases).

```bash
# 100 games, seeded, logs written to ./sim_logs/
godot --headless -s sim/run.gd -- --games=100 --seed=1 --out=sim_logs

# quick, quiet smoke run
godot --headless -s sim/run.gd -- --games=10 --seed=1 --quiet
```

Flags (after the `--`):

| Flag | Default | Meaning |
|------|---------|---------|
| `--games=N` | 10 | number of games to play |
| `--seed=S` | 1 | base RNG seed (game `i` uses `S + i`) |
| `--out=DIR` | — | write `game_NNN.simlog.json` per game |
| `--quiet` | off | suppress the per-game lines |

Each log records the seed, first player, both policies, winner, turn count and
the full structured game log (setup, plays, attacks, KOs, game-over).

The two policies (`sim/ai_policy.gd`) both play on curve:

- **aggro** — always attacks the enemy Vanguard, never defends. Races Life.
- **guard** — clears exhausted enemy Banners first, and uses a Blocker / counter
  cards to protect its Vanguard when Life is low.

---

## The rules

**Zones (per player):** Deck, Hand, Life (face-down), Battle Area (max 5
Banners), Stage slot (max 1), Aura pool, Trash, Vanguard zone.

**Setup:** draw 5, one free mulligan (shuffle back, redraw 5). Place the top
*N* deck cards face-down as Life, where *N* is the Vanguard's printed life —
**5** for a mono-colour Vanguard, **4** for a dual-colour one.

**Turn structure:**

1. **Refresh** — unexhaust all your cards (Vanguard, Banners, Aura, Stage).
2. **Draw** — draw 1. The first player skips this on turn 1 only.
3. **Aura** — gain 2 Aura, except the first player gains only 1 on turn 1.
   Active (unexhausted) Aura is capped at 10.
4. **Main** — in any order: play Banners / Techniques / Stages by exhausting
   Aura equal to cost; attach Aura (exhaust 1 Aura = +1000 power for the
   battle); declare attacks.
5. **End** — end-of-turn effects expire. No hand-size cap.

**Combat:**

- Attackers are your unexhausted Vanguard or Banners. A Banner cannot attack
  the turn it is played unless it has **Rush**. Attacking exhausts the attacker.
- Legal targets: the enemy Vanguard, or an **exhausted** enemy Banner.
- Resolution: declare → attacker may attach Aura → defender may play [Counter]
  Techniques and discard counter-value cards (+power to the defender) → compare
  power.
- The attacker wins if **attacker power ≥ defender power**.
  - vs a Banner → the defender's Banner is KO'd to Trash.
  - vs the Vanguard → the defender flips 1 Life card into hand; if it is a
    [Trigger] they may resolve the trigger instead. A hit while 0 Life remain
    ends the game — the attacker wins.
- **Blocker:** when attacked, the defender may exhaust a Banner with Blocker to
  become the new defend target.

**Keywords:** Rush, Blocker, [On Play], [When Attacking], [Activate: Main],
[Once Per Turn], [Counter], [Trigger], [Your Turn].

### House rule: deck-out

The printed rules only end a game via a lethal Vanguard hit. To guarantee that
simulations always terminate, a player who must draw from an **empty deck
loses**. This is the only rule here not drawn from the card game itself.

---

## Card data & the effect system

Cards are authored as JSON (`data/cards/*.json`) and imported to `CardData`
Resources by `tools/importer.gd`. The schema, one object per card:

```json
{
  "id": "cinder_darter",
  "name": "Cinder Darter",
  "type": "Banner",
  "colors": ["Red"],
  "cost": 2,
  "power": 3000,
  "counter": 1000,
  "life": 0,
  "keywords": ["Rush"],
  "effects": [],
  "flavor": "It strikes before the smoke clears.",
  "faction": "Emberwing Host",
  "tribe": "Redgale"
}
```

- `type` is one of `Vanguard | Banner | Technique | Stage`.
- `counter` is the value contributed when the card is discarded on defense.
- `life` is Vanguard-only.

The importer is **lossless**: `dict → CardData → dict` is a stable fixed point
(exercised by `test_importer.gd`). A file may be a bare array of cards or an
object with a `"cards"` array. Malformed rows are skipped and recorded in
`CardImporter.last_issues` rather than aborting the batch.

**Effects** are event-driven and data-first. Each effect names a `trigger`
(matched against event-bus events such as `on_play`, `when_attacking`,
`on_trigger_reveal`, `on_turn_start`) plus an `action` and `params`:

```json
{ "trigger": "on_play", "action": "draw", "params": { "amount": 1 } }
```

Built-in actions: `draw`, `power_buff` (targets `self` / `vanguard` /
`attacker` / `defender` / `chosen_ally`), `ko_enemy_banner_max_power`,
`gain_rush`, `search_top`. Anything the vocabulary can't express uses the
**hook escape hatch**:

```json
{ "trigger": "on_play", "action": "hook", "params": { "hook": "my_bespoke_id" } }
```

Register the hook in GDScript (`EffectHooks.register("my_bespoke_id", cb)`);
`cb` receives `(game, source, ctx)`. This is how bespoke card text will be wired
up as real cards arrive.

> The seed kit (`data/cards/sora_akaza.json`) is **placeholder** text for engine
> bring-up — real card text lands next session.

---

## Design notes

- The engine is built from plain `RefCounted` / `Resource` classes, never
  `Node`s — no scene tree, no rendering, no input. `GameEngine` exposes the full
  public API (`begin_turn`, `play_card`, `attach_aura`, `declare_attack`, …);
  the AI policies call only that API, so they double as usage documentation.
- All randomness flows through one seeded `RandomNumberGenerator`, so any game
  is exactly reproducible from its seed — essential for the balance harness.
- Combat decisions are passed in as plain choice dictionaries
  (`atk_choices` / `def_choices`), which keeps resolution deterministic and lets
  tests drive every branch (attach-Aura, counters, Blocker, Trigger) directly.
