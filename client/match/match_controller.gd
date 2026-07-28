class_name MatchController
extends Node

## Drives one human-vs-AI match on top of the FROZEN engine. It is the only
## client object that talks to GameEngine, and it does so exclusively through
## the public API the AI policies already use — it never reaches into engine
## internals and carries no rules of its own.
##
## Two output channels, both derived purely from public data:
##   * presentation — every new `state.log` entry is translated into a beat and
##     pushed to an owned PresentationQueue (the board animates from that).
##   * prompts — when the HUMAN must decide (mulligan, defence, life trigger) the
##     controller pauses and emits a signal; the UI (or a test) answers via the
##     matching answer_* method. Everything is synchronous and script-drivable:
##     no coroutine waits, so a headless test can play a full game by calling
##     methods and responding to signals.
##
## The AI opponent uses the archetype pilot for its Vanguard. Because the engine
## resolves an attack atomically (attacker + defender choices up front), the AI
## attack loop is stepped here so the human defender can be prompted before each
## declaration; the AI's own main phase is delegated to the pilot unchanged.

signal prompt_mulligan(seat: int, hand: Array)
signal prompt_defense(attacker: CardInstance, target: CardInstance, options: Dictionary)
signal prompt_life_trigger(card: CardInstance)
signal turn_began(seat: int, turn: int)
signal board_dirty()
signal match_over(winner: int)

const HUMAN := 0
const AI := 1

const _DURATION := {
	"turn_start": 0.35,
	"play_banner": 0.55,
	"play_self": 0.55,
	"play_technique": 0.40,
	"play_stage": 0.40,
	"activate_main": 0.30,
	"attach_aura": 0.20,
	"blocker": 0.30,
	"attack": 0.90,
	"ko": 0.45,
	"freeze_banner": 0.45,
	"freeze_aura": 0.30,
	"bounce": 0.45,
	"game_over": 0.60,
}

var engine: GameEngine
var queue: PresentationQueue
var ai_policy: AIPolicy
var human_vg_id: String = ""
var ai_vg_id: String = ""
var auto_prompts: bool = false          # tests: auto-answer human prompts

var _phase: String = "idle"
var _log_cursor: int = 0
var _pending_attack: Dictionary = {}
var _pending_def: Dictionary = {}


func _ready() -> void:
	if queue == null:
		queue = PresentationQueue.new()
		add_child(queue)


## Build both decks, seat the players, and open the mulligan step.
## `first` is which seat takes turn 1 (default: the human).
func begin_match(p_human_vg: String, p_ai_vg: String, seed_value: int = 0,
		first: int = HUMAN) -> void:
	human_vg_id = p_human_vg
	ai_vg_id = p_ai_vg
	if queue == null:
		queue = PresentationQueue.new()
		add_child(queue)

	var van0 := DeckFactory.card(human_vg_id)
	var van1 := DeckFactory.card(ai_vg_id)
	var deck0 := DeckFactory.deck_for(van0)
	var deck1 := DeckFactory.deck_for(van1)

	engine = GameEngine.new(seed_value)
	engine.setup(deck0, van0, deck1, van1, first)
	ai_policy = AIPolicy.for_vanguard(ai_vg_id)
	_log_cursor = engine.state.log.size()   # setup entries need no beats

	_phase = "mulligan_human"
	if auto_prompts:
		answer_mulligan(true)
	else:
		prompt_mulligan.emit(HUMAN, engine.state.players[HUMAN].hand.duplicate())


# =========================================================================
# Mulligan
# =========================================================================

func answer_mulligan(keep: bool) -> void:
	if _phase != "mulligan_human":
		return
	if not keep:
		engine.mulligan(HUMAN)
	if ai_policy.want_mulligan(engine, AI):
		engine.mulligan(AI)
	engine.start_game()
	_log_cursor = engine.state.log.size()   # game_start is not a beat
	board_dirty.emit()
	_advance_turn()


# =========================================================================
# Turn flow
# =========================================================================

