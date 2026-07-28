class_name GameState
extends RefCounted

## Pure data container for a single game in progress. The GameEngine owns one
## of these and mutates it; effects read/write it through `game.state`.

const PHASE_SETUP := "setup"
const PHASE_REFRESH := "refresh"
const PHASE_DRAW := "draw"
const PHASE_AURA := "aura"
const PHASE_MAIN := "main"
const PHASE_END := "end"

var players: Array = []                  # [PlayerState, PlayerState]
var event_bus: EventBus

var first_player: int = 0                # who took the first turn
var active_player: int = 0               # whose turn it is now
var turn_number: int = 0                 # increments each turn (starts at 1)
var phase: String = PHASE_SETUP

var winner: int = -1                     # -1 = ongoing
var game_over: bool = false

var rng: RandomNumberGenerator
var log: Array = []                      # structured game-log entries


func _init(seed_value: int = 0) -> void:
	event_bus = EventBus.new()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	players = [PlayerState.new(0), PlayerState.new(1)]


func opponent_of(p: int) -> int:
	return 1 - p


func active() -> PlayerState:
	return players[active_player]


func log_event(kind: String, data: Dictionary = {}) -> void:
	var entry := { "turn": turn_number, "player": active_player, "kind": kind }
	for k in data:
		entry[k] = data[k]
	log.append(entry)
