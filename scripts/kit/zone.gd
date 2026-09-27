@tool
class_name Zone
extends Node3D
## Root of a zone built with the world kit. Pick a Biome and the zone sets
## up its WorldEnvironment (sky, fog, ambient light), its Moonlight, and the
## biome's ambient particle effects across `bounds`. KitGround and
## PropScatter children read the same biome for ground materials and props.
##
## Build a new zone from scenes/kit/zone_template.tscn: pick a biome, move the
## ground and exits, place entries and gates, and add scatters and props.
## Gameplay nodes (AreaInfo, NavigationRegion3D, Entries, Exits, spawners)
## are ordinary children, exactly as in hand-built zones.

const META: StringName = &"kit_generated"

@export var biome: Biome:
	set(value):
		biome = value
		_queue_apply()
## Size of the playable area, centred on the zone origin. Ambient effects fill it.
@export var bounds: Vector3 = Vector3(40, 5, 40):
	set(value):
		bounds = value
		_queue_apply()
## Offset of the effects box from the zone origin.
@export var bounds_center: Vector3 = Vector3.ZERO:
	set(value):
		bounds_center = value
		_queue_apply()

var _pending: bool = false


## The Zone that `node` belongs to (its nearest Zone ancestor), or null.
static func of(node: Node) -> Zone:
	var n: Node = node
	while n != null:
		if n is Zone:
			return n as Zone
		n = n.get_parent()
	return null


func _ready() -> void:
	apply_biome()


func _queue_apply() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		apply_biome.call_deferred()


func apply_biome() -> void:
	_pending = false
	for child: Node in get_children():
		if child.has_meta(META) and child is GPUParticles3D:
			remove_child(child)
			child.queue_free()
	if biome == null:
		return
	var env: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null:
		env = WorldEnvironment.new()
		env.name = "WorldEnvironment"
		env.set_meta(META, true)
		add_child(env)
	env.environment = biome.make_environment()
	var moon: DirectionalLight3D = get_node_or_null("Moonlight") as DirectionalLight3D
	if moon == null:
		moon = DirectionalLight3D.new()
		moon.name = "Moonlight"
		moon.set_meta(META, true)
		add_child(moon)
	biome.apply_moon(moon)
	for scene: PackedScene in biome.ambient_effects:
		if scene == null:
			continue
		var fx: Node3D = scene.instantiate() as Node3D
		if fx is AmbientEffect and (fx as AmbientEffect).fit_to_zone:
			(fx as AmbientEffect).extents = Vector3(bounds.x * 0.5, bounds.y * 0.5, bounds.z * 0.5)
			fx.position = bounds_center + Vector3(0.0, bounds.y * 0.5, 0.0)
		fx.set_meta(META, true)
		add_child(fx)


## The biome's music id, unless the AreaInfo overrides it.
func music_id() -> StringName:
	var info: AreaInfo = get_node_or_null("AreaInfo") as AreaInfo
	if info != null and info.music_id != &"":
		return info.music_id
	return biome.music_id if biome != null else &""


func ambience_id() -> StringName:
	var info: AreaInfo = get_node_or_null("AreaInfo") as AreaInfo
	if info != null and info.ambience_id != &"":
		return info.ambience_id
	return biome.ambience_id if biome != null else &""
