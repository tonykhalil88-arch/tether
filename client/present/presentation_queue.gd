class_name PresentationQueue
extends Node

## Sits between the (instant) engine and the screen. The engine resolves a whole
## action synchronously; the MatchController turns the resulting state.log delta
## into an ordered list of presentation *beats* and pushes them here. This queue
## then plays them ONE AT A TIME over wall-clock time, so the board has room to
## animate — summon, strike, KO, freeze, etc.
##
## It owns nothing about rules. A beat is just a Dictionary:
##   { "kind": String, "duration": float, ... }  (any extra payload passes through)
##
## Speed is global: 1x, 2x, or SKIP (flush everything instantly). Prompts pause
## the queue via pause()/resume() so human input never races an animation.

signal beat_started(beat: Dictionary)
signal beat_finished(beat: Dictionary)
signal queue_drained()

const SPEED_1X := 1.0
const SPEED_2X := 2.0

var speed_mult: float = SPEED_1X
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _elapsed: float = 0.0
var _paused: bool = false
var _skipping: bool = false


func _process(delta: float) -> void:
	if _paused:
		return
	if _skipping:
		_flush_all()
		return
	if _current.is_empty():
		_start_next()
		if _current.is_empty():
			return
	_elapsed += delta * speed_mult
	if _elapsed >= float(_current.get("duration", 0.0)):
		_finish_current()


# --- public API -----------------------------------------------------------

func enqueue(beat: Dictionary) -> void:
	_queue.append(beat)


func enqueue_many(beats: Array) -> void:
	for b in beats:
		if typeof(b) == TYPE_DICTIONARY:
			_queue.append(b)


## Cycle 1x -> 2x -> 1x (skip is a separate momentary action).
func toggle_speed() -> float:
	speed_mult = SPEED_2X if is_equal_approx(speed_mult, SPEED_1X) else SPEED_1X
	return speed_mult


func set_speed_mult(m: float) -> void:
	speed_mult = maxf(0.1, m)


## Flush every pending beat this frame (each still fires started+finished so the
## board can snap to final state). Auto-clears once drained.
func skip() -> void:
	_skipping = true


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_idle() -> bool:
	return _current.is_empty() and _queue.is_empty()


func pending() -> int:
	return _queue.size() + (0 if _current.is_empty() else 1)


func clear() -> void:
	_queue.clear()
	_current = {}
	_elapsed = 0.0
	_skipping = false


# --- internals ------------------------------------------------------------

func _start_next() -> void:
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	_elapsed = 0.0
	beat_started.emit(_current)
	# Zero-duration beats resolve the same frame they start.
	if float(_current.get("duration", 0.0)) <= 0.0:
		_finish_current()


func _finish_current() -> void:
	var done := _current
	_current = {}
	_elapsed = 0.0
	beat_finished.emit(done)
	if _queue.is_empty() and not _skipping:
		queue_drained.emit()


func _flush_all() -> void:
	# Resolve current + all queued instantly, preserving started/finished order.
	if not _current.is_empty():
		_finish_current()
	while not _queue.is_empty():
		_current = _queue.pop_front()
		_elapsed = 0.0
		beat_started.emit(_current)
		_finish_current()
	_skipping = false
	queue_drained.emit()
