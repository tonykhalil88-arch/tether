# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this is

**WILDMIGRATION** — a digital TCG built in **Godot 4.5 / GDScript**, in two layers:

1. **A headless rules engine** (`engine/`, `sim/`, `tools/`, `data/`) — pure logic,
   zero rendering, fully deterministic, driven from the command line. It runs the
   real **WM01 "The First Stampede"** set: 88 cards, five tribes, eight Vanguards.
2. **A playable human-vs-AI 3D client** (`client/`) — a *pure consumer* of that
   engine. It renders by translating the engine's public `state.log` into
   presentation beats. **No rules live in `client/`.**

The repo directory is `tether`; the Godot project is named `wildmigration`.

Start with [`README.md`](README.md) for the full rules text, card schema and
balance history, [`SCREENS.md`](SCREENS.md) for the client, and
[`docs/balance-campaign.md`](docs/balance-campaign.md) for the balance method.

---

## ⚠️ Godot is not preinstalled — install it first

`godot` is **not on PATH** in a fresh remote-execution container, and the
container is ephemeral, so **every new session has to install it again**.

**On the web this is automatic**: `.claude/hooks/session-start.sh` (registered as
a `SessionStart` hook in `.claude/settings.json`) installs Godot 4.5 and warms
the import scan before the session starts — ~13s cold, ~8s warm. Check with
`godot --version` before assuming you need to do anything. The hook is
remote-only and a no-op for local sessions.

To install by hand (or if the hook did not run) — about a minute, after which
everything headless works (verified: full suite 146/146 green, simulator and
import scan both fine on `4.5.stable.official.876b29033`):

```bash
cd /tmp && curl -sSL -o godot45.zip \
  https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip
# optional but cheap — verify against the official sums file
curl -sSL -O https://github.com/godotengine/godot/releases/download/4.5-stable/SHA512-SUMS.txt
grep 'linux.x86_64.zip' SHA512-SUMS.txt | sed 's/Godot_v4.5-stable_linux.x86_64.zip/godot45.zip/' | sha512sum -c -
unzip -oq godot45.zip && install -m 0755 Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot
godot --version   # -> 4.5.stable.official.876b29033
```

Notes:

- Use the **4.5** build. The project targets Godot 4.5 (`config/features` in
  `project.godot`) and GUT 9.5.0 is the release that targets 4.5.
- The plain editor binary is the right one — `--headless --editor --quit` (the
  required `class_name` import scan) needs the editor, not an export template.
- `github.com` and its release-asset host are reachable through the agent proxy;
  `api.github.com` returns 403, so fetch release assets by direct URL rather than
  through the API.
- No GPU here, so the **client itself (`godot`, `client/main.tscn`) still cannot
  be run** — only the headless suite, simulator and tools. Client behaviour is
  covered headlessly by `test_client_smoke.gd`.
- The import scan writes `.godot/` (gitignored) and generates any missing `.uid`
  / `.import` sidecars — those *are* tracked, so commit them if they appear.

If installation is unavailable (egress blocked, no disk), fall back to
read-only work: **never claim tests pass**, say exactly what you did and did not
verify, prefer changes justifiable by reading the code, and still write the GUT
test that would prove any behaviour change.

---

## Commands (require Godot 4.5)

```bash
# Import scan — REQUIRED after adding or renaming any script with a class_name.
# Godot resolves class_name globals during an editor import pass; skip this and
# tests fail with "Identifier not found".
godot --headless --editor --quit

# Full test suite (GUT 9.5.0, vendored in addons/gut/). 146 tests, 26 suites.
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs=true -gexit

# A single suite. Use -gselect (matches by script name) — -gtest= does NOT
# isolate a suite, because .gutconfig.json's `dirs` still applies and the whole
# suite runs anyway.
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_freeze.gd -gexit

# Parse-check one script (there is no configured linter; this is the closest
# equivalent). Exits 1 on a parse error, 0 when clean.
godot --headless --check-only --script engine/game_engine.gd

# AI-vs-AI simulator (flags go after `--`)
godot --headless -s sim/run.gd -- --games=100 --seed=1 --out=sim_logs
godot --headless -s sim/run.gd -- --games=10 --seed=1 --quiet

# Balance matrix -> balance_report.{json,md}   (8x8 Vanguards x N games)
godot --headless -s sim/balance.gd -- --games=50 --seed=1

# Isolation pass (ablations + shared-pilot control) -> isolation_report.{json,md}
for S in A0 A1 A2 A3 A4 A5 C0; do
  godot --headless -s sim/isolation.gd -- --scenario=$S --games=50 --seed=1
done
godot --headless -s sim/isolation.gd -- --consolidate

# Patch measurement -> patch0N_report.md
godot --headless -s sim/patch_report.gd -- --phase=archetype --games=50 --seed=1
godot --headless -s sim/patch_report.gd -- --phase=c0 --games=50 --seed=1
godot --headless -s sim/patch_report.gd -- --phase=consolidate5   # or consolidate/3/4

# Client (needs a GPU; main scene is client/main.tscn)
godot

# Asset + screenshot generators
godot --headless -s tools/gen_client_assets.gd   # procedural placeholder art
godot --headless -s tools/gen_screens.gd         # docs/screens/board_schematic.png
```

