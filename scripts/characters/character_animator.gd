class_name CharacterAnimator
extends Node
## Procedural animation for a CharacterModel, driven by its CharacterBody3D:
## - walking swings the legs and the free arm, bobs the hips and leans forward,
##   all scaled by the body's ground speed;
## - standing still breathes (the torso swells gently);
## - during a swing the torso twists after the weapon.
## Death and leaps are left to the existing tweens on Visual, which this never touches.

@export var model: CharacterModel
@export var health: Health
## The pivot SwingAnimator sweeps; it bobs with the hips.
@export var weapon_pivot: Node3D
## Metres covered by one full stride (two steps).
@export var stride: float = 1.6
@export var leg_swing_degrees: float = 32.0
@export var arm_swing_degrees: float = 24.0
@export var bob: float = 0.05
@export var lean_degrees: float = 7.0
@export var breathe: float = 0.018
## Speed that counts as a full walk.
@export var walk_speed: float = 4.5
## How much of the weapon's sweep the torso follows.
@export_range(0.0, 1.0) var twist: float = 0.3
## The weapon points up this much at rest...
@export var hand_rest_tilt_degrees: float = 60.0
## ...and levels out to this during a swing.
@export var hand_swing_tilt_degrees: float = 12.0

var _phase: float = 0.0
var _time: float = 0.0
var _speed: float = 0.0
var _pivot_rest: Vector3
var _pivot_rest_yaw: float = 0.0

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


var _started: bool = false


func _ready() -> void:
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if model == null or model.hips == null or _body == null:
		return
	if not _started:
		# Read the pivot's rest pose after every _ready (SwingAnimator sets it).
		_started = true
		if weapon_pivot != null:
			_pivot_rest = weapon_pivot.position
			_pivot_rest_yaw = weapon_pivot.rotation.y
	if health != null and health.is_dead():
		return
	var ground := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	_speed = lerpf(_speed, ground.length(), 1.0 - exp(-10.0 * delta))
	var move: float = clampf(_speed / walk_speed, 0.0, 1.0)
	_phase = fmod(_phase + _speed / stride * TAU * delta, TAU)
	_time += delta
	var s: float = sin(_phase)

	var legs: float = deg_to_rad(leg_swing_degrees) * move
	model.leg_l.rotation.x = s * legs
	model.leg_r.rotation.x = -s * legs
	var lift: float = absf(cos(_phase)) * bob * move
	model.hips.position.y = model.hip_height + lift - bob * move * 0.5
	var breath: float = sin(_time * 1.9) * breathe * (1.0 - move)
	model.torso.scale = Vector3(1.0 + breath * 0.5, 1.0 + breath, 1.0 + breath * 0.5)
	model.torso.rotation.x = model.torso_rest.x - deg_to_rad(lean_degrees) * move
	if model.arm_l != null:
		model.arm_l.rotation.x = -s * deg_to_rad(arm_swing_degrees) * move + breath * 2.0
	if weapon_pivot != null:
		var swing_offset: float = weapon_pivot.rotation.y - _pivot_rest_yaw
		model.torso.rotation.y = model.torso_rest.y + swing_offset * twist
		weapon_pivot.position.y = _pivot_rest.y + (model.hips.position.y - model.hip_height)
		if model.right_hand != null:
			var swinging: float = clampf(absf(swing_offset) / deg_to_rad(35.0), 0.0, 1.0)
			model.right_hand.rotation.x = deg_to_rad(lerpf(hand_rest_tilt_degrees, hand_swing_tilt_degrees, swinging))
