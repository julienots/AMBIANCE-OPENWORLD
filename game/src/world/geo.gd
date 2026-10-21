class_name Geo
extends RefCounted
## Batches procedural geometry: every box/prism is merged per (tile, material) into one
## mesh so a whole city block costs a handful of draw calls. Colliders go into one
## StaticBody3D per tile (group "navsource" for navmesh baking). Tiles get a visibility
## range so distant geometry is culled (draw distance setting).

const TILE := 48.0

var materials := {}          # key -> Material
var _st := {}                # "tx,tz|mat" -> SurfaceTool
var _bodies := {}            # "tx,tz|surface" -> StaticBody3D
var root: Node3D
var draw_distance := 160.0
var tri_count := 0


func _init(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Geometry"
	parent.add_child(root)


func define(key: String, mat: Material) -> void:
	materials[key] = mat


func env_mat(key: String, c1: Color, c2: Color, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/env.gdshader")
	m.set_shader_parameter("albedo", c1)
	m.set_shader_parameter("albedo2", c2)
	m.set_shader_parameter("noise_tex", Mats.NOISE)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	materials[key] = m
	return m


func _tile_key(p: Vector3) -> String:
	return "%d,%d" % [int(floor(p.x / TILE)), int(floor(p.z / TILE))]


func _surface_tool(p: Vector3, mat: String) -> SurfaceTool:
	var k := _tile_key(p) + "|" + mat
	if not _st.has(k):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[k] = st
	return _st[k]


func body_for(p: Vector3, surface := "concrete") -> StaticBody3D:
	var k := _tile_key(p) + "|" + surface
	if not _bodies.has(k):
		var b := StaticBody3D.new()
		b.collision_layer = Combat.LAYER_WORLD
		b.collision_mask = 0
		b.set_meta("surface", surface)
		b.add_to_group("navsource")
		root.add_child(b)
		_bodies[k] = b
	return _bodies[k]


func add_collider_box(xf: Transform3D, size: Vector3, surface := "concrete") -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	body_for(xf.origin, surface).add_child(cs)


func box(center: Vector3, size: Vector3, mat: String, rot_y := 0.0, collide := true, surface := "concrete", shade_bottom := 0.75, rot_x := 0.0) -> void:
	var b := Basis(Vector3.UP, rot_y) * Basis(Vector3.RIGHT, rot_x)
	var xf := Transform3D(b, center)
	_add_box_mesh(xf, size, mat, shade_bottom)
	if collide:
		add_collider_box(xf, size, surface)


func _add_box_mesh(xf: Transform3D, size: Vector3, mat: String, shade_bottom: float) -> void:
	var st := _surface_tool(xf.origin, mat)
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
	]
	for f in faces:
		var n: Vector3 = xf.basis * f[0]
		var v: Array = f[1]
		var cols := []
		for p in v:
			# Vertex-colour ambient occlusion: darker toward the bottom of tall boxes.
			var t = (p.y + h.y) / maxf(size.y, 0.001)
			var c := lerpf(shade_bottom, 1.0, clampf(t * 3.0, 0.0, 1.0))
			cols.append(Color(c, c, c))
		var idx := [0, 1, 2, 0, 2, 3]
		for i in idx:
			st.set_normal(n)
			st.set_color(cols[i])
			st.set_uv(Vector2(v[i].x + v[i].z, v[i].y))
			st.add_vertex(xf * v[i])
		tri_count += 2


func ramp(start: Vector3, end: Vector3, width: float, thickness: float, mat: String, surface := "concrete") -> void:
	## Sloped slab from start to end (both are top-surface centre points).
	var d := end - start
	var length := d.length()
	var yaw := atan2(d.x, d.z)
	var pitch := -asin(d.y / length)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var center := (start + end) * 0.5 - b.y * thickness * 0.5
	var xf := Transform3D(b, center)
	var size := Vector3(width, thickness, length)
	_add_box_mesh(xf, size, mat, 1.0)
	add_collider_box(xf, size, surface)


func mesh(m: Mesh, xf: Transform3D, mat_override := "") -> void:
	## Merges an arbitrary mesh (e.g. a prop) into the batch.
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var key := mat_override if mat_override != "" else "prop_%s" % m.surface_get_material(s).get_rid().get_id()
		if mat_override == "" and not materials.has(key):
			materials[key] = Mats.from_imported(m.surface_get_material(s), false)
		var st := _surface_tool(xf.origin, key)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var order: Array = idx if idx.size() > 0 else range(verts.size())
		for i in order:
			st.set_normal((xf.basis * norms[i]).normalized())
			st.set_color(Color.WHITE)
			st.set_uv(Vector2.ZERO)
			st.add_vertex(xf * verts[i])
		tri_count += order.size() / 3


func build() -> void:
	for k in _st:
		var parts: PackedStringArray = k.split("|")
		var mat_key := parts[1]
		var st: SurfaceTool = _st[k]
		var am := st.commit()
		if am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = materials.get(mat_key)
		mi.name = "Tile_" + k.replace("|", "_").replace(",", "_")
		if not mat_key.begins_with("ground") and not mat_key.begins_with("big"):
			mi.visibility_range_end = draw_distance
			mi.visibility_range_end_margin = 12.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if mat_key.begins_with("ground") or mat_key.begins_with("glow"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	_st.clear()
