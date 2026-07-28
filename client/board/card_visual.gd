class_name CardVisual
extends Node3D

## Card Frame v2. A card face built in 3D from a procedural-art quad plus real
## Label3D text (Godot's font renderer — crisp, wrapping, no bitmap font, no
## truncation). Used by both hand and unit views so a card looks the same
## everywhere. Pure presentation: it reads printed data + CardText, nothing else.
##
## Layout (local XY plane, facing +Z):
##   title band  — name (auto-shrink + wrap) and the cost pip
##   art field   — PlaceholderArt sigil (or real art once it exists)
##   text panel  — keywords + synthesised rules text
##   stat band   — POWER / LIFE

const ASPECT := 240.0 / 168.0     # card is taller than wide

var card: CardData
var width: float = 1.0
var height: float = 1.0


func build(p_card: CardData, p_width: float = 1.0, show_rules: bool = true) -> void:
	card = p_card
	width = p_width
	height = p_width * ASPECT
	var w := width
	var h := height

	# Art background quad.
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	face.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(
		PlaceholderArt.card_art(card, 336, 480))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # readable first
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = mat
	add_child(face)

	# Rules text panel (translucent dark) for legibility over art.
	if show_rules:
		var panel := MeshInstance3D.new()
		var pq := QuadMesh.new()
		pq.size = Vector2(w * 0.92, h * 0.34)
		panel.mesh = pq
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.05, 0.06, 0.08, 0.72)
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		panel.material_override = pm
		panel.position = Vector3(0, -h * 0.20, 0.01)
		add_child(panel)

	# --- text ---
	var name_size := _name_font_size(card.name)
	_label(card.name.to_upper(), Vector3(0, h * 0.42, 0.02), name_size,
		int(w * 380), HORIZONTAL_ALIGNMENT_CENTER, Color(0.98, 0.97, 0.93))

	_label(str(card.cost), Vector3(-w * 0.40, h * 0.42, 0.02), 52,
		0, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))

	var is_vg := card.type == CardEnums.TYPE_VANGUARD
	var stat := "LIFE %d" % card.vanguard_life() if is_vg else "PWR %d" % card.power
	_label(stat, Vector3(w * 0.02, -h * 0.44, 0.02), 34,
		0, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.95, 0.8))

	if card.counter > 0:
		_label("CTR %d" % card.counter, Vector3(-w * 0.30, -h * 0.44, 0.02), 24,
			0, HORIZONTAL_ALIGNMENT_LEFT, Color(0.8, 0.9, 1.0))

	if show_rules:
		var body := CardText.frame_text(card)
		if body.strip_edges().is_empty():
			body = "—"
		_label(body, Vector3(0, -h * 0.20, 0.02), 22, int(w * 360),
			HORIZONTAL_ALIGNMENT_CENTER, Color(0.94, 0.94, 0.90))

	var subtitle := card.type.capitalize()
	if not card.tribe.is_empty():
		subtitle += " · " + card.tribe
	_label(subtitle, Vector3(0, h * 0.28, 0.02), 20, int(w * 360),
		HORIZONTAL_ALIGNMENT_CENTER, Color(0.9, 0.88, 0.8))


func _label(text: String, pos: Vector3, font_size: int, wrap_px: int,
		align: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0016 * (width / 1.0)
	l.modulate = color
	l.outline_size = maxi(4, font_size / 6)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.horizontal_alignment = align
	l.no_depth_test = true
	l.render_priority = 2
	l.outline_render_priority = 1
	if wrap_px > 0:
		l.width = wrap_px
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	add_child(l)
	return l


## Auto-shrink: shorter names print big, longer names step down so they wrap to
## at most ~two lines instead of truncating.
func _name_font_size(name: String) -> int:
	var n := name.length()
	if n <= 14:
		return 40
	if n <= 22:
		return 32
	if n <= 30:
		return 27
	return 23
