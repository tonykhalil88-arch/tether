class_name CardText
extends RefCounted

## Turns a card's PRINTED data (keywords + the structured `effects` array) into
## readable English for the frame and the inspector. This is pure presentation:
## it DESCRIBES what a card says, it never executes anything. The engine owns
## behaviour; this owns words.
##
## The set JSON carries no prose rules field (by design — no copied rulebook
## text), so the human-readable text is synthesised here from the structured
## trigger + action.

const _TRIGGER_LABEL := {
	"on_play": "On Play",
	"activate_main": "Activate (Main)",
	"main": "Main",
	"counter": "Counter",
	"life_trigger": "Life Trigger",
	"when_attacking": "When Attacking",
	"passive": "Continuous",
}


## One short line per keyword (for the frame chip area / inspector).
static func keyword_lines(card: CardData) -> Array:
	var out: Array = []
	for kw in card.keywords:
		match str(kw):
			"rush":
				out.append("Rush — may attack the turn it is played.")
			"blocker":
				out.append("Blocker — may be rested to intercept an attack.")
			_:
				out.append(str(kw).capitalize())
	return out


## Full multi-line rules text: keyword lines + one line per effect.
static func rules_text(card: CardData) -> String:
	var lines: Array = keyword_lines(card)
	for e in card.effects:
		if typeof(e) == TYPE_DICTIONARY:
			lines.append(describe_effect(e))
	return "\n".join(lines)


## Compact rules text for the small frame (keywords + effects, terse).
static func frame_text(card: CardData) -> String:
	return rules_text(card)


## A single effect -> "Trigger[ (cost)][ if …]: action." sentence.
static func describe_effect(e: Dictionary) -> String:
	var trigger := str(e.get("trigger", ""))
	var label: String = _TRIGGER_LABEL.get(trigger, trigger.capitalize())
	var prefix := label
	var cost := _cost_text(e.get("cost", {}))
	if not cost.is_empty():
		prefix += " (%s)" % cost
	if bool(e.get("once_per_turn", false)):
		prefix += " [once per turn]"
	var cond := _condition_text(e.get("condition", {}))
	var body := _action_text(e.get("action", {}))
	var rider := _rider_text(e.get("action", {}).get("rider", {}))
	var sentence := "%s: %s" % [prefix, body]
	if not cond.is_empty():
		sentence += " (if %s)" % cond
	if not rider.is_empty():
		sentence += " %s" % rider
	return sentence


# --- pieces ---------------------------------------------------------------

static func _cost_text(cost) -> String:
	if typeof(cost) != TYPE_DICTIONARY or cost.is_empty():
		return ""
	var aura := int(cost.get("aura", 0))
	if aura > 0:
		return "%d Aura" % aura
	return ""


static func _condition_text(cond) -> String:
	if typeof(cond) != TYPE_DICTIONARY or cond.is_empty():
		return ""
	if cond.has("vanguard_name"):
		return "your Vanguard is %s" % str(cond["vanguard_name"])
	if cond.has("min_aura_total"):
		return "you have %d+ Aura" % int(cond["min_aura_total"])
	if cond.has("played_this_turn"):
		return "it was played this turn"
	if cond.has("defender_has_rested_banner"):
		return "the defender has a rested Banner"
	# Fallback: name the first key readably.
	for k in cond.keys():
		return str(k).replace("_", " ")
	return ""


static func _action_text(act) -> String:
	if typeof(act) != TYPE_DICTIONARY or act.is_empty():
		return "no effect"
	var t := str(act.get("type", ""))
	var tgt := _target_text(act)
	match t:
		"power_buff":
			var amt := int(act.get("amount", 0))
			var sign := "+" if amt >= 0 else ""
			var dur := _duration_text(act.get("duration", ""))
			return "give %s %s%d power%s" % [tgt, sign, amt, dur]
		"ko":
			var cap := int(act.get("max_power", 0))
			if cap > 0:
				return "KO %s with %d power or less" % [tgt, cap]
			return "KO %s" % tgt
		"rest":
			return "rest %s" % tgt
		"refresh":
			return "refresh %s" % tgt
		"rest_and_freeze":
			return "rest and freeze %s" % tgt
		"freeze":
			var amt := int(act.get("amount", 0))
			if act.get("target", "") == "enemy_aura" or amt > 0:
				return "freeze %d of the enemy's Aura" % maxi(amt, 1)
			return "freeze %s" % tgt
		"bounce":
			return "return %s to its owner's hand" % tgt
		"draw":
			var n := int(act.get("amount", 1))
			return "draw %d" % n
		"draw_then_bottom":
			return "draw %d, then put %d from hand on the bottom of your deck" % [
				int(act.get("draw", 1)), int(act.get("bottom", 1))]
		"gain_aura":
			return "gain %d Aura" % int(act.get("amount", 1))
		"cost_reduction":
			return "your %s Banners cost %d less (min %d)" % [
				str(act.get("filter_tribe", "")), int(act.get("amount", 1)),
				int(act.get("minimum", 1))]
		"search_top":
			var tribes: Array = act.get("filter_tribes", [])
			var tribe_s := ", ".join(_to_strings(tribes)) if not tribes.is_empty() else "any"
			return "look at the top %d, add %d %s to hand, rest to %s" % [
				int(act.get("count", 1)), int(act.get("add", 1)), tribe_s,
				str(act.get("rest_to", "bottom"))]
		"play_self":
			return "put this card into play"
		_:
			return t.replace("_", " ")


static func _target_text(act: Dictionary) -> String:
	var tgt := str(act.get("target", ""))
	var tribe := str(act.get("filter_tribe", ""))
	var base: String = {
		"self": "this unit",
		"own_banner": "one of your Banners",
		"own_banners": "your Banners",
		"own_other_banner": "another of your Banners",
		"own_unit": "one of your units",
		"own_vanguard": "your Vanguard",
		"enemy_banner": "an enemy Banner",
		"enemy_aura": "the enemy's Aura",
	}.get(tgt, tgt.replace("_", " "))
	if not tribe.is_empty():
		base += " (%s)" % tribe
	return base


static func _duration_text(dur) -> String:
	match str(dur):
		"turn": return " this turn"
		"battle": return " this battle"
		_: return ""


static func _rider_text(rider) -> String:
	if typeof(rider) != TYPE_DICTIONARY or rider.is_empty():
		return ""
	var parts: Array = []
	if rider.has("grant_keyword"):
		parts.append("also grants %s" % str(rider["grant_keyword"]).capitalize())
	if rider.has("if"):
		parts.append("if %s" % str(rider["if"]).replace("_", " "))
	if rider.has("applies_to"):
		parts.append("when %s" % str(rider["applies_to"]))
	if parts.is_empty():
		return ""
	return "(%s)" % " ".join(parts)


static func _to_strings(a) -> Array:
	var out: Array = []
	if typeof(a) == TYPE_ARRAY:
		for x in a:
			out.append(str(x))
	return out
