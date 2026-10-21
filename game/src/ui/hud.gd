extends CanvasLayer
## In-game HUD: vitals, objective + compass, boss bar, toasts, combo, threat feedback,
## horror post-processing, hiding overlay, audio-log transcripts and the death screen.

const TouchControls := preload("res://src/ui/touch_controls.gd")
const TITLE_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

var player: Node
var touch: Control
var _post: ColorRect
var _post_mat: ShaderMaterial
var _hp_bar: ProgressBar
var _hp_ghost: ProgressBar
var _en_bar: ProgressBar
var _st_bar: ProgressBar
var _hero_label: Label
var _level_label: Label
var _obj_title: Label
var _obj_text: Label
var _compass: Control
var _boss_box: Control
var _boss_bar: ProgressBar
var _boss_name: Label
var _boss: Node
var _toasts: VBoxContainer
var _combo: Label
var _hidden_label: Label
var _res_label: Label
var _fps: Label
var _death: Control
var _log_box: PanelContainer
var _log_text: Label
var _threat := 0.0
var _damage := 0.0
var _heartbeat_t := 0.0
var objective_pos := Vector3.INF
var objective_label := ""


func _ready() -> void:
	layer = 10
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://shaders/postfx.gdshader")
	_post_mat.set_shader_parameter("grain_tex", load("res://assets/textures/grain.png"))
	_post.material = _post_mat
	add_child(_post)
	_build_vitals()
	_build_objective()
	_build_boss()
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(20, 210)
	_toasts.custom_minimum_size = Vector2(460, 0)
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_combo = _title_label(54, Color(1, 0.85, 0.25))
	_combo.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_combo.position = Vector2(-260, -40)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.size = Vector2(220, 60)
	add_child(_combo)
	_hidden_label = _title_label(30, Color(0.7, 0.9, 1.0))
	_hidden_label.text = "CACHÉ — restez silencieux"
	_hidden_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hidden_label.position = Vector2(-220, -200)
	_hidden_label.size = Vector2(440, 40)
	_hidden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hidden_label.visible = false
	add_child(_hidden_label)
	_res_label = Label.new()
	_res_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_res_label.position = Vector2(-560, 14)
	_res_label.size = Vector2(470, 30)
	_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_res_label.add_theme_font_size_override("font_size", 18)
	_res_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_res_label.add_theme_constant_override("outline_size", 6)
	add_child(_res_label)
	_fps = Label.new()
	_fps.position = Vector2(8, 690)
	add_child(_fps)
	touch = TouchControls.new()
	add_child(touch)
	_build_log_box()
	_build_death()
	Events.toast.connect(_on_toast)
	Events.combo_changed.connect(_on_combo)
	Events.player_damaged.connect(func(a): _damage = minf(1.0, _damage + a / 30.0))
	Events.threat_level.connect(func(t): _threat = t)
	Events.player_hidden.connect(func(h): _hidden_label.visible = h)
	Events.boss_started.connect(_on_boss)
	Events.mission_updated.connect(func(_m): _refresh_objective())
	Events.mission_completed.connect(func(_m): _refresh_objective())
	Events.resources_changed.connect(_refresh_res)
	Events.player_died.connect(_on_death)
	Events.log_found.connect(_on_log)
	Events.jumpscare.connect(_on_jumpscare)
	_refresh_objective()
	_refresh_res()


func set_player(p: Node) -> void:
	player = p
	touch.set_player(p)
	p.hero_changed.connect(_refresh_hero)
	_refresh_hero()


