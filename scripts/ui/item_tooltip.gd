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
var _shown_skill_key: String = ""
var _shown_footer: String = ""


## Shows a skill (from the skill bar) with its damage estimate.
func show_skill(skill: SkillInstance, estimate: Dictionary) -> void:
	# Callers may call this every frame; only rebuild when the numbers change.
	var key: String = "%s|%s|%.2f" % [skill.gem_item, skill.display_name, estimate["dps"]]
	if visible and key == _shown_skill_key:
		return
	_shown_skill_key = key
	_shown_item = null
	_clear()
	(get_theme_stylebox("panel") as StyleBoxFlat).border_color = Item.GEM_COLOR
	_add(skill.display_name, Item.GEM_COLOR, 18, true)
	if not skill.supports.is_empty():
		_add("Supported by: %s" % ", ".join(PackedStringArray(skill.supports.map(
			func(s: SupportGem) -> String: return s.short_name))), LABEL_COLOR)
	_separator()
	_add_skill_numbers(skill, estimate)
	_finish()


## `skill_estimate` is {skill, estimate} for an active gem socketed in equipped gear.
## `footer` is an extra line at the bottom (e.g. a vendor price).
func show_item(item: Item, detailed: bool = false, skill_estimate: Dictionary = {}, footer: String = "") -> void:
	# Callers may call this every frame; only rebuild when something changed.
	if visible and item == _shown_item and detailed == _shown_detailed and footer == _shown_footer:
		return
	_shown_footer = footer
	_shown_item = item
	_shown_detailed = detailed
	_shown_skill_key = ""
	_clear()
	(get_theme_stylebox("panel") as StyleBoxFlat).border_color = item.color()

	_add(item.display_name(), item.color(), 18, true)
	if item.rarity >= Item.Rarity.RARE and not item.base.is_currency():
		_add(item.base.name, item.color(), 18, true)
	_separator()
	_add(item.base.type_name(), LABEL_COLOR)

	if item.base.is_gem():
		_show_gem(item)
		if not skill_estimate.is_empty():
			_separator()
			_add("With your gear and linked supports:", LABEL_COLOR, 13)
			_add_skill_numbers(skill_estimate["skill"], skill_estimate["estimate"])
		_finish()
		return

	if item.base.is_currency():
		_add("Stack Size: %d / %d" % [item.stack, item.base.max_stack], VALUE_COLOR)
		if item.base.description != "":
			_add(item.base.description, LABEL_COLOR)
		if Crafting.is_orb(item):
			_add("Right click to use, then left click an item. Hold Shift to keep using.", LABEL_COLOR, 12)
		_finish()
		return

	var stats: Dictionary = item.base.stats
	if stats.has("phys_min"):
		var damage: Vector2 = item.weapon_damage()
		_add("Physical Damage: %d-%d" % [damage.x, damage.y], _local_color(item, &"local_phys_percent", &"local_added_phys"))
		_add("Attacks per Second: %.2f" % stats["aps"], VALUE_COLOR)
	for key: StringName in [&"armour", &"evasion", &"energy_shield"]:
		var value: int = item.local_defence(key)
		if value > 0:
			var label: String = {&"armour": "Armour", &"evasion": "Evasion Rating", &"energy_shield": "Energy Shield"}[key]
			_add("%s: %d" % [label, value], _local_color(item, &"local_defences_percent", key))
	if stats.has("block"):
		_add("Chance to Block: %d%%" % stats["block"], VALUE_COLOR)
	if item.sockets > 0:
		var names: PackedStringArray = []
		for i: int in item.sockets:
			var g: Item = item.socketed_gem(i)
			names.append("[%s]" % ((g.gem as GemData).short_name if g != null else "  "))
		_add("Sockets: %s" % " ".join(names), VALUE_COLOR)
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


func _clear() -> void:
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.free()


func _add_skill_numbers(skill: SkillInstance, e: Dictionary) -> void:
	_add("Damage per Hit: %d-%d" % [roundi(e["hit_min"]), roundi(e["hit_max"])], VALUE_COLOR)
	_add("Critical Strike: %.1f%% for %d%% damage" % [e["crit_chance"], e["crit_multiplier"]], VALUE_COLOR)
	_add("Uses per Second: %.2f%s" % [e["uses_per_second"], " (cooldown %.1fs)" % skill.cooldown if skill.cooldown > 0.0 else ""], VALUE_COLOR)
	if skill.hits_all:
		_add("Area Radius: %.1f" % e["area_radius"], VALUE_COLOR)
	if skill.splash_radius > 0.0:
		_add("Splash: %d%% damage within %.1f" % [skill.splash_damage_percent, skill.splash_radius], VALUE_COLOR)
	if skill.leech_percent > 0.0:
		_add("Life Leeched per Hit: %.1f" % e["leech_per_hit"], VALUE_COLOR)
	_add("Mana Cost: %d" % skill.mana_cost, VALUE_COLOR)
	_add("Damage per Second: %.1f%s" % [e["dps"], " (per target)" if skill.hits_all else ""], AFFIX_COLOR, 16)


func _show_gem(item: Item) -> void:
	var gem: GemData = item.gem
	var is_support: bool = gem is SupportGem
	_add("Support Gem" if is_support else "Active Skill Gem", LABEL_COLOR)
	_add(", ".join(PackedStringArray(gem.tags.map(func(t: StringName) -> String: return String(t).capitalize()))), LABEL_COLOR)
	_add("Level: %d" % item.gem_level, VALUE_COLOR)
	_separator()
	if is_support:
		var support: SupportGem = gem as SupportGem
		_add("Mana Cost Multiplier: %d%%" % roundi(support.mana_multiplier * 100.0), VALUE_COLOR)
		_add("Supports: %s skills" % ", ".join(PackedStringArray(support.supported_tags.map(
			func(t: StringName) -> String: return String(t).capitalize()))), VALUE_COLOR)
		_separator()
		for line: String in support.effect_lines:
			_add(line, AFFIX_COLOR)
	else:
		var skill: SkillGem = gem as SkillGem
		_add("Mana Cost: %d" % skill.mana_cost, VALUE_COLOR)
		if skill.cooldown > 0.0:
			_add("Cooldown: %.1f sec" % skill.cooldown, VALUE_COLOR)
		_add("Deals %d%% of Base Damage" % roundi(skill.damage_multiplier * 100.0), AFFIX_COLOR)
	_separator()
	_add(gem.description, LABEL_COLOR)
	_add("Place into an item socket to use it. Supports affect active gems in the same item.", LABEL_COLOR, 12)


## Values raised by the item's own mods show in the affix colour, as in PoE.
func _local_color(item: Item, stat_a: StringName, stat_b: StringName) -> Color:
	return AFFIX_COLOR if item.stat_total(stat_a) > 0 or item.stat_total(stat_b) > 0 else VALUE_COLOR


func _finish() -> void:
	if _shown_footer != "" and _shown_item != null:
		_separator()
		_add(_shown_footer, Item.CURRENCY_COLOR, 14)
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
