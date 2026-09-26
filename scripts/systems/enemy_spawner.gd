class_name EnemySpawner
extends Node3D
## Keeps one enemy alive at each child Marker3D, respawning after a delay.
## Enemies become children of this node.

@export var enemy_scene: PackedScene
@export var respawn_delay: float = 8.0


func _ready() -> void:
	for marker: Node in get_children():
		if marker is Marker3D:
			_spawn_at.call_deferred(marker as Marker3D)


func _spawn_at(marker: Marker3D) -> void:
	var enemy: Node3D = enemy_scene.instantiate() as Node3D
	add_child(enemy)
	enemy.global_position = marker.global_position
	# Face a random way so packs don't all stare in the same direction.
	enemy.rotation.y = randf() * TAU
	enemy.reset_physics_interpolation()
	Health.of(enemy).died.connect(_on_enemy_died.bind(marker))


func _on_enemy_died(marker: Marker3D) -> void:
	await get_tree().create_timer(respawn_delay, false).timeout
	if is_inside_tree():
		_spawn_at(marker)
