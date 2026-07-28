class_name EffectEngine
extends RefCounted

## Resolves WM01 structured effects. An effect is a Dictionary:
##
##   {
##     "trigger": "on_play" | "main" | "counter" | "life_trigger" |
##                "when_attacking" | "activate_main" | ...,
##     "once_per_turn": <bool>,          # optional latch
##     "cost": { "aura": N, "exhaust_self": <bool> },   # optional
##     "condition": { ... },             # optional gate
##     "action": { "type": "...", ...inline params... }
##   }
##
## All mutations and target selection go through the live GameEngine `game`, so
## this class is pure interpretation. `ctx` carries battle/target references
## (attacker, defender, ...) supplied by the caller.


## Fire every effect on `source` whose trigger == `trigger`. Returns the number
## that actually resolved (cost paid, condition met, not latched).
static func fire(game, source: CardInstance, trigger: String, ctx: Dictionary = {}) -> int:
	if source == null or source.data == null:
		return 0
	# Ablation A2: Total Mobilisation is blanked — none of its effects fire.
	if source.data.id == "wm01-087" and game.state.ablated("blank_total_mobilisation"):
		return 0
	var resolved := 0
	var effects: Array = source.data.effects
	for i in range(effects.size()):
		var eff = effects[i]
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		if str(eff.get("trigger", "")) != trigger:
			continue
		if _try_effect(game, source, eff, i, ctx):
			resolved += 1
	return resolved


static func _try_effect(game, source: CardInstance, eff: Dictionary, idx: int, ctx: Dictionary) -> bool:
	var opt := bool(eff.get("once_per_turn", false))
	var latch := "opt_%d" % idx
	if opt and source.flags.get(latch, false):
		return false
	if not _condition_holds(game, source, eff, ctx):
		return false
	if not _pay_cost(game, source, eff.get("cost", {})):
		return false
	_resolve_action(game, source, eff.get("action", {}), ctx)
	if opt:
		source.flags[latch] = true
	return true


# --- conditions & costs ---------------------------------------------------

static func _condition_holds(game, source: CardInstance, eff: Dictionary, ctx: Dictionary) -> bool:
	var cond: Dictionary = eff.get("condition", {})
	if cond.is_empty():
		return true
	if cond.has("vanguard_name"):
		var vg: CardInstance = game.state.players[source.owner].vanguard
		if vg == null or not vg.name().begins_with(str(cond["vanguard_name"])):
			return false
	if cond.has("target_is_rested"):
		var tgt = ctx.get("defender", null)
		if tgt == null or not tgt.exhausted:
			return false
	if cond.has("min_aura_total"):
		if game.state.players[source.owner].aura_total < int(cond["min_aura_total"]):
			return false
	return true


