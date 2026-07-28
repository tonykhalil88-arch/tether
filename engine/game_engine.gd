class_name GameEngine
extends RefCounted

## The rules engine. Owns a GameState and exposes the operations that players
## (AI policies or tests) invoke: setup, per-phase turn progression, main-phase
## plays, and combat resolution. Fully headless and deterministic given a seed.
##
## Turn structure (per the WILDMIGRATION rules):
##   1. Refresh  - unexhaust all your cards
##   2. Draw     - draw 1 (first player skips on turn 1 only)
##   3. Aura     - gain 2 (first player gains 1 on turn 1); pool capped at 10
##   4. Main     - interactive: plays, activations, aura attach, attacks
##   5. End      - end-of-turn effects expire
##
## Deck-out rule: a player who must draw from an empty deck loses. This is not
## in the printed rules but guarantees simulations terminate; it is documented
## in the README.

var state: GameState
var _uid_counter: int = 0
var _mulligan_used := [false, false]


func _init(seed_value: int = 0) -> void:
	state = GameState.new(seed_value)


# =========================================================================
# Setup
# =========================================================================

## Build both players from CardData deck lists + Vanguards, shuffle, draw 5.
## Deck lists are Arrays of CardData (typically 50 cards each).
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


## One free mulligan: shuffle the whole hand back and redraw 5. Returns false
## if this player has already mulliganed.
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


## Place Life and hand control to turn 1. Call after any mulligans.
func start_game() -> void:
	_place_life(0)
	_place_life(1)
	state.turn_number = 0
	state.active_player = state.opponent_of(state.first_player)  # begin_turn flips it
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

## Advance to the next player's turn and run Refresh, Draw and Aura. Leaves
## the game in the Main phase, ready for main-phase actions. Returns the index
## of the player whose turn it now is.
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

	# 2. Draw (first player skips on turn 1 only)
	state.phase = GameState.PHASE_DRAW
	if state.turn_number > 1:
		draw_cards(p, 1)

	# 3. Aura (first player's turn 1 gains only 1)
	state.phase = GameState.PHASE_AURA
	var gain := 1 if state.turn_number == 1 else 2
	state.players[p].gain_aura(gain)

	# 4. Main
	state.phase = GameState.PHASE_MAIN
	state.event_bus.emit(CardEnums.EV_ON_TURN_START, { "player": p, "game": self })
	state.log_event("turn_start", {
		"aura_total": state.players[p].aura_total,
		"hand": state.players[p].hand.size(),
	})
	return p


func _refresh_active_player() -> void:
	var ps: PlayerState = state.players[state.active_player]
	ps.refresh_all()
	# Own Banners shed summoning sickness and per-turn flags refresh.
	for b in ps.battle_area:
		b.summoning_sick = false
		b.flags.clear()
	if ps.vanguard:
		ps.vanguard.flags.clear()


## End the current turn: end-of-turn effects expire.
func end_turn() -> void:
	if state.game_over:
		return
	state.phase = GameState.PHASE_END
	state.event_bus.emit(CardEnums.EV_ON_TURN_END, {
		"player": state.active_player, "game": self,
	})
	_clear_all_battle_bonuses()
	state.log_event("turn_end", {})


# =========================================================================
# Card movement / drawing
# =========================================================================

func draw_cards(idx: int, n: int) -> void:
	for i in range(n):
		if state.game_over:
			return
		if state.players[idx].deck.is_empty():
			# Deck-out: this player loses.
			_declare_winner(state.opponent_of(idx), "deck_out")
			return
		_move_top_deck_to_hand(idx)


func _move_top_deck_to_hand(idx: int) -> void:
	var ps: PlayerState = state.players[idx]
	var inst: CardInstance = ps.deck.pop_front()
	inst.zone = CardEnums.ZONE_HAND
	ps.hand.append(inst)


# =========================================================================
# Main-phase actions
# =========================================================================

