@tool
class_name BannerProp
extends KitProp
## A cloth banner hanging from a crossbar on a pole, rippling in the wind
## (cloth_sway shader). Colours are per-instance shader parameters, so many
## banners share one material. Pivot: foot of the pole.

@export var pole_height: float = 3.4:
	set(value):
		pole_height = value
		_queue_rebuild()
@export var cloth_size: Vector2 = Vector2(0.9, 1.7):
	set(value):
		cloth_size = value
		_queue_rebuild()
@export var cloth_color: Color = Color(0.4, 0.07, 0.05):
	set(value):
		cloth_color = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	add_mesh(KitMesh.cached("banner:pole:%s:%s" % [pole_height, cloth_size.x], _pole), KitMaterials.named("bark"))
	add_cylinder_collider(0.12, pole_height)
	var quad := QuadMesh.new()
	quad.size = cloth_size
	quad.subdivide_width = 4
	quad.subdivide_depth = 12
	# QuadMesh UVs run from the top-left, so UV.y = 0 is the pinned top edge.
	var cloth: MeshInstance3D = add_mesh(quad, KitMaterials.named("banner"),
		Transform3D(Basis.IDENTITY, Vector3(0, pole_height - 0.12 - cloth_size.y * 0.5, 0.1)))
	cloth.set_instance_shader_parameter(&"albedo", cloth_color)


func _pole() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var c := Color(0.6, 0.5, 0.42)
	KitMesh.cylinder(st, Vector3.ZERO, Vector3(0, pole_height + 0.1, 0), 0.06, 0.05, 6, c)
	var half: float = cloth_size.x * 0.5 + 0.12
	KitMesh.cylinder(st, Vector3(-half, pole_height - 0.1, 0.1), Vector3(half, pole_height - 0.1, 0.1), 0.03, 0.03, 5, c)
	KitMesh.blob(st, Vector3(0, pole_height + 0.15, 0), Vector3(0.07, 0.09, 0.07), 3, 0.2, Color(0.3, 0.28, 0.25), 0)
	return KitMesh.commit(st)
