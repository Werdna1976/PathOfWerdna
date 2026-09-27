class_name KitMesh
extends RefCounted
## Procedural low-poly mesh helpers for kit props.
##
## Meshes are flat shaded, carry vertex colours (kit materials multiply them
## into the albedo, so one material serves many tints) and get box-projected
## UVs and tangents, so triplanar and normal-mapped materials work on them.
##
## Faces are given with an `inside` point and are flipped to face away from it,
## so callers never have to think about winding order.
## Build meshes through `cached()` so props that share a shape share the mesh.

static var _cache: Dictionary = {}


## Returns the mesh for `key`, building it with `builder` the first time.
static func cached(key: String, builder: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_tangents()
	return st.commit()


## A flat triangle facing away from `inside`.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t: Vector3 = b
		b = c
		c = t
		n = -n
	# Godot's front faces wind clockwise, so emit a, c, b.
	for v: Vector3 in [a, c, b]:
		st.set_color(color)
		st.set_normal(n)
		st.set_uv(_box_uv(v, n))
		st.add_vertex(v)


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, inside: Vector3) -> void:
	tri(st, a, b, c, color, inside)
	tri(st, a, c, d, color, inside)


## An oriented box. `basis` rotates it around `center`.
static func box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
	var h: Vector3 = size * 0.5
	var p: Array[Vector3] = []
	for i: int in 8:
		var corner := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(center + basis * corner)
	quad(st, p[0], p[1], p[3], p[2], color, center)  # -z
	quad(st, p[4], p[5], p[7], p[6], color, center)  # +z
	quad(st, p[0], p[1], p[5], p[4], color, center)  # -y
	quad(st, p[2], p[3], p[7], p[6], color, center)  # +y
	quad(st, p[0], p[2], p[6], p[4], color, center)  # -x
	quad(st, p[1], p[3], p[7], p[5], color, center)  # +x


## A (possibly tapered) cylinder from `a` to `b`. rb = 0 makes a cone.
static func cylinder(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, color: Color,
		cap_a: bool = true, cap_b: bool = true, twist: float = 0.0) -> void:
	var axis: Vector3 = b - a
	if axis.length_squared() < 1e-8:
		return
	var up: Vector3 = axis.normalized()
	var u: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var v: Vector3 = up.cross(u)
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for i: int in sides:
		var ang: float = TAU * i / sides + twist
		var dir: Vector3 = u * cos(ang) + v * sin(ang)
		ring_a.append(a + dir * ra)
		ring_b.append(b + dir * rb)
	var mid: Vector3 = (a + b) * 0.5
	for i: int in sides:
		var j: int = (i + 1) % sides
		quad(st, ring_a[i], ring_a[j], ring_b[j], ring_b[i], color, mid)
	if cap_a and ra > 0.0:
		for i: int in sides:
			tri(st, a, ring_a[i], ring_a[(i + 1) % sides], color.darkened(0.15), a + up * 0.01)
	if cap_b and rb > 0.0:
		for i: int in sides:
			tri(st, b, ring_b[i], ring_b[(i + 1) % sides], color.darkened(0.15), b - up * 0.01)


## A chain of cylinders through `points` (a branch, a bent log, a rope).
static func tube(st: SurfaceTool, points: Array[Vector3], radii: Array[float], sides: int, color: Color) -> void:
	for i: int in points.size() - 1:
		cylinder(st, points[i], points[i + 1], radii[i], radii[i + 1], sides, color, i == 0, i == points.size() - 2)


## A lumpy, flat-shaded blob (rocks, bushes, sacks). Vertices of an icosphere
## are pushed in and out by 3D noise. `bottom` flattens everything below it.
static func blob(st: SurfaceTool, center: Vector3, scale: Vector3, seed_value: int, jag: float, color: Color,
		subdivisions: int = 1, bottom: float = -1.0, color_jitter: float = 0.08) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.3
	var sphere: Array = icosphere(subdivisions)
	var verts: Array[Vector3] = []
	for p: Vector3 in sphere[0]:
		var r: float = 1.0 + noise.get_noise_3dv(p * 1.7) * jag
		var q: Vector3 = p * r
		q.y = maxf(q.y, bottom)
		verts.append(center + q * scale)
	var faces: Array = sphere[1]
	for f: Vector3i in faces:
		var shade: float = noise.get_noise_3dv((verts[f.x] - center) * 3.1) * color_jitter
		var c: Color = Color(color.r + shade, color.g + shade, color.b + shade, color.a)
		tri(st, verts[f.x], verts[f.y], verts[f.z], c, center)


## Unit icosphere as [vertices: Array[Vector3], faces: Array[Vector3i]].
static func icosphere(subdivisions: int) -> Array:
	var key: String = "ico:%d" % subdivisions
	if _cache.has(key):
		return _cache[key]
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for p: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(p.normalized())
	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)]
	for s: int in subdivisions:
		var midpoints: Dictionary = {}
		var next: Array[Vector3i] = []
		for f: Vector3i in faces:
			var ab: int = _midpoint(verts, midpoints, f.x, f.y)
			var bc: int = _midpoint(verts, midpoints, f.y, f.z)
			var ca: int = _midpoint(verts, midpoints, f.z, f.x)
			next.append_array([Vector3i(f.x, ab, ca), Vector3i(f.y, bc, ab), Vector3i(f.z, ca, bc), Vector3i(ab, bc, ca)])
		faces = next
	var result: Array = [verts, faces]
	_cache[key] = result
	return result


static func _midpoint(verts: Array[Vector3], cache: Dictionary, a: int, b: int) -> int:
	var key: int = mini(a, b) * 100000 + maxi(a, b)
	if not cache.has(key):
		verts.append(((verts[a] + verts[b]) * 0.5).normalized())
		cache[key] = verts.size() - 1
	return cache[key]


static func _box_uv(v: Vector3, n: Vector3) -> Vector2:
	var an: Vector3 = n.abs()
	if an.x >= an.y and an.x >= an.z:
		return Vector2(v.z, -v.y)
	if an.y >= an.z:
		return Vector2(v.x, v.z)
	return Vector2(v.x, -v.y)
