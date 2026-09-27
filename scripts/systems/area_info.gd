class_name AreaInfo
extends Node
## Per-level settings. Area level sets monster level and dropped item level.

const GROUP: StringName = &"area_info"

@export_range(1, 100) var area_level: int = 1
## Shown when the player enters.
@export var zone_name: String = ""
## Towns are safe: no monsters, and skills can't be used.
@export var is_town: bool = false
## Music and ambience ids for the Audio autoload. Empty = use the zone's Biome.
@export var music_id: StringName = &""
@export var ambience_id: StringName = &""


func _ready() -> void:
	add_to_group(GROUP)


## True when the current area is a town.
static func in_town(tree: SceneTree) -> bool:
	var info: AreaInfo = tree.get_first_node_in_group(GROUP) as AreaInfo
	return info != null and info.is_town


## The current area's level, or 1 if the level has no AreaInfo.
static func level_of(tree: SceneTree) -> int:
	var info: AreaInfo = tree.get_first_node_in_group(GROUP) as AreaInfo
	return info.area_level if info != null else 1
