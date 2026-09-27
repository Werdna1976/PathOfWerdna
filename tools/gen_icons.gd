extends SceneTree
## Writes the item icons in assets/icons/ as SVG. The shapes are hand-drawn
## path data below; colours come from a small palette per defence type, so
## every armour slot has a matching set. Run with:
##   godot --headless --path <project> -s res://tools/gen_icons.gd
## then import. Icon ids and how bases map to them are in ItemIcons.
## To use hand-painted art instead, drop a PNG or SVG named like the icon id
## (or like a base id, which wins over the type icon) into assets/icons/.

const DIR: String = "res://assets/icons/"
const INK: String = "#0c0a08"

## Defence kind -> [light, dark, accent].
const KINDS: Dictionary = {
	"str": ["#c3c8d0", "#4b5058", "#e8ecf2"],
	"dex": ["#a0714a", "#46301e", "#d6a86a"],
	"int": ["#716ad0", "#252052", "#9ad8ff"],
	"str_dex": ["#cf9c52", "#553a1a", "#f0c880"],
	"str_int": ["#aeb2ba", "#4c5058", "#a3302a"],
	"dex_int": ["#6f8c5c", "#2c3c24", "#d2ba76"],
}
const STEEL: Array[String] = ["#d6dbe2", "#555a62", "#ffffff"]
const WOOD: Array[String] = ["#8a5e38", "#3a2414", "#b88452"]
const GOLD: Array[String] = ["#f2cf6e", "#7a5418", "#fff2b8"]

var _count: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for kind: String in KINDS:
		var c: Array = KINDS[kind]
		_write("chest_" + kind, 64, 96, _chest(kind, c))
		_write("helm_" + kind, 64, 64, _helm(kind, c))
		_write("gloves_" + kind, 64, 64, _gloves(kind, c))
		_write("boots_" + kind, 64, 64, _boots(kind, c))
		_write("shield_" + kind, 64, 96 if kind in ["str", "str_int"] else 64, _shield(kind, c))
	_write("axe_1h", 64, 96, _axe(false))
	_write("axe_2h", 64, 128, _axe(true))
	_write("sword_1h", 64, 96, _sword(false))
	_write("sword_2h", 64, 128, _sword(true))
	_write("mace_1h", 64, 96, _mace(false))
	_write("mace_2h", 64, 128, _mace(true))
	_write("ring", 64, 64, _ring())
	_write("amulet", 64, 64, _amulet())
	_write("charm_bone", 64, 64, _charm_bone())
	_write("charm_iron", 64, 64, _charm_iron())
	_write("charm_gilded", 64, 64, _charm_gilded())
	_write("charm_swift", 64, 64, _charm_swift())
	_write("orb_transmutation", 64, 64, _orb("#4f8ef0", "#10245a", _swirl()))
	_write("orb_augmentation", 64, 64, _orb("#6a7cf8", "#1a1c62", _plus()))
	_write("orb_alteration", 64, 64, _orb("#3fc4c0", "#0c3c44", _cycle()))
	_write("orb_jeweller", 64, 64, _orb("#f0a040", "#5a2808", _sockets()))
	_write("orb_scouring", 64, 64, _orb("#e8eef2", "#5a646c", _waves()))
	_write("orb_regal", 64, 64, _orb("#f4cc58", "#6a4410", _crown()))
	_write("orb_chaos", 64, 64, _orb("#e0502c", "#3a0c06", _chaos_star()))
	_write("orb_ascension", 64, 64, _ascension())
	_write("transmutation_shard", 64, 64, _shard())
	_write("gem_heavy_strike", 64, 64, _active_gem(_hammer()))
	_write("gem_cleave", 64, 64, _active_gem(_crescent()))
	_write("gem_leap_slam", 64, 64, _active_gem(_slam()))
	_write("gem_added_fire", 64, 64, _support_gem("#ff8a2a", "#6a1c04", _flame()))
	_write("gem_melee_splash", 64, 64, _support_gem("#52a8ff", "#0c2a5a", _splash()))
	_write("gem_faster_attacks", 64, 64, _support_gem("#62d86a", "#0c4418", _chevrons()))
	_write("gem_life_leech", 64, 64, _support_gem("#ff4a5a", "#5a0612", _drop()))
	_write("gem_brutality", 64, 64, _support_gem("#b8342a", "#200404", _claws()))
	_write("unknown", 64, 64, _unknown())
	print("gen_icons: wrote %d icons" % _count)
	quit(0)


# --- Output helpers. ---

func _write(icon_id: String, w: int, h: int, body: String) -> void:
	var svg: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n%s\n</svg>\n" \
		% [w * 2, h * 2, w, h, body]
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path(DIR + icon_id + ".svg"), FileAccess.WRITE)
	f.store_string(svg)
	f.close()
	_count += 1


