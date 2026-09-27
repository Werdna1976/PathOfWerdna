@tool
class_name TorchProp
extends KitProp
## A torch on a wooden post, or on an iron wall bracket, with a flickering
## light, flames, embers and smoke. Pivot: the foot of the post, or for wall
## torches the point where the bracket meets the wall (the torch sticks out
## along +Z).

@export var wall_mounted: bool = false:
	set(value):
		wall_mounted = value
		_queue_rebuild()
@export var post_height: float = 2.2:
	set(value):
		post_height = value
		_queue_rebuild()
@export var light_color: Color = Color(1.0, 0.58, 0.25):
	set(value):
		light_color = value
		_queue_rebuild()
@export var light_energy: float = 3.0:
	set(value):
		light_energy = value
		_queue_rebuild()
@export var light_range: float = 9.0:
	set(value):
		light_range = value
		_queue_rebuild()
## Shadows from many torches get expensive; keep them for the important ones.
@export var shadows: bool = true:
	set(value):
		shadows = value
		_queue_rebuild()


func _build(rng: RandomNumberGenerator) -> void:
	var head: Vector3
	if wall_mounted:
		head = Vector3(0.0, 0.18, 0.34)
		add_mesh(KitMesh.cached("torch:bracket", _bracket_mesh), KitMaterials.iron())
	else:
		head = Vector3(0.0, post_height, 0.0)
		var lean := Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
		head += lean
		var key: String = "torch:post:%s:%d" % [post_height, variant]
		add_mesh(KitMesh.cached(key, _post_mesh.bind(head)), KitMaterials.named("bark"))
		add_cylinder_collider(0.15, post_height)
	add_mesh(KitMesh.cached("torch:head", _head_mesh), KitMaterials.flat(Color(0.12, 0.09, 0.07)),
		Transform3D(Basis.IDENTITY, head))
	add_mesh(KitMesh.cached("torch:coals", _coals_mesh), KitMaterials.glow(Color(1.0, 0.4, 0.1), 3.0),
		Transform3D(Basis.IDENTITY, head + Vector3(0, 0.17, 0)), false)

	var flame_at: Vector3 = head + Vector3(0.0, 0.22, 0.0)
	for fx: GPUParticles3D in [KitFx.fire(1.0), KitFx.embers(0.8), KitFx.smoke(0.6)]:
		fx.position = flame_at
		add_generated(fx)

	var light := FlickerLight.new()
	light.light_color = light_color
	light.base_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	light.position = flame_at + Vector3(0.0, 0.25, 0.0)
	add_generated(light)


func _post_mesh(top: Vector3) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.cylinder(st, Vector3.ZERO, top, 0.09, 0.065, 6, Color(0.8, 0.72, 0.62))
	return KitMesh.commit(st)


func _bracket_mesh() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var c := Color.WHITE
	KitMesh.box(st, Vector3(0, 0, 0.02), Vector3(0.14, 0.26, 0.04), c)  # wall plate
	KitMesh.cylinder(st, Vector3(0, -0.05, 0.03), Vector3(0, 0.12, 0.34), 0.025, 0.025, 5, c)  # arm
	KitMesh.cylinder(st, Vector3(0, 0.1, 0.34), Vector3(0, 0.2, 0.34), 0.09, 0.09, 6, c, false, false)  # ring
	return KitMesh.commit(st)


func _head_mesh() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	# A wooden handle wrapped in pitch-soaked cloth.
	KitMesh.cylinder(st, Vector3(0, -0.25, 0), Vector3(0, 0.02, 0), 0.04, 0.05, 6, Color(0.35, 0.25, 0.16))
	KitMesh.cylinder(st, Vector3(0, 0.0, 0), Vector3(0, 0.18, 0), 0.07, 0.085, 7, Color(0.5, 0.45, 0.4))
	return KitMesh.commit(st)


func _coals_mesh() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.blob(st, Vector3.ZERO, Vector3(0.075, 0.04, 0.075), 7, 0.3, Color.WHITE, 1)
	return KitMesh.commit(st)
