extends "res://src/enemies/enemy.gd"
## THE DEVOURER — signature horror predator.
##
## Rules it follows (no cheating):
##  - It only knows where the player is through sight (cone + line of sight, modulated by
##    the player's visibility), hearing (Events.noise) and the player's recent trail.
##  - It never teleports: vents are real shortcuts with a travel time, and its passage is
##    audible (rattling moves along the duct).
##  - Closed doors cost it time (it must break them); barricades even more.
##  - Flares blind it and drive it back. Smoke, darkness, hiding spots break its tracking.
##  - It cannot be killed in free roam: the player must flee, hide or outsmart it.

const CHASE_RAMP := 10.0            # seconds to reach max chase speed
const LOSE_TIME := 4.0              # seconds without contact before it gives up the chase

var territory: Array = []           # patrol points (Vector3)
var vents: Array = []               # vent nodes in its territory
var sealed := false                 # mission: trapped in containment
var invulnerable := true
var _chase_t := 0.0
var _no_contact_t := 0.0
var _linger_t := 0.0
var _search_points: Array = []
var _vent_from: Node3D
var _vent_to: Node3D
var _vent_t := 0.0
var _vent_total := 0.0
var _rattle_t := 0.0
var _bash_door: Node
var _bash_t := 0.0
var _click_t := 0.0
var _step_t := 0.0
var _breath: AudioStreamPlayer3D
var _smoke: CPUParticles3D
var _check_spot: Node3D
var _grab_recover := 0.0
var _scream_cd := 0.0
var _threat := 0.0


func _on_ready() -> void:
	_smoke = Fx.symbiote_smoke($Visual, Color(0.02, 0.01, 0.03, 0.8), 1.6, 22, 3.0)
	_breath = Audio.attach_loop(self, "devourer_breath", 0.0, 22.0)
	add_to_group("devourer")
	leash = 1e9
	set_state("patrol")
	Mats.set_param(mats, "vein_strength", 0.6)


# ------------------------------------------------------------------------------ perception

func can_see(player: Node3D) -> bool:
	if sealed or state in ["vent", "stunned_light"]:
		return false
	return super.can_see(player)


func _perceive(player: Node3D, dt: float) -> void:
	if player == null or sealed:
		return
	if state == "chase" and target:
		if can_see(player):
			_no_contact_t = 0.0
			last_known = player.global_position
		else:
			_no_contact_t += dt
		return
	if can_see(player):
		var d := global_position.distance_to(player.global_position)
		awareness += dt * (3.0 if d < 8.0 else 1.1) * clampf(player.visibility(), 0.3, 1.6)
		last_known = player.global_position
		if state in ["patrol", "linger", "return"] and awareness > 0.25:
			set_state("investigate")
		if awareness >= 1.0:
			_start_chase(player)
	else:
		awareness = maxf(0.0, awareness - dt * 0.15)


func heard(pos: Vector3, source: Node, dist: float) -> void:
	if sealed or state in ["chase", "attack", "vent", "stunned_light", "grab_recover"]:
		if state == "chase" and source and source.is_in_group("player"):
			last_known = pos
			_no_contact_t = maxf(0.0, _no_contact_t - 1.0)
		return
	last_known = pos
	awareness = maxf(awareness, 0.4)
	# Loud noises close by trigger the hunt immediately.
	if source and source.is_in_group("player") and dist < 6.0:
		_start_chase(source)
		return
	set_state("investigate")
	_head_twitch()


func on_light(pos: Vector3, duration: float) -> void:
	if sealed:
		return
	var mult := 2.0 if Game.has_research("uv_flares") else 1.0
	set_state("stunned_light")
	_attack_phase = ""
	play_once("stunned")
	Audio.play_at("devourer_scream", global_position, -2.0, 70.0)
	statuses["blind"] = 3.0 * mult
	_linger_t = 3.0 * mult
	last_known = global_position + (global_position - pos).normalized() * 12.0
	Events.toast.emit("Le Dévoreur est aveuglé !", "counter")


