extends GutTest

## Cost reduction: Idris Vale (passive, once/turn, Bulwark) and Canyon Bastion
## (Stage, next Bulwark Banner) stack to -2, but never below cost 1.

const VALE := "wm01-056"       # Vanguard: -1 to a Bulwark Banner play (passive)
const CANYON := "wm01-066"     # Stage: -1 to the next Bulwark Banner this turn
const BULWARK_3 := "wm01-060"  # Line Infantry, Bulwark, cost 3
const BULWARK_5 := "wm01-062"  # Artillery Captain Wren, Bulwark, cost 5
const BULWARK_2 := "wm01-058"  # Idris cadet, Bulwark, cost 2
const OFF_TRIBE := "wm01-005"  # Denji, Redgale, cost 3

func _vale_and_canyon() -> GameEngine:
	var g := Scenario.fresh_with_vanguards(VALE, VALE)
	Scenario.set_stage(g, 0, CANYON)
	Scenario.set_aura(g, 0, 10, 0)
	g.activate_main(g.state.players[0].stage)  # adds Canyon's charge
	return g

func test_vale_passive_alone_reduces_by_one():
	var g := Scenario.fresh_with_vanguards(VALE, VALE)
	var banner: CardInstance = Scenario.hand_card(g, 0, BULWARK_3)
	assert_eq(g._effective_play_cost(0, banner), 2, "Vale passive: 3 -> 2")

func test_vale_and_canyon_stack_to_minus_two():
	var g := _vale_and_canyon()
	var banner: CardInstance = Scenario.hand_card(g, 0, BULWARK_5)
	assert_eq(g._effective_play_cost(0, banner), 3, "5 - 2 = 3")

func test_reduction_never_below_one():
	var g := _vale_and_canyon()
	var cheap: CardInstance = Scenario.hand_card(g, 0, BULWARK_2)
	assert_eq(g._effective_play_cost(0, cheap), 1, "2 - 2 floored at 1")

func test_reduction_only_applies_to_matching_tribe():
	var g := _vale_and_canyon()
	var off: CardInstance = Scenario.hand_card(g, 0, OFF_TRIBE)
	assert_eq(g._effective_play_cost(0, off), 3, "no discount for non-Bulwark")

func test_charges_consumed_after_a_banner_play():
	var g := _vale_and_canyon()
	var first: CardInstance = Scenario.hand_card(g, 0, BULWARK_3)
	assert_eq(g._effective_play_cost(0, first), 1)
	assert_true(g.play_card(0, first))
	var second: CardInstance = Scenario.hand_card(g, 0, BULWARK_3)
	assert_eq(g._effective_play_cost(0, second), 3, "charges spent -> full price")
