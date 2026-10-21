extends "res://src/enemies/enemy.gd"
## Burrower: blind, travels underground toward vibrations (noise). A dust trail and a
## rumble betray its position. It surfaces near the source, strikes, then dives again.
## Staying still or crouched makes you undetectable. The open mouth is its weak point.

var underground := true
var _trail: CPUParticles3D
var _rumble: AudioStreamPlayer3D
var _surface_t := 0.0
var dig_target := Vector3.INF      # base raids: cell the burrower is tunnelling toward
var raid_mode := false


func _on_ready() -> void:
	_trail = CPUParticles3D.new()
	_trail.amount = maxi(8, int(24 * Fx.density()))
	_trail.lifetime = 1.2
	_trail.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	_trail.mesh = q
	_trail.material_override = Fx._particle_mat(Fx.TEX_SMOKE, false, true)
	_trail.color_ramp = Fx._gradient(Color(0.35, 0.3, 0.25, 0.7), Color(0.3, 0.27, 0.22, 0.0))
	_trail.direction = Vector3.UP
	_trail.initial_velocity_max = 1.5
	_trail.gravity = Vector3(0, -1, 0)
	_trail.anim_speed_min = 1.0
	_trail.anim_speed_max = 1.0
	add_child(_trail)
	_rumble = Audio.attach_loop(self, "burrower_rumble", -4.0, 30.0)
	_go_under()


func _go_under() -> void:
	underground = true
	$Visual.visible = false
	collision_layer = 0
	_trail.emitting = true
	if _rumble:
		_rumble.play()
	set_state("burrow")


func _surface() -> void:
	underground = false
	$Visual.visible = true
	collision_layer = Combat.LAYER_ENEMY
	_trail.emitting = false
	if _rumble:
		_rumble.stop()
	play_once("emerge")
	Audio.play_at("burrower_emerge", global_position, 2.0)
	Fx.dig_debris(global_position + Vector3.UP * 0.5, Color(0.45, 0.4, 0.33))
	Fx.add_shake(0.35)
	_surface_t = 0.0
	set_state("surfaced")
	Game.codex_seen(id)


func _perceive(_player: Node3D, _dt: float) -> void:
	# Blind: only vibrations count (see heard()).
	if not underground and target and global_position.distance_to(target.global_position) < 3.0 and target.is_noisy():
		last_known = target.global_position


func heard(pos: Vector3, source: Node, _dist: float) -> void:
	last_known = pos
	if source and source.is_in_group("player"):
		target = source
	if state in ["burrow_idle", "burrow"]:
		set_state("burrow")


func _think(delta: float, player: Node3D) -> void:
	match state:
		"burrow", "burrow_idle":
			if raid_mode and dig_target != Vector3.INF:
				return
			if last_known == Vector3.ZERO:
				stop(delta)
				return
			var arrived := move_to(last_known, run_speed, delta)
			if arrived or global_position.distance_to(last_known) < 2.5:
				# Only surface next to the player if the player is still making noise.
				if player and player.global_position.distance_to(global_position) < 4.0 and not player.is_noisy() and player.crouching:
					last_known = Vector3.ZERO
					set_state("burrow_idle")
				else:
					_surface()
		"surfaced":
			_surface_t += delta
			stop(delta)
			if player and _surface_t > 0.8:
				face_towards(player.global_position, delta, 4.0)
				var d := global_position.distance_to(player.global_position)
				if d < float(data.attack_range) + 0.5 and _attack_cd <= 0.0 and _attack_phase == "":
					start_attack()
				elif _surface_t > 1.5 and _attack_phase == "":
					play_anim("idle")
			if _surface_t > 5.0 and _attack_phase == "":
				play_once("dive")
				_attack_cd = 1.0
				await get_tree().create_timer(0.9).timeout
				if alive:
					last_known = Vector3.ZERO
					_go_under()
			Audio.request_state("combat", 2.0)


func windup_time() -> float:
	return 0.5


func _attack_begin(_k: String) -> void:
	play_once("attack")
	Fx.danger_zone(global_position + forward() * 1.8, 1.6, windup_time(), Color(1, 0.5, 0.1))


func take_damage(info: Dictionary) -> float:
	if underground:
		return 0.0
	return super.take_damage(info)


func weak_point_mult(info: Dictionary) -> float:
	# Mouth is open during the strike.
	return 2.0 if _attack_phase != "" else 1.0


func _death_sound() -> void:
	Audio.play_at("burrower_emerge", global_position, -4.0)
