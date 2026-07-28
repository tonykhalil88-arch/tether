class_name PlaceholderArt
extends RefCounted

## Deterministic placeholder identity per card id, until Phase 4 delivers real
## art. Everything is a pure function of (id, colours, tribe): the same id always
## produces the same art, so two Stormfoals look identical and no two different
## cards collide by accident.
##
##   * palette   — from colour identity (red/blue/green/purple, blended if dual)
##   * pattern   — family chosen by tribe (stripes/scatter/chevron/grid/bricks)
##   * sigil     — a bold symmetric silhouette seeded by the id hash
##   * initial   — the name's first letter worked in as a watermark
##
## `card_art` backs the CardVisual frame; `sprite_for` is the creature billboard
## (a matching sigil) used as the AssetManifest sprite fallback — so the board
## reads at a glance instead of a field of identical diamonds.

const COLORS := {
	"red": Color(0.80, 0.24, 0.20),
	"blue": Color(0.22, 0.44, 0.80),
	"green": Color(0.24, 0.60, 0.32),
	"purple": Color(0.54, 0.30, 0.68),
}
const NEUTRAL := Color(0.45, 0.47, 0.52)

const _TRIBE_PATTERN := {
	"Redgale": "stripes",
	"Runner": "scatter",
	"Pact": "chevron",
	"Consortium": "grid",
	"Bulwark": "bricks",
}

static var _sprite_cache: Dictionary = {}


# =========================================================================
# Public
# =========================================================================

static func palette(colors: Array) -> Dictionary:
	var base := NEUTRAL
	if not colors.is_empty():
		base = COLORS.get(str(colors[0]), NEUTRAL)
		if colors.size() >= 2:
			base = base.lerp(COLORS.get(str(colors[1]), NEUTRAL), 0.5)
	return {
		"base": base,
		"dark": base.darkened(0.55),
		"accent": base.lightened(0.35),
		"ink": Color(0.96, 0.95, 0.92),
	}


## Background art Image for a card frame at (w,h). Includes dark title/stat bands
## so overlaid light text stays legible.
static func card_art(card: CardData, w: int, h: int) -> Image:
	var pal := palette(card.colors)
	var seed := _hash(card.id)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(pal["dark"])

	# Art field.
	var fx := int(w * 0.06)
	var fy := int(h * 0.14)
	var fw := w - fx * 2
	var fh := int(h * 0.52)
	_fill(img, fx, fy, fw, fh, pal["base"])
	_pattern(img, fx, fy, fw, fh, _pattern_for(card.tribe), pal, seed)
	_sigil(img, fx + fw / 2, fy + fh / 2, int(min(fw, fh) * 0.34), pal, seed)
	_initial(img, card.name, fx + 4, fy + 2, pal)

	# Colour-identity border.
	_border(img, 0, 0, w, h, 3, pal["accent"])
	# Title band (top) + stat band (bottom) for legible overlaid text.
	_fill(img, 0, 0, w, int(h * 0.12), pal["dark"].darkened(0.1))
	_fill(img, 0, int(h * 0.80), w, int(h * 0.20), pal["dark"].darkened(0.1))
	return img


## Creature billboard texture for a card (cached by id). Transparent PNG-style
## sigil silhouette in the card's palette, ~size x size.
static func sprite_for(card: CardData, size: int = 96) -> Texture2D:
	if _sprite_cache.has(card.id):
		return _sprite_cache[card.id]
	var pal := palette(card.colors)
	var seed := _hash(card.id)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Soft body blob so the sigil sits on a readable silhouette.
	_blob(img, size / 2, int(size * 0.56), int(size * 0.40), int(size * 0.34), pal["base"])
	_sigil(img, size / 2, int(size * 0.50), int(size * 0.30), pal, seed)
	_initial(img, card.name, int(size * 0.06), int(size * 0.04), pal)
	var tex := ImageTexture.create_from_image(img)
	_sprite_cache[card.id] = tex
	return tex