CLI scripts `extends SceneTree` and parse `OS.get_cmdline_user_args()` with a
shared `_parse_args()` helper: `--key=value` → `opts["key"]`, bare `--flag` →
`opts["flag"] = true`.

---

## Layering — the rule that matters most

```
data/cards/*.json  →  tools/importer.gd  →  engine/  ←  sim/     (AI policies)
                                                     ←  client/  (presentation)
                                                     ←  tests/
```

**Dependencies point inward only.** The engine knows nothing about `sim/`,
`client/` or `tests/`.

| Layer | Rule |
|---|---|
| `engine/` | Owns **all** rules. `RefCounted` / `Resource` only — **never `Node`**, no scene tree, no rendering, no input, no `_process`. |
| `sim/` | AI pilots + batch harness. Calls only `GameEngine`'s public API. The policies double as usage documentation. |
| `client/` | **Zero rules.** Only `MatchController` touches `GameEngine`, and only through the same public API the AI policies use. Everything else renders from public state + `state.log`. |
| `tests/` | GUT suites plus the `Scenario` / `DeckFactory` helpers. |

### The engine is FROZEN at the alpha balance baseline

Set 1 balance is **closed at Patch 0.5** (commit `54cbe82`, intended to carry the
`alpha-balance-baseline` tag). Remaining balance gaps are deliberately handed to
human playtesting in the client, **not** to further simulation tuning.

Treat `engine/` and `data/cards/` as frozen unless the task explicitly asks for
an engine change or a new balance patch. Client and tooling work must not require
touching them — if it seems to, that's a signal the design is wrong, not that the
freeze should break.

---

## Core invariants

These hold throughout and should survive any change you make:

1. **Determinism.** All randomness flows through the single seeded
   `state.rng` (`RandomNumberGenerator`). A game is exactly reproducible from
   `(seed, vanguards, first player)`. Never introduce `randi()`, `randf()`,
   wall-clock time or dictionary-iteration-order dependence into engine or sim
   code. `_shuffle()` in `GameEngine` is the only shuffle.
2. **Combat is atomic and choice-driven.** `declare_attack(attacker, target,
   atk_choices, def_choices)` resolves an entire battle in one call. Attacker and
   defender decisions arrive up front as plain Dictionaries (`attach_aura`,
   `blocker`, `counter_techniques`, `counter_cards`, `resolve_trigger`), so tests
   can drive every branch and there is no interactive priority loop.
3. **`EffectEngine` is pure interpretation.** Every mutation and target selection
   goes through `GameEngine` methods (`rest_unit`, `freeze_banner`, `ko_unit`,
   `select_enemy_banners`, …). Do not mutate `CardInstance` / `PlayerState`
   directly from effect code.
4. **`CardData` is immutable printed data**; all per-game mutable state lives on
   `CardInstance`. The importer round-trip (`dict → CardData → dict`) is a stable
   fixed point over all 88 cards and is tested — keep it lossless.
5. **Ablations are runtime-only.** `GameState.ablations` flags (checked via
   `state.ablated("flag")`) disable or weaken a card for isolation runs **without
   changing card data**. Ablation checks live inline in `EffectEngine` /
   `GameEngine`, keyed by card id.
