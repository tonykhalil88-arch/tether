extends GutTest

## Turn structure: phase order, Refresh unexhausts, End clears buffs, no hand cap.

const B_VANILLA := "wm01-005"   # Denji, pow 5000, no effects
const B_FILLER := "wm01-050"    # PR Directorate Chief, pow 5000, no effects

func _started_game(seed_value: int = 10) -> GameEngine:
	var g := GameEngine.new(seed_value)
	var vg: CardData = DeckFactory.vanguard()
	g.setup(DeckFactory.build_deck(50), vg, DeckFactory.build_deck(50), vg, 0)
	g.start_game()
	return g

func test_begin_turn_lands_in_main_phase():
	var g := _started_game()
	var p := g.begin_turn()
	assert_eq(p, 0, "first player acts on turn 1")
	assert_eq(g.state.phase, GameState.PHASE_MAIN)
	assert_eq(g.state.turn_number, 1)

func test_refresh_unexhausts_all_own_cards():
	var g := _started_game()
	g.begin_turn()
	var b: CardInstance = Scenario.spawn_banner(g, 0, B_VANILLA, true, false)
	g.state.players[0].vanguard.exhaust()
	Scenario.set_aura(g, 0, 5, 5)
	g.end_turn()
	g.begin_turn()  # P1
	g.end_turn()
	g.begin_turn()  # back to P0 -> refresh
	assert_false(b.exhausted, "Banner refreshed")
	assert_false(g.state.players[0].vanguard.exhausted, "Vanguard refreshed")
	assert_eq(g.state.players[0].aura_exhausted, 0, "Aura refreshed")

func test_no_hand_size_cap_at_end_of_turn():
	var g := _started_game()
	g.begin_turn()
	for i in range(12):
		Scenario.hand_card(g, 0, B_FILLER)
	var before: int = g.state.players[0].hand.size()
	g.end_turn()
	assert_eq(g.state.players[0].hand.size(), before, "no discard-to-hand-size")
	assert_true(before >= 12, "hand can exceed any cap")

func test_end_turn_clears_turn_and_battle_bonuses():
	var g := _started_game()
	g.begin_turn()
	var b: CardInstance = Scenario.spawn_banner(g, 0, B_VANILLA)
	b.battle_power_bonus = 3000
	b.turn_power_bonus = 2000
	g.end_turn()
	assert_eq(b.battle_power_bonus, 0, "battle buffs expire")
	assert_eq(b.turn_power_bonus, 0, "turn buffs expire at end of turn")
