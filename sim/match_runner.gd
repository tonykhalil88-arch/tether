class_name MatchRunner
extends RefCounted

## Drives complete AI-vs-AI games using GameEngine + AIPolicy. Deterministic
## given a seed; shared by the CLI simulator and the GUT tests.

const MAX_TURNS := 300

# Watch-list keys surfaced per game and aggregated per batch.
const WATCH_KEYS := [
	"sora_rush_grants", "verdigris_double_rest", "korgan_repeat_attacks",
	"stampede_multi_refresh", "averil_cards_seen", "rue_aura_frozen",
]


## Play one full game between two named Vanguards. Returns a structured result
## including the engine game log and the balance watch-list counters.
static func play_game(seed_value: int, vg_a: String, vg_b: String,
		style_a: String, style_b: String, first: int) -> Dictionary:
	var g := GameEngine.new(seed_value)
	var kit := DeckFactory.load_kit()
	var van_a: CardData = kit[vg_a]
	var van_b: CardData = kit[vg_b]
	g.setup(DeckFactory.deck_for(van_a), van_a, DeckFactory.deck_for(van_b), van_b, first)

	var policies := [AIPolicy.new(style_a), AIPolicy.new(style_b)]
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
		"vanguards": [vg_a, vg_b],
		"styles": [style_a, style_b],
		"winner": g.state.winner,
		"turns": g.state.turn_number,
		"capped": capped,
		"final_life": [g.state.players[0].life.size(), g.state.players[1].life.size()],
		"watch": g.state.watch.duplicate(),
		"log": g.state.log,
	}


static func _run_attacks(g: GameEngine, active: int, policies: Array) -> void:
	var pol: AIPolicy = policies[active]
	var opp := g.state.opponent_of(active)
	var guard := 0
	while not g.state.game_over:
		guard += 1
		if guard > 64:
			break
		var attacker: CardInstance = pol.choose_attacker(g, active)
		if attacker == null:
			break
		var target: CardInstance = pol.choose_target(g, active, attacker)
		var atk_choices: Dictionary = pol.attacker_choices(g, active, attacker, target)
		var def_choices: Dictionary = policies[opp].defender_choices(g, opp, attacker, target)
		g.declare_attack(attacker, target, atk_choices, def_choices)


## Run `n` games, rotating through every Vanguard match-up and alternating the
## first player. Returns an aggregate report with per-game results and summed
## watch-list flags.
static func run_batch(n: int, base_seed: int, style_a: String = "aggro", style_b: String = "guard") -> Dictionary:
	var vgs := _vanguard_ids()
	var results: Array = []
	var wins := { "0": 0, "1": 0, "draw": 0 }
	var style_wins := {}
	var watch_totals := {}
	for k in WATCH_KEYS:
		watch_totals[k] = 0

	for i in range(n):
		var first := i % 2
		var va: String = vgs[i % vgs.size()]
		var vb: String = vgs[(i + 1 + i / vgs.size()) % vgs.size()]
		var sa := style_a if i % 2 == 0 else style_b
		var sb := style_b if i % 2 == 0 else style_a
		var r := play_game(base_seed + i, va, vb, sa, sb, first)
		results.append(r)
		var w: int = r["winner"]
		if w < 0:
			wins["draw"] += 1
		else:
			wins[str(w)] += 1
			var winning_style: String = r["styles"][w]
			style_wins[winning_style] = int(style_wins.get(winning_style, 0)) + 1
		for k in WATCH_KEYS:
			watch_totals[k] += int(r["watch"].get(k, 0))

	return {
		"games": n,
		"base_seed": base_seed,
		"wins_by_seat": wins,
		"wins_by_style": style_wins,
		"watch_totals": watch_totals,
		"results": results,
	}


static func _vanguard_ids() -> Array:
	var ids: Array = []
	for v in DeckFactory.vanguards():
		ids.append(v.id)
	ids.sort()
	return ids
