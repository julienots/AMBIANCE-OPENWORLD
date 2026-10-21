extends CharacterBody3D
## Base symbiote. Perception (sight cone + raycast line of sight + awareness meter,
## hearing through Events.noise, light), navigation, telegraphed attacks that can be
## dodged, status effects, poise/stagger, weak points, execution, capture and death.
## Families override the hooks (_think, _attack_begin, _attack_hit, weak_point_mult…).

var id := "crawler"
var data: Dictionary
var family := ""
var alive := true
var hp := 40.0
var max_hp := 40.0
var hit_radius := 0.5
var aim_height := 0.5
var poise := 10.0
var _poise_dmg := 0.0
var statuses := {}
var state := "idle"
var _state_t := 0.0
var home := Vector3.ZERO
var patrol_points: Array = []
var _patrol_i := 0
var target: Node3D                  # the player when engaged
var last_known := Vector3.ZERO
var awareness := 0.0                # 0..1, reaches 1 => spotted
var _think_t := 0.0
var _attack_cd := 0.0
var _attack_phase := ""
var _attack_t := 0.0
var _ext_vel := Vector3.ZERO
var _taunt_t := 0.0
var _dot_t := 0.0
var speed := 3.0
var run_speed := 6.0
var leash := 45.0
var model: Node3D
var anim: AnimationPlayer
var mats: Array = []
var agent: NavigationAgent3D
var eyes_height := 1.0
var spawner: Node                   # region spawner that owns this enemy
var _anim_cur := ""
var _heading := 0.0
var _hit_flash := 0.0
var _seen_reported := false
var _onscreen := true
var _lod_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var weak_marker: Node3D
var boss := false
var xp := 10
var gravity_on := true

const LOOPING := ["idle", "walk", "run", "swim", "move", "search", "charge"]


func setup(enemy_id: String, pos: Vector3) -> void:
	id = enemy_id
	data = DB.ENEMIES[id]
	family = data.family
	max_hp = float(data.hp) * _difficulty_scale()
	hp = max_hp
	hit_radius = float(data.radius)
	aim_height = float(data.height) * 0.55
	eyes_height = float(data.height) * 0.85
	poise = float(data.poise)
	speed = float(data.speed)
	run_speed = float(data.run_speed)
	xp = int(data.xp)
	boss = data.get("boss", false)
	position = pos
	home = pos


func _difficulty_scale() -> float:
	var lvl := Game.player_level() if not Game.profile.is_empty() else 1
	return 1.0 + 0.08 * (lvl - 1)


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = Combat.LAYER_ENEMY
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY | Combat.LAYER_PLAYER
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = hit_radius
	cap.height = maxf(float(data.height), hit_radius * 2.0 + 0.1)
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	var root := Node3D.new()
	root.name = "Visual"
	add_child(root)
	model = (load(data.model) as PackedScene).instantiate()
	model.scale = Vector3.ONE * float(data.get("scale", 1.0))
	root.add_child(model)
	mats = Mats.apply(model, true, true)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for n in LOOPING:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.0
	agent.radius = hit_radius
	agent.height = float(data.height)
	agent.avoidance_enabled = false
	add_child(agent)
	var vis := VisibleOnScreenNotifier3D.new()
	vis.aabb = AABB(Vector3(-hit_radius * 2, 0, -hit_radius * 2), Vector3(hit_radius * 4, float(data.height) + 0.5, hit_radius * 4))
	vis.screen_entered.connect(func(): _onscreen = true; if anim: anim.active = true)
	vis.screen_exited.connect(func(): _onscreen = false; if anim and not boss: anim.active = false)
	add_child(vis)
	Events.noise.connect(_on_noise)
	Events.light_flash.connect(_on_light_flash)
	_heading = randf() * TAU
	_last_pos = global_position
	_on_ready()
	play_anim("idle")


func _on_ready() -> void:
	pass


