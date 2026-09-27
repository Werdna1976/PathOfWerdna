@tool
class_name WarriorModel
extends CharacterModel
## Werdna: a low-poly armoured warrior with a beard and an optional cape.
## His look follows his gear (see EquipmentVisuals):
## - `armour` restyles the body: plate (STR), leather (DEX), robe (INT), scale
##   (STR/DEX), chain with a tabard (STR/INT), padded (DEX/INT), or a plain tunic.
## - `helm` adds a great helm, hood, circlet, sallet, coif or mask.
## - `gloves` and `boots` recolour the hands and feet by defence type.
## About 1.8 m tall; forward is -Z.

enum Armour { NONE, PLATE, LEATHER, ROBE, SCALE, CHAIN, PADDED }

const HIP_Y: float = 0.92
## Defence kind (GearModels.defence_kind) -> style.
const STYLE_BY_KIND: Dictionary = {
	"": Armour.NONE, "str": Armour.PLATE, "dex": Armour.LEATHER, "int": Armour.ROBE,
	"str_dex": Armour.SCALE, "str_int": Armour.CHAIN, "dex_int": Armour.PADDED,
}

@export var armour: Armour = Armour.PLATE:
	set(value):
		armour = value
		_queue_rebuild()
@export var helm: Armour = Armour.NONE:
	set(value):
		helm = value
		_queue_rebuild()
@export var gloves: Armour = Armour.NONE:
	set(value):
		gloves = value
		_queue_rebuild()
@export var boots: Armour = Armour.NONE:
	set(value):
		boots = value
		_queue_rebuild()
@export var cape: bool = true:
	set(value):
		cape = value
		_queue_rebuild()
@export var cape_color: Color = Color(0.3, 0.05, 0.04):
	set(value):
		cape_color = value
		_queue_rebuild()