func _title_label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(col: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(h / 2))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(int(h / 2))
	back.border_color = Color(1, 1, 1, 0.25)
	back.set_border_width_all(1)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_vitals() -> void:
	var box := Control.new()
	box.position = Vector2(18, 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_hero_label = _title_label(26, Color.WHITE)
	_hero_label.position = Vector2(0, 0)
	box.add_child(_hero_label)
	_level_label = Label.new()
	_level_label.position = Vector2(0, 32)
	_level_label.add_theme_font_size_override("font_size", 15)
	_level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	box.add_child(_level_label)
	_hp_ghost = _bar(Color(1, 1, 1, 0.5), 300, 18)
	_hp_ghost.position = Vector2(0, 56)
	box.add_child(_hp_ghost)
	_hp_bar = _bar(Color(0.25, 0.95, 0.45), 300, 18)
	_hp_bar.position = Vector2(0, 56)
	box.add_child(_hp_bar)
	_en_bar = _bar(Color(0.3, 0.75, 1.0), 240, 11)
	_en_bar.position = Vector2(0, 80)
	box.add_child(_en_bar)
	_st_bar = _bar(Color(1.0, 0.85, 0.3), 180, 7)
	_st_bar.position = Vector2(0, 97)
	box.add_child(_st_bar)


func _build_objective() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-260, 12)
	box.custom_minimum_size = Vector2(520, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_obj_title = _title_label(22, Color(1, 0.82, 0.2))
	_obj_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_obj_title)
	_obj_text = Label.new()
	_obj_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_text.add_theme_font_size_override("font_size", 17)
	_obj_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_obj_text.add_theme_constant_override("outline_size", 6)
	box.add_child(_obj_text)
	_compass = Control.new()
	_compass.custom_minimum_size = Vector2(520, 26)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	box.add_child(_compass)


func _build_boss() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.position = Vector2(-330, -70)
	_boss_box.custom_minimum_size = Vector2(660, 0)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_box)
	_boss_name = _title_label(26, Color(1, 0.35, 0.35))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color(0.85, 0.12, 0.2), 660, 16)
	_boss_box.add_child(_boss_bar)


func _build_log_box() -> void:
	_log_box = PanelContainer.new()
	_log_box.set_anchors_preset(Control.PRESET_CENTER)
	_log_box.position = Vector2(-330, -120)
	_log_box.custom_minimum_size = Vector2(660, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.04, 0.9)
	sb.border_color = Color(0.3, 1.0, 0.6, 0.6)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	_log_box.add_theme_stylebox_override("panel", sb)
	_log_text = Label.new()
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.custom_minimum_size = Vector2(620, 0)
	_log_text.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_log_text.add_theme_font_size_override("font_size", 19)
	_log_box.add_child(_log_text)
	_log_box.visible = false
	_log_box.gui_input.connect(func(e): if e is InputEventScreenTouch or e is InputEventMouseButton: _log_box.visible = false)
	add_child(_log_box)


func _build_death() -> void:
	_death = ColorRect.new()
	_death.color = Color(0.1, 0.0, 0.02, 0.75)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.visible = false
	add_child(_death)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(-250, -90)
	vb.custom_minimum_size = Vector2(500, 0)
	vb.add_theme_constant_override("separation", 20)
	_death.add_child(vb)
	var t := _title_label(56, Color(0.95, 0.2, 0.25))
	t.text = "VOUS AVEZ SUCCOMBÉ"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var b := Button.new()
	b.text = "Revenir au dernier refuge"
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func():
		_death.visible = false
		var w := get_tree().get_first_node_in_group("world")
		if w:
			w.respawn_player())
	vb.add_child(b)


# ------------------------------------------------------------------------------ events

