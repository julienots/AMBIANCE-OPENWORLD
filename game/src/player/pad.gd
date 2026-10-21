class_name Pad
## Unified input state fed by the touch HUD and by keyboard / mouse / gamepad.
## Gameplay reads only from here, so touch and desktop behave identically.

static var move := Vector2.ZERO          # left stick, length 0..1
static var look := Vector2.ZERO          # accumulated camera delta (pixels) this frame
static var _pressed := {}                # action -> frame pressed
static var _held := {}                   # action -> bool
static var _frame := 0
static var touch_active := false         # the touch HUD reports activity


static func begin_frame() -> void:
	_frame = Engine.get_process_frames()


static func press(action: String) -> void:
	_pressed[action] = Engine.get_process_frames()
	_held[action] = true


static func release(action: String) -> void:
	_held[action] = false


static func held(action: String) -> bool:
	return _held.get(action, false)


static func just(action: String) -> bool:
	## True during the frame the action was pressed (and the next one, to survive input timing).
	var f: int = _pressed.get(action, -100)
	return Engine.get_process_frames() - f <= 1


static func consume(action: String) -> bool:
	if just(action):
		_pressed.erase(action)
		return true
	return false


static func take_look() -> Vector2:
	var l := look
	look = Vector2.ZERO
	return l


static func clear() -> void:
	move = Vector2.ZERO
	look = Vector2.ZERO
	_pressed.clear()
	_held.clear()
