extends GutTest

## Aura economy: gain, spend, refresh, and the active cap of 10.

func test_gain_and_available():
	var ps := PlayerState.new(0)
	ps.gain_aura(3)
	assert_eq(ps.aura_total, 3)
	assert_eq(ps.aura_available(), 3)

func test_spend_reduces_available_not_total():
	var ps := PlayerState.new(0)
	ps.gain_aura(5)
	assert_true(ps.spend_aura(2))
	assert_eq(ps.aura_available(), 3)
	assert_eq(ps.aura_total, 5, "total pool unchanged")

func test_cannot_overspend():
	var ps := PlayerState.new(0)
	ps.gain_aura(2)
	assert_false(ps.spend_aura(3))
	assert_eq(ps.aura_available(), 2, "unchanged on failed spend")

func test_refresh_restores_all_aura():
	var ps := PlayerState.new(0)
	ps.gain_aura(6)
	ps.spend_aura(4)
	ps.refresh_aura()
	assert_eq(ps.aura_available(), 6)

func test_active_aura_capped_at_ten():
	var ps := PlayerState.new(0)
	for i in range(8):
		ps.gain_aura(2)  # 16 uncapped
	assert_eq(ps.aura_total, 10, "capped at 10")

func test_playing_a_banner_exhausts_aura_equal_to_cost():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var banner: CardInstance = Scenario.hand_card(g, 0, "wm01-005")  # Denji, cost 3
	assert_true(g.play_card(0, banner))
	assert_eq(g.state.players[0].aura_available(), 2, "5 - 3 = 2 available")

func test_attach_aura_gives_plus_1000_and_exhausts_one():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 4, 0)
	var b: CardInstance = Scenario.spawn_banner(g, 0, "wm01-036")  # Neza, power 3000
	assert_true(g.attach_aura(0, b))
	assert_eq(b.current_power(), 4000, "+1000 attached")
	assert_eq(g.state.players[0].aura_available(), 3)
