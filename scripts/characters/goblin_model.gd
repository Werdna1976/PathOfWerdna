@tool
class_name GoblinModel
extends CharacterModel
## A hunched goblin: big ears, a long hooked nose, glowing eyes, a loincloth,
## long arms and a crude nail-studded club (in the WeaponPivot's hand).
## About 1.3 m tall; forward is -Z. `variant` shifts the skin tone and size a
## little so a pack doesn't look cloned; `randomize_variant` picks one on spawn.

const HIP_Y: float = 0.6

@export var skin_color: Color = Color(0.3, 0.42, 0.22):
	set(value):
		skin_color = value
		_queue_rebuild()
## Pick a random variant when spawned in game.
@export var randomize_variant: bool = true


func _ready() -> void:
	if randomize_variant and not Engine.is_editor_hint():
		variant = randi_range(0, 7)
	rebuild()


func _build(rng: RandomNumberGenerator) -> void:
	hip_height = HIP_Y
	var tone: Color = skin_color.lerp(Color(0.38, 0.4, 0.2), rng.randf() * 0.6).darkened(rng.randf() * 0.2)
	var skin: Material = mat(tone, 0.85)
	var dark_skin: Material = mat(tone.darkened(0.3), 0.9)
	var cloth: Material = mat(Color(0.3, 0.22, 0.14), 0.95)
	var eyes: Material = mat(Color(1.0, 0.85, 0.2), 1.0, 0.0, Color(1.0, 0.8, 0.15), 3.5)
	var wood: Material = mat(Color(0.3, 0.2, 0.12), 1.0)
	var iron: Material = mat(Color(0.3, 0.28, 0.26), 0.5, 0.7)
	var bone: Material = mat(Color(0.8, 0.76, 0.62), 0.7)

	hips = joint(self, "Hips", Vector3(0, HIP_Y, 0))
	leg_l = joint(hips, "LegL", Vector3(-0.11, 0, 0))
	leg_r = joint(hips, "LegR", Vector3(0.11, 0, 0))
	for leg: Node3D in [leg_l, leg_r]:
		part(leg, "leg", _leg_mesh, skin)
		part(leg, "foot", _foot_mesh, dark_skin)

	torso = joint(hips, "Torso", Vector3.ZERO, Vector3(-22, 0, 0))
	torso_rest = torso.rotation
	part(torso, "body", _body_mesh, skin)
	part(torso, "loincloth", _loincloth_mesh, cloth)
	part(torso, "belt", _belt_mesh, mat(Color(0.22, 0.15, 0.09), 0.9))
	part(torso, "tooth_necklace", _necklace_mesh, bone)

	head = joint(torso, "Head", Vector3(0, 0.5, -0.1), Vector3(18, 0, 0))
	part(head, "head", _head_mesh, skin)
	part(head, "ears", _ears_mesh, skin)
	part(head, "nose", _nose_mesh, dark_skin)
	part(head, "eyes", _eyes_mesh, eyes)
	part(head, "teeth", _teeth_mesh, bone)

	arm_l = joint(torso, "ArmL", Vector3(-0.22, 0.38, -0.02))
	part(arm_l, "arm", _arm_mesh, skin)
	part(arm_l, "hand", _hand_mesh, dark_skin)
	left_hand = joint(arm_l, "LeftHand", Vector3(0, -0.5, -0.08))

	var pivot: Node3D = weapon_pivot()
	if pivot != null:
		arm_r = joint(pivot, "ArmR", Vector3.ZERO)
		part(arm_r, "arm_r", _arm_r_mesh, skin)
		part(arm_r, "hand_r", _hand_r_mesh, dark_skin)
		right_hand = joint(arm_r, "RightHand", Vector3(0, -0.28, -0.32), Vector3(30, 0, 0))
		part(right_hand, "club", _club_mesh, wood)
		part(right_hand, "nails", _nails_mesh, iron)


func _leg_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.03, 0), Vector3(0, -0.28, -0.09), Vector3(0, -0.55, 0.02)] as Array[Vector3],
			[0.075, 0.06, 0.045] as Array[float], 6, Color.WHITE))


func _foot_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, -0.57, -0.06), Vector3(0.07, 0.04, 0.12), 3, 0.2, Color.WHITE, 1, -0.5))


func _body_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, 0.14, -0.02), Vector3(0.2, 0.2, 0.18), 5, 0.12, Color.WHITE, 1)
		KitMesh.blob(st, Vector3(0, 0.35, -0.03), Vector3(0.2, 0.14, 0.15), 6, 0.12, Color(0.95, 0.95, 0.95), 1)
		KitMesh.blob(st, Vector3(0, 0.36, 0.08), Vector3(0.14, 0.1, 0.09), 8, 0.15, Color(0.9, 0.9, 0.9), 1))


