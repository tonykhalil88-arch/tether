class_name WinLoss
extends Control

## End-of-match screen: result banner + a few honest stats pulled from public
## engine state, and a button back to the menu.

signal play_again()


func show_result(won: bool, stats: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-180, -140)
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var banner := Label.new()
	banner.text = "VICTORY" if won else "DEFEAT"
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

	box.add_child(_spacer(16))
	var again := Button.new()
	again.text = "Back to Menu"
	again.add_theme_font_size_override("font_size", 20)
	again.pressed.connect(func(): play_again.emit())
	box.add_child(again)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
