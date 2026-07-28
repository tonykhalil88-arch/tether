extends SceneTree

## Balance harness: runs the full 8x8 Vanguard matchup matrix with the
## archetype-aware pilots and writes balance_report.json + balance_report.md.
##
## Usage:
##   godot --headless -s sim/balance.gd -- [--games=50] [--seed=1] [--out=DIR]
##
## Defaults: 50 games per ordered matchup (25/25 first player) x 64 = 3200 games.

const MATCHUP_LO := 0.35
const MATCHUP_HI := 0.65
const VG_LO := 0.45
const VG_HI := 0.55

func _init() -> void:
	var opts := _parse_args()
	var games := int(opts.get("games", 50))
	var seed_value := int(opts.get("seed", 1))
	var out_dir := str(opts.get("out", ProjectSettings.globalize_path("res://")))

	var vgs: Array = MatchRunner.vanguard_ids()
	var total_games := games * vgs.size() * vgs.size()
	print("WILDMIGRATION balance matrix — %d matchups x %d games = %d games (seed %d)" % [
		vgs.size() * vgs.size(), games, total_games, seed_value])

	# Run every ordered matchup with a distinct, reproducible seed block.
	var matchups := {}
	for ai in range(vgs.size()):
		var a: String = vgs[ai]
		matchups[a] = {}
		for bi in range(vgs.size()):
			var b: String = vgs[bi]
			var block_seed := seed_value + (ai * vgs.size() + bi) * games
			matchups[a][b] = MatchRunner.run_matchup(a, b, games, block_seed)
		print("  row %d/%d done (%s)" % [ai + 1, vgs.size(), a])

	var report := _build_report(vgs, matchups, games, seed_value, total_games)

	var json_path := out_dir.path_join("balance_report.json")
	var md_path := out_dir.path_join("balance_report.md")
	_write(json_path, JSON.stringify(report, "  "))
	_write(md_path, _render_markdown(report))
	print("Wrote %s" % json_path)
	print("Wrote %s" % md_path)
	print("REVIEW: %d matchup(s), %d vanguard(s) outside tolerance." % [
		report["review"]["matchups"].size(), report["review"]["vanguards"].size()])
	quit(0)


# =========================================================================
# Aggregation
# =========================================================================

func _build_report(vgs: Array, matchups: Dictionary, games: int, seed_value: int, total_games: int) -> Dictionary:
	var matrix := {}
	var per_vg := {}
	var watch_per_matchup := {}
	var first_wins_total := 0

	for v in vgs:
		per_vg[v] = { "wins": 0, "games": 0, "turns": 0, "metrics": GameState._new_metrics() }

	for a in vgs:
		matrix[a] = {}
		for b in vgs:
			var m: Dictionary = matchups[a][b]
			matrix[a][b] = _rate(m["a_wins"], games)
			first_wins_total += int(m["first_player_wins"])
			# Per-vanguard aggregation (A gets a_wins, B gets b_wins).
			per_vg[a]["wins"] += int(m["a_wins"])
			per_vg[a]["games"] += games
			per_vg[a]["turns"] += int(m["total_turns"])
			_add_metrics(per_vg[a]["metrics"], m["metrics_a"])
			per_vg[b]["wins"] += int(m["b_wins"])
			per_vg[b]["games"] += games
			per_vg[b]["turns"] += int(m["total_turns"])
			_add_metrics(per_vg[b]["metrics"], m["metrics_b"])
			# Watch-list normalised per game.
			var wn := {}
			for k in MatchRunner.WATCH_KEYS:
				wn[k] = _rate(int(m["watch"][k]), games)
			watch_per_matchup["%s_vs_%s" % [a, b]] = wn

	var per_vanguard := {}
	var review_vgs: Array = []
	for v in vgs:
		var wr := _rate(per_vg[v]["wins"], per_vg[v]["games"])
		var avg_turns := _rate(per_vg[v]["turns"], per_vg[v]["games"])
		var mv: Dictionary = per_vg[v]["metrics"]
		var atk: int = mv["attacks"]
		per_vanguard[v] = {
			"archetype": AIPolicy.ARCHETYPE_BY_VANGUARD.get(v, "?"),
			"win_rate": wr,
			"avg_game_length": avg_turns,
			"games": per_vg[v]["games"],
			"connect_rate": _rate(mv["connects"], atk),
			"counters_per_life_lost": _rate(mv["counter_cards_spent"], max(1, int(mv["life_lost"]))),
			"avg_attacker_power": _rate(mv["atk_power_sum"], atk),
			"avg_defender_power": _rate(mv["def_power_sum"], atk),
		}
		if wr < VG_LO or wr > VG_HI:
			review_vgs.append({ "vanguard": v, "win_rate": wr })

	# First-player win rate: overall and per matchup.
	var fp_per_matchup := {}
	for a in vgs:
		for b in vgs:
			fp_per_matchup["%s_vs_%s" % [a, b]] = _rate(int(matchups[a][b]["first_player_wins"]), games)

	# REVIEW matchups: any matrix cell outside [35%, 65%].
	var review_matchups: Array = []
	for a in vgs:
		for b in vgs:
			var cell: float = matrix[a][b]
			if cell < MATCHUP_LO or cell > MATCHUP_HI:
				review_matchups.append({ "a": a, "b": b, "a_win_rate": cell })

	return {
		"config": {
			"games_per_matchup": games,
			"seed": seed_value,
			"total_games": total_games,
			"matchup_tolerance": [MATCHUP_LO, MATCHUP_HI],
			"vanguard_tolerance": [VG_LO, VG_HI],
		},
		"vanguards": vgs,
		"decklists": _decklists(vgs),
		"matrix": matrix,
		"per_vanguard": per_vanguard,
		"first_player": {
			"overall_win_rate": _rate(first_wins_total, total_games),
			"per_matchup": fp_per_matchup,
		},
		"watch_per_game_by_matchup": watch_per_matchup,
		"review": { "matchups": review_matchups, "vanguards": review_vgs },
	}


