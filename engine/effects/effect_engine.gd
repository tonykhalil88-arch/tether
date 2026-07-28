class_name EffectEngine
extends RefCounted

## Resolves the structured effect Dictionaries carried by CardData.
##
## An effect looks like:
##     { "trigger": "on_play", "action": "draw", "params": { "amount": 1 } }
## `trigger` selects when it fires (matched by the engine against event ids);
## `action` + `params` say what happens. `action == "hook"` defers to
## EffectHooks for anything the built-in vocabulary can't express.
##
## Every method takes the live GameEngine `game` so actions can mutate state
## and emit further events. `ctx` carries battle/target references supplied by
## the caller (attacker, defender, chosen_ally, ...).

const SUPPORTED_ACTIONS := [
	"draw", "power_buff", "ko_enemy_banner_max_power",
	"gain_rush", "search_top", "hook",
]


## Fire every effect on `source` whose trigger == `trigger`.
static func fire(game, source: CardInstance, trigger: String, ctx: Dictionary = {}) -> void:
	if source == null or source.data == null:
		return
	for effect in source.data.effects_for(trigger):
		resolve(game, source, effect, ctx)


## Resolve a single effect dict.
static func resolve(game, source: CardInstance, effect: Dictionary, ctx: Dictionary = {}) -> void:
	var action := str(effect.get("action", ""))
	var params: Dictionary = effect.get("params", {})
	match action:
		"draw":
			game.draw_cards(source.owner, int(params.get("amount", 1)))
		"power_buff":
			_apply_power_buff(game, source, params, ctx)
		"ko_enemy_banner_max_power":
			_ko_enemy_banner(game, source, int(params.get("max_power", 0)))
		"gain_rush":
			source.grant_keyword(CardEnums.KW_RUSH)
		"search_top":
			_search_top(game, source, params)
		"hook":
			EffectHooks.run(str(params.get("hook", "")), game, source, ctx)
		_:
			push_warning("EffectEngine: unknown action '%s'" % action)


# --- action implementations ----------------------------------------------

static func _apply_power_buff(game, source: CardInstance, params: Dictionary, ctx: Dictionary) -> void:
	var amount := int(params.get("amount", 0))
	if amount == 0:
		return
	var target := _resolve_target(game, source, str(params.get("target", "self")), ctx)
	if target != null:
		target.battle_power_bonus += amount


static func _resolve_target(game, source: CardInstance, key: String, ctx: Dictionary) -> CardInstance:
	match key:
		"self":
			return source
		"vanguard":
			return game.state.players[source.owner].vanguard
		"attacker":
			return ctx.get("attacker", null)
		"defender":
			return ctx.get("defender", null)
		"chosen_ally":
			if ctx.has("chosen_ally"):
				return ctx["chosen_ally"]
			# Default: buff the currently attacking unit, else the Vanguard.
			return ctx.get("attacker", game.state.players[source.owner].vanguard)
		_:
			return null


static func _ko_enemy_banner(game, source: CardInstance, max_power: int) -> void:
	var enemy: PlayerState = game.state.players[1 - source.owner]
	var best: CardInstance = null
	for b in enemy.battle_area:
		if b.data.power <= max_power:
			if best == null or b.data.power < best.data.power:
				best = b
	if best != null:
		game.ko_unit(best)


static func _search_top(game, source: CardInstance, params: Dictionary) -> void:
	var count := int(params.get("count", 1))
	var want_type := str(params.get("type", ""))
	var player: PlayerState = game.state.players[source.owner]
	var looked: Array = []
	for i in range(min(count, player.deck.size())):
		looked.append(player.deck[i])
	var picked: CardInstance = null
	for c in looked:
		if want_type.is_empty() or c.type() == want_type:
			picked = c
			break
	if picked != null:
		player.remove_from_current_zone(picked)
		picked.zone = CardEnums.ZONE_HAND
		player.hand.append(picked)