## Sets every style at once and rebuilds immediately (EquipmentVisuals uses this).
func set_look(body: Armour, head_style: Armour, hands: Armour, feet: Armour) -> void:
	if body == armour and head_style == helm and hands == gloves and feet == boots:
		return
	armour = body
	helm = head_style
	gloves = hands
	boots = feet
	rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	hip_height = HIP_Y
	var skin: Material = mat(Color(0.72, 0.55, 0.43), 0.7)
	var hair: Material = mat(Color(0.2, 0.13, 0.08), 0.9)
	var main: Material = _armour_material(armour)
	var under: Material = mat(Color(0.2, 0.17, 0.14), 0.9)  # leggings, sleeves
	var leather: Material = mat(Color(0.24, 0.16, 0.1), 0.75)
	var trim: Material = _trim_material(armour)
	var shoulder: Vector3 = _shoulder_scale(armour)
	var metal_limbs: bool = armour in [Armour.PLATE, Armour.SCALE, Armour.CHAIN]

	hips = joint(self, "Hips", Vector3(0, HIP_Y, 0))
	# Legs.
	leg_l = joint(hips, "LegL", Vector3(-0.12, 0, 0))
	leg_r = joint(hips, "LegR", Vector3(0.12, 0, 0))
	for leg: Node3D in [leg_l, leg_r]:
		part(leg, "leg", _leg_mesh, main if metal_limbs else under)
		part(leg, "boot", _boot_mesh, _limb_material(boots, leather))
		if armour == Armour.PLATE:
			part(leg, "knee", _knee_mesh, trim)

	# Torso, with belt, skirt and shoulders.
	torso = joint(hips, "Torso", Vector3.ZERO)
	torso_rest = Vector3.ZERO
	var flat := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.72)), Vector3.ZERO)
	part(torso, "torso", _torso_mesh, main, flat)
	part(torso, "belt", _belt_mesh, leather)
	part(torso, "buckle", _buckle_mesh, mat(Color(0.8, 0.6, 0.25), 0.4, 0.8, Color(1.0, 0.6, 0.2), 0.4))
	match armour:
		Armour.PLATE, Armour.SCALE:
			part(torso, "tassets", _tassets_mesh, main)
		Armour.ROBE:
			part(torso, "robe_skirt", _robe_mesh, main)
			part(torso, "robe_trim", _robe_trim_mesh, trim)
		Armour.CHAIN:
			part(torso, "tabard", _tabard_mesh, mat(Color(0.35, 0.07, 0.06), 0.9))
		Armour.LEATHER, Armour.PADDED:
			part(torso, "flaps", _flaps_mesh, leather if armour == Armour.PADDED else main)
	if shoulder != Vector3.ZERO:
		for s: float in [-1.0, 1.0]:
			part(torso, "pauldron", _pauldron_mesh, trim,
				Transform3D(Basis.from_scale(shoulder), Vector3(s * 0.27, 0.52, 0)))
	part(torso, "neck", _neck_mesh, skin)
	if cape:
		var hang: Node3D = joint(torso, "Cape", Vector3(0, 0.56, 0.16), Vector3(10, 0, 0))
		var quad := QuadMesh.new()
		quad.size = Vector2(0.56, 1.0)
		quad.subdivide_width = 3
		quad.subdivide_depth = 8
		var cloth := MeshInstance3D.new()
		cloth.mesh = quad
		cloth.material_override = KitMaterials.named("banner")
		cloth.position = Vector3(0, -0.5, 0)
		cloth.set_instance_shader_parameter(&"albedo", cape_color)
		hang.add_child(cloth)

	# Head: face, beard, hair or helm.
	head = joint(torso, "Head", Vector3(0, 0.72, 0))
	part(head, "head", _head_mesh, skin)
	part(head, "beard", _beard_mesh, hair)
	_build_helm(head, hair)

	# Left arm, with the shield mount at the hand.
	arm_l = joint(torso, "ArmL", Vector3(-0.3, 0.5, 0))
	part(arm_l, "arm_l", _arm_l_mesh, main if metal_limbs else under)
	part(arm_l, "hand_l", _hand_mesh.bind(Vector3(0, -0.56, -0.06)), _limb_material(gloves, leather))
	left_hand = joint(arm_l, "LeftHand", Vector3(0.02, -0.52, -0.14), Vector3(0, 0, 0))

	# Right arm lives in the weapon pivot so it swings with the weapon.
	var pivot: Node3D = weapon_pivot()
	if pivot != null:
		arm_r = joint(pivot, "ArmR", Vector3.ZERO)
		part(arm_r, "arm_r", _arm_r_mesh, main if metal_limbs else under)
		part(arm_r, "hand_r", _hand_mesh.bind(Vector3(0, -0.4, -0.36)), _limb_material(gloves, leather))
		right_hand = joint(arm_r, "RightHand", Vector3(0, -0.4, -0.38), Vector3(25, 0, 0))


func _build_helm(on: Node3D, hair: Material) -> void:
	var metal: Material = mat(Color(0.5, 0.5, 0.52), 0.35, 0.85)
	var slit_glow: Material = mat(Color(0.1, 0.05, 0.02), 1.0, 0.0, Color(1.0, 0.55, 0.2), 1.6)
	match helm:
		Armour.PLATE, Armour.SCALE:
			var tint: Material = metal if helm == Armour.PLATE else mat(Color(0.5, 0.38, 0.22), 0.4, 0.8)
			part(on, "great_helm", _great_helm_mesh, tint)
			part(on, "visor", _visor_mesh, slit_glow)
		Armour.LEATHER, Armour.PADDED:
			part(on, "hood", _hood_mesh, mat(Color(0.2, 0.15, 0.1) if helm == Armour.LEATHER else Color(0.16, 0.2, 0.14), 0.9))
		Armour.ROBE:
			part(on, "hair", _hair_mesh, hair)
			part(on, "circlet", _circlet_mesh, mat(Color(0.7, 0.55, 0.25), 0.35, 0.9))
			part(on, "circlet_gem", _circlet_gem_mesh, mat(Color(0.2, 0.4, 0.9), 0.3, 0.0, Color(0.35, 0.6, 1.0), 2.5))
		Armour.CHAIN:
			part(on, "coif", _hood_mesh, mat(Color(0.45, 0.45, 0.47), 0.5, 0.7))
		_:
			part(on, "hair", _hair_mesh, hair)


