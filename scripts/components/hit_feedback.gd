class_name HitFeedback
extends Node
## Makes damage readable: flashes the body and pops a floating number.
## With `flash_root` set, every mesh under it flashes (a whole character model,
## its weapon and shield included), using a shared additive overlay that is
## only attached for the length of the flash. Otherwise `body_mesh` flashes
## through its own material, as with the old capsule bodies.

const NUMBER_RISE: float = 1.2
const NUMBER_LIFETIME: float = 0.8
const FLASH_TIME: float = 0.15

@export var health: Health
## Optional. Shows "Block" / "Evade" when a hit is avoided.
@export var defenses: Defenses
## Every MeshInstance3D under this node flashes on a hit.
@export var flash_root: Node3D
## Used when there is no flash_root: a single mesh with a StandardMaterial3D override.
@export var body_mesh: MeshInstance3D
@export var number_color: Color = Color(1.0, 0.95, 0.85)
@export var number_height: float = 2.0

var _flash_material: StandardMaterial3D
var _overlay: StandardMaterial3D
var _flash_tween: Tween
var _flashing: Array[MeshInstance3D] = []


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	if defenses != null:
		defenses.avoided.connect(func(how: String) -> void: _spawn_text(how, Color(0.8, 0.8, 0.8)))
	if flash_root != null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_overlay.albedo_color = Color(1.0, 0.9, 0.8, 0.0)
	elif body_mesh != null:
		# Each instance gets its own material so flashes don't bleed across bodies.
		_flash_material = (body_mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		_flash_material.emission_enabled = true
		_flash_material.emission = Color(1.0, 0.9, 0.8)
		_flash_material.emission_energy_multiplier = 0.0
		body_mesh.material_override = _flash_material


func _on_damaged(amount: float) -> void:
	_flash()
	_spawn_number(amount)


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	if _overlay != null:
		_clear_overlay()
		for node: Node in flash_root.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			if mesh.material_overlay == null:
				mesh.material_overlay = _overlay
				_flashing.append(mesh)
		_overlay.albedo_color.a = 0.55
		_flash_tween.tween_property(_overlay, "albedo_color:a", 0.0, FLASH_TIME)
		_flash_tween.tween_callback(_clear_overlay)
	elif _flash_material != null:
		_flash_material.emission_energy_multiplier = 0.6
		_flash_tween.tween_property(_flash_material, "emission_energy_multiplier", 0.0, FLASH_TIME)


func _clear_overlay() -> void:
	for mesh: MeshInstance3D in _flashing:
		if is_instance_valid(mesh) and mesh.material_overlay == _overlay:
			mesh.material_overlay = null
	_flashing.clear()


func _spawn_number(amount: float) -> void:
	_spawn_text(str(int(roundf(amount))), number_color)


func _spawn_text(text: String, color: Color) -> void:
	var owner_body: Node3D = get_parent() as Node3D
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.font_size = 56
	label.outline_size = 12
	label.pixel_size = 0.008
	label.modulate = color
	# Parent to the level so the number stays put if the body moves or dies.
	owner_body.get_parent().add_child(label)
	var jitter := Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	label.global_position = owner_body.global_position + Vector3.UP * number_height + jitter
	var tween: Tween = label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + NUMBER_RISE, NUMBER_LIFETIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, NUMBER_LIFETIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
