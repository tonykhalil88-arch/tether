class_name AIPolicy
extends RefCounted

## Archetype-aware scripted pilots — one gameplan per Vanguard kit. The policy
## is chosen automatically from the Vanguard id (for_vanguard). Every policy is
## deterministic under a fixed seed and drives a whole turn via play_turn().
##
## Archetypes (Vanguard -> plan):
##   rush            (Sora)  - deploy, convert the Vanguard buff into extra
##                             damage (Rush rider), swing with everything.
##   rest_punish     (Kaya)  - rest a target, then attack rested Banners with
##                             the Bo & Lantern line.
##   refresh_tempo   (Bram)  - attack, then spend refresh effects (Stampede
##                             Doctrine, Bram, Korgan) for extra attacks.
##   lockdown        (Neza)  - rest + freeze the biggest threat, hold Blockers.
##   filter_control  (Averil)- filter every turn, hold counters, bounce curve
##                             threats, win late.
##   discount_deploy (Vale)  - sequence Canyon Bastion + discount, then drop the
##                             biggest affordable Bulwark.
##   drain           (Rue)   - maximise Aura frozen per turn, trade evenly.
##   threshold_ramp  (Dreyse)- ramp to 8+ Aura, leverage the threshold, deploy
##                             the Walkbreaker.

const ARCHETYPE_BY_VANGUARD := {
	"wm01-001": "rush",
	"wm01-012": "rest_punish",
	"wm01-023": "refresh_tempo",
	"wm01-034": "lockdown",
	"wm01-045": "filter_control",
	"wm01-056": "discount_deploy",
	"wm01-067": "drain",
	"wm01-078": "threshold_ramp",
}

# Kit ids for signature lines.
const STAMPEDE_DOCTRINE := "wm01-032"
const CONTROL_ARCHETYPES := ["lockdown", "filter_control", "drain"]

var archetype: String = "rush"
var name: String = "rush"
var _manufacture_turn: int = -1   # refresh_tempo: extra-attack latch per turn


func _init(a: String = "rush") -> void:
	archetype = a
	name = a


static func for_vanguard(vg_id: String) -> AIPolicy:
	return AIPolicy.new(ARCHETYPE_BY_VANGUARD.get(vg_id, "rush"))


# =========================================================================
# Turn driver
# =========================================================================

func play_turn(game: GameEngine, me: int, opponent: AIPolicy) -> void:
	do_main_phase(game, me)
	run_attacks(game, me, opponent)


func run_attacks(game: GameEngine, me: int, opponent: AIPolicy) -> void:
	var opp := game.state.opponent_of(me)
	var guard := 0
	while not game.state.game_over:
		guard += 1
		if guard > 96:
			break
		var attacker: CardInstance = choose_attacker(game, me)
		if attacker == null:
			break
		var target: CardInstance = choose_target(game, me, attacker)
		if target == null:
			break
		var atk_choices: Dictionary = attacker_choices(game, me, attacker, target)
		var def_choices: Dictionary = opponent.defender_choices(game, opp, attacker, target)
		game.declare_attack(attacker, target, atk_choices, def_choices)


# =========================================================================
# Mulligan
# =========================================================================

func want_mulligan(game: GameEngine, player: int) -> bool:
	var cheap := 0
	for inst in game.state.players[player].hand:
		if inst.data.cost <= 2:
			cheap += 1
	return cheap < 2


# =========================================================================
# Main phase
# =========================================================================

func do_main_phase(game: GameEngine, me: int) -> void:
	var ps: PlayerState = game.state.players[me]

	# Stage first (Canyon discount / board-control help before Banners).
	if ps.stage == null:
		var stage := _cheapest_of_type(ps.hand, CardEnums.TYPE_STAGE, ps.aura_available())
		if stage != null:
			game.play_card(me, stage)
	if ps.stage != null:
		game.activate_main(ps.stage)

	# filter_control filters FIRST (Averil) so it deploys off better cards.
	if archetype == "filter_control":
		game.activate_main(ps.vanguard)

	# Ramp / drain want their resource techniques down before committing.
	if archetype == "threshold_ramp" or archetype == "drain":
		_play_priority_techniques(game, me)

	_deploy_banners(game, me)
	_play_useful_techniques(game, me)

	# Vanguard ability: refresh_tempo reserves Bram's refresh for extra attacks
	# after the first combat, so it is NOT fired here.
	if archetype != "refresh_tempo":
		game.activate_main(ps.vanguard)
	for b in ps.battle_area:
		game.activate_main(b)


func _deploy_banners(game: GameEngine, me: int) -> void:
	var ps: PlayerState = game.state.players[me]
	var progressed := true
	while progressed and not ps.battle_area_full():
		progressed = false
		var pick := _best_affordable_banner(game, ps, me, _deploy_budget(ps))
		if pick != null and game.play_card(me, pick):
			progressed = true


