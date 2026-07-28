extends SceneTree

## Generates the board-capture image for SCREENS.md. GPU 3D rendering is
## unavailable under --headless (dummy driver), so instead of a framebuffer
## screenshot this composites a faithful SCHEMATIC of a real mid-game board —
## using the same CardFrame / PixelFont Image tools the live client renders with
## — by playing a scripted human-vs-AI game to a mid-game state and drawing it.
##
##   godot --headless -s tools/gen_screens.gd

const HUMAN := 0
const AI := 1
const W := 1040
const H := 760
const TW := 74
const TH := 106

var mc: MatchController


func _init() -> void:
	mc = MatchController.new()
	get_root().add_child(mc)
	mc.auto_prompts = true
	mc.begin_match("wm01-001", "wm01-034", 5, HUMAN)

	# Play until both sides have a developed board (or turn 5), then snapshot.
	var guard := 0
	while not mc.engine.state.game_over and guard < 60:
		guard += 1
		if mc.is_human_turn():
			_drive_human_turn()
		else:
			break
		if _developed() and mc.engine.state.turn_number >= 3:
			break

	var img := _compose()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screens"))
	var out := "res://docs/screens/board_schematic.png"
	img.save_png(ProjectSettings.globalize_path(out))
	print("wrote %s (turn %d)" % [out, mc.engine.state.turn_number])
	quit(0)


func _developed() -> bool:
	return not mc.player(HUMAN).battle_area.is_empty() \
		and not mc.player(AI).battle_area.is_empty()


# =========================================================================
# Compose the schematic
# =========================================================================

func _compose() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.09, 0.10, 0.13))

	var turn := mc.engine.state.turn_number
	_text(img, "WILDMIGRATION  -  BOARD SCHEMATIC  -  TURN %d" % turn, 24, 18,
		Color(0.95, 0.95, 0.98), 3)
	_text(img, "human (rush)  vs  ai (lockdown)          generated headless - the live client renders this in 3D",
		24, 52, Color(0.6, 0.7, 0.55), 1)

	# Opponent band.
	var ai_ps: PlayerState = mc.player(AI)
	_text(img, "OPPONENT", 24, 84, Color(0.85, 0.5, 0.5), 2)
	_zone_counts(img, ai_ps, 700, 84)
	_unit_thumb(img, ai_ps.vanguard, W / 2 - TW / 2, 104)
	_banner_row(img, ai_ps, 210)

	# Divider.
	img.fill_rect(Rect2i(24, 358, W - 48, 3), Color(0.25, 0.28, 0.34))

	# Human band.
	var hu_ps: PlayerState = mc.player(HUMAN)
	_banner_row(img, hu_ps, 372)
	_unit_thumb(img, hu_ps.vanguard, W / 2 - TW / 2, 500)
	_text(img, "YOU", 24, 500, Color(0.5, 0.8, 0.55), 2)
	_zone_counts(img, hu_ps, 700, 500)

	# Hand.
	_text(img, "YOUR HAND", 24, 616, Color(0.8, 0.82, 0.7), 2)
	var hand := hu_ps.hand
	for i in range(hand.size()):
		_unit_thumb(img, hand[i], 24 + i * (TW + 10), 640)

	return img


func _banner_row(img: Image, ps: PlayerState, y: int) -> void:
	for i in range(ps.battle_area.size()):
		_unit_thumb(img, ps.battle_area[i], 150 + i * (TW + 16), y)
	if ps.stage != null:
		_unit_thumb(img, ps.stage, 24, y)
		_text(img, "STAGE", 24, y - 14, Color(0.6, 0.6, 0.7), 1)


func _unit_thumb(img: Image, inst: CardInstance, x: int, y: int) -> void:
	if inst == null:
		return
	# Deterministic per-id placeholder art (the new distinct identity), so the
	# schematic reflects that every card now reads differently.
	var frame: Image = PlaceholderArt.card_art(inst.data, TW * 2, TH * 2)
	frame.resize(TW, TH, Image.INTERPOLATE_LANCZOS)
	img.blit_rect(frame, Rect2i(0, 0, TW, TH), Vector2i(x, y))
	# Name + power under the card (clipped to the thumb width).
	var name := inst.data.name
	if PixelFont.measure(name, 1) > TW:
		name = name.substr(0, 11)
	_text(img, name, x, y + TH + 2, Color(0.92, 0.92, 0.85), 1)
	var stat := "L%d" % inst.data.vanguard_life() if inst.data.type == "vanguard" else "P%d" % inst.data.power
	var tag := stat
	if inst.frozen:
		tag += "  FROZEN"
	elif inst.exhausted:
		tag += "  RESTED"
	_text(img, tag, x, y + TH + 12, Color(0.7, 0.85, 1.0), 1)


func _zone_counts(img: Image, ps: PlayerState, x: int, y: int) -> void:
	var lines := [
		"LIFE  %d" % ps.life.size(),
		"AURA  %d/%d" % [ps.aura_available(), ps.aura_total],
		"HAND  %d" % ps.hand.size(),
		"DECK  %d   TRASH %d" % [ps.deck.size(), ps.trash.size()],
	]
	for i in range(lines.size()):
		_text(img, lines[i], x, y + i * 20, Color(0.82, 0.84, 0.88), 2)


func _text(img: Image, s: String, x: int, y: int, color: Color, scale: int) -> void:
	PixelFont.draw_text(img, s, x, y, color, scale)


# =========================================================================
# Scripted human turn (same shape as the smoke test)
# =========================================================================

func _drive_human_turn() -> void:
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
	if _developed() and mc.engine.state.turn_number >= 3:
		return   # stop before attacking so the snapshot shows a full board
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
