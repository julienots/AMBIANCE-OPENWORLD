extends CharacterBody3D
## The playable hero. Reads Pad, moves relative to the camera, fights (combos, heavy
## attacks, dodge with perfect-dodge counters, 3 abilities + ultimate), sneaks (noise,
## visibility, hiding spots), uses items and interacts with the world.

const Projectile := preload("res://src/combat/projectile.gd")

signal hero_changed

var hero_id := "vortex"
var hero: Dictionary
var stats: Dictionary
var alive := true

# Resources
var hp := 100.0
var max_hp := 100.0
var energy := 100.0
var max_energy := 100.0
var stamina := 100.0
var max_stamina := 100.0
var ult := 0.0                      # 0..100
var shield_hp := 0.0
var shield_t := 0.0
var cooldowns := [0.0, 0.0, 0.0]
var temp_def := 0.0
var temp_def_t := 0.0
var _hot := 0.0                     # heal over time remaining
var _hot_rate := 0.0
var second_wind_used := false

# State
var state := "move"                 # move | attack | heavy | action | dodge | hidden | dead | stunned | execute
var sprinting := false
var crouching := false
var flashlight_on := false
var invisible_t := 0.0
var domain_hidden := false
var transformed := false
var transform_mult := 1.0
var _transform_t := 0.0
var _iframes := 0.0
var _perfect_t := 0.0
var _counter_t := 0.0
var _action_t := 0.0
var _combo := 0
var _combo_window := 0.0
var _attack_hit_done := true
var _attack_hit_t := 0.0
var _attack_mult := 1.0
var _shots := 0
var _stamina_delay := 0.0
var _dash_vel := Vector3.ZERO
var _dash_t := 0.0
var _phase := false
var _ext_vel := Vector3.ZERO
var _step_dist := 0.0
var _heading := 0.0
var _no_damage_t := 0.0
var combo_count := 0
var _combo_decay := 0.0
var current_target: Node3D
var portal_point := Vector3.INF
var _portal_fx: Node3D
var hiding_spot: Node3D
var seen_entering_hide := false
var interact_target: Node
var item_index := 0
var last_safe_pos := Vector3.ZERO
var stunned_t := 0.0
var in_light := 0.0

@onready var visual: Node3D = $Visual
@onready var model_root: Node3D = $Visual/ModelRoot
@onready var flashlight: SpotLight3D = $Visual/Flashlight
@onready var cam_rig: Node3D = get_node_or_null("../CameraRig")
var model: Node3D
var anim: AnimationPlayer
var _mats: Array = []
var _shield_mesh: MeshInstance3D

const LOOPS := ["idle", "run", "sprint", "crouch", "pose", "block"]
const ITEM_ORDER := ["flare", "medkit", "decoy", "smoke", "cell", "barricade", "capture", "mine"]


func _ready() -> void:
	add_to_group("player")
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	setup_hero(Game.profile.get("active_hero", "vortex") if not Game.profile.is_empty() else "vortex")
	_shield_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.3
	_shield_mesh.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/energy_field.gdshader")
	m.set_shader_parameter("noise_tex", Mats.NOISE)
	_shield_mesh.material_override = m
	_shield_mesh.position.y = 1.0
	_shield_mesh.visible = false
	_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield_mesh)
	last_safe_pos = global_position
	# Soft fill light that keeps the hero readable in dark places (no shadows: cheap).
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.75, 0.8, 1.0)
	fill.light_energy = 0.55
	fill.omni_range = 4.5
	fill.position = Vector3(0, 2.2, 1.2)
	fill.light_specular = 0.0
	add_child(fill)


