extends GutTest

## Sanity checks that the engine classes load and a game can be set up.

func test_kit_imports():
	var kit: Dictionary = DeckFactory.load_kit()
	assert_eq(kit.size(), 100, "WM01 contains 100 cards (patch 1.1)")
	assert_true(kit.has("wm01-001"), "Sora Vanguard present")

func test_engine_setup_places_life():
	var g := GameEngine.new(12345)
	var deck0: Array = DeckFactory.build_deck(50)
	var deck1: Array = DeckFactory.build_deck(50)
	var vg: CardData = DeckFactory.vanguard()
	g.setup(deck0, vg, deck1, vg, 0)
	assert_eq(g.state.players[0].hand.size(), 5, "Opening hand is 5")
	g.start_game()
	assert_eq(g.state.players[0].life.size(), 5, "Mono-colour Vanguard: 5 Life")
	assert_eq(g.state.players[0].deck.size(), 40, "50 - 5 hand - 5 life = 40")
