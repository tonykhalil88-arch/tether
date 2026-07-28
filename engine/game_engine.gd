class_name GameEngine
extends RefCounted

## The rules engine (WM01). Owns a GameState and exposes the operations that
## players (AI policies or tests) invoke. Fully headless and deterministic
## given a seed.
##
## Turn structure:
##   1. Refresh  - unexhaust all your cards (frozen cards skip this once)
##   2. Draw     - draw 1 (first player skips on turn 1 only)
##   3. Aura     - gain 2 (first player gains 1 on turn 1); pool capped at 10;
##                 frozen Aura stays unavailable for this turn
##   4. Main     - plays, activations, aura attach, attacks
##   5. End      - turn-duration effects expire
##
## Deck-out rule: a player who must draw from an empty deck loses (documented
## in the README) so simulations always terminate.

var state: GameState
var _uid_counter: int = 0
var _mulligan_used := [false, false]
# Refreshes scheduled for the end of the current battle (Korgan). Each entry is
# a CardInstance to unexhaust once the battle resolves.
var _end_of_battle_refresh: Array = []


func _init(seed_value: int = 0) -> void:
	state = GameState.new(seed_value)


# =========================================================================
# Setup
# =========================================================================

func setup(deck0: Array, van0: CardData, deck1: Array, van1: CardData, first: int = 0) -> void:
	state.first_player = first
	_build_player(0, deck0, van0)
	_build_player(1, deck1, van1)
	state.phase = GameState.PHASE_SETUP
	_draw_opening_hand(0)
	_draw_opening_hand(1)
	state.log_event("setup", { "first_player": first })


func _build_player(idx: int, deck: Array, vanguard: CardData) -> void:
	var ps: PlayerState = state.players[idx]
	ps.deck.clear()
	for cd in deck:
		var inst := _make_instance(cd, idx)
		inst.zone = CardEnums.ZONE_DECK
		ps.deck.append(inst)
	_shuffle(ps.deck)
	ps.vanguard = _make_instance(vanguard, idx)
	ps.vanguard.zone = CardEnums.ZONE_VANGUARD
	ps.vanguard.summoning_sick = false


func _draw_opening_hand(idx: int) -> void:
	for i in range(5):
		_move_top_deck_to_hand(idx)


func mulligan(idx: int) -> bool:
	if _mulligan_used[idx]:
		return false
	_mulligan_used[idx] = true
	var ps: PlayerState = state.players[idx]
	for inst in ps.hand:
		inst.zone = CardEnums.ZONE_DECK
		ps.deck.append(inst)
	ps.hand.clear()
	_shuffle(ps.deck)
	_draw_opening_hand(idx)
	state.log_event("mulligan", { "who": idx })
	return true


func start_game() -> void:
	_place_life(0)
	_place_life(1)
	state.turn_number = 0
	state.active_player = state.opponent_of(state.first_player)
	state.log_event("game_start", {
		"life": [state.players[0].life.size(), state.players[1].life.size()],
	})


func _place_life(idx: int) -> void:
	var ps: PlayerState = state.players[idx]
	var n := ps.vanguard.data.vanguard_life()
	for i in range(n):
		if ps.deck.is_empty():
			break
		var inst: CardInstance = ps.deck.pop_front()
		inst.zone = CardEnums.ZONE_LIFE
		ps.life.append(inst)


# =========================================================================
# Turn progression
# =========================================================================

func begin_turn() -> int:
	if state.game_over:
		return -1
	state.turn_number += 1
	if state.turn_number == 1:
		state.active_player = state.first_player
	else:
		state.active_player = state.opponent_of(state.active_player)
	var p := state.active_player

	# 1. Refresh
	state.phase = GameState.PHASE_REFRESH
	_refresh_active_player()

	# 2. Draw
	state.phase = GameState.PHASE_DRAW
	if state.turn_number > 1:
		draw_cards(p, 1)

	# 3. Aura
	state.phase = GameState.PHASE_AURA
	var gain := 1 if state.turn_number == 1 else 2
	state.players[p].gain_aura(gain)

	# 4. Main
	state.phase = GameState.PHASE_MAIN
	_prime_cost_charges(p)
	state.event_bus.emit(CardEnums.EV_ON_TURN_START, { "player": p, "game": self })
	state.log_event("turn_start", {
		"aura_total": state.players[p].aura_total,
		"aura_available": state.players[p].aura_available(),
		"hand": state.players[p].hand.size(),
	})
	return p