func setup_hero(id: String) -> void:
	hero_id = id
	hero = DB.HEROES[id]
	stats = Game.hero_stats(id) if not Game.profile.is_empty() else hero.stats.duplicate()
	if not stats.has("atk_mult"):
		stats.merge({"crit": 0.05, "cdr": 0.0, "ability_mult": 0.0, "ult_gain": 0.0, "noise_mult": 0.0, "energy_regen": 0.0,
			"execute_threshold": 0.15, "perfect_window": 0.0, "finisher_mult": 0.0, "second_wind": 0, "spore_immune": 0, "heavy_stun": 0})
	max_hp = stats.hp
	max_energy = stats.energy
	max_stamina = 100.0 * (float(hero.passive.mult) if hero.passive.kind == "stamina" else 1.0)
	hp = max_hp
	energy = max_energy
	stamina = max_stamina
	if model:
		model.queue_free()
	model = (load(hero.model) as PackedScene).instantiate()
	model_root.add_child(model)
	_mats = Mats.apply(model, true, id == "porteur")
	Mats.set_param(_mats, "power_color", hero.color)
	var skin: String = Game.hero_state(id).get("skin", "default") if not Game.profile.is_empty() else "default"
	Mats.set_param(_mats, "hue_shift", {"default": 0.0, "eclipse": 0.0, "prisme": 2.2}[skin])
	Mats.set_param(_mats, "skin_dark", 0.6 if skin == "eclipse" else 0.0)
	anim = model.find_child("AnimationPlayer", true, false)
	for n in LOOPS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim.play("idle")
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	hero_changed.emit()


# ------------------------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if not alive:
		_apply_gravity(delta)
		move_and_slide()
		return
	_tick_timers(delta)
	match state:
		"hidden":
			_hidden_update(delta)
			return
		"stunned":
			stunned_t -= delta
			velocity.x = move_toward(velocity.x, 0, delta * 20)
			velocity.z = move_toward(velocity.z, 0, delta * 20)
			if stunned_t <= 0:
				state = "move"
		"execute":
			velocity = Vector3.ZERO
			return
	_update_target()
	_read_combat_input()
	_move(delta)
	_footsteps(delta)
	_update_interact()
	_update_light_level()
	if is_on_floor() and state == "move":
		last_safe_pos = global_position


func _tick_timers(delta: float) -> void:
	for i in 3:
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_perfect_t = maxf(0.0, _perfect_t - delta)
	_counter_t = maxf(0.0, _counter_t - delta)
	_combo_window = maxf(0.0, _combo_window - delta)
	_no_damage_t += delta
	energy = minf(max_energy, energy + delta * 4.0 * (1.0 + float(stats.get("energy_regen", 0.0))))
	_stamina_delay -= delta
	if not sprinting and _stamina_delay <= 0.0:
		stamina = minf(max_stamina, stamina + delta * 22.0)
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield_hp = 0.0
	_shield_mesh.visible = shield_hp > 0.0
	if temp_def_t > 0.0:
		temp_def_t -= delta
		if temp_def_t <= 0.0:
			temp_def = 0.0
	if _hot > 0.0:
		var h := minf(_hot, _hot_rate * delta)
		_hot -= h
		heal(h, true)
	if invisible_t > 0.0:
		invisible_t -= delta
		if invisible_t <= 0.0:
			_set_model_alpha(1.0)
	if transformed:
		_transform_t -= delta
		if _transform_t <= 0.0:
			transformed = false
			model_root.scale = Vector3.ONE
			Mats.set_param(_mats, "power_glow", 0.0)
	if _combo_decay > 0.0:
		_combo_decay -= delta
		if _combo_decay <= 0.0 and combo_count > 0:
			combo_count = 0
			Events.combo_changed.emit(0)
	if _action_t > 0.0:
		_action_t -= delta
		if _action_t <= 0.0 and state in ["action", "attack", "heavy"]:
			state = "move"
	if state == "attack" and not _attack_hit_done:
		_attack_hit_t -= delta
		if _attack_hit_t <= 0.0:
			_attack_hit_done = true
			_do_melee_hit()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)


# ------------------------------------------------------------------------------- movement

func _cam_axes() -> Array:
	if cam_rig:
		return [cam_rig.forward_flat(), cam_rig.right_flat()]
	return [Vector3.FORWARD, Vector3.RIGHT]


func input_dir() -> Vector3:
	var ax := _cam_axes()
	var m := Pad.move
	var d: Vector3 = ax[1] * m.x + ax[0] * (-m.y)
	return d


