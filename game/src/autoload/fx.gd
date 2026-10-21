extends Node
## Visual effects library built from code (CPU particles, sprites, short-lived lights),
## plus camera shake, hit-stop and slow motion. Densities follow the quality settings.

const TEX_SMOKE := preload("res://assets/textures/smoke_sheet.png")
const TEX_GLOW := preload("res://assets/textures/glow.png")
const TEX_SPARK := preload("res://assets/textures/spark.png")
const TEX_RING := preload("res://assets/textures/ring.png")

var shake := 0.0              # read & decayed by the camera
var _mats := {}
var _slowmo_t := 0.0
var _hitstop_t := 0.0
var _base_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _hitstop_t > 0.0:
		_hitstop_t -= real
		Engine.time_scale = 0.05 if _hitstop_t > 0.0 else (0.35 if _slowmo_t > 0.0 else 1.0)
	elif _slowmo_t > 0.0:
		_slowmo_t -= real
		Engine.time_scale = 0.35 if _slowmo_t > 0.0 else 1.0
	shake = maxf(0.0, shake - real * 2.5)


func add_shake(amount: float) -> void:
	shake = minf(1.5, shake + amount * float(Settings.get_v("shake", 1.0)))
	if Settings.get_v("vibration", true) and amount > 0.35 and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(40 + amount * 80))


func hitstop(t := 0.06) -> void:
	_hitstop_t = maxf(_hitstop_t, t)


func slowmo(t := 0.8) -> void:
	_slowmo_t = maxf(_slowmo_t, t)


func reset_time() -> void:
	_slowmo_t = 0.0
	_hitstop_t = 0.0
	Engine.time_scale = 1.0


func density() -> float:
	return float(Settings.get_v("particles", 1.0))


func _scene_root() -> Node:
	var w := get_tree().get_first_node_in_group("fx_root")
	return w if w else get_tree().current_scene


# ----------------------------------------------------------------------------- materials

func _particle_mat(tex: Texture2D, additive: bool, flipbook := false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [tex.resource_path, additive, flipbook]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if flipbook:
		m.particles_anim_h_frames = 4
		m.particles_anim_v_frames = 4
		m.particles_anim_loop = false
	_mats[key] = m
	return m


func _quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


func _gradient(c0: Color, c1: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	return g


func _burst(pos: Vector3, amount: int, tex: Texture2D, additive: bool, color: Color, size: float, life: float,
		vel: float, spread := 180.0, gravity := Vector3.ZERO, flipbook := false, end_color := Color(0, 0, 0, 0),
		scale_curve_up := false, dir := Vector3.UP) -> CPUParticles3D:
	var n := maxi(1, int(amount * density()))
	var p := CPUParticles3D.new()
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.mesh = _quad(size)
	p.material_override = _particle_mat(tex, additive, flipbook)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = gravity
	p.damping_min = vel * 0.5
	p.damping_max = vel * 1.2
	p.color_ramp = _gradient(color, Color(color.r, color.g, color.b, 0) if end_color == Color(0, 0, 0, 0) else end_color)
	var c := Curve.new()
	if scale_curve_up:
		c.add_point(Vector2(0, 0.4))
		c.add_point(Vector2(1, 1.3))
	else:
		c.add_point(Vector2(0, 1))
		c.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = c
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	if flipbook:
		p.anim_speed_min = 1.0
		p.anim_speed_max = 1.0
		p.anim_offset_max = 0.1
	_scene_root().add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


func _flash_light(pos: Vector3, color: Color, energy: float, range_: float, t: float) -> void:
	if int(Settings.get_v("quality", 1)) == 0:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.shadow_enabled = false
	_scene_root().add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t)
	tw.tween_callback(l.queue_free)


# ----------------------------------------------------------------------------- effects

func hit_spark(pos: Vector3, color := Color(1, 0.9, 0.6), strong := false) -> void:
	_burst(pos, 10 if strong else 6, TEX_SPARK, true, color * 2.0, 0.35, 0.25, 9.0 if strong else 6.0)
	_burst(pos, 1, TEX_GLOW, true, color * 1.5, 1.4 if strong else 0.9, 0.12, 0.0, 0.0)


func impact(pos: Vector3, color: Color, size := 1.0) -> void:
	_burst(pos, 12, TEX_SPARK, true, color * 2.5, 0.45 * size, 0.35, 10.0 * size)
	_burst(pos, 1, TEX_GLOW, true, color * 2.0, 2.2 * size, 0.18, 0.0, 0.0)
	_burst(pos, 4, TEX_SMOKE, false, Color(0.3, 0.3, 0.35, 0.5), 1.2 * size, 0.8, 1.5, 90.0, Vector3(0, 0.6, 0), true)
	_flash_light(pos, color, 3.0, 5.0 * size, 0.2)


func smoke_puff(pos: Vector3, color := Color(0.25, 0.25, 0.28, 0.6), size := 1.5, amount := 6) -> void:
	_burst(pos, amount, TEX_SMOKE, false, color, size, 1.4, 1.2, 70.0, Vector3(0, 0.4, 0), true, Color(color.r, color.g, color.b, 0), true)


func explosion(pos: Vector3, radius: float, color := Color(1.0, 0.55, 0.15)) -> void:
	_burst(pos, 14, TEX_SMOKE, true, color * 2.0, radius * 0.9, 0.6, radius * 2.5, 180.0, Vector3.ZERO, true, Color(0.4, 0.1, 0.0, 0), true)
	_burst(pos, 10, TEX_SMOKE, false, Color(0.12, 0.1, 0.1, 0.7), radius * 1.1, 2.0, radius * 1.2, 120.0, Vector3(0, 1.0, 0), true, Color(0.1, 0.1, 0.1, 0), true)
	_burst(pos, 24, TEX_SPARK, true, color * 3.0, 0.5, 0.7, radius * 6.0, 180.0, Vector3(0, -9, 0))
	ring(pos + Vector3(0, 0.1, 0), radius * 1.4, color, 0.45)
	_flash_light(pos + Vector3.UP, color, 8.0, radius * 3.0, 0.5)
	add_shake(0.6)


func ring(pos: Vector3, radius: float, color: Color, t := 0.4) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = TEX_RING
	m.albedo_color = color * 2.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene_root().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, t)
	tw.chain().tween_callback(mi.queue_free)