static func _pay_cost(game, source: CardInstance, cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
	var need_aura := int(cost.get("aura", 0))
	var need_exhaust := bool(cost.get("exhaust_self", false))
	var ps: PlayerState = game.state.players[source.owner]
	if need_exhaust and source.exhausted:
		return false
	if ps.aura_available() < need_aura:
		return false
	if need_aura > 0:
		ps.spend_aura(need_aura)
	if need_exhaust:
		source.exhaust()
	return true


# --- action dispatch ------------------------------------------------------

static func _resolve_action(game, source: CardInstance, action: Dictionary, ctx: Dictionary) -> void:
	match str(action.get("type", "")):
		CardEnums.ACT_POWER_BUFF: _act_power_buff(game, source, action, ctx)
		CardEnums.ACT_KO: _act_ko(game, source, action)
		CardEnums.ACT_REST: _act_rest(game, source, action)
		CardEnums.ACT_REFRESH: _act_refresh(game, source, action, ctx)
		CardEnums.ACT_REST_AND_FREEZE: _act_rest_and_freeze(game, source, action)
		CardEnums.ACT_FREEZE: _act_freeze(game, source, action)
		CardEnums.ACT_BOUNCE: _act_bounce(game, source, action)
		CardEnums.ACT_DRAW: game.draw_cards(source.owner, int(action.get("count", 1)))
		CardEnums.ACT_DRAW_THEN_BOTTOM: _act_draw_then_bottom(game, source, action)
		CardEnums.ACT_GAIN_AURA: game.gain_aura_permanent(source.owner, int(action.get("amount", 1)))
		CardEnums.ACT_COST_REDUCTION: _act_cost_reduction(game, source, action)
		CardEnums.ACT_SEARCH_TOP: _act_search_top(game, source, action)
		CardEnums.ACT_PLAY_SELF: game.play_self_from_life(source)
		"hook":
			# Escape hatch for bespoke effects the data vocabulary can't express.
			EffectHooks.run(str(action.get("hook", "")), game, source, ctx)
		_:
			push_warning("EffectEngine: unknown action '%s'" % str(action.get("type", "")))


static func _act_power_buff(game, source: CardInstance, action: Dictionary, ctx: Dictionary) -> void:
	var amount := int(action.get("amount", 0))
	if amount == 0:
		return
	var count := int(action.get("targets", 1))
	var duration := str(action.get("duration", "turn"))
	var targets := _buff_targets(game, source, action, ctx, count)
	for t in targets:
		if t == null:
			continue
		if duration == "battle":
			t.battle_power_bonus += amount
		else:
			t.turn_power_bonus += amount
		_apply_rider(game, source, action.get("rider", {}), t)


static func _apply_rider(game, source: CardInstance, rider: Dictionary, target: CardInstance) -> void:
	if rider.is_empty():
		return
	if str(rider.get("if", "")) == "played_this_turn" and target.played_on_turn == game.state.turn_number:
		if rider.has("grant_keyword"):
			# Ablation A1: Sora's Rush rider is disabled (the buff still lands).
			if source.data.id == "wm01-001" and game.state.ablated("sora_no_rush_rider"):
				return
			target.grant_keyword(str(rider["grant_keyword"]))
			if source.data.id == "wm01-001":
				game.note_watch("sora_rush_grants")


static func _act_ko(game, source: CardInstance, action: Dictionary) -> void:
	var up_to := int(action.get("up_to", 1))
	var filter := { "max_power": int(action.get("max_power", CardEnums.POWER_CEILING)) }
	for b in game.select_enemy_banners(source.owner, filter, up_to):
		game.ko_unit(b)


static func _act_rest(game, source: CardInstance, action: Dictionary) -> void:
	var up_to := int(action.get("up_to", 1))
	# Ablation A4: Verdigris rests 1 instead of 2.
	if source.data.id == "wm01-013" and game.state.ablated("verdigris_rest_1"):
		up_to = 1
	var filter := { "max_cost": int(action.get("max_cost", 99)) }
	var targets: Array = game.select_enemy_banners(source.owner, filter, up_to)
	for b in targets:
		game.rest_unit(b)
	if source.data.id == "wm01-013" and targets.size() >= 2:
		game.note_watch("verdigris_double_rest")


static func _act_refresh(game, source: CardInstance, action: Dictionary, ctx: Dictionary) -> void:
	var target := str(action.get("target", CardEnums.TGT_SELF))
	if target == CardEnums.TGT_SELF:
		if str(action.get("timing", "")) == "end_of_battle":
			# Ablation A5: Korgan's self-refresh is disabled.
			if source.data.id == "wm01-024" and game.state.ablated("korgan_no_refresh"):
				return
			game.schedule_end_of_battle_refresh(source, ctx)
		else:
			game.refresh_unit(source)
		return
	var up_to := int(action.get("up_to", 1))
	var filter := {
		"filter_tribe": action.get("filter_tribe", ""),
		"max_cost": int(action.get("max_cost", 99)),
		"only_exhausted": true,
		"exclude": source if target == CardEnums.TGT_OWN_OTHER_BANNER else null,
	}
	var targets: Array = game.select_own_banners(source.owner, filter, up_to)
	for b in targets:
		game.refresh_unit(b)
	if source.data.id == "wm01-032" and targets.size() >= 2:
		game.note_watch("stampede_multi_refresh")


static func _act_rest_and_freeze(game, source: CardInstance, action: Dictionary) -> void:
	var filter := { "max_cost": int(action.get("max_cost", 99)) }
	var targets: Array = game.select_enemy_banners(source.owner, filter, 1)
	for b in targets:
		game.rest_unit(b)
		game.freeze_banner(b, source.owner)


static func _act_freeze(game, source: CardInstance, action: Dictionary) -> void:
	var up_to := int(action.get("up_to", 1))
	if str(action.get("target", "")) == CardEnums.TGT_ENEMY_AURA:
		var amount: int = game.freeze_aura(game.state.opponent_of(source.owner), up_to)
		if source.data.id == "wm01-067" and amount > 0:
			game.note_watch("rue_aura_frozen", amount)
		return
	# enemy_banner freeze (capped, usually require_rested)
	var filter := {
		"max_cost": int(action.get("max_cost", 99)),
		"require_rested": bool(action.get("require_rested", false)),
	}
	for b in game.select_enemy_banners(source.owner, filter, up_to):
		if not game.freeze_banner(b, source.owner):
			break  # Banner-freeze cap reached this turn


static func _act_bounce(game, source: CardInstance, action: Dictionary) -> void:
	var up_to := int(action.get("up_to", 1))
	var filter := { "max_cost": int(action.get("max_cost", 99)) }
	for b in game.select_enemy_banners(source.owner, filter, up_to):
		game.bounce_unit(b)


static func _act_draw_then_bottom(game, source: CardInstance, action: Dictionary) -> void:
	var draw := int(action.get("draw", 1))
	var bottom := int(action.get("bottom", 1))
	game.draw_then_bottom(source.owner, draw, bottom)
	if source.data.id == "wm01-045":
		game.note_watch("averil_cards_seen", draw)


static func _act_cost_reduction(game, source: CardInstance, action: Dictionary) -> void:
	# Ablation A3: Canyon Bastion's discount is disabled (Vale passive remains).
	if source.data.id == "wm01-066" and game.state.ablated("canyon_no_discount"):
		return
	game.add_cost_charge(source.owner,
		int(action.get("amount", 1)),
		str(action.get("filter_tribe", "")),
		int(action.get("minimum", 1)))


static func _act_search_top(game, source: CardInstance, action: Dictionary) -> void:
	var count := int(action.get("count", 1))
	var add := int(action.get("add", 1))
	var tribes: Array = action.get("filter_tribes", [])
	var seen: int = game.search_top(source.owner, count, tribes, add, str(action.get("rest_to", "bottom")))
	game.note_watch("cards_seen", seen)


# --- target resolution for power_buff -------------------------------------

static func _buff_targets(game, source: CardInstance, action: Dictionary, ctx: Dictionary, count: int) -> Array:
	var owner := source.owner
	var ps: PlayerState = game.state.players[owner]
	match str(action.get("target", CardEnums.TGT_SELF)):
		CardEnums.TGT_SELF:
			return [source]
		CardEnums.TGT_OWN_VANGUARD:
			return [ps.vanguard]
		CardEnums.TGT_OWN_BANNER, CardEnums.TGT_OWN_BANNERS:
			var tribe := str(action.get("filter_tribe", ""))
			var pool: Array = []
			for b in ps.battle_area:
				if tribe.is_empty() or b.data.tribe == tribe:
					pool.append(b)
			if str(action.get("target", "")) == CardEnums.TGT_OWN_BANNERS:
				return pool  # all matching
			pool.sort_custom(func(a, b): return _buff_priority(a, game) > _buff_priority(b, game))
			return pool.slice(0, count)
		CardEnums.TGT_OWN_OTHER_BANNER:
			var pool2: Array = []
			for b in ps.battle_area:
				if b != source:
					pool2.append(b)
			pool2.sort_custom(func(a, b): return _buff_priority(a, game) > _buff_priority(b, game))
			return pool2.slice(0, count)
		CardEnums.TGT_OWN_UNIT:
			# Prefer the defending unit if this is a counter buff.
			var out: Array = []
			var defender = ctx.get("defender", null)
			if defender != null and defender.owner == owner:
				out.append(defender)
			var units: Array = []
			if ps.vanguard:
				units.append(ps.vanguard)
			for b in ps.battle_area:
				units.append(b)
			units.sort_custom(func(a, b): return _buff_priority(a, game) > _buff_priority(b, game))
			for u in units:
				if out.size() >= count:
					break
				if not out.has(u):
					out.append(u)
			return out.slice(0, count)
		_:
			return []


static func _buff_priority(inst: CardInstance, game) -> int:
	# Prefer a unit that can attack (not yet exhausted), then raw power.
	var p := inst.current_power()
	if not inst.exhausted:
		p += 100000
	return p
