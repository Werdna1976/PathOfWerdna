@tool
class_name CharacterModel
extends Node3D
## Base for low-poly procedural character models, built from KitMesh parts on
## a simple joint hierarchy that CharacterAnimator drives:
##   Hips -> LegL, LegR, Torso -> Head, ArmL (-> LeftHand)
## The right arm is built inside the sibling WeaponPivot (the node that
## SwingAnimator sweeps), with a RightHand mount at its end, so the arm swings
## with the weapon. Put the model at Visual/Body; forward is -Z.
## Held items (a weapon, a shield) survive rebuilds: set them with set_held().

signal rebuilt

const META: StringName = &"model_generated"

## Seeds small per-instance variations (skin tone, proportions).
@export var variant: int = 0:
	set(value):
		variant = value
		_queue_rebuild()

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var left_hand: Node3D
var right_hand: Node3D
## Rest values the animator adds motion to.
var hip_height: float = 0.9
var torso_rest: Vector3 = Vector3.ZERO

var _held_weapon: Node3D
var _held_shield: Node3D
var _materials: Dictionary = {}
var _pending: bool = false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	# Skipped if something rebuilt the model directly in the meantime.
	if _pending:
		rebuild()


## The WeaponPivot next to this model (Visual/WeaponPivot), if any.
func weapon_pivot() -> Node3D:
	return get_parent().get_node_or_null("WeaponPivot") as Node3D if get_parent() != null else null


func rebuild() -> void:
	_pending = false
	for held: Node3D in [_held_weapon, _held_shield]:
		if held != null and held.get_parent() != null:
			held.get_parent().remove_child(held)
	for container: Node in [self, weapon_pivot()]:
		if container == null:
			continue
		for child: Node in container.get_children():
			if child.has_meta(META):
				container.remove_child(child)
				child.free()
	_materials.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [get_script().get_global_name(), variant])
	_build(rng)
	_attach_held()
	rebuilt.emit()


## Override: build the joints and parts.
func _build(_rng: RandomNumberGenerator) -> void:
	pass


## Attach (or clear, with null) the weapon and shield models the character holds.
func set_held(weapon: Node3D, shield: Node3D) -> void:
	for old: Node3D in [_held_weapon, _held_shield]:
		if old != null and old != weapon and old != shield:
			old.queue_free()
	_held_weapon = weapon
	_held_shield = shield
	_attach_held()


func held_weapon() -> Node3D:
	return _held_weapon


func held_shield() -> Node3D:
	return _held_shield


func _attach_held() -> void:
	for pair: Array in [[_held_weapon, right_hand], [_held_shield, left_hand]]:
		var held: Node3D = pair[0]
		var mount: Node3D = pair[1]
		if held == null or mount == null:
			continue
		if held.get_parent() != mount:
			if held.get_parent() != null:
				held.get_parent().remove_child(held)
			mount.add_child(held)


# --- Building helpers. ---

func joint(parent: Node3D, joint_name: String, pos: Vector3, rot_degrees: Vector3 = Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.name = joint_name
	j.position = pos
	j.rotation_degrees = rot_degrees
	if parent == self or parent == weapon_pivot():
		j.set_meta(META, true)
	parent.add_child(j)
	return j


## A mesh part on a joint, built once per key and shared between instances.
func part(parent: Node3D, key: String, builder: Callable, material: Material,
		xform: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = KitMesh.cached("%s:%s" % [get_script().get_global_name(), key], builder)
	mi.material_override = material
	mi.transform = xform
	if parent == self or parent == weapon_pivot():
		mi.set_meta(META, true)
	parent.add_child(mi)
	return mi


## A per-model material. Rim light keeps silhouettes readable in the dark.
func mat(color: Color, roughness: float = 0.8, metallic: float = 0.0,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s:%s:%s:%s:%s" % [color.to_html(), roughness, metallic, emission.to_html(), emission_energy]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		m.vertex_color_use_as_albedo = true
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.4
		if emission_energy > 0.0:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = emission_energy
		_materials[key] = m
	return _materials[key]


static func mesh_of(build: Callable) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	build.call(st)
	return KitMesh.commit(st)