func _decklists(vgs: Array) -> Dictionary:
	var kit := DeckFactory.load_kit()
	var out := {}
	for v in vgs:
		var deck := DeckFactory.deck_for(kit[v])
		var counts := {}
		for c in deck:
			counts[c.id] = int(counts.get(c.id, 0)) + 1
		out[v] = {
			"vanguard": kit[v].name,
			"kit_cards": DeckFactory.kit_ids(kit[v]),
			"filler_cards": DeckFactory.filler_ids_for(kit[v]).slice(0, 3),
			"counts": counts,
			"deck_size": deck.size(),
		}
	return out


# =========================================================================
# Markdown
# =========================================================================

func _render_markdown(report: Dictionary) -> String:
	var vgs: Array = report["vanguards"]
	var s := "# WILDMIGRATION — Set 1 Balance Report\n\n"
	var cfg: Dictionary = report["config"]
	s += "Archetype-aware pilots, pure-kit decks. **%d** games per ordered matchup " % cfg["games_per_matchup"]
	s += "(first player split evenly), **%d** total games, base seed **%d**.\n\n" % [cfg["total_games"], cfg["seed"]]
	s += "Tolerances: matchup %d–%d%%, per-Vanguard overall %d–%d%%. " % [
		int(cfg["matchup_tolerance"][0] * 100), int(cfg["matchup_tolerance"][1] * 100),
		int(cfg["vanguard_tolerance"][0] * 100), int(cfg["vanguard_tolerance"][1] * 100)]
	s += "Cells/rows outside tolerance are flagged **REVIEW**.\n\n"

	# Win-rate matrix.
	s += "## Win-rate matrix (row = Player A's Vanguard, cell = A's win rate vs column B)\n\n"
	s += "| A \\ B |"
	for b in vgs:
		s += " %s |" % _short(b)
	s += "\n|---|" + "---|".repeat(vgs.size()) + "\n"
	for a in vgs:
		s += "| **%s** |" % _short(a)
		for b in vgs:
			var cell: float = report["matrix"][a][b]
			var mark := "" if (cell >= MATCHUP_LO and cell <= MATCHUP_HI) else "⚠"
			s += " %d%%%s |" % [round(cell * 100), mark]
		s += "\n"
	s += "\n"

	# Per-vanguard.
	s += "## Per-Vanguard overall\n\n"
	s += "| Vanguard | Archetype | Overall win rate | Avg game length (turns) |\n|---|---|---|---|\n"
	for v in vgs:
		var pv: Dictionary = report["per_vanguard"][v]
		var flag := "" if (pv["win_rate"] >= VG_LO and pv["win_rate"] <= VG_HI) else " **REVIEW**"
		s += "| %s | %s | %d%%%s | %.1f |\n" % [
			_short(v), pv["archetype"], round(pv["win_rate"] * 100), flag, pv["avg_game_length"]]
	s += "\n"

	# Defence economy.
	s += "## Defence economy (per Vanguard)\n\n"
	s += "Connect rate = attacks that won / attacks declared. A low connect rate "
	s += "with avg attacker power well under avg defender power means small bodies "
	s += "bouncing off big Vanguards.\n\n"
	s += "| Vanguard | Connect rate | Counters / Life lost | Avg attacker pow | Avg defender pow |\n"
	s += "|---|---|---|---|---|\n"
	for v in vgs:
		var pv2: Dictionary = report["per_vanguard"][v]
		s += "| %s | %d%% | %.2f | %.0f | %.0f |\n" % [
			_short(v), round(pv2["connect_rate"] * 100), pv2["counters_per_life_lost"],
			pv2["avg_attacker_power"], pv2["avg_defender_power"]]
	s += "\n"

	# First player.
	s += "## First-player advantage\n\n"
	s += "Overall first-player win rate: **%d%%**.\n\n" % round(report["first_player"]["overall_win_rate"] * 100)

	# Watch-list (per game, averaged across all matchups for a compact view).
	s += "## Balance watch-list (resolutions per game, set-wide average)\n\n"
	var watch_avg := _average_watch(report)
	s += "| Flag | Per game |\n|---|---|\n"
	for k in MatchRunner.WATCH_KEYS:
		s += "| %s | %.3f |\n" % [k, watch_avg[k]]
	s += "\nPer-matchup watch normals are in `balance_report.json` "
	s += "(`watch_per_game_by_matchup`).\n\n"

	# Review.
	s += "## REVIEW items\n\n"
	var rv: Array = report["review"]["vanguards"]
	var rm: Array = report["review"]["matchups"]
	if rv.is_empty() and rm.is_empty():
		s += "None — every Vanguard is 45–55% overall and every matchup is 35–65%.\n\n"
	else:
		if not rv.is_empty():
			s += "**Vanguards outside 45–55%:**\n\n"
			for e in rv:
				s += "- %s: %d%%\n" % [_short(e["vanguard"]), round(e["win_rate"] * 100)]
			s += "\n"
		if not rm.is_empty():
			s += "**Matchups outside 35–65% (A's win rate vs B):**\n\n"
			for e in rm:
				s += "- %s vs %s: %d%%\n" % [_short(e["a"]), _short(e["b"]), round(e["a_win_rate"] * 100)]
			s += "\n"

	# Decklists.
	s += "## Decklists (reproducible)\n\n"
	s += "Each deck is **kit ×4 (40)** — the Vanguard's ten non-Vanguard cards, "
	s += "4 copies each — **plus 10 filler** from colour-legal neighbour kits "
	s += "(4/4/2 of the top-ranked picks). All decks are 50 cards, ≤4 copies, "
	s += "colour-legal.\n\n"
	for v in vgs:
		var dl: Dictionary = report["decklists"][v]
		s += "- **%s** (%s): kit %s ×4 + filler %s\n" % [
			dl["vanguard"], _short(v), ", ".join(dl["kit_cards"]), ", ".join(dl["filler_cards"])]
	s += "\n"
	return s


func _average_watch(report: Dictionary) -> Dictionary:
	var out := {}
	for k in MatchRunner.WATCH_KEYS:
		out[k] = 0.0
	var m: Dictionary = report["watch_per_game_by_matchup"]
	for key in m:
		for k in MatchRunner.WATCH_KEYS:
			out[k] += float(m[key][k])
	var n: int = m.size()
	if n > 0:
		for k in MatchRunner.WATCH_KEYS:
			out[k] /= n
	return out


func _short(vg_id: String) -> String:
	return "%s(%s)" % [vg_id.trim_prefix("wm01-"), AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg_id, "?")]


# =========================================================================
# Utilities
# =========================================================================

func _rate(num, den) -> float:
	return 0.0 if int(den) == 0 else float(num) / float(den)


func _add_metrics(acc: Dictionary, m: Dictionary) -> void:
	for k in m:
		acc[k] += int(m[k])


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
		push_error("balance.gd: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
