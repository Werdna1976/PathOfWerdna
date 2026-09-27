@tool
class_name KitGround
extends StaticBody3D
## A flat walkable ground slab: a plane mesh with the top at y = 0 and a box
## collider underneath (on the world layer, so the navmesh bakes on it).
## With no material set it uses the zone biome's ground material.
## Keep it under the zone's NavigationRegion3D.

const META: StringName = &"kit_generated"

@export var size: Vector2 = Vector2(40, 40):
	set(value):
		size = value
		_queue_rebuild()
@export var material: Material:
	set(value):
		material = value
		_queue_rebuild()
@export var thickness: float = 1.0:
	set(value):
		thickness = value
		_queue_rebuild()

var _pending: bool = false


func _ready() -> void:
	collision_layer = KitProp.WORLD_LAYER
	collision_mask = 0
	rebuild()


func _queue_rebuild() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		rebuild.call_deferred()


func rebuild() -> void:
	_pending = false
	for child: Node in get_children():
		if child.has_meta(META):
			remove_child(child)
			child.queue_free()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, thickness, size.y)
	shape.shape = box
	shape.position.y = -thickness * 0.5
	shape.set_meta(META, true)
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = int(size.x / 4.0)
	plane.subdivide_depth = int(size.y / 4.0)
	mesh.mesh = plane
	mesh.material_override = _material()
	mesh.set_meta(META, true)
	add_child(mesh)


func _material() -> Material:
	if material != null:
		return material
	var zone: Zone = Zone.of(self)
	if zone != null and zone.biome != null and zone.biome.ground_material != null:
		return zone.biome.ground_material
	return KitMaterials.named("dirt")
