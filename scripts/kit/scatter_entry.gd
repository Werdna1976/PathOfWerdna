class_name ScatterEntry
extends Resource
## One kind of prop that a PropScatter can place, with how often and how.

@export var scene: PackedScene
## Relative chance against the other entries.
@export var weight: float = 1.0
@export var scale_min: float = 0.8
@export var scale_max: float = 1.2
@export var random_yaw: bool = true
## Maximum random tilt in degrees (small tilts make rocks and logs sit naturally).
@export_range(0.0, 45.0) var tilt: float = 0.0
## Decorative props get no colliders, so they don't block movement or the navmesh.
@export var decorative: bool = false
## Minimum distance in metres to any other placed prop.
@export var spacing: float = 1.0
## How many distinct variants (seeds) of a KitProp to use. More variety,
## fewer shared meshes.
@export_range(1, 32) var variants: int = 4
## Property overrides applied to each instance, e.g. {"style": 1, "size": 1.4}.
@export var properties: Dictionary = {}