## Play a card from hand, paying its Aura cost. Returns true on success.
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
			if not ps.spend_aura(inst.data.cost):
				return false
			ps.hand.erase(inst)
			inst.zone = CardEnums.ZONE_BATTLE
			inst.exhausted = false
			inst.summoning_sick = true
			ps.battle_area.append(inst)
			_fire_on_play(inst)
			state.log_event("play_banner", { "card": inst.data.id, "uid": inst.uid })
			return true
		CardEnums.TYPE_TECHNIQUE:
			# Non-counter (main-phase) technique: one-shot then to trash.
			if not ps.spend_aura(inst.data.cost):
				return false
			ps.hand.erase(inst)
			inst.zone = CardEnums.ZONE_BATTLE  # transient
			_fire_on_play(inst)
			ps.send_to_trash(inst)
			state.log_event("play_technique", { "card": inst.data.id, "uid": inst.uid })
			return true
		CardEnums.TYPE_STAGE:
			if not ps.spend_aura(inst.data.cost):
				return false
			ps.hand.erase(inst)
			if ps.stage != null:
				ps.send_to_trash(ps.stage)  # only one Stage per player
			inst.zone = CardEnums.ZONE_STAGE
			inst.exhausted = false
			ps.stage = inst
			_fire_on_play(inst)
			state.log_event("play_stage", { "card": inst.data.id, "uid": inst.uid })
			return true
		_:
			return false


func _fire_on_play(inst: CardInstance) -> void:
	EffectEngine.fire(self, inst, CardEnums.EV_ON_PLAY, { "source": inst })
	state.event_bus.emit(CardEnums.EV_ON_PLAY, { "source": inst, "game": self })


## Activate an [Activate: Main] ability. Honours Once Per Turn.
func activate_main(inst: CardInstance) -> bool:
	if state.game_over or inst.owner != state.active_player or state.phase != GameState.PHASE_MAIN:
		return false
	if not inst.has_keyword(CardEnums.KW_ACTIVATE_MAIN):
		return false
	if inst.has_keyword(CardEnums.KW_ONCE_PER_TURN) and inst.flags.get("activated", false):
		return false
	EffectEngine.fire(self, inst, "activate_main", { "source": inst })
	inst.flags["activated"] = true
	state.log_event("activate_main", { "card": inst.data.id, "uid": inst.uid })
	return true


## Attach one Aura to a unit: exhaust 1 Aura for +1000 battle power.
func attach_aura(idx: int, target: CardInstance) -> bool:
	if target == null or target.owner != idx:
		return false
	if not state.players[idx].spend_aura(1):
		return false
	target.battle_power_bonus += 1000
	state.log_event("attach_aura", { "uid": target.uid, "power": target.current_power() })
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
		# Banners cannot attack the turn they are played unless they have Rush.
		if inst.summoning_sick and not inst.has_keyword(CardEnums.KW_RUSH):
			return false
		return true
	return false


## Legal defend targets for `attacker`: the enemy Vanguard or any EXHAUSTED
## enemy Banner.
func legal_attack_targets(attacker: CardInstance) -> Array:
	var out: Array = []
	var enemy: PlayerState = state.players[state.opponent_of(attacker.owner)]
	out.append(enemy.vanguard)
	for b in enemy.battle_area:
		if b.exhausted:
			out.append(b)
	return out


