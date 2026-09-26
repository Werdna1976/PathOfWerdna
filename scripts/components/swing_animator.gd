class_name SwingAnimator
extends Node
## Placeholder attack animation: sweeps a weapon pivot across the body
## during a MeleeAttack's wind-up, then returns it during recovery.
## The sweep matches the swing's arc, so Cleave visibly sweeps wider.

const REST_DEGREES: float = 75.0
const MAX_SWEEP_DEGREES: float = 170.0

@export var melee: MeleeAttack
@export var pivot: Node3D

var _tween: Tween


func _ready() -> void:
	melee.swing_started.connect(_on_swing_started)
	pivot.rotation.y = deg_to_rad(REST_DEGREES)


func _on_swing_started() -> void:
	if _tween != null:
		_tween.kill()
	var rest: float = deg_to_rad(REST_DEGREES)
	var half_sweep: float = deg_to_rad(minf(melee.current_arc(), MAX_SWEEP_DEGREES) * 0.5 + 20.0)
	var windup: float = melee.current_windup()
	_tween = create_tween()
	# Short raise, then a fast sweep that lands as the hit resolves.
	_tween.tween_property(pivot, "rotation:y", half_sweep, windup * 0.4)
	_tween.tween_property(pivot, "rotation:y", -half_sweep, windup * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(pivot, "rotation:y", rest, melee.current_recovery()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
