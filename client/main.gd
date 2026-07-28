class_name WildmigrationClient
extends Node

## App root. Owns the screen flow: MainMenu -> match (BoardView + Hud on a
## MatchController) -> WinLoss -> back to menu. All rules live in the frozen
## engine; this node only wires presentation to the MatchController.

var _menu: MainMenu
var _board: BoardView
var _hud: Hud
var _win: WinLoss
var _mc: MatchController
var _seed_counter: int = 1


func _ready() -> void:
	_show_menu()


func _show_menu() -> void:
	_teardown_match()
	_menu = MainMenu.new()
	_menu.start_match.connect(_start_match)
	add_child(_menu)


func _start_match(human_vg: String, ai_vg: String) -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null

	_seed_counter += 1
	var seed_value := _seed_counter * 1000 + int(Time.get_ticks_msec()) % 997

	_mc = MatchController.new()
	add_child(_mc)

	_board = BoardView.new()
	add_child(_board)
	_board.bind(_mc)

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(_mc, _board)

	_mc.match_over.connect(_on_match_over)
	# Human is seat 0; alternate who goes first by seed parity for variety.
	var first := MatchController.HUMAN if seed_value % 2 == 0 else MatchController.AI
	_mc.begin_match(human_vg, ai_vg, seed_value, first)


func _on_match_over(winner: int) -> void:
	var stats := _collect_stats()
	_win = WinLoss.new()
	add_child(_win)
	_win.play_again.connect(_show_menu)
	_win.show_result(winner == MatchController.HUMAN, stats)


func _collect_stats() -> Dictionary:
	var st := _mc.engine.state
	var human_metrics: Dictionary = st.metrics[MatchController.HUMAN]
	var ai_metrics: Dictionary = st.metrics[MatchController.AI]
	return {
		"turns": st.turn_number,
		"dealt": int(ai_metrics.get("life_lost", 0)),
		"lost": int(human_metrics.get("life_lost", 0)),
		"attacks": int(human_metrics.get("attacks", 0)),
		"connects": int(human_metrics.get("connects", 0)),
	}


func _teardown_match() -> void:
	for n in [_board, _hud, _win, _mc]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_board = null
	_hud = null
	_win = null
	_mc = null
