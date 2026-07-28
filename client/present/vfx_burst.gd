class_name VfxBurst
extends Node3D

## A tiny code-driven strike burst: a bright quad that flares out and fades,
## then frees itself. Used as the DEFAULT `vfx.strike` scene for example cards
## (see each card's manifest.json). Deliberately GPU-particle-free so it also
## constructs cleanly under a headless smoke test — it just never gets drawn.
##
## Tint it before/after instancing via `tint`; the SummonStateMachine sets it
## to the card's accent colour so each strike reads a little differently.

@export var tint: Color = Color(1.0, 0.85, 0.35)
@export var lifetime: float = 0.35

var _t := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	_mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / maxf(0.001, lifetime), 0.0, 1.0)
	if _mesh != null:
		var s := 0.3 + k * 1.8
		_mesh.scale = Vector3(s, s, s)
		var mat := _mesh.material_override as StandardMaterial3D
		if mat != null:
			var c := mat.albedo_color
			c.a = 1.0 - k
			mat.albedo_color = c
	if k >= 1.0:
		queue_free()
