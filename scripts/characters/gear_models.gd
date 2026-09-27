class_name GearModels
extends RefCounted
## Low-poly weapon and shield models for characters to hold.
## Weapons: the grip is at the origin and the weapon points along -Z (forward
## in a hand mount). Shields: the arm strap is at the origin and the face looks
## along -Z. `tier` (0..1, from the base's drop level) moves the metal from
## rusty iron toward bright steel.

static var _materials: Dictionary = {}


## An item's weapon model, or null if it isn't a weapon.
static func weapon_for(item: Item) -> Node3D:
	if item == null or not item.base.is_weapon():
		return null
	var kind: String = "sword"
	for k: String in ["axe", "sword", "mace"]:
		if item.base.has_tag(StringName(k)):
			kind = k
	return weapon(kind, item.base.is_two_handed(), tier_of(item.base))


## An item's shield model, or null if it isn't a shield.
static func shield_for(item: Item) -> Node3D:
	if item == null or not item.base.has_tag(&"shield"):
		return null
	return shield(defence_kind(item.base), tier_of(item.base))


static func tier_of(base: ItemBase) -> float:
	return clampf((base.drop_level - 1) / 60.0, 0.0, 1.0)


## "str", "dex", "int", "str_dex", "str_int", "dex_int", or "" for no defences.
static func defence_kind(base: ItemBase) -> String:
	var parts: Array[String] = []
	for tag: String in ["str", "dex", "int"]:
		if base.has_tag(StringName(tag + "_armour")):
			parts.append(tag)
	return "_".join(parts)