## refresh_tempo keeps a small Aura reserve during deployment so it can still
## afford Stampede Doctrine / Bram's refresh for extra attacks after combat.
func _deploy_budget(ps: PlayerState) -> int:
	var reserve := 2 if archetype == "refresh_tempo" else 0
	return max(0, ps.aura_available() - reserve)


func _play_priority_techniques(game: GameEngine, me: int) -> void:
	# threshold_ramp: gain_aura techniques. drain: freeze-aura techniques.
	var want := CardEnums.ACT_GAIN_AURA if archetype == "threshold_ramp" else CardEnums.ACT_FREEZE
	var ps: PlayerState = game.state.players[me]
	for inst in ps.hand.duplicate():
		if inst.type() != CardEnums.TYPE_TECHNIQUE or inst.data.cost > ps.aura_available():
			continue
		if _technique_has_main_action(inst, want) and _technique_useful(game, me, inst):
			game.play_card(me, inst)


func _play_useful_techniques(game: GameEngine, me: int) -> void:
	# Play up to two more board-affecting main Techniques.
	var ps: PlayerState = game.state.players[me]
	var played := 0
	for inst in ps.hand.duplicate():
		if played >= 2:
			break
		if inst.type() != CardEnums.TYPE_TECHNIQUE or inst.data.cost > ps.aura_available():
			continue
		if _technique_useful(game, me, inst) and game.play_card(me, inst):
			played += 1


# =========================================================================
# Attacks
# =========================================================================

func choose_attacker(game: GameEngine, me: int) -> CardInstance:
	var a := _ready_attacker(game, me)
	if a != null:
		return a
	# refresh_tempo: manufacture extra attacks with refresh effects.
	if archetype == "refresh_tempo" and _manufacture_attacks(game, me):
		return _ready_attacker(game, me)
	return null


func _ready_attacker(game: GameEngine, me: int) -> CardInstance:
	var ps: PlayerState = game.state.players[me]
	# Vanguard swings first (rest_punish/drain want their on-attack effect early).
	if ps.vanguard and game.can_attack(ps.vanguard):
		return ps.vanguard
	var best: CardInstance = null
	for b in ps.battle_area:
		if not game.can_attack(b):
			continue
		# lockdown holds its Blockers back for defense.
		if archetype == "lockdown" and b.has_keyword(CardEnums.KW_BLOCKER):
			continue
		if best == null or game.effective_power(b) > game.effective_power(best):
			best = b
	return best


func choose_target(game: GameEngine, me: int, attacker: CardInstance) -> CardInstance:
	var enemy: PlayerState = game.state.players[game.state.opponent_of(me)]
	# Board-control / punish plans clear a beatable rested enemy Banner with a
	# Banner attacker (Bo & Lantern etc.); the Vanguard still hits face.
	if attacker != game.state.players[me].vanguard \
			and archetype in ["rest_punish", "lockdown", "filter_control", "drain", "generic"]:
		var best: CardInstance = null
		for t in game.legal_attack_targets(attacker):
			if t == enemy.vanguard or t.type() != CardEnums.TYPE_BANNER:
				continue
			if game.effective_power(attacker) >= game.effective_power(t):
				if best == null or game.effective_power(t) > game.effective_power(best):
					best = t
		if best != null:
			return best
	return enemy.vanguard


func attacker_choices(game: GameEngine, me: int, attacker: CardInstance, target: CardInstance) -> Dictionary:
	var deficit := game.effective_power(target) - game.effective_power(attacker)
	if deficit <= 0:
		return { "attach_aura": 0 }
	var need := int(ceil(float(deficit) / 1000.0))
	# refresh_tempo keeps 2 Aura in reserve for Stampede / Bram refreshes and
	# only attaches the surplus above it.
	var budget: int = game.state.players[me].aura_available()
	if archetype == "refresh_tempo":
		budget = max(0, budget - 2)
	return { "attach_aura": min(need, budget) }


func defender_choices(game: GameEngine, defender: int, attacker: CardInstance, target: CardInstance) -> Dictionary:
	var choices := { "resolve_trigger": true }
	var ps: PlayerState = game.state.players[defender]
	if target != ps.vanguard:
		return choices
	# Control plans defend earlier (Life <= 2); aggressive plans only when lethal.
	var threshold := 2 if archetype in CONTROL_ARCHETYPES else 1
	if ps.life.size() > threshold:
		return choices

	for b in ps.battle_area:
		if b.has_keyword(CardEnums.KW_BLOCKER) and not b.exhausted:
			choices["blocker"] = b
			break

	var need: int = game.effective_power(attacker)
	var block_power: int = game.effective_power(ps.vanguard)
	if choices.has("blocker"):
		block_power = game.effective_power(choices["blocker"])
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


