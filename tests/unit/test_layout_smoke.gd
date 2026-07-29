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


## Finding 8: the LOCAL player's aura rack used to render on top of the hand row.
## It now stands clear on the far right. Prove — headless, via camera projection —
## that its screen rect intersects NEITHER any hand card NOR the bottom HUD bar, at
## every supported window size.
func test_aura_rack_never_overlaps_hand_or_hud_bar_at_any_size() -> void:
	var mc := MatchController.new()
	add_child_autofree(mc)
	mc.auto_prompts = true
	var board := BoardView.new()
	add_child_autofree(board)
	board.bind(mc)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(mc, board)
	mc.begin_match("wm01-001", "wm01-034", 5, 0)
	await get_tree().process_frame

	for size in SIZES:
		get_tree().root.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		board.reconcile()

		var rack := _project_aabb(board, board.human_aura_rack_world_aabb())
		assert_gt(rack.size.x, 0.0, "rack projects to a real rect at %dx%d" % [size.x, size.y])

		var hands: Array = board.hand_card_world_aabbs()
		assert_gt(hands.size(), 0, "the human has hand cards to guard against")
		for box in hands:
			var hr := _project_aabb(board, box)
			assert_false(rack.intersects(hr),
				"aura rack (%s) clears hand card (%s) at %dx%d" % [str(rack), str(hr), size.x, size.y])

		var bar := hud.action_bar_rect()
		assert_gt(bar.size.y, 0.0, "HUD bar has a real rect at %dx%d" % [size.x, size.y])
		assert_false(rack.intersects(bar),
			"aura rack (%s) clears the HUD bar (%s) at %dx%d" % [str(rack), str(bar), size.x, size.y])


## Project a world AABB's 8 corners to screen and return their bounding Rect2.
func _project_aabb(board: BoardView, box: AABB) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(8):
		var p: Vector2 = board.camera.unproject_position(box.get_endpoint(i))
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.y)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.y)
	return Rect2(lo, hi - lo)


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
