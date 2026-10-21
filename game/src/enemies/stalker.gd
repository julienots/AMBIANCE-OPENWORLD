extends "res://src/enemies/enemy.gd"
## Stalker: spots the player from afar, follows at a distance, waits for an opening
## (player isolated, hurt, turned away or busy), strikes, then retreats. Back hits x2.

var _growl_t := 0.0
var _orbit_dir := 1.0


func _think(delta: float, player: Node3D) -> void:
	_growl_t -= delta
	if state == "chase" and target:
		var d := global_position.distance_to(target.global_position)
		if _growl_t <= 0.0:
			_growl_t = randf_range(4.0, 8.0)
			Audio.play_at("stalker_growl", global_position, -2.0, 40.0)
		var to_me := (global_position - target.global_position).normalized()
		var player_facing_me: bool = target.facing().dot(to_me) > 0.6
		var opening: bool = not player_facing_me or target.hp < target.max_hp * 0.4 or target.state in ["attack", "heavy", "action"]
		if d <= float(data.attack_range) and _attack_cd <= 0.0:
			start_attack()
			return
		if _attack_phase != "":
			return
		if opening or _state_t > 12.0 or _taunt_t > 0.0:
			play_anim("run")
			move_to(target.global_position, run_speed, delta)
		else:
			# Circle at a distance, staying in the shadows of the player's flanks.
			var want := target.global_position + to_me.rotated(Vector3.UP, 0.6 * _orbit_dir) * 9.0
			play_anim("walk")
			move_to(want, speed * 1.4, delta)
			face_towards(target.global_position, delta, 4.0)
			if randf() < delta * 0.2:
				_orbit_dir = -_orbit_dir
		if awareness <= 0.0:
			lose_player()
		Audio.request_state("combat", 2.0)
		return
	super._think(delta, player)


func _on_spotted(player: Node3D) -> void:
	super._on_spotted(player)
	if randf() < 0.5:
		play_once("scream")
		Audio.play_at("stalker_scream", global_position, 0.0, 60.0)


func windup_time() -> float:
	return 0.45


func _attack_hit(player: Node3D) -> void:
	super._attack_hit(player)
	set_state("chase")
	_state_t = 0.0
	# Retreat after striking.
	_ext_vel -= forward() * 8.0


func weak_point_mult(info: Dictionary) -> float:
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	if dir.length() > 0.1 and forward().dot(dir.normalized()) > 0.3:
		return 2.0
	return 1.0


func _death_sound() -> void:
	Audio.play_at("stalker_scream", global_position, -6.0)
