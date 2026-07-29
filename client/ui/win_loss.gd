class_name WinLoss
extends Control

## End-of-match screen: result banner + a few honest stats pulled from public
## engine state, and a button back to the menu. 100% anchors + containers, no
## absolute positions, so it centres at any window size.

signal play_again()


func show_result(won: bool, stats: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

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
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var banner := Label.new()
	banner.text = "VICTORY" if won else "DEFEAT"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color",
		Color(0.4, 0.9, 0.5) if won else Color(0.9, 0.4, 0.4))
	box.add_child(banner)

	for line in [
		"Turns played: %d" % int(stats.get("turns", 0)),
		"Life dealt to opponent: %d" % int(stats.get("dealt", 0)),
		"Life you lost: %d" % int(stats.get("lost", 0)),
		"Your attacks that connected: %d/%d" % [
			int(stats.get("connects", 0)), int(stats.get("attacks", 0))],
	]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 18)
		box.add_child(l)

	box.add_child(_gap(16))
	var again := Button.new()
	again.text = "Back to Menu"
	again.add_theme_font_size_override("font_size", 20)
	again.pressed.connect(func(): play_again.emit())
	box.add_child(again)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
