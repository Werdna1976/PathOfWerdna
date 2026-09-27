class_name Game
extends Node3D
## Root of the playable game (scenes/main.tscn). Keeps the player, camera and
## UI alive and swaps zones underneath them: town, wilderness and so on.
## Each zone is its own scene with its own navigation, lighting and entries
## (Marker3D nodes under an "Entries" node). Travelling unloads the current
## zone, loads the next one and places the player at the named entry.

signal zone_changed(zone: Node3D)

const GROUP: StringName = &"game"

@export_file("*.tscn") var start_zone: String = "res://scenes/levels/town.tscn"
@export var start_entry: StringName = &"start"

var current_zone: Node3D
var current_zone_path: String = ""

@onready var player: CharacterBody3D = $Player as CharacterBody3D
@onready var camera: FollowCamera = $Camera as FollowCamera
@onready var hud: Hud = $Hud as Hud


func _ready() -> void:
	add_to_group(GROUP)
	change_zone.call_deferred(start_zone, start_entry)


static func of(tree: SceneTree) -> Game:
	return tree.get_first_node_in_group(GROUP) as Game


## Where dropped items should go: the current zone, so they're left behind
## when the player travels. Falls back to `fallback` outside the game scene.
static func item_parent(tree: SceneTree, fallback: Node) -> Node:
	var game: Game = of(tree)
	return game.current_zone if game != null and game.current_zone != null else fallback


func change_zone(path: String, entry: StringName) -> void:
	(player.get_node("NavMovement") as NavMovement).stop()
	(player.get_node("PlayerCombat") as PlayerCombat).clear()
	hud.close_panels()
	if current_zone != null:
		remove_child(current_zone)
		current_zone.queue_free()
	var zone: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	add_child(zone)
	current_zone = zone
	current_zone_path = path

	var marker: Node3D = zone.get_node_or_null("Entries/" + String(entry)) as Node3D
	var arrive: Vector3 = marker.global_position if marker != null else Vector3.ZERO
	if marker == null:
		push_warning("Game: zone %s has no entry '%s'" % [path, entry])
	player.global_position = arrive
	player.reset_physics_interpolation()
	camera.snap_to_target()
	(player.get_node("PlayerRespawn") as PlayerRespawn).set_spawn(arrive)
	var info: AreaInfo = zone.get_node_or_null("AreaInfo") as AreaInfo
	hud.show_banner(info.zone_name if info != null else zone.name)
	zone_changed.emit(zone)