func _refresh_active_player() -> void:
	var ps: PlayerState = state.players[state.active_player]
	ps.banner_freezes_used = 0

	# Aura: unexhaust, leaving frozen tokens spent for this turn.
	ps.refresh_aura()

	# Vanguard and Stage always refresh.
	if ps.vanguard:
		ps.vanguard.refresh()
		ps.vanguard.flags.clear()
	if ps.stage:
		ps.stage.refresh()

	# Banners: frozen ones skip this Refresh and thaw for next turn.
	for b in ps.battle_area:
		if b.frozen:
			b.frozen = false          # thaws; stays exhausted this turn
		else:
			b.refresh()
		b.summoning_sick = false
		b.flags.clear()


func end_turn() -> void:
	if state.game_over:
		return
	state.phase = GameState.PHASE_END
	state.event_bus.emit(CardEnums.EV_ON_TURN_END, {
		"player": state.active_player, "game": self,
	})
	_clear_all_battle_bonuses()
	_clear_all_turn_bonuses()
	state.players[state.active_player].cost_charges.clear()
	state.log_event("turn_end", {})


# =========================================================================
# Card movement / drawing
# =========================================================================

func draw_cards(idx: int, n: int) -> void:
	for i in range(n):
		if state.game_over:
			return
		if state.players[idx].deck.is_empty():
			_declare_winner(state.opponent_of(idx), "deck_out")
			return
		_move_top_deck_to_hand(idx)


## Draw `draw` cards, then place `bottom` cards from hand on the deck bottom.
## The AI-neutral heuristic bottoms the highest-cost cards it cannot yet play.
func draw_then_bottom(idx: int, draw: int, bottom: int) -> void:
	draw_cards(idx, draw)
	if state.game_over:
		return
	var ps: PlayerState = state.players[idx]
	for i in range(bottom):
		if ps.hand.is_empty():
			return
		# Bottom the least useful card: highest cost above current Aura, else
		# the highest cost overall.
		var pick: CardInstance = null
		for c in ps.hand:
			if pick == null or c.data.cost > pick.data.cost:
				pick = c
		ps.hand.erase(pick)
		pick.zone = CardEnums.ZONE_DECK
		ps.deck.append(pick)


func _move_top_deck_to_hand(idx: int) -> void:
	var ps: PlayerState = state.players[idx]
	var inst: CardInstance = ps.deck.pop_front()
	inst.zone = CardEnums.ZONE_HAND
	ps.hand.append(inst)


## Look at the top `count` cards; add up to `add` matching `tribes` to hand,
## send the rest to the chosen end of the deck. Returns cards seen.
func search_top(idx: int, count: int, tribes: Array, add: int, rest_to: String) -> int:
	var ps: PlayerState = state.players[idx]
	var looked: Array = []
	for i in range(min(count, ps.deck.size())):
		looked.append(ps.deck[i])
	var added := 0
	for c in looked:
		if added >= add:
			break
		if tribes.is_empty() or tribes.has(c.data.tribe):
			ps.deck.erase(c)
			c.zone = CardEnums.ZONE_HAND
			ps.hand.append(c)
			added += 1
	# Remaining looked-at cards go to the bottom (or stay on top).
	if rest_to == "bottom":
		for c in looked:
			if c.zone == CardEnums.ZONE_DECK and ps.deck.has(c):
				ps.deck.erase(c)
				ps.deck.append(c)
	return looked.size()


# =========================================================================
# Main-phase actions
# =========================================================================

func play_card(idx: int, inst: CardInstance) -> bool:
	if state.game_over or idx != state.active_player or state.phase != GameState.PHASE_MAIN:
		return false
	if inst.zone != CardEnums.ZONE_HAND or inst.owner != idx:
		return false
	var ps: PlayerState = state.players[idx]
	match inst.type():
		CardEnums.TYPE_BANNER:
			if ps.battle_area_full():
				return false
			var cost := _effective_play_cost(idx, inst)
			if not ps.spend_aura(cost):
				return false
			_consume_cost_charges(idx, inst)
			ps.hand.erase(inst)
			inst.zone = CardEnums.ZONE_BATTLE
			inst.exhausted = false
			inst.summoning_sick = true
			inst.played_on_turn = state.turn_number
			ps.battle_area.append(inst)
			_fire(inst, CardEnums.EV_ON_PLAY)
			state.log_event("play_banner", { "card": inst.data.id, "uid": inst.uid, "cost": cost })
			return true
		CardEnums.TYPE_TECHNIQUE:
			if not ps.spend_aura(inst.data.cost):
				return false
			ps.hand.erase(inst)
			inst.zone = CardEnums.ZONE_BATTLE
			_fire(inst, CardEnums.EV_MAIN)
			ps.send_to_trash(inst)
			state.log_event("play_technique", { "card": inst.data.id, "uid": inst.uid })
			return true
		CardEnums.TYPE_STAGE:
			if not ps.spend_aura(inst.data.cost):
				return false
			ps.hand.erase(inst)
			if ps.stage != null:
				ps.send_to_trash(ps.stage)
			inst.zone = CardEnums.ZONE_STAGE
			inst.exhausted = false
			inst.played_on_turn = state.turn_number
			ps.stage = inst
			_fire(inst, CardEnums.EV_ON_PLAY)
			state.log_event("play_stage", { "card": inst.data.id, "uid": inst.uid })
			return true
		_:
			return false