# ---------------------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var player := _player()
	var dist := 999.0
	if player:
		dist = global_position.distance_to(player.global_position)
	# Far away enemies think less often (mobile CPU budget).
	_lod_t -= delta
	var far := dist > 60.0 and not boss
	if far and _lod_t > 0.0:
		return
	if far:
		_lod_t = 0.5
		delta = 0.5
	_tick_status(delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_state_t += delta
	_taunt_t = maxf(0.0, _taunt_t - delta)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		Mats.set_param(mats, "flash", _hit_flash)
	if has_status("stun"):
		_set_state_anim_stun()
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		_apply_motion(delta)
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.15
		_perceive(player, 0.15)
	_think(delta, player)
	if _attack_phase != "":
		_tick_attack(delta, player)
	_apply_motion(delta)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _apply_motion(delta: float) -> void:
	if gravity_on:
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = maxf(velocity.y, -1.0)
	velocity += _ext_vel
	_ext_vel = _ext_vel.move_toward(Vector3.ZERO, delta * 25.0)
	move_and_slide()
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 0.3 and _attack_phase == "":
		_heading = lerp_angle(_heading, atan2(hv.x, hv.z), clampf(delta * 8.0, 0, 1))
	$Visual.rotation.y = _heading


func face_towards(p: Vector3, delta: float, rate := 8.0) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		_heading = lerp_angle(_heading, atan2(d.x, d.z), clampf(delta * rate, 0, 1))


func forward() -> Vector3:
	return Vector3(sin(_heading), 0, cos(_heading))


func set_state(s: String) -> void:
	if s == state:
		return
	state = s
	_state_t = 0.0


func play_anim(n: String, blend := 0.15, spd := 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	if _anim_cur == n and anim.is_playing():
		anim.speed_scale = spd
		return
	_anim_cur = n
	anim.play(n, blend)
	anim.speed_scale = spd


func play_once(n: String, blend := 0.08) -> float:
	if anim == null or not anim.has_animation(n):
		return 0.5
	_anim_cur = n
	anim.play(n, blend)
	anim.seek(0.0, true)
	anim.speed_scale = 1.0
	return anim.get_animation(n).length


# ---------------------------------------------------------------------------- navigation

func move_to(p: Vector3, spd: float, delta: float) -> bool:
	## Moves along the navmesh toward p. Returns true when arrived.
	var flat := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	if flat.length() < 1.0 + hit_radius * 0.5:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
		return true
	if has_status("root"):
		velocity.x = 0
		velocity.z = 0
		return false
	if has_status("slow"):
		spd *= 0.5
	var next := p
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		if agent.target_position.distance_to(p) > 0.8:
			agent.target_position = p
		if not agent.is_navigation_finished():
			next = agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = flat
	dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * spd, 25 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 25 * delta)
	# Unstick: if barely moving while trying to, sidestep.
	_stuck_t += delta
	if _stuck_t > 0.6:
		if global_position.distance_to(_last_pos) < 0.15 * spd:
			_ext_vel += dir.cross(Vector3.UP) * (3.0 if randf() > 0.5 else -3.0)
		_last_pos = global_position
		_stuck_t = 0.0
	return false


func stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 25 * delta)
	velocity.z = move_toward(velocity.z, 0, 25 * delta)


# ---------------------------------------------------------------------------- perception

func can_see(player: Node3D) -> bool:
	if player == null or has_status("blind") or not player.alive:
		return false
	var vis: float = player.visibility()
	if vis <= 0.0:
		return false
	var eye := global_position + Vector3.UP * eyes_height
	var tgt := player.global_position + Vector3.UP * (0.9 if player.crouching else 1.3)
	var to := tgt - eye
	var range_ := float(data.sight) * clampf(vis, 0.2, 1.6)
	if to.length() > range_:
		return false
	var flat := Vector3(to.x, 0, to.z).normalized()
	var fov := float(data.fov)
	if to.length() > 2.5 and rad_to_deg(acos(clampf(flat.dot(forward()), -1.0, 1.0))) > fov * 0.5:
		return false
	if not Combat.has_los(get_world_3d(), eye, tgt):
		return false
	for s in get_tree().get_nodes_in_group("smoke_cloud"):
		if s.blocks(eye, tgt):
			return false
	return true


func _perceive(player: Node3D, dt: float) -> void:
	if player == null:
		return
	if _taunt_t > 0.0:
		target = player
		awareness = 1.0
		last_known = player.global_position
		return
	if can_see(player):
		var d := global_position.distance_to(player.global_position)
		var gain := dt * (2.5 if d < 6.0 else 1.2) * clampf(player.visibility(), 0.3, 1.6)
		awareness = minf(1.0, awareness + gain)
		last_known = player.global_position
		if awareness >= 1.0:
			if target == null:
				_on_spotted(player)
			target = player
	else:
		awareness = maxf(0.0, awareness - dt * 0.25)
		if target and _state_t > 0.0:
			_on_lost_sight(player)


func _on_spotted(player: Node3D) -> void:
	Game.codex_seen(id)
	Events.enemy_spotted_player.emit(self)


func _on_lost_sight(_player: Node3D) -> void:
	pass


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if not alive or source == self:
		return
	var d := global_position.distance_to(pos)
	if d > radius * float(data.hearing):
		return
	heard(pos, source, d)


func heard(pos: Vector3, _source: Node, _dist: float) -> void:
	## Default: go investigate unless already hunting.
	if target == null:
		last_known = pos
		if state in ["idle", "patrol", "return", "search"]:
			set_state("investigate")


func _on_light_flash(pos: Vector3, radius: float, duration: float) -> void:
	if not alive or float(data.get("light_aversion", 0.0)) <= 0.0:
		return
	if global_position.distance_to(pos) < radius:
		on_light(pos, duration)


