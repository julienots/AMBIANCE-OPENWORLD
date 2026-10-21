extends Interactable
## Hiding place (locker, desk, bush, vent cover). Inside, the player is invisible and
## silent. Monsters find you only if they saw you get in (or by bad luck when searching).

var kind := "locker"             # locker | bush | desk
var _door: Node3D


func _build() -> void:
	add_to_group("hide_spot")
	interact_range = 1.9
	match kind:
		"locker":
			var body := box_mesh(Vector3(0.9, 2.1, 0.7), Color(0.35, 0.42, 0.45))
			body.position.y = 1.05
			add_child(body)
			_door = box_mesh(Vector3(0.86, 2.0, 0.05), Color(0.42, 0.5, 0.53))
			_door.position = Vector3(0, 1.05, -0.37)
			_door.set_meta("dynamic", true)
			add_child(_door)
			for i in 4:
				var slot := box_mesh(Vector3(0.5, 0.04, 0.06), Color(0.08, 0.08, 0.1))
				slot.position = Vector3(0, 1.7 - i * 0.08, -0.4)
				add_child(slot)
			static_box(self, Vector3(0.9, 2.1, 0.7), Vector3(0, 1.05, 0), "metal")
		"bush":
			for i in 5:
				var mi := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = randf_range(0.55, 0.85)
				s.height = s.radius * 1.6
				mi.mesh = s
				mi.material_override = Mats.toon(Color(0.12, 0.22, 0.12).lerp(Color(0.2, 0.3, 0.12), randf()))
				mi.position = Vector3(randf_range(-0.6, 0.6), 0.6 + randf() * 0.3, randf_range(-0.6, 0.6))
				add_child(mi)
		"desk":
			var top := box_mesh(Vector3(1.8, 0.08, 0.9), Color(0.55, 0.5, 0.45))
			top.position.y = 0.85
			add_child(top)
			for x in [-0.8, 0.8]:
				var leg := box_mesh(Vector3(0.08, 0.85, 0.8), Color(0.3, 0.3, 0.32))
				leg.position = Vector3(x, 0.42, 0)
				add_child(leg)
			var back := box_mesh(Vector3(1.7, 0.6, 0.05), Color(0.3, 0.3, 0.32))
			back.position = Vector3(0, 0.55, 0.4)
			add_child(back)
			static_box(self, Vector3(1.8, 0.1, 0.9), Vector3(0, 0.85, 0), "metal")


func get_prompt(_p: Node) -> String:
	return "Se cacher"


func interact(p: Node) -> void:
	var seen := false
	for e in Combat.enemies(get_tree()):
		if e.target == p and e.can_see(p):
			seen = true
			break
	if _door:
		var tw := create_tween()
		tw.tween_property(_door, "position:z", -0.6, 0.12)
		tw.tween_property(_door, "position:z", -0.37, 0.15)
	Audio.play_at("door_close" if kind == "locker" else "branch_snap", global_position, -10.0)
	p.enter_hiding(self, seen)


func hide_position() -> Vector3:
	return global_position + Vector3.UP * 0.1


func exit_position() -> Vector3:
	return global_position - global_transform.basis.z * 1.1


func peek_transform() -> Transform3D:
	var eye := global_position + Vector3.UP * (1.6 if kind == "locker" else 0.7) - global_transform.basis.z * 0.3
	return Transform3D(global_transform.basis, eye)


func on_exit() -> void:
	if _door:
		var tw := create_tween()
		tw.tween_property(_door, "position:z", -0.7, 0.1)
		tw.tween_property(_door, "position:z", -0.37, 0.2)
