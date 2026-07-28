class_name AIPolicy
extends RefCounted

## Scripted, deterministic AI used by the headless simulator. Two styles:
##
##   "aggro" - play on curve, always attack the enemy Vanguard, never defend.
##             Races the opponent's Life to zero.
##   "guard" - play on curve, clear exhausted enemy Banners first, and use a
##             Blocker / counter cards to defend the Vanguard when Life is low.
##
## Policies never reach into private engine state; they only call the public
## GameEngine API, so they double as living documentation of that API.

var name: String = "aggro"
var style: String = "aggro"


func _init(policy_style: String = "aggro") -> void:
	style = policy_style
	name = policy_style


# --- Mulligan -------------------------------------------------------------

## Mulligan a hand that cannot act early: keep only if it has at least two
## cards costing 2 or less.
func want_mulligan(game: GameEngine, player: int) -> bool:
	var cheap := 0
	for inst in game.state.players[player].hand:
		if inst.data.cost <= 2:
			cheap += 1
	return cheap < 2


# --- Main phase -----------------------------------------------------------

## Play on curve: deploy a Stage if useful, then the most expensive affordable
## Banner while Battle Area space remains, then fire any main-phase abilities.
func do_main_phase(game: GameEngine, player: int) -> void:
	var ps: PlayerState = game.state.players[player]

	# Deploy a Stage if we hold one and none is in play.
	if ps.stage == null:
		var stage := _cheapest_of_type(ps.hand, CardEnums.TYPE_STAGE, ps.aura_available())
		if stage != null:
			game.play_card(player, stage)

	# Deploy Banners on curve (most expensive first), up to the area cap.
	var progressed := true
	while progressed and not ps.battle_area_full():
		progressed = false
		var pick := _best_affordable_banner(ps.hand, ps.aura_available())
		if pick != null:
			if game.play_card(player, pick):
				progressed = true

	# Fire [Activate: Main] abilities (e.g. buff the Vanguard before attacks).
	for b in ps.battle_area:
		if b.has_keyword(CardEnums.KW_ACTIVATE_MAIN):
			game.activate_main(b)


# --- Attacks --------------------------------------------------------------

## Next unit that can legally attack, or null when the turn's attacks are done.
func choose_attacker(game: GameEngine, player: int) -> CardInstance:
	var ps: PlayerState = game.state.players[player]
	if ps.vanguard and game.can_attack(ps.vanguard):
		return ps.vanguard
	for b in ps.battle_area:
		if game.can_attack(b):
			return b
	return null


## Aggro hits the Vanguard; guard clears an exhausted enemy Banner first.
func choose_target(game: GameEngine, player: int, attacker: CardInstance) -> CardInstance:
	var targets := game.legal_attack_targets(attacker)
	var enemy: PlayerState = game.state.players[game.state.opponent_of(player)]
	if style == "guard":
		for t in targets:
			if t != enemy.vanguard and t.type() == CardEnums.TYPE_BANNER:
				return t
	return enemy.vanguard


## Attach just enough Aura to make the hit connect against the target's
## current power; never waste Aura beyond that.
func attacker_choices(game: GameEngine, player: int, attacker: CardInstance, target: CardInstance) -> Dictionary:
	var deficit := target.current_power() - attacker.current_power()
	var attach := 0
	if deficit > 0:
		attach = min(int(ceil(float(deficit) / 1000.0)), game.state.players[player].aura_available())
	return { "attach_aura": attach }


## Defensive decisions. Aggro never defends; guard blocks / counters to protect
## its Vanguard when Life is running out.
func defender_choices(game: GameEngine, defender: int, attacker: CardInstance, target: CardInstance) -> Dictionary:
	var choices := { "resolve_trigger": true }
	if style != "guard":
		return choices
	var ps: PlayerState = game.state.players[defender]
	var defending_vanguard := (target == ps.vanguard)
	if not defending_vanguard or ps.life.size() > 1:
		return choices

	# Life is low: throw up a Blocker if we have one.
	for b in ps.battle_area:
		if b.has_keyword(CardEnums.KW_BLOCKER) and not b.exhausted:
			choices["blocker"] = b
			break

	# And pitch counter-value cards from hand to survive the swing.
	var need := attacker.current_power()
	var block_power := 0
	if choices.has("blocker"):
		block_power = choices["blocker"].current_power()
	else:
		block_power = ps.vanguard.current_power()
	var counters: Array = []
	if block_power < need:
		for c in ps.hand:
			if c.data.counter > 0:
				counters.append(c)
				block_power += c.data.counter
				if block_power >= need:
					break
	if not counters.is_empty():
		choices["counter_cards"] = counters
	return choices


# --- helpers --------------------------------------------------------------

func _best_affordable_banner(hand: Array, aura: int) -> CardInstance:
	var best: CardInstance = null
	for inst in hand:
		if inst.type() != CardEnums.TYPE_BANNER:
			continue
		if inst.data.cost > aura:
			continue
		if best == null or inst.data.cost > best.data.cost:
			best = inst
	return best


func _cheapest_of_type(hand: Array, type: String, aura: int) -> CardInstance:
	var best: CardInstance = null
	for inst in hand:
		if inst.type() != type or inst.data.cost > aura:
			continue
		if best == null or inst.data.cost < best.data.cost:
			best = inst
	return best
