class_name CardInspector
extends CanvasLayer

## MTG-Arena-style card reader. Hovering any card for ~0.3s shows a large,
## fully-legible panel on the right; clicking a card pins it open; Esc or a
## click-away closes it. It lives on its own high layer so it works during
## prompts too (reading the attacker while you pick counters is the whole game).
##
## Pure presentation: it renders a CardData via CardText + PlaceholderArt.

const SHOW_DELAY := 0.3
const HIDE_DELAY := 0.15

var _panel: PanelContainer
var _band: TextureRect
var _art: TextureRect
var _title: Label
var _meta: Label
var _body: RichTextLabel
var _pin_hint: Label

var _pinned: bool = false
var _pending: CardData
var _current: CardData
var _show_timer: Timer
var _hide_timer: Timer


func _ready() -> void:
	layer = 3
	_build()
	_show_timer = _mk_timer(SHOW_DELAY, _on_show)
	_hide_timer = _mk_timer(HIDE_DELAY, _on_hide)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-368, 20)
	_panel.custom_minimum_size = Vector2(348, 0)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	sb.border_color = Color(0.5, 0.45, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	# Colour-identity header band: a 50/50 vertical split for dual cards (left =
	# colour A, right = colour B), solid for mono. Never a blended colour.
	_band = TextureRect.new()
	_band.custom_minimum_size = Vector2(324, 10)
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(_band)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	_meta = Label.new()
	_meta.add_theme_font_size_override("font_size", 15)
	_meta.add_theme_color_override("font_color", Color(0.75, 0.78, 0.68))
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_meta)

	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(324, 200)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_art)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(324, 0)
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 17)
	box.add_child(_body)

	_pin_hint = Label.new()
	_pin_hint.add_theme_font_size_override("font_size", 13)
	_pin_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	box.add_child(_pin_hint)


# =========================================================================
# Public API (driven by the board / prompts)
# =========================================================================

func hover_show(card: CardData) -> void:
	if card == null:
		return
	_pending = card
	_hide_timer.stop()
	if _panel.visible:
		# Already open — swap to the hovered card immediately (pinned or not).
		_populate(card)
	else:
		_show_timer.start()


func hover_out() -> void:
	_show_timer.stop()
	if not _pinned:
		_hide_timer.start()


func pin(card: CardData) -> void:
	if card == null:
		return
	_pinned = true
	_populate(card)


func close() -> void:
	_pinned = false
	_show_timer.stop()
	_hide_timer.stop()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func current_card() -> CardData:
	return _current


## The rendered body text (for tests / data-binding checks).
func inspected_text() -> String:
	return _body.text if _body != null else ""


func meta_text() -> String:
	return _meta.text if _meta != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _panel.visible:
		close()
		get_viewport().set_input_as_handled()


# =========================================================================
# Internals
# =========================================================================

func _on_show() -> void:
	if _pending != null:
		_populate(_pending)


func _on_hide() -> void:
	if not _pinned:
		_panel.visible = false


func _populate(card: CardData) -> void:
	_current = card
	_title.text = card.name
	_meta.text = _meta_line(card)
	_band.texture = _identity_band(card)
	# Real card art when the card ships some; procedural sigil otherwise.
	var art := AssetManifest.card_art(card.id)
	_art.texture = art if art != null else ImageTexture.create_from_image(
		PlaceholderArt.card_art(card, 336, 480))
	_body.text = _body_bbcode(card)
	_pin_hint.text = "click a card to pin · Esc to close" if not _pinned else "pinned · Esc to close"
	_panel.visible = true


## A 2px-wide identity texture: left column = colour A, right = colour B. Stretched
## across the header band it reads as a 50/50 vertical split (solid for mono).
func _identity_band(card: CardData) -> Texture2D:
	var cols: Array = PlaceholderArt.identity_colors(card.colors)
	var img := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, cols[0])
	img.set_pixel(1, 0, cols[1])
	return ImageTexture.create_from_image(img)


func _meta_line(card: CardData) -> String:
	var parts: Array = ["Cost %d" % card.cost]
	if card.type == CardEnums.TYPE_VANGUARD:
		parts.append("Life %d" % card.vanguard_life())
	else:
		parts.append("Power %d" % card.power)
	if card.counter > 0:
		parts.append("Counter %d" % card.counter)
	parts.append(card.type.capitalize())
	if not card.tribe.is_empty():
		parts.append(card.tribe)
	if not card.colors.is_empty():
		parts.append("/".join(card.colors))
	return "  ·  ".join(parts)


func _body_bbcode(card: CardData) -> String:
	var out := ""
	var kw := CardText.keyword_lines(card)
	for line in kw:
		out += "[b]%s[/b]\n" % line
	for e in card.effects:
		if typeof(e) == TYPE_DICTIONARY:
			out += CardText.describe_effect(e) + "\n"
	if out.strip_edges().is_empty():
		out = "[i]No printed abilities.[/i]\n"
	if not card.flavor.is_empty():
		out += "\n[i]%s[/i]" % card.flavor
	return out


func _mk_timer(wait: float, cb: Callable) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = wait
	t.timeout.connect(cb)
	add_child(t)
	return t
