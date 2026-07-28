class_name Scenario
extends RefCounted

## Test helper for building precise, controlled game states. Bypasses the
## random deck shuffle so combat/rules tests are deterministic.

## A game post-setup with both Vanguards and Life placed, parked in P0's Main
## phase on turn 1. Tests then spawn units / set Aura as needed.
static func fresh(seed_value: int = 999) -> GameEngine:
	var g := GameEngine.new(seed_value)
	var vg: CardData = DeckFactory.vanguard()
	g.setup(DeckFactory.build_deck(50), vg, DeckFactory.build_deck(50), vg, 0)
	g.start_game()
	g.state.turn_number = 1
	g.state.active_player = 0
	g.state.phase = GameState.PHASE_MAIN
	return g


## Put a Banner directly into a player's Battle Area with explicit state.
static func spawn_banner(g: GameEngine, player: int, card_id: String,
		exhausted: bool = false, summoning_sick: bool = false) -> CardInstance:
	var kit: Dictionary = DeckFactory.load_kit()
	var inst: CardInstance = g._make_instance(kit[card_id], player)
	inst.zone = CardEnums.ZONE_BATTLE
	inst.exhausted = exhausted
	inst.summoning_sick = summoning_sick
	g.state.players[player].battle_area.append(inst)
	return inst


## Put a card into a player's hand and return the instance.
static func hand_card(g: GameEngine, player: int, card_id: String) -> CardInstance:
	var kit: Dictionary = DeckFactory.load_kit()
	var inst: CardInstance = g._make_instance(kit[card_id], player)
	inst.zone = CardEnums.ZONE_HAND
	g.state.players[player].hand.append(inst)
	return inst


## Overwrite a player's Aura pool.
static func set_aura(g: GameEngine, player: int, total: int, exhausted: int = 0) -> void:
	g.state.players[player].aura_total = total
	g.state.players[player].aura_exhausted = exhausted


## Force a player's Life pile to an exact count of face-down cards.
static func set_life(g: GameEngine, player: int, count: int) -> void:
	var ps: PlayerState = g.state.players[player]
	while ps.life.size() > count:
		var c: CardInstance = ps.life.pop_back()
		c.zone = CardEnums.ZONE_DECK
		ps.deck.append(c)
	while ps.life.size() < count and not ps.deck.is_empty():
		var c: CardInstance = ps.deck.pop_front()
		c.zone = CardEnums.ZONE_LIFE
		ps.life.append(c)
