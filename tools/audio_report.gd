extends SceneTree
## Checks the generated audio without listening: prints each file's length,
## peak, loudness (RMS), DC offset and clipping, and draws a band spectrogram
## of each music and ambience loop to tests/shots/audio_<name>.png (time left
## to right, low to high frequency bottom to top), plus how well the loop
## seam matches. Run with:
##   godot --headless --path <project> -s res://tools/audio_report.gd

const DIRS: Array[String] = ["res://assets/audio/sfx/", "res://assets/audio/music/", "res://assets/audio/ambience/"]
const BANDS: int = 40


func _initialize() -> void:
	for dir: String in DIRS:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".wav"):
				continue
			var samples: PackedFloat32Array = _read_wav(ProjectSettings.globalize_path(dir + f))
			var rate: int = _last_rate
			var peak: float = 0.0
			var sum: float = 0.0
			var dc: float = 0.0
			var clipped: int = 0
			for v: float in samples:
				peak = maxf(peak, absf(v))
				sum += v * v
				dc += v
				if absf(v) > 0.99:
					clipped += 1
			var rms: float = sqrt(sum / maxf(samples.size(), 1))
			print("%-28s %6.2f s  peak %5.2f  rms %6.1f dB  dc %+.4f  clipped %d" % [f, float(samples.size()) / rate, peak,
				20.0 * log(maxf(rms, 1e-6)) / log(10.0), dc / maxf(samples.size(), 1), clipped])
			if not dir.ends_with("sfx/"):
				_spectrogram(samples, rate, f.get_basename())
				# Compare the jump across the seam with the signal's typical step.
				var seam: float = absf(samples[0] - samples[samples.size() - 1])
				var steps: float = 0.0
				for i: int in range(1, samples.size()):
					steps += absf(samples[i] - samples[i - 1])
				var typical: float = steps / (samples.size() - 1)
				print("    loop seam jump %.4f = %.1fx the typical step (under ~3x is inaudible)" % [seam, seam / maxf(typical, 1e-6)])
	quit(0)


var _last_rate: int = 22050


## Minimal 16-bit mono PCM WAV reader.
func _read_wav(path: String) -> PackedFloat32Array:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var out := PackedFloat32Array()
	var pos: int = 12
	while pos + 8 <= bytes.size():
		var id: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		if id == "fmt ":
			_last_rate = bytes.decode_u32(pos + 12)
		elif id == "data":
			var count: int = size / 2
			out.resize(count)
			for i: int in count:
				out[i] = bytes.decode_s16(pos + 8 + i * 2) / 32768.0
			return out
		pos += 8 + size + (size % 2)
	return out


func _spectrogram(samples: PackedFloat32Array, rate: int, sound_name: String) -> void:
	var columns: int = 480
	var window: int = 1024
	var img: Image = Image.create(columns, BANDS * 4, false, Image.FORMAT_RGB8)
	var hop: int = maxi(1, (samples.size() - window) / columns)
	var freqs: Array[float] = []
	for b: int in BANDS:
		freqs.append(40.0 * pow(8000.0 / 40.0, float(b) / (BANDS - 1)))
	for c: int in columns:
		var start: int = c * hop
		for b: int in BANDS:
			# Goertzel filter at the band's centre frequency.
			var w: float = TAU * freqs[b] / rate
			var coeff: float = 2.0 * cos(w)
			var s1: float = 0.0
			var s2: float = 0.0
			for i: int in range(0, window, 2):
				var s: float = samples[start + i] + coeff * s1 - s2
				s2 = s1
				s1 = s
			var power: float = s1 * s1 + s2 * s2 - coeff * s1 * s2
			var db: float = 10.0 * log(maxf(power, 1e-9)) / log(10.0)
			var v: float = clampf((db + 20.0) / 60.0, 0.0, 1.0)
			var color := Color(v, v * v, v * 0.3 + (1.0 - v) * 0.15)
			for y: int in 4:
				img.set_pixel(c, (BANDS - 1 - b) * 4 + y, color)
	var out: String = "res://tests/shots/audio_%s.png" % sound_name
	img.save_png(ProjectSettings.globalize_path(out))
