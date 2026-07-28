class_name CardInstance
extends RefCounted

## A single physical card in play. Wraps an immutable CardData definition with
## the mutable, per-game state the rules engine mutates.
##
## Terminology: a "rested" card is an exhausted one — the set's `rest` action
## simply exhausts a unit. `frozen` is the new status: a frozen card is skipped
## by exactly one of its owner's Refresh Phases.

var uid: int = 0
var data: CardData
var owner: int = 0
var exhausted: bool = false        # "rested" in card text
var frozen: bool = false           # skip the next Refresh, then thaw
var zone: String = ""
var summoning_sick: bool = true    # true the turn a Banner enters the Battle Area
var played_on_turn: int = -1       # turn number this unit entered play

# Temporary power granted for the duration of the current battle only.
var battle_power_bonus: int = 0
# Temporary power granted for the rest of the current turn.
var turn_power_bonus: int = 0

# Per-turn / persistent flags used by effects (e.g. Once Per Turn latches).
var flags: Dictionary = {}
# Keywords granted at runtime by effects (e.g. an effect that grants Rush).
var granted_keywords: Array = []


func _init(card: CardData = null, controller: int = 0, unique_id: int = 0) -> void:
	data = card
	owner = controller
	uid = unique_id


func name() -> String:
	return data.name if data else "<empty>"


func type() -> String:
	return data.type if data else ""


func has_keyword(kw: String) -> bool:
	if granted_keywords.has(kw):
		return true
	return data != null and data.has_keyword(kw)


func grant_keyword(kw: String) -> void:
	if not granted_keywords.has(kw):
		granted_keywords.append(kw)


## Printed power plus temporary battle- and turn-duration bonuses. Passive,
## conditional buffs (Dreyse, Old Hollow, Siegeworks) are layered on top by
## GameEngine.effective_power().
func current_power() -> int:
	var base := data.power if data else 0
	return base + battle_power_bonus + turn_power_bonus


func clear_battle_bonus() -> void:
	battle_power_bonus = 0


func clear_turn_bonus() -> void:
	turn_power_bonus = 0


func exhaust() -> void:
	exhausted = true


func refresh() -> void:
	exhausted = false


func to_log_dict() -> Dictionary:
	return {
		"uid": uid,
		"id": data.id if data else "",
		"name": name(),
		"type": type(),
		"owner": owner,
		"exhausted": exhausted,
		"frozen": frozen,
		"power": current_power(),
	}