func _loincloth_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.box(st, Vector3(0, -0.12, -0.16), Vector3(0.18, 0.24, 0.02), Color.WHITE, Basis(Vector3.RIGHT, 0.25))
		KitMesh.box(st, Vector3(0, -0.12, 0.14), Vector3(0.2, 0.22, 0.02), Color(0.85, 0.85, 0.85), Basis(Vector3.RIGHT, -0.2)))


func _belt_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.cylinder(st, Vector3(0, -0.02, 0), Vector3(0, 0.05, 0), 0.19, 0.2, 8, Color.WHITE, false, false))


func _necklace_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for i: int in 5:
			var ang: float = PI + (i - 2) * 0.35
			var at := Vector3(sin(ang) * 0.14, 0.4, cos(ang) * 0.13 - 0.03)
			KitMesh.cylinder(st, at, at + Vector3(0, -0.06, -0.01), 0.012, 0.0, 4, Color.WHITE))


func _head_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, 0.02, 0), Vector3(0.14, 0.13, 0.14), 9, 0.1, Color.WHITE, 1)
		# Heavy brow and jaw.
		KitMesh.box(st, Vector3(0, 0.06, -0.115), Vector3(0.19, 0.04, 0.05), Color(0.85, 0.85, 0.85))
		KitMesh.blob(st, Vector3(0, -0.07, -0.06), Vector3(0.11, 0.05, 0.09), 10, 0.1, Color(0.95, 0.95, 0.95), 1))


func _ears_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for s: float in [-1.0, 1.0]:
			# Long, flat, drooping ears pointing out and back.
			var root_pt := Vector3(s * 0.12, 0.02, 0.01)
			var tip := Vector3(s * 0.4, 0.1, 0.12)
			var up := Vector3(0, 0.07, -0.02)
			KitMesh.tri(st, root_pt + up, root_pt - up, tip, Color.WHITE, root_pt + Vector3(0, 0, 0.3))
			KitMesh.tri(st, root_pt + up, root_pt - up, tip, Color(0.75, 0.6, 0.6), root_pt - Vector3(0, 0, 0.3)))


func _nose_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.03, -0.12), Vector3(0, -0.01, -0.22), Vector3(0, -0.06, -0.27)] as Array[Vector3],
			[0.035, 0.025, 0.006] as Array[float], 5, Color.WHITE))


func _eyes_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for s: float in [-1.0, 1.0]:
			KitMesh.box(st, Vector3(s * 0.055, 0.03, -0.128), Vector3(0.045, 0.022, 0.02), Color.WHITE, Basis(Vector3.FORWARD, -s * 0.25)))


func _teeth_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for s: float in [-1.0, 1.0]:
			KitMesh.cylinder(st, Vector3(s * 0.05, -0.06, -0.13), Vector3(s * 0.05, -0.01, -0.14), 0.013, 0.0, 4, Color.WHITE))


func _arm_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.02, 0), Vector3(-0.03, -0.25, 0.03), Vector3(0, -0.47, -0.06)] as Array[Vector3],
			[0.06, 0.045, 0.04] as Array[float], 6, Color.WHITE))


func _hand_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, -0.5, -0.07), Vector3(0.05, 0.06, 0.06), 12, 0.2, Color.WHITE, 1))


func _arm_r_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0.02, 0), Vector3(0.03, -0.2, -0.1), Vector3(0, -0.27, -0.3)] as Array[Vector3],
			[0.06, 0.045, 0.04] as Array[float], 6, Color.WHITE))


func _hand_r_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.blob(st, Vector3(0, -0.28, -0.32), Vector3(0.05, 0.06, 0.06), 14, 0.2, Color.WHITE, 1))


func _club_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		KitMesh.tube(st, [Vector3(0, 0, 0.08), Vector3(0, 0.01, -0.3), Vector3(0, 0.0, -0.62)] as Array[Vector3],
			[0.03, 0.05, 0.085] as Array[float], 6, Color.WHITE)
		KitMesh.blob(st, Vector3(0, 0, -0.64), Vector3(0.09, 0.09, 0.08), 15, 0.25, Color(0.9, 0.9, 0.9), 1))


func _nails_mesh() -> ArrayMesh:
	return mesh_of(func(st: SurfaceTool) -> void:
		for i: int in 5:
			var ang: float = TAU * i / 5.0 + 0.3
			var dir := Vector3(cos(ang), sin(ang), 0)
			var at := Vector3(0, 0, -0.52 - (i % 2) * 0.1)
			KitMesh.cylinder(st, at + dir * 0.06, at + dir * 0.14, 0.012, 0.0, 3, Color.WHITE))