static func weapon(kind: String, two_handed: bool, tier: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon"
	var key: String = "%s:%s:%d" % [kind, two_handed, roundi(tier * 4.0)]
	var length: float = 1.35 if two_handed else 0.85
	var metal: Material = _metal(tier)
	var wood: Material = _flat(Color(0.3, 0.2, 0.12), 0.9)
	match kind:
		"axe":
			_add(root, KitMesh.cached("axe_haft:" + key, _haft.bind(length, 0.028)), wood)
			_add(root, KitMesh.cached("axe_head:" + key, _axe_head.bind(length, two_handed)), metal)
		"mace":
			_add(root, KitMesh.cached("mace_haft:" + key, _haft.bind(length * 0.95, 0.03)), wood)
			_add(root, KitMesh.cached("mace_head:" + key, _mace_head.bind(length, two_handed)), metal)
		_:
			_add(root, KitMesh.cached("sword_hilt:" + key, _sword_hilt.bind(two_handed)), _flat(Color(0.25, 0.17, 0.1), 0.8))
			_add(root, KitMesh.cached("sword_blade:" + key, _sword_blade.bind(length, two_handed)), metal)
	return root


## Shield styles by defence: str = tower, dex = buckler, int = spirit shield,
## str_dex = round, str_int = kite, dex_int = spiked.
static func shield(kind: String, tier: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Shield"
	var metal: Material = _metal(tier)
	var wood: Material = KitMaterials.named("planks")
	match kind:
		"str":
			_add(root, KitMesh.cached("shield_tower", _tower), wood)
			_add(root, KitMesh.cached("shield_tower_rim", _tower_rim), metal)
		"int":
			_add(root, KitMesh.cached("shield_spirit", _round.bind(0.3, 10, 0.05)), _flat(Color(0.75, 0.72, 0.65), 0.6))
			_add(root, KitMesh.cached("shield_rune", _boss.bind(0.07)), _glow(Color(0.35, 0.6, 1.0), 2.5))
		"dex":
			_add(root, KitMesh.cached("shield_buckler", _round.bind(0.22, 9, 0.04)), _flat(Color(0.35, 0.24, 0.15), 0.9))
			_add(root, KitMesh.cached("shield_boss_small", _boss.bind(0.07)), metal)
		"str_int":
			_add(root, KitMesh.cached("shield_kite", _kite), wood)
			_add(root, KitMesh.cached("shield_boss", _boss.bind(0.08)), metal)
		"dex_int":
			_add(root, KitMesh.cached("shield_spiked", _round.bind(0.27, 8, 0.05)), _flat(Color(0.3, 0.22, 0.15), 0.9))
			_add(root, KitMesh.cached("shield_spikes", _spikes), metal)
		_:
			_add(root, KitMesh.cached("shield_round", _round.bind(0.3, 12, 0.05)), wood)
			_add(root, KitMesh.cached("shield_boss", _boss.bind(0.08)), metal)
	return root


static func _add(root: Node3D, mesh: Mesh, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	root.add_child(mi)


static func _metal(tier: float) -> StandardMaterial3D:
	var color: Color = Color(0.36, 0.3, 0.26).lerp(Color(0.72, 0.74, 0.78), tier)
	return _flat(color, lerpf(0.7, 0.3, tier), lerpf(0.5, 0.9, tier))


static func _flat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s:%s:%s" % [color.to_html(), roughness, metallic]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		m.vertex_color_use_as_albedo = true
		m.rim_enabled = true
		m.rim = 0.5
		m.rim_tint = 0.3
		_materials[key] = m
	return _materials[key]


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	return KitMaterials.glow(color, energy)


# --- Weapon parts. ---

static func _haft(length: float, radius: float) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.cylinder(st, Vector3(0, 0, 0.12), Vector3(0, 0, -length), radius, radius * 0.85, 6, Color.WHITE)
	return KitMesh.commit(st)


static func _axe_head(length: float, two_handed: bool) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var z: float = -length + 0.12
	var sides: Array[float] = [1.0]
	if two_handed:
		sides.append(-1.0)
	var s: float = 1.3 if two_handed else 1.0
	for side: float in sides:
		# A wedge: thick at the haft, fanning out to a curved edge.
		var inside := Vector3(side * 0.08 * s, 0, z)
		var t: float = 0.025
		var a := Vector3(side * 0.03, 0, z - 0.06 * s)
		var b := Vector3(side * 0.03, 0, z + 0.08 * s)
		var c := Vector3(side * 0.2 * s, 0, z + 0.14 * s)
		var d := Vector3(side * 0.23 * s, 0, z - 0.02)
		var e := Vector3(side * 0.2 * s, 0, z - 0.16 * s)
		for pts: Array in [[a, b, c], [a, c, d], [a, d, e]]:
			var p0: Vector3 = pts[0]
			var p1: Vector3 = pts[1]
			var p2: Vector3 = pts[2]
			KitMesh.tri(st, p0 + Vector3.UP * t, p1 + Vector3.UP * t, p2 + Vector3.UP * t * 0.3, Color.WHITE, inside)
			KitMesh.tri(st, p0 - Vector3.UP * t, p1 - Vector3.UP * t, p2 - Vector3.UP * t * 0.3, Color.WHITE, inside)
		KitMesh.quad(st, c + Vector3.UP * t * 0.3, d + Vector3.UP * t * 0.3, d - Vector3.UP * t * 0.3, c - Vector3.UP * t * 0.3, Color(1.3, 1.3, 1.3), inside)
		KitMesh.quad(st, d + Vector3.UP * t * 0.3, e + Vector3.UP * t * 0.3, e - Vector3.UP * t * 0.3, d - Vector3.UP * t * 0.3, Color(1.3, 1.3, 1.3), inside)
	KitMesh.box(st, Vector3(0, 0, z), Vector3(0.07, 0.07, 0.16 * s), Color(0.8, 0.8, 0.8))
	return KitMesh.commit(st)


static func _mace_head(length: float, two_handed: bool) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var z: float = -length * 0.95
	if two_handed:
		# A maul: a heavy squared hammer head.
		KitMesh.box(st, Vector3(0, 0, z), Vector3(0.34, 0.16, 0.18), Color.WHITE)
		KitMesh.box(st, Vector3(0, 0, z), Vector3(0.38, 0.12, 0.14), Color(0.8, 0.8, 0.8))
	else:
		KitMesh.blob(st, Vector3(0, 0, z), Vector3(0.09, 0.09, 0.11), 3, 0.15, Color.WHITE, 1)
		for i: int in 6:
			var ang: float = TAU * i / 6.0
			var dir := Vector3(cos(ang), sin(ang), 0)
			KitMesh.cylinder(st, Vector3(0, 0, z) + dir * 0.07, Vector3(0, 0, z) + dir * 0.15, 0.025, 0.0, 4, Color(0.9, 0.9, 0.9))
	return KitMesh.commit(st)


static func _sword_hilt(two_handed: bool) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var grip: float = 0.28 if two_handed else 0.16
	KitMesh.cylinder(st, Vector3(0, 0, grip * 0.6), Vector3(0, 0, -0.05), 0.025, 0.025, 6, Color.WHITE)
	KitMesh.blob(st, Vector3(0, 0, grip * 0.6 + 0.03), Vector3(0.04, 0.04, 0.04), 2, 0.1, Color(1.4, 1.2, 0.9), 0)
	KitMesh.box(st, Vector3(0, 0, -0.06), Vector3(0.26 if two_handed else 0.2, 0.04, 0.04), Color(1.4, 1.2, 0.9))
	return KitMesh.commit(st)


static func _sword_blade(length: float, two_handed: bool) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var w: float = 0.06 if two_handed else 0.045
	var t: float = 0.012
	var z0: float = -0.08
	var z1: float = -length + 0.1
	var tip := Vector3(0, 0, -length)
	var inside := Vector3(0, 0, (z0 + z1) * 0.5)
	# A diamond cross-section: a centre ridge and two edges.
	for s: float in [1.0, -1.0]:
		var edge0 := Vector3(s * w, 0, z0)
		var edge1 := Vector3(s * w * 0.85, 0, z1)
		for up: float in [1.0, -1.0]:
			var ridge0 := Vector3(0, up * t, z0)
			var ridge1 := Vector3(0, up * t, z1)
			KitMesh.quad(st, ridge0, edge0, edge1, ridge1, Color.WHITE, inside)
			KitMesh.tri(st, ridge1, edge1, tip, Color(1.1, 1.1, 1.1), inside)
	return KitMesh.commit(st)


# --- Shield parts (face toward -Z, strap at the origin). ---

static func _tower() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.box(st, Vector3(0, 0.05, -0.05), Vector3(0.5, 0.85, 0.06), Color(0.9, 0.8, 0.7))
	return KitMesh.commit(st)


static func _tower_rim() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	for y: float in [-0.36, 0.05, 0.46]:
		KitMesh.box(st, Vector3(0, y, -0.085), Vector3(0.52, 0.05, 0.02), Color.WHITE)
	KitMesh.blob(st, Vector3(0, 0.05, -0.1), Vector3(0.07, 0.07, 0.04), 1, 0.1, Color.WHITE, 1)
	return KitMesh.commit(st)


static func _round(radius: float, sides: int, thickness: float) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.cylinder(st, Vector3(0, 0, 0), Vector3(0, 0, -thickness), radius, radius * 0.95, sides, Color(0.9, 0.85, 0.8))
	return KitMesh.commit(st)


static func _boss(radius: float) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.blob(st, Vector3(0, 0, -0.06), Vector3(radius, radius, radius * 0.6), 4, 0.1, Color.WHITE, 1)
	return KitMesh.commit(st)


static func _kite() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var inside := Vector3(0, 0.05, 0.02)
	var top_l := Vector3(-0.26, 0.35, -0.04)
	var top_r := Vector3(0.26, 0.35, -0.04)
	var mid_l := Vector3(-0.24, 0.0, -0.06)
	var mid_r := Vector3(0.24, 0.0, -0.06)
	var tip := Vector3(0, -0.5, -0.04)
	var centre := Vector3(0, 0.05, -0.09)
	for tri: Array in [[top_l, top_r, centre], [top_r, mid_r, centre], [mid_r, tip, centre], [tip, mid_l, centre], [mid_l, top_l, centre]]:
		KitMesh.tri(st, tri[0], tri[1], tri[2], Color(0.95, 0.9, 0.85), inside)
	var back := Vector3(0, 0.05, 0.0)
	var outside := Vector3(0, 0.05, -0.3)
	for tri: Array in [[top_l, top_r, back], [top_r, mid_r, back], [mid_r, tip, back], [tip, mid_l, back], [mid_l, top_l, back]]:
		KitMesh.tri(st, tri[0], tri[1], tri[2], Color(0.6, 0.55, 0.5), outside)
	return KitMesh.commit(st)


static func _spikes() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.cylinder(st, Vector3(0, 0, -0.05), Vector3(0, 0, -0.2), 0.05, 0.0, 6, Color.WHITE)
	for i: int in 6:
		var ang: float = TAU * i / 6.0
		var at := Vector3(cos(ang), sin(ang), 0) * 0.19 + Vector3(0, 0, -0.05)
		KitMesh.cylinder(st, at, at + Vector3(0, 0, -0.08), 0.02, 0.0, 4, Color.WHITE)
	return KitMesh.commit(st)
