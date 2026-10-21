extends "res://src/enemies/enemy.gd"
## Small, fast pack hunter. Lurks under debris/ceilings, ambushes with a leap,
## avoids lit areas, weak glowing abdomen (back hits deal double).

var ambusher := false          # waits motionless until the player is close
var _leap_t := 0.0
var _chitter_t := 0.0


func _on_ready() -> void:
	if ambusher:
		visible = true
		set_state("ambush")


func _think(delta: float, player: Node3D) -> void:
	_chitter_t -= delta
	if _chitter_t <= 0.0 and (target or state == "investigate"):
		_chitter_t = randf_range(1.5, 3.5)
		Audio.play_at("crawler_chitter", global_position, -6.0, 25.0)
	if state == "ambush":
		play_anim("idle", 0.2, 0.3)
		stop(delta)
		if player and global_position.distance_to(player.global_position) < 5.5 and player.visibility() > 0.2:
			target = player
			awareness = 1.0
			_on_spotted(player)
			Audio.play_at("crawler_screech", global_position, 0.0)
			Events.jumpscare.emit(0.35)
			set_state("chase")
			start_attack("leap")
		return
	# Light aversion: crawlers keep out of lamps (they circle at the light's edge).
	if state == "chase" and target and _in_strong_light(target.global_position) and not has_status("taunt"):
		play_anim("run")
		var away := (global_position - target.global_position)
		away.y = 0
		var side := away.normalized().cross(Vector3.UP) * 4.0
		move_to(global_position + away.normalized() * 2.0 + side, run_speed * 0.7, delta)
		if _state_t > 6.0:
			lose_player()
		return
	super._think(delta, player)


func _in_strong_light(p: Vector3) -> bool:
	for l in get_tree().get_nodes_in_group("light_source"):
		if l.has_method("light_at") and l.get("repels") and l.light_at(p) > 0.7:
			return true
	return false


func windup_time() -> float:
	return 0.3


func _attack_begin(kind: String) -> void:
	play_once("attack")
	if kind == "leap" or randf() < 0.3:
		_ext_vel += forward() * 9.0 + Vector3.UP * 3.0
		Audio.play_at("crawler_screech", global_position, -4.0)


func weak_point_mult(info: Dictionary) -> float:
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	if dir.length() > 0.1 and forward().dot(dir.normalized()) > 0.4:
		return 2.0
	return 1.0


func _death_sound() -> void:
	Audio.play_at("crawler_death", global_position, -2.0)
