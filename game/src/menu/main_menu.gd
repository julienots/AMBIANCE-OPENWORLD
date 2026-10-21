extends Control
## Main menu: animated title, 3D showcase of the active hero, Continue / New game,
## hero collection, codex and settings (shared with the in-game menu).

const MenuScript := preload("res://src/ui/game_menu.gd")

var _menu: CanvasLayer
var _preview: HeroPreview
var _confirm: Control


func _ready() -> void:
	theme = UiKit.theme()
	if Game.profile.is_empty():
		Game.load_game()
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.03, 0.08))
	g.set_color(1, Color(0.01, 0.01, 0.03))
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.7, 0.55)
	grad.fill_to = Vector2(0.1, 0.0)
	bg.texture = grad
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	var motes := _Motes.new()
	motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(motes)
	var left := UiKit.vbox(14)
	left.position = Vector2(60, 70)
	left.custom_minimum_size = Vector2(440, 0)
	add_child(left)
	var t1 := UiKit.title("SYMBIOTE", 84, Color(0.96, 0.96, 1.0))
	t1.add_theme_color_override("font_shadow_color", Color(0.8, 0.05, 0.15, 0.9))
	t1.add_theme_constant_override("shadow_offset_x", 5)
	t1.add_theme_constant_override("shadow_offset_y", 6)
	left.add_child(t1)
	var t2 := UiKit.title("ABYSS", 64, UiKit.ACCENT)
	left.add_child(t2)
	left.add_child(UiKit.text("Un jeu SuperEssence studio", 16, Color(0.7, 0.68, 0.78)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	left.add_child(sp)
	var has := Save.has_save()
	if has:
		left.add_child(UiKit.button("▶  Continuer", _continue, 64))
	left.add_child(UiKit.button("✦  Nouvelle partie", _new_game, 58))
	left.add_child(UiKit.button("Héros", func(): _open("heroes"), 54, has))
	left.add_child(UiKit.button("Codex", func(): _open("codex"), 54, has))
	left.add_child(UiKit.button("Options", func(): _open("options"), 54))
	left.add_child(UiKit.button("Quitter", func(): get_tree().quit(), 50))
	_preview = HeroPreview.new(Vector2(560, 640))
	_preview.position = Vector2(get_viewport_rect().size.x - 620, 40)
	add_child(_preview)
	var hid: String = Game.profile.get("active_hero", "vortex") if not Game.profile.is_empty() else "vortex"
	_preview.show_model(DB.HEROES[hid].model, DB.HEROES[hid].color)
	var name_l := UiKit.title(DB.HEROES[hid].name + " — " + DB.HEROES[hid].title, 26, DB.HEROES[hid].color.lightened(0.3))
	name_l.position = Vector2(get_viewport_rect().size.x - 560, get_viewport_rect().size.y - 70)
	add_child(name_l)
	var ver := UiKit.text("v" + str(ProjectSettings.get_setting("application/config/version")), 13, Color(0.5, 0.5, 0.6), false)
	ver.position = Vector2(12, get_viewport_rect().size.y - 26)
	add_child(ver)
	_menu = MenuScript.new()
	add_child(_menu)
	Audio.play_music("menu", 2.0)
	Audio.set_ambience("")


func _continue() -> void:
	if Game.load_game():
		Loader.goto_world(Game.current_region, "")
	else:
		Events.toast.emit("Sauvegarde illisible", "warn")
		_new_game()


func _new_game() -> void:
	if Save.has_save() and _confirm == null:
		_confirm = UiKit.panel(Vector2(520, 0), Color(0.12, 0.04, 0.05, 0.97), Color(1, 0.3, 0.3))
		_confirm.position = get_viewport_rect().size / 2 - Vector2(260, 100)
		var v := UiKit.vbox()
		_confirm.add_child(v)
		v.add_child(UiKit.text("Une partie existe déjà. La remplacer ? (une copie de secours .bak est conservée)", 18))
		var h := UiKit.hbox()
		h.add_child(UiKit.button("Remplacer", func(): _confirm.queue_free(); _confirm = null; _start_new(), 54))
		h.add_child(UiKit.button("Annuler", func(): _confirm.queue_free(); _confirm = null, 54))
		v.add_child(h)
		add_child(_confirm)
		return
	_start_new()


func _start_new() -> void:
	Game.start_new_game()
	Loader.goto_world("city", "start")


func _open(tab: String) -> void:
	if Game.profile.is_empty() and not Game.load_game():
		Game.profile = Game.new_profile()
	_menu.open(tab, false)


class _Motes extends Control:
	## Drifting ember particles behind the menu.
	var pts: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 60:
			pts.append([Vector2(randf(), randf()), randf_range(0.01, 0.04), randf_range(1.0, 3.5), randf()])

	func _process(delta: float) -> void:
		for p in pts:
			p[0].y -= p[1] * delta
			p[0].x += sin(Time.get_ticks_msec() * 0.0005 + p[3] * 10.0) * delta * 0.01
			if p[0].y < -0.02:
				p[0] = Vector2(randf(), 1.02)
		queue_redraw()

	func _draw() -> void:
		for p in pts:
			var a := 0.25 + 0.35 * sin(Time.get_ticks_msec() * 0.002 + p[3] * 20.0)
			draw_circle(p[0] * size, p[2], Color(1.0, 0.45, 0.25, a))
