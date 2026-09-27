class_name Biome
extends Resource
## Everything that gives an area type its look and sound: sky and fog,
## ambient and moonlight colours, ground materials, the props and small
## scatter it is dressed with, its ambient particle effects, and its music
## and ambience ids. Zones point at a Biome (see Zone); PropScatter nodes can
## pull their entries from it. Biomes live in data/biomes/.

@export var display_name: String = ""

@export_group("Sky and light")
@export var background_color: Color = Color(0.012, 0.012, 0.016)
@export var ambient_color: Color = Color(0.35, 0.38, 0.5)
@export var ambient_energy: float = 0.4
@export var moon_color: Color = Color(0.6, 0.68, 0.9)
@export var moon_energy: float = 0.25
## Moonlight direction as Euler angles in degrees.
@export var moon_rotation: Vector3 = Vector3(-50.0, 30.0, 0.0)
@export var moon_shadows: bool = true
@export var tonemap_white: float = 6.0
@export var exposure: float = 1.0
@export var glow_intensity: float = 0.6

@export_group("Fog")
@export var fog_color: Color = Color(0.04, 0.045, 0.06)
@export var fog_density: float = 0.006
@export var volumetric_density: float = 0.012
@export var volumetric_albedo: Color = Color(0.7, 0.72, 0.8)
@export var volumetric_length: float = 80.0

@export_group("Ground")
## The main walkable ground (KitGround uses this when it has no material).
@export var ground_material: Material
## Paths, plazas and the like.
@export var path_material: Material
## Zone edges: cliffs and big rocks.
@export var cliff_material: Material

@export_group("Dressing")
## Larger props that usually block movement (rocks, trees, wrecks).
@export var props: Array[ScatterEntry] = []
## Small decorative scatter (grass, pebbles, driftwood).
@export var scatter: Array[ScatterEntry] = []
## Particle effects that fill the whole zone (dust, mist, fireflies...).
@export var ambient_effects: Array[PackedScene] = []

@export_group("Audio")
## Music track id for the Audio autoload (e.g. &"town").
@export var music_id: StringName = &""
## Ambience loop id (e.g. &"campfire", &"sea").
@export var ambience_id: StringName = &""


## A new Environment configured for this biome.
func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = tonemap_white
	env.tonemap_exposure = exposure
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = volumetric_density > 0.0
	env.volumetric_fog_density = volumetric_density
	env.volumetric_fog_albedo = volumetric_albedo
	env.volumetric_fog_length = volumetric_length
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	return env


## Points and colours a DirectionalLight3D as this biome's moonlight.
func apply_moon(light: DirectionalLight3D) -> void:
	light.light_color = moon_color
	light.light_energy = moon_energy
	light.rotation_degrees = moon_rotation
	light.shadow_enabled = moon_shadows
	light.directional_shadow_max_distance = 60.0