func _armour_material(style: Armour) -> Material:
	match style:
		Armour.PLATE: return mat(Color(0.52, 0.53, 0.56), 0.35, 0.85)
		Armour.LEATHER: return mat(Color(0.33, 0.22, 0.13), 0.75)
		Armour.ROBE: return mat(Color(0.16, 0.14, 0.3), 0.9)
		Armour.SCALE: return mat(Color(0.5, 0.38, 0.22), 0.45, 0.75)
		Armour.CHAIN: return mat(Color(0.42, 0.42, 0.44), 0.5, 0.7)
		Armour.PADDED: return mat(Color(0.2, 0.25, 0.17), 0.9)
	return mat(Color(0.36, 0.3, 0.22), 0.9)


func _trim_material(style: Armour) -> Material:
	match style:
		Armour.PLATE: return mat(Color(0.62, 0.63, 0.66), 0.3, 0.9)
		Armour.ROBE: return mat(Color(0.5, 0.4, 0.2), 0.5, 0.6, Color(0.35, 0.5, 1.0), 0.8)
		Armour.SCALE: return mat(Color(0.6, 0.45, 0.25), 0.4, 0.8)
		Armour.CHAIN: return mat(Color(0.5, 0.5, 0.52), 0.35, 0.85)
	return mat(Color(0.3, 0.2, 0.12), 0.8)


func _limb_material(style: Armour, fallback: Material) -> Material:
	if style == Armour.NONE:
		return fallback
	return _trim_material(style) if style in [Armour.PLATE, Armour.SCALE, Armour.CHAIN] else _armour_material(style)


func _shoulder_scale(style: Armour) -> Vector3:
	match style:
		Armour.PLATE: return Vector3(0.17, 0.12, 0.17)
		Armour.SCALE: return Vector3(0.14, 0.1, 0.14)
		Armour.CHAIN: return Vector3(0.12, 0.08, 0.12)
		Armour.LEATHER, Armour.PADDED: return Vector3(0.1, 0.07, 0.11)
	return Vector3.ZERO


# --- Mesh parts (local to their joint). ---

func _leg_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.04, 0), Vector3(0, -0.45, -0.015), Vector3(0, -0.84, 0)] as Array[Vector3],
			[0.1, 0.08, 0.065] as Array[float], 7, Color.WHITE))


func _boot_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.box(st, Vector3(0, -0.86, -0.04), Vector3(0.14, 0.13, 0.26), Color.WHITE)
		KitMesh.cylinder(st, Vector3(0, -0.8, 0), Vector3(0, -0.62, 0), 0.08, 0.075, 7, Color(0.9, 0.9, 0.9)))


func _knee_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, -0.45, -0.07), Vector3(0.07, 0.07, 0.05), 5, 0.1, Color.WHITE, 1))


func _torso_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, -0.02, 0), Vector3(0, 0.25, 0), Vector3(0, 0.47, -0.01), Vector3(0, 0.62, 0)] as Array[Vector3],
			[0.18, 0.21, 0.27, 0.15] as Array[float], 8, Color.WHITE))


func _belt_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, -0.02, 0), Vector3(0, 0.07, 0), 0.19, 0.19, 8, Color.WHITE, false, false))


func _buckle_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.box(st, Vector3(0, 0.025, -0.145), Vector3(0.08, 0.07, 0.03), Color.WHITE))


func _tassets_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for i: int in 5:
			var ang: float = PI + (i - 2) * 0.55
			var dir := Vector3(sin(ang), 0, cos(ang))
			KitMesh.box(st, dir * 0.19 + Vector3(0, -0.13, 0), Vector3(0.13, 0.22, 0.03), Color.WHITE,
				Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, -0.2)))


func _robe_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, 0.05, 0), Vector3(0, -0.8, 0), 0.19, 0.3, 9, Color.WHITE, false, true))


func _robe_trim_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, -0.76, 0), Vector3(0, -0.82, 0), 0.305, 0.31, 9, Color.WHITE, false, false)
		KitMesh.box(st, Vector3(0, -0.35, -0.24), Vector3(0.05, 0.85, 0.02), Color.WHITE, Basis(Vector3.RIGHT, 0.13)))


