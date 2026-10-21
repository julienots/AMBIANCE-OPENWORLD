extends Interactable
## Hinged door. Blocks movement and sight while closed. Creatures must bash it open
## (barricades take much longer). Can be locked until a generator is powered.

var open := false
var barricaded := false
var broken := false
var locked_by := ""                 # power group tag; "" = not locked
var width := 1.6
var height := 2.6
var color := Color(0.42, 0.45, 0.5)
var _hinge: Node3D
var _body: StaticBody3D
var _planks: Node3D


func _build() -> void:
	add_to_group("door")
	interact_range = 2.4
	_hinge = Node3D.new()
	_hinge.position = Vector3(-width * 0.5, 0, 0)
	add_child(_hinge)
	var panel := box_mesh(Vector3(width, height, 0.12), color)
	panel.position = Vector3(width * 0.5, height * 0.5, 0)
	_hinge.add_child(panel)
	var stripe := box_mesh(Vector3(width * 0.9, 0.12, 0.14), Color(0.9, 0.7, 0.15))
	stripe.position = Vector3(width * 0.5, height * 0.45, 0)
	_hinge.add_child(stripe)
	var handle := box_mesh(Vector3(0.1, 0.1, 0.25), Color(0.2, 0.2, 0.22))
	handle.position = Vector3(width * 0.85, height * 0.45, 0)
	_hinge.add_child(handle)
	_body = static_box(_hinge, Vector3(width, height, 0.2), Vector3(width * 0.5, height * 0.5, 0), "metal")
	_planks = Node3D.new()
	add_child(_planks)
	for i in 3:
		var p := box_mesh(Vector3(width * 1.15, 0.22, 0.1), Color(0.45, 0.32, 0.2))
		p.position = Vector3(0, 0.7 + i * 0.7, -0.15)
		p.rotation.z = deg_to_rad(randf_range(-12, 12))
		_planks.add_child(p)
	_planks.visible = false
	if locked_by != "":
		Events.mission_event.connect(_on_mission_event)


func _on_mission_event(kind: String, target: String, _n: int) -> void:
	if kind == "power" and target == locked_by:
		locked_by = ""


func is_closed() -> bool:
	return not open and not broken


func can_interact(_p: Node) -> bool:
	return not broken


func get_prompt(_p: Node) -> String:
	if locked_by != "":
		return "Verrouillé (sans courant)"
	if barricaded:
		return "Retirer la barricade"
	return "Fermer la porte" if open else "Ouvrir la porte"


func interact(p: Node) -> void:
	if locked_by != "":
		Audio.play_at("ui_error", global_position, -6.0)
		return
	if barricaded:
		barricaded = false
		_planks.visible = false
		Game.add_item("barricade", 1)
		return
	set_open(not open, p)


func set_open(v: bool, opener: Node = null) -> void:
	open = v
	var ang := -95.0
	if opener and v:
		# Swing away from whoever opens it.
		var local := to_local(opener.global_position)
		ang = -95.0 if local.z < 0 else 95.0
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation_degrees:y", ang if v else 0.0, 0.35).set_trans(Tween.TRANS_QUAD)
	_body.collision_layer = 0 if v else Combat.LAYER_WORLD
	Audio.play_at("door_open" if v else "door_close", global_position, -2.0)
	Events.noise.emit(global_position, 7.0, opener)


func can_barricade() -> bool:
	return not open and not barricaded and not broken


func barricade() -> void:
	barricaded = true
	_planks.visible = true
	Audio.play_at("build_place", global_position)


func bash_time() -> float:
	return 6.5 if barricaded else 2.6


func force_open(dir: Vector3) -> void:
	broken = true
	open = true
	barricaded = false
	_planks.visible = false
	_body.collision_layer = 0
	Audio.play_at("door_slam", global_position, 4.0)
	Fx.dig_debris(global_position + Vector3.UP, Color(0.4, 0.4, 0.42))
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation_degrees:x", -88.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_hinge.position += dir * 0.6