## Resolve a full attack. `atk_choices` / `def_choices` are decision dicts:
##   atk_choices: { "attach_aura": int }
##   def_choices: {
##       "blocker": CardInstance|null,           # unexhausted enemy Blocker
##       "counter_techniques": Array[CardInstance],  # [Counter] cards from hand
##       "counter_cards": Array[CardInstance],       # cards discarded for counter value
##       "resolve_trigger": bool,                     # resolve a revealed Trigger?
##   }
## Returns a result Dictionary describing the outcome.
func declare_attack(attacker: CardInstance, target: CardInstance,
		atk_choices: Dictionary = {}, def_choices: Dictionary = {}) -> Dictionary:
	var fail := { "ok": false }
	if not can_attack(attacker):
		return fail
	if not legal_attack_targets(attacker).has(target):
		return fail

	var defender_idx := state.opponent_of(attacker.owner)
	attacker.exhaust()

	# Attack declared / when-attacking effects.
	state.event_bus.emit(CardEnums.EV_ON_ATTACK_DECLARED, {
		"attacker": attacker, "target": target, "game": self,
	})
	EffectEngine.fire(self, attacker, CardEnums.EV_WHEN_ATTACKING,
		{ "attacker": attacker, "defender": target })

	# Attacker may attach Aura.
	var attach := int(atk_choices.get("attach_aura", 0))
	for i in range(attach):
		if not attach_aura(attacker.owner, attacker):
			break

	# Defender may declare a Blocker (redirects the attack).
	var current_target := target
	var blocker = def_choices.get("blocker", null)
	if blocker != null and _is_valid_blocker(blocker, defender_idx):
		blocker.exhaust()
		current_target = blocker
		state.log_event("blocker", { "uid": blocker.uid })

	# Defender plays [Counter] techniques and/or discards counter-value cards.
	var defense_bonus := _apply_defender_counters(defender_idx, current_target, def_choices)

	# Compare power.
	var atk_power := attacker.current_power()
	var def_power := current_target.current_power() + defense_bonus
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

	# [Counter] techniques played from hand.
	for tech in def_choices.get("counter_techniques", []):
		if tech == null or tech.zone != CardEnums.ZONE_HAND or tech.owner != defender_idx:
			continue
		if not tech.has_keyword(CardEnums.KW_COUNTER):
			continue
		if not ps.spend_aura(tech.data.cost):
			continue
		ps.hand.erase(tech)
		# A counter technique buffs the defender for this battle.
		EffectEngine.fire(self, tech, CardEnums.KW_COUNTER.to_lower(),
			{ "defender": target })
		# Fallback: if the tech has no structured counter effect, use its
		# printed counter value.
		if tech.data.effects_for(CardEnums.KW_COUNTER.to_lower()).is_empty():
			bonus += tech.data.counter
		ps.send_to_trash(tech)

	# Cards discarded from hand purely for their counter value.
	for card in def_choices.get("counter_cards", []):
		if card == null or card.zone != CardEnums.ZONE_HAND or card.owner != defender_idx:
			continue
		bonus += card.data.counter
		ps.send_to_trash(card)

	return bonus


func _resolve_life_hit(defender_idx: int, def_choices: Dictionary, result: Dictionary) -> void:
	var ps: PlayerState = state.players[defender_idx]
	if ps.life.is_empty():
		# Hit with no Life remaining: attacker wins the game.
		_declare_winner(state.opponent_of(defender_idx), "life_zero")
		return
	var card: CardInstance = ps.life.pop_front()
	var resolve_trigger := bool(def_choices.get("resolve_trigger", true))
	if card.has_keyword(CardEnums.KW_TRIGGER) and resolve_trigger:
		card.zone = CardEnums.ZONE_TRASH
		ps.trash.append(card)
		EffectEngine.fire(self, card, CardEnums.EV_ON_TRIGGER_REVEAL, { "source": card })
		state.event_bus.emit(CardEnums.EV_ON_TRIGGER_REVEAL, { "source": card, "game": self })
		result["trigger_resolved"] = true
	else:
		card.zone = CardEnums.ZONE_HAND
		ps.hand.append(card)
	result["life_remaining"] = ps.life.size()


# =========================================================================
# Shared helpers
# =========================================================================

func ko_unit(inst: CardInstance) -> void:
	var ps: PlayerState = state.players[inst.owner]
	ps.send_to_trash(inst)
	state.event_bus.emit(CardEnums.EV_ON_KO, { "unit": inst, "game": self })
	state.log_event("ko", { "uid": inst.uid, "card": inst.data.id })


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


func _make_instance(cd: CardData, owner: int) -> CardInstance:
	_uid_counter += 1
	return CardInstance.new(cd, owner, _uid_counter)


func _shuffle(arr: Array) -> void:
	# Fisher-Yates using the seeded RNG for determinism.
	for i in range(arr.size() - 1, 0, -1):
		var j := state.rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
