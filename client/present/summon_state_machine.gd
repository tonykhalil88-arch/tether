class_name SummonStateMachine
extends Node3D

## The "money feature": a per-card presentation state machine. Each card view
## owns one. It resolves the card's four presentation channels once (via
## AssetManifest) and, on every state, fires whichever of them apply:
##
##   sprite  — swap idle/attack sheet, animate frames, tint/scale for status
##   SFX     — summon / hit cues (AudioStreamPlayer3D)
##   VFX     — instance the card's strike scene at the strike moment
##   voice   — optional summon barks
##
## States: summon -> idle -> attack_windup -> strike -> return -> idle, plus the
## status flourishes damaged / ko / rested / frozen / bounce / refresh /
## life_trigger_reveal. Transient states auto-advance and emit `state_finished`
## so the PresentationQueue can pace beats against real animation. It carries NO
## rules: it reacts to states the MatchController tells it to enter.

signal state_finished(state: String)

const SUMMON := "summon"
const IDLE := "idle"
const ATTACK_WINDUP := "attack_windup"
const STRIKE := "strike"
const RETURN := "return"
const DAMAGED := "damaged"
const KO := "ko"
const RESTED := "rested"
const FROZEN := "frozen"
const BOUNCE := "bounce"
const REFRESH := "refresh"
const LIFE_TRIGGER_REVEAL := "life_trigger_reveal"

# Persistent states hold until told otherwise; transient ones auto-advance.
const _DURATION := {
	SUMMON: 0.45,
	ATTACK_WINDUP: 0.25,
	STRIKE: 0.30,
	RETURN: 0.25,
	DAMAGED: 0.30,
	REFRESH: 0.35,
	BOUNCE: 0.40,
	LIFE_TRIGGER_REVEAL: 0.50,
}
const _NEXT := {
	SUMMON: IDLE,
	ATTACK_WINDUP: STRIKE,
	STRIKE: RETURN,
	RETURN: IDLE,
	REFRESH: IDLE,
	LIFE_TRIGGER_REVEAL: IDLE,
}

var card_id: String = ""
var state: String = IDLE

var _bundle: Dictionary = {}
var _sprite: Sprite3D
var _sfx: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _rest_state: String = IDLE          # persistent state to fall back to
var _t: float = 0.0
var _frame_t: float = 0.0
var _hframes: int = 1
var _fps: int = 8
var _home := Vector3.ZERO


func setup(id: String) -> void:
	card_id = id
	_bundle = AssetManifest.resolve(id)

	_sprite = Sprite3D.new()
	_sprite.texture = _bundle.get("sprite_idle")
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_hframes = maxi(1, int(_bundle.get("hframes", 1)))
	_fps = maxi(1, int(_bundle.get("fps", 8)))
	_sprite.hframes = _hframes
	_sprite.vframes = maxi(1, int(_bundle.get("vframes", 1)))
	_sprite.frame = 0
	# Normalise size by SOURCE resolution so a creature sits within its slot's
	# footprint regardless of the art's pixel dimensions (a 96px placeholder and
	# a 32px sheet frame both render ~TARGET_HEIGHT tall, not 3 slots wide).
	_sprite.pixel_size = _fit_pixel_size(_sprite)
	add_child(_sprite)

	_sfx = AudioStreamPlayer3D.new()
	add_child(_sfx)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 6.0
	add_child(_voice)

	enter(IDLE)


## World-space height a creature billboard should occupy, so it sits within its
## slot (a little overhang is fine) instead of spanning several.
const TARGET_HEIGHT := 0.95


func _fit_pixel_size(sprite: Sprite3D) -> float:
	var tex: Texture2D = sprite.texture
	if tex == null:
		return 0.01
	var frame_h := float(tex.get_height()) / float(maxi(1, sprite.vframes))
	if frame_h <= 0.0:
		return 0.01
	return TARGET_HEIGHT / frame_h


## The billboard's rendered world height (for the size-normalisation test).
func sprite_world_height() -> float:
	if _sprite == null or _sprite.texture == null:
		return 0.0
	return _sprite.pixel_size * float(_sprite.texture.get_height()) / float(maxi(1, _sprite.vframes))


func set_home(pos: Vector3) -> void:
	_home = pos
	position = pos