func _start_chase(player: Node3D) -> void:
	if state == "chase":
		return
	target = player
	awareness = 1.0
	_chase_t = 0.0
	_no_contact_t = 0.0
	set_state("chase")
	Game.codex_seen(id)
	Events.enemy_spotted_player.emit(self)
	Events.devourer_state.emit("chase")
	if _scream_cd <= 0.0:
		_scream_cd = 20.0
		play_once("scream")
		Audio.play_at("devourer_scream", global_position, 4.0, 90.0)
		Audio.scare("jumpscare", -6.0)
		Events.jumpscare.emit(1.0)
		_attack_cd = 1.4


func lose_player() -> void:
	# Invisibility, dark domain…: it goes to the last place it knew about.
	if state == "chase":
		_begin_search()


func taunt(_p: Node3D, _t: float) -> void:
	pass


# ------------------------------------------------------------------------------ brain

func _think(delta: float, player: Node3D) -> void:
	_scream_cd = maxf(0.0, _scream_cd - delta)
	_update_threat(player, delta)
	if sealed:
		stop(delta)
		play_anim("idle", 0.3, 0.6)
		return
	_click_t -= delta
	if _click_t <= 0.0 and state in ["investigate", "search", "check_hide", "chase"]:
		_click_t = randf_range(2.0, 4.5)
		Audio.play_at("devourer_click", global_position + Vector3.UP * 3.0, 0.0, 35.0)
	if state != "vent" and Vector2(velocity.x, velocity.z).length() > 1.0:
		_step_t -= delta * Vector2(velocity.x, velocity.z).length()
		if _step_t <= 0.0:
			_step_t = 2.4
			Audio.play_at("devourer_step", global_position, -2.0, 30.0)
			Fx.add_shake(0.05 if player and player.global_position.distance_to(global_position) < 12.0 else 0.0)
	if _bash_door:
		_do_bash(delta)
		return
	match state:
		"patrol": _patrol(delta)
		"linger": _linger(delta)
		"investigate": _investigate(delta)
		"chase": _chase(delta, player)
		"search": _search(delta)
		"check_hide": _check_hide(delta, player)
		"return": _return(delta)
		"vent": _vent_travel(delta)
		"stunned_light":
			stop(delta)
			_linger_t -= delta
			if _linger_t <= 0.0:
				set_state("flee")
		"flee":
			play_anim("run", 0.2, 0.8)
			if move_to(last_known, run_speed, delta) or _state_t > 5.0:
				_begin_search()
		"grab_recover":
			stop(delta)
			play_anim("idle", 0.2, 0.5)
			_grab_recover -= delta
			if _grab_recover <= 0.0:
				_chase_t = 0.0
				set_state("chase" if target else "search")


func _update_threat(player: Node3D, delta: float) -> void:
	if player == null:
		return
	var d := global_position.distance_to(player.global_position)
	var t := 0.0
	if state == "chase":
		t = 1.0
	elif d < 30.0:
		t = clampf(1.0 - d / 30.0, 0.0, 1.0) * 0.8
	_threat = lerpf(_threat, t, delta * 2.0)
	Events.threat_level.emit(_threat)
	if state == "chase":
		Audio.request_state("chase", 3.0)
	elif d < 26.0:
		Audio.request_state("silence", 2.0)
	if _breath:
		_breath.volume_db = -2.0 if state != "chase" else 4.0


func _patrol(delta: float) -> void:
	if territory.is_empty():
		_linger_t = 5.0
		set_state("linger")
		return
	play_anim("walk", 0.3, 0.9)
	if move_to(territory[_patrol_i], speed, delta):
		_patrol_i = (_patrol_i + randi_range(1, territory.size() - 1)) % territory.size() if territory.size() > 1 else 0
		_linger_t = randf_range(3.0, 9.0)
		set_state("linger")
		_maybe_use_vent(territory[_patrol_i])


func _linger(delta: float) -> void:
	# Long unnatural stillness, interrupted by head twitches.
	stop(delta)
	play_anim("idle", 0.4)
	_linger_t -= delta
	if _linger_t <= 0.0:
		set_state("patrol")


