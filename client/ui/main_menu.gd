class_name MainMenu
extends Control

## Pick your Vanguard, pick the AI's Vanguard (or Random), start the match. The
## AI automatically uses the archetype pilot mapped to whatever Vanguard it ends
## up with (handled by the MatchController).
##
## Layout is 100% anchors + containers (CenterContainer -> styled card ->
## VBox) — NO absolute pixel positions — so it centres and stays fully visible
## at any window size / aspect (project stretch = canvas_items / expand).

signal start_match(human_vg: String, ai_vg: String)
signal brightness_changed(value: float)

const RANDOM := "__random__"

var _human_pick: OptionButton
var _ai_pick: OptionButton
var _brightness: HSlider
var _vg_ids: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# CenterContainer fills the screen and centres its single child at any size.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Styled card (explicit StyleBox so it never falls back to the grey theme panel).
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.98)
	sb.border_color = Color(0.45, 0.40, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := Label.new()
	title.text = "WILDMIGRATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Set 1 — The First Stampede"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.72, 0.6))
	box.add_child(sub)

	box.add_child(_gap(16))
	box.add_child(_row_label("Your Vanguard"))
	_human_pick = _mk_vanguard_picker(false)
	box.add_child(_human_pick)

	box.add_child(_row_label("Opponent Vanguard"))
	_ai_pick = _mk_vanguard_picker(true)
	box.add_child(_ai_pick)

	box.add_child(_gap(10))
	box.add_child(_row_label("Brightness"))
	_brightness = HSlider.new()
	_brightness.min_value = 0.5
	_brightness.max_value = 2.0
	_brightness.step = 0.05
	_brightness.value = 1.0
	_brightness.custom_minimum_size = Vector2(0, 24)
	_brightness.value_changed.connect(func(v): brightness_changed.emit(v))
	box.add_child(_brightness)

	box.add_child(_gap(20))
	var start := Button.new()
	start.text = "Start Match"
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_start)
	box.add_child(start)


## Menu controls whose on-screen rect the layout smoke test checks.
func layout_controls() -> Array:
	return [_human_pick, _ai_pick, _brightness]


func brightness() -> float:
	return _brightness.value if _brightness != null else 1.0


func _mk_vanguard_picker(with_random: bool) -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vg_ids = DeckFactory.vanguards()
	var idx := 0
	if with_random:
		ob.add_item("Random")
		ob.set_item_metadata(0, RANDOM)
		idx = 1
	for i in range(_vg_ids.size()):
		var vg: CardData = _vg_ids[i]
		var vid: String = vg.id if vg is CardData else str(vg)
		var vname: String = vg.name if vg is CardData else str(vg)
		ob.add_item("%s (%s)" % [vname, AIPolicy.ARCHETYPE_BY_VANGUARD.get(vid, "?")])
		ob.set_item_metadata(idx, vid)
		idx += 1
	ob.selected = 0
	return ob


func _on_start() -> void:
	var human_vg := str(_human_pick.get_item_metadata(_human_pick.selected))
	var ai_meta := str(_ai_pick.get_item_metadata(_ai_pick.selected))
	var ai_vg := ai_meta
	if ai_meta == RANDOM:
		var pool: Array = []
		for vg in _vg_ids:
			pool.append(vg.id if vg is CardData else str(vg))
		ai_vg = pool[randi() % pool.size()]
	start_match.emit(human_vg, ai_vg)


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