## A top-left to bottom-right shading gradient.
func _grad(id: String, light: String, dark: String) -> String:
	return "<linearGradient id=\"%s\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [id, light, dark]


func _radial(id: String, inner: String, outer: String) -> String:
	return "<radialGradient id=\"%s\" cx=\"0.38\" cy=\"0.34\" r=\"0.7\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></radialGradient>" % [id, inner, outer]


func _path(d: String, fill: String, stroke: String = INK, width: float = 2.5, extra: String = "") -> String:
	return "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\" stroke-linecap=\"round\" %s/>" % [d, fill, stroke, width, extra]


func _line(d: String, stroke: String, width: float = 1.5, extra: String = "") -> String:
	return _path(d, "none", stroke, width, extra)


func _circle(cx: float, cy: float, r: float, fill: String, stroke: String = INK, width: float = 2.0) -> String:
	return "<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [cx, cy, r, fill, stroke, width]


func _defs(content: String) -> String:
	return "<defs>%s</defs>" % content


## `content` drawn only inside the shape `d` (for patterns like chain links).
func _clipped(clip_id: String, d: String, content: String) -> String:
	return "<clipPath id=\"%s\"><path d=\"%s\"/></clipPath><g clip-path=\"url(#%s)\">%s</g>" % [clip_id, d, clip_id, content]


# --- Armour. ---

func _chest(kind: String, c: Array) -> String:
	var s: String = _defs(_grad("g", c[0], c[1]))
	var body: String = "M20 10 L27 6 Q32 13 37 6 L44 10 L56 18 L60 34 L52 38 L50 30 L50 86 Q32 92 14 86 L14 30 L12 38 L4 34 L8 18 Z"
	if kind == "int":
		body = "M20 10 L27 6 Q32 13 37 6 L44 10 L56 18 L60 36 L52 40 L50 32 L56 90 Q32 96 8 90 L14 32 L12 40 L4 36 L8 18 Z"
	s += _path(body, "url(#g)", INK, 3.0)
	match kind:
		"str":
			s += "<ellipse cx=\"12\" cy=\"21\" rx=\"10\" ry=\"8\" fill=\"url(#g)\" stroke=\"%s\" stroke-width=\"2.5\"/>" % INK
			s += "<ellipse cx=\"52\" cy=\"21\" rx=\"10\" ry=\"8\" fill=\"url(#g)\" stroke=\"%s\" stroke-width=\"2.5\"/>" % INK
			s += _line("M32 14 L32 42", c[1], 2.0)
			for y: int in [48, 60, 72]:
				s += _line("M15 %d Q32 %d 49 %d" % [y, y + 4, y], c[1], 2.0)
			s += _line("M20 20 Q32 26 44 20", c[2], 1.5)
		"dex":
			s += _line("M18 32 L18 82 M46 32 L46 82", c[2], 1.5, "stroke-dasharray=\"3 3\"")
			s += _path("M14 62 L50 62 L50 70 L14 70 Z", c[1], INK, 2.0)
			s += _path("M28 61 L36 61 L36 71 L28 71 Z", "#d8b060", INK, 1.5)
			s += _line("M26 10 L32 26 L38 10", c[2], 1.5)
		"int":
			s += _line("M32 16 L32 92", c[2], 3.0)
			s += _line("M32 16 L32 92", "#ffffff", 1.0)
			s += _circle(32, 30, 5.0, c[2], INK, 1.5)
			s += _line("M14 88 Q32 94 50 88", c[2], 2.0)
		"str_dex":
			var scales: String = ""
			for row: int in 9:
				var y: int = 24 + row * 7
				var offset: int = 4 if row % 2 else 0
				for x: int in range(10 + offset, 54, 8):
					scales += _line("M%d %d q4 6 8 0" % [x, y], c[1], 1.4)
			s += _clipped("clip", body, scales)
		"str_int":
			var links: String = ""
			for y: int in range(12, 90, 5):
				for x: int in range(6, 60, 5):
					links += "<circle cx=\"%d\" cy=\"%d\" r=\"1.2\" fill=\"%s\"/>" % [x, y, c[1]]
			s += _clipped("clip", body, links)
			s += _path("M24 28 L40 28 L41 88 Q32 90 23 88 Z", c[2], INK, 2.0)
			s += _path("M28 40 L36 40 L36 48 L28 48 Z", "#e0c070", INK, 1.2)
		"dex_int":
			var quilt: String = ""
			for i: int in range(-4, 7):
				quilt += _line("M%d 0 L%d 96" % [i * 10, 40 + i * 10], c[1], 1.3)
				quilt += _line("M%d 0 L%d 96" % [64 - i * 10, 24 - i * 10], c[1], 1.3)
			s += _clipped("clip", body, quilt)
			s += _path(body, "none", INK, 3.0)
	return s