func _fire(inst: CardInstance, trigger: String, ctx: Dictionary = {}) -> int:
	return EffectEngine.fire(self, inst, trigger, ctx)


## Activate an [Activate: Main] ability (Vanguard, Banner or Stage). Returns
## true if at least one ability resolved.
func activate_main(inst: CardInstance) -> bool:
	if state.game_over or inst.owner != state.active_player or state.phase != GameState.PHASE_MAIN:
		return false
	var fired := _fire(inst, CardEnums.EV_ACTIVATE_MAIN, { "source": inst })
	if fired > 0:
		state.log_event("activate_main", { "card": inst.data.id, "uid": inst.uid })
	return fired > 0


## Attach one Aura to a unit: exhaust 1 Aura for +1000 battle power.
func attach_aura(idx: int, target: CardInstance) -> bool:
	if target == null or target.owner != idx:
		return false
	if not state.players[idx].spend_aura(1):
		return false
	target.battle_power_bonus += 1000
	return true


# =========================================================================
# Combat
# =========================================================================

func can_attack(inst: CardInstance) -> bool:
	if state.game_over or inst == null or inst.owner != state.active_player:
		return false
	if inst.exhausted:
		return false
	var t := inst.type()
	if t == CardEnums.TYPE_VANGUARD:
		return true
	if t == CardEnums.TYPE_BANNER:
		if inst.summoning_sick and not inst.has_keyword(CardEnums.KW_RUSH):
			return false
		return true
	return false


func legal_attack_targets(attacker: CardInstance) -> Array:
	var out: Array = []
	var enemy: PlayerState = state.players[state.opponent_of(attacker.owner)]
	out.append(enemy.vanguard)
	for b in enemy.battle_area:
		if b.exhausted:  # rested/frozen banners are legal targets
			out.append(b)
	return out


func declare_attack(attacker: CardInstance, target: CardInstance,
		atk_choices: Dictionary = {}, def_choices: Dictionary = {}) -> Dictionary:
	var fail := { "ok": false }
	if not can_attack(attacker):
		return fail
	if not legal_attack_targets(attacker).has(target):
		return fail

	var defender_idx := state.opponent_of(attacker.owner)
	_end_of_battle_refresh.clear()
	attacker.exhaust()

	state.event_bus.emit(CardEnums.EV_ON_ATTACK_DECLARED, {
		"attacker": attacker, "target": target, "game": self,
	})
	_fire(attacker, CardEnums.EV_WHEN_ATTACKING, { "attacker": attacker, "defender": target })

	var attach := int(atk_choices.get("attach_aura", 0))
	for i in range(attach):
		if not attach_aura(attacker.owner, attacker):
			break

	# Blocker redirection.
	var current_target := target
	var blocker = def_choices.get("blocker", null)
	if blocker != null and _is_valid_blocker(blocker, defender_idx):
		blocker.exhaust()
		current_target = blocker
		state.log_event("blocker", { "uid": blocker.uid })

	var defense_bonus := _apply_defender_counters(defender_idx, current_target, def_choices)

	var atk_power := effective_power(attacker)
	var def_power := effective_power(current_target) + defense_bonus
	var attacker_wins := atk_power >= def_power

	var result := {
		"ok": true,
		"attacker": attacker.uid,
		"target": current_target.uid,
		"attacker_power": atk_power,
		"defender_power": def_power,
		"attacker_wins": attacker_wins,
		"life_flipped": false,
		"ko": false,
		"game_over": false,
	}

	if attacker_wins:
		if current_target.type() == CardEnums.TYPE_VANGUARD:
			result["life_flipped"] = true
			_resolve_life_hit(defender_idx, def_choices, result)
		else:
			ko_unit(current_target)
			result["ko"] = true

	state.event_bus.emit(CardEnums.EV_ON_BATTLE_END, {
		"attacker": attacker, "target": current_target,
		"attacker_wins": attacker_wins, "game": self,
	})
	# Resolve any end-of-battle refreshes (e.g. Korgan) so the unit can attack
	# again this turn.
	for inst in _end_of_battle_refresh:
		inst.refresh()
		if inst.data.id == "wm01-024":
			note_watch("korgan_repeat_attacks")
	_end_of_battle_refresh.clear()

	_clear_all_battle_bonuses()

	result["game_over"] = state.game_over
	state.log_event("attack", result)
	return result


