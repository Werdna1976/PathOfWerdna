extends SceneTree
## Generates the world kit's tileable ground and surface textures, with normal
## maps derived from each texture's height field, plus a StandardMaterial3D
## .tres for each one. Run with:
##   godot --headless --path <project> -s res://tools/gen_textures.gd
## then run the import (godot --headless --path <project> --import).
##
## Everything is procedural, so the look can be retuned here and regenerated.
## To use real art instead, overwrite the PNGs in assets/textures/ (keeping the
## names) or point the materials in assets/materials/ at other textures.

const SIZE: int = 512
const TEX_DIR: String = "res://assets/textures/"
const MAT_DIR: String = "res://assets/materials/"

## name -> material settings. uv = texture repeats per metre (triplanar);
## world = world-space triplanar (ground, cliffs) vs object-space (props).
const MATERIALS: Dictionary = {
	"sand": {"roughness": 0.95, "uv": 0.22, "world": true, "normal": 0.8},
	"wet_sand": {"roughness": 0.35, "uv": 0.22, "world": true, "normal": 0.6},
	"dirt": {"roughness": 0.95, "uv": 0.25, "world": true, "normal": 1.0},
	"packed_earth": {"roughness": 0.9, "uv": 0.22, "world": true, "normal": 0.9},
	"grass": {"roughness": 0.95, "uv": 0.3, "world": true, "normal": 0.7},
	"stone": {"roughness": 0.85, "uv": 0.5, "world": false, "normal": 1.2},
	"cobbles": {"roughness": 0.8, "uv": 0.3, "world": true, "normal": 1.4},
	"planks": {"roughness": 0.85, "uv": 0.6, "world": false, "normal": 1.0},
	"cliff_rock": {"roughness": 0.9, "uv": 0.18, "world": true, "normal": 1.5},
	"bark": {"roughness": 0.95, "uv": 1.0, "world": false, "normal": 1.2},
	"cloth": {"roughness": 1.0, "uv": 1.2, "world": false, "normal": 0.5},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	for tex_name: String in MATERIALS:
		var start: int = Time.get_ticks_msec()
		var result: Array = call("_make_" + tex_name)
		_save(tex_name, result[0], result[1], MATERIALS[tex_name]["normal"])
		_write_material(tex_name, MATERIALS[tex_name])
		print("  %s: %d ms" % [tex_name, Time.get_ticks_msec() - start])
	print("gen_textures: done")
	quit(0)


# --- Texture recipes. Each returns [albedo: PackedColorArray, height: PackedFloat32Array]. ---

func _make_sand() -> Array:
	var fine: PackedFloat32Array = _noise(11, 0.02, 5)
	var grain: PackedFloat32Array = _noise(12, 0.35, 1)
	var warp: PackedFloat32Array = _noise(13, 0.006, 2)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			var i: int = y * SIZE + x
			# Wind ripples: whole cycles across the tile keep it seamless.
			var phase: float = float(12 * x + 4 * y) / SIZE + warp[i] * 2.0
			var ripple: float = 0.5 + 0.5 * sin(phase * TAU)
			var h: float = fine[i] * 0.5 + ripple * 0.3 + grain[i] * 0.2
			height[i] = h
			var c: Color = Color(0.46, 0.4, 0.31).lerp(Color(0.64, 0.56, 0.43), h)
			if grain[i] > 0.82:
				c = c.lightened(0.12)
			elif grain[i] < 0.12:
				c = c.darkened(0.2)
			albedo[i] = c
	return [albedo, height]


func _make_wet_sand() -> Array:
	var fine: PackedFloat32Array = _noise(21, 0.015, 4)
	var grain: PackedFloat32Array = _noise(22, 0.3, 1)
	var warp: PackedFloat32Array = _noise(23, 0.005, 2)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			var i: int = y * SIZE + x
			var phase: float = float(8 * x + 2 * y) / SIZE + warp[i] * 1.5
			var ripple: float = 0.5 + 0.5 * sin(phase * TAU)
			var h: float = fine[i] * 0.6 + ripple * 0.25 + grain[i] * 0.15
			height[i] = h
			var c: Color = Color(0.25, 0.22, 0.18).lerp(Color(0.36, 0.32, 0.26), h)
			if grain[i] > 0.85:
				c = c.lightened(0.1)
			albedo[i] = c
	return [albedo, height]


func _make_dirt() -> Array:
	var base: PackedFloat32Array = _noise(31, 0.012, 5)
	var grain: PackedFloat32Array = _noise(32, 0.25, 2)
	var pebbles: Dictionary = _voronoi(24, 33)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	var f1: PackedFloat32Array = pebbles["f1"]
	var ids: PackedFloat32Array = pebbles["id"]
	for i: int in SIZE * SIZE:
		var h: float = base[i] * 0.65 + grain[i] * 0.35
		var c: Color = Color(0.22, 0.16, 0.11).lerp(Color(0.38, 0.29, 0.2), h)
		# A few cells become small pebbles.
		if ids[i] > 0.72 and f1[i] < 0.3:
			var bump: float = 1.0 - f1[i] / 0.3
			h += bump * 0.5
			c = Color(0.36, 0.33, 0.29).lerp(Color(0.5, 0.46, 0.4), bump * ids[i])
		height[i] = h
		albedo[i] = c
	return [albedo, height]


func _make_packed_earth() -> Array:
	var base: PackedFloat32Array = _noise(41, 0.01, 5)
	var grain: PackedFloat32Array = _noise(42, 0.3, 1)
	var cracks: Dictionary = _voronoi(7, 43)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	var f1: PackedFloat32Array = cracks["f1"]
	var f2: PackedFloat32Array = cracks["f2"]
	for i: int in SIZE * SIZE:
		var edge: float = f2[i] - f1[i]
		var crack: float = 1.0 - smoothstep(0.0, 0.05, edge)
		crack *= smoothstep(0.35, 0.6, base[i])  # cracks only in drier patches
		var h: float = base[i] * 0.7 + grain[i] * 0.3 - crack * 0.6
		height[i] = h
		var c: Color = Color(0.24, 0.19, 0.14).lerp(Color(0.36, 0.29, 0.21), base[i] * 0.8 + grain[i] * 0.2)
		albedo[i] = c.lerp(Color(0.1, 0.08, 0.06), crack * 0.8)
	return [albedo, height]


func _make_grass() -> Array:
	var patches: PackedFloat32Array = _noise(51, 0.008, 3)
	var blades: PackedFloat32Array = _noise(52, 0.12, 3)
	var grain: PackedFloat32Array = _noise(53, 0.45, 1)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	for i: int in SIZE * SIZE:
		var h: float = blades[i] * 0.6 + grain[i] * 0.4
		height[i] = h
		var green: Color = Color(0.1, 0.14, 0.07).lerp(Color(0.22, 0.27, 0.12), h)
		var dry: Color = Color(0.26, 0.23, 0.13).lerp(Color(0.36, 0.32, 0.18), h)
		var c: Color = green.lerp(dry, smoothstep(0.55, 0.8, patches[i]))
		# Bare earth shows through the thinnest grass.
		c = c.lerp(Color(0.2, 0.15, 0.1), smoothstep(0.3, 0.12, patches[i]) * 0.7)
		albedo[i] = c
	return [albedo, height]


func _make_stone() -> Array:
	var base: PackedFloat32Array = _noise(61, 0.015, 6)
	var grain: PackedFloat32Array = _noise(62, 0.3, 2)
	var facets: Dictionary = _voronoi(6, 63)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	var f1: PackedFloat32Array = facets["f1"]
	var f2: PackedFloat32Array = facets["f2"]
	var ids: PackedFloat32Array = facets["id"]
	for i: int in SIZE * SIZE:
		var edge: float = smoothstep(0.0, 0.12, f2[i] - f1[i])
		var h: float = base[i] * 0.5 + grain[i] * 0.2 + edge * 0.3
		height[i] = h
		var c: Color = Color(0.27, 0.27, 0.27).lerp(Color(0.46, 0.45, 0.43), base[i] * 0.7 + grain[i] * 0.3)
		c = c.lerp(c.darkened(0.2), ids[i] * 0.5)
		# Lichen specks.
		if grain[i] > 0.8 and base[i] > 0.55:
			c = c.lerp(Color(0.34, 0.36, 0.24), 0.5)
		albedo[i] = c.lerp(Color(0.12, 0.12, 0.12), (1.0 - edge) * 0.4)
	return [albedo, height]


func _make_cobbles() -> Array:
	var cells: Dictionary = _voronoi(9, 71)
	var base: PackedFloat32Array = _noise(72, 0.03, 4)
	var grain: PackedFloat32Array = _noise(73, 0.35, 1)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	var f1: PackedFloat32Array = cells["f1"]
	var f2: PackedFloat32Array = cells["f2"]
	var ids: PackedFloat32Array = cells["id"]
	for i: int in SIZE * SIZE:
		var edge: float = f2[i] - f1[i]
		var stone: float = smoothstep(0.04, 0.2, edge)
		var dome: float = sqrt(clampf(1.0 - f1[i] * 1.2, 0.0, 1.0))
		var h: float = stone * (0.55 + 0.3 * dome + 0.15 * base[i]) + grain[i] * 0.05
		height[i] = h
		var tone: Color = Color(0.3, 0.29, 0.27).lerp(Color(0.44, 0.41, 0.37), ids[i])
		tone = tone.lerp(Color(0.36, 0.3, 0.24), base[i] * 0.4)
		var mortar: Color = Color(0.13, 0.11, 0.09).lerp(Color(0.2, 0.17, 0.13), grain[i])
		albedo[i] = mortar.lerp(tone * (0.8 + 0.2 * dome), stone)
	return [albedo, height]


func _make_planks() -> Array:
	var grain_noise: PackedFloat32Array = _noise(81, 0.02, 4)
	var fine: PackedFloat32Array = _noise(82, 0.3, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	const PLANKS: int = 8
	var plank_h: int = SIZE / PLANKS
	var tones: Array[float] = []
	var joints: Array[int] = []
	for p: int in PLANKS:
		tones.append(rng.randf())
		joints.append(rng.randi_range(0, SIZE - 1))
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	for y: int in SIZE:
		var p: int = y / plank_h
		var in_plank: int = y % plank_h
		for x: int in SIZE:
			var i: int = y * SIZE + x
			# Stretch the noise along x by sampling rows at 6x: long wood grain.
			var gi: int = ((y * 6 + p * 37) % SIZE) * SIZE + x
			var grain: float = grain_noise[gi]
			var rings: float = 0.5 + 0.5 * sin((grain * 9.0 + float(in_plank) / plank_h * 2.0) * TAU)
			var gap: bool = in_plank < 2 or absi(x - joints[p]) < 2
			var h: float = 0.0 if gap else 0.7 + rings * 0.2 + fine[i] * 0.1
			# Worn, rounded edges near the gaps.
			h -= 0.25 * (1.0 - smoothstep(0.0, 5.0, float(mini(in_plank, plank_h - in_plank))))
			height[i] = h
			var c: Color = Color(0.26, 0.17, 0.1).lerp(Color(0.42, 0.3, 0.19), tones[p] * 0.6 + rings * 0.4)
			c = c.lerp(c.darkened(0.3), fine[i] * 0.3)
			albedo[i] = Color(0.05, 0.035, 0.025) if gap else c
	return [albedo, height]


func _make_cliff_rock() -> Array:
	var base: PackedFloat32Array = _noise(91, 0.008, 6)
	var warp: PackedFloat32Array = _noise(92, 0.004, 3)
	var grain: PackedFloat32Array = _noise(93, 0.25, 2)
	var cracks: Dictionary = _voronoi(5, 94)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	var f1: PackedFloat32Array = cracks["f1"]
	var f2: PackedFloat32Array = cracks["f2"]
	for y: int in SIZE:
		for x: int in SIZE:
			var i: int = y * SIZE + x
			# Horizontal strata, bent by low-frequency warp.
			var strata: float = 0.5 + 0.5 * sin((float(10 * y) / SIZE + warp[i] * 3.0) * TAU)
			var crack: float = 1.0 - smoothstep(0.0, 0.06, f2[i] - f1[i])
			var h: float = base[i] * 0.45 + strata * 0.3 + grain[i] * 0.25 - crack * 0.5
			height[i] = h
			var c: Color = Color(0.17, 0.16, 0.15).lerp(Color(0.36, 0.33, 0.29), base[i] * 0.6 + strata * 0.4)
			c = c.lerp(Color(0.3, 0.26, 0.2), grain[i] * 0.25)
			albedo[i] = c.lerp(Color(0.06, 0.06, 0.06), crack * 0.8)
	return [albedo, height]


func _make_bark() -> Array:
	var base: PackedFloat32Array = _noise(101, 0.02, 4)
	var fine: PackedFloat32Array = _noise(102, 0.25, 2)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			var i: int = y * SIZE + x
			# Stretch along y: sample columns at 8x for long vertical ridges.
			var si: int = y * SIZE + (x * 8) % SIZE
			var ridge: float = absf(sin((base[si] * 5.0) * TAU))
			var h: float = ridge * 0.7 + fine[i] * 0.3
			height[i] = h
			albedo[i] = Color(0.1, 0.075, 0.055).lerp(Color(0.3, 0.24, 0.18), h)
	return [albedo, height]


func _make_cloth() -> Array:
	var stains: PackedFloat32Array = _noise(111, 0.01, 4)
	var fine: PackedFloat32Array = _noise(112, 0.4, 1)
	var albedo := PackedColorArray()
	var height := PackedFloat32Array()
	albedo.resize(SIZE * SIZE)
	height.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			var i: int = y * SIZE + x
			# Plain weave: alternating warp and weft threads.
			var wx: float = 0.5 + 0.5 * sin(float(x) / SIZE * 128.0 * TAU)
			var wy: float = 0.5 + 0.5 * sin(float(y) / SIZE * 128.0 * TAU)
			var over: bool = ((x / 4) + (y / 4)) % 2 == 0
			var weave: float = wx if over else wy
			var h: float = weave * 0.7 + fine[i] * 0.3
			height[i] = h
			var c: Color = Color(0.5, 0.45, 0.36).lerp(Color(0.66, 0.6, 0.49), weave * 0.6 + fine[i] * 0.4)
			albedo[i] = c.lerp(Color(0.42, 0.36, 0.27), smoothstep(0.6, 0.9, stains[i]) * 0.5)
	return [albedo, height]


# --- Helpers. ---

## Seamless fractal value noise, normalized to 0..1, one float per pixel.
## `frequency` is in cycles per pixel for the first octave (like FastNoiseLite).
## Each octave is a periodic random grid upscaled with cubic filtering, so the
## result tiles perfectly.
func _noise(seed_value: int, frequency: float, octaves: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := PackedFloat32Array()
	total.resize(SIZE * SIZE)
	var cells: int = maxi(2, roundi(frequency * SIZE))
	var amplitude: float = 1.0
	for o: int in octaves:
		var layer: PackedFloat32Array = _value_layer(rng, mini(cells, SIZE / 2))
		for i: int in total.size():
			total[i] += layer[i] * amplitude
		amplitude *= 0.5
		cells *= 2
	var lo: float = INF
	var hi: float = -INF
	for v: float in total:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span: float = maxf(hi - lo, 0.0001)
	for i: int in total.size():
		total[i] = (total[i] - lo) / span
	return total


## One tileable octave: a `cells` x `cells` random grid, tiled 3x3, upscaled
## with cubic filtering, and the middle tile cropped out.
func _value_layer(rng: RandomNumberGenerator, cells: int) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(cells * cells)
	for i: int in grid.size():
		grid[i] = rng.randf()
	var wide: int = cells * 3
	var tiled := PackedFloat32Array()
	tiled.resize(wide * wide)
	for y: int in wide:
		for x: int in wide:
			tiled[y * wide + x] = grid[(y % cells) * cells + x % cells]
	var img: Image = Image.create_from_data(wide, wide, false, Image.FORMAT_RF, tiled.to_byte_array())
	img.resize(SIZE * 3, SIZE * 3, Image.INTERPOLATE_CUBIC)
	return img.get_region(Rect2i(SIZE, SIZE, SIZE, SIZE)).get_data().to_float32_array()


## Tileable Voronoi over a `cells` x `cells` grid of jittered points.
## Returns f1 and f2 (distances to the nearest two points, in cell units)
## and id (a random 0..1 value per cell).
func _voronoi(cells: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: Array[Vector2] = []
	var cell_ids: Array[float] = []
	for i: int in cells * cells:
		points.append(Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9)))
		cell_ids.append(rng.randf())
	var f1 := PackedFloat32Array()
	var f2 := PackedFloat32Array()
	var ids := PackedFloat32Array()
	f1.resize(SIZE * SIZE)
	f2.resize(SIZE * SIZE)
	ids.resize(SIZE * SIZE)
	var scale: float = float(cells) / SIZE
	for y: int in SIZE:
		var py: float = (y + 0.5) * scale
		var cy: int = int(py)
		for x: int in SIZE:
			var px: float = (x + 0.5) * scale
			var cx: int = int(px)
			var d1: float = 99.0
			var d2: float = 99.0
			var best: int = 0
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					var nx: int = cx + ox
					var ny: int = cy + oy
					var idx: int = posmod(ny, cells) * cells + posmod(nx, cells)
					var p: Vector2 = points[idx]
					var dx: float = nx + p.x - px
					var dy: float = ny + p.y - py
					var d: float = sqrt(dx * dx + dy * dy)
					if d < d1:
						d2 = d1
						d1 = d
						best = idx
					elif d < d2:
						d2 = d
			var i: int = y * SIZE + x
			f1[i] = d1
			f2[i] = d2
			ids[i] = cell_ids[best]
	return {"f1": f1, "f2": f2, "id": ids}


func _save(tex_name: String, albedo: PackedColorArray, height: PackedFloat32Array, strength: float) -> void:
	var color_bytes := PackedByteArray()
	color_bytes.resize(SIZE * SIZE * 3)
	var normal_bytes := PackedByteArray()
	normal_bytes.resize(SIZE * SIZE * 3)
	var k: float = strength * 6.0
	for y: int in SIZE:
		var up: int = posmod(y - 1, SIZE) * SIZE
		var down: int = posmod(y + 1, SIZE) * SIZE
		var row: int = y * SIZE
		for x: int in SIZE:
			var i: int = row + x
			var c: Color = albedo[i]
			color_bytes[i * 3] = clampi(int(c.r * 255.0), 0, 255)
			color_bytes[i * 3 + 1] = clampi(int(c.g * 255.0), 0, 255)
			color_bytes[i * 3 + 2] = clampi(int(c.b * 255.0), 0, 255)
			var left: int = posmod(x - 1, SIZE)
			var right: int = posmod(x + 1, SIZE)
			var dhdx: float = height[row + right] - height[row + left]
			var dhdy: float = height[down + x] - height[up + x]
			# OpenGL convention (Godot): green points up the texture.
			var n := Vector3(-dhdx * k, dhdy * k, 1.0).normalized()
			normal_bytes[i * 3] = int((n.x * 0.5 + 0.5) * 255.0)
			normal_bytes[i * 3 + 1] = int((n.y * 0.5 + 0.5) * 255.0)
			normal_bytes[i * 3 + 2] = int((n.z * 0.5 + 0.5) * 255.0)
	var albedo_img: Image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, color_bytes)
	var normal_img: Image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, normal_bytes)
	_save_png(albedo_img, TEX_DIR + tex_name + "_albedo.png", false)
	_save_png(normal_img, TEX_DIR + tex_name + "_normal.png", true)


