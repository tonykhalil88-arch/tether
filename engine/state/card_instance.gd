class_name CardInstance
extends RefCounted

## A single physical card in play. Wraps an immutable CardData definition
## with the mutable, per-game state the rules engine mutates: which player
## controls it, whether it is exhausted, temporary battle buffs, etc.

var uid: int = 0                    # unique within a game, for logging/targeting
var data: CardData
var owner: int = 0                  # controlling player index (0 or 1)
var exhausted: bool = false
var zone: String = ""              # CardEnums.ZONE_*
var summoning_sick: bool = true    # true the turn a Banner enters the battle area

# Temporary power granted for the duration of the current battle only
# (attached Aura, counter techniques, "when attacking" buffs...).
var battle_power_bonus: int = 0

# Per-turn / persistent flags used by effects (e.g. Once Per Turn latches).
var flags: Dictionary = {}

# Keywords granted at runtime by effects (e.g. an effect that gives Rush).
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


## Base printed power plus any temporary battle bonus.
func current_power() -> int:
	var base := data.power if data else 0
	return base + battle_power_bonus


func clear_battle_bonus() -> void:
	battle_power_bonus = 0


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
		"power": current_power(),
	}
