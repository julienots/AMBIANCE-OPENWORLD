extends Control
## Multitouch controls drawn in a single control:
##  - left side: dynamic joystick (appears under the thumb; edge push = sprint)
##  - right side: camera drag area
##  - action buttons with radial cooldowns, energy dimming, hold-to-charge attack
##  - edit mode: drag buttons to customise the layout (saved in Settings.layout)

signal pause_pressed

const ICON_DIR := "res://assets/icons/"
const HOLD_HEAVY := 0.35

var player: Node
var edit_mode := false
var _touches := {}          # index -> {kind, button, start, pos, t}
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_active := false
var _icons := {}
var _font: Font
var _btn_state := {}        # name -> pressed bool
var _interact_prompt := ""
var _interact_repeat := 0.0
var buttons := {}           # name -> {pos: Vector2 (from bottom-right), r, icon}

const DEFAULT_LAYOUT := {
	"attack": [Vector2(-140, -140), 70.0],
	"dodge": [Vector2(-282, -78), 44.0],
	"ability1": [Vector2(-275, -190), 42.0],
	"ability2": [Vector2(-222, -292), 42.0],
	"ability3": [Vector2(-112, -310), 42.0],
	"ultimate": [Vector2(-330, -300), 46.0],
	"interact": [Vector2(-150, -440), 48.0],
	"item": [Vector2(-420, -78), 38.0],
	"item_next": [Vector2(-470, -140), 22.0],
	"crouch": [Vector2(-70, -560), 32.0],
	"flashlight": [Vector2(-150, -560), 32.0],
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)
	_font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
	for n in ["attack", "dodge", "interact", "crouch", "flashlight", "pause", "cycle", "map"]:
		_icons[n] = load(ICON_DIR + n + ".png")
	for it in DB.ITEMS:
		_icons["item_" + it] = load(ICON_DIR + it + ".png")
	Events.interaction_available.connect(func(p, _t): _interact_prompt = p)
	Events.interaction_cleared.connect(func(_t): _interact_prompt = "")
	Settings.changed.connect(_rebuild)
	_rebuild()


func _fit_screen() -> void:
	## Under a CanvasLayer, anchors do not reliably give this control the screen size:
	## size it explicitly so buttons and the joystick zone are always on screen.
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	queue_redraw()


func _joy_home() -> Vector2:
	var r := 80.0 * float(Settings.get_v("button_scale", 1.0))
	return Vector2(r + 70.0, size.y - r - 70.0)


func _rebuild() -> void:
	var sc := float(Settings.get_v("button_scale", 1.0))
	var custom: Dictionary = Settings.get_v("layout", {})
	buttons.clear()
	for n in DEFAULT_LAYOUT:
		var pos: Vector2 = DEFAULT_LAYOUT[n][0]
		if custom.has(n):
			pos = Vector2(custom[n][0], custom[n][1])
		buttons[n] = {"pos": pos, "r": float(DEFAULT_LAYOUT[n][1]) * sc}
	queue_redraw()


func set_player(p: Node) -> void:
	player = p
	if p:
		p.hero_changed.connect(_load_hero_icons)
		_load_hero_icons()


func _load_hero_icons() -> void:
	if player == null:
		return
	for i in 3:
		_icons["ability%d" % (i + 1)] = load(ICON_DIR + player.hero.abilities[i].kind + ".png")
	_icons["ultimate"] = load(ICON_DIR + player.hero.ultimate.kind + ".png")


func _btn_center(n: String) -> Vector2:
	return size + buttons[n].pos


