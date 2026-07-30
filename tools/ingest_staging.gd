extends SceneTree

## Ingests staged card art/audio from `staging/<id>/` into `assets/cards/<id>/`.
##
##   godot --headless --path . -s tools/ingest_staging.gd
##   godot --headless --path . -s tools/ingest_staging.gd -- --dry-run
##   godot --headless --path . -s tools/ingest_staging.gd -- --only wm01-001,wm01-004
##
## The drop is INCREMENTAL and RERUNNABLE: staging folders are never modified or
## deleted, and a channel that is absent from this drop leaves whatever is
## already in assets/cards/ untouched. More files land in staging over time and
## this tool is expected to run again over the same folders.
##
## Per card it:
##   1. validates the expected files and reports what is missing,
##   2. normalises WAV loudness to the reference measured from the original
##      procedural example cards (see LOUDNESS_REF),
##   3. copies assets into assets/cards/<id>/ and writes a manifest.json whose
##      frame count / fps match the sheet that was actually ingested,
##   4. prints a per-card coverage table.
##
## Channel states in the coverage table:
##   staged      — a real asset from this drop was ingested
##   present     — already in assets/cards/ (kept; not part of this drop)
##   placeholder — nothing on disk; AssetManifest generates a runtime fallback

const STAGING := "res://staging"
const OUT := "res://assets/cards"
const CARD_DATA := "res://data/cards"
const VFX_STRIKE := "res://client/present/vfx_burst.tscn"

## Cards whose (procedural) audio defines the loudness reference. Measured once
## and cached, because ingestion may later overwrite these very files.
const REF_CARDS := ["wm01-008", "wm01-046"]
const LOUDNESS_REF := "res://tools/loudness_reference.json"

## Sheet is preferred; the un-animated raw art is the fallback idle frame.
const SPRITE_SOURCES := ["sprite.png", "sprite_raw.png"]
const AUDIO_FILES := ["summon.wav", "hit.wav", "voice.wav"]

## Peak headroom kept after applying normalisation gain (-1 dBFS).
const PEAK_CEILING := 0.891

var _dry_run := false
var _only: Array = []
var _rows: Array = []
var _problems: Array = []


func _init() -> void:
	_parse_args()
	var ids := _staged_ids()
	if ids.is_empty():
		print("ingest_staging: nothing staged under %s" % STAGING)
		quit(0)
		return

	var targets := _loudness_targets()
	var names := _card_names()

	for id in ids:
		_ingest(id, targets, names)

	_print_table()
	_print_problems()
	if _dry_run:
		print("\n(dry run — no files were written)")
	quit(0)


# --- argument handling ----------------------------------------------------

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a := str(args[i])
		if a == "--dry-run":
			_dry_run = true
		elif a == "--only" and i + 1 < args.size():
			for part in str(args[i + 1]).split(",", false):
				_only.append(part.strip_edges())


func _staged_ids() -> Array:
	var out: Array = []
	var dir := DirAccess.open(STAGING)
	if dir == null:
		return out
	for d in dir.get_directories():
		if _only.is_empty() or _only.has(d):
			out.append(d)
	out.sort()
	return out


# --- card names -----------------------------------------------------------

## id -> printed name, so the written manifest carries the same "name" field the
## hand-authored example manifests do.
func _card_names() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(CARD_DATA)
	if dir == null:
		return out
	for fname in dir.get_files():
		if not fname.to_lower().ends_with(".json"):
			continue
		var parsed = JSON.parse_string(
			FileAccess.get_file_as_string(CARD_DATA.path_join(fname)))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		for entry in parsed.get("cards", []):
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
				out[str(entry["id"])] = str(entry.get("name", ""))
	return out


# --- loudness reference ---------------------------------------------------

## Target RMS per audio channel. Measured from the procedural example cards on
## first run and cached, so that later runs (which may have already replaced the
## example audio with real recordings) keep normalising to the SAME target
## instead of drifting toward whatever was ingested last.
func _loudness_targets() -> Dictionary:
	var cached = JSON.parse_string(FileAccess.get_file_as_string(LOUDNESS_REF)) \
		if FileAccess.file_exists(LOUDNESS_REF) else null
	if typeof(cached) == TYPE_DICTIONARY and cached.has("targets"):
		return cached["targets"]

	var targets: Dictionary = {}
	for fname in AUDIO_FILES:
		var sum := 0.0
		var n := 0
		for id in REF_CARDS:
			var path := "%s/%s/%s" % [OUT, id, fname]
			if not FileAccess.file_exists(path):
				continue
			var wav := _read_wav(ProjectSettings.globalize_path(path))
			if wav.get("ok", false) and wav["rms"] > 0.0:
				sum += wav["rms"]
				n += 1
		if n > 0:
			targets[fname] = sum / float(n)

	if not targets.is_empty() and not _dry_run:
		var payload := {
			"_comment": "Reference RMS measured from the original procedural example cards (%s). Delete to re-measure." % ", ".join(REF_CARDS),
			"targets": targets,
		}
		_write_text(LOUDNESS_REF, JSON.stringify(payload, "  "))
	return targets