func _is_valid_blocker(blocker: CardInstance, defender_idx: int) -> bool:
	return blocker.owner == defender_idx \
		and blocker.type() == CardEnums.TYPE_BANNER \
		and blocker.has_keyword(CardEnums.KW_BLOCKER) \
		and not blocker.exhausted \
		and state.players[defender_idx].battle_area.has(blocker)


func _apply_defender_counters(defender_idx: int, target: CardInstance, def_choices: Dictionary) -> int:
	var bonus := 0
	var ps: PlayerState = state.players[defender_idx]

	for tech in def_choices.get("counter_techniques", []):
		if tech == null or tech.zone != CardEnums.ZONE_HAND or tech.owner != defender_idx:
			continue
		if not ps.spend_aura(tech.data.cost):
			continue
		ps.hand.erase(tech)
		tech.zone = CardEnums.ZONE_BATTLE
		var fired := _fire(tech, CardEnums.EV_COUNTER, { "defender": target })
		if fired == 0:
			bonus += tech.data.counter  # fallback to printed counter value
		ps.send_to_trash(tech)

	for card in def_choices.get("counter_cards", []):
		if card == null or card.zone != CardEnums.ZONE_HAND or card.owner != defender_idx:
			continue
		bonus += card.data.counter
		ps.send_to_trash(card)

	return bonus


func _resolve_life_hit(defender_idx: int, def_choices: Dictionary, result: Dictionary) -> void:
	var ps: PlayerState = state.players[defender_idx]
	if ps.life.is_empty():
		_declare_winner(state.opponent_of(defender_idx), "life_zero")
		return
	var card: CardInstance = ps.life.pop_front()
	var has_trigger := not card.data.effects_for(CardEnums.EV_LIFE_TRIGGER).is_empty()
	var resolve_trigger := bool(def_choices.get("resolve_trigger", true))
	if has_trigger and resolve_trigger:
		# The card may relocate itself (play_self); otherwise it goes to Trash.
		card.zone = CardEnums.ZONE_LIFE  # transient marker while resolving
		_fire(card, CardEnums.EV_LIFE_TRIGGER, { "source": card })
		if card.zone == CardEnums.ZONE_LIFE:  # not relocated by play_self
			card.zone = CardEnums.ZONE_TRASH
			ps.trash.append(card)
		result["trigger_resolved"] = true
	else:
		card.zone = CardEnums.ZONE_HAND
		ps.hand.append(card)
	result["life_remaining"] = ps.life.size()


# =========================================================================
# Effect primitives (called by EffectEngine)
# =========================================================================

func rest_unit(inst: CardInstance) -> void:
	if inst != null:
		inst.exhausted = true


func refresh_unit(inst: CardInstance) -> void:
	if inst != null:
		inst.exhausted = false


func schedule_end_of_battle_refresh(inst: CardInstance, _ctx: Dictionary) -> void:
	if inst != null and not _end_of_battle_refresh.has(inst):
		_end_of_battle_refresh.append(inst)


## Freeze a Banner. Enforces the per-turn cap of 1 Banner freeze per player.
## Returns true if the freeze was applied.
func freeze_banner(inst: CardInstance, freezer: int) -> bool:
	if inst == null:
		return false
	var fp: PlayerState = state.players[freezer]
	if fp.banner_freezes_used >= CardEnums.BANNER_FREEZE_CAP_PER_TURN:
		return false
	fp.banner_freezes_used += 1
	inst.frozen = true
	state.log_event("freeze_banner", { "uid": inst.uid, "by": freezer })
	return true


