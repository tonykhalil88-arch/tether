extends SceneTree

## Headless AI-vs-AI batch runner.
##
## Usage:
##   godot --headless -s sim/run.gd -- [--games=N] [--seed=S] [--out=DIR] [--quiet]
##
## Prints a one-line summary per game plus an aggregate report, and (with
## --out) writes a structured JSON log per game for later balance analysis.

func _init() -> void:
	var opts := _parse_args()
	var games := int(opts.get("games", 10))
	var seed_value := int(opts.get("seed", 1))
	var out_dir := str(opts.get("out", ""))
	var quiet := opts.has("quiet")

	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) \
			if out_dir.begins_with("res://") or out_dir.begins_with("user://") else out_dir)

	print("WILDMIGRATION simulator — %d game(s), base seed %d" % [games, seed_value])
	print("-------------------------------------------------------------")

	var report := MatchRunner.run_batch(games, seed_value)
	var results: Array = report["results"]

	for i in range(results.size()):
		var r: Dictionary = results[i]
		var winner_txt := ("draw" if r["winner"] < 0 else "P%d (%s)" % [r["winner"], r["styles"][r["winner"]]])
		if not quiet:
			print("Game %3d | seed %d | first=P%d | winner=%s | turns=%d | life=%s" % [
				i, r["seed"], r["first_player"], winner_txt, r["turns"], str(r["final_life"])])
		if not out_dir.is_empty():
			_write_log(out_dir, i, r)

	print("-------------------------------------------------------------")
	print("Wins by seat : %s" % JSON.stringify(report["wins_by_seat"]))
	print("Wins by style: %s" % JSON.stringify(report["wins_by_style"]))
	var capped := 0
	for r in results:
		if r["capped"]:
			capped += 1
	print("Turn-capped (unfinished) games: %d" % capped)
	if not out_dir.is_empty():
		print("Per-game JSON logs written to: %s" % out_dir)

	quit(0)


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


func _write_log(out_dir: String, index: int, result: Dictionary) -> void:
	var path := out_dir.path_join("game_%03d.simlog.json" % index)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("run.gd: cannot write log to %s" % path)
		return
	f.store_string(JSON.stringify(result, "  "))
	f.close()
