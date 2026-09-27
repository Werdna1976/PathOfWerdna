@tool
class_name CampfireProp
extends KitProp
## A campfire: a ring of stones, crossed logs, glowing coals, big flames,
## embers and smoke, and a strong flickering light. Pivot: centre, on the ground.

@export var radius: float = 0.75:
	set(value):
		radius = value
		_queue_rebuild()
@export var light_energy: float = 5.0:
	set(value):
		light_energy = value
		_queue_rebuild()
@export var light_range: float = 13.0:
	set(value):
		light_range = value
		_queue_rebuild()
@export var burning: bool = true:
	set(value):
		burning = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "campfire:%s:%d" % [radius, variant]
	add_mesh(KitMesh.cached(key + ":stones", _stones_mesh), KitMaterials.named("stone"))
	add_mesh(KitMesh.cached(key + ":logs", _logs_mesh), KitMaterials.named("bark"))
	add_cylinder_collider(radius + 0.1, 0.4)
	if not burning:
		return
	add_mesh(KitMesh.cached(key + ":coals", _coals_mesh), KitMaterials.glow(Color(1.0, 0.35, 0.08), 2.5),
		Transform3D.IDENTITY, false)
	var scale: float = radius / 0.75
	var fire: GPUParticles3D = KitFx.fire(2.4 * scale)
	fire.position = Vector3(0, 0.15, 0)
	add_generated(fire)
	var embers: GPUParticles3D = KitFx.embers(2.0 * scale)
	embers.position = Vector3(0, 0.3, 0)
	add_generated(embers)
	var smoke: GPUParticles3D = KitFx.smoke(1.6 * scale)
	smoke.position = Vector3(0, 0.9, 0)
	add_generated(smoke)
	var light := FlickerLight.new()
	light.light_color = Color(1.0, 0.52, 0.2)
	light.base_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.3
	light.flicker = 0.28
	light.sway = 0.06
	light.shadow_enabled = true
	light.position = Vector3(0, 0.9, 0)
	add_generated(light)


func _stones_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 31 + 5
	var st: SurfaceTool = KitMesh.begin()
	var count: int = int(radius * 12.0)
	for i: int in count:
		var ang: float = TAU * i / count + rng.randf_range(-0.1, 0.1)
		var pos := Vector3(cos(ang), 0.0, sin(ang)) * radius
		var s: float = rng.randf_range(0.14, 0.2)
		KitMesh.blob(st, pos + Vector3(0, s * 0.35, 0), Vector3(s, s * 0.75, s * 1.1), rng.randi(), 0.3,
			Color(0.8, 0.78, 0.74).darkened(rng.randf() * 0.3), 1, -0.4)
	return KitMesh.commit(st)


func _logs_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 17 + 3
	var st: SurfaceTool = KitMesh.begin()
	for i: int in 5:
		var ang: float = TAU * i / 5.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(ang), 0.0, sin(ang)) * radius * 0.85
		KitMesh.cylinder(st, out + Vector3(0, 0.06, 0), Vector3(0, 0.45, 0) + out * 0.1, 0.07, 0.05, 6,
			Color(0.55, 0.45, 0.38) if i % 2 == 0 else Color(0.25, 0.2, 0.16))
	return KitMesh.commit(st)


func _coals_mesh() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.blob(st, Vector3(0, 0.02, 0), Vector3(radius * 0.65, 0.08, radius * 0.65), 11, 0.4, Color.WHITE, 1, -0.2)
	return KitMesh.commit(st)
