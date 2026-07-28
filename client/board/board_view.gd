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

const SEAT_HUMAN := 0
const SEAT_AI := 1

var mc: MatchController
var camera: Camera3D

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
	camera = Camera3D.new()
	camera.position = Vector3(0, 7.0, 7.6)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 0.3), Vector3.UP)
	camera.fov = 55.0
	add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.07, 0.09)
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(11, 10)
	table.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.16, 0.20)
	table.material_override = mat
	add_child(table)

	# Faint slot outlines for both seats.
	for seat in [SEAT_HUMAN, SEAT_AI]:
		for i in range(5):
			_add_slot_pad(_banner_slot(seat, i), Color(0.22, 0.25, 0.30))
		_add_slot_pad(_vanguard_slot(seat), Color(0.30, 0.26, 0.20))


func _add_slot_pad(pos: Vector3, color: Color) -> void:
	var pad := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.9, 0.9)
	pad.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	pad.material_override = m
	pad.position = pos + Vector3(0, 0.01, 0)
	add_child(pad)


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
		_aura_chips(ps, seat)
		var s := _seat_sign(seat)
		_count_marker("LIFE %d" % ps.life.size(), Vector3(3.4, 0.02, 2.0 * s), Color(0.8, 0.3, 0.3))
		_count_marker("DECK %d" % ps.deck.size(), Vector3(3.4, 0.02, 3.0 * s), Color(0.3, 0.4, 0.7))
		_count_marker("TRASH %d" % ps.trash.size(), Vector3(3.4, 0.02, 3.7 * s), Color(0.4, 0.4, 0.45))
		if seat == SEAT_AI:
			_count_marker("HAND %d" % ps.hand.size(), Vector3(-3.4, 0.02, 3.0 * s), Color(0.5, 0.45, 0.3))


func _aura_chips(ps: PlayerState, seat: int) -> void:
	var s := _seat_sign(seat)
	var avail := ps.aura_available()
	var frozen := ps.aura_frozen_pending
	for i in range(ps.aura_total):
		var chip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.1, 0.16)
		chip.mesh = bm
		var m := StandardMaterial3D.new()
		var color := Color(0.3, 0.7, 0.4)          # available
		if i >= ps.aura_total - frozen:
			color = Color(0.4, 0.7, 1.0)            # frozen
		elif i >= avail:
			color = Color(0.4, 0.4, 0.45)           # exhausted
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color * 0.4
		chip.material_override = m
		chip.position = Vector3(-2.2 + i * 0.22, 0.05, 3.9 * s)
		_markers.add_child(chip)


func _count_marker(text: String, pos: Vector3, color: Color) -> void:
	var sp := Sprite3D.new()
	sp.texture = _label_texture(text, color)
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.pixel_size = 0.01
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.position = pos + Vector3(0, 0.3, 0)
	_markers.add_child(sp)


func _label_texture(text: String, color: Color) -> Texture2D:
	var w := PixelFont.measure(text, 2) + 8
	var h := 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.09, 0.11, 0.85))
	PixelFont.draw_text(img, text, 4, 3, color, 2)
	return ImageTexture.create_from_image(img)


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
	if not mc.is_human_turn():
		return
	var inst := _find_hand(uid)
	if inst == null:
		return
	if not _can_play(inst):
		action_message.emit("Can't play %s yet (need Aura or a free slot)." % inst.data.name)
		return
	if mc.human_play_card(inst):
		action_message.emit("Played %s." % inst.data.name)
	_clear_selection()


func _on_unit_clicked(uid: int) -> void:
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
		action_message.emit("%s can't attack right now." % inst.data.name)
		_clear_selection()
		return
	_select_attacker(uid)


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
