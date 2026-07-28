class_name EventBus
extends RefCounted

## Minimal synchronous publish/subscribe hub that the effect system rides on.
##
## Card effects (and internal engine bookkeeping) subscribe to named events
## such as "on_play" or "on_attack_declared"; the engine emits those events
## with a payload Dictionary as the game progresses. Handlers run in
## subscription order, synchronously, so rules resolution stays deterministic.

# event_name -> Array[Dictionary{ id:int, cb:Callable }]
var _subs: Dictionary = {}
var _next_id: int = 1

# Emitted-event tape, useful for tests and the sim log.
var history: Array = []
var record_history: bool = false


## Subscribe `cb` to `event_name`. Returns a token that unsubscribe() accepts.
func subscribe(event_name: String, cb: Callable) -> int:
	if not _subs.has(event_name):
		_subs[event_name] = []
	var token := _next_id
	_next_id += 1
	_subs[event_name].append({ "id": token, "cb": cb })
	return token


## Remove a previously registered subscription by token.
func unsubscribe(token: int) -> void:
	for event_name in _subs.keys():
		var arr: Array = _subs[event_name]
		for i in range(arr.size() - 1, -1, -1):
			if arr[i]["id"] == token:
				arr.remove_at(i)


## Drop every subscription for a given event (used when a card leaves play).
func clear_event(event_name: String) -> void:
	_subs.erase(event_name)


## Fire `event_name`. Every handler receives the same `payload` Dictionary and
## may mutate it (e.g. accumulate a power total). Returns the payload.
func emit(event_name: String, payload: Dictionary = {}) -> Dictionary:
	if record_history:
		history.append({ "event": event_name, "payload": payload.duplicate(true) })
	if _subs.has(event_name):
		# Iterate a copy so handlers may (un)subscribe during dispatch.
		for entry in _subs[event_name].duplicate():
			var cb: Callable = entry["cb"]
			if cb.is_valid():
				cb.call(payload)
	return payload


func handler_count(event_name: String) -> int:
	return _subs.get(event_name, []).size()