6. **`state.log` is the public event stream.** `state.log_event(kind, data)`
   appends `{turn, player, kind, ...}`. The client's entire presentation layer is
   derived from it — adding a log entry kind is a presentation-visible change
   (see `MatchController._DURATION`).
7. **Effect vocabulary is centralised** in `CardEnums`. Never hard-code the
   strings `"banner"`, `"on_play"`, `"power_buff"`, `"hand"`, … in rules code —
   use the constants so card JSON and engine stay in lockstep.

---

## Directory map

```
engine/                         # rules engine — pure logic, no rendering
  game_engine.gd                # turn structure, combat, freeze, passives, effect primitives (~775 lines, the core)
  deck_validator.gd             # 50 cards / max 4 copies / colour legality
  cards/card_enums.gd           # canonical vocab: types, keywords, triggers, actions, zones, caps
  cards/card_data.gd            # immutable printed card (Resource); from_dict/to_dict
  state/game_state.gd           # per-game container: players, turn, rng, log, watch, ablations, metrics
  state/player_state.gd         # zones + Aura economy + freeze / cost bookkeeping
  state/card_instance.gd        # a physical card in play (runtime state)
  state/event_bus.gd            # synchronous publish/subscribe hub
  effects/effect_engine.gd      # data-driven effect resolver (WM01 schema)
  effects/hooks.gd              # GDScript escape hatch for bespoke effects
data/cards/wildmigration_set1.json   # WM01 — {set, rules_addenda, cards[88]}
tools/importer.gd               # JSON <-> CardData, lossless; issues in last_issues
tools/gen_client_assets.gd      # procedural placeholder art
tools/gen_screens.gd            # board-schematic capture for SCREENS.md
sim/ai_policy.gd                # 8 archetype pilots; AIPolicy.for_vanguard(id)
sim/match_runner.gd             # play_game / run_matchup / run_matrix / run_batch
sim/run.gd                      # CLI: AI-vs-AI batch
sim/balance.gd                  # CLI: 8x8 matrix -> balance_report.*
sim/isolation.gd                # CLI: ablation + control scenarios -> isolation_report.*
sim/patch_report.gd             # CLI: patch before/after on matched seeds -> patch0N_report.md
client/main.gd|.tscn            # app root: menu -> table -> win/loss
client/match/match_controller.gd  # the ONLY client object that talks to GameEngine
client/present/                 # PresentationQueue, SummonStateMachine, CardFrame, PixelFont, vfx_burst
client/board/                   # BoardView (3D table + input), UnitView, HandCardView
client/ui/                      # Hud, MainMenu, WinLoss
client/assets/asset_manifest.gd # 4-channel art resolver with graceful fallbacks
assets/cards/<id>/              # per-card art drop (wm01-008 and wm01-046 fully wired)
tests/scenario.gd               # build precise game states (bypasses the shuffle)
tests/deck_factory.gd           # load the kit, build legal decks, stack decks
tests/unit/test_*.gd            # 26 GUT suites, 146 tests
addons/gut/                     # vendored GUT 9.5.0 — do not edit
```

---

## Code style

GDScript, Godot 4.5 idioms. Match the surrounding file exactly.

- **Tabs** for indentation (Godot standard). No spaces.
- Every script opens with `class_name X` + `extends <RefCounted|Resource|Node|Node3D|Control|CanvasLayer>`,
  then a `##` doc block explaining what it owns and — importantly — *what it does not*.
  CLI scripts (`sim/*.gd` entry points, `tools/gen_*.gd`) `extends SceneTree` with
  no `class_name` and document their usage line in the header.
- `##` doc comments above non-obvious public functions; `#` for inline notes.
  Comments explain *why* (rule provenance, patch rationale), not *what*.
- Section banners inside large files:
  ```gdscript
  # =========================================================================
  # Combat
  # =========================================================================
  ```
  and lighter `# --- selection helpers ---...` sub-banners.
- **Two blank lines** between top-level functions in `engine/`, `sim/`, `client/`,
  `tools/`. Test files use **one** blank line between `test_*` functions (except
  where a `# --- section ---` banner separates groups). Match the file you're in.
- Static typing throughout: `func foo(x: int) -> bool:`, `var g := GameEngine.new()`,
  `var ps: PlayerState = state.players[idx]`. Use `:=` inference where the type is
  obvious, an explicit annotation where it is not.
