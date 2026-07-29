extends SceneTree

## Patch 1.2 revalidation: re-runs the full 8x8 Vanguard matchup matrix under the
## MONO RECOLOUR (only Vanguards are multi-coloured; every Banner/Technique/Stage
## is mono, so colour pools grew to Red 18 / Green 28 / Blue 21 / Purple 25) with
## both the archetype pilots AND the C0 shared-generic-pilot control, on the SAME
## matched-seed protocol as before. Writes revalidation_v12_report.md.
##
## The v1.1 standings are shown for orientation only and marked **VOID** — they
## were measured before the recolour changed which decks exist, so they are not
## comparable. This 1.2 run is the new baseline.
##
##   godot --headless -s sim/revalidation_v12.gd -- [--games=50] [--seed=1] [--out=DIR]

const MATCHUP_LO := 0.35
const MATCHUP_HI := 0.65
const VG_LO := 0.45
const VG_HI := 0.55

# Frozen v1.1 baseline (archetype / C0), for the VOID orientation column only.
const OLD_ARCH := {
	"wm01-001": 0.81, "wm01-012": 0.28, "wm01-023": 0.28, "wm01-034": 0.40,
	"wm01-045": 0.46, "wm01-056": 0.63, "wm01-067": 0.45, "wm01-078": 0.70,
}
const OLD_C0 := {
	"wm01-001": 0.68, "wm01-012": 0.25, "wm01-023": 0.22, "wm01-034": 0.54,
	"wm01-045": 0.69, "wm01-056": 0.56, "wm01-067": 0.54, "wm01-078": 0.52,
}


func _init() -> void:
	var opts := _parse_args()
	var games := int(opts.get("games", 50))
	var seed_value := int(opts.get("seed", 1))
	var out_dir := str(opts.get("out", ProjectSettings.globalize_path("res://")))

	var vgs: Array = MatchRunner.vanguard_ids()
	var total := games * vgs.size() * vgs.size()
	print("Revalidation v1.2 (mono recolour) — %d matchups x %d games x 2 (arch + C0) = %d games, seed %d" % [
		vgs.size() * vgs.size(), games, total * 2, seed_value])

	var arch := {}
	var c0 := {}
	for ai in range(vgs.size()):
		var a: String = vgs[ai]
		arch[a] = {}
		c0[a] = {}
		for bi in range(vgs.size()):
			var b: String = vgs[bi]
			var block := seed_value + (ai * vgs.size() + bi) * games
			arch[a][b] = MatchRunner.run_matchup(a, b, games, block)
			c0[a][b] = MatchRunner.run_matchup(a, b, games, block, {}, "generic")
		print("  row %d/%d done (%s)" % [ai + 1, vgs.size(), a])

	var report := _aggregate(vgs, arch, c0, games, seed_value, total)
	_write(out_dir.path_join("revalidation_v12_report.md"), _render(report, vgs, games, seed_value, total))
	_write(out_dir.path_join("revalidation_v12_report.json"), JSON.stringify(report, "  "))
	print("Wrote revalidation_v12_report.md")
	print("REVIEW: %d matchup(s), %d vanguard(s) outside tolerance." % [
		report["review_matchups"].size(), report["review_vgs"].size()])
	quit(0)