func _tabard_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.box(st, Vector3(0, 0.05, -0.17), Vector3(0.26, 0.85, 0.02), Color.WHITE, Basis(Vector3.RIGHT, 0.08))
		KitMesh.box(st, Vector3(0, 0.05, 0.17), Vector3(0.26, 0.85, 0.02), Color(0.8, 0.8, 0.8), Basis(Vector3.RIGHT, -0.08)))


func _flaps_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for z: float in [-1.0, 1.0]:
			KitMesh.box(st, Vector3(0, -0.14, z * 0.14), Vector3(0.28, 0.24, 0.03), Color.WHITE, Basis(Vector3.RIGHT, -z * 0.15)))


func _pauldron_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3.ZERO, Vector3.ONE, 7, 0.12, Color.WHITE, 1, -0.3))


func _neck_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, 0.58, 0), Vector3(0, 0.68, 0), 0.065, 0.06, 6, Color.WHITE))


func _head_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, 0.03, 0), Vector3(0.115, 0.135, 0.125), 11, 0.08, Color.WHITE, 1)
		KitMesh.cylinder(st, Vector3(0, 0.04, -0.11), Vector3(0, 0.0, -0.15), 0.025, 0.012, 4, Color(0.95, 0.85, 0.8))
		for s: float in [-1.0, 1.0]:
			KitMesh.blob(st, Vector3(s * 0.045, 0.05, -0.108), Vector3(0.018, 0.012, 0.01), 2, 0.0, Color(0.05, 0.04, 0.03), 0))


func _beard_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, -0.06, -0.07), Vector3(0.09, 0.08, 0.06), 13, 0.25, Color.WHITE, 1)
		KitMesh.blob(st, Vector3(0, 0.0, -0.105), Vector3(0.06, 0.02, 0.02), 14, 0.2, Color.WHITE, 0))


func _hair_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, 0.08, 0.02), Vector3(0.125, 0.11, 0.125), 17, 0.2, Color.WHITE, 1))


func _great_helm_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, -0.1, 0), Vector3(0, 0.12, 0), 0.15, 0.145, 8, Color.WHITE, true, false)
		KitMesh.blob(st, Vector3(0, 0.12, 0), Vector3(0.145, 0.08, 0.145), 19, 0.02, Color.WHITE, 1, 0.0)
		KitMesh.box(st, Vector3(0, 0.02, -0.15), Vector3(0.03, 0.2, 0.02), Color(1.2, 1.2, 1.2)))


func _visor_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for s: float in [-1.0, 1.0]:
			KitMesh.box(st, Vector3(s * 0.06, 0.05, -0.145), Vector3(0.075, 0.022, 0.012), Color.WHITE))


func _hood_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, 0.05, 0.035), Vector3(0.15, 0.16, 0.15), 23, 0.1, Color.WHITE, 1)
		KitMesh.cylinder(st, Vector3(0, -0.08, 0.03), Vector3(0, -0.16, 0.03), 0.13, 0.2, 8, Color(0.9, 0.9, 0.9), false, false))


func _circlet_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, 0.08, 0), Vector3(0, 0.11, 0), 0.128, 0.128, 10, Color.WHITE, false, false))


func _circlet_gem_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, 0.095, -0.13), Vector3(0.022, 0.026, 0.015), 29, 0.0, Color.WHITE, 0))


func _arm_l_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.02, 0), Vector3(-0.02, -0.28, 0.02), Vector3(0.0, -0.52, -0.05)] as Array[Vector3],
			[0.075, 0.062, 0.052] as Array[float], 6, Color.WHITE))


func _arm_r_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.02, 0), Vector3(0.02, -0.26, -0.1), Vector3(0, -0.38, -0.32)] as Array[Vector3],
			[0.075, 0.062, 0.052] as Array[float], 6, Color.WHITE))


func _hand_mesh(at: Vector3) -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, at, Vector3(0.06, 0.065, 0.07), 31, 0.1, Color.WHITE, 1))
