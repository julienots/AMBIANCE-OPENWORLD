class_name Mats
## Material factory: converts imported glTF materials into the game's toon / symbiote
## shaders and caches the results so identical surfaces share one material.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const SYMBIOTE := preload("res://shaders/symbiote.gdshader")
const NOISE := preload("res://assets/textures/noise.png")

static var _cache := {}
static var outline_enabled := true
static var _outline_mat: ShaderMaterial


static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE
	return _outline_mat


static func toon(color: Color, emission := 0.0, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_energy", emission)
	m.set_shader_parameter("noise_tex", NOISE)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


static var _prop_vc: ShaderMaterial


static func prop_vc() -> ShaderMaterial:
	## Shared toon material for merged props (colour comes from vertex colours).
	if _prop_vc == null:
		_prop_vc = toon(Color.WHITE, 0.0, {"use_vertex_color": true, "rim_amount": 0.2})
		if outline_enabled:
			_prop_vc.next_pass = outline_material()
	return _prop_vc


static func symbiote(opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SYMBIOTE
	m.set_shader_parameter("noise_tex", NOISE)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


## Builds the toon material for an imported surface from its name and colour.
## Each call returns a unique material when `unique` is set (needed for per-instance
## hit flashes / dissolves); otherwise materials are shared.
static func from_imported(src: Material, unique: bool, symbiote_body := false) -> ShaderMaterial:
	var name := src.resource_name.to_lower() if src else "default"
	var col := Color(0.8, 0.8, 0.8)
	var em_src := 0.0
	if src is BaseMaterial3D:
		col = src.albedo_color
		if src.emission_enabled:
			em_src = src.emission_energy_multiplier
	var key := "%s|%s|%s" % [name, col.to_html(), symbiote_body]
	if not unique and _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial
	if symbiote_body and not (name.begins_with("glow") or name.begins_with("eye")):
		var opts := {"base_color": col}
		if name.begins_with("vein"):
			opts["vein_strength"] = 2.0
		elif name.begins_with("bone") or name.begins_with("tooth") or name.begins_with("plate"):
			opts["vein_strength"] = 0.25
			opts["breathe"] = 0.0
		m = symbiote(opts)
	else:
		var emission := 0.0
		var opts := {}
		if name.begins_with("glow"):
			emission = 2.2
			opts["pulse_speed"] = 3.0
		elif name.begins_with("eye"):
			emission = 2.5
		elif em_src > 0.0:
			emission = 1.5
		if name.begins_with("metal"):
			opts["specular_amount"] = 0.45
			opts["specular_threshold"] = 0.86
		m = toon(col, emission, opts)
	if not unique:
		_cache[key] = m
	return m


## Applies toon/symbiote materials to every MeshInstance3D below `root`.
## Returns the list of created materials (to drive flash / dissolve per instance).
static func apply(root: Node, unique := false, symbiote_body := false, outline := true) -> Array:
	var out: Array = []
	for mi in find_meshes(root):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var m := from_imported(src, unique, symbiote_body)
			if outline and outline_enabled and src and not src.resource_name.to_lower().begins_with("glow"):
				m.next_pass = outline_material()
			mi.set_surface_override_material(s, m)
			if not out.has(m):
				out.append(m)
	return out


static func find_meshes(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(find_meshes(c))
	return out


static func set_param(mats: Array, param: String, value) -> void:
	for m in mats:
		if m is ShaderMaterial:
			m.set_shader_parameter(param, value)
