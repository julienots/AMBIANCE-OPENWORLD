class_name DigTerrain
extends Node3D
## Diggable underground volume made of cells (2 m x 1 m x 2 m). Chunks are meshed with
## face culling and a deterministic per-vertex jitter (shared corners => watertight,
## organic-looking rock). Collision uses the same triangles. Only the modified cells are
## stored in the save (generation is deterministic).

enum { AIR, DIRT, STONE, ORE, CRYSTAL, BEDROCK, REINFORCED, ALLOY }

const SX := 2.0
const SY := 1.0
const SZ := 2.0
const NX := 40
const NY := 24
const NZ := 40
const CH := 8                         # chunk size in X/Z (full height)

const INFO := {
	DIRT: {"name": "Terre", "hard": 0.6, "color": Color(0.36, 0.27, 0.2), "drops": {"materials": [1, 1]}},
	STONE: {"name": "Pierre", "hard": 1.2, "color": Color(0.38, 0.37, 0.4), "drops": {"materials": [1, 2]}},
	ORE: {"name": "Filon de métal", "hard": 1.6, "color": Color(0.5, 0.42, 0.36), "drops": {"metal": [2, 3]}},
	CRYSTAL: {"name": "Cristaux", "hard": 1.6, "color": Color(0.25, 0.75, 0.95), "drops": {"crystal": [1, 3]}},
	BEDROCK: {"name": "Roche-mère", "hard": INF, "color": Color(0.16, 0.15, 0.18), "drops": {}},
	REINFORCED: {"name": "Paroi renforcée", "hard": INF, "color": Color(0.45, 0.5, 0.56), "drops": {}},
	ALLOY: {"name": "Veine d'alliage", "hard": 2.4, "color": Color(0.85, 0.65, 0.3), "drops": {"alloy": [1, 1], "metal": [1, 2]}},
}

var cells := PackedByteArray()
var origin := Vector3(-40, -24, -40)  # world position of cell (0,0,0) min corner
var seed_value := 4242
var _chunks := {}                      # Vector2i -> {mi, body}
var _dirty := {}
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var changes: Dictionary                # "x,y,z" -> type (saved)
var nav_dirty := false


func _init() -> void:
	cells.resize(NX * NY * NZ)


func idx(x: int, y: int, z: int) -> int:
	return x + NX * (y + NY * z)


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < NX and c.y < NY and c.z < NZ


func get_cell(c: Vector3i) -> int:
	if not inside(c):
		return BEDROCK
	return cells[idx(c.x, c.y, c.z)]


func cell_at(p: Vector3) -> Vector3i:
	var l := p - origin
	return Vector3i(floori(l.x / SX), floori(l.y / SY), floori(l.z / SZ))


func cell_center(c: Vector3i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * SX, (c.y + 0.5) * SY, (c.z + 0.5) * SZ)


func cell_floor(c: Vector3i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * SX, c.y * SY, (c.z + 0.5) * SZ)


# ------------------------------------------------------------------------------ generation

func generate(saved_changes: Dictionary) -> void:
	changes = saved_changes
	_rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	var ore := FastNoiseLite.new()
	ore.seed = seed_value + 7
	ore.frequency = 0.15
	for z in NZ:
		for y in NY:
			for x in NX:
				var t := STONE
				if x == 0 or z == 0 or x == NX - 1 or z == NZ - 1 or y == 0 or y >= NY - 2:
					t = BEDROCK
				else:
					var n := noise.get_noise_3d(x * 2.0, y, z * 2.0)
					var o := ore.get_noise_3d(x * 2.0, y * 1.3, z * 2.0)
					t = DIRT if y > 15 + n * 3.0 else STONE
					if o > 0.55:
						t = ORE
					elif o < -0.62 and y < 12:
						t = CRYSTAL
					elif o > 0.5 and y < 6:
						t = ALLOY
				cells[idx(x, y, z)] = t
	# Starting chamber under the hatch (floor at y=12) + shaft up to the surface hatch.
	_carve_box(Vector3i(17, 12, 17), Vector3i(23, 15, 23))
	_carve_box(Vector3i(19, 15, 19), Vector3i(21, 22, 21))
	for x in range(17, 24):
		for z in range(17, 24):
			cells[idx(x, 11, z)] = STONE
	# A natural crystal cavern to the east, linked by a short crawl tunnel.
	_carve_ellipsoid(Vector3(31, 9, 20), Vector3(5, 3.5, 5))
	_carve_box(Vector3i(23, 12, 19), Vector3i(26, 14, 21))
	_carve_box(Vector3i(26, 10, 19), Vector3i(28, 14, 21))
	for i in 14:
		var c := Vector3i(_rng.randi_range(27, 35), _rng.randi_range(6, 12), _rng.randi_range(15, 25))
		if get_cell(c) != AIR:
			cells[idx(c.x, c.y, c.z)] = CRYSTAL
	# Apply saved modifications.
	for k in changes:
		var p: PackedStringArray = k.split(",")
		var c := Vector3i(int(p[0]), int(p[1]), int(p[2]))
		if inside(c):
			cells[idx(c.x, c.y, c.z)] = int(changes[k])


func _carve_box(a: Vector3i, b: Vector3i) -> void:
	for z in range(a.z, b.z):
		for y in range(a.y, b.y):
			for x in range(a.x, b.x):
				cells[idx(x, y, z)] = AIR


