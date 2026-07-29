extends GutTest

## Brief 12.1 layout smoke: the menu must stay fully on-screen (no clipping) at
## any window size, and the project must use the stretch settings that make the
## viewport + anchored UI fill the window. Headless can't SEE the pixels, but it
## can prove the anchoring math keeps every control inside the frame.

const SIZES := [
	Vector2i(1152, 648),   # Tony's debug window
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1600, 900),   # maximized odd size
]


func test_project_uses_fill_the_window_stretch():
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "expand")
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1920)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1080)


func test_menu_controls_stay_inside_the_frame_at_every_size() -> void:
	for size in SIZES:
		# A fixed-size holder stands in for the window frame; the menu fills it
		# (PRESET_FULL_RECT) and its CenterContainer centres the card within.
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
		holder.size = Vector2(size)
		add_child_autofree(holder)
		var menu := MainMenu.new()
		holder.add_child(menu)
		await get_tree().process_frame
		await get_tree().process_frame

		var frame := Rect2(Vector2.ZERO, Vector2(size))
		for ctrl in menu.layout_controls():
			var r: Rect2 = ctrl.get_global_rect()
			assert_true(frame.encloses(r),
				"menu control fits inside %dx%d (control rect %s)" % [size.x, size.y, str(r)])
			assert_gt(r.size.x, 0.0, "control has a real width at %dx%d" % [size.x, size.y])
		holder.queue_free()
		await get_tree().process_frame


func test_win_loss_centres_without_absolute_positions() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.size = Vector2(1152, 648)
	add_child_autofree(holder)
	var wl := WinLoss.new()
	holder.add_child(wl)
	wl.show_result(true, { "turns": 7, "dealt": 5, "lost": 2, "attacks": 12, "connects": 9 })
	await get_tree().process_frame
	await get_tree().process_frame
	# The card (a PanelContainer under the CenterContainer) sits within the frame.
	var frame := Rect2(Vector2.ZERO, Vector2(1152, 648))
	var found := false
	for c in wl.get_children():
		if c is CenterContainer:
			for card in c.get_children():
				found = true
				assert_true(frame.encloses((card as Control).get_global_rect()),
					"win/loss card fits inside the frame")
	assert_true(found, "win/loss uses a CenterContainer (no absolute positioning)")