func _aggregate(vgs: Array, arch: Dictionary, c0: Dictionary, games: int,
		seed_value: int, total: int) -> Dictionary:
	var matrix := {}
	var per_vg := {}
	var per_vg_c0 := {}
	for v in vgs:
		per_vg[v] = { "wins": 0, "games": 0, "turns": 0, "metrics": GameState._new_metrics() }
		per_vg_c0[v] = { "wins": 0, "games": 0 }
	var watch_totals := _zero_watch()
	var first_wins := 0

	for a in vgs:
		matrix[a] = {}
		for b in vgs:
			var m: Dictionary = arch[a][b]
			matrix[a][b] = _rate(m["a_wins"], games)
			first_wins += int(m["first_player_wins"])
			per_vg[a]["wins"] += int(m["a_wins"]); per_vg[a]["games"] += games
			per_vg[a]["turns"] += int(m["total_turns"])
			MatchRunner._add_metrics(per_vg[a]["metrics"], m["metrics_a"])
			per_vg[b]["wins"] += int(m["b_wins"]); per_vg[b]["games"] += games
			per_vg[b]["turns"] += int(m["total_turns"])
			MatchRunner._add_metrics(per_vg[b]["metrics"], m["metrics_b"])
			for k in MatchRunner.WATCH_KEYS:
				watch_totals[k] += int(m["watch"][k])
			var mc: Dictionary = c0[a][b]
			per_vg_c0[a]["wins"] += int(mc["a_wins"]); per_vg_c0[a]["games"] += games
			per_vg_c0[b]["wins"] += int(mc["b_wins"]); per_vg_c0[b]["games"] += games

	var standings := {}
	var review_vgs: Array = []
	for v in vgs:
		var wr := _rate(per_vg[v]["wins"], per_vg[v]["games"])
		var c0wr := _rate(per_vg_c0[v]["wins"], per_vg_c0[v]["games"])
		var mv: Dictionary = per_vg[v]["metrics"]
		var atk: int = max(1, int(mv["attacks"]))
		standings[v] = {
			"archetype": AIPolicy.ARCHETYPE_BY_VANGUARD.get(v, "?"),
			"win_rate": wr,
			"c0_win_rate": c0wr,
			"avg_game_length": _rate(per_vg[v]["turns"], per_vg[v]["games"]),
			"connect_rate": _rate(mv["connects"], atk),
			"counters_per_life_lost": _rate(mv["counter_cards_spent"], max(1, int(mv["life_lost"]))),
			"avg_attacker_power": _rate(mv["atk_power_sum"], atk),
			"avg_defender_power": _rate(mv["def_power_sum"], atk),
		}
		if wr < VG_LO or wr > VG_HI:
			review_vgs.append(v)

	var review_matchups: Array = []
	for a in vgs:
		for b in vgs:
			var cell: float = matrix[a][b]
			if cell < MATCHUP_LO or cell > MATCHUP_HI:
				review_matchups.append({ "a": a, "b": b, "a_win_rate": cell })

	return {
		"config": { "games_per_matchup": games, "seed": seed_value, "total_games": total },
		"vanguards": vgs,
		"matrix": matrix,
		"standings": standings,
		"decklists": _decklists(vgs),
		"watch_totals": watch_totals,
		"first_player_win_rate": _rate(first_wins, total),
		"review_matchups": review_matchups,
		"review_vgs": review_vgs,
	}


func _decklists(vgs: Array) -> Dictionary:
	var kit := DeckFactory.load_kit()
	var out := {}
	for v in vgs:
		var vg: CardData = kit[v]
		out[v] = {
			"name": vg.name,
			"colors": vg.colors,
			"mono": vg.colors.size() <= 1,
			"kit": DeckFactory.kit_ids(vg),
			"filler": DeckFactory.filler_ids_for(vg).slice(0, 3),
			"counts": DeckFactory.decklist(vg),
		}
	return out


