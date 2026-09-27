class_name GroundItem
extends Node3D
## An item lying on the floor: a small tile glowing in its rarity colour with
## the item's icon floating over it. Rares and legendaries also get a light
## beam. Its clickable label is drawn by GroundLabels.

const GROUP: StringName = &"ground_items"
const CELL: float = 0.22
## Height of the floating icon in metres.
const ICON_HEIGHT: float = 0.55

var item: Item


## Creates a ground item under `parent` at `at`, with a small drop "pop".
static func spawn(dropped: Item, parent: Node, at: Vector3) -> GroundItem:
	var ground := GroundItem.new()
	ground.item = dropped
	parent.add_child(ground)
	ground.global_position = at
	return ground


func _ready() -> void:
	add_to_group(GROUP)
	var color: Color = item.color()

	var tile := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(item.base.size.x * CELL, 0.08, item.base.size.y * CELL)
	tile.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.6
	tile.material_override = material
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.position.y = 0.04
	add_child(tile)

	# The item's icon floats just above the tile, facing the camera.
	var icon_texture: Texture2D = ItemIcons.texture_for(item)
	if icon_texture != null:
		var icon := Sprite3D.new()
		icon.name = "Icon"
		icon.texture = icon_texture
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.shaded = false
		icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.pixel_size = ICON_HEIGHT / maxf(icon_texture.get_height(), icon_texture.get_width())
		icon.position.y = ICON_HEIGHT * 0.5 + 0.06
		tile.add_child(icon)

	if not item.base.is_currency() and item.rarity >= Item.Rarity.RARE:
		_add_beam(color)

	# Drop pop: arc up and settle.
	tile.position.y = 0.8
	var tween: Tween = create_tween()
	tween.tween_property(tile, "position:y", 0.04, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _add_beam(color: Color) -> void:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.12
	cylinder.height = 6.0
	beam.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, 0.35)
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 3.0
	add_child(beam)

	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.2
	glow.omni_range = 2.5
	glow.position.y = 0.5
	add_child(glow)
