extends GutTest

## Client (Phase 3) smoke tests. They prove the presentation layer constructs
## and runs under --headless and that the FROZEN engine is driven only through
## its public API. No rules are asserted here — the engine suites own rules.

const HUMAN := 0
const AI := 1


# --- Asset manifest -------------------------------------------------------

func test_asset_manifest_resolves_four_channels_for_wired_card():
	AssetManifest.clear_cache()
	var b := AssetManifest.resolve("wm01-008")
	assert_true(b["has_manifest"], "example card has a manifest.json")
	assert_true(b["sprite_idle"] is Texture2D, "idle sprite resolves")
	assert_true(b["sprite_attack"] is Texture2D, "attack sprite resolves")
	assert_true(b["sfx_summon"] is AudioStream, "summon SFX resolves")
	assert_true(b["voice_summon"] is AudioStream, "voice resolves")
	assert_true(b["vfx_strike"] is PackedScene, "strike VFX resolves")


func test_asset_manifest_resolves_card_art_only_when_shipped():
	AssetManifest.clear_cache()
	assert_true(AssetManifest.card_art("wm01-001") is Texture2D,
		"an ingested card_art.png resolves")
	assert_null(AssetManifest.card_art("wm01-046"),
		"a card with no card art gets none fabricated")


## The attack strip has its own frame count. Before real art landed the client
## assumed every attack sheet was the placeholder set's 2 frames.
func test_asset_manifest_reads_attack_sheet_geometry():
	AssetManifest.clear_cache()
	assert_eq(AssetManifest.resolve("wm01-001")["attack_hframes"], 8,
		"an ingested 8-frame attack sheet declares 8 frames")
	assert_eq(AssetManifest.resolve("wm01-046")["attack_hframes"], 2,
		"an undeclared attack sheet keeps the legacy 2-frame shape")


## Ingestion contract: every manifest it writes must reference files that exist,
## or the client silently falls back to placeholders.
func test_every_card_manifest_points_at_files_that_exist():
	var dir := DirAccess.open("res://assets/cards")
	assert_not_null(dir, "assets/cards is readable")
	for id in dir.get_directories():
		var mpath := "res://assets/cards/%s/manifest.json" % id
		assert_true(FileAccess.file_exists(mpath), "%s has a manifest.json" % id)
		var m = JSON.parse_string(FileAccess.get_file_as_string(mpath))
		assert_eq(typeof(m), TYPE_DICTIONARY, "%s manifest.json parses" % id)
		if typeof(m) != TYPE_DICTIONARY:
			continue
		for section in ["sprite", "sfx", "voice", "art"]:
			var block = m.get(section, {})
			if typeof(block) != TYPE_DICTIONARY:
				continue
			for key in block.keys():
				var v := str(block[key])
				if not (v.ends_with(".png") or v.ends_with(".wav")):
					continue   # frame counts, and the shared res:// VFX scene
				assert_true(FileAccess.file_exists("res://assets/cards/%s/%s" % [id, v]),
					"%s: %s.%s -> %s exists" % [id, section, key, v])


func test_asset_manifest_falls_back_for_unknown_card():
	AssetManifest.clear_cache()
	var b := AssetManifest.resolve("wm01-does-not-exist")
	assert_false(b["has_manifest"], "no manifest for unknown card")
	assert_true(b["sprite_idle"] is Texture2D, "placeholder sprite still provided")
	assert_true(b["sfx_summon"] is AudioStream, "fallback whoosh provided")
	assert_null(b["voice_summon"], "no fabricated voice")
	assert_null(b["vfx_strike"], "no fabricated VFX")


# --- Card frame -----------------------------------------------------------

func test_card_frame_renders_every_card_type():
	for id in ["wm01-001", "wm01-008", "wm01-046"]:  # vanguard, banner, banner
		var img: Image = CardFrame.render(DeckFactory.card(id))
		assert_eq(img.get_width(), CardFrame.W, "frame width for %s" % id)
		assert_eq(img.get_height(), CardFrame.H, "frame height for %s" % id)


## The art window shows real art when the card ships some, and the flat accent
## plate when it does not.
func test_card_frame_art_window_uses_real_card_art():
	CardFrame.clear_cache()
	AssetManifest.clear_cache()
	var with_art: Image = CardFrame.render(DeckFactory.card("wm01-001"))
	var without: Image = CardFrame.render(DeckFactory.card("wm01-046"))
	assert_gt(_art_well_colours(with_art), 8,
		"real card art paints a varied art window")
	assert_eq(_art_well_colours(without), 1,
		"with no card art the window stays a flat accent plate")


## Distinct colours sampled from inside the art well (clear of its 2px border).
func _art_well_colours(img: Image) -> int:
	var seen: Dictionary = {}
	for y in range(48, 152, 4):
		for x in range(20, 148, 4):
			seen[img.get_pixel(x, y)] = true
	return seen.size()


