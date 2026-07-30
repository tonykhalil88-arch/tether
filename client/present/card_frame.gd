class_name CardFrame
extends RefCounted

## Generates a SIMPLE placeholder card frame as a Texture2D straight from card
## data — no external art required. It reads only printed fields (name, type,
## cost, power/life, counter, colours, keywords) so it is a pure presentation
## helper: it renders what a card IS, it never decides what a card DOES.
##
## Everything is drawn into an `Image` with a bitmap font (PixelFont), so it
## works identically on a real GPU and under `--headless` (needed for the
## client smoke test and the SCREENS board schematic).

const W := 168
const H := 240

# Printed-colour -> frame accent. Anything unknown falls back to slate.
const COLORS := {
	"red": Color(0.78, 0.20, 0.18),
	"blue": Color(0.20, 0.42, 0.78),
	"green": Color(0.22, 0.58, 0.30),
	"purple": Color(0.52, 0.28, 0.66),
}
const NEUTRAL := Color(0.42, 0.44, 0.50)

static var _cache: Dictionary = {}


## Texture2D frame for a CardData (or a plain card dict). Cached by card id.
static func make(card) -> Texture2D:
	var d := _as_dict(card)
	var key := str(d.get("id", ""))
	if key != "" and _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(render(d))
	if key != "":
		_cache[key] = tex
	return tex


## The raw Image (useful for compositing into the board schematic).
static func render(card) -> Image:
	var d := _as_dict(card)
	var accent: Color = _accent(d.get("colors", []))
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.11, 0.13))

	# Outer accent border + inner parchment panel.
	_rect(img, 0, 0, W, H, accent)
	_rect(img, 4, 4, W - 8, H - 8, Color(0.10, 0.11, 0.13))
	_fill(img, 6, 6, W - 12, H - 12, Color(0.90, 0.87, 0.80))

	# Title band.
	_fill(img, 6, 6, W - 12, 26, accent)
	# Cost pip (top-left, over the band) drawn first so the name clears it.
	var cost := int(d.get("cost", 0))
	_disc(img, 16, 19, 9, Color(0.10, 0.11, 0.13))
	PixelFont.draw_text(img, str(cost), 13, 15, Color(1, 1, 1), 1)
	# Name to the right of the pip, clipped to the remaining band width.
	PixelFont.draw_text(img, _clip(str(d.get("name", "")).to_upper(), 10),
		30, 12, Color(0.98, 0.96, 0.92), 2)

	# Art well: a coloured plate, with the card's real art composited over it when
	# the card ships some. The plate stays as the backing so art with transparency
	# (or no art at all) still reads at a glance.
	_fill(img, 12, 40, W - 24, 120, accent.lerp(Color(0.90, 0.87, 0.80), 0.55))
	_blend_card_art(img, str(d.get("id", "")), 12, 40, W - 24, 120)
	_rect(img, 12, 40, W - 24, 120, accent)

	# Type + tribe line.
	var type_s := str(d.get("type", "")).to_upper()
	var tribe := str(d.get("tribe", "")).to_upper()
	var subtitle := type_s if tribe.is_empty() else "%s - %s" % [type_s, tribe]
	PixelFont.draw_text(img, _clip(subtitle, 26), 12, 168, Color(0.15, 0.14, 0.12), 1)

	# Keyword chips.
	var kx := 12
	for kw in d.get("keywords", []):
		var label := str(kw).to_upper()
		var cw := PixelFont.measure(label, 1) + 8
		_fill(img, kx, 182, cw, 12, accent)
		PixelFont.draw_text(img, label, kx + 4, 185, Color(1, 1, 1), 1)
		kx += cw + 4

	# Stat box (bottom-right): power for units, LIFE for vanguards.
	var is_vanguard: bool = str(d.get("type", "")) == "vanguard"
	var stat_val := int(d.get("life", 0)) if is_vanguard else int(d.get("power", 0))
	var stat_lbl := "LIFE" if is_vanguard else "PWR"
	_fill(img, W - 58, H - 34, 46, 22, Color(0.10, 0.11, 0.13))
	_rect(img, W - 58, H - 34, 46, 22, accent)
	PixelFont.draw_text(img, stat_lbl, W - 54, H - 31, accent.lightened(0.3), 1)
	PixelFont.draw_text(img, str(stat_val), W - 54, H - 23, Color(1, 1, 1), 1)

	# Counter value (bottom-left) when present.
	var ctr := int(d.get("counter", 0))
	if ctr > 0:
		PixelFont.draw_text(img, "CTR %d" % ctr, 12, H - 22, Color(0.15, 0.14, 0.12), 1)

	return img


static func clear_cache() -> void:
	_cache.clear()


# --- helpers --------------------------------------------------------------

## Composite a card's real art into the art well, cover-fitted (scaled to fill,
## centre-cropped) so it never stretches. No-op when the card ships no art.
static func _blend_card_art(img: Image, card_id: String, x: int, y: int,
		w: int, h: int) -> bool:
	if card_id.is_empty() or w <= 0 or h <= 0:
		return false
	var art := AssetManifest.card_art_image(card_id)
	if art == null or art.get_width() <= 0 or art.get_height() <= 0:
		return false
	art = art.duplicate()   # never mutate the cached texture's own image
	# Godot's "detect 3D" can re-import card art VRAM-compressed once CardVisual
	# uses it on a material; a compressed Image cannot be resized or blended.
	if art.is_compressed() and art.decompress() != OK:
		return false
	var scale: float = max(float(w) / art.get_width(), float(h) / art.get_height())
	var sw := maxi(w, int(ceil(art.get_width() * scale)))
	var sh := maxi(h, int(ceil(art.get_height() * scale)))
	art.resize(sw, sh, Image.INTERPOLATE_LANCZOS)
	var region := art.get_region(Rect2i((sw - w) / 2, (sh - h) / 2, w, h))
	if region.get_format() != img.get_format():
		region.convert(img.get_format())
	img.blend_rect(region, Rect2i(0, 0, w, h), Vector2i(x, y))
	return true

static func _as_dict(card) -> Dictionary:
	if card is CardData:
		return card.to_dict()
	if typeof(card) == TYPE_DICTIONARY:
		return card
	return {}


## NOTE: this v1 pixel-font frame is superseded by CardVisual (Card Frame v2),
## which shows dual-colour identity as a 50/50 vertical split (see PlaceholderArt).
## v1 survives only as a headless dimension check; it uses the PRIMARY colour and
## never a blended/averaged colour (per the Strict-split rule).
static func _accent(colors) -> Color:
	if typeof(colors) == TYPE_ARRAY and not colors.is_empty():
		return COLORS.get(str(colors[0]), NEUTRAL)
	return NEUTRAL


static func _clip(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n)


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	# 2px stroked border.
	_fill(img, x, y, w, 2, c)
	_fill(img, x, y + h - 2, w, 2, c)
	_fill(img, x, y, 2, h, c)
	_fill(img, x + w - 2, y, 2, h, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= img.get_width():
				continue
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, c)
