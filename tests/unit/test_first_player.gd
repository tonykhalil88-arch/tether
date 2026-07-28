extends GutTest

## First-player asymmetries: skip the draw on turn 1, gain only 1 Aura on
## turn 1; the second player draws normally and gains 2.

func _game(first: int) -> GameEngine:
	var g := GameEngine.new(20)
	var vg: CardData = DeckFactory.vanguard()
	g.setup(DeckFactory.build_deck(50), vg, DeckFactory.build_deck(50), vg, first)
	g.start_game()
	return g

func test_first_player_skips_draw_on_turn_one():
	var g := _game(0)
	var hand_before: int = g.state.players[0].hand.size()
	g.begin_turn()  # turn 1, player 0
	assert_eq(g.state.players[0].hand.size(), hand_before, "no draw on turn 1")

func test_first_player_gains_one_aura_on_turn_one():
	var g := _game(0)
	g.begin_turn()
	assert_eq(g.state.players[0].aura_total, 1, "1 Aura on turn 1")

func test_second_player_draws_on_their_first_turn():
	var g := _game(0)
	g.begin_turn()  # turn 1 P0
	g.end_turn()
	var hand_before: int = g.state.players[1].hand.size()
	g.begin_turn()  # turn 2 P1
	assert_eq(g.state.players[1].hand.size(), hand_before + 1, "P1 draws on turn 2")

func test_second_player_gains_two_aura():
	var g := _game(0)
	g.begin_turn()
	g.end_turn()
	g.begin_turn()  # P1 turn 2
	assert_eq(g.state.players[1].aura_total, 2, "P1 gains 2 Aura")

func test_first_player_gains_two_aura_on_later_turns():
	var g := _game(0)
	g.begin_turn()      # T1 P0 -> +1 (total 1)
	g.end_turn()
	g.begin_turn()      # T2 P1
	g.end_turn()
	g.begin_turn()      # T3 P0 -> +2 (total 3)
	assert_eq(g.state.players[0].aura_total, 3, "1 then 2 => 3 total")

func test_designating_player_one_as_first_still_skips_correctly():
	var g := _game(1)  # player 1 goes first
	var p := g.begin_turn()
	assert_eq(p, 1, "player 1 is the first player")
	assert_eq(g.state.players[1].aura_total, 1, "first player (P1) gains 1")
