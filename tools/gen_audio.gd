extends SceneTree
## Synthesizes every sound in assets/audio/: sound effects, two music tracks
## and the ambience loops. Nothing is sampled; it is all oscillators, noise,
## filters, Karplus-Strong plucked strings and a small reverb, so it can be
## retuned here and regenerated. Run with:
##   godot --headless --path <project> -s res://tools/gen_audio.gd
## then import. Pass `-- --only=<name>` to rebuild just the sounds whose
## names contain <name> (e.g. --only=music_town). A full run is deterministic;
## a partial one draws different random details for what it rebuilds.
##
## Sound ids ending in _1, _2... are variants; the Audio autoload picks one
## at random. The music is original, in a slow, melancholic dark-fantasy mood.

const SFX_RATE: int = 44100
const MUSIC_RATE: int = 22050
const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const AMBIENCE_DIR: String = "res://assets/audio/ambience/"

var _rng := RandomNumberGenerator.new()
var _only: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	for dir: String in [SFX_DIR, MUSIC_DIR, AMBIENCE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_rng.seed = 1976
	var start: int = Time.get_ticks_msec()
	_sfx()
	_music_town()
	_music_shore()
	_ambience()
	print("gen_audio: done in %.1f s" % ((Time.get_ticks_msec() - start) / 1000.0))
	quit(0)


func _wanted(sound_name: String) -> bool:
	return _only == "" or sound_name.contains(_only)


# --- Sound effects. ---

func _sfx() -> void:
	for v: int in 3:
		_save_sfx("swing_%d" % (v + 1), _swing(0.9 + v * 0.12))
		_save_sfx("hit_flesh_%d" % (v + 1), _hit_flesh(0.9 + v * 0.1))
		_save_sfx("goblin_grunt_%d" % (v + 1), _voice(0.34, 175.0 + v * 22.0, 140.0 + v * 15.0, [720.0, 1250.0, 2700.0], 0.25))
	for v: int in 2:
		_save_sfx("hit_armour_%d" % (v + 1), _clank([620.0, 1480.0, 2330.0, 3710.0], 0.95 + v * 0.1, 0.4))
		_save_sfx("player_hurt_%d" % (v + 1), _voice(0.3, 118.0 + v * 10.0, 92.0 + v * 6.0, [540.0, 930.0, 2400.0], 0.15))
	_save_sfx("crit", _crit())
	_save_sfx("block", _clank([420.0, 1030.0, 1810.0, 2900.0], 1.0, 0.45))
	_save_sfx("evade", _swing(1.5, 0.18, 0.45))
	_save_sfx("goblin_death", _voice(0.85, 390.0, 105.0, [820.0, 1350.0, 2800.0], 0.4, true))
	_save_sfx("player_death", _voice(1.2, 122.0, 62.0, [600.0, 950.0, 2300.0], 0.3, true))
	_save_sfx("drop_normal", _thunk(0.8))
	_save_sfx("drop_magic", _mix([_thunk(0.7), _bells([1318.5, 1975.5], 0.35, 0.12, 0.3)]))
	_save_sfx("drop_rare", _mix([_thunk(0.8), _bells([1318.5, 1661.2, 1975.5, 2637.0], 0.9, 0.09, 0.55)]))
	_save_sfx("drop_legendary", _legendary_drop())
	_save_sfx("orb_drop", _orb_clink())
	_save_sfx("pickup", _pickup())
	_save_sfx("potion_drink", _drink())
	_save_sfx("skill_fail", _buzz())
	_save_sfx("zone_travel", _travel())
	_save_sfx("vendor_buy", _coins(6, 1.0, true))
	_save_sfx("vendor_sell", _coins(9, 0.85, false))
	_save_sfx("ui_click", _click())
	_save_sfx("inventory_open", _rustle(true))
	_save_sfx("inventory_close", _rustle(false))
	for v: int in 4:
		_save_sfx("footstep_sand_%d" % (v + 1), _footstep(true, v))
		_save_sfx("footstep_dirt_%d" % (v + 1), _footstep(false, v))


func _swing(pitch: float, length: float = 0.28, gain: float = 0.8) -> PackedFloat32Array:
	var n: int = int(length * SFX_RATE)
	var out: PackedFloat32Array = _noise(n)
	_bandpass_sweep(out, SFX_RATE, 500.0 * pitch, 2600.0 * pitch, 900.0 * pitch, 1.3)
	for i: int in n:
		var t: float = float(i) / n
		out[i] *= sin(PI * pow(t, 0.7)) * gain
	return out


func _hit_flesh(pitch: float) -> PackedFloat32Array:
	var n: int = int(0.24 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var noise: PackedFloat32Array = _noise(n)
	_lowpass(noise, SFX_RATE, 900.0 * pitch)
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		phase += TAU * (48.0 + 110.0 * exp(-t * 14.0)) * pitch / SFX_RATE
		var body: float = sin(phase) * exp(-t / 0.07)
		var smack: float = noise[i] * exp(-t / 0.025) * 2.2
		out[i] = tanh((body + smack) * 1.6) * 0.9
	return out


## Metal clang: inharmonic partials with fast decays, plus a click.
func _clank(partials: Array, pitch: float, length: float) -> PackedFloat32Array:
	var n: int = int(length * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var click: PackedFloat32Array = _noise(n)
	_highpass(click, SFX_RATE, 2000.0)
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		var s: float = click[i] * exp(-t / 0.004) * 0.8
		for k: int in partials.size():
			s += sin(TAU * partials[k] * pitch * t + k) * exp(-t / (0.14 - k * 0.022)) * (1.0 / (k + 1.0))
		s += sin(TAU * 90.0 * t) * exp(-t / 0.05) * 0.5
		out[i] = s * 0.55
	return out


func _crit() -> PackedFloat32Array:
	var thud: PackedFloat32Array = _hit_flesh(0.75)
	var ring: PackedFloat32Array = _clank([1800.0, 2610.0, 4130.0], 1.0, 0.55)
	var crack: PackedFloat32Array = _noise(int(0.08 * SFX_RATE))
	_highpass(crack, SFX_RATE, 1200.0)
	for i: int in crack.size():
		crack[i] *= exp(-float(i) / SFX_RATE / 0.012) * 1.2
	var out: PackedFloat32Array = _mix([thud, ring, crack])
	for i: int in out.size():
		out[i] = tanh(out[i] * 1.8) * 0.85
	return out


## A creature voice: a buzzy glottal source through formant filters, with the
## pitch sliding from f_start to f_end. `rasp` mixes in breath noise;
## `dying` adds a gurgling tremble toward the end.
func _voice(length: float, f_start: float, f_end: float, formants: Array, rasp: float, dying: bool = false) -> PackedFloat32Array:
	var n: int = int(length * SFX_RATE)
	var source := PackedFloat32Array()
	source.resize(n)
	var phase: float = 0.0
	var breath: PackedFloat32Array = _noise(n)
	for i: int in n:
		var t: float = float(i) / n
		var f: float = f_start * pow(f_end / f_start, t) * (1.0 + 0.03 * sin(TAU * 6.5 * t * length))
		phase = fmod(phase + f / SFX_RATE, 1.0)
		var glottal: float = (phase * 2.0 - 1.0) - 0.4 * sin(TAU * phase)
		var shake: float = 1.0
		if dying and t > 0.55:
			shake = 0.55 + 0.45 * sin(TAU * 28.0 * t * length)
		source[i] = (glottal + breath[i] * rasp) * shake
	var out := PackedFloat32Array()
	out.resize(n)
	for k: int in formants.size():
		var band: PackedFloat32Array = source.duplicate()
		_bandpass(band, SFX_RATE, formants[k], 5.0 + k * 2.0)
		var gain: float = [1.0, 0.7, 0.3][mini(k, 2)]
		for i: int in n:
			out[i] += band[i] * gain
	for i: int in n:
		var t: float = float(i) / n
		var env: float = minf(t * length / 0.025, 1.0) * pow(1.0 - t, 1.2)
		out[i] = tanh(out[i] * 2.5 * env)
	return out


func _thunk(gain: float) -> PackedFloat32Array:
	var n: int = int(0.16 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var noise: PackedFloat32Array = _noise(n)
	_lowpass(noise, SFX_RATE, 700.0)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		phase += TAU * (85.0 + 120.0 * exp(-t * 30.0)) / SFX_RATE
		out[i] = (sin(phase) * exp(-t / 0.05) + noise[i] * exp(-t / 0.02) * 1.5) * gain
	return out


## Bell tones, one after another, `gap` seconds apart.
func _bells(freqs: Array, length: float, gap: float, gain: float) -> PackedFloat32Array:
	var n: int = int(length * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ratios: Array[float] = [1.0, 2.0, 2.76, 5.4]
	var amps: Array[float] = [1.0, 0.5, 0.35, 0.15]
	for b: int in freqs.size():
		var start: int = int(b * gap * SFX_RATE)
		for i: int in range(start, n):
			var t: float = float(i - start) / SFX_RATE
			var s: float = 0.0
			for k: int in ratios.size():
				s += sin(TAU * freqs[b] * ratios[k] * t) * amps[k] * exp(-t / (0.5 / (k + 1.0)))
			out[i] += s * gain * minf(t / 0.002, 1.0)
	return out


func _legendary_drop() -> PackedFloat32Array:
	var n: int = int(2.2 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		out[i] = sin(TAU * (55.0 + 30.0 * exp(-t * 6.0)) * t) * exp(-t / 0.45) * 0.8
	var shimmer: PackedFloat32Array = _noise(n)
	_bandpass(shimmer, SFX_RATE, 6000.0, 2.0)
	var chord: PackedFloat32Array = _bells([659.3, 830.6, 987.8, 1318.5, 1661.2, 1975.5], 2.2, 0.07, 0.4)
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		var beat: float = 0.8 + 0.2 * sin(TAU * 5.0 * t)
		out[i] += chord[i] * beat + shimmer[i] * 0.25 * sin(PI * minf(t / 1.6, 1.0)) * exp(-t / 1.2)
	return _echo(out, SFX_RATE, 0.21, 0.35)


func _orb_clink() -> PackedFloat32Array:
	var n: int = int(0.35 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for hit: int in 3:
		var start: int = int([0.0, 0.085, 0.14][hit] * SFX_RATE)
		var gain: float = [1.0, 0.45, 0.2][hit]
		for i: int in range(start, n):
			var t: float = float(i - start) / SFX_RATE
			var s: float = sin(TAU * 2400.0 * t) + 0.6 * sin(TAU * 3620.0 * t) + 0.35 * sin(TAU * 5110.0 * t)
			out[i] += s * exp(-t / 0.05) * gain * 0.5
	return out


func _pickup() -> PackedFloat32Array:
	var n: int = int(0.12 * SFX_RATE)
	var out: PackedFloat32Array = _noise(n)
	_bandpass(out, SFX_RATE, 1500.0, 2.0)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		phase += TAU * (900.0 + 2500.0 * t) / SFX_RATE
		out[i] = out[i] * exp(-t / 0.012) * 1.5 + sin(phase) * exp(-t / 0.03) * 0.35 * minf(t / 0.003, 1.0)
	return out


func _drink() -> PackedFloat32Array:
	var n: int = int(0.75 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bubbles: PackedFloat32Array = _noise(n)
	_bandpass(bubbles, SFX_RATE, 750.0, 6.0)
	for g: int in 4:
		var start: int = int((g * 0.17 + _rng.randf_range(0.0, 0.02)) * SFX_RATE)
		var phase: float = 0.0
		for i: int in range(start, mini(start + int(0.12 * SFX_RATE), n)):
			var t: float = float(i - start) / SFX_RATE
			phase += TAU * (230.0 + 2400.0 * t) / SFX_RATE
			var env: float = sin(PI * minf(t / 0.12, 1.0))
			out[i] += (sin(phase) * 0.7 + bubbles[i] * 1.6) * env * 0.6
	return out


func _buzz() -> PackedFloat32Array:
	var n: int = int(0.28 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		var sq: float = signf(sin(TAU * 98.0 * t)) + 0.6 * signf(sin(TAU * 147.0 * t))
		var trem: float = 0.6 + 0.4 * sin(TAU * 18.0 * t)
		out[i] = sq * trem * minf(t / 0.01, 1.0) * (1.0 - t / 0.28) * 0.3
	_lowpass(out, SFX_RATE, 1400.0)
	return out


func _travel() -> PackedFloat32Array:
	var n: int = int(1.5 * SFX_RATE)
	var out: PackedFloat32Array = _noise(n)
	_bandpass_sweep(out, SFX_RATE, 180.0, 3200.0, 3200.0, 1.5)
	for i: int in n:
		var t: float = float(i) / n
		var env: float = pow(sin(PI * pow(t, 0.8)), 1.5)
		var tt: float = float(i) / SFX_RATE
		out[i] = out[i] * env * 0.9 + sin(TAU * 55.0 * tt) * env * 0.4 + sin(TAU * (660.0 + 440.0 * t) * tt) * env * 0.06
	return _echo(out, SFX_RATE, 0.17, 0.3)


func _coins(count: int, pitch: float, closing_thud: bool) -> PackedFloat32Array:
	var n: int = int(0.6 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var at: float = 0.0
	for c: int in count:
		var start: int = int(at * SFX_RATE)
		var f: float = _rng.randf_range(2700.0, 4300.0) * pitch
		var gain: float = _rng.randf_range(0.4, 0.8)
		for i: int in range(start, n):
			var t: float = float(i - start) / SFX_RATE
			out[i] += (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.47 * t)) * exp(-t / 0.035) * gain * 0.45
		at += _rng.randf_range(0.025, 0.07)
	if closing_thud:
		var thud: PackedFloat32Array = _thunk(0.5)
		var start: int = int(at * SFX_RATE)
		for i: int in thud.size():
			if start + i < n:
				out[start + i] += thud[i]
	return out


func _click() -> PackedFloat32Array:
	var n: int = int(0.03 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		out[i] = sin(TAU * 1500.0 * t) * exp(-t / 0.006) * 0.6 + _rng.randf_range(-1.0, 1.0) * exp(-t / 0.0015) * 0.4
	return out


func _rustle(opening: bool) -> PackedFloat32Array:
	var length: float = 0.35 if opening else 0.25
	var n: int = int(length * SFX_RATE)
	var out: PackedFloat32Array = _noise(n)
	if opening:
		_bandpass_sweep(out, SFX_RATE, 800.0, 1900.0, 1400.0, 1.5)
	else:
		_bandpass_sweep(out, SFX_RATE, 1800.0, 1100.0, 700.0, 1.5)
	for i: int in n:
		var t: float = float(i) / n
		var grain: float = 0.6 + 0.4 * sin(TAU * 40.0 * t * length + _rng.randf() * 0.5)
		out[i] *= sin(PI * pow(t, 0.6)) * grain * 0.7
	var extra: PackedFloat32Array = _orb_clink() if opening else _thunk(0.4)
	for i: int in extra.size():
		if i < n:
			out[i] += extra[i] * 0.3
	return out


func _footstep(sand: bool, variant: int) -> PackedFloat32Array:
	var n: int = int((0.16 if sand else 0.12) * SFX_RATE)
	var out: PackedFloat32Array = _noise(n)
	_lowpass(out, SFX_RATE, (1100.0 if sand else 2400.0) + variant * 150.0)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / SFX_RATE
		# Sand crunches: many tiny grains. Dirt is one duller scuff.
		var grain: float = 1.0
		if sand:
			grain = 0.4 + 0.6 * absf(sin(TAU * (180.0 + variant * 30.0) * t + _rng.randf() * 0.3))
		var attack: float = minf(t / (0.012 if sand else 0.004), 1.0)
		phase += TAU * (80.0 + variant * 6.0) / SFX_RATE
		out[i] = (out[i] * grain * 1.4 + sin(phase) * 0.5 * exp(-t / 0.03)) * attack * exp(-t / (0.05 if sand else 0.035)) * 0.8
	return out


# --- Music. ---

## Werdna's Camp: a slow plucked-guitar arpeggio in D minor over a low drone,
## with sparse echoes. 36 bars at 72 bpm (120 s), and it loops.
func _music_town() -> void:
	if not _wanted("music_town"):
		return
	var bpm: float = 72.0
	var beat: float = 60.0 / bpm
	var bars: int = 36
	var length: float = bars * 4 * beat
	var n: int = int(length * MUSIC_RATE)
	var tail: int = int(6.0 * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n + tail)
	# Chords (root MIDI note, minor/major) one per bar.
	var a: Array = [[50, "m"], [50, "m"], [46, "M"], [46, "M"], [53, "M"], [53, "M"], [45, "M"], [45, "M"]]
	var b: Array = [[43, "m"], [43, "m"], [50, "m"], [50, "m"], [46, "M"], [48, "M"], [45, "M"], [45, "M"]]
	var intro: Array = [[50, "m"], [50, "m"], [46, "M"], [45, "M"]]
	var sections: Array = [[intro, 0.6, false], [a, 0.9, false], [a, 1.0, true], [b, 1.0, true], [a, 0.8, false]]
	# Arpeggio shape over the chord: root, fifth, octave, tenth, octave, fifth, third, fifth.
	var shape: Array[int] = [0, 7, 12, 15, 12, 7, 3, 7]
	var melody: Array[int] = [74, 72, 70, 69, 70, 69, 65, 64, 62, 65, 69, 70, 72, 70, 69, 67]
	var bar: int = 0
	var mel_i: int = 0
	for section: Array in sections:
		var chords: Array = section[0]
		var density: float = section[1]
		var with_melody: bool = section[2]
		for chord: Array in chords:
			var root: int = chord[0]
			var third: int = 3 if chord[1] == "m" else 4
			var bar_start: float = bar * 4 * beat
			for step: int in 8:
				if _rng.randf() > density and step % 2 == 1:
					continue
				var interval: int = shape[step]
				if interval == 3 or interval == 15:
					interval += third - 3
				var t: float = bar_start + step * beat * 0.5 + _rng.randf_range(-0.012, 0.012)
				var vel: float = (0.55 if step == 0 else 0.35) * _rng.randf_range(0.85, 1.1)
				_pluck(out, _midi(root + interval), t, 3.2, vel, 0.996)
			if with_melody and bar % 2 == 0:
				_pluck(out, _midi(melody[mel_i % melody.size()]), bar_start + beat * 0.02, 4.5, 0.42, 0.998, true)
				_pluck(out, _midi(melody[(mel_i + 1) % melody.size()]), bar_start + beat * 2.0, 3.5, 0.32, 0.998, true)
				mel_i += 2
			bar += 1
	# Low D drone with a quiet fifth, breathing slowly.
	var drone_phase: float = 0.0
	var fifth_phase: float = 0.0
	var drone := PackedFloat32Array()
	drone.resize(n + tail)
	for i: int in n:
		var t: float = float(i) / MUSIC_RATE
		drone_phase = fmod(drone_phase + _midi(38) / MUSIC_RATE, 1.0)
		fifth_phase = fmod(fifth_phase + _midi(45) * 1.002 / MUSIC_RATE, 1.0)
		var swell: float = 0.75 + 0.25 * sin(TAU * t / 16.0)
		drone[i] = (sin(TAU * drone_phase) * 0.6 + (drone_phase * 2.0 - 1.0) * 0.25 + sin(TAU * fifth_phase) * 0.2) * 0.16 * swell
	_lowpass(drone, MUSIC_RATE, 320.0)
	for i: int in n:
		out[i] += drone[i]
	out = _echo(out, MUSIC_RATE, beat * 0.75, 0.32)
	out = _reverb(out, MUSIC_RATE, 0.25)
	_save_loop(MUSIC_DIR + "town.wav", _fold_loop(out, n))


## The Goblin Shore: a darker drone, a low string pad through a slow minor
## progression, filtered-noise waves, and distant bell tones. 120 s, loops.
func _music_shore() -> void:
	if not _wanted("music_shore"):
		return
	var length: float = 120.0
	var n: int = int(length * MUSIC_RATE)
	var tail: int = int(8.0 * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n + tail)
	# Drone: A1 and E2, detuned saws.
	var p: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var freqs: Array[float] = [_midi(33), _midi(33) * 1.003, _midi(40), _midi(40) * 0.997]
	var drone := PackedFloat32Array()
	drone.resize(n + tail)
	for i: int in n + tail:
		var t: float = float(i) / MUSIC_RATE
		var s: float = 0.0
		for k: int in 4:
			p[k] = fmod(p[k] + freqs[k] / MUSIC_RATE, 1.0)
			s += p[k] * 2.0 - 1.0
		drone[i] = s * 0.1 * (0.7 + 0.3 * sin(TAU * t / 23.0))
	_lowpass(drone, MUSIC_RATE, 240.0)
	_lowpass(drone, MUSIC_RATE, 300.0)
	# Pad: one chord every 8 seconds, overlapping.
	var chords: Array = [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59], [57, 60, 64], [58, 62, 65],
		[55, 58, 62], [57, 61, 64], [57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59], [50, 53, 57], [58, 62, 65], [52, 56, 59]]
	var pad := PackedFloat32Array()
	pad.resize(n + tail)
	for c: int in chords.size():
		var start: int = int(c * 8.0 * MUSIC_RATE)
		var dur: int = int(10.0 * MUSIC_RATE)
		for note: int in chords[c]:
			for detune: float in [0.997, 1.0, 1.004]:
				var f: float = _midi(note - 12) * detune
				var phase: float = _rng.randf()
				for i: int in range(start, mini(start + dur, n + tail)):
					var t: float = float(i - start) / MUSIC_RATE
					var env: float = minf(t / 2.5, 1.0) * minf((10.0 - t) / 2.5, 1.0)
					phase = fmod(phase + f / MUSIC_RATE, 1.0)
					pad[i] += (phase * 2.0 - 1.0) * env * 0.035
	_lowpass(pad, MUSIC_RATE, 800.0)
	_lowpass(pad, MUSIC_RATE, 1100.0)
	# Waves: filtered noise that swells and recedes irregularly.
	var waves: PackedFloat32Array = _waves(n + tail, MUSIC_RATE, 0.5, n)
	# Distant bell tones from the A minor scale.
	var bells := PackedFloat32Array()
	bells.resize(n + tail)
	var scale: Array[int] = [69, 72, 76, 74, 71, 64, 67]
	var t_bell: float = 3.0
	while t_bell < length - 4.0:
		var f: float = _midi(scale[_rng.randi_range(0, scale.size() - 1)])
		var start: int = int(t_bell * MUSIC_RATE)
		for i: int in range(start, mini(start + int(5.0 * MUSIC_RATE), n + tail)):
			var t: float = float(i - start) / MUSIC_RATE
			var s: float = sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.76 * t) * exp(-t / 0.8) + 0.2 * sin(TAU * f * 5.4 * t) * exp(-t / 0.4)
			bells[i] += s * exp(-t / 1.8) * minf(t / 0.004, 1.0) * 0.12
		t_bell += _rng.randf_range(9.0, 16.0)
	_lowpass(bells, MUSIC_RATE, 2500.0)
	bells = _echo(bells, MUSIC_RATE, 0.9, 0.45)
	for i: int in n + tail:
		out[i] = drone[i] + pad[i] + waves[i] * 0.55 + bells[i]
	out = _reverb(out, MUSIC_RATE, 0.3)
	_save_loop(MUSIC_DIR + "shore.wav", _crossfade_loop(out, n))


# --- Ambience loops. ---

func _ambience() -> void:
	var n: int = int(30.0 * MUSIC_RATE)
	# Each loop is rendered a little long and crossfaded around its seam.
	var fade: int = int(2.0 * MUSIC_RATE)
	var total: int = n + fade
	if _wanted("campfire"):
		var fire := PackedFloat32Array()
		fire.resize(total)
		var rumble: PackedFloat32Array = _noise(total)
		_lowpass(rumble, MUSIC_RATE, 180.0)
		var roar: PackedFloat32Array = _noise(total)
		_bandpass(roar, MUSIC_RATE, 500.0, 0.8)
		for i: int in total:
			var t: float = float(i) / MUSIC_RATE
			var flicker: float = 0.6 + 0.25 * sin(TAU * 0.7 * t) + 0.15 * sin(TAU * 1.9 * t + 1.0)
			fire[i] = rumble[i] * 1.6 + roar[i] * 0.35 * flicker
		# Crackles and pops.
		var t_pop: float = 0.0
		while t_pop < float(total) / MUSIC_RATE:
			var start: int = int(t_pop * MUSIC_RATE)
			var loud: float = _rng.randf_range(0.2, 1.0) if _rng.randf() < 0.15 else _rng.randf_range(0.05, 0.3)
			var decay: float = _rng.randf_range(0.001, 0.006)
			var bright: float = _rng.randf_range(0.3, 1.0)
			for i: int in range(start, mini(start + int(0.03 * MUSIC_RATE), total)):
				var t: float = float(i - start) / MUSIC_RATE
				fire[i] += _rng.randf_range(-1.0, 1.0) * exp(-t / decay) * loud * bright
			t_pop += -log(maxf(_rng.randf(), 0.0001)) / 9.0
		_save_loop(AMBIENCE_DIR + "campfire.wav", _crossfade_loop(fire, n))
	if _wanted("sea"):
		var sea: PackedFloat32Array = _waves(total, MUSIC_RATE, 1.0, n)
		var wind: PackedFloat32Array = _wind(total, MUSIC_RATE, n)
		for i: int in total:
			sea[i] += wind[i] * 0.4
		_save_loop(AMBIENCE_DIR + "sea.wav", _crossfade_loop(sea, n))
	if _wanted("wind"):
		_save_loop(AMBIENCE_DIR + "wind.wav", _crossfade_loop(_wind(total, MUSIC_RATE, n), n))


## Surf: lowpassed noise with irregular swells (about one wave every 8 s).
## The swell pattern repeats every `loop_n` samples, so it loops.
func _waves(n: int, rate: int, gain: float, loop_n: int = -1) -> PackedFloat32Array:
	var noise: PackedFloat32Array = _noise(n)
	_lowpass(noise, rate, 700.0)
	_lowpass(noise, rate, 900.0)
	var hiss: PackedFloat32Array = _noise(n)
	_bandpass(hiss, rate, 3000.0, 0.7)
	var length: float = float(loop_n if loop_n > 0 else n) / rate
	var count: int = maxi(1, int(round(length / 8.0)))
	var wobble_a: float = _rng.randf() * TAU
	var wobble_b: float = _rng.randf() * TAU
	for i: int in n:
		var t: float = float(i) / rate
		# Wave phase: `count` waves per loop, unevenly spaced by a periodic
		# wobble, so the timing varies but stays smooth and loops exactly.
		var u: float = t / length
		var p: float = u * count + 0.35 * sin(TAU * u * 2.0 + wobble_a) + 0.2 * sin(TAU * u * 5.0 + wobble_b)
		var local: float = p - floorf(p)
		# Fast rise as the wave breaks, long hissing retreat.
		var swell: float = pow(sin(PI * pow(local, 0.35)), 2.0)
		noise[i] = (noise[i] * 2.2 * (0.25 + swell) + hiss[i] * 0.3 * swell) * gain
	return noise


## Wind: band-passed noise whose centre wanders, with slow gusts that repeat
## every `loop_n` samples.
func _wind(n: int, rate: int, loop_n: int = -1) -> PackedFloat32Array:
	var noise: PackedFloat32Array = _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var length: float = float(loop_n if loop_n > 0 else n) / rate
	var low: float = 0.0
	var band: float = 0.0
	for i: int in n:
		var t: float = float(i) / rate
		# Whole cycles over the loop keep it seamless.
		var centre: float = 700.0 + 350.0 * sin(TAU * t / length * 3.0) + 150.0 * sin(TAU * t / length * 7.0)
		var gust: float = 0.45 + 0.35 * sin(TAU * t / length * 4.0) + 0.2 * sin(TAU * t / length * 11.0)
		var f: float = 2.0 * sin(PI * centre / rate)
		# A state-variable band-pass, retuned every sample.
		var high: float = noise[i] - low - band * 0.35
		band += f * high
		low += f * band
		out[i] = band * gust * 0.5
	return out


# --- DSP helpers. ---

func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _noise(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		out[i] = _rng.randf_range(-1.0, 1.0)
	return out


func _lowpass(buffer: PackedFloat32Array, rate: int, cutoff: float) -> void:
	var a: float = 1.0 - exp(-TAU * cutoff / rate)
	var y: float = 0.0
	for i: int in buffer.size():
		y += a * (buffer[i] - y)
		buffer[i] = y


func _highpass(buffer: PackedFloat32Array, rate: int, cutoff: float) -> void:
	var a: float = 1.0 - exp(-TAU * cutoff / rate)
	var y: float = 0.0
	for i: int in buffer.size():
		y += a * (buffer[i] - y)
		buffer[i] = buffer[i] - y


## RBJ band-pass (constant peak gain).
func _bandpass(buffer: PackedFloat32Array, rate: int, freq: float, q: float) -> void:
	_bandpass_sweep(buffer, rate, freq, freq, freq, q)


## Band-pass whose centre moves f0 -> f1 (first half) -> f2 (second half).
func _bandpass_sweep(buffer: PackedFloat32Array, rate: int, f0: float, f1: float, f2: float, q: float) -> void:
	var n: int = buffer.size()
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var b0: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	for i: int in n:
		if i % 32 == 0:
			var t: float = float(i) / maxf(n - 1, 1)
			var f: float = lerpf(f0, f1, t * 2.0) if t < 0.5 else lerpf(f1, f2, (t - 0.5) * 2.0)
			var w: float = TAU * clampf(f, 20.0, rate * 0.45) / rate
			var alpha: float = sin(w) / (2.0 * q)
			var a0: float = 1.0 + alpha
			b0 = alpha / a0
			b2 = -alpha / a0
			a1 = -2.0 * cos(w) / a0
			a2 = (1.0 - alpha) / a0
		var x: float = buffer[i]
		var y: float = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buffer[i] = y


## Karplus-Strong plucked string, mixed into `out` at time `t`.
func _pluck(out: PackedFloat32Array, freq: float, t: float, length: float, velocity: float, decay: float,
		bright: bool = false) -> void:
	var start: int = int(maxf(t, 0.0) * MUSIC_RATE)
	var period: int = maxi(2, int(MUSIC_RATE / freq))
	var line := PackedFloat32Array()
	line.resize(period)
	# A softened noise burst: pick position and fingertip damping.
	var prev: float = 0.0
	for i: int in period:
		var r: float = _rng.randf_range(-1.0, 1.0)
		prev = prev + (0.7 if bright else 0.45) * (r - prev)
		line[i] = prev
	var n: int = mini(int(length * MUSIC_RATE), out.size() - start)
	var idx: int = 0
	for i: int in n:
		var cur: float = line[idx]
		var nxt: float = line[(idx + 1) % period]
		line[idx] = (cur + nxt) * 0.5 * decay
		out[start + i] += cur * velocity
		idx = (idx + 1) % period


## A feedback echo with a darkening repeat.
func _echo(buffer: PackedFloat32Array, rate: int, delay: float, feedback: float) -> PackedFloat32Array:
	var d: int = int(delay * rate)
	var out: PackedFloat32Array = buffer.duplicate()
	var y: float = 0.0
	for i: int in range(d, out.size()):
		y += 0.35 * (out[i - d] - y)
		out[i] += y * feedback
	return out


## A small Schroeder reverb (four combs, two all-passes), mixed `wet`.
func _reverb(buffer: PackedFloat32Array, rate: int, wet: float) -> PackedFloat32Array:
	var n: int = buffer.size()
	var comb_delays: Array[float] = [0.0297, 0.0371, 0.0411, 0.0437]
	var sum := PackedFloat32Array()
	sum.resize(n)
	for delay_s: float in comb_delays:
		var d: int = int(delay_s * rate * 1.6)
		var line := PackedFloat32Array()
		line.resize(d)
		var idx: int = 0
		var damp: float = 0.0
		for i: int in n:
			var out: float = line[idx]
			damp += 0.4 * (out - damp)
			line[idx] = buffer[i] + damp * 0.8
			sum[i] += out * 0.25
			idx = (idx + 1) % d
	for delay_s: float in [0.005, 0.0017]:
		var d: int = int(delay_s * rate)
		var line := PackedFloat32Array()
		line.resize(d)
		var idx: int = 0
		for i: int in n:
			var delayed: float = line[idx]
			var v: float = sum[i] + delayed * 0.5
			line[idx] = v
			sum[i] = delayed - v * 0.5
			idx = (idx + 1) % d
	var out: PackedFloat32Array = buffer.duplicate()
	for i: int in n:
		out[i] = buffer[i] * (1.0 - wet * 0.5) + sum[i] * wet
	return out


## Adds everything past `length` samples back onto the start, so the ringing
## tail of the end plays over the beginning and the loop is seamless.
func _fold_loop(buffer: PackedFloat32Array, length: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = buffer.slice(0, length)
	for i: int in range(length, buffer.size()):
		out[(i - length) % length] += buffer[i]
	return out


## Loops a buffer rendered past its loop length: the extra samples are
## crossfaded (equal power) over the start. Where the loop wraps, the last
## sample leads straight into what followed it, so the seam is continuous.
func _crossfade_loop(buffer: PackedFloat32Array, length: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = buffer.slice(0, length)
	var fade: int = mini(buffer.size() - length, length)
	for i: int in fade:
		var w: float = float(i) / fade
		out[i] = buffer[i] * sqrt(w) + buffer[length + i] * sqrt(1.0 - w)
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var n: int = 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		for i: int in p.size():
			out[i] += p[i]
	return out


func _normalize(buffer: PackedFloat32Array, peak: float) -> void:
	var m: float = 0.0001
	for v: float in buffer:
		m = maxf(m, absf(v))
	var k: float = peak / m
	for i: int in buffer.size():
		buffer[i] *= k


func _save_sfx(sound_name: String, buffer: PackedFloat32Array) -> void:
	if not _wanted(sound_name):
		return
	# A 2 ms fade in and out avoids clicks.
	var fade: int = mini(int(0.002 * SFX_RATE), buffer.size() / 2)
	for i: int in fade:
		buffer[i] *= float(i) / fade
		buffer[buffer.size() - 1 - i] *= float(i) / fade
	_normalize(buffer, 0.89)
	_write_wav(SFX_DIR + sound_name + ".wav", buffer, SFX_RATE, false)


func _save_loop(path: String, buffer: PackedFloat32Array) -> void:
	_normalize(buffer, 0.8)
	_write_wav(path, buffer, MUSIC_RATE, true)
	print("  %s: %.1f s" % [path, float(buffer.size()) / MUSIC_RATE])


func _write_wav(path: String, buffer: PackedFloat32Array, rate: int, loop: bool) -> void:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i: int in buffer.size():
		data.encode_s16(i * 2, clampi(int(buffer[i] * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buffer.size()
	stream.save_to_wav(ProjectSettings.globalize_path(path))
	# Loops import as looping, compressed streams; effects stay uncompressed.
	var import_path: String = ProjectSettings.globalize_path(path + ".import")
	if loop and not FileAccess.file_exists(import_path):
		var f: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
		f.store_string("[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n[deps]\n\nsource_file=\"%s\"\n\n[params]\n\nedit/loop_mode=2\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=2\n" % path)
		f.close()