func _helm(kind: String, c: Array) -> String:
	var s: String = _defs(_grad("g", c[0], c[1]))
	match kind:
		"str":
			s += _path("M14 52 L14 28 Q14 8 32 8 Q50 8 50 28 L50 52 Q32 60 14 52 Z", "url(#g)", INK, 3.0)
			s += _path("M18 29 L46 29 L46 34 L18 34 Z", "#1a1008", INK, 1.5)
			s += _path("M30 34 L34 34 L34 50 L30 50 Z", "#1a1008", INK, 1.2)
			s += _line("M32 9 L32 28", c[2], 1.6)
		"dex":
			s += _path("M8 50 Q6 12 32 8 Q58 12 56 50 L46 54 Q46 28 32 26 Q18 28 18 54 Z", "url(#g)", INK, 3.0)
			s += _path("M18 54 Q18 28 32 26 Q46 28 46 54 Z", "#1a120a", INK, 2.0)
			s += _line("M14 44 Q12 18 32 13", c[2], 1.4, "stroke-dasharray=\"3 3\"")
		"int":
			s += "<ellipse cx=\"32\" cy=\"36\" rx=\"24\" ry=\"10\" fill=\"none\" stroke=\"%s\" stroke-width=\"8\"/>" % INK
			s += "<ellipse cx=\"32\" cy=\"36\" rx=\"24\" ry=\"10\" fill=\"none\" stroke=\"%s\" stroke-width=\"4.5\"/>" % GOLD[0]
			s += _path("M32 34 L38 42 L32 52 L26 42 Z", c[2], INK, 2.0)
			s += _circle(32, 42, 2.0, "#ffffff", "none", 0.0)
		"str_dex":
			s += _path("M6 42 Q8 12 32 12 Q54 12 56 34 L62 46 L44 44 L44 36 L20 36 L20 44 Z", "url(#g)", INK, 3.0)
			s += _path("M20 36 L44 36 L44 40 L20 40 Z", "#1a1008", INK, 1.5)
			s += _line("M14 24 Q32 16 50 24", c[2], 1.5)
		"str_int":
			var hood: String = "M10 56 Q6 12 32 8 Q58 12 54 56 Z"
			s += _path(hood, "url(#g)", INK, 3.0)
			var links: String = ""
			for y: int in range(10, 58, 5):
				for x: int in range(6, 60, 5):
					links += "<circle cx=\"%d\" cy=\"%d\" r=\"1.1\" fill=\"%s\"/>" % [x, y, c[1]]
			s += _clipped("clip", hood, links)
			s += "<ellipse cx=\"32\" cy=\"36\" rx=\"11\" ry=\"14\" fill=\"#1a120a\" stroke=\"%s\" stroke-width=\"2\"/>" % INK
		"dex_int":
			s += _path("M12 18 Q32 6 52 18 L50 40 Q32 60 14 40 Z", "url(#g)", INK, 3.0)
			s += _path("M18 26 Q24 20 29 27 Q24 31 18 26 Z", "#0a0806", INK, 1.2)
			s += _path("M46 26 Q40 20 35 27 Q40 31 46 26 Z", "#0a0806", INK, 1.2)
			s += _line("M32 32 L32 44", c[1], 2.0)
			s += _line("M12 22 L4 30 M52 22 L60 30", c[2], 2.0)
	return s


func _gloves(kind: String, c: Array) -> String:
	var s: String = _defs(_grad("g", c[0], c[1]))
	var hand: String = "M18 50 L18 34 L12 26 Q10 20 16 19 L22 26 L22 12 Q22 8 26 8 Q29 8 29 12 L29 24 L30 8 Q30 4 34 4 Q37 4 37 8 L37 24 L38 10 Q38 6 42 6 Q45 6 45 10 L45 26 L46 16 Q46 12 49 12 Q52 12 52 16 L52 40 Q51 46 48 50 Z"
	s += _path(hand, "url(#g)", INK, 2.5)
	s += _path("M15 48 L51 48 L53 60 L13 60 Z", c[1], INK, 2.5)
	match kind:
		"str":
			for x: int in [25, 33, 41, 48]:
				s += _line("M%d 16 L%d 22" % [x, x], c[2], 1.4)
			s += _line("M22 34 L50 34", c[2], 1.5)
			for x: int in [19, 33, 47]:
				s += _circle(x, 54, 1.6, c[2], "none", 0.0)
		"dex", "dex_int":
			s += _line("M20 40 Q34 44 50 40", c[2], 1.3, "stroke-dasharray=\"2.5 2.5\"")
			s += _line("M16 53 L50 53", c[2], 1.3, "stroke-dasharray=\"2.5 2.5\"")
		"int":
			s += _path("M36 30 L40 36 L36 42 L32 36 Z", c[2], INK, 1.2)
			s += _line("M16 53 L50 53", c[2], 1.6)
		"str_dex":
			for row: int in 3:
				for x: int in range(22, 50, 7):
					s += _line("M%d %d q3.5 4 7 0" % [x, 30 + row * 5], c[1], 1.2)
		"str_int":
			for y: int in range(28, 48, 4):
				for x: int in range(21, 51, 4):
					s += "<circle cx=\"%d\" cy=\"%d\" r=\"0.9\" fill=\"%s\"/>" % [x, y, c[1]]
			s += _line("M14 54 L52 54", c[2], 2.2)
	return s


