extends Interactable
## Container with resources. Looted state is saved per container id.
## Mission caches emit an "activate" event with their tag.

var uid := ""
var table := {"metal": [1, 3], "materials": [1, 2]}
var kind := "crate"                 # crate | locker | car | cache
var mission_tag := ""
var items := {}                     # item id -> count
var _lid: Node3D


func _build() -> void:
	interact_range = 2.0
	if uid in Game.profile.get("opened", []):
		enabled = false
	match kind:
		"cache":
			var b := box_mesh(Vector3(1.0, 0.6, 0.7), Color(0.18, 0.35, 0.3))
			b.position.y = 0.3
			add_child(b)
			_lid = box_mesh(Vector3(1.04, 0.12, 0.74), Color(0.9, 0.7, 0.15))
			_lid.position.y = 0.66
			add_child(_lid)
			var beacon := box_mesh(Vector3(0.12, 0.12, 0.12), Color(0.3, 1.0, 0.5), 3.0 if enabled else 0.0)
			beacon.position = Vector3(0.35, 0.78, 0)
			add_child(beacon)
		_:
			var b := box_mesh(Vector3(0.9, 0.7, 0.9), Color(0.48, 0.36, 0.22))
			b.position.y = 0.35
			add_child(b)
			_lid = box_mesh(Vector3(0.95, 0.1, 0.95), Color(0.36, 0.26, 0.16))
			_lid.position.y = 0.75
			add_child(_lid)
	static_box(self, Vector3(0.95, 0.8, 0.95), Vector3(0, 0.4, 0), "metal")
	if not enabled and _lid:
		_lid.rotation_degrees.x = -70


func get_prompt(_p: Node) -> String:
	return "Ouvrir la cache" if kind == "cache" else "Fouiller"


func interact(_p: Node) -> void:
	enabled = false
	Game.profile.opened.append(uid)
	var tw := create_tween()
	tw.tween_property(_lid, "rotation_degrees:x", -70.0, 0.3).set_trans(Tween.TRANS_BACK)
	Audio.play_at("chest_open", global_position, -2.0)
	Events.noise.emit(global_position, 5.0, _p)
	var drops := Game.roll_drops(table)
	for k in drops:
		Pickup.spawn(get_parent(), global_position + Vector3.UP, k, drops[k])
	for it in items:
		var got := Game.add_item(it, items[it])
		if got > 0:
			Events.toast.emit("+%d %s" % [got, DB.ITEMS[it].name], "item")
	if mission_tag != "":
		Events.mission_event.emit("activate", mission_tag, 1)
