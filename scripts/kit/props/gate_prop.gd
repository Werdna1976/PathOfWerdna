@tool
class_name GateProp
extends KitProp
## An open palisade gateway: two thick posts, a lintel with a skull, and
## optional torches on the posts. The opening (along X, `width` wide) has no
## collider, so it stays walkable. Pivot: centre of the opening, on the ground.
## Place a ZoneExit in the opening to make it a zone gate.

@export var width: float = 5.0:
	set(value):
		width = value
		_queue_rebuild()
@export var height: float = 3.6:
	set(value):
		height = value
		_queue_rebuild()
@export var torches: bool = true:
	set(value):
		torches = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "gate:%s:%s:%d" % [width, height, variant]
	add_mesh(KitMesh.cached(key, _mesh), KitMaterials.named("bark"))
	add_mesh(KitMesh.cached("gate:skull", _skull), KitMaterials.flat(Color(0.72, 0.68, 0.58), 0.7),
		Transform3D(Basis.IDENTITY, Vector3(0, height + 0.05, 0.3)))
	var half: float = width * 0.5 + 0.3
	for s: float in [-1.0, 1.0]:
		add_cylinder_collider(0.4, height, Vector3(s * half, 0, 0))
		if torches:
			var torch := TorchProp.new()
			torch.wall_mounted = true
			torch.light_energy = 3.0
			torch.light_range = 8.0
			torch.position = Vector3(s * half, height * 0.62, 0.35)
			add_generated(torch)


func _mesh() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var half: float = width * 0.5 + 0.3
	var c := Color(0.7, 0.6, 0.5)
	for s: float in [-1.0, 1.0]:
		KitMesh.cylinder(st, Vector3(s * half, -0.1, 0), Vector3(s * half, height, 0), 0.34, 0.3, 8, c)
		KitMesh.cylinder(st, Vector3(s * half, height, 0), Vector3(s * half, height + 0.6, 0), 0.3, 0.0, 8, c.lightened(0.1))
	KitMesh.box(st, Vector3(0, height - 0.15, 0.28), Vector3(width + 1.4, 0.35, 0.3), c.darkened(0.1))
	# Rope lashings where the lintel meets the posts.
	for s: float in [-1.0, 1.0]:
		KitMesh.cylinder(st, Vector3(s * half, height - 0.35, 0), Vector3(s * half, height + 0.05, 0), 0.36, 0.36, 8, Color(0.45, 0.38, 0.26), false, false)
	return KitMesh.commit(st)


func _skull() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.blob(st, Vector3(0, 0.22, 0), Vector3(0.2, 0.22, 0.22), 5, 0.1, Color.WHITE, 1)
	KitMesh.box(st, Vector3(0, 0.05, 0.08), Vector3(0.22, 0.12, 0.12), Color.WHITE)
	# Dark eye sockets.
	for s: float in [-1.0, 1.0]:
		KitMesh.blob(st, Vector3(s * 0.08, 0.22, 0.17), Vector3(0.05, 0.05, 0.04), 9, 0.1, Color(0.05, 0.04, 0.03), 0)
	return KitMesh.commit(st)
