class_name PixelFont
extends RefCounted

## A tiny embedded 5x7 bitmap font so the client can rasterise readable text
## straight into an `Image` — no GPU, no FontFile, no TextServer. That keeps
## the placeholder CardFrame generator and the SCREENS board schematic working
## under `--headless` (where nothing can be drawn to a viewport).
##
## Glyphs cover A–Z, 0–9, space and the punctuation that shows up in card
## names / stats. Lower-case is folded to upper-case; unknown glyphs render as
## a hollow box so nothing silently vanishes.

const GW := 5
const GH := 7

# Authoring form: each glyph is 7 rows of 5 chars ("1" = ink). Converted to
# bit rows once, lazily, into `_bits`.
const _GLYPHS := {
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11100", "10010", "10001", "10001", "10001", "10010", "11100"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
	":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
	"!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
	"'": ["00100", "00100", "00100", "00000", "00000", "00000", "00000"],
	"(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
	")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
	"&": ["01100", "10010", "10010", "01100", "10101", "10010", "01101"],
	"%": ["11001", "11010", "00100", "01000", "01011", "10011", "00000"],
	"#": ["01010", "01010", "11111", "01010", "11111", "01010", "01010"],
}

const _MISSING := ["11111", "10001", "10001", "10001", "10001", "10001", "11111"]

static var _bits: Dictionary = {}


static func _ensure() -> void:
	if not _bits.is_empty():
		return
	for ch in _GLYPHS.keys():
		_bits[ch] = _to_rows(_GLYPHS[ch])
	_bits["__missing__"] = _to_rows(_MISSING)


static func _to_rows(rows: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in rows:
		var v := 0
		var s: String = r
		for i in range(GW):
			v = (v << 1) | (1 if s[i] == "1" else 0)
		out.append(v)
	return out


static func _rows_for(ch: String) -> PackedInt32Array:
	_ensure()
	var up := ch.to_upper()
	if _bits.has(up):
		return _bits[up]
	if _bits.has(ch):
		return _bits[ch]
	return _bits["__missing__"]


## Pixel width of `text` at the given scale (1px glyph gap included).
static func measure(text: String, scale: int = 1) -> int:
	if text.is_empty():
		return 0
	return text.length() * (GW + 1) * scale - scale


## Blit `text` into `img` with top-left at (x,y). `scale` enlarges each glyph
## pixel to a scale×scale block. Clipped to the image bounds.
static func draw_text(img: Image, text: String, x: int, y: int, color: Color,
		scale: int = 1) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := x
	for ci in range(text.length()):
		var rows := _rows_for(text[ci])
		for ry in range(GH):
			var bits: int = rows[ry]
			for rxi in range(GW):
				if (bits >> (GW - 1 - rxi)) & 1:
					_block(img, cx + rxi * scale, y + ry * scale, scale, color, w, h)
		cx += (GW + 1) * scale


static func _block(img: Image, px: int, py: int, s: int, color: Color,
		w: int, h: int) -> void:
	for dy in range(s):
		var yy := py + dy
		if yy < 0 or yy >= h:
			continue
		for dx in range(s):
			var xx := px + dx
			if xx >= 0 and xx < w:
				img.set_pixel(xx, yy, color)
