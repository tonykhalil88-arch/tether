extends GutTest

## The scripted AI must understand Rush (attack the turn a Banner is played)
## and Freeze (a frozen/rested Banner is a target, not a valid blocker), so the
## simulator's balance flags are meaningful.

const RUSH := "wm01-006"      # Redgale Twins, Rush, 5000
const READY := "wm01-005"     # Denji, 5000
const SMALL := "wm01-036"     # Neza, 3000
const BLOCKER := "wm01-017"   # Pact Scout Iva, Blocker, 3000

# --- Rush -----------------------------------------------------------------

func test_ai_attacks_with_a_freshly_played_rush_banner():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("rush")
	Scenario.set_aura(g, 0, 10, 0)
	g.state.players[0].hand.clear()  # isolate: the Rush banner is the only play
	var rush: CardInstance = Scenario.hand_card(g, 0, RUSH)
	pol.do_main_phase(g, 0)
	assert_eq(rush.zone, CardEnums.ZONE_BATTLE, "Rush banner deployed")
	# With the Vanguard already spent, the AI still finds the Rush attacker.
	g.state.players[0].vanguard.exhaust()
	assert_true(g.can_attack(rush), "Rush ignores summoning sickness")
	assert_eq(pol.choose_attacker(g, 0), rush, "AI attacks with the Rush banner")

func test_ai_does_not_pick_a_sick_non_rush_banner():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("rush")
	g.state.players[0].vanguard.exhaust()
	Scenario.spawn_banner(g, 0, READY, false, true)  # sick, no Rush
	assert_null(pol.choose_attacker(g, 0), "no legal attacker this turn")

# --- Freeze awareness -----------------------------------------------------

func test_control_pilot_will_not_block_with_a_frozen_banner():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("filter_control")  # a defending archetype
	Scenario.set_life(g, 1, 1)  # low life -> wants to block
	var blocker: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER)
	blocker.frozen = true
	blocker.exhausted = true      # frozen banners are rested
	var choices := pol.defender_choices(g, 1, g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_false(choices.has("blocker"), "a frozen/rested Blocker cannot block")

func test_control_pilot_blocks_with_a_ready_blocker():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("filter_control")
	Scenario.set_life(g, 1, 1)
	var blocker: CardInstance = Scenario.spawn_banner(g, 1, BLOCKER, false)  # ready
	var choices := pol.defender_choices(g, 1, g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_eq(choices.get("blocker", null), blocker, "a ready Blocker is used")

func test_punish_pilot_targets_a_rested_enemy_banner_it_can_beat():
	var g := Scenario.fresh()
	var pol := AIPolicy.new("rest_punish")
	var attacker: CardInstance = Scenario.spawn_banner(g, 0, READY)     # 5000
	var rested: CardInstance = Scenario.spawn_banner(g, 1, SMALL, true)  # 3000, rested
	var target := pol.choose_target(g, 0, attacker)
	assert_eq(target, rested, "clears the beatable rested Banner")
