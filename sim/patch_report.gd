extends SceneTree

## Patch 0.2 measurement. Reruns the full 8x8 matrix (archetype pilots) and the
## C0 shared-generic-pilot matrix under Patch 0.2, on the SAME seed blocks as
## Brief 4's A0 baseline, and writes patch02_report.md comparing before/after.
##
## Baselines (before) are read from isolation_report.json (A0 = archetype,
## C0 = generic), which was produced on the pre-patch data at the same seeds.
##
## Usage: godot --headless -s sim/patch_report.gd -- [--games=50] [--seed=1]

const MATCHUP_LO := 0.35
const MATCHUP_HI := 0.65
const VG_LO := 0.45
const VG_HI := 0.55
const BUFFED := ["wm01-012", "wm01-023", "wm01-067"]  # Kaya, Bram, Rue

func _init() -> void:
	var opts := _parse_args()
	var games := int(opts.get("games", 50))
	var seed_value := int(opts.get("seed", 1))
	var phase := str(opts.get("phase", "consolidate"))
	var out_dir := ProjectSettings.globalize_path("res://")

	match phase:
		"archetype":
			print("Patch 0.2 matrix (archetype pilots)…")
			var patched := _run_full(games, seed_value, "")
			_write(out_dir.path_join("patch_after_arch.json"), JSON.stringify(patched))
			print("Wrote patch_after_arch.json")
		"c0":
			print("Patch 0.2 C0 (shared generic pilot)…")
			var c0 := _run_full(games, seed_value, "generic")
			_write(out_dir.path_join("patch_after_c0.json"), JSON.stringify(c0))
			print("Wrote patch_after_c0.json")
		"consolidate":
			_consolidate(out_dir, games)
		_:
			push_error("patch_report: unknown phase '%s'" % phase)
	quit(0)


func _consolidate(out_dir: String, games: int) -> void:
	var iso = JSON.parse_string(FileAccess.get_file_as_string(out_dir.path_join("isolation_report.json")))
	if iso == null:
		push_error("patch_report: isolation_report.json not found")
		return
	var patched = JSON.parse_string(FileAccess.get_file_as_string(out_dir.path_join("patch_after_arch.json")))
	var c0_patched = JSON.parse_string(FileAccess.get_file_as_string(out_dir.path_join("patch_after_c0.json")))
	if patched == null or c0_patched == null:
		push_error("patch_report: run --phase=archetype and --phase=c0 first")
		return
	var md := _render(iso["scenarios"]["A0"]["per_vanguard"], iso["scenarios"]["C0"]["per_vanguard"],
		patched, c0_patched, games)
	_write(out_dir.path_join("patch02_report.md"), md)
	print("Wrote %s" % out_dir.path_join("patch02_report.md"))


# =========================================================================
# Full matrix with per-cell win rates + per-Vanguard metrics
# =========================================================================

func _run_full(games: int, seed_value: int, shared: String) -> Dictionary:
	var vgs: Array = MatchRunner.vanguard_ids()
	var matrix := {}
	var per_vg := {}
	for v in vgs:
		per_vg[v] = { "wins": 0, "games": 0, "metrics": GameState._new_metrics() }
	for ai in range(vgs.size()):
		matrix[vgs[ai]] = {}
		for bi in range(vgs.size()):
			var a: String = vgs[ai]
			var b: String = vgs[bi]
			var block_seed := seed_value + (ai * vgs.size() + bi) * games
			var m := MatchRunner.run_matchup(a, b, games, block_seed, {}, shared)
			matrix[a][b] = _rate(m["a_wins"], games)
			per_vg[a]["wins"] += int(m["a_wins"]); per_vg[a]["games"] += games
			_add_metrics(per_vg[a]["metrics"], m["metrics_a"])
			per_vg[b]["wins"] += int(m["b_wins"]); per_vg[b]["games"] += games
			_add_metrics(per_vg[b]["metrics"], m["metrics_b"])
	return { "vanguards": vgs, "matrix": matrix, "per_vanguard": per_vg }


# =========================================================================
# Markdown
# =========================================================================