func _on_toast(text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", 18)
	var col := Color(0.95, 0.95, 1.0)
	match kind:
		"warn": col = Color(1.0, 0.55, 0.4)
		"mission", "level", "hero": col = Color(1.0, 0.85, 0.3)
		"objective": col = Color(0.6, 1.0, 0.7)
		"counter": col = Color(0.5, 0.9, 1.0)
		"codex", "research": col = Color(0.85, 0.6, 1.0)
		"dialog": col = Color(0.8, 1.0, 0.85)
	if kind.begins_with("res:"):
		col = DB.RESOURCES[kind.substr(4)].color.lightened(0.3)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(l)
	if _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
	if kind in ["mission", "level", "hero"]:
		Audio.play("levelup" if kind != "mission" else "ui_reward", -4.0)
	elif not kind.begins_with("res:"):
		Audio.play("toast", -12.0)
	var tw := l.create_tween()
	tw.tween_interval(3.5 if not kind.begins_with("res:") else 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _on_combo(n: int) -> void:
	_combo.text = "" if n < 3 else "%d COMBO" % n
	if n >= 3:
		_combo.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.12)


func _on_boss(boss: Node, title: String) -> void:
	_boss = boss
	_boss_name.text = title
	_boss_box.visible = true


func _on_death() -> void:
	await get_tree().create_timer(1.6).timeout
	_death.visible = true


func _on_log(id: String) -> void:
	var l: Dictionary = DB.AUDIO_LOGS[id]
	_log_text.text = "◉ %s\n\n%s\n\n(touchez pour fermer)" % [l.title, l.text]
	_log_box.visible = true


func _on_jumpscare(intensity: float) -> void:
	_damage = maxf(_damage, intensity * 0.6 * float(Settings.get_v("horror_fx", 1.0)))
	Fx.add_shake(intensity * 0.5)


func _refresh_hero() -> void:
	if player == null:
		return
	_hero_label.text = player.hero.name
	_hero_label.add_theme_color_override("font_color", player.hero.color.lightened(0.3))
	var h := Game.hero_state(player.hero_id)
	_level_label.text = "Héros niv. %d   ·   Joueur niv. %d" % [int(h.get("level", 1)), Game.player_level()]


func _refresh_objective() -> void:
	var id := Game.active_mission_id()
	if id == "":
		_obj_title.text = "Aucune mission active"
		_obj_text.text = "Ouvrez le menu (II) › Missions"
		return
	var m: Dictionary = DB.MISSIONS[id]
	_obj_title.text = m.title
	var cur := Game.current_objective(id)
	if cur.is_empty():
		_obj_text.text = ""
	else:
		_obj_text.text = "%s  (%d/%d)" % [cur.text, cur.done, cur.count]
	_refresh_hero()


func _refresh_res() -> void:
	var parts: PackedStringArray = []
	for k in ["metal", "crystal", "electronics", "materials", "samples"]:
		parts.append("%s %d" % [DB.RESOURCES[k].icon, Game.res(k)])
	_res_label.text = "   ".join(parts)


# ------------------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if player:
		_hp_bar.max_value = player.max_hp
		_hp_bar.value = player.hp
		_hp_ghost.max_value = player.max_hp
		_hp_ghost.value = maxf(player.hp, move_toward(_hp_ghost.value, player.hp, delta * 30.0))
		_en_bar.max_value = player.max_energy
		_en_bar.value = player.energy
		_st_bar.max_value = player.max_stamina
		_st_bar.value = player.stamina
		_st_bar.modulate.a = 1.0 if player.stamina < player.max_stamina - 1 else 0.35
		var low := clampf(1.0 - player.hp / player.max_hp * 3.0, 0.0, 1.0)
		_post_mat.set_shader_parameter("low_hp", low)
		_post_mat.set_shader_parameter("hidden", 1.0 if player.state == "hidden" else 0.0)
	_damage = maxf(0.0, _damage - delta * 1.5)
	var hfx := float(Settings.get_v("horror_fx", 1.0))
	_post.visible = bool(Settings.get_v("post_fx", true))
	_post_mat.set_shader_parameter("threat", _threat)
	_post_mat.set_shader_parameter("damage", _damage)
	_post_mat.set_shader_parameter("strength", hfx)
	# Heartbeat when something hunts nearby.
	if _threat > 0.25:
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = lerpf(1.1, 0.42, _threat)
			Audio.play("heartbeat", linear_to_db(clampf(_threat, 0.1, 1.0)) - 4.0, 0.0)
	if _boss and is_instance_valid(_boss) and _boss.alive:
		_boss_bar.max_value = _boss.max_hp
		_boss_bar.value = _boss.hp
	elif _boss_box.visible:
		_boss_box.visible = false
		_boss = null
	if Settings.get_v("show_fps", false):
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	else:
		_fps.text = ""
	_compass.queue_redraw()


func _draw_compass() -> void:
	if objective_pos == Vector3.INF or player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var w := _compass.size.x
	var to := objective_pos - player.global_position
	var dist := Vector2(to.x, to.z).length()
	var fwd := -cam.global_transform.basis.z
	var ang := atan2(fwd.x * to.z - fwd.z * to.x, fwd.x * to.x + fwd.z * to.z)
	var x := w * 0.5 + clampf(ang / PI, -1.0, 1.0) * w * 0.5
	_compass.draw_line(Vector2(0, 13), Vector2(w, 13), Color(1, 1, 1, 0.2), 2.0)
	var col := Color(1, 0.82, 0.2)
	_compass.draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x - 9, 18), Vector2(x + 9, 18)]), col)
	_compass.draw_string(TITLE_FONT, Vector2(clampf(x + 14, 0, w - 70), 22), "%d m" % int(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