func _move(delta: float) -> void:
	_apply_gravity(delta)
	var dir := input_dir()
	var mag := minf(1.0, Pad.move.length())
	if Pad.consume("crouch"):
		crouching = not crouching
	if Pad.consume("flashlight"):
		toggle_flashlight()
	var want_sprint = (Pad.held("sprint_hold") or (Settings.get_v("auto_sprint", true) and mag > 0.96)) and not crouching
	sprinting = want_sprint and stamina > 1.0 and mag > 0.3 and state == "move"
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 20.0)
		_stamina_delay = 0.8
	var speed: float = stats.speed
	if transformed:
		speed *= 1.15
	if crouching:
		speed *= 0.5
	elif sprinting:
		speed *= 1.5
	if state in ["attack", "heavy", "action"]:
		speed *= 0.25
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity.x = _dash_vel.x
		velocity.z = _dash_vel.z
		if _dash_t <= 0.0:
			collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	elif state == "dodge":
		velocity.x = _dash_vel.x
		velocity.z = _dash_vel.z
		_dash_vel = _dash_vel.move_toward(Vector3.ZERO, delta * 14.0)
	else:
		var target_v := dir * speed * mag
		var accel := 30.0 if is_on_floor() else 8.0
		velocity.x = move_toward(velocity.x, target_v.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_v.z, accel * delta)
	velocity += _ext_vel
	_ext_vel = _ext_vel.move_toward(Vector3.ZERO, delta * 30.0)
	move_and_slide()
	_try_step_up(dir, mag)
	# Facing
	var face := Vector3.ZERO
	if state in ["attack", "heavy", "action"] and current_target:
		face = current_target.global_position - global_position
	elif Vector3(velocity.x, 0, velocity.z).length() > 0.3 and state != "dodge":
		face = Vector3(velocity.x, 0, velocity.z)
	if face.length() > 0.01:
		_heading = lerp_angle(_heading, atan2(-face.x, -face.z), clampf(delta * 14.0, 0, 1))
	visual.rotation.y = _heading
	_update_locomotion_anim(mag)
	if global_position.y < -40.0:
		global_position = last_safe_pos + Vector3.UP
		velocity = Vector3.ZERO


func _try_step_up(dir: Vector3, mag: float) -> void:
	## Climbs ledges up to 1.1 m (dug tunnels, rubble) when pushing against them.
	if not is_on_wall() or mag < 0.3 or state != "move" or not is_on_floor():
		return
	var fwd := dir.normalized() * 0.45
	var raised := global_transform.translated(Vector3.UP * 1.1)
	if test_move(global_transform, Vector3.UP * 1.1):
		return
	if test_move(raised, fwd):
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.15 + fwd, global_position + fwd + Vector3.UP * 0.05, Combat.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	global_position = hit.position + Vector3.UP * 0.05
	velocity.y = 0.0


func move_heading() -> float:
	return _heading


func facing() -> Vector3:
	return Vector3(-sin(_heading), 0, -cos(_heading))


func aim_direction() -> Vector3:
	if current_target and is_instance_valid(current_target):
		var d := current_target.global_position - global_position
		d.y = 0
		if d.length() > 0.1:
			return d.normalized()
	var dir := input_dir()
	if dir.length() > 0.2:
		return dir.normalized()
	return facing()


func muzzle_position() -> Vector3:
	return global_position + Vector3.UP * 1.25 + aim_direction() * 0.6


func _update_locomotion_anim(mag: float) -> void:
	if state != "move" or anim == null:
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var want := "idle"
	var spd := 1.0
	if crouching:
		want = "crouch"
		spd = clampf(hspeed / 2.0, 0.0, 1.4)
	elif hspeed > 0.5:
		want = "sprint" if sprinting else "run"
		spd = clampf(hspeed / (stats.speed * (1.5 if sprinting else 1.0)), 0.5, 1.4)
	if anim.current_animation != want:
		anim.play(want, 0.15)
	anim.speed_scale = spd


func play_action(name: String, lock := 0.4, blend := 0.08) -> void:
	if anim == null or not anim.has_animation(name):
		return
	anim.play(name, blend)
	anim.speed_scale = 1.0
	anim.seek(0.0, true)
	_action_t = lock
	if state == "move":
		state = "action"


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed < 0.5:
		return
	_step_dist += hspeed * delta
	var stride := 1.6 if sprinting else (0.9 if crouching else 1.25)
	if _step_dist >= stride:
		_step_dist = 0.0
		var surf := _surface()
		var vol := -10.0 if not crouching else -24.0
		if sprinting:
			vol = -5.0
		Audio.play_at("step_" + surf, global_position, vol, 25.0, 0.1)
		var r := 1.2 if crouching else (14.0 if sprinting else 7.0)
		r *= 1.0 + float(stats.get("noise_mult", 0.0))
		Events.noise.emit(global_position, r, self)


