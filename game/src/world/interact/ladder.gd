extends Interactable
## Fire escape / ladder: climbs between two points (rooftops, pits).

var top := Vector3.ZERO           # global target position
var height := 8.0


func _build() -> void:
	interact_range = 1.8
	for x in [-0.35, 0.35]:
		var rail := box_mesh(Vector3(0.08, height, 0.08), Color(0.55, 0.2, 0.15))
		rail.position = Vector3(x, height * 0.5, 0)
		add_child(rail)
	for i in int(height / 0.4):
		var rung := box_mesh(Vector3(0.7, 0.05, 0.06), Color(0.55, 0.2, 0.15))
		rung.position = Vector3(0, 0.3 + i * 0.4, 0)
		add_child(rung)


func get_prompt(p: Node) -> String:
	return "Grimper" if p.global_position.y < global_position.y + height * 0.5 else "Descendre"


func interact(p: Node) -> void:
	var up: bool = p.global_position.y < global_position.y + height * 0.5
	var dest := top if up else global_position - global_transform.basis.z * 0.8
	p.play_action("crouch", 0.6)
	var tw := p.create_tween()
	tw.tween_property(p, "global_position", global_position + Vector3.UP * (height if up else 0.2) - global_transform.basis.z * 0.3, 0.9)
	tw.tween_property(p, "global_position", dest, 0.25)
	Audio.play_at("step_metal", global_position, -4.0)
