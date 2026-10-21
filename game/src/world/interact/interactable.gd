class_name Interactable
extends Node3D
## Base for everything the player can use. Subclasses override get_prompt / interact.

@export var prompt := "Utiliser"
@export var interact_range := 2.2
var enabled := true


func _ready() -> void:
	add_to_group("interactable")
	_build()
	merge_static(self)


static func merge_static(root: Node3D, vis_range := 90.0) -> void:
	## Merges the direct, static, non-emissive toon meshes of `root` into one mesh coloured
	## per vertex: a lamp, a locker or a generator costs one draw call instead of 3-20.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var merged := 0
	for c in root.get_children():
		if not c is MeshInstance3D or c.has_meta("dynamic"):
			continue
		var mi: MeshInstance3D = c
		var m := mi.material_override as ShaderMaterial
		if m == null or m.shader != Mats.TOON or float(m.get_shader_parameter("emission_energy")) > 0.0:
			continue
		var col: Color = (m.get_shader_parameter("albedo") as Color).srgb_to_linear()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var order: Array = Array(idx) if idx != null and idx.size() > 0 else range(verts.size())
			for i in order:
				st.set_color(col)
				st.set_normal((mi.transform.basis * norms[i]).normalized())
				st.add_vertex(mi.transform * verts[i])
		mi.queue_free()
		merged += 1
	if merged == 0:
		return
	var out := MeshInstance3D.new()
	out.name = "Merged"
	out.mesh = st.commit()
	out.material_override = Mats.prop_vc()
	out.visibility_range_end = vis_range
	root.add_child(out)


func _build() -> void:
	pass


func can_interact(_p: Node) -> bool:
	return enabled


func get_prompt(_p: Node) -> String:
	return prompt


func interact(_p: Node) -> void:
	pass


static func box_mesh(size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.toon(color, emission)
	return mi


static func static_box(parent: Node3D, size: Vector3, pos := Vector3.ZERO, surface := "metal") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Combat.LAYER_WORLD
	b.collision_mask = 0
	b.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)
	return b
