extends GutTest

## Combat: power comparison, KO, attach-Aura, counter cards, counter
## techniques, Blocker redirection, When-Attacking buffs, and targeting.
##
## spawn_banner() bypasses On Play, so a card's printed power/keywords drive the
## math regardless of its (unfired) On Play text.

const A_2000 := "wm01-037"          # Route-Sage Immi, power 2000
const A_3000 := "wm01-036"          # Neza, power 3000
const A_5000 := "wm01-005"          # Denji, power 5000
const BLOCKER_3000 := "wm01-025"    # Bram Shieldbrother, Blocker, power 3000
const CTR_2000 := "wm01-049"        # Ledger Clerk, counter value 2000
const WHEN_ATK := "wm01-003"        # Sora First to Ride, When Attacking +2000 (vg Sora)
const CTR_TECH := "wm01-009"        # Redgale Charge!, [Counter] +4000 to own unit

func test_attacker_wins_on_tie():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_3000)
	var def: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000, true)  # rested
	var r := g.declare_attack(atk, def)
	assert_true(r["attacker_wins"], "3000 >= 3000 wins")
	assert_true(r["ko"], "defender KO'd")
	assert_eq(def.zone, CardEnums.ZONE_TRASH)

func test_attacker_loses_when_weaker():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_2000)
	var def: CardInstance = Scenario.spawn_banner(g, 1, A_5000, true)
	var r := g.declare_attack(atk, def)
	assert_false(r["attacker_wins"], "2000 < 5000")
	assert_false(r["ko"])
	assert_eq(def.zone, CardEnums.ZONE_BATTLE, "defender survives")

func test_attacker_exhausts_when_attacking():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_3000)
	var def: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000, true)
	g.declare_attack(atk, def)
	assert_true(atk.exhausted)

func test_when_attacking_buff_applies():
	var g := Scenario.fresh()  # P0 Vanguard is Sora
	var atk: CardInstance = Scenario.spawn_banner(g, 0, WHEN_ATK)  # 3000
	atk.summoning_sick = false
	var r := g.declare_attack(atk, g.state.players[1].vanguard)
	assert_eq(r["attacker_power"], 5000, "3000 + 2000 When Attacking (Sora)")

func test_attach_aura_secures_the_kill():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_2000)          # 2000
	var def: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000, true)  # 3000
	var r := g.declare_attack(atk, def, { "attach_aura": 1 })
	assert_eq(r["attacker_power"], 3000, "2000 + 1000 attached")
	assert_true(r["attacker_wins"])

func test_counter_cards_boost_defender():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_3000)          # 3000
	var def: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000, true)  # 3000
	var counter_card: CardInstance = Scenario.hand_card(g, 1, CTR_2000)  # counter 2000
	var r := g.declare_attack(atk, def, {}, { "counter_cards": [counter_card] })
	assert_eq(r["defender_power"], 5000, "3000 + 2000 counter")
	assert_false(r["attacker_wins"])
	assert_eq(counter_card.zone, CardEnums.ZONE_TRASH)

func test_counter_technique_boosts_defender():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 1, 5, 0)
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_5000)          # 5000
	var def: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000, true)  # 3000
	var tech: CardInstance = Scenario.hand_card(g, 1, CTR_TECH)          # [Counter] +4000
	var r := g.declare_attack(atk, def, {}, { "counter_techniques": [tech] })
	assert_eq(r["defender_power"], 7000, "3000 + 4000 from [Counter] technique")
	assert_false(r["attacker_wins"], "5000 < 7000")
	assert_eq(tech.zone, CardEnums.ZONE_TRASH)

func test_blocker_redirects_and_is_ko_when_outmatched():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_5000)          # 5000
	var blocker: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000)  # 3000 Blocker
	var vg: CardInstance = g.state.players[1].vanguard
	var life_before: int = g.state.players[1].life.size()
	var r := g.declare_attack(atk, vg, {}, { "blocker": blocker })
	assert_eq(r["target"], blocker.uid, "redirected to the Blocker")
	assert_true(r["ko"], "Blocker KO'd")
	assert_eq(g.state.players[1].life.size(), life_before, "Vanguard took no hit")

func test_surviving_blocker_stays_exhausted():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_2000)          # 2000
	var blocker: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000)  # 3000
	var r := g.declare_attack(atk, g.state.players[1].vanguard, {}, { "blocker": blocker })
	assert_false(r["attacker_wins"], "2000 < 3000")
	assert_true(blocker.exhausted, "Blocker exhausted and survived")
	assert_eq(blocker.zone, CardEnums.ZONE_BATTLE)

func test_targeting_excludes_unexhausted_banners():
	var g := Scenario.fresh()
	var atk: CardInstance = Scenario.spawn_banner(g, 0, A_3000)
	var ready: CardInstance = Scenario.spawn_banner(g, 1, A_5000, false)  # ready
	var tapped: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER_3000, true)  # rested
	var targets := g.legal_attack_targets(atk)
	assert_true(targets.has(g.state.players[1].vanguard))
	assert_true(targets.has(tapped), "rested Banner targetable")
	assert_false(targets.has(ready), "ready Banner NOT targetable")