## Freeze up to `amount` of a player's Aura (uncapped). Returns amount frozen.
func freeze_aura(owner: int, amount: int) -> int:
	var ps: PlayerState = state.players[owner]
	var frozen: int = min(amount, ps.aura_total)
	ps.aura_frozen_pending += frozen
	state.log_event("freeze_aura", { "owner": owner, "amount": frozen })
	return frozen


func bounce_unit(inst: CardInstance) -> void:
	if inst == null:
		return
	var ps: PlayerState = state.players[inst.owner]
	ps.remove_from_current_zone(inst)
	inst.zone = CardEnums.ZONE_HAND
	inst.exhausted = false
	inst.frozen = false
	inst.clear_battle_bonus()
	inst.clear_turn_bonus()
	inst.granted_keywords.clear()
	inst.flags.clear()
	ps.hand.append(inst)
	state.log_event("bounce", { "uid": inst.uid })


func gain_aura_permanent(owner: int, amount: int) -> void:
	state.players[owner].gain_aura(amount)


func ko_unit(inst: CardInstance) -> void:
	var ps: PlayerState = state.players[inst.owner]
	ps.send_to_trash(inst)
	state.event_bus.emit(CardEnums.EV_ON_KO, { "unit": inst, "game": self })
	state.log_event("ko", { "uid": inst.uid, "card": inst.data.id })


## Life-trigger play_self: put the revealed Banner into the Battle Area.
func play_self_from_life(inst: CardInstance) -> void:
	var ps: PlayerState = state.players[inst.owner]
	ps.remove_from_current_zone(inst)
	if inst.type() == CardEnums.TYPE_BANNER and not ps.battle_area_full():
		inst.zone = CardEnums.ZONE_BATTLE
		inst.exhausted = false
		inst.summoning_sick = true
		inst.played_on_turn = state.turn_number
		ps.battle_area.append(inst)
		state.log_event("play_self", { "uid": inst.uid, "card": inst.data.id })
		_fire(inst, CardEnums.EV_ON_PLAY)
	else:
		inst.zone = CardEnums.ZONE_HAND
		ps.hand.append(inst)


# --- selection helpers ----------------------------------------------------

## Enemy Banners matching a filter, ranked best-first (highest power). Filter
## keys: max_cost, max_power, require_rested.
func select_enemy_banners(owner: int, filter: Dictionary, up_to: int) -> Array:
	var enemy: PlayerState = state.players[state.opponent_of(owner)]
	var pool: Array = []
	for b in enemy.battle_area:
		if filter.has("max_cost") and b.data.cost > int(filter["max_cost"]):
			continue
		if filter.has("max_power") and b.data.power > int(filter["max_power"]):
			continue
		if filter.get("require_rested", false) and not b.exhausted:
			continue
		pool.append(b)
	pool.sort_custom(func(a, b): return a.data.power > b.data.power)
	return pool.slice(0, up_to)


## Own Banners matching a filter. Filter keys: filter_tribe, max_cost,
## only_exhausted, exclude.
func select_own_banners(owner: int, filter: Dictionary, up_to: int) -> Array:
	var ps: PlayerState = state.players[owner]
	var tribe := str(filter.get("filter_tribe", ""))
	var pool: Array = []
	for b in ps.battle_area:
		if filter.get("exclude", null) == b:
			continue
		if not tribe.is_empty() and b.data.tribe != tribe:
			continue
		if filter.has("max_cost") and b.data.cost > int(filter["max_cost"]):
			continue
		if filter.get("only_exhausted", false) and not b.exhausted:
			continue
		pool.append(b)
	pool.sort_custom(func(a, b): return a.data.power > b.data.power)
	return pool.slice(0, up_to)


# --- cost reduction -------------------------------------------------------

func add_cost_charge(owner: int, amount: int, tribe: String, minimum: int) -> void:
	state.players[owner].cost_charges.append({
		"amount": amount, "filter_tribe": tribe, "minimum": minimum,
	})


## At the start of the turn, seed passive cost-reduction charges (e.g. Idris
## Vale's once-per-turn Bulwark discount).
func _prime_cost_charges(owner: int) -> void:
	var ps: PlayerState = state.players[owner]
	ps.cost_charges.clear()
	var vg: CardInstance = ps.vanguard
	if vg == null:
		return
	for eff in vg.data.effects:
		if str(eff.get("trigger", "")) != CardEnums.EV_PASSIVE:
			continue
		var act: Dictionary = eff.get("action", {})
		if str(act.get("type", "")) == CardEnums.ACT_COST_REDUCTION \
				and str(act.get("applies", "")) == "banner_play":
			add_cost_charge(owner, int(act.get("amount", 1)),
				str(act.get("filter_tribe", "")), int(act.get("minimum", 1)))


