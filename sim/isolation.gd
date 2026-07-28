extends SceneTree

## Isolation pass: run the full 8x8 matrix under one ablation/control scenario
## (writing a partial JSON), then consolidate the partials into
## isolation_report.md. Scenarios share the baseline seed blocks so deltas are
## apples-to-apples.
##
## Usage:
##   godot --headless -s sim/isolation.gd -- --scenario=A0 --games=50 --seed=1 --out=DIR
##   ... (repeat for A1..A5, C0) ...
##   godot --headless -s sim/isolation.gd -- --consolidate --out=DIR

const SCENARIOS := {
	"A0": { "label": "new-rules baseline (nothing disabled)", "ablations": {}, "shared": "" },
	"A1": { "label": "Sora Vanguard Rush rider disabled", "ablations": { "sora_no_rush_rider": true }, "shared": "" },
	"A2": { "label": "Total Mobilisation blanked", "ablations": { "blank_total_mobilisation": true }, "shared": "" },
	"A3": { "label": "Vale discount Vanguard-only (Canyon disabled)", "ablations": { "canyon_no_discount": true }, "shared": "" },
	"A4": { "label": "Verdigris rests 1 instead of 2", "ablations": { "verdigris_rest_1": true }, "shared": "" },
	"A5": { "label": "Korgan self-refresh disabled", "ablations": { "korgan_no_refresh": true }, "shared": "" },
	"C0": { "label": "pilot-skill control (shared generic pilot)", "ablations": {}, "shared": "generic" },
}

# Which Vanguard's kit contains each ablation's suspect card.
const SUSPECT_OWNER := {
	"A1": "wm01-001", "A2": "wm01-078", "A3": "wm01-056", "A4": "wm01-012", "A5": "wm01-023",
}
const ABLATIONS := ["A1", "A2", "A3", "A4", "A5"]
const REAL_THRESHOLD := 5.0   # percentage points
const ACQUIT_THRESHOLD := 2.0


func _init() -> void:
	var opts := _parse_args()
	var out_dir := str(opts.get("out", ProjectSettings.globalize_path("res://")))
	if opts.has("consolidate"):
		_consolidate(out_dir)
	else:
		_run_scenario(str(opts.get("scenario", "A0")), int(opts.get("games", 50)),
			int(opts.get("seed", 1)), out_dir)
	quit(0)


# =========================================================================
# One scenario
# =========================================================================

func _run_scenario(scenario: String, games: int, seed_value: int, out_dir: String) -> void:
	if not SCENARIOS.has(scenario):
		push_error("isolation: unknown scenario '%s'" % scenario)
		return
	var cfg: Dictionary = SCENARIOS[scenario]
	print("Isolation %s — %s (%d games/matchup, seed %d)" % [
		scenario, cfg["label"], games, seed_value])

	var matrix := MatchRunner.run_matrix(games, seed_value, cfg["ablations"], cfg["shared"])
	var vgs: Array = matrix["vanguards"]
	var per_vg := {}
	for v in vgs:
		per_vg[v] = _vg_stats(matrix["per_vanguard"][v], v)

	var partial := {
		"scenario": scenario,
		"label": cfg["label"],
		"games_per_matchup": games,
		"seed": seed_value,
		"total_games": matrix["total_games"],
		"first_player_win_rate": _rate(matrix["first_player_wins"], matrix["total_games"]),
		"per_vanguard": per_vg,
	}
	var path := out_dir.path_join("iso_%s.json" % scenario)
	_write(path, JSON.stringify(partial, "  "))
	print("Wrote %s" % path)


func _vg_stats(agg: Dictionary, vg: String) -> Dictionary:
	var m: Dictionary = agg["metrics"]
	var attacks: int = m["attacks"]
	return {
		"archetype": AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg, "?"),
		"win_rate": _rate(agg["wins"], agg["games"]),
		"avg_game_length": _rate(agg["turns"], agg["games"]),
		"connect_rate": _rate(m["connects"], attacks),
		"counters_per_life_lost": _rate(m["counter_cards_spent"], max(1, int(m["life_lost"]))),
		"avg_attacker_power": _rate(m["atk_power_sum"], attacks),
		"avg_defender_power": _rate(m["def_power_sum"], attacks),
	}


# =========================================================================
# Consolidation
# =========================================================================

func _consolidate(out_dir: String) -> void:
	var data := {}
	for s in SCENARIOS:
		var p := out_dir.path_join("iso_%s.json" % s)
		if not FileAccess.file_exists(p):
			push_error("isolation: missing partial %s — run scenario %s first" % [p, s])
			return
		data[s] = JSON.parse_string(FileAccess.get_file_as_string(p))

	var a0: Dictionary = data["A0"]
	var vgs: Array = a0["per_vanguard"].keys()
	vgs.sort()

	var md := _render(data, a0, vgs)
	_write(out_dir.path_join("isolation_report.md"), md)
	_write(out_dir.path_join("isolation_report.json"), JSON.stringify({
		"scenarios": data, "consolidated_at_seed": a0["seed"],
	}, "  "))
	print("Wrote %s" % out_dir.path_join("isolation_report.md"))


