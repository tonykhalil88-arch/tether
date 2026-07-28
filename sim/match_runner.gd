class_name MatchRunner
extends RefCounted

## Drives complete AI-vs-AI games using GameEngine + AIPolicy. Pure logic and
## deterministic given a seed, so both the CLI simulator (sim/run.gd) and the
## GUT tests share it.

const MAX_TURNS := 300  # safety cap so a pathological game still terminates


## Play one full game. Returns a structured result Dictionary including the
## engine's game log.
static func play_game(seed_value: int, style_a: String, style_b: String, first: int) -> Dictionary:
	var g := GameEngine.new(seed_value)
	var vg: CardData = DeckFactory.vanguard()
	g.setup(DeckFactory.build_deck(50), vg, DeckFactory.build_deck(50), vg, first)

	var policies := [AIPolicy.new(style_a), AIPolicy.new(style_b)]

	# Mulligan decisions before Life is set.
	for p in range(2):
		if policies[p].want_mulligan(g, p):
			g.mulligan(p)

	g.start_game()

	var capped := false
	while not g.state.game_over:
		if g.state.turn_number >= MAX_TURNS:
			capped = true
			break
		var active := g.begin_turn()
		if active < 0:
			break
		var pol: AIPolicy = policies[active]
		pol.do_main_phase(g, active)
		_run_attacks(g, active, policies)
		if g.state.game_over:
			break
		g.end_turn()

	return {
		"seed": seed_value,
		"first_player": first,
		"styles": [style_a, style_b],
		"winner": g.state.winner,
		"turns": g.state.turn_number,
		"capped": capped,
		"final_life": [g.state.players[0].life.size(), g.state.players[1].life.size()],
		"log": g.state.log,
	}


static func _run_attacks(g: GameEngine, active: int, policies: Array) -> void:
	var pol: AIPolicy = policies[active]
	var opp := g.state.opponent_of(active)
	var guard := 0
	while not g.state.game_over:
		guard += 1
		if guard > 64:  # defensive: never loop forever within one turn
			break
		var attacker: CardInstance = pol.choose_attacker(g, active)
		if attacker == null:
			break
		var target: CardInstance = pol.choose_target(g, active, attacker)
		var atk_choices: Dictionary = pol.attacker_choices(g, active, attacker, target)
		var def_choices: Dictionary = policies[opp].defender_choices(g, opp, attacker, target)
		g.declare_attack(attacker, target, atk_choices, def_choices)


## Run a batch of `n` games alternating first player and match-ups. Returns an
## aggregate report with per-game results.
static func run_batch(n: int, base_seed: int, style_a: String = "aggro", style_b: String = "guard") -> Dictionary:
	var results: Array = []
	var wins := { "0": 0, "1": 0, "draw": 0 }
	var style_wins := {}
	for i in range(n):
		var first := i % 2
		# Alternate which seat plays which style so neither seat/style is fixed.
		var sa := style_a if i % 2 == 0 else style_b
		var sb := style_b if i % 2 == 0 else style_a
		var r := play_game(base_seed + i, sa, sb, first)
		results.append(r)
		var w: int = r["winner"]
		if w < 0:
			wins["draw"] += 1
		else:
			wins[str(w)] += 1
			var winning_style: String = r["styles"][w]
			style_wins[winning_style] = int(style_wins.get(winning_style, 0)) + 1
	return {
		"games": n,
		"base_seed": base_seed,
		"wins_by_seat": wins,
		"wins_by_style": style_wins,
		"results": results,
	}
