extends GutTest

## The headless simulator: batches complete, terminate, and produce logs.

func test_single_game_completes_with_a_result():
	var r: Dictionary = MatchRunner.play_game(42, "aggro", "guard", 0)
	assert_true(r["turns"] > 0, "game advanced")
	assert_false(r["capped"], "game finished before the turn cap")
	assert_true(r["winner"] == 0 or r["winner"] == 1, "a player won")
	assert_true(r["log"].size() > 0, "structured game log produced")

func test_batch_runs_without_errors():
	var report: Dictionary = MatchRunner.run_batch(12, 1000)
	assert_eq(report["games"], 12)
	var seat: Dictionary = report["wins_by_seat"]
	var total: int = int(seat["0"]) + int(seat["1"]) + int(seat["draw"])
	assert_eq(total, 12, "every game accounted for")
	for r in report["results"]:
		assert_true(r["turns"] > 0, "each game advanced")

func test_games_are_deterministic_for_a_seed():
	var a: Dictionary = MatchRunner.play_game(7, "aggro", "aggro", 0)
	var b: Dictionary = MatchRunner.play_game(7, "aggro", "aggro", 0)
	assert_eq(a["winner"], b["winner"], "same seed => same winner")
	assert_eq(a["turns"], b["turns"], "same seed => same length")

func test_log_contains_setup_and_outcome():
	var r: Dictionary = MatchRunner.play_game(99, "aggro", "guard", 1)
	var kinds := {}
	for entry in r["log"]:
		kinds[entry["kind"]] = true
	assert_true(kinds.has("setup"), "log records setup")
	assert_true(kinds.has("attack"), "log records attacks")
