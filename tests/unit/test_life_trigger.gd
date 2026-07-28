extends GutTest

## Life / Trigger flow: a Vanguard hit flips a Life card into hand, unless it
## carries a life_trigger the defender resolves instead (e.g. play_self).

const PLAIN := "wm01-005"        # Denji, no life_trigger
const PLAY_SELF := "wm01-008"    # Stormfoal Hatchling, life_trigger: play_self

func _put_on_top_of_life(g: GameEngine, player: int, card_id: String) -> CardInstance:
	var inst: CardInstance = g._make_instance(DeckFactory.card(card_id), player)
	inst.zone = CardEnums.ZONE_LIFE
	g.state.players[player].life.push_front(inst)
	return inst

func test_plain_life_card_flips_to_hand():
	var g := Scenario.fresh()
	var top := _put_on_top_of_life(g, 1, PLAIN)
	var hand_before: int = g.state.players[1].hand.size()
	var r := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_true(r["attacker_wins"], "5000 vs 5000")
	assert_true(r["life_flipped"])
	assert_eq(top.zone, CardEnums.ZONE_HAND, "no trigger => card to hand")
	assert_eq(g.state.players[1].hand.size(), hand_before + 1)

func test_life_trigger_play_self_puts_banner_into_play():
	var g := Scenario.fresh()
	var top := _put_on_top_of_life(g, 1, PLAY_SELF)
	var battle_before: int = g.state.players[1].battle_area.size()
	var r := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_true(r.get("trigger_resolved", false), "life_trigger resolved")
	assert_eq(top.zone, CardEnums.ZONE_BATTLE, "play_self put it into play")
	assert_eq(g.state.players[1].battle_area.size(), battle_before + 1)

func test_declining_trigger_adds_it_to_hand():
	var g := Scenario.fresh()
	var top := _put_on_top_of_life(g, 1, PLAY_SELF)
	var hand_before: int = g.state.players[1].hand.size()
	g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard,
		{}, { "resolve_trigger": false })
	assert_eq(top.zone, CardEnums.ZONE_HAND, "declined trigger => hand")
	assert_eq(g.state.players[1].hand.size(), hand_before + 1)
