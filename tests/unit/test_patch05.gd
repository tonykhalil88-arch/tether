extends GutTest

## Patch 0.5 — the Kaya rest-package uncap (Verdigris / Toll / Twilight Road).

func test_set_is_patch_12_carrying_the_05_tuning():
	# The set is now patch 1.2 (mono-recolour baseline); it still carries the full
	# 0.2–0.5 card tuning unchanged (verified by the value checks below).
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DeckFactory.KIT_PATH))
	assert_eq(str(parsed["set"]["patch"]), "1.2")

func test_changelog_05_values():
	var kit: Dictionary = DeckFactory.load_kit()
	# 1. Verdigris double-rest max_cost removed
	assert_false(kit["wm01-013"].effects[0]["action"].has("max_cost"), "Verdigris rest uncapped")
	assert_eq(int(kit["wm01-013"].effects[0]["action"]["up_to"]), 2)
	# 2. Toll of the Quiet Road both modes max_cost 4 -> 6
	assert_eq(int(kit["wm01-020"].effects[0]["action"]["max_cost"]), 6, "Toll main rests up to cost 6")
	assert_eq(int(kit["wm01-020"].effects[1]["action"]["max_cost"]), 6, "Toll life-trigger too")
	# 3. Twilight Road max_cost 3 -> 4
	assert_eq(int(kit["wm01-022"].effects[0]["action"]["max_cost"]), 4, "Twilight Road rests up to cost 4")

# --- Verdigris rests two uncapped-cost Banners ----------------------------

func test_verdigris_rests_two_uncapped_banners():
	var g := Scenario.fresh()
	var verd: CardInstance = Scenario.spawn_banner(g, 0, "wm01-013")
	var walk: CardInstance = Scenario.spawn_banner(g, 1, "wm01-079")   # Walkbreaker cost 9
	var doctrine: CardInstance = Scenario.spawn_banner(g, 1, "wm01-057")  # Doctrine cost 8
	g._fire(verd, CardEnums.EV_ON_PLAY)
	assert_true(walk.exhausted, "cost-9 Banner rested")
	assert_true(doctrine.exhausted, "cost-8 Banner rested")

# --- Toll rests a cost-6 Banner -------------------------------------------

func test_toll_rests_a_cost_six_banner():
	var g := Scenario.fresh()
	var ram: CardInstance = Scenario.spawn_banner(g, 1, "wm01-084")  # Ram-Titan cost 6
	var toll: CardInstance = g._make_instance(DeckFactory.card("wm01-020"), 0)
	g._fire(toll, CardEnums.EV_MAIN)
	assert_true(ram.exhausted, "Toll now reaches a cost-6 Banner")

# --- Rest auto-targets the BIGGEST legal threat ---------------------------

func test_rest_prioritises_the_biggest_legal_threat():
	var g := Scenario.fresh()
	var verd: CardInstance = Scenario.spawn_banner(g, 0, "wm01-013")  # rests up to 2, uncapped
	var small: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036", false)  # 3000
	var walk: CardInstance = Scenario.spawn_banner(g, 1, "wm01-079", false)   # 9000
	var mid: CardInstance = Scenario.spawn_banner(g, 1, "wm01-072", false)    # 6000
	g._fire(verd, CardEnums.EV_ON_PLAY)  # picks the 2 highest-power
	assert_true(walk.exhausted, "9000 threat rested")
	assert_true(mid.exhausted, "6000 threat rested")
	assert_false(small.exhausted, "3000 body left alone")

func test_kaya_vanguard_rests_biggest_when_attacking():
	var g := Scenario.fresh()
	var kaya: CardInstance = g._make_instance(DeckFactory.card("wm01-012"), 0)
	kaya.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = kaya
	Scenario.set_aura(g, 0, 3, 0)
	var small: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036", false)  # 3000
	var greatox: CardInstance = Scenario.spawn_banner(g, 1, "wm01-029", false)  # 6000, cost 5
	g.declare_attack(kaya, g.state.players[1].vanguard)
	assert_true(greatox.exhausted, "rested the cost-5 6000 threat")
	assert_false(small.exhausted, "not the small body")