func _boots(kind: String, c: Array) -> String:
	var s: String = _defs(_grad("g", c[0], c[1]))
	s += _path("M20 6 L40 6 L40 36 L54 42 Q61 46 59 54 L59 56 L14 56 L14 50 L20 44 Z", "url(#g)", INK, 2.5)
	s += _path("M13 54 L60 54 L60 60 L13 60 Z", "#20150c", INK, 2.0)
	s += _path("M18 6 L42 6 L42 14 L18 14 Z", c[1], INK, 2.0)
	match kind:
		"str":
			s += _line("M22 26 L38 26 M22 36 L40 36", c[2], 1.5)
			s += _path("M26 18 L34 18 L34 30 L26 30 Z", "none", c[2], 1.3)
		"dex", "dex_int":
			s += _line("M24 18 L36 22 M24 24 L36 28 M24 30 L36 34", c[2], 1.3)
		"int":
			s += _line("M20 44 Q36 38 52 46", c[2], 2.0)
			s += _circle(30, 10, 2.5, c[2], INK, 1.0)
		"str_dex":
			for row: int in 4:
				for x: int in range(22, 40, 6):
					s += _line("M%d %d q3 4 6 0" % [x, 18 + row * 6], c[1], 1.2)
		"str_int":
			for y: int in range(18, 50, 4):
				for x: int in range(22, 40, 4):
					s += "<circle cx=\"%d\" cy=\"%d\" r=\"0.9\" fill=\"%s\"/>" % [x, y, c[1]]
	return s


func _shield(kind: String, c: Array) -> String:
	var s: String = _defs(_grad("g", c[0], c[1]) + _grad("m", STEEL[0], STEEL[1]) + _grad("w", WOOD[0], WOOD[1]))
	match kind:
		"str":
			s += _path("M8 8 L56 8 L56 76 Q32 94 8 76 Z", "url(#w)", INK, 3.0)
			for x: int in [20, 32, 44]:
				s += _line("M%d 9 L%d 84" % [x, x], WOOD[1], 1.5)
			for y: int in [20, 52]:
				s += _path("M8 %d L56 %d L56 %d L8 %d Z" % [y, y, y + 6, y + 6], "url(#m)", INK, 1.5)
			s += _circle(32, 40, 7.0, "url(#m)", INK, 2.0)
		"dex":
			s += _circle(32, 32, 26.0, "url(#g)", INK, 3.0)
			s += _circle(32, 32, 18.0, "none", c[2], 1.5)
			s += _circle(32, 32, 7.0, "url(#m)", INK, 2.0)
		"int":
			s += _circle(32, 32, 28.0, "#d8d0bc", INK, 3.0)
			s += _circle(32, 32, 22.0, "none", "#8a8070", 1.5)
			# A glowing crescent moon with three stars.
			s += _path("M38 14 Q20 18 22 34 Q24 50 42 50 Q26 44 28 32 Q30 20 38 14 Z", c[2], INK, 1.5)
			for p: Vector2 in [Vector2(40, 26), Vector2(44, 36), Vector2(36, 40)]:
				s += _circle(p.x, p.y, 1.8, c[2], "none", 0.0)
		"str_dex":
			s += _circle(32, 32, 28.0, "url(#w)", INK, 3.0)
			for x: int in [18, 27, 37, 46]:
				s += _line("M%d 6 L%d 58" % [x, x], WOOD[1], 1.3)
			s += _circle(32, 32, 28.0, "none", c[0], 4.0)
			s += _circle(32, 32, 8.0, "url(#g)", INK, 2.0)
		"str_int":
			s += _path("M8 10 L56 10 L54 44 Q46 72 32 90 Q18 72 10 44 Z", "url(#g)", INK, 3.0)
			# Two stacked chevrons.
			s += _path("M14 22 L32 38 L50 22 L50 32 L32 48 L14 32 Z", c[2], INK, 1.5)
			s += _path("M18 44 L32 56 L46 44 L46 52 L32 64 L18 52 Z", c[2], INK, 1.5)
		"dex_int":
			for i: int in 8:
				var a: float = TAU * i / 8.0
				var tip := Vector2(32, 32) + Vector2(cos(a), sin(a)) * 31.0
				var l := Vector2(32, 32) + Vector2(cos(a - 0.2), sin(a - 0.2)) * 22.0
				var r := Vector2(32, 32) + Vector2(cos(a + 0.2), sin(a + 0.2)) * 22.0
				s += _path("M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" % [l.x, l.y, tip.x, tip.y, r.x, r.y], "url(#m)", INK, 1.5)
			s += _circle(32, 32, 23.0, "url(#g)", INK, 3.0)
			s += _path("M32 20 L38 32 L32 44 L26 32 Z", "url(#m)", INK, 1.5)
	return s


