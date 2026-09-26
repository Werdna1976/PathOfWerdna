class_name Hud
extends CanvasLayer
## Player HUD along the bottom of the screen:
## - life bar and potion slots (bottom-left), mana bar (bottom-right)
## - skill bar (bottom-centre); click a slot to cycle its gem
## - a short warning line ("Not enough mana") and the death message
## Built in code; placeholder until real life/mana globes and art.

const BAR_SIZE: Vector2 = Vector2(300.0, 24.0)
const SLOT_SIZE: Vector2 = Vector2(64.0, 64.0)
const POTION_SIZE: Vector2 = Vector2(34.0, 56.0)
const MARGIN: float = 24.0
const MESSAGE_TIME: float = 1.2

var _life: Dictionary
var _mana: Dictionary
var _potion_fills: Array[ColorRect] = []
var _slot_names: Array[Label] = []
var _slot_costs: Array[Label] = []
var _slot_cooldowns: Array[ColorRect] = []
var _message: Label
var _message_time: float = 0.0
var _death_label: Label

var _skill_bar: SkillBar
var _potion_belt: PotionBelt


func _ready() -> void:
	_life = _make_bar(Color(0.62, 0.08, 0.07), false)
	_mana = _make_bar(Color(0.12, 0.25, 0.72), true)

	_message = _make_label(20, Color(0.95, 0.85, 0.6))
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.position.y -= MARGIN + SLOT_SIZE.y + 36.0
	_message.visible = false
	add_child(_message)

	_death_label = _make_label(44, Color(0.75, 0.1, 0.08))
	_death_label.text = "Werdna has fallen..."
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.visible = false
	add_child(_death_label)

	_bind_player.call_deferred()


func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var health: Health = Health.of(player)
	var mana: Mana = Mana.of(player)
	if health == null or mana == null:
		push_warning("Hud: player is missing Health or Mana.")
		return
	health.changed.connect(_on_life_changed)
	health.died.connect(func() -> void: _death_label.visible = true)
	mana.changed.connect(func(c: float, m: float) -> void: _set_bar(_mana, "Mana", c, m))
	_on_life_changed(health.current, health.max_health)
	_set_bar(_mana, "Mana", mana.current, mana.max_mana)

	_skill_bar = player.get_node("SkillBar") as SkillBar
	_build_skill_bar()
	_skill_bar.slots_changed.connect(_refresh_slots)
	_skill_bar.use_failed.connect(_show_message)
	_refresh_slots()

	_potion_belt = player.get_node("PotionBelt") as PotionBelt
	_build_potions()
	_potion_belt.changed.connect(_refresh_potions)
	_potion_belt.drink_failed.connect(_show_message)
	_refresh_potions()


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message.visible = _message_time > 0.0
	if _skill_bar == null:
		return
	for slot: int in SkillBar.SLOT_COUNT:
		var gem: SkillGem = _skill_bar.gem_in(slot)
		var fraction: float = 0.0
		if gem != null and gem.cooldown > 0.0:
			fraction = _skill_bar.cooldown_left(gem) / gem.cooldown
		_slot_cooldowns[slot].size.y = SLOT_SIZE.y * fraction
		_slot_cooldowns[slot].position.y = SLOT_SIZE.y * (1.0 - fraction)


func _on_life_changed(current: float, maximum: float) -> void:
	_set_bar(_life, "Life", current, maximum)
	if current > 0.0:
		_death_label.visible = false


func _show_message(text: String) -> void:
	# Holding a key while out of mana reports every frame; only restart the timer.
	_message.text = text
	_message_time = MESSAGE_TIME
	_message.visible = true


# --- Bars -------------------------------------------------------------------

