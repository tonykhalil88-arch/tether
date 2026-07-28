extends GutTest

## Summoning sickness: Banners cannot attack the turn they are played unless
## they have Rush.

func test_freshly_played_banner_cannot_attack():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var b: CardInstance = Scenario.hand_card(g, 0, "redgale_scout")  # no Rush
	assert_true(g.play_card(0, b))
	assert_true(b.summoning_sick, "just played => summoning sick")
	assert_false(g.can_attack(b), "cannot attack the turn it's played")

func test_rush_banner_can_attack_immediately():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var b: CardInstance = Scenario.hand_card(g, 0, "cinder_darter")  # Rush
	assert_true(g.play_card(0, b))
	assert_true(b.summoning_sick, "still marked sick...")
	assert_true(g.can_attack(b), "...but Rush ignores summoning sickness")

func test_sickness_clears_next_turn():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var b: CardInstance = Scenario.hand_card(g, 0, "redgale_scout")
	g.play_card(0, b)
	g.end_turn()
	g.begin_turn()  # P1
	g.end_turn()
	g.begin_turn()  # back to P0: Refresh clears sickness
	assert_false(b.summoning_sick, "sickness cleared on controller's next turn")
	assert_true(g.can_attack(b), "now able to attack")

func test_granted_rush_via_effect():
	var g := Scenario.fresh()
	var b: CardInstance = Scenario.spawn_banner(g, 0, "redgale_scout", false, true)
	assert_false(g.can_attack(b), "sick, no Rush")
	b.grant_keyword(CardEnums.KW_RUSH)
	assert_true(g.can_attack(b), "granted Rush enables the attack")