# --- Weapons. ---

func _axe(two_handed: bool) -> String:
	var s: String = _defs(_grad("m", STEEL[0], STEEL[1]) + _grad("w", WOOD[0], WOOD[1]))
	var bottom: int = 124 if two_handed else 92
	s += _path("M29 18 L35 18 L35 %d L29 %d Z" % [bottom, bottom], "url(#w)", INK, 2.5)
	s += _path("M35 12 Q60 4 60 40 Q48 34 35 36 Z", "url(#m)", INK, 2.5)
	s += _line("M40 11 Q58 8 57 36", STEEL[2], 1.5)
	if two_handed:
		s += _path("M29 12 Q4 4 4 40 Q16 34 29 36 Z", "url(#m)", INK, 2.5)
		s += _line("M24 11 Q6 8 7 36", STEEL[2], 1.5)
	else:
		s += _path("M29 18 L22 22 L29 28 Z", "url(#m)", INK, 2.0)
	s += _path("M28 10 L36 10 L36 40 L28 40 Z", "url(#m)", INK, 2.0)
	for y: int in range(bottom - 20, bottom - 2, 5):
		s += _line("M29 %d L35 %d" % [y, y + 3], "#1a0e06", 1.5)
	return s


func _sword(two_handed: bool) -> String:
	var s: String = _defs(_grad("m", STEEL[0], STEEL[1]) + _grad("gd", GOLD[0], GOLD[1]))
	var guard_y: int = 94 if two_handed else 68
	var half: int = 6 if two_handed else 5
	s += _path("M%d %d L%d 16 L32 4 L%d 16 L%d %d Z" % [32 - half, guard_y, 32 - half, 32 + half, 32 + half, guard_y], "url(#m)", INK, 2.5)
	s += _line("M32 14 L32 %d" % (guard_y - 4), STEEL[1], 1.5)
	s += _line("M%d 18 L%d %d" % [33 - half + 1, 33 - half + 1, guard_y - 2], STEEL[2], 1.0)
	var wide: int = 18 if two_handed else 13
	s += _path("M%d %d L%d %d L%d %d L%d %d Z" % [32 - wide, guard_y, 32 + wide, guard_y, 32 + wide - 2, guard_y + 6, 32 - wide + 2, guard_y + 6], "url(#gd)", INK, 2.0)
	var grip_end: int = guard_y + (26 if two_handed else 18)
	s += _path("M29 %d L35 %d L35 %d L29 %d Z" % [guard_y + 6, guard_y + 6, grip_end, grip_end], "#4a2c18", INK, 2.0)
	for y: int in range(guard_y + 9, grip_end, 4):
		s += _line("M29 %d L35 %d" % [y, y + 2], "#2a180c", 1.2)
	s += _circle(32, grip_end + 4, 4.5, "url(#gd)", INK, 2.0)
	return s


func _mace(two_handed: bool) -> String:
	var s: String = _defs(_grad("m", STEEL[0], STEEL[1]) + _grad("w", WOOD[0], WOOD[1]))
	var bottom: int = 124 if two_handed else 92
	s += _path("M29 30 L35 30 L35 %d L29 %d Z" % [bottom, bottom], "url(#w)", INK, 2.5)
	if two_handed:
		s += _path("M10 8 L54 8 L54 34 L10 34 Z", "url(#m)", INK, 3.0)
		s += _path("M6 12 L10 12 L10 30 L6 30 Z M54 12 L58 12 L58 30 L54 30 Z", "url(#m)", INK, 2.0)
		s += _line("M10 16 L54 16 M10 26 L54 26", STEEL[1], 1.5)
		s += _line("M13 11 L50 11", STEEL[2], 1.2)
	else:
		for i: int in 6:
			var a: float = TAU * i / 6.0 + 0.26
			var tip := Vector2(32, 22) + Vector2(cos(a), sin(a)) * 18.0
			var l := Vector2(32, 22) + Vector2(cos(a - 0.35), sin(a - 0.35)) * 9.0
			var r := Vector2(32, 22) + Vector2(cos(a + 0.35), sin(a + 0.35)) * 9.0
			s += _path("M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" % [l.x, l.y, tip.x, tip.y, r.x, r.y], "url(#m)", INK, 1.8)
		s += _circle(32, 22, 10.0, "url(#m)", INK, 2.5)
		s += _circle(29, 19, 3.0, STEEL[2], "none", 0.0)
	for y: int in range(bottom - 20, bottom - 2, 5):
		s += _line("M29 %d L35 %d" % [y, y + 3], "#1a0e06", 1.5)
	return s


