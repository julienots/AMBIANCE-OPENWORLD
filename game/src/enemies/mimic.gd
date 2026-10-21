extends "res://src/enemies/enemy.gd"
## Mimic: stands like a hunched survivor and calls for help in an almost-human voice.
## It reveals itself when the player comes close, when attacked, or when the flashlight
## stays on it. Revealed, it lunges with blooming head-petals. Head hits x2.

var disguised := true
var _call_t := 2.0
var _light_t := 0.0


func _on_ready() -> void:
	set_state("disguise")
	Mats.set_param(mats, "vein_strength", 0.0)
	Mats.set_param(mats, "breathe", 0.0)


func _think(delta: float, player: Node3D) -> void:
	if disguised:
		play_anim("idle", 0.2, 0.6)
		stop(delta)
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = randf_range(6.0, 11.0)
			Audio.play_at("mimic_voice", global_position + Vector3.UP * 1.6, -2.0, 45.0)
			Events.noise.emit(global_position, 3.0, self)
		if player:
			var d := global_position.distance_to(player.global_position)
			if player.flashlight_hits(global_position + Vector3.UP * 1.5):
				_light_t += delta
			else:
				_light_t = maxf(0.0, _light_t - delta)
			if d < 3.5 or _light_t > 1.2:
				reveal(player)
		return
	super._think(delta, player)


func reveal(player: Node3D) -> void:
	if not disguised:
		return
	disguised = false
	target = player
	awareness = 1.0
	Mats.set_param(mats, "vein_strength", 1.6)
	Mats.set_param(mats, "breathe", 0.012)
	var t := play_once("reveal")
	Audio.play_at("mimic_reveal", global_position, 2.0)
	Events.jumpscare.emit(0.6)
	_on_spotted(player)
	set_state("stagger")
	_attack_cd = t * 0.7


func _perceive(player: Node3D, dt: float) -> void:
	if disguised:
		return
	super._perceive(player, dt)


func take_damage(info: Dictionary) -> float:
	if disguised:
		reveal(info.get("source"))
	return super.take_damage(info)


func heard(pos: Vector3, source: Node, dist: float) -> void:
	if not disguised:
		super.heard(pos, source, dist)


func _attack_begin(_k: String) -> void:
	play_once("attack")
	_ext_vel += forward() * 6.0


func weak_point_mult(info: Dictionary) -> float:
	var p: Vector3 = info.get("pos", global_position)
	return 2.0 if p.y - global_position.y > 1.35 else 1.0


func _death_sound() -> void:
	Audio.play_at("mimic_reveal", global_position, -6.0)
