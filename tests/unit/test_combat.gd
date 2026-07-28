extends GutTest

## Combat: power comparison, KO, attach-Aura, counter cards, counter
## techniques, Blocker redirection, and legal targeting.

func test_attacker_wins_on_tie():
	# attacker power >= defender power => attacker wins.
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")      # 3000
	var def: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel", true)  # 3000, exhausted
	var r := g.declare_attack(atk, def)
	assert_true(r["ok"], "attack legal")
	assert_true(r["attacker_wins"], "3000 >= 3000 wins")
	assert_true(r["ko"], "defender KO'd")
	assert_eq(def.zone, CardEnums.ZONE_TRASH, "KO'd Banner in Trash")

func test_attacker_loses_when_weaker():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "redgale_scout")       # 2000
	var def: CardInstance = Scenario.spawn_banner(g, 1, "emberwing_raptor", true)  # 4000
	var r := g.declare_attack(atk, def)
	assert_false(r["attacker_wins"], "2000 < 4000 loses")
	assert_false(r["ko"], "no KO")
	assert_eq(def.zone, CardEnums.ZONE_BATTLE, "defender survives in Battle Area")

func test_attacker_exhausts_when_attacking():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")
	var def: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel", true)
	g.declare_attack(atk, def)
	assert_true(atk.exhausted, "attacking exhausts the attacker")

func test_when_attacking_buff_applies():
	# Vanguard has a +1000 When Attacking effect (6000 -> 7000).
	var g := Scenario.fresh()
	var atk: CardInstance = g.state.players[0].vanguard
	var target: CardInstance = g.state.players[1].vanguard
	var r := g.declare_attack(atk, target)
	assert_eq(r["attacker_power"], 7000, "6000 + 1000 When Attacking")

func test_attach_aura_secures_the_kill():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "redgale_scout")       # 2000
	var def: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel", true)  # 3000
	var r := g.declare_attack(atk, def, { "attach_aura": 1 })
	assert_eq(r["attacker_power"], 3000, "2000 + 1000 attached")
	assert_true(r["attacker_wins"], "now wins the tie")

func test_counter_cards_boost_defender():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")       # 3000
	var def: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel", true)  # 3000
	var counter_card: CardInstance = Scenario.hand_card(g, 1, "ashguard_sentinel")  # counter 2000
	var r := g.declare_attack(atk, def, {}, { "counter_cards": [counter_card] })
	assert_eq(r["defender_power"], 5000, "3000 + 2000 counter")
	assert_false(r["attacker_wins"], "3000 < 5000")
	assert_eq(counter_card.zone, CardEnums.ZONE_TRASH, "counter card discarded")

func test_counter_technique_boosts_defender():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 1, 5, 0)
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")       # 3000
	var def: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel", true)  # 3000
	var tech: CardInstance = Scenario.hand_card(g, 1, "windward_ward")         # [Counter] +2000
	var r := g.declare_attack(atk, def, {}, { "counter_techniques": [tech] })
	assert_eq(r["defender_power"], 5000, "3000 + 2000 from [Counter] technique")
	assert_false(r["attacker_wins"], "attack repelled")
	assert_eq(tech.zone, CardEnums.ZONE_TRASH, "spent technique to Trash")

func test_blocker_redirects_and_is_ko_when_outmatched():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")       # 3000
	var blocker: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel")   # 3000 Blocker
	var vg: CardInstance = g.state.players[1].vanguard
	var life_before: int = g.state.players[1].life.size()
	var r := g.declare_attack(atk, vg, {}, { "blocker": blocker })
	assert_eq(r["target"], blocker.uid, "attack redirected to the Blocker")
	assert_true(r["ko"], "Blocker KO'd by 3000 vs 3000")
	assert_eq(blocker.zone, CardEnums.ZONE_TRASH, "KO'd Blocker in Trash")
	assert_eq(g.state.players[1].life.size(), life_before, "Vanguard took no Life hit")

func test_surviving_blocker_stays_exhausted_and_protects_vanguard():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "redgale_scout")       # 2000
	var blocker: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel")   # 3000 Blocker
	var vg: CardInstance = g.state.players[1].vanguard
	var life_before: int = g.state.players[1].life.size()
	var r := g.declare_attack(atk, vg, {}, { "blocker": blocker })
	assert_eq(r["target"], blocker.uid, "attack redirected to the Blocker")
	assert_false(r["attacker_wins"], "2000 < 3000, attack repelled")
	assert_true(blocker.exhausted, "Blocker exhausted to block and survived")
	assert_eq(blocker.zone, CardEnums.ZONE_BATTLE, "surviving Blocker stays in play")
	assert_eq(g.state.players[1].life.size(), life_before, "Vanguard protected")

func test_legal_targets_exclude_unexhausted_banners():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")
	var ready: CardInstance = Scenario.spawn_banner(g, 1, "emberwing_raptor", false)  # unexhausted
	var tapped: CardInstance = Scenario.spawn_banner(g, 1, "ashguard_sentinel", true)  # exhausted
	var targets := g.legal_attack_targets(atk)
	assert_true(targets.has(g.state.players[1].vanguard), "Vanguard always targetable")
	assert_true(targets.has(tapped), "exhausted Banner targetable")
	assert_false(targets.has(ready), "unexhausted Banner NOT targetable")

func test_cannot_attack_illegal_target():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")
	var ready: CardInstance = Scenario.spawn_banner(g, 1, "emberwing_raptor", false)
	var r := g.declare_attack(atk, ready)  # unexhausted banner is illegal
	assert_false(r["ok"], "illegal attack rejected")
	assert_false(atk.exhausted, "rejected attack does not exhaust")