- `_leading_underscore` for private members and helpers.
- Constructor params that shadow a member are prefixed `p_`
  (`func setup(p_card_id: String, p_uid: int)`).
- Prefer `match` over long `if/elif` chains for dispatch on a string type.
- Failure mode: boolean returns (`play_card`, `spend_aura`, `freeze_banner`) or
  `{ "ok": false, ... }` result dicts. `push_error` / `push_warning` for
  programmer errors; the importer collects per-row problems into
  `CardImporter.last_issues` rather than aborting the batch.

### `.uid` sidecar files

Godot 4 writes a `<script>.gd.uid` next to each script. **Commit them** — most
scripts here have one. They are generated by the editor import pass, so create a
new script's `.uid` by running the import scan rather than hand-writing it.

---

## Common tasks

### Add or change a card

1. Edit `data/cards/wildmigration_set1.json`. Fields are lower-case and match
   `CardData` one-to-one (see README "Card data & the effect system").
2. If the vocabulary already covers the behaviour, **no GDScript is needed** —
   `EffectEngine` interprets `trigger` / `cost` / `condition` / `action`.
3. Add or extend a test asserting the printed values *and* the in-game behaviour.
4. Power must stay ≤ `CardEnums.POWER_CEILING` (9000); the importer flags
   violations into `last_issues` and `test_importer.gd` asserts the ceiling.
5. Colour legality matters: `DeckFactory` builds a deck as the Vanguard's own
   10-card kit ×4 (40) + 10 colour-legal filler, and `DeckValidator` rejects
   anything else.

### Add a new effect action type

1. Add `ACT_MY_THING := "my_thing"` to `CardEnums`.
2. Add the `match` arm and a `_act_my_thing(game, source, action, ctx)` static in
   `EffectEngine` — it must call `GameEngine` methods, never mutate state itself.
3. Add any new primitive it needs to `GameEngine`'s "Effect primitives" section.
4. Cover it in `tests/unit/test_effects.gd`.
5. Bespoke one-offs that don't generalise should use the **hook escape hatch**
   instead: `{"action": {"type": "hook", "hook": "my_id"}}` +
   `EffectHooks.register("my_id", cb)`.

### Apply a balance patch (the established protocol)

The campaign in `docs/balance-campaign.md` is the template. Every patch so far:

1. **Evidence first** — a measured finding from the previous report, not intuition.
2. **Buffs only**, and leave at least one deck deliberately untouched as a
   measurement-stability control.
3. Bump `set.patch` in the set JSON (currently `"0.5"`).
4. Add `tests/unit/test_patchNN.gd` asserting (a) `set.patch` is the new value,
   (b) each changed printed value, (c) the behaviour the change is supposed to buy.
5. Re-measure on **matched seed blocks** via `sim/patch_report.gd` and write
   `patchNN_report.md`.
6. **Report, don't tune.** Never adjust a pilot to flatter a number — a flat
   result is a finding, and the changelog records flat results as prominently as
   wins.
7. Append a changelog section to `README.md` with the change table and the
   measured outcome.

Remember the freeze: do this only when the task explicitly asks for a balance pass.

### Add card art

Drop files into `assets/cards/<card_id>/` — `sprite.png`, `attack.png`,
`summon.wav`, `hit.wav`, `voice.wav`, optional `manifest.json`, optional
`vfx.tscn`. **Zero code changes required**: `AssetManifest.resolve()` falls back
per channel (generated placeholder sprite/SFX, `null` voice/VFX). `wm01-008` and
`wm01-046` are the fully-wired reference examples.

### Client work

- New visuals go in `client/board/` or `client/present/`; new controls in
  `client/ui/`. Everything is **built in code**, not authored as scenes, so it
  constructs under `--headless` for the smoke tests. `client/main.tscn` and
  `client/present/vfx_burst.tscn` are the only scene files.
- Animation timing belongs in `PresentationQueue` beats; a new engine log kind
  needs a duration in `MatchController._DURATION` or it is silently skipped.
- Text rasterised into an `Image` uses `PixelFont` (a 5×7 embedded bitmap font)
  so it works with no GPU and no TextServer.

---

## Testing

- Framework: **GUT 9.5.0**, vendored at `addons/gut/` (do not edit). Config in
  `.gutconfig.json`; suites live in `tests/unit/`, named `test_*.gd`,
  `extends GutTest`, with `func test_*()` cases.
