class_name BoardView
extends Node3D

## The 3D table. Builds a fixed, angled camera scene in code and reconciles the
## visible board (units, hand, aura chips, life/deck/trash counts) from the
## engine's PUBLIC state each time the board changes. Transient animations
## (summon / attack / ko / freeze / bounce) are driven off PresentationQueue
## beats, so the visuals follow the same public event stream the AI sees.
##
## It also owns human *selection* input: click a hand card to play it, click a
## unit to pick an attacker, click a highlighted enemy to attack. It asks the
## MatchController to perform actions — it never touches the engine directly.

signal action_message(text: String)
signal attacker_selected(has_attacker: bool)
signal card_reason(uid: int, text: String)

const SEAT_HUMAN := 0
const SEAT_AI := 1
const _AMBIENT_BASE := 1.15

var mc: MatchController
var camera: Camera3D
var inspector: CardInspector

var _env: Environment
var _brightness: float = 1.0

var _units: Dictionary = {}       # uid -> UnitView
var _hand: Dictionary = {}        # uid -> HandCardView
var _markers: Node3D
var _selected_attacker: int = -1
var _pending_attach: int = 0
var _legal_targets: Array = []    # uids currently highlighted as attack targets


func bind(controller: MatchController) -> void:
	mc = controller
	mc.ensure_infra()
	_ensure_built()
	mc.board_dirty.connect(reconcile)
	mc.queue.beat_started.connect(_on_beat_started)
	mc.queue.queue_drained.connect(reconcile)


func _ready() -> void:
	_ensure_built()


## Build the static table + marker layer exactly once, regardless of whether
## _ready or bind() runs first.
func _ensure_built() -> void:
	if _markers != null:
		return
	_build_static()
	_markers = Node3D.new()
	add_child(_markers)


# =========================================================================
# Static scene
# =========================================================================

func _build_static() -> void:
	# Camera: tighter framing, slightly lower angle for depth.
	camera = Camera3D.new()
	camera.position = Vector3(0, 5.6, 7.4)
	camera.look_at_from_position(camera.position, Vector3(0, 0.1, 0.2), Vector3.UP)
	camera.fov = 50.0
	add_child(camera)

	# Warm key light with soft shadows.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -34, 0)
	key.light_color = Color(1.0, 0.95, 0.86)
	key.light_energy = 1.7
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	add_child(key)

	# Cool fill, no shadow, opposite side.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32, 140, 0)
	fill.light_color = Color(0.78, 0.86, 1.0)
	fill.light_energy = 0.8
	add_child(fill)

	# WorldEnvironment. READABLE FIRST, moody second (Brief 10): strong ambient,
	# LINEAR tonemap (no midtone crush) with an exposure the brightness slider
	# drives, and only a whisper of glow. Default exposure lands every slot and
	# zone clearly readable on normally lit monitors.
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.65, 0.72)
	e.ambient_light_energy = _AMBIENT_BASE
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.25
	e.glow_bloom = 0.1
	e.glow_hdr_threshold = 1.2
	_env = e
	var env := WorldEnvironment.new()
	env.environment = e
	add_child(env)

	# Table: warm stone/wood tone, lifted so it reads against the background.
	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 10.5)
	table.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.15, 0.12)
	mat.roughness = 0.7
	mat.metallic = 0.05
	table.material_override = mat
	table.position = Vector3(0, -0.02, 0)
	add_child(table)

	# Carved zone inlays for both seats (brighter so slots clearly separate from
	# the table and the background).
	for seat in [SEAT_HUMAN, SEAT_AI]:
		for i in range(5):
			_add_slot_pad(_banner_slot(seat, i), 0.92, Color(0.30, 0.33, 0.40))
		_add_slot_pad(_vanguard_slot(seat), 1.0, Color(0.46, 0.37, 0.22))
		_add_slot_pad(_stage_slot(seat), 0.9, Color(0.34, 0.30, 0.42))

	_build_vignette()
	set_brightness(_brightness)


