extends GutTest

## Patch 0.4 — the refresh-package redesign (uncapped) + Kaya rest nudge.

func test_changelog_04_values():
	var kit: Dictionary = DeckFactory.load_kit()
	# 1. Bram refresh max_cost removed
	assert_false(kit["wm01-023"].effects[0]["action"].has("max_cost"), "Bram refresh uncapped")
	# 2. Stampede: no max_cost, no rider, still up_to 2 Pact
	var st: Dictionary = kit["wm01-032"].effects[0]["action"]
	assert_false(st.has("max_cost"), "Stampede uncapped")
	assert_false(st.has("rider"), "Stampede rider removed")
	assert_eq(int(st["up_to"]), 2)
	assert_eq(str(st["filter_tribe"]), "Pact")
	# 3. Kaya rest max_cost 4 -> 5
	assert_eq(int(kit["wm01-012"].effects[0]["action"]["max_cost"]), 5, "Kaya rests up to cost 5")

# --- Bram Vanguard refreshes a cost-7 Banner (Korgan) ---------------------

func test_bram_vanguard_refreshes_a_cost_seven_banner():
	var g := Scenario.fresh()
	var bram: CardInstance = g._make_instance(DeckFactory.card("wm01-023"), 0)
	bram.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = bram
	Scenario.set_aura(g, 0, 3, 0)
	var korgan: CardInstance = Scenario.spawn_banner(g, 0, "wm01-024", true)  # cost 7, rested
	assert_true(korgan.exhausted, "starts rested")
	assert_true(g.activate_main(bram))
	assert_false(korgan.exhausted, "uncapped Bram refresh reached the cost-7 Korgan")

# --- Stampede refreshes two uncapped-cost Pact Banners --------------------

func test_stampede_refreshes_two_uncapped_pact_banners():
	var g := Scenario.fresh()
	var big1: CardInstance = Scenario.spawn_banner(g, 0, "wm01-024", true)  # Korgan cost 7
	var big2: CardInstance = Scenario.spawn_banner(g, 0, "wm01-035", true)  # Tortallon cost 7
	var stampede: CardInstance = g._make_instance(DeckFactory.card("wm01-032"), 0)
	g._fire(stampede, CardEnums.EV_MAIN)
	assert_false(big1.exhausted, "cost-7 Pact Banner refreshed")
	assert_false(big2.exhausted, "second cost-7 Pact Banner refreshed")
	# And no rider buff anymore.
	assert_eq(big1.current_power(), 8000, "no rider power buff")

func test_stampede_still_filters_to_pact_and_caps_at_two():
	var g := Scenario.fresh()
	var p1: CardInstance = Scenario.spawn_banner(g, 0, "wm01-024", true)  # Pact
	var p2: CardInstance = Scenario.spawn_banner(g, 0, "wm01-035", true)  # Pact
	var p3: CardInstance = Scenario.spawn_banner(g, 0, "wm01-027", true)  # Pact (third)
	var non_pact: CardInstance = Scenario.spawn_banner(g, 0, "wm01-005", true)  # Redgale, rested
	var stampede: CardInstance = g._make_instance(DeckFactory.card("wm01-032"), 0)
	g._fire(stampede, CardEnums.EV_MAIN)
	var refreshed := int(!p1.exhausted) + int(!p2.exhausted) + int(!p3.exhausted)
	assert_eq(refreshed, 2, "only up to 2 Pact Banners refreshed")
	assert_true(non_pact.exhausted, "non-Pact Banner never touched")

# --- Kaya rests a cost-5 Banner -------------------------------------------

func test_kaya_rests_a_cost_five_banner():
	var g := Scenario.fresh()
	var kaya: CardInstance = g._make_instance(DeckFactory.card("wm01-012"), 0)
	kaya.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = kaya
	Scenario.set_aura(g, 0, 3, 0)
	var greatox: CardInstance = Scenario.spawn_banner(g, 1, "wm01-029", false)  # cost 5, ready
	g.declare_attack(kaya, g.state.players[1].vanguard)
	assert_true(greatox.exhausted, "Kaya's rest now reaches a cost-5 Banner")
