class_name Hud
extends CanvasLayer

## Screen-space controls and prompts for the human. Built entirely in code so it
## has no scene dependencies. It reads nothing from the engine directly — it
## drives the MatchController (end turn, activate, attach, answer prompts) and
## the BoardView (attach count), and reflects their signals.

const PHASE_YOU := Color(0.35, 0.85, 0.5)
const PHASE_AI := Color(0.9, 0.45, 0.4)

var mc: MatchController
var board: BoardView

var _root: Control
var _status: Label
var _banner: PanelContainer
var _banner_label: Label
var _banner_style: StyleBoxFlat
var _attach_label: Label
var _speed_btn: Button
var _prompt_panel: PanelContainer
var _prompt_box: VBoxContainer


func setup(controller: MatchController, board_view: BoardView) -> void:
	mc = controller
	board = board_view
	_build()
	mc.turn_began.connect(_on_turn_began)
	mc.prompt_mulligan.connect(_on_prompt_mulligan)
	mc.prompt_defense.connect(_on_prompt_defense)
	mc.prompt_life_trigger.connect(_on_prompt_life_trigger)
	board.action_message.connect(_set_status)
	board.card_reason.connect(_float_reason)
	board.attacker_selected.connect(_on_attacker_selected)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	# Phase banner (top-left): large, phase-coloured.
	_banner = PanelContainer.new()
	_banner.position = Vector2(16, 12)
	_banner_style = StyleBoxFlat.new()
	_banner_style.bg_color = Color(0.1, 0.11, 0.14, 0.9)
	_banner_style.set_corner_radius_all(6)
	_banner_style.set_content_margin_all(8)
	_banner_style.border_color = PHASE_YOU
	_banner_style.set_border_width_all(3)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	root.add_child(_banner)
	_banner_label = Label.new()
	_banner_label.add_theme_font_size_override("font_size", 28)
	_banner_label.text = "WILDMIGRATION"
	_banner.add_child(_banner_label)

	_status = _mk_label(Vector2(16, 66), 18, Color(0.82, 0.86, 0.72))
	root.add_child(_status)

	# Bottom action bar.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(16, -52)
	bar.set_anchor_and_offset(SIDE_TOP, 1.0, -52)
	root.add_child(bar)

	bar.add_child(_mk_button("End Turn", _on_end_turn))
	bar.add_child(_mk_button("Activate VG", func(): _activate(true)))
	bar.add_child(_mk_button("Activate Stage", func(): _activate(false)))
	bar.add_child(_mk_button("Aura -", func(): _attach(-1)))
	_attach_label = _mk_label(Vector2.ZERO, 16, Color.WHITE)
	_attach_label.text = "attach 0"
	_attach_label.custom_minimum_size = Vector2(84, 0)
	bar.add_child(_attach_label)
	bar.add_child(_mk_button("Aura +", func(): _attach(1)))
	_speed_btn = _mk_button("Speed 1x", _on_speed)
	bar.add_child(_speed_btn)
	bar.add_child(_mk_button("Skip", func(): mc.queue.skip()))

	# Center prompt panel (hidden until needed).
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_panel.position = Vector2(-180, -120)
	_prompt_panel.custom_minimum_size = Vector2(360, 0)
	_prompt_panel.visible = false
	root.add_child(_prompt_panel)
	_prompt_box = VBoxContainer.new()
	_prompt_box.add_theme_constant_override("separation", 8)
	_prompt_panel.add_child(_prompt_box)


# =========================================================================
# Bar actions
# =========================================================================

func _on_end_turn() -> void:
	if mc.is_human_turn():
		mc.human_end_turn()


func _activate(vanguard: bool) -> void:
	if not mc.is_human_turn():
		return
	var ps: PlayerState = mc.player(MatchController.HUMAN)
	var target: CardInstance = ps.vanguard if vanguard else ps.stage
	if target == null:
		return
	if mc.human_activate(target):
		_set_status("Activated %s." % target.data.name)
	else:
		_set_status("Nothing to activate on %s." % target.data.name)


func _attach(delta: int) -> void:
	if board == null:
		return
	board.set_pending_attach(board.pending_attach() + delta)
	_attach_label.text = "attach %d" % board.pending_attach()


func _on_speed() -> void:
	var m := mc.queue.toggle_speed()
	_speed_btn.text = "Speed %dx" % int(m)


func _on_attacker_selected(has: bool) -> void:
	if not has:
		_attach_label.text = "attach 0"


# =========================================================================
# Turn / status
# =========================================================================

func _on_turn_began(seat: int, turn: int) -> void:
	var human := seat == MatchController.HUMAN
	var color := PHASE_YOU if human else PHASE_AI
	_banner_label.text = "TURN %d  ·  %s" % [turn, "YOUR TURN" if human else "AI TURN"]
	_banner_label.add_theme_color_override("font_color", color)
	if _banner_style != null:
		_banner_style.border_color = color
	if human:
		_set_status("Play cards, then attack. Click a unit to select an attacker; hover any card to read it.")


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


## Floating reason label anchored near the card that caused it (world -> screen),
## so "can't attack: exhausted" appears at the unit, not only in the corner.
func _float_reason(uid: int, text: String) -> void:
	if board == null or _root == null:
		return
	var screen := board.camera_unproject(board.world_pos_for_uid(uid))
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = screen - Vector2(60, 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)


# =========================================================================
# Prompts
# =========================================================================

func _clear_prompt() -> void:
	for c in _prompt_box.get_children():
		c.queue_free()
	_prompt_panel.visible = false


func _prompt_title(text: String) -> void:
	for c in _prompt_box.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_box.add_child(l)
	_prompt_panel.visible = true


func _prompt_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		_clear_prompt()
		cb.call())
	_prompt_box.add_child(b)


func _on_prompt_mulligan(_seat: int, hand: Array) -> void:
	var names: Array = []
	for c in hand:
		names.append(c.data.name)
	_prompt_title("Opening hand:\n%s\n\nKeep, or mulligan once?" % ", ".join(names))
	_prompt_button("Keep", func(): mc.answer_mulligan(true))
	_prompt_button("Mulligan", func(): mc.answer_mulligan(false))


func _on_prompt_defense(attacker: CardInstance, target: CardInstance, options: Dictionary) -> void:
	_prompt_title("%s (%d) attacks your %s.\nDefend?" % [
		attacker.data.name, mc.engine.effective_power(attacker), target.data.name])
	for b in options.get("blockers", []):
		var blk: CardInstance = b
		_prompt_button("Block with %s" % blk.data.name,
			func(): mc.answer_defense({ "blocker_uid": blk.uid }))
	var counters: Array = options.get("counter_cards", [])
	if not counters.is_empty():
		var uids: Array = []
		for c in counters:
			uids.append(c.uid)
		_prompt_button("Pitch %d counter card(s)" % counters.size(),
			func(): mc.answer_defense({ "counter_uids": uids }))
	_prompt_button("Take it (pass)", func(): mc.answer_defense({}))


func _on_prompt_life_trigger(card: CardInstance) -> void:
	_prompt_title("Life revealed: %s.\nResolve its trigger, or add it to your hand?" % card.data.name)
	_prompt_button("Resolve trigger", func(): mc.answer_life_trigger(true))
	_prompt_button("Add to hand", func(): mc.answer_life_trigger(false))


# =========================================================================
# Widgets
# =========================================================================

func _mk_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _mk_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
