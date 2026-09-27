@tool
class_name ScatterExclusion
extends Node3D
## Keeps PropScatter from placing props in an area: a circle, a (rotated)
## box, or a path of line segments with a width. Put these over roads,
## plazas, gates and anywhere the player must be able to walk.
## Scatters also avoid Entries/Exits and spawn markers on their own.

const GROUP: StringName = &"scatter_exclusion"

enum Shape { CIRCLE, BOX, PATH }

@export var shape: Shape = Shape.CIRCLE
@export var radius: float = 3.0
## Box size on X and Z (local, so the node's rotation turns it).
@export var box_size: Vector2 = Vector2(6, 6)
## Path points in local X/Z; the path is `radius` wide on each side.
@export var path_points: PackedVector2Array = PackedVector2Array()


func _enter_tree() -> void:
	add_to_group(GROUP)


## True if the world-space point is excluded (with an extra `margin`).
func excludes(point: Vector3, margin: float = 0.0) -> bool:
	var local: Vector3 = global_transform.affine_inverse() * point
	var p := Vector2(local.x, local.z)
	match shape:
		Shape.CIRCLE:
			return p.length() <= radius + margin
		Shape.BOX:
			return absf(p.x) <= box_size.x * 0.5 + margin and absf(p.y) <= box_size.y * 0.5 + margin
		Shape.PATH:
			for i: int in path_points.size() - 1:
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, path_points[i], path_points[i + 1])
				if closest.distance_to(p) <= radius + margin:
					return true
	return false