func dissolve_burst(pos: Vector3, color := Color(0.8, 0.1, 0.25), size := 1.0) -> void:
	_burst(pos, 16, TEX_SMOKE, false, Color(0.05, 0.03, 0.07, 0.85), 1.0 * size, 1.6, 2.0 * size, 180.0, Vector3(0, 1.5, 0), true, Color(0.05, 0.03, 0.07, 0), true)
	_burst(pos, 20, TEX_GLOW, true, color * 2.0, 0.25 * size, 1.2, 3.0 * size, 180.0, Vector3(0, 2.0, 0))


func dig_debris(pos: Vector3, color: Color) -> void:
	_burst(pos, 10, TEX_GLOW, false, color, 0.25, 0.7, 5.0, 70.0, Vector3(0, -12, 0), false, color, false, Vector3.UP)
	_burst(pos, 5, TEX_SMOKE, false, Color(color.r * 0.8, color.g * 0.75, color.b * 0.7, 0.55), 1.5, 1.6, 1.0, 120.0, Vector3(0, 0.3, 0), true, Color(0.3, 0.28, 0.25, 0), true)


func heal_fx(pos: Vector3, color := Color(0.4, 1.0, 0.5)) -> void:
	_burst(pos, 14, TEX_GLOW, true, color * 2.0, 0.3, 1.0, 2.0, 40.0, Vector3(0, 2.5, 0))


func damage_number(pos: Vector3, amount: float, crit := false, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount))) + ("!" if crit else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012 if not crit else 0.0016
	l.font_size = 48
	l.outline_size = 12
	l.modulate = (Color(1, 0.85, 0.2) if crit else color)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
	_scene_root().add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func symbiote_smoke(parent: Node3D, color := Color(0.03, 0.02, 0.05, 0.75), size := 1.2, amount := 16, height := 2.0) -> CPUParticles3D:
	## Persistent black organic smoke (used by the Devourer, nests and corrupted zones).
	var p := CPUParticles3D.new()
	p.amount = maxi(4, int(amount * density()))
	p.lifetime = 2.6
	p.mesh = _quad(size)
	p.material_override = _particle_mat(TEX_SMOKE, false, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, height * 0.5, 0.35)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.25, 0)
	p.color_ramp = _gradient(color, Color(color.r, color.g, color.b, 0.0))
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	p.position = Vector3(0, height * 0.5, 0)
	parent.add_child(p)
	return p


func ambient_motes(parent: Node3D, color: Color, extents: Vector3, amount := 40, size := 0.12, additive := true) -> CPUParticles3D:
	## Floating spores / dust / embers around the camera.
	var p := CPUParticles3D.new()
	p.amount = maxi(8, int(amount * density()))
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.mesh = _quad(size)
	p.material_override = _particle_mat(TEX_GLOW, additive)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, 0.03, 0)
	p.color_ramp = _gradient(color, Color(color.r, color.g, color.b, 0))
	p.local_coords = false
	parent.add_child(p)
	return p


func danger_zone(pos: Vector3, radius: float, t: float, color := Color(1.0, 0.15, 0.1)) -> void:
	## Telegraph: a red disc that fills up until the attack lands.
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/telegraph.gdshader")
	m.set_shader_parameter("color", color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene_root().add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.06
	var tw := mi.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("fill", v), 0.0, 1.0, t)
	tw.tween_callback(mi.queue_free)
