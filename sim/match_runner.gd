class_name MatchRunner
extends RefCounted

## Drives complete AI-vs-AI games. Policies are chosen automatically from each
## Vanguard id (archetype-aware), so every kit is piloted toward its gameplan.
## Deterministic given a seed.

const MAX_TURNS := 300

const WATCH_KEYS := [
	"sora_rush_grants", "verdigris_double_rest", "korgan_repeat_attacks",
	"stampede_multi_refresh", "averil_cards_seen", "rue_aura_frozen",
]


## Play one full game between two Vanguards (deck A in seat 0, deck B in seat 1).
## `first` is the first player's seat. `keep_log` controls whether the (large)
## per-turn game log is returned — the matrix run sets it false to save memory.
static func play_game(seed_value: int, vg_a: String, vg_b: String, first: int,
		keep_log: bool = true) -> Dictionary:
	var g := GameEngine.new(seed_value)
	var kit := DeckFactory.load_kit()
	var van_a: CardData = kit[vg_a]
	var van_b: CardData = kit[vg_b]
	g.setup(DeckFactory.deck_for(van_a), van_a, DeckFactory.deck_for(van_b), van_b, first)

	var policies := [AIPolicy.for_vanguard(vg_a), AIPolicy.for_vanguard(vg_b)]
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
		policies[active].play_turn(g, active, policies[g.state.opponent_of(active)])
		if g.state.game_over:
			break
		g.end_turn()

	var result := {
		"seed": seed_value,
		"first_player": first,
		"vanguards": [vg_a, vg_b],
		"archetypes": [policies[0].archetype, policies[1].archetype],
		"winner": g.state.winner,
		"turns": g.state.turn_number,
		"capped": capped,
		"final_life": [g.state.players[0].life.size(), g.state.players[1].life.size()],
		"watch": g.state.watch.duplicate(),
	}
	if keep_log:
		result["log"] = g.state.log
	return result


## Play `games` games of one ordered matchup (A vs B), alternating the first
## player evenly. Returns an aggregate (no per-game logs kept).
static func run_matchup(vg_a: String, vg_b: String, games: int, base_seed: int) -> Dictionary:
	var agg := {
		"a": vg_a, "b": vg_b, "games": games,
		"a_wins": 0, "b_wins": 0, "draws": 0,
		"first_player_wins": 0, "total_turns": 0,
		"watch": _zero_watch(),
	}
	for i in range(games):
		var first := i % 2  # 25/25 split over an even count
		var r := play_game(base_seed + i, vg_a, vg_b, first, false)
		agg["total_turns"] += int(r["turns"])
		var w: int = r["winner"]
		if w < 0:
			agg["draws"] += 1
		elif w == 0:
			agg["a_wins"] += 1
		else:
			agg["b_wins"] += 1
		if w == first:
			agg["first_player_wins"] += 1
		for k in WATCH_KEYS:
			agg["watch"][k] += int(r["watch"].get(k, 0))
	return agg


## Legacy rotating batch used by the sim smoke test — auto-policies, no styles.
static func run_batch(n: int, base_seed: int) -> Dictionary:
	var vgs := vanguard_ids()
	var results: Array = []
	var wins := { "0": 0, "1": 0, "draw": 0 }
	var watch_totals := _zero_watch()
	for i in range(n):
		var first := i % 2
		var va: String = vgs[i % vgs.size()]
		var vb: String = vgs[(i + 1 + i / vgs.size()) % vgs.size()]
		var r := play_game(base_seed + i, va, vb, first, true)
		results.append(r)
		var w: int = r["winner"]
		if w < 0:
			wins["draw"] += 1
		else:
			wins[str(w)] += 1
		for k in WATCH_KEYS:
			watch_totals[k] += int(r["watch"].get(k, 0))
	return {
		"games": n, "base_seed": base_seed,
		"wins_by_seat": wins, "watch_totals": watch_totals, "results": results,
	}


static func vanguard_ids() -> Array:
	var ids: Array = []
	for v in DeckFactory.vanguards():
		ids.append(v.id)
	ids.sort()
	return ids


static func _zero_watch() -> Dictionary:
	var d := {}
	for k in WATCH_KEYS:
		d[k] = 0
	return d
