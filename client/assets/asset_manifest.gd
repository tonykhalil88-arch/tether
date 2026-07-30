class_name AssetManifest
extends RefCounted

## Resolves a card's four presentation channels (sprite / SFX / VFX / voice)
## from `assets/cards/<card_id>/` with graceful fallbacks, so ART DROPS IN
## WITHOUT CODE CHANGES (the Phase 4 contract).
##
## Convention per card directory:
##   manifest.json  — { "sprite": {...}, "sfx": {...}, "voice": {...}, "vfx": {...},
##                      "art": { "card": "card_art.png" } }
##   sprite.png     — idle sheet (hframes x vframes)
##   attack.png     — attack sheet (optional)
##   card_art.png   — full-bleed card-face art (optional; replaces PlaceholderArt)
##   summon.wav / hit.wav / voice.wav
##   vfx.tscn       — optional VFX scene
##
## Resolution order for each asset: manifest-named file -> convention-named file
## -> generated placeholder (sprite/SFX) or null (voice/VFX/card art). PNGs and
## WAVs are hot-loaded (Image.load / a small RIFF reader) so freshly ingested
## assets need no reimport; VFX resolves through ResourceLoader.

const CARDS_DIR := "res://assets/cards"

static var _cache: Dictionary = {}
static var _placeholder_sprite: Texture2D = null
static var _default_whoosh: AudioStream = null


## Resolved presentation bundle for a card. Cached per id.
static func resolve(card_id: String) -> Dictionary:
	if _cache.has(card_id):
		return _cache[card_id]
	var dir := "%s/%s" % [CARDS_DIR, card_id]
	var m := _read_manifest(dir)
	var sprite: Dictionary = m.get("sprite", {})
	var sfx: Dictionary = m.get("sfx", {})
	var voice: Dictionary = m.get("voice", {})
	var vfx: Dictionary = m.get("vfx", {})
	var art: Dictionary = m.get("art", {})
	var bundle := {
		"id": card_id,
		"has_manifest": not m.is_empty(),
		"card_art": _texture(dir, str(art.get("card", "card_art.png")), false),
		"sprite_idle": _sprite_or_placeholder(dir, str(sprite.get("idle", "sprite.png")), card_id),
		"sprite_attack": _texture(dir, str(sprite.get("attack", "attack.png")), false),
		"frames": int(sprite.get("frames", 1)),
		"fps": int(sprite.get("fps", 8)),
		"hframes": int(sprite.get("hframes", int(sprite.get("frames", 1)))),
		"vframes": int(sprite.get("vframes", 1)),
		# Attack sheets have their own geometry. Undeclared falls back to the
		# 2-frame shape of the original procedural placeholder set.
		"attack_hframes": int(sprite.get("attack_hframes",
			int(sprite.get("attack_frames", 2)))),
		"attack_vframes": int(sprite.get("attack_vframes", 1)),
		"sfx_summon": _audio(dir, str(sfx.get("summon", "summon.wav")), true),
		"sfx_hit": _audio(dir, str(sfx.get("hit", "hit.wav")), true),
		"voice_summon": _audio(dir, str(voice.get("summon", "voice.wav")), false),
		"vfx_strike": _scene(dir, str(vfx.get("strike", "vfx.tscn"))),
	}
	_cache[card_id] = bundle
	return bundle


static func clear_cache() -> void:
	_cache.clear()


## Real card-face art for a card, or null when it ships none. Callers fall back
## to PlaceholderArt.card_art so the frame still renders (the Phase 4 contract).
static func card_art(card_id: String) -> Texture2D:
	return resolve(card_id)["card_art"]


## The same art as an Image, for the code paths that composite into an Image
## (CardFrame) rather than assigning a texture.
static func card_art_image(card_id: String) -> Image:
	var tex := card_art(card_id)
	return tex.get_image() if tex != null else null


# --- resolution helpers ---------------------------------------------------

