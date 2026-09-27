class_name CharacterSheet
extends PanelContainer
## Character stats panel (toggle with C). Refreshes whenever gear changes.
## Stats marked * are rolled on gear but not implemented in combat yet.

const HEADER_COLOR: Color = Color(0.85, 0.78, 0.6)
const LABEL_COLOR: Color = Color(0.65, 0.62, 0.56)
const VALUE_COLOR: Color = Color(0.95, 0.95, 0.95)
const SECTIONS: Array = [
	["Attributes", [
		["Strength", &"strength", "%d"], ["Dexterity", &"dexterity", "%d"], ["Intelligence", &"intelligence", "%d"]]],
	["Offence", [
		["Physical Damage", &"phys", ""], ["Added Fire Damage", &"fire", ""],
		["Attacks per Second", &"attacks_per_second", "%.2f"], ["Critical Strike Chance", &"crit_chance", "%.1f%%"],
		["Critical Strike Multiplier", &"crit_multiplier", "%d%%"], ["Accuracy Rating", &"accuracy", "%d"],
		["Area of Effect", &"area_of_effect", "+%d%%"], ["Life Gained per Hit", &"life_on_hit", "%d"],
		["Culling Strike", &"culling_strike", "below %d%%"],
		["Chance to Bleed *", &"bleed_chance", "%d%%"], ["Stun Duration *", &"stun_duration", "+%d%%"]]],
	["Defence", [
		["Life", &"max_life", "%d"], ["Mana", &"max_mana", "%d"], ["Energy Shield", &"energy_shield", "%d"],
		["Armour", &"armour", "%d"], ["Evasion Rating", &"evasion", "%d"], ["Chance to Block", &"block_chance", "%d%%"],
		["Fire Resistance", &"fire_resistance", "res"], ["Cold Resistance", &"cold_resistance", "res"],
		["Lightning Resistance", &"lightning_resistance", "res"], ["Chaos Resistance", &"chaos_resistance", "res"],
		["Life Regeneration", &"life_regen", "%.1f/s"], ["Mana Regeneration", &"mana_regen", "%.1f/s"],
		["Life Recoup", &"life_recoup", "%d%%"]]],
	["Utility", [
		["Movement Speed", &"movement_speed_increase", "+%d%%"], ["Item Rarity", &"item_rarity", "+%d%%"],
		["Item Quantity", &"item_quantity", "+%d%%"], ["Cooldown Recovery", &"cooldown_recovery", "+%d%%"],
		["Potion Charges on Kill", &"potion_charges_on_kill", "+%d"], ["Mana on Kill", &"mana_on_kill", "%d"],
		["Avoid Stun *", &"avoid_stun", "%d%%"], ["Avoid Elemental Ailments *", &"avoid_ailments", "%d%%"],
		["Explode on Kill *", &"explode_on_kill_chance", "%d%%"], ["Onslaught on Kill *", &"onslaught_on_kill_chance", "%d%%"]]],
]

var _stats: CharacterStats
var _skill_bar: SkillBar
var _melee: MeleeAttack
var _rows: VBoxContainer


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.96)
	style.border_color = Color(0.35, 0.3, 0.22)
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(300.0, 0.0)
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = 20.0
	offset_top = -380.0
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	add_child(_rows)
	visible = false


func bind(player: Node) -> void:
	_stats = player.get_node("CharacterStats") as CharacterStats
	_skill_bar = player.get_node("SkillBar") as SkillBar
	_melee = player.get_node("Melee") as MeleeAttack
	_stats.recomputed.connect(_refresh)
	_skill_bar.slots_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character"):
		visible = not visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and visible:
		visible = false


func _refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	_add_row("Werdna", "Warrior", HEADER_COLOR, 18)
	# Damage only means something for a skill, so lead with each slotted skill's DPS.
	_add_row("Skills (damage per second)", "", HEADER_COLOR, 15)
	for slot: int in SkillBar.SLOT_COUNT:
		var skill: SkillInstance = _skill_bar.gem_in(slot)
		if skill != null:
			var e: Dictionary = _melee.estimate(skill, _skill_bar.cooldown_rate)
			_add_row("  %s  %s" % [SkillBar.SLOT_KEYS[slot], skill.display_name], "%.1f" % e["dps"], LABEL_COLOR, 13)
	for section: Array in SECTIONS:
		_add_row(section[0], "", HEADER_COLOR, 15)
		for entry: Array in section[1]:
			var text: String = _format(entry[1], entry[2])
			if text != "":
				_add_row("  " + entry[0], text, LABEL_COLOR, 13)
	reset_size()


func _format(key: StringName, fmt: String) -> String:
	var v: Dictionary = _stats.values
	match fmt:
		"":
			var lo: float = v.get(StringName(String(key) + "_min"), 0.0)
			var hi: float = v.get(StringName(String(key) + "_max"), 0.0)
			return "%d-%d" % [lo, hi] if hi > 0.0 else ""
		"res":
			var value: float = v.get(key, 0.0)
			var capped: float = minf(value, Defenses.RESIST_CAP)
			return "%d%%" % capped if value <= Defenses.RESIST_CAP else "%d%% (%d%%)" % [capped, value]
	var value: float = v.get(key, 0.0)
	# Hide optional stats the character doesn't have, but always show the core ones.
	var always: Array[StringName] = [&"strength", &"dexterity", &"intelligence", &"attacks_per_second",
		&"crit_chance", &"crit_multiplier", &"accuracy", &"max_life", &"max_mana", &"armour", &"evasion",
		&"energy_shield", &"mana_regen"]
	if value == 0.0 and not always.has(key):
		return ""
	return fmt % value


func _add_row(label: String, value: String, color: Color, font_size: int) -> void:
	var row := HBoxContainer.new()
	var left := Label.new()
	left.text = label
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_color_override("font_color", color)
	left.add_theme_font_size_override("font_size", font_size)
	row.add_child(left)
	var right := Label.new()
	right.text = value
	right.add_theme_color_override("font_color", VALUE_COLOR)
	right.add_theme_font_size_override("font_size", font_size)
	row.add_child(right)
	_rows.add_child(row)