## Enter a state, firing every channel that applies. Persistent states stay put;
## transient states run for their duration then emit `state_finished`.
func enter(new_state: String) -> void:
	state = new_state
	_t = 0.0
	_frame_t = 0.0
	if _sprite == null:
		return

	match new_state:
		SUMMON:
			_use_sheet(false)
			_sprite.scale = Vector3.ONE * 0.2
			_sprite.modulate = Color.WHITE
			_play_sfx(_bundle.get("sfx_summon"))
			_play_voice(_bundle.get("voice_summon"))
		IDLE:
			_use_sheet(false)
			_sprite.scale = Vector3.ONE
			_sprite.modulate = Color.WHITE
			_rest_state = IDLE
		ATTACK_WINDUP:
			_use_sheet(true)
			_sprite.modulate = Color.WHITE
		STRIKE:
			_use_sheet(true)
			_play_sfx(_bundle.get("sfx_hit"))
			_spawn_vfx()
		RETURN:
			_use_sheet(true)
		DAMAGED:
			_sprite.modulate = Color(1.0, 0.5, 0.5)
			_play_sfx(_bundle.get("sfx_hit"))
		KO:
			_use_sheet(false)
			_sprite.modulate = Color(0.4, 0.4, 0.4)
			_play_sfx(_bundle.get("sfx_hit"))
			_rest_state = KO
		RESTED:
			_use_sheet(false)
			_sprite.rotation_degrees.z = 90.0
			_sprite.modulate = Color(0.75, 0.75, 0.8)
			_rest_state = RESTED
		FROZEN:
			_use_sheet(false)
			_sprite.modulate = Color(0.6, 0.8, 1.0)
			_rest_state = FROZEN
		REFRESH:
			_sprite.rotation_degrees.z = 0.0
			_sprite.modulate = Color(1.2, 1.2, 1.0)
			_rest_state = IDLE
		BOUNCE:
			_play_sfx(_bundle.get("sfx_summon"))
		LIFE_TRIGGER_REVEAL:
			_use_sheet(false)
			_sprite.modulate = Color(1.3, 1.25, 0.7)

	# Reset transform quirks for non-rested states.
	if new_state not in [RESTED]:
		if new_state in [IDLE, SUMMON, FROZEN, REFRESH, KO]:
			_sprite.rotation_degrees.z = 90.0 if _rest_state == RESTED else 0.0


## Kick off the full windup->strike->return attack chain.
func attack() -> void:
	enter(ATTACK_WINDUP)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	# Frame cycling for animated sheets.
	if _hframes > 1 and state in [IDLE, SUMMON, ATTACK_WINDUP, STRIKE, RETURN]:
		_frame_t += delta
		var spf := 1.0 / float(_fps)
		if _frame_t >= spf:
			_frame_t -= spf
			var frames := _sprite.hframes * _sprite.vframes
			_sprite.frame = (_sprite.frame + 1) % maxi(1, frames)

	# Summon pop-in.
	if state == SUMMON:
		var k := clampf(_t / _DURATION[SUMMON], 0.0, 1.0)
		_sprite.scale = Vector3.ONE * lerpf(0.2, 1.0, k)
	# Strike lunge toward +Z then back on return.
	elif state == STRIKE:
		var k := clampf(_t / _DURATION[STRIKE], 0.0, 1.0)
		position = _home + Vector3(0, 0, sin(k * PI) * 0.6)
	elif state == RETURN:
		position = _home

	# Transient-state timeout -> auto advance.
	if _DURATION.has(state):
		_t += delta
		if _t >= float(_DURATION[state]):
			var finished := state
			state_finished.emit(finished)
			if _NEXT.has(finished):
				enter(_NEXT[finished])
			elif finished == DAMAGED:
				enter(_rest_state)


# --- channel helpers ------------------------------------------------------

func _use_sheet(attacking: bool) -> void:
	var tex = _bundle.get("sprite_attack") if attacking else _bundle.get("sprite_idle")
	if tex == null:
		tex = _bundle.get("sprite_idle")
	_sprite.texture = tex
	if attacking:
		# Attack sheet is 2-frame in the placeholder set; fall back gracefully.
		_sprite.hframes = 2 if tex == _bundle.get("sprite_attack") else _hframes
	else:
		_sprite.hframes = _hframes
	_sprite.frame = 0


func _play_sfx(stream) -> void:
	if stream is AudioStream and _sfx != null:
		_sfx.stream = stream
		_sfx.play()


func _play_voice(stream) -> void:
	if stream is AudioStream and _voice != null:
		_voice.stream = stream
		_voice.play()


func _spawn_vfx() -> void:
	var scene = _bundle.get("vfx_strike")
	if scene is PackedScene:
		var inst = scene.instantiate()
		if inst is Node3D:
			add_child(inst)
			(inst as Node3D).position = Vector3(0, 0, 0.4)