func _surface() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.6, Combat.LAYER_WORLD)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return "concrete"
	var c: Object = res.collider
	if c.has_meta("surface"):
		return c.get_meta("surface")
	return "concrete"


func external_push(v: Vector3) -> void:
	_ext_vel += v


# ------------------------------------------------------------------------------- combat input

func _update_target() -> void:
	var dir := aim_direction() if Pad.move.length() < 0.2 else input_dir()
	var keep = current_target and is_instance_valid(current_target) and current_target.alive \
		and current_target.global_position.distance_to(global_position) < 16.0
	if not keep:
		current_target = Combat.best_target(get_tree(), global_position, dir if dir.length() > 0.1 else facing(), 14.0, 140.0)
	if cam_rig:
		cam_rig.mode = "combat" if current_target else ("interior" if state == "hidden" else "explore")


func lock_target() -> Node3D:
	return current_target if current_target and float(Settings.get_v("aim_assist", 0.7)) > 0.05 else null


func _read_combat_input() -> void:
	if Pad.consume("dodge"):
		_try_dodge()
	if state in ["dodge", "stunned"]:
		return
	if Pad.consume("attack"):
		_attack()
	if Pad.consume("heavy"):
		_heavy()
	for i in 3:
		if Pad.consume("ability%d" % (i + 1)):
			use_ability(i)
	if Pad.consume("ultimate"):
		use_ultimate()
	if Pad.consume("interact"):
		_interact()
	if Pad.consume("item"):
		use_item()
	if Pad.consume("item_next"):
		cycle_item()


func _attack() -> void:
	if state == "heavy" or (state == "attack" and _combo_window <= 0.0 and _action_t > 0.12):
		return
	break_invisibility()
	var prim: Dictionary = hero.primary
	if prim.kind == "melee":
		if _combo_window > 0.0 and state == "attack":
			_combo = (_combo + 1) % 3
		else:
			_combo = 0
		var names := ["attack1", "attack2", "attack3"]
		play_action(names[_combo], 0.42 if _combo < 2 else 0.58)
		state = "attack"
		_combo_window = 0.5 if _combo < 2 else 0.0
		_attack_hit_done = false
		_attack_hit_t = 0.16 if _combo < 2 else 0.3
		_attack_mult = [1.0, 1.1, 1.7 + float(stats.get("finisher_mult", 0.0))][_combo] * float(prim.dmg)
		Audio.play_at("swing", global_position, -6.0)
		if current_target and current_target.global_position.distance_to(global_position) < 5.0:
			var to := current_target.global_position - global_position
			to.y = 0
			_ext_vel += to.normalized() * 6.0
	else:
		_shots += 1
		var mult := float(prim.dmg)
		if hero.passive.kind == "every_nth" and _shots % int(hero.passive.n) == 0:
			mult *= float(hero.passive.mult)
		play_action("attack1" if _shots % 2 else "attack2", 0.26)
		state = "attack"
		_attack_hit_done = true
		var dir := aim_direction()
		var vel := dir * 26.0
		if current_target:
			var aimp = current_target.global_position + Vector3.UP * current_target.aim_height
			vel = (aimp - muzzle_position()).normalized() * 26.0
		Projectile.spawn(get_parent(), muzzle_position(), vel, {"owner_node": self, "mult": mult, "color": hero.color,
			"status": prim.get("status", ""), "status_t": 3.0, "life": float(prim.range) / 26.0, "kind": "ranged"})
		Audio.play_at("energy_bolt" if prim.get("status", "") != "burn" else "fire_cast", global_position, -9.0, 30.0, 0.12)
	Events.noise.emit(global_position, 10.0, self)


func _do_melee_hit() -> void:
	var prim: Dictionary = hero.primary
	var reach: float = float(prim.range) * (1.4 if transformed else 1.0)
	var targets := Combat.in_cone(get_tree(), global_position, facing(), reach, 120.0 if _combo < 2 else 220.0)
	var any := false
	for e in targets:
		var opts := {"kind": "melee", "knock": 3.0 if _combo < 2 else 8.0, "color": hero.color}
		if _combo == 2:
			opts["poise"] = 35.0
		if transformed:
			heal(4.0, true)
		if Combat.hit(self, e, _attack_mult, opts) > 0:
			any = true
			Fx.hit_spark(e.global_position + Vector3.UP * e.aim_height, hero.color, _combo == 2)
	if any:
		Audio.play_at("hit_flesh" if _combo < 2 else "hit_heavy", global_position, -2.0)
		Fx.hitstop(0.035 if _combo < 2 else 0.07)
		energy = minf(max_energy, energy + 3.0)