func _render(a0_base: Dictionary, c0_base: Dictionary, patched: Dictionary,
		c0_patched: Dictionary, games: int) -> String:
	var vgs: Array = patched["vanguards"]
	var s := "# WILDMIGRATION — Patch 0.2 (Apply + Measure)\n\n"
	s += "Six buffs applied (see the changelog in the README). "
	s += "The full 8×8 matrix (%d games/matchup, %d games) and the C0 " % [games, games * vgs.size() * vgs.size()]
	s += "shared-generic-pilot matrix were rerun on the **same seed blocks** as "
	s += "Brief 4's A0 baseline, so before/after is like-for-like.\n\n"

	# Table 1: per-Vanguard, archetype pilots.
	s += "## Per-Vanguard win rate — archetype pilots (A0 → Patch 0.2)\n\n"
	s += "| Vanguard | A0 baseline | Patch 0.2 | Delta |\n|---|---|---|---|\n"
	for v in vgs:
		var base: float = float(a0_base[v]["win_rate"])
		var now: float = _rate(patched["per_vanguard"][v]["wins"], patched["per_vanguard"][v]["games"])
		s += "| %s | %s | %s | %s |\n" % [_short(v), _pct(base), _pct(now), _delta(base, now)]
	s += "\n"

	# Table 2: C0 control.
	s += "## Per-Vanguard win rate — C0 shared generic pilot (baseline → patched)\n\n"
	s += "| Vanguard | C0 baseline | C0 patched | Delta |\n|---|---|---|---|\n"
	for v in vgs:
		var base2: float = float(c0_base[v]["win_rate"])
		var now2: float = _rate(c0_patched["per_vanguard"][v]["wins"], c0_patched["per_vanguard"][v]["games"])
		s += "| %s | %s | %s | %s |\n" % [_short(v), _pct(base2), _pct(now2), _delta(base2, now2)]
	s += "\n"

	# Table 3: defence economy for the three buffed decks.
	s += "## Defence economy — connect rate (buffed decks, before → after)\n\n"
	s += "| Vanguard | Connect A0 | Connect Patch 0.2 | Avg atk pow A0 | Avg atk pow Patch 0.2 |\n"
	s += "|---|---|---|---|---|\n"
	for v in BUFFED:
		var mb: Dictionary = patched["per_vanguard"][v]["metrics"]
		var atks: int = mb["attacks"]
		var cr_now: float = _rate(mb["connects"], atks)
		var ap_now: float = _rate(mb["atk_power_sum"], atks)
		s += "| %s | %s | %s | %.0f | %.0f |\n" % [
			_short(v), _pct(float(a0_base[v]["connect_rate"])), _pct(cr_now),
			float(a0_base[v]["avg_attacker_power"]), ap_now]
	s += "\n"

	# Success criteria.
	s += "## Patch success check\n\n"
	s += "Target: Bram / Kaya / Rue all move toward tolerance without any overshooting >55%.\n\n"
	for v in BUFFED:
		var base3: float = float(a0_base[v]["win_rate"])
		var now3: float = _rate(patched["per_vanguard"][v]["wins"], patched["per_vanguard"][v]["games"])
		var moved_up := now3 > base3
		var overshoot := now3 > VG_HI
		var verdict := "✓ moved up" if moved_up else "✗ did not improve"
		if overshoot:
			verdict += ", ⚠ OVERSHOT >55%"
		s += "- **%s**: %s → %s (%s) — %s\n" % [_short(v), _pct(base3), _pct(now3), _delta(base3, now3), verdict]
	s += "\n"

	# Remaining REVIEW flags under the patch.
	s += "## Remaining REVIEW flags (Patch 0.2)\n\n"
	var rev_vg: Array = []
	for v in vgs:
		var wr: float = _rate(patched["per_vanguard"][v]["wins"], patched["per_vanguard"][v]["games"])
		if wr < VG_LO or wr > VG_HI:
			rev_vg.append("%s (%s)" % [_short(v), _pct(wr)])
	var rev_mu := 0
	for a in vgs:
		for b in vgs:
			var cell: float = patched["matrix"][a][b]
			if cell < MATCHUP_LO or cell > MATCHUP_HI:
				rev_mu += 1
	s += "Vanguards outside 45–55%%: %s\n\n" % ("none" if rev_vg.is_empty() else ", ".join(rev_vg))
	s += "Matchups outside 35–65%%: **%d / %d** cells.\n" % [rev_mu, vgs.size() * vgs.size()]
	return s


# =========================================================================
# Utilities
# =========================================================================

func _short(vg_id: String) -> String:
	return "%s(%s)" % [vg_id.trim_prefix("wm01-"), AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg_id, "?")]


func _pct(x) -> String:
	return "%d%%" % round(float(x) * 100.0)


func _delta(before: float, after: float) -> String:
	return "%+.0f pts" % ((after - before) * 100.0)


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
		push_error("patch_report: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
