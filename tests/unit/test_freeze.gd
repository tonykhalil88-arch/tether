extends GutTest

## Freeze: persists exactly one Refresh Phase; Banner-freeze capped at 1 per
## turn; Aura freeze uncapped and reduces spendable Aura next turn.

const B := "wm01-005"   # Denji, no effects

func test_freeze_skips_exactly_one_refresh():
	var g := Scenario.fresh()  # P0's turn
	var b: CardInstance = Scenario.spawn_banner(g, 1, B, true)  # P1 banner, rested
	assert_true(g.freeze_banner(b, 0), "P0 freezes P1's banner")
	assert_true(b.frozen)

	# P1's next turn: the frozen banner is SKIPPED by Refresh and thaws.
	g.end_turn()
	g.begin_turn()  # turn 2, P1
	assert_eq(g.state.active_player, 1)
	assert_true(b.exhausted, "frozen banner did not refresh")
	assert_false(b.frozen, "but the freeze has thawed")

	# P1's following turn: it refreshes normally.
	g.end_turn()
	g.begin_turn()  # P0
	g.end_turn()
	g.begin_turn()  # P1 again
	assert_false(b.exhausted, "refreshes normally the turn after")

func test_banner_freeze_capped_at_one_per_turn():
	var g := Scenario.fresh()
	var b1: CardInstance = Scenario.spawn_banner(g, 1, B, true)
	var b2: CardInstance = Scenario.spawn_banner(g, 1, B, true)
	assert_true(g.freeze_banner(b1, 0), "first Banner freeze applies")
	assert_false(g.freeze_banner(b2, 0), "second Banner freeze blocked by the cap")
	assert_true(b1.frozen)
	assert_false(b2.frozen)

func test_aura_freeze_is_uncapped():
	var g := Scenario.fresh()
	g.state.players[1].aura_total = 10
	var a := g.freeze_aura(1, 3)
	var b := g.freeze_aura(1, 4)
	assert_eq(a, 3)
	assert_eq(b, 4)
	assert_eq(g.state.players[1].aura_frozen_pending, 7, "aura freezes stack, no cap")

func test_frozen_aura_reduces_spendable_next_turn_directly():
	var ps := PlayerState.new(1)
	ps.gain_aura(5)
	ps.aura_frozen_pending = 2
	ps.refresh_aura()
	assert_eq(ps.aura_available(), 3, "5 total - 2 frozen = 3 spendable")
	assert_eq(ps.aura_frozen_pending, 0, "freeze consumed after one Refresh")

func test_frozen_aura_reduces_spendable_through_begin_turn():
	var g := Scenario.fresh()  # P0's turn
	g.state.players[1].aura_total = 6
	g.freeze_aura(1, 3)        # P0 freezes 3 of P1's Aura
	g.end_turn()
	g.begin_turn()             # P1's turn: refresh applies the freeze, then +2 gain
	# total = min(10, 6+2) = 8, exhausted = 3 frozen -> available = 5
	assert_eq(g.state.players[1].aura_available(), 5, "3 frozen Aura unavailable this turn")