func _heavy() -> void:
	if state in ["heavy", "dodge"]:
		return
	if stamina < 15.0:
		return
	break_invisibility()
	stamina -= 15.0
	_stamina_delay = 0.8
	play_action("heavy", 0.75)
	state = "heavy"
	await get_tree().create_timer(0.38).timeout
	if not alive or state != "heavy":
		return
	var pos := global_position + facing() * 1.6
	Fx.ring(pos + Vector3.UP * 0.1, 3.5, hero.color, 0.35)
	Fx.impact(pos + Vector3.UP * 0.4, hero.color, 1.2)
	Fx.add_shake(0.45)
	Audio.play_at("hit_heavy", pos)
	for e in Combat.in_radius(get_tree(), pos, 3.0):
		var opts := {"kind": "melee", "knock": 10.0, "poise": 60.0, "color": hero.color}
		if int(stats.get("heavy_stun", 0)) > 0:
			opts["status"] = "stun"
			opts["status_t"] = 1.5
		Combat.hit(self, e, 2.3, opts)
	Events.noise.emit(global_position, 16.0, self)


func _try_dodge() -> void:
	if state in ["dodge", "dead", "hidden", "execute"] or stamina < 12.0:
		return
	stamina -= 12.0
	_stamina_delay = 0.6
	state = "dodge"
	var dir := input_dir()
	if dir.length() < 0.2:
		dir = -facing() if current_target else facing()
	dir = dir.normalized()
	_heading = atan2(-dir.x, -dir.z)
	_dash_vel = dir * 13.0
	_iframes = 0.42
	_perfect_t = 0.22 * (1.0 + float(stats.get("perfect_window", 0.0)))
	play_action("dodge", 0.45, 0.05)
	state = "dodge"
	Audio.play_at("dodge", global_position, -4.0)
	if hero.passive.kind == "dodge_cdr":
		for i in 3:
			cooldowns[i] = maxf(0.0, cooldowns[i] - cooldowns[i] * float(hero.passive.value))
	await get_tree().create_timer(0.45).timeout
	if state == "dodge":
		state = "move"


func counter_ready() -> bool:
	return _counter_t > 0.0


func use_counter() -> void:
	_counter_t = 0.0


func _perfect_dodge() -> void:
	_counter_t = 2.0
	_perfect_t = 0.0
	Fx.slowmo(0.9)
	Events.toast.emit("Esquive parfaite ! Contre-attaque prête", "counter")
	Audio.play("shield_hit", -4.0)
	Mats.set_param(_mats, "power_glow", 1.0)
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(self) and not transformed: Mats.set_param(_mats, "power_glow", 0.0))


func ability_cost(i: int) -> float:
	return float(hero.abilities[i].get("cost", 20))


func ability_cd(i: int) -> float:
	return float(hero.abilities[i].cd) * (1.0 - float(stats.get("cdr", 0.0)))


func use_ability(i: int) -> bool:
	if i >= hero.abilities.size() or state in ["dodge", "dead", "hidden", "execute"]:
		return false
	var a: Dictionary = hero.abilities[i]
	if cooldowns[i] > 0.0:
		return false
	if energy < ability_cost(i):
		Events.toast.emit("Énergie insuffisante", "warn")
		Audio.play("ui_error", -8.0)
		return false
	if a.kind != "invisibility":
		break_invisibility()
	energy -= ability_cost(i)
	cooldowns[i] = ability_cd(i)
	Abilities.cast(self, a)
	return true


func use_ultimate() -> bool:
	if ult < 100.0 or state in ["dead", "hidden", "execute"]:
		return false
	ult = 0.0
	break_invisibility()
	Abilities.cast(self, hero.ultimate, true)
	Fx.slowmo(0.4)
	return true


