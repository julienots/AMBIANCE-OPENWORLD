extends "res://src/enemies/enemy.gd"
## Colossus: slow and massive. Telegraphed ground slam (knockdown), sweeping strike and
## a charge that smashes breakable props. Charging into a wall or taking a heavy blow
## makes it stagger: the glowing core is exposed (x3 damage).

var core_open_t := 0.0
var _charge_t := 0.0
var _roar_t := 0.0
var _kind := "slam"


func _think(delta: float, player: Node3D) -> void:
	core_open_t = maxf(0.0, core_open_t - delta)
	Mats.set_param(mats, "alert", 1.0 if core_open_t > 0.0 else 0.0)
	if state == "charge":
		play_anim("run", 0.1, 1.3)
		var dir := forward()
		velocity.x = dir.x * run_speed * 1.8
		velocity.z = dir.z * run_speed * 1.8
		_smash_props()
		if target and global_position.distance_to(target.global_position) < 2.5:
			target.take_damage({"amount": float(data.dmg) * 1.2 * _dmg_scale(), "source": self, "dir": dir, "kind": "melee", "knockdown": true})
			set_state("chase")
			_attack_cd = 2.5
		elif is_on_wall() and _state_t > 0.3:
			Fx.add_shake(0.8)
			Audio.play_at("colossus_slam", global_position)
			expose_core(4.0)
		elif _state_t > 2.2:
			set_state("chase")
		return
	if state == "chase" and target:
		_roar_t -= delta
		if _roar_t <= 0.0:
			_roar_t = randf_range(8.0, 14.0)
			Audio.play_at("colossus_roar", global_position, 0.0, 70.0)
		var d := global_position.distance_to(target.global_position)
		if _attack_phase == "" and _attack_cd <= 0.0 and d > 7.0 and d < 18.0 and randf() < delta * 0.6:
			face_towards(target.global_position, 1.0, 100.0)
			Fx.danger_zone(global_position + forward() * 6.0, 2.0, 0.6)
			Audio.play_at("colossus_roar", global_position, -3.0)
			set_state("charge")
			return
	if state == "stagger":
		stop(delta)
		if _state_t > 3.5:
			set_state("chase" if target else "search")
		return
	super._think(delta, player)


func _smash_props() -> void:
	for b in get_tree().get_nodes_in_group("breakable"):
		if b.global_position.distance_to(global_position) < hit_radius + 2.0 and b.has_method("smash"):
			b.smash(forward())


func windup_time() -> float:
	return 0.9 if _kind == "slam" else 0.55


func _attack_begin(_k: String) -> void:
	var p := _player()
	_kind = "slam" if randf() < 0.55 or (p and p.global_position.distance_to(global_position) < 2.2) else "swipe"
	if _kind == "slam":
		play_once("slam")
		Fx.danger_zone(global_position + forward() * 2.0, 3.6, windup_time())
	else:
		play_once("swipe")
		Fx.danger_zone(global_position + forward() * 2.2, 2.8, windup_time(), Color(1.0, 0.45, 0.1))


func _attack_hit(player: Node3D) -> void:
	if _kind == "slam":
		var c := global_position + forward() * 2.0
		Fx.add_shake(0.9)
		Fx.dig_debris(c, Color(0.4, 0.35, 0.3))
		Fx.ring(c + Vector3.UP * 0.1, 4.0, Color(1, 0.5, 0.2), 0.4)
		Audio.play_at("colossus_slam", c, 2.0)
		Events.noise.emit(c, 30.0, self)
		if player and player.global_position.distance_to(c) < 3.6:
			player.take_damage({"amount": float(data.dmg) * _dmg_scale(), "source": self, "dir": (player.global_position - c).normalized(), "kind": "melee", "knockdown": true})
		_smash_props()
	else:
		super._attack_hit(player)


func expose_core(t: float) -> void:
	core_open_t = t
	_attack_phase = ""
	set_state("stagger")
	play_once("stagger")
	Events.toast.emit("Le cœur est exposé !", "counter")


func on_stagger() -> void:
	expose_core(3.0)


func weak_point_mult(_info: Dictionary) -> float:
	return 3.0 if core_open_t > 0.0 else 0.8


func _death_sound() -> void:
	Audio.play_at("colossus_roar", global_position, 2.0)