# --- Jewellery and charms. ---

func _ring() -> String:
	var s: String = _defs(_grad("gd", GOLD[0], GOLD[1]) + _radial("gem", "#ffb0a0", "#a0100c"))
	s += "<ellipse cx=\"32\" cy=\"40\" rx=\"18\" ry=\"15\" fill=\"none\" stroke=\"%s\" stroke-width=\"10\"/>" % INK
	s += "<ellipse cx=\"32\" cy=\"40\" rx=\"18\" ry=\"15\" fill=\"none\" stroke=\"url(#gd)\" stroke-width=\"6\"/>"
	s += _path("M22 22 L42 22 L38 30 L26 30 Z", "url(#gd)", INK, 2.0)
	s += _path("M32 6 L42 16 L32 26 L22 16 Z", "url(#gem)", INK, 2.0)
	s += _line("M27 14 L32 9", "#ffffff", 1.5)
	return s


func _amulet() -> String:
	var s: String = _defs(_grad("gd", GOLD[0], GOLD[1]) + _radial("gem", "#b0ffd8", "#0c6a3c"))
	s += _line("M8 6 Q32 46 56 6", INK, 5.0)
	s += _line("M8 6 Q32 46 56 6", GOLD[0], 2.5, "stroke-dasharray=\"4 2\"")
	s += _path("M32 26 L39 34 Q45 42 39 51 L32 60 L25 51 Q19 42 25 34 Z", "url(#gd)", INK, 2.5)
	s += _path("M32 33 L36 38 Q40 43 36 48 L32 54 L28 48 Q24 43 28 38 Z", "url(#gem)", INK, 1.5)
	s += _circle(29.5, 40, 1.8, "#ffffff", "none", 0.0)
	return s


func _charm_bone() -> String:
	var s: String = _defs(_grad("b", "#f2ead2", "#8a7c5a"))
	s += _line("M32 4 L32 12", "#6a4a2a", 2.5)
	s += _path("M18 30 Q18 10 32 10 Q46 10 46 30 L42 38 L42 48 L22 48 L22 38 Z", "url(#b)", INK, 2.5)
	s += _path("M23 26 Q27 21 30 27 Q27 32 23 26 Z M41 26 Q37 21 34 27 Q37 32 41 26 Z", "#1a120a", INK, 1.0)
	s += _path("M30 34 L32 30 L34 34 Z", "#1a120a", INK, 1.0)
	s += _line("M26 42 L26 48 M30 42 L30 48 M34 42 L34 48 M38 42 L38 48", "#5a4a30", 1.2)
	s += _line("M10 56 L54 50 M10 50 L54 56", "#e8dcc0", 4.0)
	return s


func _charm_iron() -> String:
	var s: String = _defs(_grad("i", "#8a8e94", "#2a2c30"))
	s += _line("M32 4 L32 10", "#6a4a2a", 2.5)
	s += _circle(32, 34, 24.0, "url(#i)", INK, 3.0)
	s += _path("M22 24 L42 24 L42 44 L22 44 Z", "none", "#1a1c1e", 2.5)
	for p: Vector2 in [Vector2(22, 24), Vector2(42, 24), Vector2(22, 44), Vector2(42, 44)]:
		s += _circle(p.x, p.y, 2.5, "#c0c4ca", INK, 1.0)
	s += _line("M22 24 L42 44 M42 24 L22 44", "#50545a", 1.5)
	return s


func _charm_gilded() -> String:
	var s: String = _defs(_grad("gd", GOLD[0], GOLD[1]))
	s += _line("M32 4 L32 10", "#6a4a2a", 2.5)
	s += _circle(32, 34, 24.0, "url(#gd)", INK, 3.0)
	s += _circle(32, 34, 18.0, "none", GOLD[1], 1.5)
	var pts: Array[String] = []
	for i: int in 10:
		var a: float = -PI * 0.5 + TAU * i / 10.0
		var r: float = 13.0 if i % 2 == 0 else 5.5
		pts.append("%.1f %.1f" % [32.0 + cos(a) * r, 34.0 + sin(a) * r])
	s += _path("M" + " L".join(pts) + " Z", GOLD[2], INK, 1.5)
	return s