## A carved-looking inlay: a recessed dark plate with a bright rim so slots read
## as cut into the table rather than floating on it.
func _add_slot_pad(pos: Vector3, size: float, color: Color) -> void:
	var rim := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(size + 0.06, size + 0.06)
	rim.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color.lightened(0.25)
	rmat.emission_enabled = true
	rmat.emission = color.lightened(0.1)
	rmat.emission_energy_multiplier = 0.25
	rim.material_override = rmat
	rim.position = pos + Vector3(0, 0.008, 0)
	add_child(rim)

	var inlay := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	inlay.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.35)
	m.roughness = 0.9
	inlay.material_override = m
	inlay.position = pos + Vector3(0, 0.014, 0)
	add_child(inlay)


## Subtle screen vignette (generated radial alpha, no shader) so the eye settles
## on the board centre. Darkens corners only.
func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = _vignette_texture()
	layer.add_child(tr)


func _vignette_texture() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	var maxd := sqrt(2.0) * c
	for y in range(n):
		for x in range(n):
			var d := sqrt(pow(x - c, 2) + pow(y - c, 2)) / maxd
			# Eased off (Brief 12.1): starts further out, much lighter, so it
			# frames the board without darkening the play area.
			var a := clampf((d - 0.72) / 0.28, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * 0.28))
	return ImageTexture.create_from_image(img)


## In-game brightness (Environment exposure multiplier), driven by the menu/HUD
## slider so per-monitor variance is user-fixable. 1.0 = default.
func set_brightness(value: float) -> void:
	_brightness = clampf(value, 0.4, 2.5)
	if _env != null:
		_env.tonemap_exposure = _brightness
		_env.ambient_light_energy = _AMBIENT_BASE * _brightness


func brightness() -> float:
	return _brightness


# =========================================================================
# Slot geometry
# =========================================================================

func _seat_sign(seat: int) -> float:
	return 1.0 if seat == SEAT_HUMAN else -1.0


func _banner_slot(seat: int, i: int) -> Vector3:
	return Vector3(-2.0 + i * 1.0, 0.0, 1.6 * _seat_sign(seat))


func _vanguard_slot(seat: int) -> Vector3:
	return Vector3(0.0, 0.0, 3.0 * _seat_sign(seat))


func _stage_slot(seat: int) -> Vector3:
	return Vector3(-3.3, 0.0, 2.3 * _seat_sign(seat))


func _hand_slot(i: int, n: int) -> Vector3:
	var spread := 0.62
	var x := (i - (n - 1) * 0.5) * spread
	return Vector3(x, 0.35, 4.3)


# =========================================================================
# Reconcile from engine state
# =========================================================================

func reconcile() -> void:
	if mc == null or mc.engine == null:
		return
	var live_units: Dictionary = {}
	for seat in [SEAT_HUMAN, SEAT_AI]:
		var ps: PlayerState = mc.player(seat)
		if ps.vanguard != null:
			_place_unit(ps.vanguard, _vanguard_slot(seat), live_units)
		for i in range(ps.battle_area.size()):
			_place_unit(ps.battle_area[i], _banner_slot(seat, i), live_units)
		if ps.stage != null:
			_place_unit(ps.stage, _stage_slot(seat), live_units)
	_prune(_units, live_units)

	_reconcile_hand()
	_rebuild_markers()
	_refresh_target_highlights()


func _place_unit(inst: CardInstance, pos: Vector3, live: Dictionary) -> void:
	live[inst.uid] = true
	var uv: UnitView = _units.get(inst.uid)
	if uv == null:
		uv = UnitView.new()
		add_child(uv)
		uv.setup(inst.data.id, inst.uid)
		uv.clicked.connect(_on_unit_clicked)
		uv.hovered.connect(_on_card_hovered)
		uv.unhovered.connect(_on_card_unhovered)
		_units[inst.uid] = uv
	uv.position = pos
	uv.set_status(inst.exhausted, inst.frozen)


