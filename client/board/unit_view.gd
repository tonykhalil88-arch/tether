class_name UnitView
extends Node3D

## A single unit in play (Vanguard or Banner) on the 3D table. Combines the
## creature billboard driven by a SummonStateMachine with a small CardFrame
## "nameplate" quad, plus an Area3D so it can be clicked. Pure presentation —
## it exposes the card's uid and forwards state changes to the state machine.

signal clicked(uid: int)

var uid: int = -1
var card_id: String = ""
var sm: SummonStateMachine
var _plate: Sprite3D
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D


func setup(p_card_id: String, p_uid: int) -> void:
	card_id = p_card_id
	uid = p_uid

	# Selection / legal-target ring under the unit.
	_highlight = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.52
	_highlight.mesh = ring
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(1.0, 0.85, 0.2)
	_highlight.material_override = _highlight_mat
	_highlight.position = Vector3(0, 0.02, 0)
	_highlight.visible = false
	add_child(_highlight)

	sm = SummonStateMachine.new()
	add_child(sm)
	sm.setup(card_id)
	sm.set_home(Vector3(0, 0.5, 0))

	_plate = Sprite3D.new()
	_plate.texture = CardFrame.make(DeckFactory.card(card_id))
	_plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_plate.pixel_size = 0.0032
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.shaded = false
	_plate.modulate = Color(1, 1, 1, 0.96)
	_plate.position = Vector3(0.55, 0.42, 0)
	add_child(_plate)

	var area := Area3D.new()
	area.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 0.3)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0)
	area.add_child(shape)
	area.input_event.connect(_on_area_input)
	add_child(area)


func enter_state(state: String) -> void:
	if sm != null:
		sm.enter(state)


func attack() -> void:
	if sm != null:
		sm.attack()


## Reflect the engine's persistent status (rested/frozen/idle) without stomping
## on a transient animation the queue may be playing.
func set_status(exhausted: bool, frozen: bool) -> void:
	if sm == null:
		return
	if sm.state in [SummonStateMachine.SUMMON, SummonStateMachine.ATTACK_WINDUP,
			SummonStateMachine.STRIKE, SummonStateMachine.RETURN,
			SummonStateMachine.DAMAGED, SummonStateMachine.KO]:
		return
	if frozen:
		sm.enter(SummonStateMachine.FROZEN)
	elif exhausted:
		sm.enter(SummonStateMachine.RESTED)
	else:
		sm.enter(SummonStateMachine.IDLE)


func set_highlight(on: bool, color: Color = Color(1.0, 0.85, 0.2)) -> void:
	if _highlight == null:
		return
	_highlight.visible = on
	if on and _highlight_mat != null:
		_highlight_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
		_highlight_mat.emission = color


func _on_area_input(_camera: Node, event: InputEvent, _pos: Vector3,
		_normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(uid)
