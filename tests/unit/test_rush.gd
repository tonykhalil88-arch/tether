extends GutTest

## Summoning sickness and the Rush exception.

const NON_RUSH := "wm01-005"   # Denji, cost 3, no Rush
const RUSH := "wm01-006"       # Redgale Twins, cost 4, Rush

func test_freshly_played_banner_cannot_attack():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 6, 0)
	var b: CardInstance = Scenario.hand_card(g, 0, NON_RUSH)
	assert_true(g.play_card(0, b))
	assert_true(b.summoning_sick)
	assert_false(g.can_attack(b), "cannot attack the turn it's played")

func test_rush_banner_can_attack_immediately():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 6, 0)
	var b: CardInstance = Scenario.hand_card(g, 0, RUSH)
	assert_true(g.play_card(0, b))
	assert_true(g.can_attack(b), "Rush ignores summoning sickness")

func test_sickness_clears_next_turn():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 6, 0)
	var b: CardInstance = Scenario.hand_card(g, 0, NON_RUSH)
	g.play_card(0, b)
	g.end_turn()
	g.begin_turn()  # P1
	g.end_turn()
	g.begin_turn()  # back to P0
	assert_false(b.summoning_sick)
	assert_true(g.can_attack(b))

func test_granted_rush_via_effect():
	var g := Scenario.fresh()
	var b: CardInstance = Scenario.spawn_banner(g, 0, NON_RUSH, false, true)
	assert_false(g.can_attack(b), "sick, no Rush")
	b.grant_keyword(CardEnums.KW_RUSH)
	assert_true(g.can_attack(b), "granted Rush enables the attack")
