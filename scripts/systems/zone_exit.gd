class_name ZoneExit
extends Area3D
## A doorway to another zone. Walking into it travels there. Builds its own
## placeholder look: a glowing floor patch, a light and a floating label.

@export_file("*.tscn") var target_zone: String
## Name of the Marker3D under the target zone's "Entries" node.
@export var target_entry: StringName
@export var label_text: String = "Travel"
@export var size: Vector3 = Vector3(2.0, 2.0, 4.0)
@export var glow_color: Color = Color(0.45, 0.65, 1.0)

var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)

	var patch := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	patch.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(glow_color, 0.35)
	patch.material_override = material
	patch.position.y = 0.03
	add_child(patch)

	var light := OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.position.y = 1.2
	add_child(light)

	var label := Label3D.new()
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.008
	label.modulate = glow_color.lightened(0.4)
	label.position.y = size.y + 0.6
	add_child(label)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _used or not body.is_in_group("player"):
		return
	var game: Game = Game.of(get_tree())
	if game == null:
		return
	_used = true
	# Deferred: the zone (and this node) can't be freed during a physics callback.
	game.change_zone.call_deferred(target_zone, target_entry)