# --- per-card ingestion ---------------------------------------------------

func _ingest(id: String, targets: Dictionary, names: Dictionary) -> void:
	var src := "%s/%s" % [STAGING, id]
	var dst := "%s/%s" % [OUT, id]
	if not _dry_run:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))

	var row := {"id": id}

	# --- sprite ---
	var sheet := _sprite_info(src)
	if sheet.get("ok", false):
		_copy(sheet["path"], "%s/sprite.png" % dst)
		row["sprite"] = "staged"
		if sheet["source"] == "sprite_raw.png":
			row["sprite"] = "staged*"     # static: no animation sheet in this drop
	elif FileAccess.file_exists("%s/sprite.png" % dst):
		row["sprite"] = "present"
		sheet = _sheet_geometry("%s/sprite.png" % dst, src)
	else:
		row["sprite"] = "placeholder"
		_problems.append("%s: no sprite.png or sprite_raw.png staged" % id)

	# --- attack ---
	var attack: Dictionary = {}
	if FileAccess.file_exists("%s/attack.png" % src):
		attack = _attack_geometry("%s/attack.png" % src, src)
		_copy("%s/attack.png" % src, "%s/attack.png" % dst)
		row["attack"] = "staged"
	elif FileAccess.file_exists("%s/attack.png" % dst):
		attack = _attack_geometry("%s/attack.png" % dst, src)
		row["attack"] = "present"
	else:
		row["attack"] = "placeholder"

	# --- audio (summon + hit) and voice ---
	var ingested: Dictionary = {}
	for fname in AUDIO_FILES:
		var s := "%s/%s" % [src, fname]
		if FileAccess.file_exists(s):
			_ingest_wav(id, s, "%s/%s" % [dst, fname], float(targets.get(fname, 0.0)))
			ingested[fname] = "staged"
		elif FileAccess.file_exists("%s/%s" % [dst, fname]):
			ingested[fname] = "present"
		else:
			ingested[fname] = "placeholder"
	row["audio"] = _merge_state([ingested["summon.wav"], ingested["hit.wav"]])
	row["voice"] = ingested["voice.wav"]

	# --- card art ---
	if FileAccess.file_exists("%s/card_art.png" % src):
		_copy("%s/card_art.png" % src, "%s/card_art.png" % dst)
		row["card_art"] = "staged"
	elif FileAccess.file_exists("%s/card_art.png" % dst):
		row["card_art"] = "present"
	else:
		row["card_art"] = "placeholder"

	_write_manifest(id, dst, sheet, attack, ingested, row["sprite"] != "placeholder",
		row["card_art"] != "placeholder", names.get(id, ""))
	_rows.append(row)


## Two sub-channels collapse into one column: both real -> staged, none -> placeholder.
func _merge_state(states: Array) -> String:
	if states.has("staged"):
		return "staged" if not states.has("placeholder") else "partial"
	if states.has("present"):
		return "present" if not states.has("placeholder") else "partial"
	return "placeholder"


# --- sprite sheet geometry ------------------------------------------------

## Locate the staged idle art and work out its sheet geometry.
func _sprite_info(src: String) -> Dictionary:
	for fname in SPRITE_SOURCES:
		var path := "%s/%s" % [src, fname]
		if FileAccess.file_exists(path):
			var geo := _sheet_geometry(path, src)
			geo["source"] = fname
			geo["path"] = path
			return geo
	return {"ok": false}


