class_name SwingAnimator
extends Node
## Placeholder attack animation: sweeps a weapon pivot across the body
## during a MeleeAttack's wind-up, then returns it during recovery.

@export var melee: MeleeAttack
@export var pivot: Node3D
@export var sweep_degrees: float = 75.0

var _tween: Tween


func _ready() -> void:
	melee.swing_started.connect(_on_swing_started)
	pivot.rotation.y = deg_to_rad(sweep_degrees)


func _on_swing_started() -> void:
	if _tween != null:
		_tween.kill()
	var rest: float = deg_to_rad(sweep_degrees)
	_tween = create_tween()
	# Short raise, then a fast sweep that lands as the hit resolves.
	_tween.tween_property(pivot, "rotation:y", rest + deg_to_rad(20.0), melee.windup * 0.4)
	_tween.tween_property(pivot, "rotation:y", -rest, melee.windup * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(pivot, "rotation:y", rest, melee.recovery) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
