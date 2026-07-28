extends SceneTree

## One-shot generator for the two example cards' PLACEHOLDER assets (free /
## procedurally generated), proving the four-channel pipeline end to end.
## Run once:  godot --headless -s tools/gen_client_assets.gd
## Produces sprite/attack PNG sheets + summon/hit/voice WAVs under
## assets/cards/<id>/. Re-runnable and deterministic.

const OUT := "res://assets/cards"

func _init() -> void:
	# Stormfoal Hatchling — bright, small, red/amber (the light tonal pole).
	_make_card("wm01-008", Color(0.9, 0.25, 0.15), Color(1.0, 0.8, 0.2),
		"foal", 660.0, 520.0, 780.0)
	# Cull-Beast 01 — dark, heavy, blue/purple (the heavy tonal pole).
	_make_card("wm01-046", Color(0.15, 0.2, 0.45), Color(0.55, 0.3, 0.7),
		"beast", 120.0, 90.0, 160.0)
	print("Generated example card assets.")
	quit(0)


func _make_card(id: String, body: Color, accent: Color, shape: String,
		summon_hz: float, hit_hz: float, voice_hz: float) -> void:
	var dir := "%s/%s" % [OUT, id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# Idle sheet: 4 frames of gentle bob. Attack sheet: 2 frames of lunge.
	_save_sheet("%s/sprite.png" % dir, 4, body, accent, shape, false)
	_save_sheet("%s/attack.png" % dir, 2, body, accent, shape, true)
	_save_wav("%s/summon.wav" % dir, summon_hz, 0.22, 0.5, false)
	_save_wav("%s/hit.wav" % dir, hit_hz, 0.14, 0.9, true)
	_save_wav("%s/voice.wav" % dir, voice_hz, 0.30, 0.3, false)


func _save_sheet(path: String, frames: int, body: Color, accent: Color,
		shape: String, attacking: bool) -> void:
	var fw := 32
	var sheet := Image.create(fw * frames, fw, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for f in range(frames):
		var bob := int(sin(float(f) / max(1, frames) * TAU) * 2.0)
		var lunge := (f * 4) if attacking else 0
		_draw_creature(sheet, f * fw, bob, lunge, body, accent, shape)
	sheet.save_png(ProjectSettings.globalize_path(path))


func _draw_creature(img: Image, ox: int, bob: int, lunge: int, body: Color,
		accent: Color, shape: String) -> void:
	var cx := 16 + lunge
	var cy := 18 + bob
	# Body blob.
	for y in range(32):
		for x in range(32):
			var dx := float(x - cx)
			var dy := float(y - cy)
			var rx := 9.0 if shape == "beast" else 7.0
			var ry := 7.0 if shape == "beast" else 8.0
			if (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0:
				img.set_pixelv(Vector2i(ox + x, y), body)
	# Accent stripe / eye.
	for x in range(cx - 4, cx + 5):
		if x >= 0 and x < 32:
			img.set_pixelv(Vector2i(ox + x, cy - 2), accent)
	img.set_pixelv(Vector2i(ox + clampi(cx + 3, 0, 31), cy - 3), Color.WHITE)
	# Legs.
	for lx in [cx - 4, cx + 3]:
		for y in range(cy + 5, cy + 9):
			if lx >= 0 and lx < 32 and y < 32:
				img.set_pixelv(Vector2i(ox + lx, y), body.darkened(0.2))


func _save_wav(path: String, freq: float, seconds: float, decay: float, gritty: bool) -> void:
	var rate := 22050
	var n := int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var noise_state := 12345
	for i in range(n):
		var t := float(i) / float(rate)
		var env := pow(1.0 - float(i) / float(n), 1.0 + decay * 4.0)
		var s := sin(TAU * freq * t)
		if gritty:
			noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
			s = s * 0.7 + (float(noise_state % 1000) / 1000.0 - 0.5) * 0.5
		var v := int(clamp(s * env * 0.6, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	# AudioStreamWAV has no save_to_wav in all builds; write a minimal WAV file.
	_write_wav_file(ProjectSettings.globalize_path(path), bytes, rate)


func _write_wav_file(abs_path: String, pcm: PackedByteArray, rate: int) -> void:
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_error("gen_client_assets: cannot write %s" % abs_path)
		return
	var data_len := pcm.size()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_len)
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)            # PCM header size
	f.store_16(1)             # PCM format
	f.store_16(1)             # mono
	f.store_32(rate)
	f.store_32(rate * 2)      # byte rate (mono, 16-bit)
	f.store_16(2)             # block align
	f.store_16(16)            # bits per sample
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_len)
	f.store_buffer(pcm)
	f.close()
