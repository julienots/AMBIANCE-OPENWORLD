extends Interactable
## Safe refuge: heals, saves, opens the refuge menu (heroes, workshop, base access).
## Creatures avoid its lit perimeter.

var refuge_id := "lumiere"
var mission_tag := "refuge"
var safe_radius := 9.0


func _build() -> void:
	add_to_group("refuge")
	interact_range = 3.0
	var tent := box_mesh(Vector3(3.0, 0.15, 3.0), Color(0.25, 0.3, 0.35))
	tent.position.y = 0.08
	add_child(tent)
	var radio := box_mesh(Vector3(0.7, 0.5, 0.4), Color(0.2, 0.25, 0.22))
	radio.position = Vector3(0, 0.8, 0)
	add_child(radio)
	var table := box_mesh(Vector3(1.4, 0.08, 0.8), Color(0.45, 0.35, 0.25))
	table.position.y = 0.55
	add_child(table)
	var screen := box_mesh(Vector3(0.5, 0.3, 0.05), Color(0.3, 1.0, 0.7), 2.0)
	screen.position = Vector3(0, 1.1, -0.18)
	add_child(screen)
	var hatch := box_mesh(Vector3(1.2, 0.12, 1.2), Color(0.55, 0.5, 0.2))
	hatch.position = Vector3(2.2, 0.06, 0)
	add_child(hatch)
	var l := Label3D.new()
	l.text = "REFUGE"
	l.font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
	l.font_size = 72
	l.pixel_size = 0.006
	l.modulate = Color(0.4, 1.0, 0.6)
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = Vector3(0, 2.6, 0)
	add_child(l)
	static_box(self, Vector3(1.4, 0.9, 0.8), Vector3(0, 0.45, 0), "metal")


func get_prompt(_p: Node) -> String:
	return "Refuge : se reposer, héros, base"


func interact(p: Node) -> void:
	p.heal(p.max_hp)
	p.energy = p.max_energy
	Audio.play("heal", -4.0)
	var w := get_tree().get_first_node_in_group("world")
	if w:
		w.store_player_state()
		w.open_refuge_menu(self)
	Game.save_game()


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.global_position.distance_to(global_position) < safe_radius:
		Events.mission_event.emit("reach", mission_tag, 1)
		set_process(false)
		await get_tree().create_timer(2.0).timeout
		set_process(true)
