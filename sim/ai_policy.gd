class_name AIPolicy
extends RefCounted

## Scripted, deterministic AI for the headless simulator. Two styles:
##
##   "aggro" - play on curve, attack the enemy Vanguard, never defend.
##   "guard" - play on curve, clear rested/frozen enemy Banners first, defend
##             the Vanguard with a Blocker / counter cards when Life is low.
##
## Both styles understand Rush (a fresh Banner with Rush can attack) and Freeze
## (a frozen enemy Banner stays rested next turn, so it is a safe attack target
## and a poor block), so the balance watch-list flags are meaningful.
##
## Policies only call the public GameEngine API, so they also document it.

var name: String = "aggro"
var style: String = "aggro"


func _init(policy_style: String = "aggro") -> void:
	style = policy_style
	name = policy_style


# --- Mulligan -------------------------------------------------------------

func want_mulligan(game: GameEngine, player: int) -> bool:
	var cheap := 0
	for inst in game.state.players[player].hand:
		if inst.data.cost <= 2:
			cheap += 1
	return cheap < 2


# --- Main phase -----------------------------------------------------------

func do_main_phase(game: GameEngine, player: int) -> void:
	var ps: PlayerState = game.state.players[player]

	# Deploy a Stage if we hold one and none is in play, then activate the
	# Stage ability BEFORE Banners (cost reduction / board control help now).
	if ps.stage == null:
		var stage := _cheapest_of_type(ps.hand, CardEnums.TYPE_STAGE, ps.aura_available())
		if stage != null:
			game.play_card(player, stage)
	if ps.stage != null:
		game.activate_main(ps.stage)

	# Deploy Banners on curve (most expensive affordable first).
	var progressed := true
	while progressed and not ps.battle_area_full():
		progressed = false
		var pick := _best_affordable_banner(game, ps, player)
		if pick != null and game.play_card(player, pick):
			progressed = true

	# Main-phase Techniques with a board-affecting effect (rest/ko/freeze/
	# bounce) — play the cheapest we can afford, once.
	var tech := _useful_main_technique(game, ps, player)
	if tech != null:
		game.play_card(player, tech)

	# Now that Banners are deployed, fire the Vanguard ability (e.g. Sora's
	# buff + Rush rider needs a Banner on board) and any Banner abilities.
	game.activate_main(ps.vanguard)
	for b in ps.battle_area:
		game.activate_main(b)


# --- Attacks --------------------------------------------------------------

func choose_attacker(game: GameEngine, player: int) -> CardInstance:
	var ps: PlayerState = game.state.players[player]
	if ps.vanguard and game.can_attack(ps.vanguard):
		return ps.vanguard
	# Highest-power ready Banner first (Rush-aware via can_attack).
	var best: CardInstance = null
	for b in ps.battle_area:
		if game.can_attack(b) and (best == null or game.effective_power(b) > game.effective_power(best)):
			best = b
	return best


func choose_target(game: GameEngine, player: int, attacker: CardInstance) -> CardInstance:
	var targets := game.legal_attack_targets(attacker)
	var enemy: PlayerState = game.state.players[game.state.opponent_of(player)]
	if style == "guard":
		# Clear the strongest rested/frozen enemy Banner we can beat.
		var best: CardInstance = null
		for t in targets:
			if t == enemy.vanguard or t.type() != CardEnums.TYPE_BANNER:
				continue
			if game.effective_power(attacker) >= game.effective_power(t):
				if best == null or game.effective_power(t) > game.effective_power(best):
					best = t
		if best != null:
			return best
	return enemy.vanguard


func attacker_choices(game: GameEngine, player: int, attacker: CardInstance, target: CardInstance) -> Dictionary:
	var deficit := game.effective_power(target) - game.effective_power(attacker)
	var attach := 0
	if deficit > 0:
		attach = min(int(ceil(float(deficit) / 1000.0)), game.state.players[player].aura_available())
	return { "attach_aura": attach }


func defender_choices(game: GameEngine, defender: int, attacker: CardInstance, target: CardInstance) -> Dictionary:
	var choices := { "resolve_trigger": true }
	if style != "guard":
		return choices
	var ps: PlayerState = game.state.players[defender]
	if target != ps.vanguard or ps.life.size() > 1:
		return choices

	# Life is low: block with a ready Blocker (never a frozen/rested one).
	for b in ps.battle_area:
		if b.has_keyword(CardEnums.KW_BLOCKER) and not b.exhausted:
			choices["blocker"] = b
			break

	var need := game.effective_power(attacker)
	var block_power := 0
	if choices.has("blocker"):
		block_power = game.effective_power(choices["blocker"])
	else:
		block_power = game.effective_power(ps.vanguard)
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

func _best_affordable_banner(game: GameEngine, ps: PlayerState, player: int) -> CardInstance:
	var best: CardInstance = null
	var best_cost := -1
	for inst in ps.hand:
		if inst.type() != CardEnums.TYPE_BANNER:
			continue
		var cost: int = game._effective_play_cost(player, inst)
		if cost > ps.aura_available():
			continue
		if cost > best_cost:
			best = inst
			best_cost = cost
	return best


func _useful_main_technique(game: GameEngine, ps: PlayerState, player: int) -> CardInstance:
	# Only bother with a main Technique if it can affect the board and there is
	# an enemy Banner to affect.
	var enemy: PlayerState = game.state.players[game.state.opponent_of(player)]
	if enemy.battle_area.is_empty():
		return null
	var best: CardInstance = null
	for inst in ps.hand:
		if inst.type() != CardEnums.TYPE_TECHNIQUE or inst.data.cost > ps.aura_available():
			continue
		var affects := false
		for eff in inst.data.effects:
			if str(eff.get("trigger", "")) == CardEnums.EV_MAIN:
				affects = true
				break
		if affects and (best == null or inst.data.cost < best.data.cost):
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