- Two helpers do the heavy lifting:
  - **`Scenario`** — `fresh()`, `fresh_with_vanguards()`, `spawn_banner()`,
    `hand_card()`, `set_aura()`, `set_life()`, `set_stage()`. Builds exact board
    states, bypassing the shuffle, so rules tests are deterministic.
  - **`DeckFactory`** — `load_kit()`, `card(id)`, `vanguards()`, `deck_for(vg)`,
    `stacked_deck()`. `KIT_PATH` points at the WM01 JSON.
- Assert on **behaviour and rule provenance**, not implementation details; give
  every assertion a message that reads as the rule
  (`assert_false(b.frozen, "but the freeze has thawed")`).
- Client tests (`test_client_smoke.gd`) assert *construction and flow only* — no
  rules. Use `MatchController.auto_prompts = true` to let a headless test
  auto-answer mulligan / defence / life-trigger prompts, and `add_child_autofree`
  for `Node`s.
- Loops that drive a whole game need a `guard` counter to bound them.

---

## Generated artifacts — do not hand-edit

These are produced by the tools and are committed as evidence:

| File | Produced by |
|---|---|
| `balance_report.json` / `.md` | `sim/balance.gd` |
| `isolation_report.json` / `.md` | `sim/isolation.gd --consolidate` |
| `patch0{2,3,4,5}_report.md` | `sim/patch_report.gd --phase=consolidate*` |
| `docs/screens/board_schematic.png` | `tools/gen_screens.gd` |
| `assets/cards/*/{sprite,attack}.png`, `*.wav` | `tools/gen_client_assets.gd` (placeholders) |

Intermediate partials (`iso_*.json`, `patch*_arch.json`, `patch*_c0.json`) and
`sim_logs/` are gitignored — regenerate rather than commit them.

---

## Gotchas

- **`class_name` needs an import scan.** After adding/renaming a script, run
  `godot --headless --editor --quit` or every suite fails on an unresolved
  identifier. This is the single most common cause of a "broken" test run.
- **The README's test count (139) is stale** — the suite is **146** across 26
  suites (139 engine + 7 client, per `SCREENS.md`), confirmed by an actual run
  on Godot 4.5 stable; the README coverage table also omits
  `test_client_smoke.gd`. Prefer `SCREENS.md`'s number; ideally fix the README
  when you touch that section.
- **Banner freeze is capped at 1 per player per turn** (`banner_freezes_used`,
  `CardEnums.BANNER_FREEZE_CAP_PER_TURN`); **Aura freeze is uncapped**. Effects
  that freeze extra Banners silently no-op — that's intentional.
- **Frozen ≠ rested.** "Rested" is `exhausted`. `frozen` means "skip exactly one
  Refresh Phase, then thaw" — a frozen Banner stays exhausted through that
  refresh and so remains a legal attack target.
- **Aura cap is 10** and `gain_aura` silently clamps. Frozen Aura is modelled as
  `aura_frozen_pending` carried into the next `refresh_aura()`.
- **Deck-out is a house rule**, not printed: drawing from an empty deck loses.
  It exists so simulations terminate.
- **First-player asymmetries**: skips the turn-1 draw and gains 1 Aura instead of 2.
- `DeckFactory.load_kit()` re-imports the JSON on every call. It's fine in tests
  and sim, but don't call it inside a hot loop in new code — hoist it.
- The engine's `_end_of_battle_refresh` list is cleared at the *start* of
  `declare_attack`; effects scheduling a refresh outside a battle will not fire.
- Rest/refresh/KO target selection auto-picks the **highest-power** eligible
  Banner (`select_enemy_banners` / `select_own_banners` sort by power). Several
  patches rely on this — changing the sort is a balance change.

---

## Git

- Work on the designated feature branch; push with `git push -u origin <branch>`.
- Commit messages follow `area: short imperative summary`
  (`client: 3D board, card views, input, HUD, menus, win/loss`), then a blank
  line, then a `-`-bulleted body naming each touched file and what it does, and a
  closing line stating what was verified (e.g. "Full suite 146/146 green (139
  engine + 7 client); engine untouched."). **Only make that claim if you actually
  ran it** — see the Godot-availability note above.
- Do not open a PR unless asked.
