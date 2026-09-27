class_name KitFx
extends RefCounted
## Particle building blocks for the world kit: fire, embers and smoke for
## torches and campfires, plus the shared soft-sprite draw materials that
## AmbientEffect uses. Every effect is a GPUParticles3D built in code, so it
## can be tuned by `scale` and dropped into any prop.

enum Blend { ADD, MIX }

static var _cache: Dictionary = {}


## Flames rising from a point. `scale` 1 suits a torch; 2.5 a campfire.
static func fire(scale: float = 1.0) -> GPUParticles3D:
	var p := _particles(int(28 * scale), 0.7, 0.3 * scale)
	var m := _motion(Vector3(0, 1, 0), 12.0, 0.25 * scale, 0.6 * scale)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.08 * scale
	m.gravity = Vector3(0, 0.8 * scale, 0)
	m.scale_min = 0.7
	m.scale_max = 1.2
	m.damping_min = 0.5
	m.damping_max = 1.0
	m.scale_curve = _curve([Vector2(0, 0.5), Vector2(0.25, 1.0), Vector2(1, 0.0)])
	m.color_ramp = _ramp([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.65, 0.2, 0.9), Color(0.9, 0.25, 0.05, 0.6),
		Color(0.3, 0.05, 0.02, 0.0)], [0.0, 0.15, 0.6, 1.0])
	p.process_material = m
	p.draw_pass_1 = quad(0.28 * scale, Blend.ADD, 2.5)
	return p


## Sparks that drift up, flicker and die.
static func embers(scale: float = 1.0) -> GPUParticles3D:
	var p := _particles(int(10 * scale), 2.2, 0.3 * scale)
	var m := _motion(Vector3(0, 1, 0), 25.0, 0.5 * scale, 1.2 * scale)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12 * scale
	m.gravity = Vector3(0, 0.3, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.5
	m.turbulence_noise_scale = 1.5
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color_ramp = _ramp([Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.45, 0.1, 1.0), Color(0.6, 0.1, 0.02, 0.0)], [0.0, 0.5, 1.0])
	p.process_material = m
	p.draw_pass_1 = quad(0.05, Blend.ADD, 4.0)
	return p


## Dark smoke that rises and spreads.
static func smoke(scale: float = 1.0) -> GPUParticles3D:
	var p := _particles(int(10 * scale), 3.5, 0.6 * scale)
	var m := _motion(Vector3(0, 1, 0), 10.0, 0.4 * scale, 0.7 * scale)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.1 * scale
	m.gravity = Vector3(0.15, 0.25, 0.05)
	m.scale_min = 0.8
	m.scale_max = 1.3
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -20.0
	m.angular_velocity_max = 20.0
	m.scale_curve = _curve([Vector2(0, 0.3), Vector2(1, 1.6)])
	m.color_ramp = _ramp([Color(0.1, 0.09, 0.08, 0.0), Color(0.12, 0.11, 0.1, 0.35), Color(0.1, 0.1, 0.1, 0.0)], [0.0, 0.25, 1.0])
	p.process_material = m
	p.draw_pass_1 = quad(0.6 * scale, Blend.MIX, 1.0)
	p.sorting_offset = -1.0
	return p


## A billboarded soft round sprite quad for particles.
static func quad(size: float, blend: Blend, energy: float = 1.0) -> QuadMesh:
	var key: String = "quad:%s:%d:%s" % [size, blend, energy]
	if _cache.has(key):
		return _cache[key]
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if blend == Blend.ADD else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(energy, energy, energy, 1.0) if blend == Blend.ADD else Color.WHITE
	mat.albedo_texture = soft_dot()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_receive_shadows = true
	mesh.material = mat
	_cache[key] = mesh
	return mesh


## A radial white-to-clear gradient, shared by every sprite.
static func soft_dot() -> Texture2D:
	if not _cache.has("soft_dot"):
		var tex := GradientTexture2D.new()
		tex.width = 64
		tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.6))
		tex.gradient = g
		_cache["soft_dot"] = tex
	return _cache["soft_dot"]


static func _particles(amount: int, lifetime: float, visibility: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.randomness = 0.3
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = maxf(visibility * 6.0, 1.0)
	p.visibility_aabb = AABB(Vector3(-r, -0.5, -r), Vector3(r * 2.0, r * 3.0, r * 2.0))
	return p


static func _motion(direction: Vector3, spread: float, speed_min: float, speed_max: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = direction
	m.spread = spread
	m.initial_velocity_min = speed_min
	m.initial_velocity_max = speed_max
	return m


static func _ramp(colors: Array[Color], offsets: Array[float]) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


static func _curve(points: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 2.0
	for p: Vector2 in points:
		c.add_point(p)
	var tex := CurveTexture.new()
	tex.curve = c
	return tex
