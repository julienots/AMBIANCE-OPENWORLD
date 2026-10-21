extends Control
## Main menu (temporary minimal version).

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	add_child(vb)
	var b := Button.new()
	b.text = "Continuer" if Save.has_save() else "Nouvelle partie"
	b.pressed.connect(func():
		if Save.has_save() and Game.load_game():
			Loader.goto_world(Game.current_region, "")
		else:
			Game.start_new_game()
			Loader.goto_world("city", "start"))
	vb.add_child(b)