func on_dealt_damage(amount: float, target: Node, kind: String) -> void:
	ult = minf(100.0, ult + amount / 4.0 * (1.0 + float(stats.get("ult_gain", 0.0))))
	if kind != "dot":
		combo_count += 1
		_combo_decay = 3.0
		Events.combo_changed.emit(combo_count)
	if not target.alive and hero.passive.kind == "heal_on_kill":
		heal(float(hero.passive.value), true)


# ------------------------------------------------------------------------------- abilities API

func add_shield(amount: float, duration: float) -> void:
	shield_hp = maxf(shield_hp, amount)
	shield_t = duration
	(_shield_mesh.material_override as ShaderMaterial).set_shader_parameter("color", hero.color)


func add_temp_def(v: float, t: float) -> void:
	temp_def = v
	temp_def_t = t


func heal(amount: float, silent := false) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	if not silent:
		Fx.heal_fx(global_position + Vector3.UP, Color(0.4, 1.0, 0.5))


func heal_over_time(amount: float, duration: float) -> void:
	_hot = amount
	_hot_rate = amount / maxf(duration, 0.1)


func dash(distance: float, t: float, phase: bool) -> void:
	var dir := aim_direction() if Pad.move.length() < 0.2 else input_dir().normalized()
	_heading = atan2(-dir.x, -dir.z)
	_dash_vel = dir * distance / t
	_dash_t = t
	_iframes = t + 0.1
	if phase:
		collision_mask = Combat.LAYER_WORLD
	play_action("dodge" if phase else "attack3", t + 0.1)


func teleport_to(pos: Vector3, look_at_pos: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 3.0, pos + Vector3.DOWN * 6.0, Combat.LAYER_WORLD)
	var res := space.intersect_ray(q)
	if not res.is_empty():
		pos = res.position
	# Never teleport into a wall: check line from current position.
	var los := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, pos + Vector3.UP, Combat.LAYER_WORLD)
	var hit := space.intersect_ray(los)
	if not hit.is_empty():
		pos = hit.position - (pos - global_position).normalized() * 0.6
		pos.y = global_position.y
	global_position = pos
	var d := look_at_pos - pos
	_heading = atan2(-d.x, -d.z)
	_iframes = 0.3


func place_portal(pos: Vector3) -> void:
	clear_portal()
	portal_point = pos
	_portal_fx = load("res://src/combat/zone.gd").new()
	_portal_fx.radius = 0.9
	_portal_fx.duration = 30.0
	_portal_fx.mult = 0.0
	_portal_fx.color = hero.color
	get_parent().add_child(_portal_fx)
	_portal_fx.global_position = pos + Vector3.UP * 1.0
	get_tree().create_timer(30.0).timeout.connect(func(): if portal_point == pos: clear_portal())


func clear_portal() -> void:
	portal_point = Vector3.INF
	if _portal_fx and is_instance_valid(_portal_fx):
		_portal_fx.queue_free()
	_portal_fx = null


func set_invisible(t: float) -> void:
	invisible_t = t
	_set_model_alpha(0.25)
	for e in Combat.enemies(get_tree()):
		e.lose_player()


func break_invisibility() -> void:
	if invisible_t > 0.0:
		invisible_t = 0.0
		_set_model_alpha(1.0)


func _set_model_alpha(a: float) -> void:
	Mats.set_param(_mats, "dissolve", 0.0 if a >= 1.0 else 0.55)
	Mats.set_param(_mats, "dissolve_color", hero.color)


func start_transform(t: float, mult: float) -> void:
	transformed = true
	transform_mult = mult
	_transform_t = t
	model_root.scale = Vector3.ONE * 1.25
	Mats.set_param(_mats, "power_glow", 1.5)
	play_action("cast_up", 0.8)


func spore_immune() -> bool:
	return hero.passive.kind == "spore_immune" or int(stats.get("spore_immune", 0)) > 0


# ------------------------------------------------------------------------------- damage

