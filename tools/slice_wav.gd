extends SceneTree
## Splits a long 16-bit PCM WAV recording into separate sounds at its silences.
## Run with:
##   godot --headless --path <project> -s res://tools/slice_wav.gd -- <input.wav> <output dir (res://...)> <prefix>
## Each piece is trimmed with a little padding and written as <prefix>_NN.wav.

## Loudness (RMS, 0-1) below which a 10 ms window counts as silence.
const SILENCE_RMS: float = 0.02
## Gaps shorter than this don't split a sound.
const MIN_GAP: float = 0.18
## Pieces shorter than this are discarded (clicks, breaths).
const MIN_LENGTH: float = 0.15
const PAD: float = 0.03
const WINDOW: float = 0.01


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <input.wav> <output dir> <prefix>")
		quit(1)
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(args[0])
	var channels: int = bytes.decode_u16(22)
	var rate: int = bytes.decode_u32(24)
	var pos: int = 12
	var data_size: int = 0
	while pos < bytes.size() - 8:
		var id: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		if id == "data":
			data_size = size
			pos += 8
			break
		pos += 8 + size + (size % 2)
	# Mono samples (first channel).
	var frame_bytes: int = 2 * channels
	var count: int = mini(data_size, bytes.size() - pos) / frame_bytes
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		samples[i] = bytes.decode_s16(pos + i * frame_bytes) / 32768.0

	var window: int = int(WINDOW * rate)
	var loud := PackedByteArray()
	for w: int in count / window:
		var sum: float = 0.0
		for j: int in window:
			var v: float = samples[w * window + j]
			sum += v * v
		loud.append(1 if sqrt(sum / window) > SILENCE_RMS else 0)

	var pieces: Array[Vector2i] = []
	var start: int = -1
	var quiet: int = 0
	var gap_windows: int = int(MIN_GAP / WINDOW)
	for w: int in loud.size():
		if loud[w] == 1:
			if start < 0:
				start = w
			quiet = 0
		elif start >= 0:
			quiet += 1
			if quiet >= gap_windows:
				pieces.append(Vector2i(start, w - quiet))
				start = -1
				quiet = 0
	if start >= 0:
		pieces.append(Vector2i(start, loud.size() - 1))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(args[1]))
	var written: int = 0
	for piece: Vector2i in pieces:
		var from: int = maxi(0, piece.x * window - int(PAD * rate))
		var to: int = mini(count, (piece.y + 1) * window + int(PAD * rate))
		var length: float = float(to - from) / rate
		if length < MIN_LENGTH:
			continue
		var pcm := PackedByteArray()
		pcm.resize((to - from) * 2)
		for i: int in to - from:
			# Short fades avoid clicks at the cut points.
			var fade: float = minf(1.0, minf(float(i), float(to - from - i)) / (0.005 * rate))
			pcm.encode_s16(i * 2, int(clampf(samples[from + i] * fade, -1.0, 1.0) * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.stereo = false
		wav.data = pcm
		written += 1
		var out: String = "%s/%s_%02d.wav" % [args[1], args[2], written]
		wav.save_to_wav(out)
		print("%s  %.2f s" % [out.get_file(), length])
	print("wrote %d pieces" % written)
	quit()