func _carve_ellipsoid(c: Vector3, r: Vector3) -> void:
	for z in NZ:
		for y in NY:
			for x in NX:
				var d := Vector3((x - c.x) / r.x, (y - c.y) / r.y, (z - c.z) / r.z)
				if d.length() < 1.0 and x > 0 and y > 0 and z > 0 and x < NX - 1 and z < NZ - 1 and y < NY - 2:
					cells[idx(x, y, z)] = AIR


# ------------------------------------------------------------------------------ editing

func set_cell(c: Vector3i, t: int) -> void:
	if not inside(c):
		return
	cells[idx(c.x, c.y, c.z)] = t
	changes["%d,%d,%d" % [c.x, c.y, c.z]] = t
	var ch := Vector2i(c.x / CH, c.z / CH)
	_dirty[ch] = true
	# Neighbouring chunks share faces.
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := Vector2i((c.x + d.x) / CH, (c.z + d.y) / CH)
		if n != ch and inside(Vector3i(c.x + d.x, c.y, c.z + d.y)):
			_dirty[n] = true
	nav_dirty = true


func hardness(c: Vector3i) -> float:
	var t := get_cell(c)
	if t == AIR:
		return 0.0
	return float(INFO[t].hard)


func diggable(c: Vector3i) -> bool:
	var t := get_cell(c)
	return t != AIR and t != BEDROCK and t != REINFORCED and inside(c)


func _process(_delta: float) -> void:
	if _dirty.is_empty():
		return
	for ch in _dirty.keys():
		build_chunk(ch)
	_dirty.clear()


# ------------------------------------------------------------------------------ meshing

func build_all() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/rock.gdshader")
	_mat.set_shader_parameter("noise_tex", Mats.NOISE)
	for cz in ceili(float(NZ) / CH):
		for cx in ceili(float(NX) / CH):
			build_chunk(Vector2i(cx, cz))


func _jitter(v: Vector3i) -> Vector3:
	## Deterministic offset per lattice vertex: identical for every face sharing it.
	if v.x <= 0 or v.z <= 0 or v.x >= NX or v.z >= NZ or v.y <= 0 or v.y >= NY:
		return Vector3.ZERO
	var h := hash(Vector3i(v.x * 73856093, v.y * 19349663, v.z * 83492791))
	var a := float(h & 1023) / 1023.0 - 0.5
	var b := float((h >> 10) & 1023) / 1023.0 - 0.5
	var c := float((h >> 20) & 1023) / 1023.0 - 0.5
	return Vector3(a * 0.7, b * 0.35, c * 0.7)


func _vpos(v: Vector3i) -> Vector3:
	return origin + Vector3(v.x * SX, v.y * SY, v.z * SZ) + _jitter(v)


const FACES := [
	[Vector3i(1, 0, 0), [Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3i(0, 0, 1), Vector3i(0, 1, 1), Vector3i(0, 1, 0), Vector3i(0, 0, 0)]],
	[Vector3i(0, 1, 0), [Vector3i(0, 1, 0), Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3i(0, 0, 1), Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1), Vector3i(0, 0, 1)]],
	[Vector3i(0, 0, -1), [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 0, 0)]],
]


func build_chunk(ch: Vector2i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var x0 := ch.x * CH
	var z0 := ch.y * CH
	var count := 0
	for z in range(z0, mini(z0 + CH, NZ)):
		for y in NY:
			for x in range(x0, mini(x0 + CH, NX)):
				var t: int = cells[idx(x, y, z)]
				if t == AIR:
					continue
				var info: Dictionary = INFO[t]
				for f in FACES:
					var d: Vector3i = f[0]
					var n := Vector3i(x + d.x, y + d.y, z + d.z)
					if not inside(n) or cells[idx(n.x, n.y, n.z)] != AIR:
						continue
					# Only faces that look into open space are built (we live inside the rock).
					var vs: Array = f[1]
					var p := []
					for o in vs:
						p.append(_vpos(Vector3i(x + o.x, y + o.y, z + o.z)))
					var col: Color = info.color
					var shade := 0.85 + 0.15 * float((x * 7 + y * 13 + z * 5) % 5) / 4.0
					col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0 if t == CRYSTAL else (0.35 if t == ALLOY else 0.0))
					var nrm: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
					if nrm.dot(Vector3(d)) < 0.0:
						nrm = -nrm
					for i in [0, 1, 2, 0, 2, 3]:
						st.set_color(col)
						st.set_normal(nrm)
						st.add_vertex(p[i])
						faces.append(p[i])
					count += 1
	var old: Dictionary = _chunks.get(ch, {})
	if old.has("mi"):
		old.mi.queue_free()
		old.body.queue_free()
	if count == 0:
		_chunks.erase(ch)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Combat.LAYER_WORLD
	body.set_meta("surface", "dirt")
	body.add_to_group("navsource")
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_chunks[ch] = {"mi": mi, "body": body}


# ------------------------------------------------------------------------------ queries

func ray_cell(from: Vector3, dir: Vector3, max_dist: float) -> Vector3i:
	## Steps along a ray and returns the first solid cell (or Vector3i(-1,-1,-1)).
	var steps := int(max_dist / 0.25)
	for i in range(1, steps + 1):
		var c := cell_at(from + dir * (i * 0.25))
		if get_cell(c) != AIR:
			return c
	return Vector3i(-1, -1, -1)


func is_floor_cell(c: Vector3i) -> bool:
	## Air cell standing on solid ground with at least 2 m of headroom.
	return get_cell(c) == AIR and get_cell(c + Vector3i(0, -1, 0)) != AIR and get_cell(c + Vector3i(0, 1, 0)) == AIR