func _advance_turn() -> void:
	if engine.state.game_over:
		_finish()
		return
	var seat := engine.begin_turn()
	if seat < 0:
		_finish()
		return
	_flush_beats()
	turn_began.emit(seat, engine.state.turn_number)
	board_dirty.emit()
	if seat == HUMAN:
		_phase = "human_turn"
	else:
		_run_ai_turn()


func _run_ai_turn() -> void:
	_phase = "ai_turn"
	ai_policy.do_main_phase(engine, AI)
	_flush_beats()
	board_dirty.emit()
	_step_ai_attacks()


## Step the AI's attacks one declaration at a time. Pauses (returns) whenever a
## declaration would hit the human, so the human can be prompted to defend;
## resumed from answer_defense / answer_life_trigger.
func _step_ai_attacks() -> void:
	while not engine.state.game_over:
		var attacker: CardInstance = ai_policy.choose_attacker(engine, AI)
		if attacker == null:
			break
		var target: CardInstance = ai_policy.choose_target(engine, AI, attacker)
		if target == null:
			break
		var atk_choices: Dictionary = ai_policy.attacker_choices(engine, AI, attacker, target)
		if target.owner == HUMAN:
			_pending_attack = { "attacker": attacker, "target": target, "atk": atk_choices }
			_phase = "await_defense"
			if auto_prompts:
				answer_defense({})
			else:
				prompt_defense.emit(attacker, target, _defense_options(target))
			return   # resumes when the human answers
		_resolve_attack(attacker, target, atk_choices, {})
	_end_ai_turn()


func _end_ai_turn() -> void:
	if engine.state.game_over:
		_finish()
		return
	engine.end_turn()
	_flush_beats()
	board_dirty.emit()
	_advance_turn()


# =========================================================================
# Human defence (against an AI attack)
# =========================================================================

func _defense_options(target: CardInstance) -> Dictionary:
	var ps: PlayerState = engine.state.players[HUMAN]
	var blockers: Array = []
	if target == ps.vanguard:
		for b in ps.battle_area:
			if b.has_keyword(CardEnums.KW_BLOCKER) and not b.exhausted:
				blockers.append(b)
	var counter_cards: Array = []
	for c in ps.hand:
		if c.data.counter > 0:
			counter_cards.append(c)
	return {
		"target_is_vanguard": target == ps.vanguard,
		"blockers": blockers,
		"counter_cards": counter_cards,
	}


## Answer the defence prompt. `choice` may contain:
##   "counter_uids": Array[int]  — hand cards to pitch for counter value
##   "blocker_uid": int          — a Blocker to interpose (or -1/absent)
func answer_defense(choice: Dictionary) -> void:
	if _phase != "await_defense":
		return
	var ps: PlayerState = engine.state.players[HUMAN]
	var def_choices: Dictionary = { "resolve_trigger": true }

	var counters: Array = []
	for uid in choice.get("counter_uids", []):
		var c := _find_in_hand(HUMAN, int(uid))
		if c != null and c.data.counter > 0:
			counters.append(c)
	if not counters.is_empty():
		def_choices["counter_cards"] = counters

	var blocker: CardInstance = null
	var buid := int(choice.get("blocker_uid", -1))
	if buid >= 0:
		blocker = _find_in_battle(HUMAN, buid)
		if blocker != null:
			def_choices["blocker"] = blocker

	# Predict whether this reaches Life so we can show the trigger reveal. Only
	# counter-value cards affect the math here (counter techniques are AI-side).
	var attacker: CardInstance = _pending_attack["attacker"]
	var target: CardInstance = _pending_attack["target"]
	var attach := int(_pending_attack["atk"].get("attach_aura", 0))
	var final_target: CardInstance = blocker if blocker != null else target
	var atk_power := engine.effective_power(attacker) + attach * 1000
	var def_power := engine.effective_power(final_target)
	for c in counters:
		def_power += c.data.counter

	var face_hit := final_target == ps.vanguard and atk_power >= def_power
	if face_hit and not ps.life.is_empty() \
			and not ps.life[0].data.effects_for(CardEnums.EV_LIFE_TRIGGER).is_empty():
		_pending_def = def_choices
		_phase = "await_life"
		if auto_prompts:
			answer_life_trigger(true)
		else:
			prompt_life_trigger.emit(ps.life[0])
		return

	_resolve_attack(attacker, target, _pending_attack["atk"], def_choices)
	_step_ai_attacks()