static func clear_cache() -> void:
	_sprite_cache.clear()


static func pattern_for(tribe: String) -> String:
	return _pattern_for(tribe)


# =========================================================================
# Internals
# =========================================================================

static func _hash(s: String) -> int:
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = (h ^ int(b)) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return h


static func _pattern_for(tribe: String) -> String:
	return _TRIBE_PATTERN.get(tribe, "grid")


static func _pattern(img: Image, x: int, y: int, w: int, h: int, kind: String,
		pal: Dictionary, seed: int) -> void:
	var line: Color = pal["dark"].lerp(pal["base"], 0.4)
	match kind:
		"stripes":
			for i in range(-h, w, 10):
				for yy in range(h):
					var xx := x + i + yy
					if xx >= x and xx < x + w:
						img.set_pixel(xx, y + yy, line)
		"scatter":
			var s := seed
			for i in range(int(w * h / 90.0)):
				s = (s * 1103515245 + 12345) & 0x7fffffff
				var px := x + s % w
				s = (s * 1103515245 + 12345) & 0x7fffffff
				var py := y + s % h
				_disc(img, px, py, 2, line)
		"chevron":
			for yy in range(0, h, 8):
				for xx in range(w):
					var d := absi((xx % 24) - 12)
					if absi((yy) - d) <= 1:
						if x + xx < x + w:
							img.set_pixel(x + xx, y + yy, line)
		"grid":
			for xx in range(x, x + w, 12):
				_fill(img, xx, y, 1, h, line)
			for yy in range(y, y + h, 12):
				_fill(img, x, yy, w, 1, line)
		"bricks":
			for row in range(0, h, 10):
				var off := 0 if (row / 10) % 2 == 0 else 12
				_fill(img, x, y + row, w, 1, line)
				for col in range(off, w, 24):
					_fill(img, x + col, y + row, 1, min(10, h - row), line)


static func _sigil(img: Image, cx: int, cy: int, r: int, pal: Dictionary, seed: int) -> void:
	# A symmetric star/gear seeded by the hash: number of points 5..9, drawn as a
	# filled radial polygon mirrored across the vertical axis for symmetry.
	var points := 5 + (seed % 5)
	var accent: Color = pal["accent"]
	var ink: Color = pal["ink"]
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= img.get_width():
				continue
			var dx := float(x - cx)
			var dy := float(y - cy)
			var dist := sqrt(dx * dx + dy * dy)
			if dist > r:
				continue
			var ang := atan2(dy, absf(dx))          # mirror across vertical axis
			var lobe := 0.62 + 0.38 * cos(ang * points)
			if dist <= r * lobe:
				img.set_pixel(x, y, accent if dist > r * lobe * 0.55 else ink)


static func _initial(img: Image, name: String, x: int, y: int, pal: Dictionary) -> void:
	if name.is_empty():
		return
	var ch := name.substr(0, 1).to_upper()
	# Large watermark initial via the bitmap font (decorative, not the readable
	# frame label — that is a real-font Label3D on top).
	PixelFont.draw_text(img, ch, x, y, Color(pal["ink"].r, pal["ink"].g, pal["ink"].b, 0.5), 4)


# --- primitive drawing ----------------------------------------------------

static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var rx := clampi(x, 0, img.get_width())
	var ry := clampi(y, 0, img.get_height())
	var rw := clampi(w, 0, img.get_width() - rx)
	var rh := clampi(h, 0, img.get_height() - ry)
	if rw > 0 and rh > 0:
		img.fill_rect(Rect2i(rx, ry, rw, rh), c)


static func _border(img: Image, x: int, y: int, w: int, h: int, t: int, c: Color) -> void:
	_fill(img, x, y, w, t, c)
	_fill(img, x, y + h - t, w, t, c)
	_fill(img, x, y, t, h, c)
	_fill(img, x + w - t, y, t, h, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= img.get_width():
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, c)


static func _blob(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or x >= img.get_width():
				continue
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, c)