func on_light(_pos: Vector3, duration: float) -> void:
	apply_status("blind", duration * float(data.light_aversion))


func is_aware_of_player() -> bool:
	return target != null and awareness > 0.5 and not has_status("blind")


func lose_player() -> void:
	target = null
	awareness = 0.0
	if state in ["chase", "attack"]:
		set_state("search")


func taunt(p: Node3D, t: float) -> void:
	_taunt_t = t
	target = p
	awareness = 1.0
	set_state("chase")


# ---------------------------------------------------------------------------- default brain

func _think(delta: float, player: Node3D) -> void:
	## Generic melee hunter. Families override for specific behaviour.
	match state:
		"idle", "patrol":
			if target:
				set_state("chase")
				return
			if patrol_points.is_empty():
				play_anim("idle")
				stop(delta)
				if _state_t > randf_range(3.0, 6.0):
					patrol_points = [home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))]
			else:
				play_anim("walk" if anim and anim.has_animation("walk") else "run", 0.2, 0.8)
				if move_to(patrol_points[_patrol_i], speed, delta):
					_patrol_i = (_patrol_i + 1) % patrol_points.size()
					if patrol_points.size() == 1:
						patrol_points.clear()
						_state_t = 0.0
		"investigate":
			if target:
				set_state("chase")
				return
			play_anim("walk" if anim and anim.has_animation("walk") else "run", 0.2, 0.9)
			if move_to(last_known, speed * 1.2, delta) or _state_t > 10.0:
				set_state("search")
		"search":
			if target:
				set_state("chase")
				return
			play_anim("idle")
			stop(delta)
			_heading += delta * 1.2
			if _state_t > 4.0:
				set_state("return")
		"return":
			if target:
				set_state("chase")
				return
			play_anim("walk" if anim and anim.has_animation("walk") else "run", 0.2, 0.8)
			if move_to(home, speed, delta) or _state_t > 20.0:
				set_state("idle")
		"chase":
			if target == null:
				set_state("search")
				return
			if global_position.distance_to(home) > leash and not can_see(player):
				lose_player()
				return
			var d := global_position.distance_to(target.global_position)
			if d <= float(data.attack_range) and _attack_cd <= 0.0:
				start_attack()
				return
			if _attack_phase == "":
				play_anim("run")
				move_to(target.global_position if awareness > 0.2 else last_known, run_speed, delta)
			if awareness <= 0.0:
				lose_player()
			Audio.request_state("combat", 2.0)
		"stagger":
			stop(delta)
			if _state_t > 1.6:
				set_state("chase" if target else "search")


# ---------------------------------------------------------------------------- attacks

func start_attack(kind := "attack") -> void:
	_attack_phase = "windup"
	_attack_t = 0.0
	velocity.x = 0
	velocity.z = 0
	_attack_begin(kind)


func _attack_begin(_kind: String) -> void:
	play_once("attack")


func windup_time() -> float:
	return 0.38


func _tick_attack(delta: float, player: Node3D) -> void:
	_attack_t += delta
	if player:
		if _attack_phase == "windup":
			face_towards(player.global_position, delta, 10.0)
	stop(delta)
	if _attack_phase == "windup" and _attack_t >= windup_time():
		_attack_phase = "strike"
		_attack_hit(player)
	elif _attack_phase == "strike" and _attack_t >= windup_time() + 0.45:
		_attack_phase = ""
		_attack_cd = float(data.attack_cd) * randf_range(0.8, 1.2)


func _attack_hit(player: Node3D) -> void:
	## Hit resolution at the strike frame: the player may have dodged out of reach.
	if player == null:
		return
	var to := player.global_position - global_position
	var reach := float(data.attack_range) + 0.6
	if to.length() <= reach and forward().dot(Vector3(to.x, 0, to.z).normalized()) > 0.2:
		player.take_damage({"amount": float(data.dmg) * _dmg_scale(), "source": self, "pos": player.global_position + Vector3.UP,
			"dir": to.normalized(), "kind": "melee"})
	_ext_vel += forward() * 4.0


func _dmg_scale() -> float:
	var lvl := Game.player_level() if not Game.profile.is_empty() else 1
	return 1.0 + 0.06 * (lvl - 1)


# ---------------------------------------------------------------------------- damage & status

func weak_point_mult(info: Dictionary) -> float:
	return 1.0