func _reconcile_hand() -> void:
	var ps: PlayerState = mc.player(SEAT_HUMAN)
	var live: Dictionary = {}
	var n := ps.hand.size()
	for i in range(n):
		var inst: CardInstance = ps.hand[i]
		live[inst.uid] = true
		var hv: HandCardView = _hand.get(inst.uid)
		if hv == null:
			hv = HandCardView.new()
			add_child(hv)
			hv.setup(inst.data.id, inst.uid)
			hv.clicked.connect(_on_hand_clicked)
			hv.hovered.connect(_on_card_hovered)
			hv.unhovered.connect(_on_card_unhovered)
			_hand[inst.uid] = hv
		hv.position = _hand_slot(i, n)
		hv.rotation_degrees = Vector3(-62, 0, 0)
		hv.remember_base_y()
		hv.set_playable(_can_play(inst))
	_prune(_hand, live)


func _can_play(inst: CardInstance) -> bool:
	if not mc.is_human_turn():
		return false
	var ps: PlayerState = mc.player(SEAT_HUMAN)
	if inst.type() == CardEnums.TYPE_BANNER and ps.battle_area_full():
		return false
	return inst.data.cost <= ps.aura_available()


func _prune(store: Dictionary, live: Dictionary) -> void:
	for uid in store.keys():
		if not live.has(uid):
			var node: Node = store[uid]
			if is_instance_valid(node):
				node.queue_free()
			store.erase(uid)


# =========================================================================
# Aura chips + zone counts
# =========================================================================

func _rebuild_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	for seat in [SEAT_HUMAN, SEAT_AI]:
		var ps: PlayerState = mc.player(seat)
		_aura_rack(ps, seat)
		var s := _seat_sign(seat)
		_plaque("LIFE %d" % ps.life.size(), Vector3(3.7, 0.02, 1.9 * s), Color(0.95, 0.5, 0.5))
		_plaque("DECK %d" % ps.deck.size(), Vector3(3.7, 0.02, 2.9 * s), Color(0.55, 0.65, 0.95))
		_plaque("TRASH %d" % ps.trash.size(), Vector3(3.7, 0.02, 3.7 * s), Color(0.7, 0.7, 0.75))
		_plaque("HAND %d" % ps.hand.size(), Vector3(-3.7, 0.02, 3.2 * s), Color(0.9, 0.82, 0.55))


## Aura rack v2: a fixed rack of large chips — bright when refreshed, dim when
## exhausted, ice-blue when frozen — with a numeric counter, readable for both
## players at all times.
func _aura_rack(ps: PlayerState, seat: int) -> void:
	var s := _seat_sign(seat)
	var z := 4.15 * s
	var avail := ps.aura_available()
	var frozen := ps.aura_frozen_pending
	var total := ps.aura_total

	# Rack base plate.
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.5, 0.05, 0.4)
	base.mesh = bm
	var basemat := StandardMaterial3D.new()
	basemat.albedo_color = Color(0.08, 0.08, 0.1)
	base.material_override = basemat
	base.position = Vector3(-0.1, 0.03, z)
	_markers.add_child(base)

	for i in range(maxi(total, 1)):
		if i >= total:
			break
		var chip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.11
		cm.bottom_radius = 0.11
		cm.height = 0.12
		chip.mesh = cm
		var m := StandardMaterial3D.new()
		var color := Color(0.35, 0.85, 0.5)              # refreshed (bright)
		var energy := 0.7
		if i >= total - frozen:
			color = Color(0.5, 0.8, 1.0)                 # frozen (ice-blue)
			energy = 0.9
		elif i >= avail:
			color = Color(0.32, 0.34, 0.4)               # exhausted (dim)
			energy = 0.05
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		chip.material_override = m
		chip.position = Vector3(-1.2 + i * 0.24, 0.11, z)
		_markers.add_child(chip)

	var counter := "AURA %d/%d" % [avail, total]
	if frozen > 0:
		counter += " (%d frozen)" % frozen
	_label3d(counter, Vector3(-1.35, 0.34, z), 30, Color(0.75, 0.95, 0.85),
		HORIZONTAL_ALIGNMENT_LEFT)


