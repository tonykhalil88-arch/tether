# WILDMIGRATION — Client (Phase 3) Screens & Run Notes

A playable human-vs-AI 3D client on top of the **frozen** Set 1 engine. The
client is a pure consumer of the engine: it drives the same public API the AI
policies use and renders by translating the engine's public `state.log` into
presentation beats. No rules live in `client/`.

---

## Board capture

![Board schematic — mid-game](docs/screens/board_schematic.png)

> **Why a schematic and not a framebuffer grab?** This repo runs under
> `godot --headless`, whose dummy video driver cannot render a 3D framebuffer to
> disk. The capture above is therefore generated *from the same Image tools the
> live client renders with* (`CardFrame` + `PixelFont`) by playing a real
> scripted game to a mid-game state and drawing the resulting **public** board.
> On a machine with a GPU the identical state is drawn in 3D — Sprite3D creature
> billboards on an angled table, the same zones, the same counts. Regenerate it
> any time with:
>
> ```bash
> godot --headless -s tools/gen_screens.gd     # -> docs/screens/board_schematic.png
> ```

The capture shows both seats: each Vanguard, the Banner row, the Stage slot, and
the Life / Aura / Hand / Deck / Trash counts, plus the human hand fanned along
the bottom. `RESTED` / `FROZEN` tags sit under any exhausted or frozen unit.

---

## Running the client

```bash
# Real GPU (desktop): launches the main menu -> table -> win/loss flow.
godot                      # main scene is client/main.tscn
```

**Main menu** — pick your Vanguard (all 8) and your opponent's Vanguard (or
*Random*). The AI automatically pilots its Vanguard with the matching archetype
(rush / rest_punish / refresh_tempo / lockdown / filter_control / discount_deploy
/ drain / threshold_ramp).

**On the table (mouse only):**

| Action | Input |
| --- | --- |
| Play a card | Click a lit hand card (auto-slots; dimmed = unaffordable/no slot) |
| Pick an attacker | Click one of your units (a green ring appears) |
| Attack | Click a highlighted (red-ring) enemy unit / Vanguard |
| Attach Aura to an attack | `Aura +` / `Aura -` while an attacker is selected |
| Activate an ability | `Activate VG` / `Activate Stage` |
| Speed / skip animations | `Speed 1x↔2x`, `Skip` |
| End your turn | `End Turn` |

**Prompts** appear as center panels when it's your decision:
- **Mulligan** — keep your opening hand or redraw once.
- **Defence** — when the AI attacks you: block with a Blocker, pitch counter
  cards, or take it.
- **Life trigger** — when a hit flips one of your Life cards with a trigger:
  resolve it or add it to your hand.

The **speed toggle (1x / 2x / skip)** is wired from day one through the
`PresentationQueue`, which paces beats between the instant engine and the screen.

---

## The two fully-wired example cards

`assets/cards/wm01-008/` (**Stormfoal Hatchling**) and `assets/cards/wm01-046/`
(**Cull-Beast 01**) ship complete **four-channel** assets — `sprite.png`,
`attack.png`, `summon.wav`, `hit.wav`, `voice.wav`, a `manifest.json`, and a
shared `vfx.strike` scene (`client/present/vfx_burst.tscn`). They exercise the
whole **summon state machine** — `summon → idle → attack_windup → strike →
return → idle`, plus `damaged / ko / rested / frozen / bounce / refresh /
life_trigger_reveal` — each state firing sprite + SFX + VFX + (optional) voice
through the `AssetManifest`. Every other card falls back gracefully: a generated
placeholder sprite, a generated whoosh, no voice, no VFX — so **art drops into
`assets/cards/<id>/` with zero code changes.**

Placeholder assets are procedurally generated (free) by:

```bash
godot --headless -s tools/gen_client_assets.gd
```

---

## Smoke tests

Client smoke tests live alongside the engine suites in `tests/unit/` and run in
the same GUT pass (`test_client_smoke.gd`):

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs=true -gexit
```

They verify, headless:
- the `AssetManifest` resolves all four channels for a wired card and falls back
  for an unknown one;
- `CardFrame` renders every card type;
- the `PresentationQueue` orders beats and skip-flushes them;
- the `SummonStateMachine` walks the full attack chain back to idle;
- the `MatchController` plays a complete human-vs-AI game to `game_over`;
- the full client stack (BoardView + Hud) plays **turn 1** — mulligan, play,
  attack, pass — driven through the board's own click handlers, with no errors.

**Engine untouched:** all pre-existing engine tests still pass — the full suite
is **146/146 green** (139 engine + 7 client).
