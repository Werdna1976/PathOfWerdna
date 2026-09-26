class_name CursorRay
extends RefCounted
## Raycasts from the active camera through the mouse cursor.

const RAY_LENGTH: float = 500.0
const NO_HIT: Vector3 = Vector3.INF


## Returns the physics hit under the cursor for the given mask, or {}.
static func cast(viewport: Viewport, mask: int) -> Dictionary:
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return {}
	var mouse: Vector2 = viewport.get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, mask)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


## Returns the ground point under the cursor (flattened to y = 0), or NO_HIT.
static func ground_point(viewport: Viewport, ground_mask: int) -> Vector3:
	var hit: Dictionary = cast(viewport, ground_mask)
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		# The arena floor is flat at y = 0; clicks on obstacles walk toward their base.
		point.y = 0.0
		return point
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return NO_HIT
	var mouse: Vector2 = viewport.get_mouse_position()
	var plane_hit: Variant = Plane.PLANE_XZ.intersects_ray(
		camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return plane_hit as Vector3 if plane_hit != null else NO_HIT