func _render(data: Dictionary, a0: Dictionary, vgs: Array) -> String:
	var s := "# WILDMIGRATION — Isolation Pass (Ablations + Control)\n\n"
	s += "Separates card power from pilot skill under the real deckbuilding rules "
	s += "(50 + 1 Vanguard, max 4 copies, colour-legal). Every scenario runs the full "
	s += "8×8 matrix (%d games/matchup, %d games) on the same seed blocks as A0.\n\n" % [
		a0["games_per_matchup"], a0["total_games"]]

	# --- Baseline win rates ---
	s += "## A0 — new-rules baseline\n\n"
	s += "| Vanguard | Archetype | Win rate | Avg length |\n|---|---|---|---|\n"
	for v in vgs:
		var pv: Dictionary = a0["per_vanguard"][v]
		s += "| %s | %s | %s | %.1f |\n" % [
			_short(v), pv["archetype"], _pct(pv["win_rate"]), pv["avg_game_length"]]
	s += "\nFirst-player win rate (A0): **%s**.\n\n" % _pct(a0["first_player_win_rate"])

	# --- Ablation deltas ---
	s += "## Ablation deltas vs A0 (percentage points)\n\n"
	s += "Row = scenario, column = Vanguard. `REAL` if the suspect's owner shifts "
	s += ">%d pts; `acquit` if <%d pts.\n\n" % [int(REAL_THRESHOLD), int(ACQUIT_THRESHOLD)]
	s += "| Scenario |"
	for v in vgs:
		s += " %s |" % _short(v)
	s += " Verdict |\n|---|" + "---|".repeat(vgs.size() + 1) + "\n"
	for scn in ABLATIONS:
		var sc: Dictionary = data[scn]
		s += "| %s |" % scn
		for v in vgs:
			var d: float = _delta(sc, a0, v)
			var is_owner: bool = str(SUSPECT_OWNER[scn]) == str(v)
			var cell := "%+.0f" % d
			if is_owner:
				cell = "**%+.0f**" % d
			s += " %s |" % cell
		s += " %s |\n" % _verdict(sc, a0, SUSPECT_OWNER[scn])
	s += "\n_Bold cell = the ablated card's own Vanguard (the suspect)._\n\n"
	s += "Scenario legend: " + ", ".join(ABLATIONS.map(func(x): return "%s = %s" % [x, data[x]["label"]])) + ".\n\n"

	# --- C0 control ---
	s += "## C0 — pilot-skill control (shared generic pilot)\n\n"
	s += "Gap that persists under one shared pilot = **cards**; gap that collapses "
	s += "toward 50% = **pilot skill**.\n\n"
	s += "| Vanguard | A0 (archetype) | C0 (generic) | Shift | Reading |\n|---|---|---|---|---|\n"
	var c0: Dictionary = data["C0"]
	for v in vgs:
		var a0wr: float = a0["per_vanguard"][v]["win_rate"]
		var c0wr: float = c0["per_vanguard"][v]["win_rate"]
		s += "| %s | %s | %s | %+.0f | %s |\n" % [
			_short(v), _pct(a0wr), _pct(c0wr), (c0wr - a0wr) * 100.0, _reading(a0wr, c0wr)]
	s += "\n"

	# --- Defence economy ---
	s += "## Defence economy (A0, per Vanguard)\n\n"
	s += "Connect rate = attacks that won / attacks declared. Low connect + low "
	s += "attacker-vs-defender power = small bodies bouncing off big Vanguards.\n\n"
	s += "| Vanguard | Connect rate | Counters / Life lost | Avg attacker pow | Avg defender pow |\n"
	s += "|---|---|---|---|---|\n"
	for v in vgs:
		var pv: Dictionary = a0["per_vanguard"][v]
		s += "| %s | %s | %.2f | %.0f | %.0f |\n" % [
			_short(v), _pct(pv["connect_rate"]), pv["counters_per_life_lost"],
			pv["avg_attacker_power"], pv["avg_defender_power"]]
	s += "\n"
	return s


func _delta(scn: Dictionary, a0: Dictionary, v: String) -> float:
	return (float(scn["per_vanguard"][v]["win_rate"]) - float(a0["per_vanguard"][v]["win_rate"])) * 100.0


func _verdict(scn: Dictionary, a0: Dictionary, owner: String) -> String:
	var d: float = abs(_delta(scn, a0, owner))
	if d > REAL_THRESHOLD:
		return "REAL (%s %+.0f)" % [_short(owner), _delta(scn, a0, owner)]
	if d < ACQUIT_THRESHOLD:
		return "acquit (%s %+.0f)" % [_short(owner), _delta(scn, a0, owner)]
	return "inconclusive (%s %+.0f)" % [_short(owner), _delta(scn, a0, owner)]


func _reading(a0wr: float, c0wr: float) -> String:
	# Over/under-performance that survives the generic pilot points at cards.
	var a0_dev: float = a0wr - 0.5
	var c0_dev: float = c0wr - 0.5
	if abs(a0_dev) < 0.05:
		return "—"
	if abs(c0_dev) >= abs(a0_dev) * 0.5 and sign(c0_dev) == sign(a0_dev):
		return "cards (persists)"
	return "pilot skill (collapses)"


# =========================================================================
# Utilities
# =========================================================================

func _short(vg_id: String) -> String:
	return "%s(%s)" % [vg_id.trim_prefix("wm01-"), AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg_id, "?")]


func _pct(x) -> String:
	return "%d%%" % round(float(x) * 100.0)


func _rate(num, den) -> float:
	return 0.0 if int(den) == 0 else float(num) / float(den)


func _parse_args() -> Dictionary:
	var opts: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var a: String = arg.trim_prefix("--")
		if a.contains("="):
			var kv := a.split("=", true, 1)
			opts[kv[0]] = kv[1]
		else:
			opts[a] = true
	return opts


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("isolation: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