## Frame count / fps for a sheet. A manifest.json staged alongside the art wins
## (the generator knows exactly what it produced); otherwise the geometry is
## inferred from the image — a horizontal strip N frames wide when the width is
## an exact multiple of the height.
func _sheet_geometry(path: String, src: String) -> Dictionary:
	var staged_manifest := _staged_sprite_block(src)
	if not staged_manifest.is_empty():
		var frames := int(staged_manifest.get("frames", 1))
		return {
			"ok": true,
			"frames": frames,
			"hframes": int(staged_manifest.get("hframes", frames)),
			"vframes": int(staged_manifest.get("vframes", 1)),
			"fps": int(staged_manifest.get("fps", 8)),
		}

	var img := Image.new()
	if img.load(path) != OK:
		return {"ok": true, "frames": 1, "hframes": 1, "vframes": 1, "fps": 8}
	var w := img.get_width()
	var h := img.get_height()
	var frames := 1
	if h > 0 and w > h and w % h == 0:
		frames = w / h
	return {"ok": true, "frames": frames, "hframes": frames, "vframes": 1, "fps": 8 if frames <= 4 else 12}


## Frame count for the attack strip. A staged manifest's attack_* keys win;
## otherwise it is inferred from the image the same way the idle sheet is.
func _attack_geometry(path: String, src: String) -> Dictionary:
	var staged := _staged_sprite_block(src)
	if staged.has("attack_frames") or staged.has("attack_hframes"):
		var frames := int(staged.get("attack_frames", staged.get("attack_hframes", 2)))
		return {
			"frames": frames,
			"hframes": int(staged.get("attack_hframes", frames)),
			"vframes": int(staged.get("attack_vframes", 1)),
		}
	var img := Image.new()
	if img.load(path) != OK:
		return {"frames": 2, "hframes": 2, "vframes": 1}
	var w := img.get_width()
	var h := img.get_height()
	var frames := 1
	if h > 0 and w > h and w % h == 0:
		frames = w / h
	return {"frames": frames, "hframes": frames, "vframes": 1}


func _staged_sprite_block(src: String) -> Dictionary:
	var path := "%s/manifest.json" % src
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var sprite = parsed.get("sprite", {})
	return sprite if typeof(sprite) == TYPE_DICTIONARY else {}


# --- manifest -------------------------------------------------------------

## Written to match the hand-authored example schema (assets/cards/wm01-008),
## with channels omitted when the card ships nothing for them so AssetManifest
## falls back cleanly.
func _write_manifest(id: String, dst: String, sheet: Dictionary, attack: Dictionary,
		audio: Dictionary, has_sprite: bool, has_card_art: bool, name: String) -> void:
	var sprite := {}
	# A card-art-only drop ships no sprite at all. Naming a sprite.png that does
	# not exist would make the manifest lie; omit the block and let AssetManifest
	# fall back to the generated placeholder billboard.
	if has_sprite:
		sprite = {
			"idle": "sprite.png",
			"frames": int(sheet.get("frames", 1)),
			"hframes": int(sheet.get("hframes", 1)),
			"vframes": int(sheet.get("vframes", 1)),
			"fps": int(sheet.get("fps", 8)),
		}
		# The attack sheet is a separate strip with its own frame count; declaring
		# it keeps the state machine off the legacy 2-frame placeholder shape.
		if not attack.is_empty():
			sprite["attack"] = "attack.png"
			sprite["attack_frames"] = int(attack.get("frames", 2))
			sprite["attack_hframes"] = int(attack.get("hframes", 2))
			sprite["attack_vframes"] = int(attack.get("vframes", 1))

	var m := {"card_id": id}
	if not name.is_empty():
		m["name"] = name
	if not sprite.is_empty():
		m["sprite"] = sprite

	var sfx: Dictionary = {}
	if audio.get("summon.wav", "placeholder") != "placeholder":
		sfx["summon"] = "summon.wav"
	if audio.get("hit.wav", "placeholder") != "placeholder":
		sfx["hit"] = "hit.wav"
	if not sfx.is_empty():
		m["sfx"] = sfx

	if audio.get("voice.wav", "placeholder") != "placeholder":
		m["voice"] = {"summon": "voice.wav"}

	m["vfx"] = {"strike": VFX_STRIKE}

	if has_card_art:
		m["art"] = {"card": "card_art.png"}

	_write_text("%s/manifest.json" % dst, JSON.stringify(m, "  ") + "\n")


# --- audio normalisation --------------------------------------------------

