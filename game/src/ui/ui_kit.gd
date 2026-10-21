class_name UiKit
## Shared UI construction helpers and theme (touch-friendly sizes, dark glass panels,
## yellow accent from the SuperEssence logo).

const TITLE_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
const ACCENT := Color(1.0, 0.82, 0.18)
const BG := Color(0.035, 0.03, 0.055, 0.94)
const PANEL := Color(0.08, 0.07, 0.11, 0.92)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = 19
	var normal := _sb(Color(0.13, 0.12, 0.18), Color(1, 1, 1, 0.12))
	var hover := _sb(Color(0.18, 0.16, 0.24), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6))
	var pressed := _sb(Color(0.3, 0.24, 0.08), ACCENT)
	var disabled := _sb(Color(0.08, 0.08, 0.1), Color(1, 1, 1, 0.05))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Color(0.95, 0.95, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, Color(1, 1, 1, 0.08), 14))
	t.set_color("font_color", "Label", Color(0.92, 0.92, 0.97))
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_corner_radius_all(10)
	t.set_stylebox("slider", "HSlider", _sb(Color(0.2, 0.2, 0.26), Color(0, 0, 0, 0), 6, 6))
	t.set_stylebox("grabber_area", "HSlider", _sb(ACCENT * Color(1, 1, 1, 0.8), Color(0, 0, 0, 0), 6, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", _sb(ACCENT, Color(0, 0, 0, 0), 6, 6))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


static func _sb(bg: Color, border: Color, radius := 12, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func title(text: String, size := 34, col := ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func text(t: String, size := 18, col := Color(0.88, 0.88, 0.94), wrap := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(t: String, cb: Callable, min_h := 56.0, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, min_h)
	b.disabled = not enabled
	b.pressed.connect(func():
		Audio.play("ui_click", -6.0)
		cb.call())
	return b


static func panel(min_size := Vector2.ZERO, col := PANEL, border := Color(1, 1, 1, 0.08)) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", _sb(col, border, 14))
	return p


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func flow(sep := 8) -> HFlowContainer:
	## Row that wraps its children onto new lines on narrow screens.
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func icon(name: String, size := 40.0, col := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/icons/%s.png" % name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = col
	return t


static func slider(label: String, value: float, min_v: float, max_v: float, step: float, cb: Callable) -> Control:
	var h := hbox()
	var l := text(label, 18)
	l.custom_minimum_size = Vector2(260, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vl := text("%.2f" % value, 16, Color(0.7, 0.7, 0.8), false)
	vl.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(v): vl.text = "%.2f" % v; cb.call(v))
	h.add_child(s)
	h.add_child(vl)
	return h


static func toggle(label: String, value: bool, cb: Callable) -> Control:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, 48)
	c.toggled.connect(func(v): Audio.play("ui_click", -8.0); cb.call(v))
	return c


static func cost_label(cost: Dictionary) -> Control:
	var h := hbox(6)
	for k in cost:
		var ok := Game.res(k) >= int(cost[k])
		var r: Dictionary = DB.RESOURCES[k]
		var l := text("%s %d" % [r.icon, int(cost[k])], 16, r.color if ok else Color(1, 0.35, 0.3), false)
		l.tooltip_text = r.name
		h.add_child(l)
	return h


static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
