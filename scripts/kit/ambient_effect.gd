@tool
class_name AmbientEffect
extends GPUParticles3D
## Zone-wide atmosphere particles: dust motes, fireflies, drifting ground mist,
## falling ash and embers, or sea spray, filling a box of `extents`.
## The particle count follows `density` and the box size, so the same effect
## scene works in small and large zones. A Zone sizes it to its bounds.

enum Kind { DUST, FIREFLIES, MIST, ASH, SEA_SPRAY }

@export var kind: Kind = Kind.DUST:
	set(value):
		kind = value
		_setup()
## Half-size of the box the particles live in, around this node.
@export var extents: Vector3 = Vector3(15, 3, 15):
	set(value):
		extents = value
		_setup()
## Particles per 100 square metres of ground.
@export var density: float = 10.0:
	set(value):
		density = value
		_setup()
@export var tint: Color = Color(1, 1, 1, 1):
	set(value):
		tint = value
		_setup()
## When a Zone spawns this effect from its Biome, stretch it over the zone's bounds.
@export var fit_to_zone: bool = true


func _ready() -> void:
	_setup()


func _setup() -> void:
	if not is_inside_tree():
		return
	var area: float = extents.x * 2.0 * extents.z * 2.0
	amount = clampi(int(area / 100.0 * density), 4, 3000)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(-extents - Vector3.ONE * 2.0, extents * 2.0 + Vector3.ONE * 4.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.gravity = Vector3.ZERO
	match kind:
		Kind.DUST: _dust(m)
		Kind.FIREFLIES: _fireflies(m)
		Kind.MIST: _mist(m)
		Kind.ASH: _ash(m)
		Kind.SEA_SPRAY: _spray(m)
	preprocess = lifetime
	process_material = m


func _dust(m: ParticleProcessMaterial) -> void:
	lifetime = 9.0
	m.direction = Vector3(1, 0.2, 0.3)
	m.spread = 180.0
	m.initial_velocity_min = 0.03
	m.initial_velocity_max = 0.15
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.4
	m.turbulence_noise_scale = 3.0
	m.color_ramp = _fade(Color(1.0, 0.85, 0.6, 0.5) * tint)
	m.scale_min = 0.5
	m.scale_max = 1.2
	draw_pass_1 = KitFx.quad(0.04, KitFx.Blend.ADD, 1.5)


func _fireflies(m: ParticleProcessMaterial) -> void:
	lifetime = 6.0
	m.emission_box_extents = Vector3(extents.x, extents.y * 0.5, extents.z)
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.3
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.2
	m.turbulence_noise_scale = 2.0
	m.turbulence_influence_min = 0.1
	m.turbulence_influence_max = 0.2
	# Blink: fade up and down twice over a life.
	var g := Gradient.new()
	var c: Color = Color(0.75, 1.0, 0.35) * tint
	g.colors = PackedColorArray([Color(c, 0), Color(c, 1), Color(c, 0.1), Color(c, 1), Color(c, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.7, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	m.color_ramp = tex
	draw_pass_1 = KitFx.quad(0.07, KitFx.Blend.ADD, 3.0)


func _mist(m: ParticleProcessMaterial) -> void:
	lifetime = 18.0
	m.emission_box_extents = Vector3(extents.x, 0.3, extents.z)
	m.direction = Vector3(1, 0, 0.3)
	m.spread = 25.0
	m.initial_velocity_min = 0.15
	m.initial_velocity_max = 0.35
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -3.0
	m.angular_velocity_max = 3.0
	m.scale_min = 0.7
	m.scale_max = 1.4
	# Unshaded, so keep it dim: in a dark zone a bright colour reads as grey blobs.
	m.color_ramp = _fade(Color(0.16, 0.18, 0.22, 0.05) * tint)
	draw_pass_1 = KitFx.quad(7.0, KitFx.Blend.MIX, 1.0)


func _ash(m: ParticleProcessMaterial) -> void:
	lifetime = 10.0
	m.direction = Vector3(0.3, -1, 0.1)
	m.spread = 20.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.5
	m.gravity = Vector3(0, -0.05, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.8
	m.turbulence_noise_scale = 2.5
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.5, 0.15, 0.0) * tint, Color(1.0, 0.45, 0.1, 0.9) * tint,
		Color(0.35, 0.33, 0.3, 0.6) * tint, Color(0.3, 0.3, 0.3, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.5, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	m.color_ramp = tex
	draw_pass_1 = KitFx.quad(0.05, KitFx.Blend.ADD, 1.5)


func _spray(m: ParticleProcessMaterial) -> void:
	lifetime = 1.6
	m.emission_box_extents = Vector3(extents.x, 0.1, extents.z)
	m.direction = Vector3(0, 1, 0.4)
	m.spread = 25.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 2.4
	m.gravity = Vector3(0, -3.0, 0)
	m.scale_min = 0.5
	m.scale_max = 1.5
	m.color_ramp = _fade(Color(0.75, 0.82, 0.9, 0.45) * tint)
	draw_pass_1 = KitFx.quad(0.12, KitFx.Blend.MIX, 1.0)


## Fade in, hold, fade out.
func _fade(c: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(c, 0.0), Color(c, c.a), Color(c, c.a), Color(c, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex
