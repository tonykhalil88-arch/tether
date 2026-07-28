extends GutTest

## Setup: opening hand, Life placement (5 mono / 4 dual), and the free mulligan.

func _mono_vg() -> CardData:
	return DeckFactory.card("wm01-001")   # Sora, mono-red, life 5

func _dual_vg() -> CardData:
	return DeckFactory.card("wm01-012")   # Kaya, red/green, life 4

func test_opening_hand_is_five():
	var g := GameEngine.new(1)
	g.setup(DeckFactory.build_deck(50), _mono_vg(), DeckFactory.build_deck(50), _mono_vg(), 0)
	assert_eq(g.state.players[0].hand.size(), 5)
	assert_eq(g.state.players[1].hand.size(), 5)

func test_mono_colour_vanguard_places_five_life():
	var g := GameEngine.new(2)
	g.setup(DeckFactory.build_deck(50), _mono_vg(), DeckFactory.build_deck(50), _mono_vg(), 0)
	g.start_game()
	assert_eq(g.state.players[0].life.size(), 5, "mono => 5 Life")

func test_dual_colour_vanguard_places_four_life():
	var g := GameEngine.new(3)
	var dv := _dual_vg()
	g.setup(DeckFactory.deck_for(dv), dv, DeckFactory.deck_for(dv), dv, 0)
	g.start_game()
	assert_eq(g.state.players[0].life.size(), 4, "dual => 4 Life")

func test_mulligan_reshuffles_and_redraws_five():
	var g := GameEngine.new(4)
	g.setup(DeckFactory.build_deck(50), _mono_vg(), DeckFactory.build_deck(50), _mono_vg(), 0)
	var deck_before: int = g.state.players[0].deck.size()
	assert_true(g.mulligan(0), "first mulligan allowed")
	assert_eq(g.state.players[0].hand.size(), 5, "redraw 5")
	assert_eq(g.state.players[0].deck.size(), deck_before, "deck size restored")

func test_only_one_mulligan_allowed():
	var g := GameEngine.new(5)
	g.setup(DeckFactory.build_deck(50), _mono_vg(), DeckFactory.build_deck(50), _mono_vg(), 0)
	assert_true(g.mulligan(0), "first mulligan ok")
	assert_false(g.mulligan(0), "second mulligan refused")