func _charm_swift() -> String:
	var s: String = _defs(_grad("f", "#d8fff0", "#3a8a78"))
	s += _path("M14 56 Q16 22 48 6 Q46 34 14 56 Z", "url(#f)", INK, 2.5)
	s += _line("M14 56 Q28 32 46 9", "#1e4a40", 1.8)
	for i: int in 5:
		var t: float = 0.25 + i * 0.13
		var x: float = lerpf(18.0, 42.0, t)
		var y: float = lerpf(50.0, 14.0, t)
		s += _line("M%.1f %.1f l8 2" % [x, y], "#1e4a40", 1.2)
	s += _line("M10 60 L18 50", "#6a4a2a", 2.5)
	return s


# --- Currency. ---

func _orb(light: String, dark: String, symbol: String) -> String:
	var s: String = _defs(_radial("o", light, dark) + _radial("h", "#ffffff", light))
	s += _circle(32, 32, 26.0, "url(#o)", INK, 3.0)
	s += "<ellipse cx=\"24\" cy=\"20\" rx=\"8\" ry=\"5\" fill=\"#ffffff\" opacity=\"0.35\"/>"
	s += symbol
	return s


func _swirl() -> String:
	return _line("M32 32 m0 -2 a4 4 0 1 1 -4 4 a8 8 0 1 1 8 -8 a12 12 0 1 1 -12 12", "#ffffff", 2.5)


func _plus() -> String:
	return _path("M28 18 L36 18 L36 28 L46 28 L46 36 L36 36 L36 46 L28 46 L28 36 L18 36 L18 28 L28 28 Z", "#e8eeff", INK, 1.5)


func _cycle() -> String:
	var s: String = _line("M20 30 A12 12 0 0 1 42 24", "#e8fffc", 3.0)
	s += _path("M42 16 L46 26 L36 26 Z", "#e8fffc", "none", 0.0)
	s += _line("M44 34 A12 12 0 0 1 22 40", "#e8fffc", 3.0)
	s += _path("M22 48 L18 38 L28 38 Z", "#e8fffc", "none", 0.0)
	return s


func _sockets() -> String:
	var s: String = ""
	for p: Vector2 in [Vector2(32, 21), Vector2(22, 38), Vector2(42, 38)]:
		s += _circle(p.x, p.y, 6.0, "#2a1004", "#fff0d0", 2.0)
	s += _line("M32 27 L24 33 M32 27 L40 33 M28 38 L36 38", "#fff0d0", 1.5)
	return s


func _waves() -> String:
	var s: String = ""
	for y: int in [24, 32, 40]:
		s += _line("M16 %d q4 -5 8 0 t8 0 t8 0 t8 0" % y, "#3a5a78", 2.5)
	return s


func _crown() -> String:
	return _path("M16 42 L14 22 L24 32 L32 18 L40 32 L50 22 L48 42 Z", "#fff0b0", INK, 2.0) \
		+ _path("M16 42 L48 42 L48 47 L16 47 Z", "#fff0b0", INK, 2.0)


func _chaos_star() -> String:
	var s: String = ""
	for i: int in 8:
		var a: float = TAU * i / 8.0
		var tip := Vector2(32, 32) + Vector2(cos(a), sin(a)) * 18.0
		s += _line("M32 32 L%.1f %.1f" % [tip.x, tip.y], "#ffe0a0", 2.5)
		var head_l := tip + Vector2(cos(a + 2.6), sin(a + 2.6)) * 5.0
		var head_r := tip + Vector2(cos(a - 2.6), sin(a - 2.6)) * 5.0
		s += _line("M%.1f %.1f L%.1f %.1f L%.1f %.1f" % [head_l.x, head_l.y, tip.x, tip.y, head_r.x, head_r.y], "#ffe0a0", 2.0)
	s += _circle(32, 32, 5.0, "#3a0c06", "#ffe0a0", 2.0)
	return s


func _ascension() -> String:
	var s: String = _defs(_radial("o", "#e2a8ff", "#2a0a4a"))
	for i: int in 12:
		var a: float = TAU * i / 12.0
		var inner := Vector2(32, 32) + Vector2(cos(a), sin(a)) * 27.0
		var outer := Vector2(32, 32) + Vector2(cos(a), sin(a)) * 31.0
		s += _line("M%.1f %.1f L%.1f %.1f" % [inner.x, inner.y, outer.x, outer.y], GOLD[0], 2.0)
	s += _circle(32, 32, 25.0, "url(#o)", INK, 3.0)
	s += "<ellipse cx=\"24\" cy=\"20\" rx=\"8\" ry=\"5\" fill=\"#ffffff\" opacity=\"0.35\"/>"
	for y: int in [40, 31, 22]:
		s += _line("M22 %d L32 %d L42 %d" % [y, y - 8, y], GOLD[0], 3.0)
	return s