func take_damage(info: Dictionary) -> float:
	if not alive:
		return 0.0
	var amount: float = info.amount
	var wm := weak_point_mult(info)
	amount *= wm
	hp -= amount
	if info.get("kind", "") != "dot":
		_hit_flash = 1.0
		Fx.damage_number(global_position + Vector3.UP * (aim_height + 0.8), amount, info.get("crit", false) or wm > 1.0,
			Color(1, 0.4, 0.3) if wm > 1.0 else Color.WHITE)
		Events.enemy_damaged.emit(self, amount, info.get("crit", false))
		if randf() < 0.5:
			Audio.play_at("hit_flesh", global_position, -6.0)
	if info.get("status", "") != "":
		apply_status(info.status, float(info.get("status_t", 2.0)))
	if float(info.get("knock", 0.0)) > 0.0 and can_be_moved():
		var dir: Vector3 = info.get("dir", Vector3.ZERO)
		dir.y = 0
		_ext_vel += dir.normalized() * float(info.knock) * (0.4 if boss else 1.0)
	# Poise: enough damage in a short time interrupts the attack (stagger).
	_poise_dmg += float(info.get("poise", 10.0))
	if _poise_dmg >= poise and _attack_phase != "" or _poise_dmg >= poise * 1.5:
		_poise_dmg = 0.0
		on_stagger()
	var src = info.get("source")
	if src and src.is_in_group("player") and target == null:
		target = src
		awareness = 1.0
		last_known = src.global_position
		_on_spotted(src)
		set_state("chase")
	if hp <= 0.0:
		die(src)
	return amount


func on_stagger() -> void:
	_attack_phase = ""
	_attack_cd = maxf(_attack_cd, 0.8)
	play_once("hit")
	if not boss:
		set_state("stagger")


func apply_status(s: String, t: float) -> void:
	if boss and s in ["stun", "root"]:
		t *= 0.35
	statuses[s] = maxf(statuses.get(s, 0.0), t)
	if s == "stun":
		_attack_phase = ""


func has_status(s: String) -> bool:
	return statuses.get(s, 0.0) > 0.0


func _tick_status(delta: float) -> void:
	for s in statuses.keys():
		statuses[s] -= delta
		if statuses[s] <= 0.0:
			statuses.erase(s)
	if has_status("burn"):
		_dot_t += delta
		if _dot_t >= 0.5:
			_dot_t = 0.0
			var p := _player()
			if p:
				Combat.hit(p, self, 0.25, {"kind": "dot"})
			Fx.hit_spark(global_position + Vector3.UP * aim_height, Color(1, 0.5, 0.1))


func _set_state_anim_stun() -> void:
	if anim and _anim_cur != "hit" and _anim_cur != "stagger":
		play_once("stagger" if anim.has_animation("stagger") else "hit")


func can_be_moved() -> bool:
	return not boss and float(data.radius) < 1.0


func external_push(v: Vector3) -> void:
	if can_be_moved():
		_ext_vel += v * 0.1


func can_be_executed(threshold: float) -> bool:
	if not alive or boss or id == "devourer":
		return false
	return has_status("stun") or hp <= max_hp * threshold


func can_be_captured() -> bool:
	return alive and not boss and id != "devourer" and has_status("stun") and Game.item_count("capture") > 0


func executed(by: Node) -> void:
	hp = 0.0
	die(by, 1.6)


func captured(by: Node) -> void:
	alive = false
	Audio.play_at("capture", global_position)
	Fx.ring(global_position + Vector3.UP * 0.2, 2.0, Color(0.4, 0.9, 1.0), 0.6)
	Game.profile.base.creatures.append(id)
	Game.profile.stats.captures += 1
	Game.codex_entry(id).studied += 1
	Events.mission_event.emit("capture", id, 1)
	Events.mission_event.emit("capture", "any", 1)
	Events.toast.emit("%s capturé et transféré en confinement" % data.name, "codex")
	_dissolve_and_free(Color(0.3, 0.8, 1.0))


func die(killer = null, drop_mult := 1.0) -> void:
	if not alive:
		return
	alive = false
	_attack_phase = ""
	collision_layer = 0
	velocity = Vector3.ZERO
	if anim and anim.has_animation("death"):
		play_once("death")
	Audio.play_at("dissolve", global_position, -2.0)
	_death_sound()
	var drops := Game.roll_drops(data.drops, drop_mult)
	for k in drops:
		Pickup.spawn(get_parent(), global_position + Vector3.UP * 0.8, k, drops[k])
	Game.add_xp(int(xp * drop_mult))
	Events.enemy_killed.emit(self, id, family)
	if spawner and spawner.has_method("on_enemy_died"):
		spawner.on_enemy_died(self)
	await get_tree().create_timer(0.6).timeout
	_dissolve_and_free(Color(0.85, 0.1, 0.25))


func _death_sound() -> void:
	pass


func _dissolve_and_free(color: Color) -> void:
	Fx.dissolve_burst(global_position + Vector3.UP * aim_height, color, clampf(hit_radius * 1.5, 0.8, 3.0))
	var tw := create_tween()
	tw.tween_method(func(v): Mats.set_param(mats, "dissolve", v), 0.0, 1.0, 1.2)
	tw.tween_callback(queue_free)
