extends Interactable
## Travel point between regions (streets, tunnels, lift shafts).

var target_region := "forest"
var target_gate := ""
var label := ""


func _build() -> void:
	interact_range = 3.0
	var arch_c := Color(0.2, 0.9, 0.6) if Game.region_unlocked(target_region) else Color(0.9, 0.2, 0.2)
	for x in [-1.6, 1.6]:
		var post := box_mesh(Vector3(0.3, 3.2, 0.3), Color(0.25, 0.26, 0.3))
		post.position = Vector3(x, 1.6, 0)
		add_child(post)
	var beam := box_mesh(Vector3(3.5, 0.3, 0.3), arch_c, 2.0)
	beam.position.y = 3.2
	add_child(beam)
	var sign := Label3D.new()
	sign.text = label if label != "" else DB.REGIONS[target_region].name
	sign.font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.position = Vector3(0, 3.8, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.outline_size = 12
	sign.modulate = arch_c.lightened(0.4)
	add_child(sign)


func get_prompt(_p: Node) -> String:
	if not Game.region_unlocked(target_region):
		return "%s — %s" % [DB.REGIONS[target_region].name, Game.region_lock_reason(target_region)]
	return "Aller : " + DB.REGIONS[target_region].name


func interact(_p: Node) -> void:
	if not Game.region_unlocked(target_region):
		Audio.play("ui_error")
		Events.toast.emit(Game.region_lock_reason(target_region), "warn")
		return
	var w := get_tree().get_first_node_in_group("world")
	if w:
		w.store_player_state()
	Game.save_game()
	Loader.goto_world(target_region, target_gate)
