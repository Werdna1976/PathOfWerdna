class_name KitMaterials
extends RefCounted
## The world kit's material library.
##
## `named()` loads the generated materials in assets/materials/ (sand, dirt,
## packed_earth, grass, stone, cobbles, planks, cliff_rock, bark, cloth, and
## the shader materials water, foliage and banner). `flat()` and `glow()` make
## simple cached colour materials for metal, coals and the like.
## To use real art, replace the files in assets/materials/ (or their textures)
## and every prop picks them up.

const DIR: String = "res://assets/materials/"

static var _cache: Dictionary = {}


static func named(id: String) -> Material:
	if not _cache.has(id):
		_cache[id] = load(DIR + id + ".tres")
	return _cache[id]


## A plain colour material that multiplies vertex colour into its albedo.
static func flat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = "flat:%s:%s:%s" % [color.to_html(), roughness, metallic]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		m.vertex_color_use_as_albedo = true
		_cache[key] = m
	return _cache[key]


## Dark forged iron for brackets, bands and braziers.
static func iron() -> StandardMaterial3D:
	return flat(Color(0.16, 0.15, 0.14), 0.55, 0.7)


## A self-lit material (coals, embers, glowing runes).
static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key: String = "glow:%s:%s" % [color.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.5)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 1.0
		_cache[key] = m
	return _cache[key]
