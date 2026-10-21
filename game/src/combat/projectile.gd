extends Node3D
## Player / enemy projectile: swept-ray collision against the world, proximity test against
## targets, optional explosion and status. Visual = glowing core + trail particles + light.

var owner_node: Node
var velocity := Vector3.ZERO
var mult := 1.0
var color := Color.CYAN
var radius := 0.35
var life := 1.6
var explode := 0.0
var status := ""
var status_t := 3.0
var hostile := false        # true = damages the player (enemy spit, turret…)
var damage_flat := 0.0      # used when hostile
var homing: Node3D
var kind := "ranged"
var pierce := 0


static func spawn(parent: Node, pos: Vector3, vel: Vector3, opts := {}) -> Node3D:
	var p: Node3D = load("res://src/combat/projectile.gd").new()
	for k in opts:
		p.set(k, opts[k])
	p.velocity = vel
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * 0.6
	sm.height = radius * 1.2
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var trail := CPUParticles3D.new()
	trail.amount = maxi(6, int(18 * Fx.density()))
	trail.lifetime = 0.35
	trail.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(radius * 1.6, radius * 1.6)
	trail.mesh = q
	trail.material_override = Fx._particle_mat(Fx.TEX_GLOW, true)
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.3
	trail.color_ramp = Fx._gradient(color * 2.0, Color(color.r, color.g, color.b, 0))
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	trail.scale_amount_curve = c
	add_child(trail)
	if int(Settings.get_v("quality", 1)) >= 2:
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = 1.5
		l.omni_range = 3.5
		add_child(l)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_finish(global_position)
		return
	if homing and is_instance_valid(homing) and homing.alive:
		var want := (homing.global_position + Vector3.UP * homing.aim_height - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, clampf(delta * 6.0, 0, 1))
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Combat.LAYER_WORLD)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if not res.is_empty():
		_finish(res.position)
		return
	global_position = to
	if hostile:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.global_position.distance_to(global_position - Vector3.UP * 1.0) < radius + 0.6:
			pl.take_damage({"amount": damage_flat, "source": owner_node, "pos": global_position, "dir": velocity.normalized(), "status": status})
			_finish(global_position)
		return
	for e in Combat.in_radius(get_tree(), global_position - Vector3.UP * 0.6, radius + 0.2):
		if absf(e.global_position.y + e.aim_height - global_position.y) > e.aim_height + 1.2:
			continue
		Combat.hit(owner_node, e, mult, {"kind": kind, "pos": global_position, "dir": velocity.normalized(), "status": status, "status_t": status_t, "color": color, "knock": 2.0})
		if pierce > 0:
			pierce -= 1
			continue
		_finish(global_position)
		return


func _finish(pos: Vector3) -> void:
	if explode > 0.0:
		Fx.explosion(pos, explode * 0.6, color)
		Audio.play_at("explosion", pos, -4.0)
		if not hostile:
			for e in Combat.in_radius(get_tree(), pos, explode):
				Combat.hit(owner_node, e, mult * 0.8, {"kind": kind, "pos": pos, "status": status, "status_t": status_t, "color": color, "knock": 6.0})
		Events.noise.emit(pos, 18.0, owner_node)
	else:
		Fx.hit_spark(pos, color)
		Audio.play_at("energy_impact", pos, -8.0)
	queue_free()