func _shard() -> String:
	var s: String = _defs(_grad("c", "#b8d8ff", "#1c3c8a"))
	s += _path("M28 8 L38 22 L34 54 L24 40 Z", "url(#c)", INK, 2.5)
	s += _path("M40 26 L50 34 L44 52 L38 44 Z", "url(#c)", INK, 2.0)
	s += _path("M18 30 L24 44 L18 54 L12 42 Z", "url(#c)", INK, 2.0)
	s += _line("M29 12 L33 24", "#ffffff", 1.5)
	return s


# --- Gems. ---

func _active_gem(symbol: String) -> String:
	var s: String = _defs(_grad("r", "#ff6a52", "#5a0a06"))
	s += _path("M32 4 L54 18 L54 46 L32 60 L10 46 L10 18 Z", "url(#r)", INK, 3.0)
	s += _line("M32 4 L32 14 M54 18 L44 22 M54 46 L44 42 M32 60 L32 50 M10 46 L20 42 M10 18 L20 22", "#ffb0a0", 1.2)
	s += _path("M32 14 L44 22 L44 42 L32 50 L20 42 L20 22 Z", "none", "#ffb0a0", 1.2)
	s += symbol
	return s


func _support_gem(light: String, dark: String, symbol: String) -> String:
	var s: String = _defs(_radial("r", light, dark))
	s += _circle(32, 32, 26.0, "url(#r)", INK, 3.0)
	s += _circle(32, 32, 20.0, "none", "#ffffff", 1.2)
	s += "<ellipse cx=\"24\" cy=\"20\" rx=\"7\" ry=\"4\" fill=\"#ffffff\" opacity=\"0.3\"/>"
	s += symbol
	return s


func _hammer() -> String:
	return _path("M20 22 L40 22 L40 32 L20 32 Z", "#fff4f0", INK, 1.5) + _path("M28 32 L32 32 L32 46 L28 46 Z", "#fff4f0", INK, 1.5) \
		+ _line("M42 20 L48 16 M42 27 L50 27 M42 34 L48 38", "#fff4f0", 2.0)


func _crescent() -> String:
	return _path("M18 40 Q20 18 44 16 Q30 24 30 44 Z", "#fff4f0", INK, 1.5) + _line("M22 44 L46 20", "#fff4f0", 1.2, "stroke-dasharray=\"2 3\"")


func _slam() -> String:
	return _path("M28 14 L36 14 L36 30 L42 30 L32 42 L22 30 L28 30 Z", "#fff4f0", INK, 1.5) \
		+ _line("M18 48 L46 48 M20 44 L16 40 M44 44 L48 40", "#fff4f0", 2.0)


func _flame() -> String:
	return _path("M32 12 Q44 26 40 38 Q46 34 44 28 Q52 40 42 48 Q32 54 22 48 Q14 40 22 28 Q22 36 28 38 Q22 24 32 12 Z", "#fff2c0", INK, 1.5)


func _splash() -> String:
	var s: String = _circle(32, 34, 5.0, "#e8f4ff", INK, 1.5)
	for i: int in 5:
		var a: float = -PI * 0.5 + TAU * i / 5.0
		var p := Vector2(32, 34) + Vector2(cos(a), sin(a)) * 13.0
		s += _circle(p.x, p.y, 3.0, "#e8f4ff", INK, 1.2)
	return s


func _chevrons() -> String:
	return _path("M18 20 L30 32 L18 44 L14 40 L22 32 L14 24 Z M32 20 L44 32 L32 44 L28 40 L36 32 L28 24 Z", "#eaffea", INK, 1.5)


func _drop() -> String:
	return _path("M32 14 Q44 30 44 38 Q44 50 32 50 Q20 50 20 38 Q20 30 32 14 Z", "#ffe0e4", INK, 1.5)


func _claws() -> String:
	return _line("M20 18 Q26 32 22 46 M30 16 Q36 32 32 48 M40 18 Q46 32 42 46", "#ffd8d0", 3.5)


func _unknown() -> String:
	return _circle(32, 32, 24.0, "#3a3430", INK, 3.0) + _path("M26 24 Q26 16 32 16 Q40 16 40 24 Q40 30 32 32 L32 38", "none", "#c8c0b0", 4.0) \
		+ _circle(32, 46, 2.5, "#c8c0b0", "none", 0.0)
