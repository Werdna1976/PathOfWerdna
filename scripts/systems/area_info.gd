class_name AreaInfo
extends Node
## Per-level settings. Area level sets monster level and dropped item level.

const GROUP: StringName = &"area_info"

@export_range(1, 100) var area_level: int = 1


func _ready() -> void:
	add_to_group(GROUP)


## The current area's level, or 1 if the level has no AreaInfo.
static func level_of(tree: SceneTree) -> int:
	var info: AreaInfo = tree.get_first_node_in_group(GROUP) as AreaInfo
	return info.area_level if info != null else 1
