class_name FlickerLight
extends OmniLight3D
## A fire light that flickers: its energy wanders around `base_energy` with
## smooth noise, plus a faint sway of the light position.

@export var base_energy: float = 3.0
## Fraction of base_energy the flicker can add or remove.
@export_range(0.0, 1.0) var flicker: float = 0.22
@export var speed: float = 7.0
## Metres the light wanders, which makes shadows shiver slightly.
@export var sway: float = 0.03

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _origin: Vector3


func _ready() -> void:
	_noise.frequency = 0.5
	_noise.seed = hash(get_path()) if is_inside_tree() else 0
	_time = randf() * 100.0
	_origin = position
	light_energy = base_energy


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = base_energy * (1.0 + flicker * _noise.get_noise_1d(_time))
	position = _origin + Vector3(_noise.get_noise_1d(_time + 40.0), _noise.get_noise_1d(_time + 80.0) * 0.5,
		_noise.get_noise_1d(_time + 120.0)) * sway