# --- Presentation queue ---------------------------------------------------

func test_presentation_queue_orders_and_skips():
	var q := PresentationQueue.new()
	add_child_autofree(q)
	var order: Array = []
	q.beat_started.connect(func(b): order.append(b.get("kind")))
	q.enqueue({ "kind": "a", "duration": 0.4 })
	q.enqueue({ "kind": "b", "duration": 0.4 })
	q.enqueue({ "kind": "c", "duration": 0.4 })
	q.skip()
	q._process(0.016)
	assert_eq(order, ["a", "b", "c"], "skip flushes all beats in order")
	assert_true(q.is_idle(), "queue idle after flush")


# --- Summon state machine -------------------------------------------------

func test_summon_state_machine_walks_the_attack_chain():
	var sm := SummonStateMachine.new()
	add_child_autofree(sm)
	sm.setup("wm01-008")
	var seen: Array = []
	sm.state_finished.connect(func(s): seen.append(s))
	sm.attack()
	for i in range(200):
		sm._process(0.016)
	assert_true(seen.has("attack_windup"), "windup ran")
	assert_true(seen.has("strike"), "strike ran")
	assert_true(seen.has("return"), "return ran")
	assert_eq(sm.state, SummonStateMachine.IDLE, "settles back to idle")


# --- Match controller: full game via public API ---------------------------

func test_match_controller_reaches_game_over():
	var mc := MatchController.new()
	add_child_autofree(mc)
	mc.auto_prompts = true
	var done := [false]
	mc.match_over.connect(func(_w): done[0] = true)
	mc.begin_match("wm01-001", "wm01-034", 5, HUMAN)
	var guard := 0
	while not done[0] and guard < 400:
		guard += 1
		if mc.is_human_turn():
			_drive_human_turn(mc)
		else:
			break
	assert_true(done[0], "a full human-vs-AI game reaches game_over")
	assert_true(mc.engine.state.game_over, "engine reports game over")
	assert_true(mc.engine.state.winner in [0, 1], "a winner is set")


# --- Client stack: scripted turn 1 through the board's input handlers ------

func test_client_stack_plays_turn_one_via_board_input():
	var mc := MatchController.new()
	add_child_autofree(mc)
	mc.auto_prompts = true
	var board := BoardView.new()
	add_child_autofree(board)
	board.bind(mc)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(mc, board)

	mc.begin_match("wm01-001", "wm01-034", 5, HUMAN)
	assert_true(mc.is_human_turn(), "human takes turn 1")
	assert_eq(board._units.size(), 2, "both Vanguards are on the board")
	assert_eq(board._hand.size(), 5, "opening hand is shown")

	# Play affordable hand cards by clicking them (board's own handler).
	var plays := 0
	var guard := 0
	while mc.is_human_turn() and guard < 20:
		guard += 1
		var played := false
		for uid in board._hand.keys().duplicate():
			var inst := board._find_hand(uid)
			if inst != null and board._can_play(inst):
				board._on_hand_clicked(uid)
				plays += 1
				played = true
				break
		if not played:
			break
	assert_gt(plays, 0, "at least one card was played via board input")

	# Select the Vanguard as attacker, then attack a highlighted target.
	var vg_uid: int = mc.player(HUMAN).vanguard.uid
	board._on_unit_clicked(vg_uid)
	assert_true(board.has_attacker(), "clicking the Vanguard selects an attacker")
	assert_gt(board._legal_targets.size(), 0, "legal targets are highlighted")
	board._on_unit_clicked(board._legal_targets[0])
	assert_false(board.has_attacker(), "selection clears after declaring")

	# Pass the turn; the game advances into the AI's turn without errors.
	if mc.is_human_turn():
		mc.human_end_turn()
	assert_gt(mc.engine.state.turn_number, 1, "turn advanced past turn 1")


# --- helper ---------------------------------------------------------------

func _drive_human_turn(mc: MatchController) -> void:
	var ps: PlayerState = mc.player(HUMAN)
	for _i in range(12):
		var pick: CardInstance = null
		for c in ps.hand:
			if c.data.cost <= ps.aura_available():
				if pick == null or c.data.cost < pick.data.cost:
					pick = c
		if pick == null:
			break
		if not mc.human_play_card(pick):
			break
	mc.human_activate(ps.vanguard)
	var guard := 0
	while mc.is_human_turn() and guard < 40:
		guard += 1
		var attacker: CardInstance = null
		if mc.engine.can_attack(ps.vanguard):
			attacker = ps.vanguard
		else:
			for b in ps.battle_area:
				if mc.engine.can_attack(b):
					attacker = b
					break
		if attacker == null:
			break
		var targets := mc.human_legal_attack_targets(attacker)
		if targets.is_empty():
			break
		mc.human_declare_attack(attacker, targets[0], 0)
	if mc.is_human_turn():
		mc.human_end_turn()
