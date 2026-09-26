class_name ClickMarker
extends MeshInstance3D
## A ring on the ground that grows and fades out, then frees itself.

@export var lifetime: float = 0.45
@export var start_scale: float = 0.5
@export var end_scale: float = 1.1

var _age: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	_material = (material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	material_override = _material
	scale = Vector3.ONE * start_scale


func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / lifetime
	if t >= 1.0:
		queue_free()
		return
	scale = Vector3.ONE * lerpf(start_scale, end_scale, t)
	_material.albedo_color.a = 1.0 - t * t
