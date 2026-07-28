class_name HandCardView
extends Node3D

## A card in the human's hand: a full CardVisual (real-font frame with legible
## name, cost, power, keywords and complete rules text at hand scale), clickable
## and hoverable for the inspector. No creature animation — hand cards are inert
## until played.

signal clicked(uid: int)
signal hovered(uid: int)
signal unhovered(uid: int)

var uid: int = -1
var card_id: String = ""
var _frame: CardVisual
var _dim: MeshInstance3D
var _lifted: bool = false
var _base_y: float = 0.0


func setup(p_card_id: String, p_uid: int) -> void:
	card_id = p_card_id
	uid = p_uid
	var card := DeckFactory.card(card_id)

	_frame = CardVisual.new()
	add_child(_frame)
	_frame.build(card, 0.72, true)   # full rules text at hand scale

	# A dim overlay used when the card is not playable.
	_dim = MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(_frame.width, _frame.height)
	_dim.mesh = dq
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.02, 0.02, 0.04, 0.0)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dim.material_override = dm
	_dim.position = Vector3(0, 0, 0.03)
	add_child(_dim)

	var area := Area3D.new()
	area.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_frame.width, _frame.height, 0.12)
	shape.shape = box
	area.add_child(shape)
	area.input_event.connect(_on_area_input)
	area.mouse_entered.connect(func(): hovered.emit(uid))
	area.mouse_exited.connect(func(): unhovered.emit(uid))
	add_child(area)


func set_playable(on: bool) -> void:
	if _dim == null:
		return
	var m := _dim.material_override as StandardMaterial3D
	if m != null:
		m.albedo_color = Color(0.02, 0.02, 0.04, 0.0 if on else 0.55)


func set_lifted(on: bool) -> void:
	if on == _lifted:
		return
	_lifted = on
	position.y = _base_y + (0.18 if on else 0.0)


func remember_base_y() -> void:
	_base_y = position.y


func _on_area_input(_camera: Node, event: InputEvent, _pos: Vector3,
		_normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(uid)
