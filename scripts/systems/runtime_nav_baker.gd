class_name RuntimeNavBaker
extends NavigationRegion3D
## Bakes this region's navmesh from its child static colliders on _ready,
## then waits until the navigation map actually contains this region's
## polygons (region sync is asynchronous) before announcing it is usable.

signal navigation_ready

const MAX_SYNC_FRAMES: int = 120

var is_navigation_ready: bool = false


func _ready() -> void:
	bake_navigation_mesh(false)
	var map: RID = get_navigation_map()
	for i: int in MAX_SYNC_FRAMES:
		await get_tree().physics_frame
		if _is_synced(map):
			break
	if not _is_synced(map):
		push_error("RuntimeNavBaker: navmesh did not sync to the map in %d frames." % MAX_SYNC_FRAMES)
	is_navigation_ready = true
	navigation_ready.emit()


func _is_synced(map: RID) -> bool:
	# Queries before the first map iteration are errors, so check that first.
	return NavigationServer3D.map_get_iteration_id(map) > 0 \
		and NavigationServer3D.map_get_closest_point_owner(map, global_position) == get_rid()