## A small billboarded plaque (real font) anchored at a zone.
func _plaque(text: String, pos: Vector3, color: Color) -> void:
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.95, 0.04, 0.34)
	plate.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.08)
	plate.material_override = mat
	plate.position = pos + Vector3(0, 0.02, 0)
	_markers.add_child(plate)
	_label3d(text, pos + Vector3(0, 0.34, 0), 26, color, HORIZONTAL_ALIGNMENT_CENTER)


func _label3d(text: String, pos: Vector3, font_size: int, color: Color,
		align: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.horizontal_alignment = align
	l.position = pos
	_markers.add_child(l)


# =========================================================================
# Beat-driven animation
# =========================================================================

func _on_beat_started(beat: Dictionary) -> void:
	var kind := str(beat.get("kind", ""))
	var uid := int(beat.get("uid", -1))
	match kind:
		"play_banner", "play_self":
			var uv: UnitView = _units.get(uid)
			if uv != null:
				uv.enter_state(SummonStateMachine.SUMMON)
		"attack":
			var au: UnitView = _units.get(int(beat.get("attacker", -1)))
			if au != null:
				au.attack()
			if bool(beat.get("ko", false)):
				var tu: UnitView = _units.get(int(beat.get("target", -1)))
				if tu != null:
					tu.enter_state(SummonStateMachine.DAMAGED)
			elif bool(beat.get("life_flipped", false)):
				_flash_target(int(beat.get("target", -1)))
		"ko":
			var ku: UnitView = _units.get(uid)
			if ku != null:
				ku.enter_state(SummonStateMachine.KO)
		"freeze_banner":
			var fu: UnitView = _units.get(uid)
			if fu != null:
				fu.enter_state(SummonStateMachine.FROZEN)
		"bounce":
			var bu: UnitView = _units.get(uid)
			if bu != null:
				bu.enter_state(SummonStateMachine.BOUNCE)


func _flash_target(uid: int) -> void:
	var uv: UnitView = _units.get(uid)
	if uv != null:
		uv.enter_state(SummonStateMachine.LIFE_TRIGGER_REVEAL)


# =========================================================================
# Human selection input
# =========================================================================

func _on_hand_clicked(uid: int) -> void:
	var inst := _find_hand(uid)
	if inst == null:
		return
	_pin(inst)                      # click pins the inspector for reading
	if not mc.is_human_turn():
		return
	if not _can_play(inst):
		_reason(uid, "Can't play %s: need Aura or a free slot." % inst.data.name)
		return
	if mc.human_play_card(inst):
		action_message.emit("Played %s." % inst.data.name)
	_clear_selection()


func _on_unit_clicked(uid: int) -> void:
	var clicked := _find_unit_inst(uid)
	if clicked != null:
		_pin(clicked)               # click pins the inspector for reading
	if not mc.is_human_turn():
		return
	# Second click on a highlighted enemy -> attack.
	if _selected_attacker >= 0 and _legal_targets.has(uid):
		var attacker := _find_unit_inst(_selected_attacker)
		var target := _find_unit_inst(uid)
		if attacker != null and target != null:
			var res := mc.human_declare_attack(attacker, target, _pending_attach)
			if res.get("ok", false):
				action_message.emit("%s attacks %s." % [attacker.data.name, target.data.name])
		_clear_selection()
		return
	# Otherwise try to select this unit as an attacker.
	var inst := _find_unit_inst(uid)
	if inst == null or inst.owner != SEAT_HUMAN:
		_clear_selection()
		return
	if not mc.engine.can_attack(inst):
		_reason(uid, "%s can't attack: %s." % [inst.data.name, _why_cant_attack(inst)])
		_clear_selection()
		return
	_select_attacker(uid)


## Human-readable reason a unit can't attack (presentation-only inference from
## public state — mirrors the engine's can_attack rule).
func _why_cant_attack(inst: CardInstance) -> String:
	if inst.owner != SEAT_HUMAN:
		return "not yours"
	if inst.frozen:
		return "frozen"
	if inst.exhausted:
		return "exhausted (rested)"
	if inst.summoning_sick and not inst.has_keyword(CardEnums.KW_RUSH):
		return "summoning sick this turn"
	return "not right now"


func _select_attacker(uid: int) -> void:
	_clear_selection()
	_selected_attacker = uid
	_pending_attach = 0
	var inst := _find_unit_inst(uid)
	_legal_targets.clear()
	for t in mc.engine.legal_attack_targets(inst):
		_legal_targets.append(t.uid)
	_refresh_target_highlights()
	if _units.has(uid):
		_units[uid].set_highlight(true, Color(0.3, 0.9, 0.4))
	attacker_selected.emit(true)


func _clear_selection() -> void:
	_selected_attacker = -1
	_pending_attach = 0
	_legal_targets.clear()
	_refresh_target_highlights()
	attacker_selected.emit(false)


func _refresh_target_highlights() -> void:
	for uid in _units.keys():
		var uv: UnitView = _units[uid]
		if uid == _selected_attacker:
			uv.set_highlight(true, Color(0.3, 0.9, 0.4))
		elif _legal_targets.has(uid):
			uv.set_highlight(true, Color(0.95, 0.3, 0.3))
		else:
			uv.set_highlight(false)


# --- HUD-driven helpers ---------------------------------------------------

func set_pending_attach(n: int) -> void:
	_pending_attach = maxi(0, n)


func pending_attach() -> int:
	return _pending_attach


func has_attacker() -> bool:
	return _selected_attacker >= 0


# --- inspector + reasons --------------------------------------------------

func set_inspector(insp: CardInspector) -> void:
	inspector = insp


func _on_card_hovered(uid: int) -> void:
	if inspector != null:
		inspector.hover_show(_card_for_uid(uid))


func _on_card_unhovered(_uid: int) -> void:
	if inspector != null:
		inspector.hover_out()


func _pin(inst: CardInstance) -> void:
	if inspector != null and inst != null:
		inspector.pin(inst.data)


func _reason(uid: int, text: String) -> void:
	action_message.emit(text)
	card_reason.emit(uid, text)


func _card_for_uid(uid: int) -> CardData:
	var u := _find_unit_inst(uid)
	if u != null:
		return u.data
	var h := _find_hand(uid)
	return h.data if h != null else null


## World position just above a unit/hand card (for floating reason labels).
func world_pos_for_uid(uid: int) -> Vector3:
	if _units.has(uid):
		return (_units[uid] as Node3D).global_position + Vector3(0, 1.2, 0)
	if _hand.has(uid):
		return (_hand[uid] as Node3D).global_position + Vector3(0, 0.6, 0)
	return Vector3.ZERO


func camera_unproject(world: Vector3) -> Vector2:
	if camera != null:
		return camera.unproject_position(world)
	return Vector2.ZERO


# --- lookups --------------------------------------------------------------

func _find_hand(uid: int) -> CardInstance:
	for c in mc.player(SEAT_HUMAN).hand:
		if c.uid == uid:
			return c
	return null


func _find_unit_inst(uid: int) -> CardInstance:
	for seat in [SEAT_HUMAN, SEAT_AI]:
		var ps: PlayerState = mc.player(seat)
		if ps.vanguard != null and ps.vanguard.uid == uid:
			return ps.vanguard
		for b in ps.battle_area:
			if b.uid == uid:
				return b
		if ps.stage != null and ps.stage.uid == uid:
			return ps.stage
	return null
