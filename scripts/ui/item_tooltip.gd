class_name ItemTooltip
extends PanelContainer
## PoE-style item description box. Hold Alt to also see each affix's
## prefix/suffix type, tier and name.

const AFFIX_COLOR: Color = Color(0.53, 0.53, 1.0)
const LABEL_COLOR: Color = Color(0.6, 0.6, 0.6)
const VALUE_COLOR: Color = Color(0.92, 0.92, 0.92)

var _lines: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.03, 0.94)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 2)
	add_child(_lines)
	visible = false


var _shown_item: Item
var _shown_detailed: bool = false


func show_item(item: Item, detailed: bool = false) -> void:
	# Callers may call this every frame; only rebuild when something changed.
	if visible and item == _shown_item and detailed == _shown_detailed:
		return
	_shown_item = item
	_shown_detailed = detailed
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.free()
	(get_theme_stylebox("panel") as StyleBoxFlat).border_color = item.color()

	_add(item.display_name(), item.color(), 18, true)
	if item.rarity >= Item.Rarity.RARE and not item.base.is_currency():
		_add(item.base.name, item.color(), 18, true)
	_separator()

	if item.base.is_currency():
		_add("Stack Size: %d / %d" % [item.stack, item.base.max_stack], VALUE_COLOR)
		if item.base.description != "":
			_add(item.base.description, LABEL_COLOR)
		_finish()
		return

	var stats: Dictionary = item.base.stats
	if stats.has("phys_min"):
		_add("Physical Damage: %d-%d" % [stats["phys_min"], stats["phys_max"]], VALUE_COLOR)
		_add("Attacks per Second: %.2f" % stats["aps"], VALUE_COLOR)
	for key: String in ["armour", "evasion", "energy_shield", "block"]:
		if stats.has(key):
			var label: String = {"armour": "Armour", "evasion": "Evasion Rating",
				"energy_shield": "Energy Shield", "block": "Chance to Block"}[key]
			_add("%s: %d%s" % [label, stats[key], "%" if key == "block" else ""], VALUE_COLOR)
	if item.sockets > 0:
		_add("Sockets: %s" % "o ".repeat(item.sockets).strip_edges(), VALUE_COLOR)
	_add("Item Level: %d" % item.ilvl, LABEL_COLOR)

	if item.implicit_text() != "":
		_separator()
		_add(item.implicit_text(), AFFIX_COLOR)
	if not item.affixes.is_empty():
		_separator()
		var lines: Array[String] = item.affix_lines()
		var index: int = 0
		for kind: AffixDef.Kind in [AffixDef.Kind.PREFIX, AffixDef.Kind.SUFFIX]:
			for roll: Dictionary in item.affixes:
				var def: AffixDef = item.affix_def(roll)
				if def.kind != kind:
					continue
				var text: String = lines[index]
				index += 1
				if detailed:
					var tier: int = def.tiers.size() - int(roll["tier"])
					text += "   [%s T%d \"%s\"]" % ["P" if kind == AffixDef.Kind.PREFIX else "S",
						tier, def.tiers[roll["tier"]]["name"]]
				_add(text, AFFIX_COLOR)
	_finish()


func _finish() -> void:
	reset_size()
	visible = true


func _add(text: String, color: Color, size: int = 15, centered: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.add_child(label)


func _separator() -> void:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 6)
	_lines.add_child(line)
