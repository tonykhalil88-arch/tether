extends GutTest

## Archetype-aware pilots: mapping + one signature-line assertion per policy.

func test_vanguard_maps_to_archetype():
	assert_eq(AIPolicy.for_vanguard("wm01-001").archetype, "rush")
	assert_eq(AIPolicy.for_vanguard("wm01-012").archetype, "rest_punish")
	assert_eq(AIPolicy.for_vanguard("wm01-023").archetype, "refresh_tempo")
	assert_eq(AIPolicy.for_vanguard("wm01-034").archetype, "lockdown")
	assert_eq(AIPolicy.for_vanguard("wm01-045").archetype, "filter_control")
	assert_eq(AIPolicy.for_vanguard("wm01-056").archetype, "discount_deploy")
	assert_eq(AIPolicy.for_vanguard("wm01-067").archetype, "drain")
	assert_eq(AIPolicy.for_vanguard("wm01-078").archetype, "threshold_ramp")

# --- rush: Sora buff grants Rush to a Banner played this turn --------------
func test_rush_converts_vanguard_buff_into_rush():
	var g := Scenario.fresh()  # Sora Vanguard
	var pol := AIPolicy.new("rush")
	Scenario.set_aura(g, 0, 6, 0)
	g.state.players[0].hand.clear()
	var redgale: CardInstance = Scenario.hand_card(g, 0, "wm01-005")  # Denji, Redgale
	pol.do_main_phase(g, 0)
	assert_true(redgale.has_keyword(CardEnums.KW_RUSH), "Sora granted Rush")
	assert_true(int(g.state.watch.get("sora_rush_grants", 0)) >= 1)

# --- rest_punish: attack the rested Banner; Bo & Lantern gets +2000 --------
func test_rest_punish_targets_rested_banner():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("rest_punish")
	var attacker: CardInstance = Scenario.spawn_banner(g, 0, "wm01-005")     # 5000
	var rested: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036", true)  # 3000, rested
	assert_eq(pol.choose_target(g, 0, attacker), rested, "punishes the rested Banner")

func test_bo_and_lantern_line_buffs_into_rested_target():
	var g := Scenario.fresh()
	var bo: CardInstance = Scenario.spawn_banner(g, 0, "wm01-015")   # Bo & Lantern, 3000
	var rested: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036", true)
	var r := g.declare_attack(bo, rested)
	assert_eq(r["attacker_power"], 6000, "Patch 0.2: 3000 + 3000 vs a rested target")

# --- refresh_tempo: Stampede double-refresh when lethal-relevant -----------
func test_refresh_tempo_finds_lethal_stampede_double_refresh():
	var g := Scenario.fresh()
	var bram := DeckFactory.card("wm01-023")
	g.state.players[0].vanguard = g._make_instance(bram, 0)
	g.state.players[0].vanguard.zone = CardEnums.ZONE_VANGUARD
	Scenario.set_aura(g, 0, 5, 0)
	Scenario.set_life(g, 1, 1)  # lethal-relevant: one hit ends it
	g.state.players[0].vanguard.exhausted = true  # Bram already swung; only the
	                                              # refreshed Banners remain
	# Two rested cost-3 Pact bodies that connect with a 5000 Vanguard.
	Scenario.spawn_banner(g, 0, "wm01-027", true)  # Warband Outriders, 5000
	Scenario.spawn_banner(g, 0, "wm01-027", true)
	Scenario.hand_card(g, 0, "wm01-032")           # Stampede Doctrine
	var pol := AIPolicy.new("refresh_tempo")
	pol.run_attacks(g, 0, AIPolicy.new("rush"))
	assert_true(int(g.state.watch.get("stampede_multi_refresh", 0)) >= 1, "Stampede double-refresh fired")

func test_refresh_tempo_natural_batch_triggers_stampede():
	var m: Dictionary = MatchRunner.run_matchup("wm01-023", "wm01-023", 40, 500)
	assert_true(int(m["watch"]["stampede_multi_refresh"]) > 0,
		"Stampede fires in a natural refresh_tempo batch")

# --- lockdown: rest + freeze the biggest threat ---------------------------
func test_lockdown_freezes_a_rested_threat():
	var g := Scenario.fresh_with_vanguards("wm01-034", "wm01-034")  # Elder Neza
	Scenario.set_aura(g, 0, 4, 0)
	g.state.players[0].hand.clear()
	var threat: CardInstance = Scenario.spawn_banner(g, 1, "wm01-036", true)  # rested, cost 2
	var pol := AIPolicy.new("lockdown")
	pol.do_main_phase(g, 0)
	assert_true(threat.frozen, "Neza froze the rested threat")

# --- filter_control: filter every turn (Averil) ---------------------------
func test_filter_control_filters_each_turn():
	var g := Scenario.fresh_with_vanguards("wm01-045", "wm01-045")  # Averil
	Scenario.set_aura(g, 0, 3, 0)
	var pol := AIPolicy.new("filter_control")
	pol.do_main_phase(g, 0)
	assert_true(int(g.state.watch.get("averil_cards_seen", 0)) >= 1, "Averil filtered")

# --- discount_deploy: Canyon + Vale discount enables the big Bulwark -------
func test_discount_deploy_lands_a_discounted_big_bulwark():
	var g := Scenario.fresh_with_vanguards("wm01-056", "wm01-056")  # Vale
	Scenario.set_stage(g, 0, "wm01-066")   # Canyon Bastion
	Scenario.set_aura(g, 0, 3, 0)          # only affordable at -2
	g.state.players[0].hand.clear()
	var big: CardInstance = Scenario.hand_card(g, 0, "wm01-062")  # Artillery, Bulwark, cost 5
	var pol := AIPolicy.new("discount_deploy")
	pol.do_main_phase(g, 0)
	assert_eq(big.zone, CardEnums.ZONE_BATTLE, "cost 5 Bulwark deployed on 3 Aura via -2 discount")

# --- drain: freeze enemy Aura every turn ----------------------------------
func test_drain_freezes_enemy_aura():
	var g := Scenario.fresh_with_vanguards("wm01-067", "wm01-067")  # Rue
	Scenario.set_aura(g, 0, 5, 0)
	g.state.players[1].aura_total = 5
	var pol := AIPolicy.new("drain")
	pol.run_attacks(g, 0, AIPolicy.new("drain"))
	assert_true(int(g.state.watch.get("rue_aura_frozen", 0)) >= 1, "Rue froze enemy Aura")

# --- threshold_ramp: deploy the Walkbreaker at 9 Aura ---------------------
func test_threshold_ramp_deploys_walkbreaker():
	var g := Scenario.fresh_with_vanguards("wm01-078", "wm01-078")  # Dreyse
	Scenario.set_aura(g, 0, 9, 0)
	g.state.players[0].hand.clear()
	var walk: CardInstance = Scenario.hand_card(g, 0, "wm01-079")  # Walkbreaker, cost 9
	var pol := AIPolicy.new("threshold_ramp")
	pol.do_main_phase(g, 0)
	assert_eq(walk.zone, CardEnums.ZONE_BATTLE, "Walkbreaker deployed once ramped to 9")
