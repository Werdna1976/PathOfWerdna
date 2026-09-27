@tool
class_name RockProp
extends KitProp
## Lumpy low-poly rocks in three styles:
## - BOULDER: one big rock.
## - CLUSTER: a few rocks of mixed size, huddled together.
## - CLIFF: a tall, layered cliff chunk (cliff material) for zone edges.
## Pivot: centre of the footprint, on the ground. `size` is roughly the
## footprint radius in metres.

enum Style { BOULDER, CLUSTER, CLIFF }

@export var style: Style = Style.BOULDER:
	set(value):
		style = value
		_queue_rebuild()
@export var size: float = 1.0:
	set(value):
		size = value
		_queue_rebuild()
## Tints the stone (vertex colour), e.g. darker and wetter by the sea.
@export var tint: Color = Color(1, 1, 1):
	set(value):
		tint = value
		_queue_rebuild()


func _build(rng: RandomNumberGenerator) -> void:
	var key: String = "rock:%d:%s:%d:%s" % [style, size, variant, tint.to_html()]
	var material: Material = KitMaterials.named("cliff_rock" if style == Style.CLIFF else "stone")
	var pieces: Array = _pieces(rng)
	add_mesh(KitMesh.cached(key, _mesh.bind(pieces)), material)
	for piece: Array in pieces:
		var center: Vector3 = piece[0]
		var scale: Vector3 = piece[1]
		var r: float = maxf(scale.x, scale.z) * 0.85
		add_cylinder_collider(r, scale.y * 1.6, Vector3(center.x, 0.0, center.z))


## [center, scale] for each rock in the prop.
func _pieces(rng: RandomNumberGenerator) -> Array:
	var list: Array = []
	match style:
		Style.BOULDER:
			var s := Vector3(size, size * rng.randf_range(0.6, 0.85), size * rng.randf_range(0.8, 1.0))
			list.append([Vector3(0, s.y * 0.35, 0), s])
		Style.CLUSTER:
			var count: int = rng.randi_range(3, 5)
			for i: int in count:
				var r: float = size * (0.55 if i == 0 else rng.randf_range(0.2, 0.4))
				var ang: float = rng.randf() * TAU
				var off: Vector3 = Vector3.ZERO if i == 0 else Vector3(cos(ang), 0, sin(ang)) * size * rng.randf_range(0.5, 0.8)
				var s := Vector3(r, r * rng.randf_range(0.55, 0.9), r * rng.randf_range(0.8, 1.1))
				list.append([off + Vector3(0, s.y * 0.3, 0), s])
		Style.CLIFF:
			var s := Vector3(size, size * rng.randf_range(1.8, 2.4), size * rng.randf_range(0.7, 0.9))
			list.append([Vector3(0, s.y * 0.45, 0), s])
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var t := Vector3(size * 0.6, size * rng.randf_range(0.9, 1.3), size * 0.6)
			list.append([Vector3(side * size * 0.8, t.y * 0.4, size * 0.2), t])
	return list


func _mesh(pieces: Array) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var i: int = 0
	for piece: Array in pieces:
		var jag: float = 0.22 if style == Style.CLIFF else 0.3
		var shade: Color = tint.darkened(0.08 * (i % 3))
		KitMesh.blob(st, piece[0], piece[1], variant * 97 + i * 13 + style, jag, shade, 2, -0.35, 0.1)
		i += 1
	return KitMesh.commit(st)