func take_damage(info: Dictionary) -> float:
	if not alive or state == "execute":
		return 0.0
	var amount: float = info.amount
	if _iframes > 0.0 and info.get("kind", "") != "dot":
		if _perfect_t > 0.0:
			_perfect_dodge()
		return 0.0
	if state == "hidden":
		return 0.0
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	if hero.passive.kind == "front_reduction" and dir.length() > 0.1 and facing().dot(-dir) > 0.3:
		amount *= float(hero.passive.mult)
	var def: float = stats.def + temp_def
	amount *= 40.0 / (40.0 + def * 4.0)
	if shield_hp > 0.0:
		var absorbed := minf(shield_hp, amount)
		shield_hp -= absorbed
		amount -= absorbed
		Audio.play_at("shield_hit", global_position, -4.0)
		if amount <= 0.0:
			return 0.0
	hp -= amount
	_no_damage_t = 0.0
	if info.get("kind", "") != "dot":
		ult = minf(100.0, ult + amount * 0.6)
		Events.player_damaged.emit(amount)
		Mats.set_param(_mats, "flash", 0.8)
		var tw := create_tween()
		tw.tween_method(func(v): Mats.set_param(_mats, "flash", v), 0.8, 0.0, 0.2)
		Audio.play_at("player_hurt", global_position, -3.0)
		Fx.add_shake(clampf(amount / 30.0, 0.15, 0.8))
		if info.get("knockdown", false):
			stunned_t = 0.8
			state = "stunned"
			play_action("hit", 0.8)
			_ext_vel += dir * 8.0
		elif state == "move" and amount > 4.0:
			play_action("hit", 0.25)
	if hp <= 0.0:
		if int(stats.get("second_wind", 0)) > 0 and not second_wind_used:
			second_wind_used = true
			hp = max_hp * 0.3
			_iframes = 1.5
			Events.toast.emit("Second souffle !", "counter")
			return amount
		die()
	return amount


func die() -> void:
	alive = false
	state = "dead"
	hp = 0.0
	anim.play("death", 0.1)
	anim.speed_scale = 1.0
	Audio.play("player_death", 0.0)
	Events.player_died.emit()
	Game.profile.stats.deaths += 1


func revive_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	alive = true
	state = "move"
	hp = max_hp
	energy = max_energy
	stamina = max_stamina
	_iframes = 2.0
	anim.play("spawn", 0.0)
	_action_t = 1.0
	state = "action"


# ------------------------------------------------------------------------------- stealth

func visibility() -> float:
	## 0 = invisible .. ~1.6 = very conspicuous. Used by every enemy perception check.
	if state == "hidden" or invisible_t > 0.0 or domain_hidden:
		return 0.0
	var v := 1.0
	if crouching:
		v *= 0.5
	if flashlight_on:
		v *= 1.6
	else:
		v *= lerpf(0.45, 1.0, clampf(in_light, 0.0, 1.0))
	if sprinting:
		v *= 1.2
	return v


func _update_light_level() -> void:
	var w := get_tree().get_first_node_in_group("world")
	var base: float = w.ambient_visibility if w else 0.6
	var best := base
	for l in get_tree().get_nodes_in_group("light_source"):
		if not l.has_method("light_at"):
			continue
		best = maxf(best, l.light_at(global_position))
	in_light = best


func is_noisy() -> bool:
	return sprinting or state in ["attack", "heavy"]


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	Audio.play_at("ui_click", global_position, -10.0)


func flashlight_hits(p: Vector3) -> bool:
	if not flashlight_on:
		return false
	var to := p - flashlight.global_position
	if to.length() > flashlight.spot_range:
		return false
	return (-flashlight.global_transform.basis.z).dot(to.normalized()) > cos(deg_to_rad(flashlight.spot_angle))


func enter_hiding(spot: Node3D, seen: bool) -> void:
	hiding_spot = spot
	seen_entering_hide = seen
	state = "hidden"
	visual.visible = false
	velocity = Vector3.ZERO
	collision_layer = 0
	global_position = spot.hide_position()
	Events.player_hidden.emit(true)
	if cam_rig:
		cam_rig.override_transform = true
		var cam: Camera3D = cam_rig.cam
		cam.global_transform = spot.peek_transform()


func exit_hiding() -> void:
	if hiding_spot == null:
		return
	global_position = hiding_spot.exit_position()
	hiding_spot.on_exit()
	hiding_spot = null
	state = "move"
	visual.visible = true
	collision_layer = Combat.LAYER_PLAYER
	Events.player_hidden.emit(false)
	if cam_rig:
		cam_rig.override_transform = false
		cam_rig.cam.position = Vector3.ZERO
		cam_rig.cam.rotation = Vector3.ZERO