func answer_life_trigger(resolve: bool) -> void:
	if _phase != "await_life":
		return
	var def_choices := _pending_def
	def_choices["resolve_trigger"] = resolve
	var attacker: CardInstance = _pending_attack["attacker"]
	var target: CardInstance = _pending_attack["target"]
	_resolve_attack(attacker, target, _pending_attack["atk"], def_choices)
	_step_ai_attacks()


# =========================================================================
# Human turn actions (called by the UI / tests). All return the engine result.
# =========================================================================

func human_play_card(inst: CardInstance) -> bool:
	if not _human_can_act():
		return false
	var ok := engine.play_card(HUMAN, inst)
	_after_human_action()
	return ok


func human_activate(inst: CardInstance) -> bool:
	if not _human_can_act():
		return false
	var ok := engine.activate_main(inst)
	_after_human_action()
	return ok


func human_attach_aura(inst: CardInstance) -> bool:
	if not _human_can_act():
		return false
	var ok := engine.attach_aura(HUMAN, inst)
	_after_human_action()
	return ok


func human_legal_attack_targets(attacker: CardInstance) -> Array:
	if not _human_can_act() or not engine.can_attack(attacker):
		return []
	return engine.legal_attack_targets(attacker)


func human_declare_attack(attacker: CardInstance, target: CardInstance,
		attach_aura: int = 0) -> Dictionary:
	if not _human_can_act():
		return { "ok": false }
	var atk_choices := { "attach_aura": attach_aura }
	var def_choices: Dictionary = ai_policy.defender_choices(engine, AI, attacker, target)
	var result := engine.declare_attack(attacker, target, atk_choices, def_choices)
	_flush_beats()
	board_dirty.emit()
	if engine.state.game_over:
		_finish()
	return result


func human_end_turn() -> void:
	if not _human_can_act():
		return
	engine.end_turn()
	_flush_beats()
	board_dirty.emit()
	_advance_turn()


# =========================================================================
# Queries for the UI
# =========================================================================

func is_human_turn() -> bool:
	return _phase == "human_turn"


func phase() -> String:
	return _phase


func active_seat() -> int:
	return engine.state.active_player if engine != null else -1


func player(seat: int) -> PlayerState:
	return engine.state.players[seat]


# =========================================================================
# Internals
# =========================================================================

func _human_can_act() -> bool:
	return _phase == "human_turn" and engine != null and not engine.state.game_over \
		and engine.state.active_player == HUMAN


func _after_human_action() -> void:
	_flush_beats()
	board_dirty.emit()
	if engine.state.game_over:
		_finish()


func _resolve_attack(attacker: CardInstance, target: CardInstance,
		atk_choices: Dictionary, def_choices: Dictionary) -> void:
	engine.declare_attack(attacker, target, atk_choices, def_choices)
	_pending_attack = {}
	_pending_def = {}
	_flush_beats()
	board_dirty.emit()


func _finish() -> void:
	if _phase == "over":
		return
	_flush_beats()
	_phase = "over"
	match_over.emit(engine.state.winner)


func _find_in_hand(seat: int, uid: int) -> CardInstance:
	for c in engine.state.players[seat].hand:
		if c.uid == uid:
			return c
	return null


func _find_in_battle(seat: int, uid: int) -> CardInstance:
	for c in engine.state.players[seat].battle_area:
		if c.uid == uid:
			return c
	return null


# --- log -> beats ---------------------------------------------------------

func _flush_beats() -> void:
	var log: Array = engine.state.log
	while _log_cursor < log.size():
		var entry: Dictionary = log[_log_cursor]
		_log_cursor += 1
		var beat := _beat_for(entry)
		if not beat.is_empty():
			queue.enqueue(beat)


func _beat_for(entry: Dictionary) -> Dictionary:
	var kind := str(entry.get("kind", ""))
	if not _DURATION.has(kind):
		return {}
	var beat := entry.duplicate(true)
	beat["duration"] = _DURATION[kind]
	return beat
