extends "res://src/enemies/enemy.gd"
## Boss base: multi-phase encounter with an introduction and a health bar.
## Phases change at 66 % and 33 % HP; each phase speeds up attacks.

var phase := 1
var _intro_done := false


func _on_ready() -> void:
	leash = 1e9


func _think(delta: float, player: Node3D) -> void:
	if not _intro_done and player and global_position.distance_to(player.global_position) < 30.0:
		_intro_done = true
		target = player
		awareness = 1.0
		set_state("chase")
		Events.boss_started.emit(self, data.name)
		Audio.play_at("boss_roar", global_position, 4.0, 120.0)
		play_once("roar" if anim and anim.has_animation("roar") else "idle")
	if _intro_done:
		Audio.request_state("boss", 3.0)
	var frac := hp / max_hp
	var want := 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	if want != phase:
		phase = want
		Events.boss_phase.emit(self, phase)
		Events.toast.emit("%s — phase %d" % [data.name, phase], "warn")
		Fx.add_shake(0.6)
	super._think(delta, player)


func windup_time() -> float:
	return 0.7 - 0.12 * (phase - 1)


func die(killer = null, drop_mult := 1.0) -> void:
	if alive:
		Events.boss_defeated.emit(self, id)
		Events.mission_event.emit("boss", id, 1)
	super.die(killer, drop_mult * 2.0)
