extends Node3D
## Timed area effect used by abilities and ultimates (storms, domains, walls, domes,
## singularities, spore clouds). Ticks damage / pull / status on enemies inside.

var owner_node: Node
var radius := 5.0
var duration := 5.0
var tick := 0.5
var mult := 0.5                 # damage multiplier per tick (player atk based)
var status := ""
var status_t := 1.0
var pull := 0.0                 # m/s toward the center (negative pushes)
var color := Color.CYAN
var shape := "sphere"           # sphere | wall
var wall_length := 8.0
var heal_player := 0.0          # HP per second while the player stands inside
var hide_player := false        # dark domain: enemies lose sight of the player
var explode_end := 0.0          # singularity: final blast multiplier
var hostile := false            # spore clouds hurt the player instead
var hostile_dps := 0.0
var _t := 0.0
var _tick_t := 0.0
var _visual: Node3D


static func spawn(parent: Node, pos: Vector3, opts := {}) -> Node3D:
	var z: Node3D = load("res://src/combat/zone.gd").new()
	for k in opts:
		z.set(k, opts[k])
	parent.add_child(z)
	z.global_position = pos
	return z


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if shape == "wall":
		var p := CPUParticles3D.new()
		p.amount = maxi(12, int(40 * Fx.density()))
		p.lifetime = 0.9
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(wall_length * 0.5, 0.2, 0.3)
		p.direction = Vector3.UP
		p.spread = 15.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.0
		p.gravity = Vector3(0, 1, 0)
		var q := QuadMesh.new()
		q.size = Vector2(1.4, 1.4)
		p.mesh = q
		p.material_override = Fx._particle_mat(Fx.TEX_SMOKE, true, true)
		p.color_ramp = Fx._gradient(color * 2.2, Color(color.r * 0.3, color.g * 0.1, 0, 0))
		p.anim_speed_min = 1.0
		p.anim_speed_max = 1.0
		_visual.add_child(p)
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = radius
		sm.height = radius * (2.0 if hide_player or heal_player > 0 else 0.6)
		sm.radial_segments = 32
		sm.rings = 12
		mi.mesh = sm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/dark_field.gdshader" if hide_player else "res://shaders/energy_field.gdshader")
		mat.set_shader_parameter("color", color)
		mat.set_shader_parameter("noise_tex", Mats.NOISE)
		mat.set_shader_parameter("darkness", 1.0 if hide_player else 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)
		var p := CPUParticles3D.new()
		p.amount = maxi(10, int(30 * Fx.density()))
		p.lifetime = 1.2
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = radius
		var q := QuadMesh.new()
		q.size = Vector2(0.4, 0.4)
		p.mesh = q
		p.material_override = Fx._particle_mat(Fx.TEX_GLOW, true)
		p.color_ramp = Fx._gradient(color * 2.0, Color(color.r, color.g, color.b, 0))
		p.gravity = Vector3.ZERO
		p.radial_accel_min = -radius * 2.0 if pull > 0 else 0.0
		p.radial_accel_max = -radius * 1.0 if pull > 0 else 0.0
		_visual.add_child(p)
		if int(Settings.get_v("quality", 1)) >= 1:
			var l := OmniLight3D.new()
			l.light_color = color
			l.light_energy = 2.0 if not hide_player else 0.0
			l.omni_range = radius * 1.5
			l.position.y = 1.0
			_visual.add_child(l)
	_visual.scale = Vector3.ONE * 0.1
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func contains(p: Vector3) -> bool:
	if shape == "wall":
		var local := global_transform.affine_inverse() * p
		return absf(local.x) <= wall_length * 0.5 and absf(local.z) <= 1.2
	var d := p - global_position
	d.y *= 0.4
	return d.length() <= radius


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t += delta
	_visual.rotation.y += delta * (2.0 if pull > 0 else 0.3)
	var player := get_tree().get_first_node_in_group("player")
	if hostile:
		if player and contains(player.global_position) and not player.spore_immune():
			player.take_damage({"amount": hostile_dps * delta, "source": self, "pos": player.global_position, "kind": "dot", "silent": true})
	else:
		for e in Combat.enemies(get_tree()):
			if not contains(e.global_position):
				continue
			if pull != 0.0 and e.can_be_moved():
				var to = global_position - e.global_position
				to.y = 0
				e.external_push(to.normalized() * pull)
			if hide_player:
				e.apply_status("blind", 0.6)
		if player and heal_player > 0.0 and contains(player.global_position):
			player.heal(heal_player * delta, true)
		if player and hide_player:
			player.domain_hidden = contains(player.global_position)
	if _tick_t >= tick and not hostile:
		_tick_t = 0.0
		for e in Combat.enemies(get_tree()):
			if contains(e.global_position) and mult > 0.0:
				Combat.hit(owner_node, e, mult, {"kind": "dot", "status": status, "status_t": status_t, "color": color})
			elif contains(e.global_position) and status != "":
				e.apply_status(status, status_t)
	if _t >= duration:
		if explode_end > 0.0:
			Fx.explosion(global_position + Vector3.UP, radius * 0.7, color)
			Audio.play_at("explosion", global_position, 0.0)
			for e in Combat.in_radius(get_tree(), global_position, radius):
				Combat.hit(owner_node, e, explode_end, {"kind": "ability", "color": color, "knock": 10.0, "status": "stun", "status_t": 1.0})
		if player and hide_player:
			player.domain_hidden = false
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.25)
		tw.tween_callback(queue_free)
