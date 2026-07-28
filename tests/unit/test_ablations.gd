extends GutTest

## Ablation config layer + defence-economy metrics.

func test_a1_sora_rush_rider_disabled_keeps_buff_drops_rush():
	var g := Scenario.fresh()
	g.state.ablations = { "sora_no_rush_rider": true }
	Scenario.set_aura(g, 0, 6, 0)
	var redgale: CardInstance = Scenario.spawn_banner(g, 0, "wm01-005")
	redgale.played_on_turn = g.state.turn_number
	var before: int = redgale.current_power()
	g.activate_main(g.state.players[0].vanguard)
	assert_eq(redgale.current_power(), before + 2000, "buff still lands")
	assert_false(redgale.has_keyword(CardEnums.KW_RUSH), "but no Rush granted")
	assert_eq(int(g.state.watch.get("sora_rush_grants", 0)), 0)

func test_a4_verdigris_rests_one_instead_of_two():
	var g := Scenario.fresh()
	g.state.ablations = { "verdigris_rest_1": true }
	var verd: CardInstance = Scenario.spawn_banner(g, 0, "wm01-013")
	var e1: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036")  # cost 2
	var e2: CardInstance = Scenario.spawn_banner(g, 1, "wm01-025")  # cost 2
	g._fire(verd, CardEnums.EV_ON_PLAY)
	var rested := int(e1.exhausted) + int(e2.exhausted)
	assert_eq(rested, 1, "only one enemy Banner rested")

func test_a2_total_mobilisation_blanked():
	var g := Scenario.fresh()
	g.state.ablations = { "blank_total_mobilisation": true }
	Scenario.set_aura(g, 0, 5, 0)
	var before: int = g.state.players[0].aura_total
	var tm: CardInstance = Scenario.spawn_banner(g, 0, "wm01-087")  # placed as source
	g._fire(tm, CardEnums.EV_MAIN)
	assert_eq(g.state.players[0].aura_total, before, "blanked card gained no Aura")

func test_a5_korgan_refresh_disabled():
	var g := Scenario.fresh()
	g.state.ablations = { "korgan_no_refresh": true }
	Scenario.set_aura(g, 0, 5, 0)
	var korgan: CardInstance = Scenario.spawn_banner(g, 0, "wm01-024")
	korgan.summoning_sick = false
	g.declare_attack(korgan, g.state.players[1].vanguard)
	assert_true(korgan.exhausted, "Korgan stays rested — no end-of-battle refresh")
	assert_eq(int(g.state.watch.get("korgan_repeat_attacks", 0)), 0)

func test_metrics_record_attacks_and_connects():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "wm01-005")        # 5000
	var weak: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036", true)  # 3000, rested
	g.declare_attack(atk, weak)
	var m: Dictionary = g.state.metrics[0]
	assert_eq(m["attacks"], 1)
	assert_eq(m["connects"], 1, "5000 >= 3000 connected")
	assert_eq(m["atk_power_sum"], 5000)
	assert_eq(m["def_power_sum"], 3000)

func test_metrics_record_counter_cards_and_life():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "wm01-035")   # Tortallon, 9000
	# Defender pitches a counter card (Vanguard 5000 + 2000 = 7000) but 9000
	# still connects, so a Life is lost too.
	var ctr: CardInstance = Scenario.hand_card(g, 1, "wm01-049")      # counter 2000
	var r := g.declare_attack(atk, g.state.players[1].vanguard, {}, { "counter_cards": [ctr] })
	assert_true(r["attacker_wins"], "9000 >= 7000")
	assert_eq(int(g.state.metrics[1]["counter_cards_spent"]), 1)
	assert_eq(int(g.state.metrics[1]["life_lost"]), 1)