# =========================================================================
# refresh_tempo: manufacture extra attacks
# =========================================================================

func _manufacture_attacks(game: GameEngine, me: int) -> bool:
	if _manufacture_turn == game.state.turn_number:
		return false
	_manufacture_turn = game.state.turn_number
	var ps: PlayerState = game.state.players[me]

	# Only worth it if the opponent still has Life to take and we have rested
	# Banners that could swing again.
	if game.state.players[game.state.opponent_of(me)].life.is_empty():
		return false
	var rested := 0
	for b in ps.battle_area:
		if b.exhausted and b.type() == CardEnums.TYPE_BANNER:
			rested += 1
	if rested == 0:
		return false

	var did := false
	# Stampede Doctrine: refresh two rested Pact Banners for a fresh swing.
	if _count_stampede_targets(ps) >= 2:
		for inst in ps.hand.duplicate():
			if inst.data.id == STAMPEDE_DOCTRINE and inst.data.cost <= ps.aura_available():
				if game.play_card(me, inst):
					did = true
				break
	# Bram's own refresh ability, reserved from the Main phase for this moment.
	if game.activate_main(ps.vanguard):
		did = true
	return did


func _count_stampede_targets(ps: PlayerState) -> int:
	# Stampede Doctrine refreshes rested Pact Banners of cost <= 3.
	var n := 0
	for b in ps.battle_area:
		if b.exhausted and b.type() == CardEnums.TYPE_BANNER \
				and b.data.tribe == "Pact" and b.data.cost <= 3:
			n += 1
	return n


# =========================================================================
# Helpers
# =========================================================================

func _best_affordable_banner(game: GameEngine, ps: PlayerState, me: int, budget: int = -1) -> CardInstance:
	var avail: int = ps.aura_available() if budget < 0 else budget
	# refresh_tempo goes wide with cost<=3 Pact bodies (the Stampede engine),
	# preferring the highest-power ones (Warband Outriders connect at 5000).
	if archetype == "refresh_tempo":
		var wide: CardInstance = null
		for inst in ps.hand:
			if inst.type() != CardEnums.TYPE_BANNER or inst.data.tribe != "Pact" or inst.data.cost > 3:
				continue
			if game._effective_play_cost(me, inst) > avail:
				continue
			if wide == null or inst.data.power > wide.data.power:
				wide = inst
		if wide != null:
			return wide
	var best: CardInstance = null
	var best_cost := -1
	for inst in ps.hand:
		if inst.type() != CardEnums.TYPE_BANNER:
			continue
		var cost: int = game._effective_play_cost(me, inst)
		if cost > avail:
			continue
		if cost > best_cost:
			best = inst
			best_cost = cost
	return best


func _technique_useful(game: GameEngine, me: int, inst: CardInstance) -> bool:
	var enemy: PlayerState = game.state.players[game.state.opponent_of(me)]
	var own: PlayerState = game.state.players[me]
	for eff in inst.data.effects:
		if str(eff.get("trigger", "")) != CardEnums.EV_MAIN:
			continue
		match str(eff.get("action", {}).get("type", "")):
			CardEnums.ACT_REST, CardEnums.ACT_KO, CardEnums.ACT_BOUNCE, CardEnums.ACT_REST_AND_FREEZE:
				if not enemy.battle_area.is_empty():
					return true
			CardEnums.ACT_FREEZE:
				if str(eff["action"].get("target", "")) == CardEnums.TGT_ENEMY_AURA:
					if enemy.aura_total > 0:
						return true
				elif not enemy.battle_area.is_empty():
					return true
			CardEnums.ACT_GAIN_AURA:
				if own.aura_total < PlayerState.MAX_ACTIVE_AURA:
					return true
			CardEnums.ACT_REFRESH:
				for b in own.battle_area:
					if b.exhausted:
						return true
			CardEnums.ACT_DRAW, CardEnums.ACT_DRAW_THEN_BOTTOM:
				if not own.deck.is_empty():
					return true
	return false


func _technique_has_main_action(inst: CardInstance, action_type: String) -> bool:
	for eff in inst.data.effects:
		if str(eff.get("trigger", "")) == CardEnums.EV_MAIN \
				and str(eff.get("action", {}).get("type", "")) == action_type:
			return true
	return false


func _cheapest_of_type(hand: Array, type: String, aura: int) -> CardInstance:
	var best: CardInstance = null
	for inst in hand:
		if inst.type() != type or inst.data.cost > aura:
			continue
		if best == null or inst.data.cost < best.data.cost:
			best = inst
	return best
