extends "res://src/enemies/enemy.gd"
## Abyssal: rare deep predator gliding over flooded caverns. Circles its lair, lunges at
## anything that makes noise near the water. Its glowing lures are weak points.

var lair_radius := 14.0
var _ang := 0.0
var _roar_t := 6.0


func _on_ready() -> void:
	gravity_on = false
	play_anim("swim")
	Audio.play_at("abyssal_roar", global_position, 4.0, 90.0)


func _think(delta: float, player: Node3D) -> void:
	_roar_t -= delta
	if _roar_t <= 0.0:
		_roar_t = randf_range(10, 18)
		Audio.play_at("abyssal_roar", global_position, 0.0, 90.0)
	if target and global_position.distance_to(target.global_position) < 26.0:
		Audio.request_state("boss", 2.0)
		play_anim("swim", 0.2, 1.6)
		var want := target.global_position + Vector3.UP * 1.2
		var d := global_position.distance_to(want)
		if d < float(data.attack_range) + 1.0 and _attack_cd <= 0.0 and _attack_phase == "":
			start_attack()
			return
		var dir := (want - global_position).normalized()
		velocity = velocity.lerp(dir * run_speed, delta * 2.0)
		if global_position.distance_to(home) > lair_radius * 1.8:
			lose_player()
		return
	_ang += delta * 0.25
	var p := home + Vector3(cos(_ang), 0.15 * sin(_ang * 3.0), sin(_ang)) * lair_radius
	velocity = velocity.lerp((p - global_position).normalized() * speed, delta * 1.5)
	play_anim("swim")


func _attack_begin(_k: String) -> void:
	play_once("attack")
	Fx.danger_zone(Vector3(global_position.x, home.y - 1.0, global_position.z) + forward() * 3.0, 3.0, windup_time())


func windup_time() -> float:
	return 0.7


func weak_point_mult(info: Dictionary) -> float:
	var p: Vector3 = info.get("pos", global_position)
	return 2.5 if p.y > global_position.y + 0.8 else 1.0