func _hit_button(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for n in buttons:
		if n == "interact" and _interact_prompt == "" and not edit_mode:
			continue
		var d := p.distance_to(_btn_center(n))
		if d <= buttons[n].r * 1.25 and d < best_d:
			best = n
			best_d = d
	var pause_c := Vector2(size.x - 46, 46)
	if p.distance_to(pause_c) < 36:
		return "pause"
	return best


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		Pad.touch_active = true
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		Pad.touch_active = true
		_touch_move(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()


func _touch_down(idx: int, p: Vector2) -> void:
	var b := _hit_button(p)
	if b != "":
		_touches[idx] = {"kind": "button", "button": b, "start": p, "pos": p, "t": 0.0}
		if edit_mode:
			return
		_btn_state[b] = true
		match b:
			"attack":
				Pad.press("attack_down")
			"pause":
				pause_pressed.emit()
			"interact":
				Pad.press("interact")
				_interact_repeat = 0.35
			_:
				Pad.press(b)
		queue_redraw()
		return
	if edit_mode:
		return
	if p.x < size.x * 0.45 and p.y > size.y * 0.25 and not _joy_active:
		_joy_active = true
		# Touching near the visible stick grabs it; elsewhere in the zone it re-centres under the thumb.
		_joy_origin = _joy_home() if p.distance_to(_joy_home()) < 120.0 else Vector2(clampf(p.x, 100, size.x * 0.45), clampf(p.y, size.y * 0.3, size.y - 100))
		_joy_pos = p
		_touches[idx] = {"kind": "joy", "pos": p}
		_update_joy()
	else:
		_touches[idx] = {"kind": "look", "pos": p}


func _touch_move(idx: int, p: Vector2, rel: Vector2) -> void:
	if not _touches.has(idx):
		return
	var t: Dictionary = _touches[idx]
	t.pos = p
	match t.kind:
		"joy":
			_joy_pos = p
			_update_joy()
		"look":
			Pad.look += rel * 1.6
		"button":
			if edit_mode:
				var n: String = t.button
				if n != "pause":
					buttons[n].pos = p - size
				queue_redraw()
			elif t.button == "attack":
				pass
			elif p.distance_to(t.start) > 60.0 and t.button != "item":
				# Thumb slid off a button: treat the rest of the gesture as camera look.
				pass


func _touch_up(idx: int, p: Vector2) -> void:
	if not _touches.has(idx):
		return
	var t: Dictionary = _touches[idx]
	_touches.erase(idx)
	match t.kind:
		"joy":
			_joy_active = false
			Pad.move = Vector2.ZERO
			Pad.release("sprint_hold")
		"button":
			var b: String = t.button
			_btn_state[b] = false
			if edit_mode:
				_save_layout()
			elif b == "attack":
				Pad.release("attack_down")
				Pad.press("heavy" if t.t >= HOLD_HEAVY else "attack")
			else:
				Pad.release(b)
	queue_redraw()


func _update_joy() -> void:
	var r := 80.0 * float(Settings.get_v("button_scale", 1.0))
	var v := (_joy_pos - _joy_origin) / r
	if v.length() > 1.0:
		# Let the joystick follow the thumb when pushed far away.
		_joy_origin = _joy_pos - v.normalized() * r
		v = v.normalized()
	Pad.move = v if v.length() > 0.12 else Vector2.ZERO
	if v.length() > 0.97:
		Pad.move = v.normalized()
	queue_redraw()


func _save_layout() -> void:
	var lay := {}
	for n in buttons:
		lay[n] = [buttons[n].pos.x, buttons[n].pos.y]
	Settings.set_value("layout", lay)


func reset_layout() -> void:
	Settings.set_value("layout", {})


func _process(delta: float) -> void:
	if size != get_viewport().get_visible_rect().size:
		_fit_screen()
	for idx in _touches:
		var t: Dictionary = _touches[idx]
		if t.kind == "button":
			t.t += delta
			if t.button == "interact" and not edit_mode:
				_interact_repeat -= delta
				if _interact_repeat <= 0.0:
					_interact_repeat = 0.15
					Pad.press("interact")
	queue_redraw()


# ----------------------------------------------------------------------------- drawing

func _draw() -> void:
	var a := float(Settings.get_v("ui_opacity", 0.85))
	var hero_col: Color = player.hero.color if player else Color(0.3, 0.9, 1.0)
	# Joystick
	if _joy_active:
		var r := 80.0 * float(Settings.get_v("button_scale", 1.0))
		draw_circle(_joy_origin, r, Color(0, 0, 0, 0.25 * a))
		draw_arc(_joy_origin, r, 0, TAU, 48, Color(1, 1, 1, 0.35 * a), 3.0, true)
		var knob := _joy_origin + (_joy_pos - _joy_origin).limit_length(r)
		var sprint := Pad.move.length() > 0.97
		draw_circle(knob, r * 0.42, Color(hero_col.r, hero_col.g, hero_col.b, (0.75 if sprint else 0.5) * a))
	else:
		# Always-visible resting joystick.
		var r := 80.0 * float(Settings.get_v("button_scale", 1.0))
		var home := _joy_home()
		draw_circle(home, r, Color(0, 0, 0, 0.3 * a))
		draw_arc(home, r, 0, TAU, 48, Color(1, 1, 1, 0.45 * a), 3.0, true)
		draw_circle(home, r * 0.42, Color(hero_col.r, hero_col.g, hero_col.b, 0.55 * a))
		for k in 4:
			var ang := k * PI / 2
			var tip := home + Vector2(cos(ang), sin(ang)) * r * 0.78
			draw_colored_polygon(PackedVector2Array([tip + Vector2(cos(ang), sin(ang)) * 8, tip + Vector2(cos(ang + 2.2), sin(ang + 2.2)) * 8, tip + Vector2(cos(ang - 2.2), sin(ang - 2.2)) * 8]), Color(1, 1, 1, 0.5 * a))
	# Pause
	var pc := Vector2(size.x - 46, 46)
	draw_circle(pc, 26, Color(0, 0, 0, 0.4 * a))
	_draw_icon("pause", pc, 30, Color(1, 1, 1, 0.85 * a))
	for n in buttons:
		_draw_button(n, a, hero_col)


func _draw_button(n: String, a: float, hero_col: Color) -> void:
	if n == "interact" and _interact_prompt == "" and not edit_mode:
		return
	if n in ["item", "item_next"] and player and player.current_item() == "" and not edit_mode:
		return
	var c := _btn_center(n)
	var r: float = buttons[n].r
	var pressed: bool = _btn_state.get(n, false)
	var bg := Color(0.04, 0.04, 0.08, 0.55 * a)
	var ring := Color(1, 1, 1, 0.5 * a)
	var icon_col := Color(1, 1, 1, 0.95 * a)
	var cd_frac := 0.0
	var label := ""
	match n:
		"attack":
			ring = Color(hero_col.r, hero_col.g, hero_col.b, 0.9 * a)
		"ability1", "ability2", "ability3":
			var i := int(n.substr(7)) - 1
			ring = Color(hero_col.r, hero_col.g, hero_col.b, 0.85 * a)
			if player:
				var cd: float = player.cooldowns[i]
				if cd > 0.0:
					cd_frac = cd / maxf(player.ability_cd(i), 0.01)
					label = "%d" % ceili(cd)
				elif player.energy < player.ability_cost(i):
					icon_col = Color(0.5, 0.5, 0.6, 0.6 * a)
					ring = Color(0.4, 0.4, 0.5, 0.6 * a)
		"ultimate":
			if player:
				var u: float = player.ult / 100.0
				var ready := u >= 1.0
				draw_circle(c, r, Color(0.1, 0.02, 0.05, 0.6 * a))
				draw_arc(c, r - 3, -PI / 2, -PI / 2 + TAU * u, 48, Color(1.0, 0.75, 0.2, 0.95 * a), 6.0, true)
				if ready:
					var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
					draw_arc(c, r + 6 + pulse * 4, 0, TAU, 48, Color(1.0, 0.8, 0.2, 0.7 * a), 4.0, true)
				else:
					icon_col = Color(0.6, 0.55, 0.5, 0.6 * a)
				_draw_icon(n, c, r * 1.1, icon_col)
				return
		"interact":
			ring = Color(0.4, 1.0, 0.6, 0.95 * a)
			var tw := _font.get_string_size(_interact_prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			var box := Rect2(c + Vector2(-r - 16 - tw.x - 20, -18), Vector2(tw.x + 24, 36))
			draw_rect(box, Color(0, 0, 0, 0.6 * a))
			draw_string(_font, box.position + Vector2(12, 26), _interact_prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 1.0, 0.9, a))
		"crouch":
			if player and player.crouching:
				bg = Color(0.2, 0.5, 0.3, 0.6 * a)
		"flashlight":
			if player and player.flashlight_on:
				bg = Color(0.6, 0.55, 0.2, 0.6 * a)
		"dodge":
			if player and player.stamina < 12.0:
				icon_col = Color(0.5, 0.5, 0.6, 0.5 * a)
		"item":
			if player:
				var id: String = player.current_item()
				if id != "":
					label = str(Game.item_count(id))
					draw_circle(c, r * (0.92 if pressed else 1.0), bg)
					draw_arc(c, r, 0, TAU, 40, Color(0.9, 0.8, 0.3, 0.8 * a), 3.0, true)
					_draw_tex(_icons.get("item_" + id), c, r * 1.1, icon_col)
					draw_string(_font, c + Vector2(r * 0.35, r * 0.95), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4, a))
					return
		"item_next":
			draw_circle(c, r, bg)
			_draw_icon("cycle", c, r * 1.2, icon_col)
			return
	if pressed:
		r *= 0.92
		bg = bg.lightened(0.2)
	draw_circle(c, r, bg)
	draw_arc(c, r, 0, TAU, 48, ring, 3.0 if n != "attack" else 5.0, true)
	if n == "attack":
		for idx in _touches:
			var t: Dictionary = _touches[idx]
			if t.kind == "button" and t.button == "attack" and t.t > 0.12:
				var f := clampf(t.t / HOLD_HEAVY, 0.0, 1.0)
				draw_arc(c, r + 8, -PI / 2, -PI / 2 + TAU * f, 48, Color(1, 0.6, 0.2, 0.9 * a), 6.0, true)
	_draw_icon(n, c, r * 1.05, icon_col)
	if cd_frac > 0.0:
		draw_circle(c, r - 2, Color(0, 0, 0, 0.45 * a))
		draw_arc(c, r - 4, -PI / 2, -PI / 2 + TAU * (1.0 - cd_frac), 40, Color(1, 1, 1, 0.6 * a), 4.0, true)
		draw_string(_font, c + Vector2(-10, 10), label, HORIZONTAL_ALIGNMENT_CENTER, 20, 26, Color(1, 1, 1, a))
	if edit_mode:
		draw_arc(c, r + 6, 0, TAU, 32, Color(1, 0.8, 0.2, 0.8), 2.0, true)


func _draw_icon(n: String, c: Vector2, sz: float, col: Color) -> void:
	_draw_tex(_icons.get(n), c, sz, col)


func _draw_tex(tex: Texture2D, c: Vector2, sz: float, col: Color) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, col)
