extends GutTest

## Win condition: a Vanguard hit while the defender has 0 Life ends the game.

func test_hit_with_zero_life_ends_game():
	var g := Scenario.fresh()
	Scenario.set_life(g, 1, 0)
	assert_eq(g.state.players[1].life.size(), 0, "defender at 0 Life")
	var r := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_true(r["attacker_wins"], "attack connects")
	assert_true(r["game_over"], "game ends")
	assert_eq(g.state.winner, 0, "attacker wins")

func test_last_life_then_lethal():
	var g := Scenario.fresh()
	Scenario.set_life(g, 1, 1)
	# First hit removes the last Life (to hand); not yet lethal.
	var r1 := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_false(r1["game_over"], "still alive at 0 Life")
	assert_eq(g.state.players[1].life.size(), 0)
	# Refresh the attacker for a second swing.
	g.state.players[0].vanguard.refresh()
	var r2 := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_true(r2["game_over"], "hit at 0 Life is lethal")
	assert_eq(g.state.winner, 0)

func test_no_further_actions_after_game_over():
	var g := Scenario.fresh()
	Scenario.set_life(g, 1, 0)
	g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_true(g.state.game_over)
	# Attacks and plays are refused once the game is over.
	g.state.players[0].vanguard.refresh()
	var r := g.declare_attack(g.state.players[0].vanguard, g.state.players[1].vanguard)
	assert_false(r["ok"], "no attacks after game over")