func _effective_play_cost(owner: int, inst: CardInstance) -> int:
	var cost := inst.data.cost
	var minimum := 0
	var reduction := 0
	for charge in state.players[owner].cost_charges:
		var tribe := str(charge.get("filter_tribe", ""))
		if not tribe.is_empty() and inst.data.tribe != tribe:
			continue
		reduction += int(charge.get("amount", 0))
		minimum = max(minimum, int(charge.get("minimum", 1)))
	if reduction == 0:
		return cost
	return max(minimum, cost - reduction)


func _consume_cost_charges(owner: int, inst: CardInstance) -> void:
	var remaining: Array = []
	for charge in state.players[owner].cost_charges:
		var tribe := str(charge.get("filter_tribe", ""))
		if tribe.is_empty() or inst.data.tribe == tribe:
			continue  # consumed by this play
		remaining.append(charge)
	state.players[owner].cost_charges = remaining


# =========================================================================
# Power (with passive, conditional layers)
# =========================================================================

## Combat power for `inst`: printed + temporary bonuses + any applicable
## passive buffs from the controller's Vanguard/Stage (Dreyse, Old Hollow,
## Siegeworks). Recomputed on demand so thresholds apply dynamically.
func effective_power(inst: CardInstance) -> int:
	return inst.current_power() + _passive_power_for(inst)


func _passive_power_for(inst: CardInstance) -> int:
	var total := 0
	var ps: PlayerState = state.players[inst.owner]
	var sources: Array = []
	if ps.vanguard:
		sources.append(ps.vanguard)
	if ps.stage:
		sources.append(ps.stage)
	for src in sources:
		for eff in src.data.effects:
			if str(eff.get("trigger", "")) != CardEnums.EV_PASSIVE:
				continue
			var act: Dictionary = eff.get("action", {})
			if str(act.get("type", "")) != CardEnums.ACT_POWER_BUFF:
				continue
			if not _passive_gate(eff, inst.owner):
				continue
			if _passive_hits(act, inst):
				total += int(act.get("amount", 0))
	return total


func _passive_gate(eff: Dictionary, owner: int) -> bool:
	var phase := str(eff.get("phase", ""))
	if phase == "your_turn" and state.active_player != owner:
		return false
	if phase == "opponent_turn" and state.active_player == owner:
		return false
	var cond: Dictionary = eff.get("condition", {})
	if cond.has("min_aura_total") and state.players[owner].aura_total < int(cond["min_aura_total"]):
		return false
	return true


func _passive_hits(act: Dictionary, inst: CardInstance) -> bool:
	match str(act.get("target", "")):
		CardEnums.TGT_OWN_VANGUARD:
			return inst.type() == CardEnums.TYPE_VANGUARD
		CardEnums.TGT_OWN_BANNERS, CardEnums.TGT_OWN_BANNER:
			if inst.type() != CardEnums.TYPE_BANNER:
				return false
			var tribe := str(act.get("filter_tribe", ""))
			if not tribe.is_empty() and inst.data.tribe != tribe:
				return false
			var kw := str(act.get("filter_keyword", ""))
			if not kw.is_empty() and not inst.has_keyword(kw):
				return false
			return true
		_:
			return false


# =========================================================================
# Watch-list + shared helpers
# =========================================================================

func note_watch(key: String, amount: int = 1) -> void:
	state.watch[key] = int(state.watch.get(key, 0)) + amount


func _declare_winner(idx: int, reason: String) -> void:
	if state.game_over:
		return
	state.winner = idx
	state.game_over = true
	state.log_event("game_over", { "winner": idx, "reason": reason })


func _clear_all_battle_bonuses() -> void:
	for ps in state.players:
		if ps.vanguard:
			ps.vanguard.clear_battle_bonus()
		for b in ps.battle_area:
			b.clear_battle_bonus()
		if ps.stage:
			ps.stage.clear_battle_bonus()


func _clear_all_turn_bonuses() -> void:
	for ps in state.players:
		if ps.vanguard:
			ps.vanguard.clear_turn_bonus()
		for b in ps.battle_area:
			b.clear_turn_bonus()
		if ps.stage:
			ps.stage.clear_turn_bonus()


func _make_instance(cd: CardData, owner: int) -> CardInstance:
	_uid_counter += 1
	return CardInstance.new(cd, owner, _uid_counter)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := state.rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