func _investigate(delta: float) -> void:
	play_anim("walk", 0.25, 1.1)
	if _maybe_use_vent(last_known):
		return
	if move_to(last_known, speed * 1.4, delta) or _state_t > 14.0:
		_begin_search()


func _chase(delta: float, player: Node3D) -> void:
	if target == null:
		_begin_search()
		return
	_chase_t += delta
	var ramp := clampf(_chase_t / CHASE_RAMP, 0.0, 1.0)
	var spd := lerpf(run_speed, float(data.max_run_speed), ramp)
	var d := global_position.distance_to(target.global_position)
	if target.state == "hidden":
		# It did not necessarily see where the player went.
		if target.seen_entering_hide and target.hiding_spot:
			_check_spot = target.hiding_spot
			set_state("check_hide")
		else:
			_begin_search()
		return
	if not target.alive:
		_begin_search()
		return
	if d < float(data.attack_range) and _attack_cd <= 0.0 and _attack_phase == "" and can_see(player):
		start_attack()
		return
	if _no_contact_t > LOSE_TIME:
		_begin_search()
		return
	if _attack_phase == "":
		play_anim("run", 0.15, 0.8 + 0.5 * ramp)
		if d > 18.0 and _maybe_use_vent(last_known):
			return
		move_to(last_known if _no_contact_t > 0.2 else target.global_position, spd, delta)
		_check_doors()


func _begin_search() -> void:
	set_state("search")
	Events.devourer_state.emit("search")
	_search_points.clear()
	_search_points.append(last_known)
	# Recent player trail near the last known position.
	var w := get_tree().get_first_node_in_group("world")
	if w and w.has_method("recent_trail"):
		for p in w.recent_trail(last_known, 14.0, 30.0):
			if _search_points.size() < 5:
				_search_points.append(p)
	# A hiding spot or two around.
	var spots := get_tree().get_nodes_in_group("hide_spot").filter(func(s): return s.global_position.distance_to(last_known) < 12.0)
	spots.shuffle()
	for s in spots.slice(0, 2):
		_search_points.append(s)
	target = null


func _search(delta: float) -> void:
	if _search_points.is_empty():
		set_state("return")
		Events.devourer_state.emit("return")
		return
	var p = _search_points[0]
	if p is Node3D:
		if move_to(p.global_position, speed * 1.2, delta):
			_check_spot = p
			_search_points.pop_front()
			set_state("check_hide")
		else:
			play_anim("walk", 0.2, 1.0)
		return
	if move_to(p, speed * 1.3, delta):
		_search_points.pop_front()
		_linger_t = 2.5
		play_anim("search", 0.3)
	else:
		play_anim("walk", 0.2, 1.0)
	if _state_t > 40.0:
		set_state("return")


func _check_hide(delta: float, player: Node3D) -> void:
	stop(delta)
	if _check_spot == null or not is_instance_valid(_check_spot):
		set_state("search")
		return
	face_towards(_check_spot.global_position, delta, 3.0)
	play_anim("search", 0.3)
	if _state_t < 3.0:
		return
	var found := false
	if player and player.state == "hidden" and player.hiding_spot == _check_spot:
		# It finds the player only if it saw them enter or if they made noise inside.
		found = player.seen_entering_hide or randf() < 0.12
	if found:
		player.exit_hiding()
		_start_chase(player)
		start_attack()
	else:
		set_state("search")


func _return(delta: float) -> void:
	play_anim("walk", 0.3, 0.9)
	var home_pt: Vector3 = territory[0] if not territory.is_empty() else home
	if move_to(home_pt, speed, delta) or _state_t > 40.0:
		set_state("patrol")
		Events.devourer_state.emit("patrol")


# ------------------------------------------------------------------------------ vents

func _maybe_use_vent(goal: Vector3) -> bool:
	if vents.is_empty():
		return false
	var direct := global_position.distance_to(goal)
	if direct < 15.0:
		return false
	for v in vents:
		if v.linked == null:
			continue
		var via: float = global_position.distance_to(v.global_position) + v.global_position.distance_to(v.linked.global_position) * 0.5 + v.linked.global_position.distance_to(goal)
		if via < direct * 0.6 and global_position.distance_to(v.global_position) < 10.0:
			_vent_from = v
			_vent_to = v.linked
			_go_vent_entry()
			return true
	return false