static func _read_manifest(dir: String) -> Dictionary:
	var path := "%s/manifest.json" % dir
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Idle sprite: a real art file if present, otherwise the DETERMINISTIC per-id
## placeholder billboard (not the shared diamond) so every creature reads
## distinctly on the board. Unknown ids (tests) fall back to the diamond.
static func _sprite_or_placeholder(dir: String, filename: String, card_id: String) -> Texture2D:
	var tex := _texture(dir, filename, false)
	if tex != null:
		return tex
	var card: CardData = DeckFactory.card(card_id)
	if card != null:
		return PlaceholderArt.sprite_for(card)
	return placeholder_sprite()


static func _texture(dir: String, filename: String, fallback: bool) -> Texture2D:
	if not filename.is_empty():
		var path := "%s/%s" % [dir, filename]
		# Prefer the imported Texture2D (no reimport, no warning); fall back to a
		# hot Image.load so freshly dropped art still shows before an editor open.
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if res is Texture2D:
				return res
		if FileAccess.file_exists(path):
			var img := Image.new()
			if img.load(path) == OK:
				return ImageTexture.create_from_image(img)
	return placeholder_sprite() if fallback else null


static func _audio(dir: String, filename: String, fallback: bool) -> AudioStream:
	if not filename.is_empty():
		var path := "%s/%s" % [dir, filename]
		# Prefer the imported AudioStream; fall back to reading the RIFF directly
		# so audio ingested since the last editor open is still audible.
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if res is AudioStream:
				return res
		var hot := _load_wav_file(path)
		if hot != null:
			return hot
	return default_whoosh() if fallback else null


## Minimal 16-bit PCM RIFF reader -> AudioStreamWAV. Returns null for anything
## it does not understand, so the caller's normal fallback still applies.
static func _load_wav_file(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var buf := f.get_buffer(f.get_length())
	f.close()
	if buf.size() < 12 or buf.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or buf.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null

	var pos := 12
	var fmt_code := 0
	var channels := 1
	var rate := 22050
	var bits := 0
	var data := PackedByteArray()
	while pos + 8 <= buf.size():
		var cid := buf.slice(pos, pos + 4).get_string_from_ascii()
		var csz := int(buf.decode_u32(pos + 4))
		var body := pos + 8
		if csz < 0 or body + csz > buf.size():
			csz = buf.size() - body
		if cid == "fmt " and csz >= 16:
			fmt_code = buf.decode_u16(body)
			channels = buf.decode_u16(body + 2)
			rate = int(buf.decode_u32(body + 4))
			bits = buf.decode_u16(body + 14)
		elif cid == "data":
			data = buf.slice(body, body + csz)
		pos = body + csz + (csz & 1)

	if fmt_code != 1 or bits != 16 or data.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = channels >= 2
	wav.data = data
	return wav


static func _scene(dir: String, filename: String) -> PackedScene:
	if not filename.is_empty():
		# Allow a shared res:// VFX scene, or a vfx.tscn inside the card dir.
		var path := filename if filename.begins_with("res://") else "%s/%s" % [dir, filename]
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if res is PackedScene:
				return res
	return null


# --- generated fallbacks --------------------------------------------------

## A generic 32x32 placeholder creature sprite (magenta diamond) so a card with
## no art still renders something readable.
static func placeholder_sprite() -> Texture2D:
	if _placeholder_sprite != null:
		return _placeholder_sprite
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(32):
		for x in range(32):
			if abs(x - 16) + abs(y - 16) <= 13:
				img.set_pixel(x, y, Color(0.85, 0.2, 0.75))
			if abs(x - 16) + abs(y - 16) == 13:
				img.set_pixel(x, y, Color(1, 1, 1))
	_placeholder_sprite = ImageTexture.create_from_image(img)
	return _placeholder_sprite


## A short generated "whoosh" used when a card ships no SFX.
static func default_whoosh() -> AudioStream:
	if _default_whoosh != null:
		return _default_whoosh
	_default_whoosh = _make_tone(220.0, 0.22, 0.4)
	return _default_whoosh


## Build a tiny mono 22.05kHz AudioStreamWAV tone (used for generated fallbacks
## and placeholder card SFX). `decay` shapes a quick fade so it reads as a cue.
static func _make_tone(freq: float, seconds: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var env := pow(1.0 - float(i) / float(n), 1.0 + decay * 4.0)
		var s := sin(TAU * freq * t) * env * 0.9
		var v := int(clamp(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
