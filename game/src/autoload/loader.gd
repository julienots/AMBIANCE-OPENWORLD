extends Node
## Scene transitions with a loading screen. The world reports real build progress
## through set_progress() while it generates a region over several frames.

const WORLD_SCENE := "res://src/world/world.tscn"
const MENU_SCENE := "res://src/menu/main_menu.tscn"

const TIPS := [
	"Accroupi dans l'ombre, vous êtes presque invisible pour les symbiotes.",
	"Le Dévoreur ne voit pas à travers les murs, mais il entend très bien.",
	"Une fusée éclairante aveugle le Dévoreur quelques secondes.",
	"Les rampants fuient la lumière des lampes de votre base.",
	"Esquivez au dernier moment pour déclencher une contre-attaque au ralenti.",
	"Les ennemis étourdis peuvent être exécutés ou capturés.",
	"Renforcez les parois de votre base : les fouisseurs ne peuvent pas les traverser.",
	"Étudier une famille de symbiotes augmente vos dégâts contre elle.",
	"Un générateur en panne coupe vos tourelles. Réparez-le vite.",
	"Les imitateurs copient la voix des survivants. Méfiez-vous des appels à l'aide.",
	"Les fouisseurs sont aveugles : restez immobile pour disparaître de leurs sens.",
	"Courir fait du bruit. Marcher accroupi est silencieux.",
]

var _layer: CanvasLayer
var _bar: ProgressBar
var _label: Label
var _tip: Label
var _title: Label
var busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.visible = false
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.012, 0.025)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	_layer.add_child(vb)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.18))
	vb.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(560, 18)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.82, 0.18)
	fill.set_corner_radius_all(9)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.12, 0.1, 0.16)
	back.set_corner_radius_all(9)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	vb.add_child(_bar)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.8))
	vb.add_child(_label)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(700, 0)
	_tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tip.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95))
	_tip.add_theme_font_size_override("font_size", 20)
	vb.add_child(_tip)


func show_loading(title: String) -> void:
	_title.text = title
	_tip.text = "Astuce : " + TIPS.pick_random()
	_bar.value = 0
	_label.text = "Chargement…"
	_layer.visible = true


func set_progress(p: float, text := "") -> void:
	_bar.value = clampf(p, 0.0, 1.0) * 100.0
	if text != "":
		_label.text = text


func hide_loading() -> void:
	var tw := create_tween()
	_layer.visible = true
	tw.tween_interval(0.15)
	tw.tween_callback(func(): _layer.visible = false; busy = false)


func goto_world(region: String, gate := "") -> void:
	if busy:
		return
	busy = true
	Fx.reset_time()
	get_tree().paused = false
	Game.current_region = region
	Game.spawn_gate = gate
	show_loading(DB.REGIONS[region].name)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(WORLD_SCENE)


func goto_menu() -> void:
	busy = true
	Fx.reset_time()
	get_tree().paused = false
	show_loading("SYMBIOTE: ABYSS")
	await get_tree().process_frame
	get_tree().change_scene_to_file(MENU_SCENE)
	await get_tree().process_frame
	hide_loading()
