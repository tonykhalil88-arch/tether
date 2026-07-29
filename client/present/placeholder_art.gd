class_name PlaceholderArt
extends RefCounted

## Deterministic placeholder identity per card id, until Phase 4 delivers real
## art. Everything is a pure function of (id, colours, tribe): the same id always
## produces the same art, so two Stormfoals look identical and no two different
## cards collide by accident.
##
##   * palette   — from colour identity. Mono = one colour; DUAL = a 50/50
##                 vertical SPLIT (left = colour A, right = colour B, order as
##                 listed in colors[]) — NEVER a blended/averaged colour.
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

## Palette for a single colour (never blended).
static func _one(color: Color) -> Dictionary:
	return {
		"base": color,
		"dark": color.darkened(0.55),
		"accent": color.lightened(0.35),
		"ink": Color(0.96, 0.95, 0.92),
	}


## The two identity palettes [A, B]. Mono cards return the same palette twice, so
## every draw path can treat the card as a 50/50 split uniformly (a mono split of
## one colour is indistinguishable from a solid fill).
static func palettes(colors: Array) -> Array:
	var a := NEUTRAL
	var b := NEUTRAL
	if not colors.is_empty():
		a = COLORS.get(str(colors[0]), NEUTRAL)
		b = COLORS.get(str(colors[1]), a) if colors.size() >= 2 else a
	return [_one(a), _one(b)]


## Primary identity palette (colour A). Back-compat convenience; NOT blended.
static func palette(colors: Array) -> Dictionary:
	return palettes(colors)[0]


## The card's identity colours [A, B] (base tones), for chips/bands elsewhere.
## Mono returns the same colour twice.
static func identity_colors(colors: Array) -> Array:
	var p := palettes(colors)
	return [p[0]["base"], p[1]["base"]]


## Background art Image for a card frame at (w,h). Dual cards split left/right;
## mono cards look solid. Dark title/stat bands keep overlaid light text legible.
static func card_art(card: CardData, w: int, h: int) -> Image:
	var ps := palettes(card.colors)
	var A: Dictionary = ps[0]
	var B: Dictionary = ps[1]
	var seed := _hash(card.id)
	var mid := int(w * 0.5)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# Split background.
	_fill(img, 0, 0, mid, h, A["dark"])
	_fill(img, mid, 0, w - mid, h, B["dark"])

	# Split art field, patterned per half.
	var fx := int(w * 0.06)
	var fy := int(h * 0.14)
	var fw := w - fx * 2
	var fh := int(h * 0.52)
	_fill(img, fx, fy, mid - fx, fh, A["base"])
	_fill(img, mid, fy, fx + fw - mid, fh, B["base"])
	_pattern(img, fx, fy, mid - fx, fh, _pattern_for(card.tribe), A, seed)
	_pattern(img, mid, fy, fx + fw - mid, fh, _pattern_for(card.tribe), B, seed)
	# Sigil centred on the split line, coloured per half.
	_sigil(img, mid, fy + fh / 2, int(min(fw, fh) * 0.34), A, B, seed)
	_initial(img, card.name, fx + 4, fy + 2, A)

	# Split colour-identity border.
	_border_lr(img, 0, 0, w, h, 3, A["accent"], B["accent"])
	# Title band (top) + stat band (bottom), each split so identity still reads.
	_band(img, 0, int(h * 0.12), A, B, mid, w, 0, 0)
	_band(img, int(h * 0.80), int(h * 0.20), A, B, mid, w, 0, 0)
	return img


## Creature billboard texture for a card (cached by id). Dual cards use a split
## body + split sigil; mono cards look solid.
static func sprite_for(card: CardData, size: int = 96) -> Texture2D:
	if _sprite_cache.has(card.id):
		return _sprite_cache[card.id]
	var ps := palettes(card.colors)
	var A: Dictionary = ps[0]
	var B: Dictionary = ps[1]
	var seed := _hash(card.id)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_blob(img, size / 2, int(size * 0.56), int(size * 0.40), int(size * 0.34), A, B)
	_sigil(img, size / 2, int(size * 0.50), int(size * 0.30), A, B, seed)
	# NOTE: no name-initial watermark on the billboard — the floating pixel-font
	# letter read as debug text. Identity comes from the CardVisual nameplate
	# (real-font name on the frame) + the colour/sigil (palette approved as-is).
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


static func _sigil(img: Image, cx: int, cy: int, r: int, A: Dictionary, B: Dictionary, seed: int) -> void:
	# A symmetric star/gear seeded by the hash: number of points 5..9, drawn as a
	# filled radial polygon mirrored across the vertical axis for symmetry. The
	# left half uses palette A, the right half palette B (split down the centre).
	var points := 5 + (seed % 5)
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
				var pal: Dictionary = A if x < cx else B
				img.set_pixel(x, y, pal["accent"] if dist > r * lobe * 0.55 else pal["ink"])


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


## Split border: top/bottom edges split at the centre, left edge = A, right = B.
static func _border_lr(img: Image, x: int, y: int, w: int, h: int, t: int,
		cA: Color, cB: Color) -> void:
	var mid := int(img.get_width() * 0.5)
	_fill(img, x, y, mid - x, t, cA)
	_fill(img, mid, y, x + w - mid, t, cB)
	_fill(img, x, y + h - t, mid - x, t, cA)
	_fill(img, mid, y + h - t, x + w - mid, t, cB)
	_fill(img, x, y, t, h, cA)
	_fill(img, x + w - t, y, t, h, cB)


## A darkened title/stat band, split left/right so identity reads inside it too.
static func _band(img: Image, y: int, h: int, A: Dictionary, B: Dictionary,
		mid: int, w: int, _a: int, _b: int) -> void:
	_fill(img, 0, y, mid, h, A["dark"].darkened(0.1))
	_fill(img, mid, y, w - mid, h, B["dark"].darkened(0.1))


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= img.get_width():
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, c)


static func _blob(img: Image, cx: int, cy: int, rx: int, ry: int, A: Dictionary, B: Dictionary) -> void:
	for y in range(cy - ry, cy + ry + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or x >= img.get_width():
				continue
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, (A if x < cx else B)["base"])
