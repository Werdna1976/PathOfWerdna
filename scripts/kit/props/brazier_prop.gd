@tool
class_name BrazierProp
extends KitProp
## An iron brazier on three legs with burning coals. Pivot: centre, on the ground.

@export var height: float = 1.0:
	set(value):
		height = value
		_queue_rebuild()
@export var light_energy: float = 3.5:
	set(value):
		light_energy = value
		_queue_rebuild()
@export var light_range: float = 10.0:
	set(value):
		light_range = value
		_queue_rebuild()
@export var shadows: bool = true:
	set(value):
		shadows = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	add_mesh(KitMesh.cached("brazier:%s" % height, _mesh), KitMaterials.iron())
	add_mesh(KitMesh.cached("brazier:coals:%s" % height, _coals), KitMaterials.glow(Color(1.0, 0.38, 0.1), 3.0),
		Transform3D.IDENTITY, false)
	add_cylinder_collider(0.45, height)
	var top := Vector3(0, height + 0.05, 0)
	for fx: GPUParticles3D in [KitFx.fire(1.5), KitFx.embers(1.2), KitFx.smoke(0.9)]:
		fx.position = top
		add_generated(fx)
	var light := FlickerLight.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	light.base_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	light.position = top + Vector3(0, 0.4, 0)
	add_generated(light)


func _mesh() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var c := Color.WHITE
	for i: int in 3:
		var ang: float = TAU * i / 3.0
		var foot := Vector3(cos(ang), 0.0, sin(ang)) * 0.42
		var knee := Vector3(cos(ang), 0.0, sin(ang)) * 0.28 + Vector3(0, height * 0.75, 0)
		KitMesh.cylinder(st, foot, knee, 0.035, 0.03, 5, c)
	# The bowl: wide rim, narrow base.
	KitMesh.cylinder(st, Vector3(0, height * 0.72, 0), Vector3(0, height, 0), 0.22, 0.42, 9, c, true, false)
	KitMesh.cylinder(st, Vector3(0, height - 0.03, 0), Vector3(0, height + 0.02, 0), 0.44, 0.44, 9, c.darkened(0.2), false, false)
	return KitMesh.commit(st)


func _coals() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.blob(st, Vector3(0, height - 0.04, 0), Vector3(0.36, 0.08, 0.36), 21, 0.35, Color.WHITE, 1)
	return KitMesh.commit(st)
