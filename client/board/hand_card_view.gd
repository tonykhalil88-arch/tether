class_name HandCardView
extends Node3D

## A card in the human's hand (or any zone shown face-up as a frame): a quad
## textured with the generated CardFrame, tilted toward the camera, clickable.
## No creature animation — hand cards are inert until played.

signal clicked(uid: int)

var uid: int = -1
var card_id: String = ""
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _lifted: bool = false
var _base_y: float = 0.0


func setup(p_card_id: String, p_uid: int) -> void:
	card_id = p_card_id
	uid = p_uid

	_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.88)      # 168:240 aspect
	_mesh.mesh = quad
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = CardFrame.make(DeckFactory.card(card_id))
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _mat
	add_child(_mesh)

	var area := Area3D.new()
	area.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.62, 0.88, 0.12)
	shape.shape = box
	area.add_child(shape)
	area.input_event.connect(_on_area_input)
	add_child(area)


func set_playable(on: bool) -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color(1, 1, 1) if on else Color(0.55, 0.55, 0.6)


func set_lifted(on: bool) -> void:
	# Small hover pop so the selected hand card reads clearly.
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
