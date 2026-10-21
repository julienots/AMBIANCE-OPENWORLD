extends Node3D
## Symbiote nest: pulsing organic mass that spawns crawlers until destroyed.
## Implements the enemy interface so every attack and ability can damage it.

var alive := true
var hp := 260.0
var max_hp := 260.0
var hit_radius := 1.3
var aim_height := 0.8
var family := "rampant"
var id := "nest"
var target: Node3D = null
var spawn_t := 6.0
var mission_tag := "nest"
var spawned: Array = []
var mats: Array = []
var _smoke: CPUParticles3D


func _ready() -> void:
	add_to_group("enemy")
	for i in 6:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = randf_range(0.5, 1.0)
		s.height = s.radius * randf_range(1.2, 2.0)
		mi.mesh = s
		mi.position = Vector3(randf_range(-0.7, 0.7), s.radius * 0.6, randf_range(-0.7, 0.7))
		var m := Mats.symbiote({"base_color": Color(0.06, 0.03, 0.06), "vein_strength": 1.8, "breathe": 0.04})
		mi.material_override = m
		mats.append(m)
		add_child(mi)
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.35
	cs.height = 0.7
	core.mesh = cs
	core.material_override = Mats.toon(Color(1.0, 0.2, 0.3), 3.0, {"pulse_speed": 3.0})
	core.position.y = 1.1
	add_child(core)
	_smoke = Fx.symbiote_smoke(self, Color(0.05, 0.02, 0.05, 0.6), 1.4, 10, 1.5)
	var b := StaticBody3D.new()
	b.collision_layer = Combat.LAYER_WORLD
	var c := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.1
	sh.height = 1.6
	c.shape = sh
	c.position.y = 0.8
	b.add_child(c)
	add_child(b)


func _process(delta: float) -> void:
	if not alive:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or p.global_position.distance_to(global_position) > 30.0:
		return
	spawn_t -= delta
	spawned = spawned.filter(func(e): return is_instance_valid(e) and e.alive)
	if spawn_t <= 0.0 and spawned.size() < 3:
		spawn_t = randf_range(7.0, 11.0)
		var w := get_tree().get_first_node_in_group("world")
		if w:
			var e = w.spawn_enemy("crawler", global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)))
			e.target = p
			e.awareness = 1.0
			e.set_state("chase")
			spawned.append(e)
			Audio.play_at("crawler_screech", global_position, -2.0)


func take_damage(info: Dictionary) -> float:
	if not alive:
		return 0.0
	hp -= info.amount
	Fx.damage_number(global_position + Vector3.UP * 1.8, info.amount, info.get("crit", false))
	Mats.set_param(mats, "flash", 0.8)
	create_tween().tween_method(func(v): Mats.set_param(mats, "flash", v), 0.8, 0.0, 0.2)
	if hp <= 0.0:
		alive = false
		Fx.explosion(global_position + Vector3.UP, 2.0, Color(0.9, 0.15, 0.3))
		Fx.dissolve_burst(global_position + Vector3.UP, Color(0.9, 0.1, 0.3), 2.0)
		Audio.play_at("crawler_death", global_position, 4.0)
		Events.mission_event.emit("destroy", mission_tag, 1)
		Game.add_xp(60)
		for k in {"samples": 2, "spores": 2}:
			Pickup.spawn(get_parent(), global_position + Vector3.UP, k, 2)
		var tw := create_tween()
		tw.tween_method(func(v): Mats.set_param(mats, "dissolve", v), 0.0, 1.0, 1.0)
		tw.tween_callback(queue_free)
	return info.amount


func has_status(_s: String) -> bool:
	return false


func apply_status(_s: String, _t: float) -> void:
	pass


func can_be_moved() -> bool:
	return false


func external_push(_v: Vector3) -> void:
	pass


func can_be_executed(_t: float) -> bool:
	return false


func can_be_captured() -> bool:
	return false


func is_aware_of_player() -> bool:
	return true


func lose_player() -> void:
	pass


func taunt(_p, _t) -> void:
	pass


func can_see(_p) -> bool:
	return false
