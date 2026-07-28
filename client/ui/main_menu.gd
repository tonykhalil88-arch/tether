class_name MainMenu
extends Control

## Pick your Vanguard, pick the AI's Vanguard (or Random), start the match. The
## AI automatically uses the archetype pilot mapped to whatever Vanguard it ends
## up with (handled by the MatchController).

signal start_match(human_vg: String, ai_vg: String)

const RANDOM := "__random__"

var _human_pick: OptionButton
var _ai_pick: OptionButton
var _vg_ids: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-200, -180)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "WILDMIGRATION"
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Set 1 — The First Stampede"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.72, 0.6))
	box.add_child(sub)

	box.add_child(_spacer(16))
	box.add_child(_row_label("Your Vanguard"))
	_human_pick = _mk_vanguard_picker(false)
	box.add_child(_human_pick)

	box.add_child(_row_label("Opponent Vanguard"))
	_ai_pick = _mk_vanguard_picker(true)
	box.add_child(_ai_pick)

	box.add_child(_spacer(20))
	var start := Button.new()
	start.text = "Start Match"
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_start)
	box.add_child(start)


func _mk_vanguard_picker(with_random: bool) -> OptionButton:
	var ob := OptionButton.new()
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


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
