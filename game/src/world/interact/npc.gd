extends Interactable
## Survivor to rescue: talk to start the escort, it follows the player and cowers
## when creatures are close. Reaching a refuge completes the rescue.

var npc_model := "res://assets/models/monsters/scientist.glb"
var npc_name := "Dr Halvorsen"
var mission_tag := "scientist"
var following := false
var rescued := false
var _anim: AnimationPlayer
var _model: Node3D
var _vel := Vector3.ZERO


func _build() -> void:
	interact_range = 2.5
	_model = (load(npc_model) as PackedScene).instantiate()
	add_child(_model)
	Mats.apply(_model, false, false)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for n in ["idle", "run", "walk", "cower", "wave"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("cower")
	var tag := Label3D.new()
	tag.text = npc_name
	tag.font_size = 40
	tag.pixel_size = 0.005
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.2
	tag.modulate = Color(0.6, 1.0, 0.7)
	add_child(tag)


func can_interact(_p: Node) -> bool:
	return not following and not rescued


func get_prompt(_p: Node) -> String:
	return "Parler à " + npc_name


func interact(_p: Node) -> void:
	following = true
	Events.toast.emit("%s : « Je vous suis. Ne courez pas trop vite ! »" % npc_name, "dialog")
	_anim.play("wave", 0.2)


func _physics_process(delta: float) -> void:
	if not following or rescued:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var danger := false
	for e in Combat.in_radius(get_tree(), global_position, 6.0):
		if e.id != "nest":
			danger = true
	var to: Vector3 = p.global_position - global_position
	to.y = 0
	if danger:
		_anim.play("cower", 0.2)
	elif to.length() > 2.5:
		var spd := clampf(to.length() - 2.0, 2.0, 6.5)
		var dir := to.normalized()
		var next := global_position + dir * spd * delta
		var q := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 2.0, next + Vector3.DOWN * 3.0, Combat.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			next.y = hit.position.y
		if to.length() > 25.0:
			next = p.global_position - dir * 2.0
		global_position = next
		rotation.y = atan2(dir.x, dir.z)
		_anim.play("run" if spd > 3.5 else "walk", 0.2)
	else:
		_anim.play("idle", 0.2)
	for r in get_tree().get_nodes_in_group("refuge"):
		if r.global_position.distance_to(global_position) < 8.0:
			rescued = true
			following = false
			_anim.play("wave", 0.2)
			Events.mission_event.emit("rescue", mission_tag, 1)
			Events.toast.emit("%s est en sécurité !" % npc_name, "mission")
