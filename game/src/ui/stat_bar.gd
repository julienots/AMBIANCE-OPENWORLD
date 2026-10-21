class_name StatBar
extends Control
## Rounded stat bar with a trailing "ghost" that shows recent damage.

var value := 1.0
var max_value := 1.0
var color := Color.GREEN
var ghost := 1.0
var back := Color(0, 0, 0, 0.55)


func _init(c: Color, w: float, h: float) -> void:
	color = c
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var f := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	ghost = f if f > ghost else move_toward(ghost, f, delta * 0.35)
	queue_redraw()


func _draw() -> void:
	var r := size.y * 0.5
	var f := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	_round(Rect2(Vector2.ZERO, size), back, r)
	if ghost > f:
		_round(Rect2(Vector2.ZERO, Vector2(size.x * ghost, size.y)), Color(1, 1, 1, 0.45), r)
	if f > 0.0:
		_round(Rect2(Vector2.ZERO, Vector2(maxf(size.x * f, size.y), size.y)), color, r)
		_round(Rect2(Vector2(r * 0.5, 1), Vector2(maxf(size.x * f - r, 1), size.y * 0.3)), Color(1, 1, 1, 0.25), r * 0.3)


func _round(rect: Rect2, c: Color, r: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(r))
	draw_style_box(sb, rect)