## Saves a PNG, and on first generation writes its .import settings so it is
## imported as a mipmapped, VRAM-compressed 3D texture (normal maps flagged).
func _save_png(img: Image, path: String, is_normal: bool) -> void:
	img.save_png(ProjectSettings.globalize_path(path))
	var import_path: String = ProjectSettings.globalize_path(path + ".import")
	if FileAccess.file_exists(import_path):
		return
	var f: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[deps]\n\nsource_file=\"%s\"\n\n[params]\n\ncompress/mode=2\ncompress/normal_map=%d\nmipmaps/generate=true\ndetect_3d/compress_to=0\n" % [path, 1 if is_normal else 2])
	f.close()


func _write_material(tex_name: String, settings: Dictionary) -> void:
	var uv: float = settings["uv"]
	var text: String = "[gd_resource type=\"StandardMaterial3D\" load_steps=3 format=3]\n\n"
	text += "[ext_resource type=\"Texture2D\" path=\"%s%s_albedo.png\" id=\"1_albedo\"]\n" % [TEX_DIR, tex_name]
	text += "[ext_resource type=\"Texture2D\" path=\"%s%s_normal.png\" id=\"2_normal\"]\n\n" % [TEX_DIR, tex_name]
	text += "[resource]\nresource_name = \"%s\"\n" % tex_name
	text += "vertex_color_use_as_albedo = true\n"
	text += "albedo_texture = ExtResource(\"1_albedo\")\n"
	text += "roughness = %s\n" % settings["roughness"]
	text += "normal_enabled = true\nnormal_scale = 1.0\nnormal_texture = ExtResource(\"2_normal\")\n"
	text += "uv1_scale = Vector3(%s, %s, %s)\nuv1_triplanar = true\n" % [uv, uv, uv]
	text += "uv1_triplanar_sharpness = 4.0\n"
	text += "uv1_world_triplanar = %s\n" % ("true" if settings["world"] else "false")
	text += "texture_filter = 5\n"
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path(MAT_DIR + tex_name + ".tres"), FileAccess.WRITE)
	f.store_string(text)
	f.close()
