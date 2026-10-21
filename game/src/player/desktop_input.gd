extends Node
## Keyboard / mouse / gamepad bridge into Pad (used on PC and for automated tests).
## WASD move, mouse (right button held) look, LMB attack (hold = heavy), Space dodge,
## 1-3 abilities, R ultimate, E interact, C crouch, Shift sprint, F lamp, Q item, Tab next item.

var _mouse_attack_t := -1.0
var _key_prev := {}
var _wrote_move := false

const KEYS := {
	KEY_SPACE: "dodge", KEY_1: "ability1", KEY_2: "ability2", KEY_3: "ability3", KEY_R: "ultimate",
	KEY_E: "interact", KEY_C: "crouch", KEY_F: "flashlight", KEY_Q: "item", KEY_TAB: "item_next",
	KEY_ESCAPE: "pause", KEY_J: "attack", KEY_M: "map",
}


func _process(_delta: float) -> void:
	if Pad.touch_active:
		return
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() > 0.2:
		v = joy
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	# Only drive the stick while keys are used, so tests / touch can also write Pad.move.
	if v.length() > 0.0:
		Pad.move = v.limit_length(1.0) * (1.0 if sprinting or joy.length() > 0.2 else 0.7)
		_wrote_move = true
	elif _wrote_move:
		Pad.move = Vector2.ZERO
		_wrote_move = false
	if sprinting:
		Pad.press("sprint_hold")
	else:
		Pad.release("sprint_hold")
	var rj := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rj.length() > 0.2:
		Pad.look += rj * 12.0
	for k in KEYS:
		var down := Input.is_physical_key_pressed(k)
		if down and not _key_prev.get(k, false):
			Pad.press(KEYS[k])
		elif not down and _key_prev.get(k, false):
			Pad.release(KEYS[k])
		_key_prev[k] = down
	# Mouse attack: short click = attack, hold > 0.4 s = heavy.
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if lmb and _mouse_attack_t < 0:
		_mouse_attack_t = 0.0
		Pad.press("attack_down")
	elif lmb:
		_mouse_attack_t += _delta
	elif _mouse_attack_t >= 0:
		Pad.press("attack" if _mouse_attack_t < 0.4 else "heavy")
		Pad.release("attack_down")
		_mouse_attack_t = -1.0


func _unhandled_input(event: InputEvent) -> void:
	if Pad.touch_active:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		Pad.look += event.relative
