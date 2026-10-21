extends Node3D
## Thrown items: flare (light + blinds the Devourer), decoy (noise lure),
## smoke (blocks lines of sight), mine (explodes on creatures).

var kind := "flare"
var vel := Vector3.ZERO
var thrower: Node
var landed := false
var _t := 0.0
var _life := 20.0
var _light: OmniLight3D
var _noise_t := 0.0
var _fx: Node3D
var _radius := 4.5


func throw(v: Vector3, by: Node) -> void:
	vel = v
	thrower = by


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.3
	mi.mesh = cm
	var col := {"flare": Color(1, 0.2, 0.15), "decoy": Color(0.2, 0.8, 1), "smoke": Color(0.6, 0.6, 0.6), "mine": Color(1, 0.8, 0.1)}[kind]
	mi.material_override = Mats.toon(col, 2.0)
	add_child(mi)
	if kind == "smoke":
		add_to_group("smoke_cloud")
	_life = {"flare": 20.0 * (2.0 if Game.has_research("uv_flares") else 1.0), "decoy": 8.0, "smoke": 10.0, "mine": 120.0}[kind]


func _physics_process(delta: float) -> void:
	_t += delta
	if not landed:
		vel.y -= 16.0 * delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, Combat.LAYER_WORLD)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty():
			global_position = to
		else:
			global_position = r.position + r.normal * 0.08
			landed = true
			_on_land()
		return
	_life -= delta
	match kind:
		"flare":
			if _light:
				_light.light_energy = 3.5 + randf_range(-0.6, 0.6)
			if fmod(_t, 1.0) < delta:
				Events.light_flash.emit(global_position, 9.0, 3.0)
		"decoy":
			_noise_t -= delta
			if _noise_t <= 0.0:
				_noise_t = 1.0
				Audio.play_at("decoy_beep", global_position, 0.0, 50.0)
				Events.noise.emit(global_position, 30.0, self)
		"mine":
			for e in Combat.in_radius(get_tree(), global_position, 1.8):
				Fx.explosion(global_position, 2.5, Color(1, 0.6, 0.2))
				Audio.play_at("explosion", global_position)
				for e2 in Combat.in_radius(get_tree(), global_position, 4.0):
					if is_instance_valid(thrower):
						Combat.hit(thrower, e2, 4.0, {"kind": "ability", "knock": 10.0, "status": "stun", "status_t": 1.5})
				queue_free()
				return
	if _life <= 0.0:
		if _fx:
			_fx.emitting = false
		var tw := create_tween()
		if _light:
			tw.tween_property(_light, "light_energy", 0.0, 0.6)
		tw.tween_callback(queue_free)
		set_physics_process(false)


func _on_land() -> void:
	match kind:
		"flare":
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.25, 0.15)
			_light.light_energy = 3.5
			_light.omni_range = 10.0
			_light.position.y = 0.4
			add_child(_light)
			add_to_group("light_source")
			_fx = CPUParticles3D.new()
			_fx.amount = 24
			_fx.lifetime = 1.2
			var q := QuadMesh.new()
			q.size = Vector2(0.5, 0.5)
			_fx.mesh = q
			_fx.material_override = Fx._particle_mat(Fx.TEX_SMOKE, true, true)
			_fx.color_ramp = Fx._gradient(Color(2.0, 0.5, 0.3, 0.8), Color(0.3, 0.1, 0.1, 0))
			_fx.direction = Vector3.UP
			_fx.initial_velocity_max = 1.5
			_fx.anim_speed_min = 1.0
			_fx.anim_speed_max = 1.0
			add_child(_fx)
			Audio.play_at("flare_ignite", global_position)
			Audio.attach_loop(self, "flare_loop", -6.0, 15.0)
			Events.light_flash.emit(global_position, 9.0, 3.0)
		"smoke":
			Fx.smoke_puff(global_position + Vector3.UP, Color(0.55, 0.55, 0.58, 0.9), 4.0, 26)
			Audio.play_at("flare_ignite", global_position, -2.0)
			_fx = CPUParticles3D.new()
			_fx.amount = 30
			_fx.lifetime = 3.0
			var q := QuadMesh.new()
			q.size = Vector2(3.5, 3.5)
			_fx.mesh = q
			_fx.material_override = Fx._particle_mat(Fx.TEX_SMOKE, false, true)
			_fx.color_ramp = Fx._gradient(Color(0.55, 0.55, 0.6, 0.85), Color(0.5, 0.5, 0.55, 0))
			_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			_fx.emission_sphere_radius = 2.5
			_fx.initial_velocity_max = 0.4
			_fx.anim_speed_min = 0.3
			_fx.anim_speed_max = 0.3
			_fx.position.y = 1.2
			add_child(_fx)
		"decoy":
			Audio.play_at("decoy_beep", global_position)
		"mine":
			Audio.play_at("build_place", global_position, -6.0)


func light_at(p: Vector3) -> float:
	if kind != "flare" or not landed or _life <= 0.0:
		return 0.0
	return clampf(1.2 - p.distance_to(global_position) / 9.0, 0.0, 1.0)


func blocks(a: Vector3, b: Vector3) -> bool:
	## Smoke: does segment a-b pass through the cloud?
	if kind != "smoke" or not landed or _life <= 0.0:
		return false
	var c := global_position + Vector3.UP * 1.2
	var ab := b - a
	var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(c) < _radius
