@tool
class_name KitProp
extends Node3D
## Base class for the world kit's procedural props.
##
## A subclass overrides `_build()` and uses the helpers below to add meshes,
## lights, particles and colliders. The generated nodes are rebuilt on `_ready`
## (in the editor as well) and are never saved, so a prop scene only stores its
## script and export values.
## - `variant` seeds the random shape. Props with the same variant share meshes.
## - `collision` off makes the prop decorative: no colliders, so it doesn't
##   block movement or carve the navmesh. PropScatter sets it per entry.
## Colliders sit on the world layer (1), so a NavigationRegion3D above the prop
## carves them out of the navmesh when it bakes.
##
## To swap in a real model later, replace the prop's scene with one that has
## the same pivot (ground level, centred) and footprint.

const META: StringName = &"kit_generated"
const WORLD_LAYER: int = 1

@export var variant: int = 0:
	set(value):
		variant = value
		_queue_rebuild()
@export var collision: bool = true:
	set(value):
		collision = value
		_queue_rebuild()

var _body: StaticBody3D
var _pending: bool = false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		rebuild.call_deferred()


## Deletes the generated nodes and builds them again.
func rebuild() -> void:
	_pending = false
	for child: Node in get_children():
		if child.has_meta(META):
			remove_child(child)
			child.queue_free()
	_body = null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [_kind_name(), variant])
	_build(rng)


## Override: build the prop. `rng` is seeded from the variant.
func _build(_rng: RandomNumberGenerator) -> void:
	pass


## A short name for cache keys, e.g. "RockProp".
func _kind_name() -> String:
	var s: Script = get_script()
	var n: StringName = s.get_global_name() if s != null else &""
	return String(n) if n != &"" else name


func add_generated(node: Node) -> Node:
	node.set_meta(META, true)
	add_child(node)
	return node


func add_mesh(mesh: Mesh, material: Material = null, xform: Transform3D = Transform3D.IDENTITY,
		shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_generated(mi)
	return mi


## The prop's static body, created on first use.
func body() -> StaticBody3D:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Body"
		_body.collision_layer = WORLD_LAYER
		_body.collision_mask = 0
		add_generated(_body)
	return _body


func add_box_collider(size: Vector3, xform: Transform3D = Transform3D.IDENTITY) -> void:
	if not collision:
		return
	var box := BoxShape3D.new()
	box.size = size
	_add_shape(box, xform)


## A vertical cylinder standing on `base`.
func add_cylinder_collider(radius: float, height: float, base: Vector3 = Vector3.ZERO) -> void:
	if not collision:
		return
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	_add_shape(cyl, Transform3D(Basis.IDENTITY, base + Vector3(0.0, height * 0.5, 0.0)))


func _add_shape(shape: Shape3D, xform: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	body().add_child(cs)
