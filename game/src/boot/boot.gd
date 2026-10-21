extends Control
## Startup: SuperEssence studio logo, then the game title while resources are preloaded.

const PRELOAD := [
	"res://assets/models/heroes/vortex.glb",
	"res://assets/models/monsters/crawler.glb",
	"res://assets/models/monsters/devourer.glb",
	"res://shaders/toon.gdshader",
	"res://shaders/symbiote.gdshader",
	"res://src/menu/main_menu.tscn",
]

var _skip := false
var _stage := 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	await get_tree().process_frame
	await _studio_logo()
	await _title_and_preload()
	get_tree().change_scene_to_file("res://src/menu/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_skip = true


func _wait(t: float) -> void:
	var e := 0.0
	while e < t and not _skip:
		await get_tree().process_frame
		e += get_process_delta_time()


func _studio_logo() -> void:
	var tex: Texture2D = load("res://assets/branding/superessence_logo.png")
	var logo := TextureRect.new()
	logo.texture = tex
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_CENTER)
	var w := minf(get_viewport_rect().size.x * 0.62, 1000.0)
	logo.size = Vector2(w, w * tex.get_height() / tex.get_width())
	logo.position = get_viewport_rect().size / 2 - logo.size / 2
	logo.pivot_offset = logo.size / 2
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/logo_shine.gdshader")
	logo.material = mat
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.92, 0.92)
	add_child(logo)
	var sub := Label.new()
	sub.text = "S T U D I O"
	sub.add_theme_font_override("font", load("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(get_viewport_rect().size.x, 40)
	sub.position = Vector2(0, logo.position.y + logo.size.y + 6)
	sub.modulate.a = 0.0
	add_child(sub)
	Audio.play("logo_sting", -2.0, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate:a", 1.0, 0.9)
	tw.tween_property(logo, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a", 1.0, 0.8).set_delay(1.0)
	tw.tween_method(func(v): mat.set_shader_parameter("progress", v), -0.3, 1.3, 1.1).set_delay(1.5)
	await _wait(3.1)
	var out := create_tween().set_parallel(true)
	out.tween_property(logo, "modulate:a", 0.0, 0.6)
	out.tween_property(sub, "modulate:a", 0.0, 0.6)
	await out.finished
	logo.queue_free()
	sub.queue_free()
	_skip = false


func _title_and_preload() -> void:
	var title := Label.new()
	title.text = "SYMBIOTE: ABYSS"
	title.add_theme_font_override("font", load("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 86)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.75, 0.05, 0.15, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.modulate.a = 0.0
	add_child(title)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size = Vector2(420, 10)
	bar.position = Vector2(get_viewport_rect().size.x / 2 - 210, get_viewport_rect().size.y * 0.72)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.08, 0.2)
	fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.08, 0.12)
	back.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	add_child(bar)
	create_tween().tween_property(title, "modulate:a", 1.0, 0.8)
	for p in PRELOAD:
		ResourceLoader.load_threaded_request(p)
	var done := 0
	while done < PRELOAD.size():
		done = 0
		var prog := 0.0
		for p in PRELOAD:
			var arr := []
			var st := ResourceLoader.load_threaded_get_status(p, arr)
			if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				done += 1
				prog += 1.0
			elif arr.size() > 0:
				prog += float(arr[0])
		bar.value = prog / PRELOAD.size() * 100.0
		await get_tree().process_frame
	for p in PRELOAD:
		ResourceLoader.load_threaded_get(p)
	bar.value = 100
	await _wait(0.8)
