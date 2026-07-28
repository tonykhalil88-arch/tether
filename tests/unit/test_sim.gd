extends GutTest

## The headless simulator: batches complete, terminate, produce logs and the
## balance watch-list.

func test_single_game_completes_with_a_result():
	var r: Dictionary = MatchRunner.play_game(42, "wm01-001", "wm01-078", 0)
	assert_true(r["turns"] > 0, "game advanced")
	assert_false(r["capped"], "finished before the turn cap")
	assert_true(r["winner"] == 0 or r["winner"] == 1, "a player won")
	assert_true(r["log"].size() > 0, "game log produced")
	assert_true(r.has("watch"), "watch-list attached")
	assert_eq(r["archetypes"], ["rush", "threshold_ramp"], "policies auto-mapped from Vanguards")

func test_batch_runs_without_errors():
	var report: Dictionary = MatchRunner.run_batch(16, 1000)
	assert_eq(report["games"], 16)
	var seat: Dictionary = report["wins_by_seat"]
	var total: int = int(seat["0"]) + int(seat["1"]) + int(seat["draw"])
	assert_eq(total, 16, "every game accounted for")
	assert_true(report.has("watch_totals"), "watch totals aggregated")
	for k in MatchRunner.WATCH_KEYS:
		assert_true(report["watch_totals"].has(k), "watch key %s reported" % k)
	for r in report["results"]:
		assert_true(r["turns"] > 0)

func test_games_are_deterministic_for_a_seed():
	var a: Dictionary = MatchRunner.play_game(7, "wm01-001", "wm01-023", 0)
	var b: Dictionary = MatchRunner.play_game(7, "wm01-001", "wm01-023", 0)
	assert_eq(a["winner"], b["winner"], "same seed => same winner")
	assert_eq(a["turns"], b["turns"], "same seed => same length")

func test_matchup_split_is_balanced_and_reported():
	var m: Dictionary = MatchRunner.run_matchup("wm01-001", "wm01-078", 20, 3000)
	assert_eq(int(m["a_wins"]) + int(m["b_wins"]) + int(m["draws"]), 20, "all games counted")
	assert_true(m.has("first_player_wins") and m.has("total_turns"))

func test_log_contains_setup_and_outcome():
	var r: Dictionary = MatchRunner.play_game(99, "wm01-045", "wm01-067", 1)
	var kinds := {}
	for entry in r["log"]:
		kinds[entry["kind"]] = true
	assert_true(kinds.has("setup"))
	assert_true(kinds.has("attack"))