## Copy a staged WAV, scaling it so its RMS matches the reference target for
## that channel. 16-bit PCM is normalised in place; any other encoding is copied
## through untouched (and reported), because rewriting it would need a decoder.
func _ingest_wav(id: String, src: String, dst: String, target_rms: float) -> void:
	if target_rms <= 0.0:
		_copy(src, dst)
		return
	var wav := _read_wav(ProjectSettings.globalize_path(src))
	if not wav.get("ok", false):
		_problems.append("%s: %s is not 16-bit PCM WAV — copied without normalising"
			% [id, src.get_file()])
		_copy(src, dst)
		return
	if wav["rms"] <= 0.0:
		_problems.append("%s: %s is silent — copied without normalising" % [id, src.get_file()])
		_copy(src, dst)
		return

	var gain: float = target_rms / wav["rms"]
	# Never push the file into clipping to hit the target.
	if wav["peak"] * gain > PEAK_CEILING:
		gain = PEAK_CEILING / wav["peak"]
	if _dry_run:
		return

	var buf: PackedByteArray = wav["bytes"]
	var off: int = wav["data_offset"]
	var count: int = wav["sample_count"]
	for i in range(count):
		var v := int(round(float(buf.decode_s16(off + i * 2)) * gain))
		buf.encode_s16(off + i * 2, clampi(v, -32768, 32767))
	var f := FileAccess.open(ProjectSettings.globalize_path(dst), FileAccess.WRITE)
	if f == null:
		_problems.append("%s: cannot write %s" % [id, dst])
		return
	f.store_buffer(buf)
	f.close()


## Parse a RIFF/WAVE file. Returns ok=false for anything that is not 16-bit PCM.
func _read_wav(abs_path: String) -> Dictionary:
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return {"ok": false}
	var buf := f.get_buffer(f.get_length())
	f.close()
	if buf.size() < 12:
		return {"ok": false}
	if buf.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {"ok": false}
	if buf.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"ok": false}

	var pos := 12
	var bits := 0
	var fmt_code := 0
	var data_off := -1
	var data_len := 0
	while pos + 8 <= buf.size():
		var cid := buf.slice(pos, pos + 4).get_string_from_ascii()
		var csz := int(buf.decode_u32(pos + 4))
		var body := pos + 8
		if csz < 0 or body + csz > buf.size():
			csz = buf.size() - body      # tolerate a truncated final chunk
		if cid == "fmt " and csz >= 16:
			fmt_code = buf.decode_u16(body)
			bits = buf.decode_u16(body + 14)
		elif cid == "data":
			data_off = body
			data_len = csz
		pos = body + csz + (csz & 1)     # RIFF chunks are word-aligned

	if data_off < 0 or fmt_code != 1 or bits != 16:
		return {"ok": false}

	var count := data_len / 2
	if count <= 0:
		return {"ok": false}
	var sum_sq := 0.0
	var peak := 0.0
	for i in range(count):
		var s := float(buf.decode_s16(data_off + i * 2)) / 32768.0
		sum_sq += s * s
		peak = max(peak, abs(s))
	return {
		"ok": true,
		"bytes": buf,
		"data_offset": data_off,
		"sample_count": count,
		"rms": sqrt(sum_sq / float(count)),
		"peak": peak,
	}


# --- io -------------------------------------------------------------------

func _copy(src: String, dst: String) -> void:
	if _dry_run:
		return
	var err := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
	if err != OK:
		_problems.append("cannot copy %s -> %s (err %d)" % [src, dst, err])


func _write_text(path: String, text: String) -> void:
	if _dry_run:
		return
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if f == null:
		_problems.append("cannot write %s" % path)
		return
	f.store_string(text)
	f.close()


# --- reporting ------------------------------------------------------------

func _print_table() -> void:
	var cols := ["sprite", "attack", "audio", "voice", "card_art"]
	var widths := {"id": 10}
	for c in cols:
		widths[c] = max(c.length(), 11)

	var header := "card".rpad(widths["id"])
	for c in cols:
		header += " | " + c.rpad(widths[c])
	print("\nCoverage")
	print(header)
	var rule := "".rpad(widths["id"], "-")
	for c in cols:
		rule += "-+-" + "".rpad(widths[c], "-")
	print(rule)

	for row in _rows:
		var line: String = str(row["id"]).rpad(widths["id"])
		for c in cols:
			line += " | " + str(row.get(c, "?")).rpad(widths[c])
		print(line)

	var totals: Dictionary = {}
	for row in _rows:
		for c in cols:
			var st := str(row.get(c, "?"))
			totals[st] = int(totals.get(st, 0)) + 1
	var parts: Array = []
	for k in ["staged", "staged*", "present", "partial", "placeholder"]:
		if totals.has(k):
			parts.append("%s %d" % [k, totals[k]])
	print("\n%d card(s): %s" % [_rows.size(), ", ".join(parts)])
	print("  staged* = static art ingested, no animation sheet in this drop")


func _print_problems() -> void:
	if _problems.is_empty():
		return
	print("\nNotes")
	for p in _problems:
		print("  - %s" % p)
