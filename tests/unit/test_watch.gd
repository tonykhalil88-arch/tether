extends GutTest

## The balance watch-list: each flagged card increments its counter when it
## actually resolves, so the sim can query win-rate impact.

func test_verdigris_double_rest_flag():
	var g := Scenario.fresh()
	var verd: CardInstance = Scenario.spawn_banner(g, 0, "wm01-013")  # rest max_cost 3, up_to 2
	Scenario.spawn_banner(g, 1, "wm01-036")  # cost 2
	Scenario.spawn_banner(g, 1, "wm01-025")  # cost 2
	g._fire(verd, CardEnums.EV_ON_PLAY)
	assert_eq(int(g.state.watch.get("verdigris_double_rest", 0)), 1, "double-rest flagged")

func test_sora_rush_grant_flag():
	var g := Scenario.fresh()  # Sora Vanguard
	Scenario.set_aura(g, 0, 5, 0)
	var redgale: CardInstance = Scenario.spawn_banner(g, 0, "wm01-005")  # Denji, Redgale
	redgale.played_on_turn = g.state.turn_number
	assert_true(g.activate_main(g.state.players[0].vanguard))
	assert_true(redgale.has_keyword(CardEnums.KW_RUSH), "Sora granted Rush")
	assert_eq(int(g.state.watch.get("sora_rush_grants", 0)), 1)

func test_korgan_repeat_attack_flag():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var korgan: CardInstance = Scenario.spawn_banner(g, 0, "wm01-024")  # refresh self end_of_battle
	korgan.summoning_sick = false
	var r := g.declare_attack(korgan, g.state.players[1].vanguard)
	assert_true(r["attacker_wins"])
	assert_false(korgan.exhausted, "Korgan refreshed at end of battle")
	assert_eq(int(g.state.watch.get("korgan_repeat_attacks", 0)), 1)

func test_rue_aura_frozen_flag():
	var g := Scenario.fresh()
	var rue: CardInstance = g._make_instance(DeckFactory.card("wm01-067"), 0)
	rue.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = rue
	Scenario.set_aura(g, 0, 5, 0)
	g.state.players[1].aura_total = 4
	g.declare_attack(rue, g.state.players[1].vanguard)
	assert_eq(int(g.state.watch.get("rue_aura_frozen", 0)), 1, "1 Aura frozen flagged")
	assert_eq(g.state.players[1].aura_frozen_pending, 1)

func test_averil_cards_seen_flag():
	var g := Scenario.fresh()
	var averil: CardInstance = g._make_instance(DeckFactory.card("wm01-045"), 0)
	averil.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = averil
	Scenario.set_aura(g, 0, 5, 0)
	g.activate_main(averil)  # draw_then_bottom draw 1
	assert_eq(int(g.state.watch.get("averil_cards_seen", 0)), 1)

func test_stampede_multi_refresh_flag():
	var g := Scenario.fresh()
	# Two exhausted Pact Banners of cost <= 3.
	Scenario.spawn_banner(g, 0, "wm01-030", true)  # Calfling, Pact, cost 1
	Scenario.spawn_banner(g, 0, "wm01-036", true)  # Neza, Pact, cost 2
	var stampede: CardInstance = g._make_instance(DeckFactory.card("wm01-032"), 0)
	g._fire(stampede, CardEnums.EV_MAIN)
	assert_eq(int(g.state.watch.get("stampede_multi_refresh", 0)), 1, "multi-refresh flagged")