func _render(report: Dictionary, vgs: Array, games: int, seed_value: int, total: int) -> String:
	var s := "# WILDMIGRATION — Patch 1.2 Revalidation (Mono Recolour)\n\n"
	s += "Full 8×8 matchup matrix + the C0 pilot-skill control, re-run after the "
	s += "**mono recolour** (40 cards recoloured so only Vanguards are multi-coloured; "
	s += "colour pools grew to Red 18 / Green 28 / Blue 21 / Purple 25). **%d** games " % games
	s += "per ordered matchup (first player split evenly), **%d** total archetype games " % total
	s += "+ the same again for C0, base seed **%d**, matched seed blocks.\n\n" % seed_value

	s += "> **The v1.1 baseline is VOID.** It was measured before the recolour changed "
	s += "which decks exist — mono Vanguards now shop a much larger single-colour pool "
	s += "(real cross-kit tech), and dual Vanguards see both full mono pools. The v1.1 "
	s += "numbers below are shown for orientation only, struck as VOID. **This 1.2 run is "
	s += "the new baseline.**\n\n"

	# Standings vs VOID baseline.
	s += "## Per-Vanguard standings (archetype pilots)\n\n"
	s += "| Vanguard | Archetype | 1.2 win rate | ~~1.1 (VOID)~~ | Avg turns |\n"
	s += "|---|---|---|---|---|\n"
	for v in vgs:
		var st: Dictionary = report["standings"][v]
		var flag := "" if (st["win_rate"] >= VG_LO and st["win_rate"] <= VG_HI) else " **REVIEW**"
		s += "| %s | %s | %d%%%s | ~~%d%%~~ | %.1f |\n" % [
			_short(v), st["archetype"], round(st["win_rate"] * 100), flag,
			round(float(OLD_ARCH.get(v, 0.0)) * 100), st["avg_game_length"]]
	s += "\n"

	# C0 control.
	s += "## C0 — pilot-skill control (shared generic pilot)\n\n"
	s += "A gap that persists under one shared pilot is attributable to **cards**; a gap "
	s += "that collapses toward 50% is **pilot skill**.\n\n"
	s += "| Vanguard | 1.2 archetype | 1.2 C0 | Shift | ~~1.1 C0 (VOID)~~ |\n"
	s += "|---|---|---|---|---|\n"
	for v in vgs:
		var st2: Dictionary = report["standings"][v]
		var shift: float = (float(st2["c0_win_rate"]) - float(st2["win_rate"])) * 100.0
		s += "| %s | %d%% | %d%% | %+.0f | ~~%d%%~~ |\n" % [
			_short(v), round(st2["win_rate"] * 100), round(st2["c0_win_rate"] * 100),
			shift, round(float(OLD_C0.get(v, 0.0)) * 100)]
	s += "\n"

	# Matrix.
	s += "## Win-rate matrix (row = A's Vanguard, cell = A's win rate vs column B)\n\n"
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

	# Defence economy.
	s += "## Defence economy (per Vanguard)\n\n"
	s += "| Vanguard | Connect rate | Counters / Life lost | Avg attacker pow | Avg defender pow |\n"
	s += "|---|---|---|---|---|\n"
	for v in vgs:
		var st3: Dictionary = report["standings"][v]
		s += "| %s | %d%% | %.2f | %.0f | %.0f |\n" % [
			_short(v), round(st3["connect_rate"] * 100), st3["counters_per_life_lost"],
			st3["avg_attacker_power"], st3["avg_defender_power"]]
	s += "\n"

	# Watch-list totals.
	s += "## Balance watch-list (total resolutions across the matrix)\n\n"
	s += "| Flag | Total |\n|---|---|\n"
	for k in MatchRunner.WATCH_KEYS:
		s += "| %s | %d |\n" % [k, int(report["watch_totals"][k])]
	s += "\n"

	# REVIEW summary.
	s += "## REVIEW flags\n\n"
	s += "Tolerances: matchup 35–65%, per-Vanguard 45–55%.\n\n"
	s += "- Vanguards outside 45–55%%: **%d / 8** — " % report["review_vgs"].size()
	var rvs: Array = []
	for v in report["review_vgs"]:
		rvs.append("%s (%d%%)" % [_short(v), round(report["standings"][v]["win_rate"] * 100)])
	s += (", ".join(rvs) if not rvs.is_empty() else "none") + "\n"
	s += "- Matchups outside 35–65%%: **%d / 64** cells.\n" % report["review_matchups"].size()
	s += "- Overall first-player win rate: **%d%%**.\n\n" % round(report["first_player_win_rate"] * 100)

	# Decklists.
	s += "## Decklists under the mono recolour\n\n"
	s += "Every Vanguard builds the same way now: own kit ×4 (40) + 10 ranked filler "
	s += "(4+4+2) from its subset-legal pool.\n\n"
	for v in vgs:
		var dl: Dictionary = report["decklists"][v]
		s += "**%s** (%s, %s) — kit ×4 (40) + filler **%s** (4+4+2).\n\n" % [
			_short(v), dl["name"], "/".join(dl["colors"]), ", ".join(dl["filler"])]
	return s


func _rate(n, d) -> float:
	return 0.0 if int(d) == 0 else float(n) / float(d)


func _short(vg_id: String) -> String:
	var n := int(vg_id.split("-")[1])
	var arch: String = AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg_id, "?")
	return "%03d(%s)" % [n, arch]


func _zero_watch() -> Dictionary:
	var d := {}
	for k in MatchRunner.WATCH_KEYS:
		d[k] = 0
	return d


func _parse_args() -> Dictionary:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			opts[kv[0]] = kv[1] if kv.size() > 1 else true
	return opts


func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("revalidation_v12: cannot write %s" % path)
		return
	f.store_string(content)
	f.close()