func _go_vent_entry() -> void:
	# Walk to the vent, then crawl in.
	set_state("vent")
	_vent_t = -1.0


func _vent_travel(delta: float) -> void:
	if _vent_t < 0.0:
		play_anim("run", 0.2, 0.8)
		if move_to(_vent_from.global_position, run_speed, delta) or _state_t > 8.0:
			$Visual.visible = false
			collision_layer = 0
			_vent_total = _vent_from.global_position.distance_to(_vent_to.global_position) / 6.0 + 1.5
			_vent_t = 0.0
			_vent_from.rattle()
		return
	_vent_t += delta
	_rattle_t -= delta
	var f := clampf(_vent_t / _vent_total, 0.0, 1.0)
	var pos := _vent_from.global_position.lerp(_vent_to.global_position, f) + Vector3.UP * 2.5
	if _rattle_t <= 0.0:
		_rattle_t = 0.9
		Audio.play_at("devourer_vent", pos, 2.0, 40.0)
	velocity = Vector3.ZERO
	if _vent_t >= _vent_total:
		global_position = _vent_to.exit_position()
		$Visual.visible = true
		collision_layer = Combat.LAYER_ENEMY
		_vent_to.rattle()
		Audio.play_at("metal_creak", global_position, 0.0)
		set_state("chase" if target else "investigate")


# ------------------------------------------------------------------------------ doors

func _check_doors() -> void:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, global_position + Vector3.UP * 1.2 + forward() * 1.6, Combat.LAYER_WORLD)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var c: Node = r.collider
	while c and not c.is_in_group("door"):
		c = c.get_parent()
	if c and c.has_method("is_closed") and c.is_closed():
		_bash_door = c
		_bash_t = c.bash_time()


func _do_bash(delta: float) -> void:
	stop(delta)
	face_towards(_bash_door.global_position, delta, 5.0)
	_bash_t -= delta
	if fmod(_bash_t, 0.8) < delta:
		play_once("attack")
		Audio.play_at("door_slam", _bash_door.global_position, 0.0, 50.0)
		Fx.add_shake(0.15)
		Events.noise.emit(_bash_door.global_position, 20.0, self)
	if _bash_t <= 0.0:
		_bash_door.force_open(forward())
		_bash_door = null


# ------------------------------------------------------------------------------ attack

func windup_time() -> float:
	return 0.55


func _attack_begin(_k: String) -> void:
	play_once("attack")
	Audio.play_at("devourer_scream", global_position, -6.0)


func _attack_hit(player: Node3D) -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	_ext_vel += forward() * 7.0
	if to.length() <= float(data.attack_range) + 0.8 and forward().dot(Vector3(to.x, 0, to.z).normalized()) > 0.1:
		var dealt: float = player.take_damage({"amount": float(data.dmg), "source": self, "dir": to.normalized(), "kind": "melee", "knockdown": true})
		if dealt > 0.0:
			Events.jumpscare.emit(0.8)
			# A brief respite after a hit: the player has a real chance to run.
			_grab_recover = 2.2
			set_state("grab_recover")


func take_damage(info: Dictionary) -> float:
	if invulnerable:
		_hit_flash = 0.6
		if info.get("kind", "") != "dot" and randf() < 0.3:
			Events.toast.emit("Vos attaques ne l'arrêtent pas. Fuyez !", "warn")
		var src = info.get("source")
		if src and src.is_in_group("player"):
			_start_chase(src)
			last_known = src.global_position
		return 0.0
	return super.take_damage(info)


func _head_twitch() -> void:
	if anim and _attack_phase == "":
		play_anim("search", 0.1)


func can_be_moved() -> bool:
	return false


func seal() -> void:
	sealed = true
	target = null
	_attack_phase = ""
	Events.devourer_state.emit("sealed")
	Events.threat_level.emit(0.0)
