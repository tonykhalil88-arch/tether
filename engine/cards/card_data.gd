class_name CardData
extends Resource

## Immutable printed definition of a single card.
##
## This mirrors the JSON schema one-to-one so that
## dict -> CardData -> dict is lossless (see tools/importer.gd and the
## importer round-trip tests). Runtime, per-game mutable state lives on
## CardInstance, never here.

@export var id: String = ""
@export var name: String = ""
@export var type: String = ""              # CardEnums.TYPE_*
@export var colors: Array[String] = []
@export var cost: int = 0
@export var power: int = 0
@export var counter: int = 0               # counter value when discarded on defense
@export var life: int = 0                  # Vanguard only; 0 for non-Vanguards
@export var keywords: Array[String] = []
@export var effects: Array = []            # Array[Dictionary] structured effects
@export var flavor: String = ""
@export var faction: String = ""
@export var tribe: String = ""


func has_keyword(kw: String) -> bool:
	return keywords.has(kw)


func is_dual_color() -> bool:
	return CardEnums.is_dual_color(colors)


## Vanguard printed Life: 5 mono-colour, 4 dual-colour (per the rules).
## Falls back to the explicit `life` field when authored, otherwise derives
## it from colour count so seed data need not restate the rule.
func vanguard_life() -> int:
	if type != CardEnums.TYPE_VANGUARD:
		return 0
	if life > 0:
		return life
	return 4 if is_dual_color() else 5


## Structured effects whose "trigger" matches the given event id.
func effects_for(trigger: String) -> Array:
	var out: Array = []
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and e.get("trigger", "") == trigger:
			out.append(e)
	return out


## Serialise back to a plain Dictionary matching the JSON schema exactly.
## Deep-copies containers so callers cannot mutate the resource.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"colors": _string_array(colors),
		"cost": cost,
		"power": power,
		"counter": counter,
		"life": life,
		"keywords": _string_array(keywords),
		"effects": _deep_dup(effects),
		"flavor": flavor,
		"faction": faction,
		"tribe": tribe,
	}


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", ""))
	c.type = str(d.get("type", ""))
	c.colors = _to_string_array(d.get("colors", []))
	c.cost = int(d.get("cost", 0))
	c.power = int(d.get("power", 0))
	c.counter = int(d.get("counter", 0))
	c.life = int(d.get("life", 0))
	c.keywords = _to_string_array(d.get("keywords", []))
	c.effects = _deep_dup(d.get("effects", []))
	c.flavor = str(d.get("flavor", ""))
	c.faction = str(d.get("faction", ""))
	c.tribe = str(d.get("tribe", ""))
	return c


# --- helpers --------------------------------------------------------------

static func _to_string_array(v) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for x in v:
			out.append(str(x))
	return out


func _string_array(a: Array[String]) -> Array:
	# Emit a plain (untyped) Array so JSON.stringify produces a clean list.
	var out: Array = []
	for x in a:
		out.append(x)
	return out


static func _deep_dup(v):
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_deep_dup(x))
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[k] = _deep_dup(v[k])
			return d
		_:
			return v
