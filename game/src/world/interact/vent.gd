extends Node3D
## Duct opening used by the Devourer as a real shortcut. Linked in pairs.

var linked: Node3D
var _grate: MeshInstance3D


func _ready() -> void:
	add_to_group("vent")
	var frame := Interactable.box_mesh(Vector3(1.4, 1.0, 0.15), Color(0.2, 0.21, 0.24))
	frame.position.y = 0.5
	add_child(frame)
	_grate = Interactable.box_mesh(Vector3(1.2, 0.8, 0.06), Color(0.32, 0.34, 0.37))
	_grate.set_meta("dynamic", true)
	_grate.position = Vector3(0, 0.5, -0.08)
	add_child(_grate)
	for i in 5:
		var bar := Interactable.box_mesh(Vector3(1.15, 0.04, 0.08), Color(0.08, 0.08, 0.1))
		bar.position = Vector3(0, 0.2 + i * 0.15, -0.12)
		add_child(bar)
	Interactable.merge_static(self)


func exit_position() -> Vector3:
	return global_position - global_transform.basis.z * 1.5


func rattle() -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_grate, "rotation_degrees:z", randf_range(-12, 12), 0.05)
	tw.tween_property(_grate, "rotation_degrees:z", 0.0, 0.1)
	Audio.play_at("devourer_vent", global_position, 2.0, 40.0)
	Fx.smoke_puff(global_position + Vector3.UP * 0.5, Color(0.05, 0.03, 0.06, 0.7), 1.2, 6)