func _hidden_update(delta: float) -> void:
	Game.profile.stats.time_hidden += delta
	var look := Pad.take_look()
	if cam_rig and look.length() > 0.0:
		var cam: Camera3D = cam_rig.cam
		cam.rotate_y(-look.x * 0.003)
	_update_interact()
	if Pad.consume("interact") or Pad.consume("dodge"):
		exit_hiding()


# ------------------------------------------------------------------------------- interaction

func _update_interact() -> void:
	var best: Node = null
	var best_d := INF
	if state == "hidden":
		best = hiding_spot
	else:
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.has_method("can_interact") or not n.can_interact(self):
				continue
			var r: float = n.get("interact_range") if n.get("interact_range") != null else 2.2
			var d: float = n.global_position.distance_to(global_position)
			if d < r and d < best_d:
				best = n
				best_d = d
		var ex := _execution_target()
		if ex:
			best = ex
	if best != interact_target:
		if interact_target and is_instance_valid(interact_target):
			Events.interaction_cleared.emit(interact_target)
		interact_target = best
	if best:
		var prompt: String
		if best.is_in_group("enemy"):
			prompt = "Exécuter"
		elif state == "hidden":
			prompt = "Sortir de la cachette"
		else:
			prompt = best.get_prompt(self)
		Events.interaction_available.emit(prompt, best)


func _execution_target() -> Node3D:
	var thr := float(stats.get("execute_threshold", 0.15))
	for e in Combat.in_radius(get_tree(), global_position, 3.0):
		if e.can_be_executed(thr):
			return e
	return null


func _interact() -> void:
	if interact_target == null or not is_instance_valid(interact_target):
		return
	if interact_target.is_in_group("enemy"):
		_execute(interact_target)
	else:
		interact_target.interact(self)


func _execute(e: Node3D) -> void:
	state = "execute"
	_iframes = 2.0
	var to := e.global_position - global_position
	_heading = atan2(-to.x, -to.z)
	visual.rotation.y = _heading
	Fx.slowmo(1.0)
	anim.play("attack3", 0.05)
	anim.speed_scale = 1.0
	Audio.play_at("shadow_blades", global_position)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(e) and e.alive:
		Fx.impact(e.global_position + Vector3.UP * e.aim_height, hero.color, 1.8)
		Fx.add_shake(0.6)
		e.executed(self)
	anim.play("heavy", 0.05)
	await get_tree().create_timer(0.45).timeout
	energy = minf(max_energy, energy + 25.0)
	ult = minf(100.0, ult + 15.0)
	state = "move"


# ------------------------------------------------------------------------------- items

func current_item() -> String:
	var owned := ITEM_ORDER.filter(func(i): return Game.item_count(i) > 0)
	if owned.is_empty():
		return ""
	return owned[item_index % owned.size()]


func cycle_item() -> void:
	item_index += 1
	Events.items_changed.emit()


func use_item() -> void:
	var id := current_item()
	if id == "" or state in ["dead", "execute"]:
		return
	var ok := true
	match id:
		"medkit":
			if hp >= max_hp:
				Events.toast.emit("PV déjà au maximum", "warn")
				return
			heal(50.0)
			Audio.play("heal", -2.0)
		"cell":
			energy = minf(max_energy, energy + 50.0)
			Fx.heal_fx(global_position + Vector3.UP, Color(0.3, 0.8, 1.0))
		"flare", "decoy", "smoke", "mine":
			var thrown: Node3D = load("res://src/world/throwable.gd").new()
			thrown.kind = id
			get_parent().add_child(thrown)
			thrown.global_position = global_position + Vector3.UP * 1.4 + facing() * 0.5
			var throw_dir := (aim_direction() + Vector3.UP * 0.35).normalized()
			thrown.throw(throw_dir * (11.0 if id != "mine" else 2.0), self)
			play_action("cast", 0.3)
		"barricade":
			ok = false
			for d in get_tree().get_nodes_in_group("door"):
				if d.global_position.distance_to(global_position) < 3.5 and d.can_barricade():
					d.barricade()
					ok = true
					break
			if not ok:
				Events.toast.emit("Approchez-vous d'une porte", "warn")
		"capture":
			ok = false
			for e in Combat.in_radius(get_tree(), global_position, 3.5):
				if e.can_be_captured():
					e.captured(self)
					ok = true
					break
			if not ok:
				Events.toast.emit("Étourdissez d'abord une créature", "warn")
	if ok:
		Game.consume_item(id)
