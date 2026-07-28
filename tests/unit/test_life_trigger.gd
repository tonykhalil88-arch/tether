extends GutTest

## Life / Trigger flow: a Vanguard hit flips a Life card into hand, unless it
## is a [Trigger] the defender resolves instead.

func _trigger_card() -> CardData:
	return CardData.from_dict({
		"id": "test_trigger", "name": "Test Trigger", "type": "Technique",
		"colors": ["Red"], "cost": 0, "power": 0, "counter": 0, "life": 0,
		"keywords": ["Trigger"],
		"effects": [{ "trigger": "on_trigger_reveal", "action": "draw", "params": { "amount": 1 } }],
		"flavor": "", "faction": "", "tribe": "",
	})

func _put_on_top_of_life(g: GameEngine, player: int, cd: CardData) -> CardInstance:
	var inst: CardInstance = g._make_instance(cd, player)
	inst.zone = CardEnums.ZONE_LIFE
	g.state.players[player].life.push_front(inst)
	return inst

func test_vanguard_hit_flips_life_to_hand():
	var g := Scenario.fresh()
	var life_before: int = g.state.players[1].life.size()
	var hand_before: int = g.state.players[1].hand.size()
	var r := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_true(r["attacker_wins"], "7000 vs 6000")
	assert_true(r["life_flipped"], "Life was flipped")
	assert_eq(g.state.players[1].life.size(), life_before - 1, "one Life lost")
	assert_eq(g.state.players[1].hand.size(), hand_before + 1, "flipped card added to hand")

func test_trigger_resolves_instead_of_going_to_hand():
	var g := Scenario.fresh()
	var trig: CardInstance = _put_on_top_of_life(g, 1, _trigger_card())
	var hand_before: int = g.state.players[1].hand.size()
	var deck_before: int = g.state.players[1].deck.size()
	var r := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard,
		{}, { "resolve_trigger": true })
	assert_true(r.get("trigger_resolved", false), "trigger was resolved")
	assert_eq(trig.zone, CardEnums.ZONE_TRASH, "resolved trigger goes to Trash")
	# The trigger drew a card: deck -1, and hand net +1 from the draw (not the
	# life card itself).
	assert_eq(g.state.players[1].deck.size(), deck_before - 1, "trigger drew a card")
	assert_eq(g.state.players[1].hand.size(), hand_before + 1, "draw, not the Life card")

func test_declining_trigger_adds_it_to_hand():
	var g := Scenario.fresh()
	var trig: CardInstance = _put_on_top_of_life(g, 1, _trigger_card())
	var hand_before: int = g.state.players[1].hand.size()
	g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard,
		{}, { "resolve_trigger": false })
	assert_eq(trig.zone, CardEnums.ZONE_HAND, "declined trigger added to hand")
	assert_eq(g.state.players[1].hand.size(), hand_before + 1)
