extends GutTest

## Patch 0.3 — the four conversion-targeted changes and the widened Bo & Lantern
## condition (defender_has_rested_banner).

# --- Changelog spot-checks -------------------------------------------------

func test_changelog_03_values():
	var kit: Dictionary = DeckFactory.load_kit()
	assert_eq(int(kit["wm01-014"].power), 5000, "Smuggler's Debt 4000 -> 5000")
	assert_eq(int(kit["wm01-028"].power), 6000, "Rhoswen 5000 -> 6000")
	assert_eq(int(kit["wm01-032"].effects[0]["action"]["rider"]["amount"]), 2000, "Stampede rider 2000")
	var cond: Dictionary = kit["wm01-015"].effects[0]["condition"]
	assert_true(cond.has("defender_has_rested_banner"), "Bo & Lantern uses the new condition")
	assert_false(cond.has("target_is_rested"), "old condition removed")

func test_set_is_patch_03():
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DeckFactory.KIT_PATH))
	assert_eq(str(parsed["set"]["patch"]), "0.3")

# --- Widened Bo & Lantern: fires vs the Vanguard --------------------------

func test_bo_and_lantern_buffs_vs_vanguard_when_defender_has_rested_banner():
	var g := Scenario.fresh()
	var bo: CardInstance = Scenario.spawn_banner(g, 0, "wm01-015")   # 3000
	# The defender controls a rested Banner elsewhere; we attack the Vanguard.
	Scenario.spawn_banner(g, 1, "wm01-036", true)                    # rested enemy Banner
	var r := g.declare_attack(bo, g.state.players[1].vanguard)
	assert_eq(r["attacker_power"], 6000, "3000 + 3000 vs the Vanguard")
	assert_true(r["attacker_wins"], "6000 >= 5000 connects")

func test_bo_and_lantern_no_buff_when_defender_has_no_rested_banner():
	var g := Scenario.fresh()
	var bo: CardInstance = Scenario.spawn_banner(g, 0, "wm01-015")   # 3000
	# Enemy has only a READY Banner (not rested) — condition false.
	Scenario.spawn_banner(g, 1, "wm01-036", false)
	var r := g.declare_attack(bo, g.state.players[1].vanguard)
	assert_eq(r["attacker_power"], 3000, "no rested defender Banner -> no buff")
	assert_false(r["attacker_wins"], "3000 < 5000 bounces")

func test_bo_and_lantern_no_buff_when_defender_has_no_banners():
	var g := Scenario.fresh()
	var bo: CardInstance = Scenario.spawn_banner(g, 0, "wm01-015")
	var r := g.declare_attack(bo, g.state.players[1].vanguard)
	assert_eq(r["attacker_power"], 3000, "empty enemy board -> no buff")

# --- Pilot: rest_punish swings Bo & Lantern at the Vanguard ---------------

func test_rest_punish_sends_bo_and_lantern_at_vanguard_when_line_is_live():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("rest_punish")
	var bo: CardInstance = Scenario.spawn_banner(g, 0, "wm01-015")
	Scenario.spawn_banner(g, 1, "wm01-036", true)  # rested enemy Banner exists
	assert_eq(pol.choose_target(g, 0, bo), g.state.players[1].vanguard,
		"targets the Vanguard to cash the widened +3000")

func test_rest_punish_bo_and_lantern_clears_banner_when_line_is_dead():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("rest_punish")
	var bo: CardInstance = Scenario.spawn_banner(g, 0, "wm01-015")
	# No rested enemy Banner -> widened line dead; falls back to clearing a
	# beatable rested Banner if one appears. Here none, so it hits face anyway.
	assert_eq(pol.choose_target(g, 0, bo), g.state.players[1].vanguard)