func _make_bar(color: Color, right_side: bool) -> Dictionary:
	var frame := ColorRect.new()
	frame.color = Color(0.0, 0.0, 0.0, 0.8)
	frame.size = BAR_SIZE + Vector2(4.0, 4.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	if right_side:
		frame.anchor_left = 1.0
		frame.anchor_right = 1.0
		frame.position = Vector2(-MARGIN - frame.size.x, -MARGIN - frame.size.y)
	else:
		frame.position = Vector2(MARGIN, -MARGIN - frame.size.y)
	add_child(frame)

	var fill := ColorRect.new()
	fill.color = color
	fill.size = BAR_SIZE
	fill.position = Vector2(2.0, 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fill)

	var label: Label = _make_label(16, Color.WHITE)
	label.size = frame.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(label)
	return {"frame": frame, "fill": fill, "label": label}


func _set_bar(bar: Dictionary, title: String, current: float, maximum: float) -> void:
	(bar["fill"] as ColorRect).size.x = BAR_SIZE.x * clampf(current / maximum, 0.0, 1.0)
	(bar["label"] as Label).text = "%s  %d / %d" % [title, ceili(current), int(maximum)]


# --- Potions ----------------------------------------------------------------

func _build_potions() -> void:
	var life_frame: ColorRect = _life["frame"]
	for i: int in _potion_belt.potions.size():
		var potion: PotionData = _potion_belt.potions[i]
		var frame := ColorRect.new()
		frame.color = Color(0.0, 0.0, 0.0, 0.8)
		frame.size = POTION_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.anchor_top = 1.0
		frame.anchor_bottom = 1.0
		frame.position = Vector2(
			life_frame.position.x + life_frame.size.x + 12.0 + i * (POTION_SIZE.x + 6.0),
			-MARGIN - POTION_SIZE.y)
		add_child(frame)

		var fill := ColorRect.new()
		fill.color = potion.color
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill)
		_potion_fills.append(fill)

		var key: Label = _make_label(14, Color.WHITE)
		key.text = str(i + 1)
		key.position = Vector2(4.0, 0.0)
		frame.add_child(key)


func _refresh_potions() -> void:
	for i: int in _potion_fills.size():
		var potion: PotionData = _potion_belt.potions[i]
		var inner: Vector2 = POTION_SIZE - Vector2(4.0, 4.0)
		var fraction: float = _potion_belt.charges[i] / potion.max_charges
		var fill: ColorRect = _potion_fills[i]
		fill.size = Vector2(inner.x, inner.y * fraction)
		fill.position = Vector2(2.0, 2.0 + inner.y * (1.0 - fraction))
		# Dim when there aren't enough charges for a drink.
		fill.modulate.a = 1.0 if _potion_belt.charges[i] >= potion.charges_per_use else 0.35


# --- Skill bar ----------------------------------------------------------------

func _build_skill_bar() -> void:
	var total_width: float = SkillBar.SLOT_COUNT * SLOT_SIZE.x + (SkillBar.SLOT_COUNT - 1) * 6.0
	for slot: int in SkillBar.SLOT_COUNT:
		var frame := Panel.new()
		frame.size = SLOT_SIZE
		frame.anchor_left = 0.5
		frame.anchor_right = 0.5
		frame.anchor_top = 1.0
		frame.anchor_bottom = 1.0
		frame.position = Vector2(-total_width * 0.5 + slot * (SLOT_SIZE.x + 6.0), -MARGIN - SLOT_SIZE.y)
		frame.tooltip_text = "Click to change the skill in this slot"
		frame.gui_input.connect(_on_slot_input.bind(slot))
		add_child(frame)

		var cooldown := ColorRect.new()
		cooldown.color = Color(0.0, 0.0, 0.0, 0.65)
		cooldown.size = Vector2(SLOT_SIZE.x, 0.0)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(cooldown)
		_slot_cooldowns.append(cooldown)

		var key: Label = _make_label(13, Color(0.8, 0.75, 0.6))
		key.text = SkillBar.SLOT_KEYS[slot]
		key.position = Vector2(4.0, 1.0)
		frame.add_child(key)

		var name_label: Label = _make_label(13, Color.WHITE)
		name_label.size = Vector2(SLOT_SIZE.x, 20.0)
		name_label.position = Vector2(0.0, 22.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame.add_child(name_label)
		_slot_names.append(name_label)

		var cost: Label = _make_label(12, Color(0.45, 0.6, 1.0))
		cost.size = Vector2(SLOT_SIZE.x - 4.0, 18.0)
		cost.position = Vector2(0.0, SLOT_SIZE.y - 19.0)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		frame.add_child(cost)
		_slot_costs.append(cost)


func _refresh_slots() -> void:
	for slot: int in SkillBar.SLOT_COUNT:
		var gem: SkillGem = _skill_bar.gem_in(slot)
		_slot_names[slot].text = gem.short_name if gem != null else ""
		_slot_costs[slot].text = str(int(gem.mana_cost)) if gem != null and gem.mana_cost > 0.0 else ""


func _on_slot_input(event: InputEvent, slot: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_skill_bar.cycle_slot(slot)
		get_viewport().set_input_as_handled()


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
