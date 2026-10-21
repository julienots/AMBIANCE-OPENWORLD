extends Node3D
## Third-person camera rig: yaw -> pitch -> spring arm -> camera.
## Adapts distance to exploration / combat / tight spaces, recenters behind the
## player while moving, eases toward the locked target and applies Fx.shake.

@export var target_path: NodePath
var target: Node3D
var yaw := 0.0
var pitch := -18.0
var distance := 5.2
var _want_dist := 5.2
var _idle_look_t := 0.0
var _shake_t := 0.0
var override_transform := false   # hiding spots / executions drive the camera directly
var fov_base := 62.0
var mode := "explore"             # explore | combat | interior | aim
var _shoulder := 0.0

@onready var pitch_node: Node3D = $Pitch
@onready var arm: SpringArm3D = $Pitch/Arm
@onready var cam: Camera3D = $Pitch/Arm/Camera


func _ready() -> void:
	if target_path:
		target = get_node(target_path)
	arm.add_excluded_object(target.get_rid() if target is CollisionObject3D else RID())
	cam.fov = fov_base
	cam.current = true


func _process(delta: float) -> void:
	if target == null or override_transform:
		return
	var look := Pad.take_look()
	var sens := 0.18 * float(Settings.get_v("cam_sensitivity", 1.0))
	var inv := -1.0 if Settings.get_v("cam_invert_y", false) else 1.0
	if look.length() > 0.01:
		yaw -= look.x * sens
		pitch = clampf(pitch - look.y * sens * 0.8 * inv, -65.0, 35.0)
		_idle_look_t = 0.0
	else:
		_idle_look_t += delta
	# Gentle auto-recenter behind the movement direction (helps one-thumb play).
	if _idle_look_t > 1.2 and target.has_method("move_heading") and target.velocity.length() > 2.0:
		var heading: float = target.move_heading()
		yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), heading, delta * 0.9))
		pitch = lerpf(pitch, -16.0, delta * 0.8)
	# Soft lock toward the current combat target.
	if target.has_method("lock_target"):
		var lt: Node3D = target.lock_target()
		if lt and _idle_look_t > 0.4:
			var to := lt.global_position - target.global_position
			var want := atan2(-to.x, -to.z)
			yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), want, delta * 1.6 * float(Settings.get_v("aim_assist", 0.7))))
	match mode:
		"combat": _want_dist = 6.4
		"interior": _want_dist = 3.8
		"aim": _want_dist = 3.2
		_: _want_dist = 5.2
	# Tight spaces: lower, flatter, over-the-shoulder framing.
	var low := _ceiling_low()
	var pivot_h := 1.55
	var eff_pitch := pitch
	if low:
		_want_dist = minf(_want_dist, 3.4)
		pivot_h = 1.3
		eff_pitch = clampf(pitch, -12.0, 10.0)
	_shoulder = 0.0
	distance = lerpf(distance, _want_dist, delta * 3.0)
	arm.spring_length = distance
	arm.position.x = _shoulder
	global_position = global_position.lerp(target.global_position + Vector3(0, pivot_h, 0), clampf(delta * 12.0, 0, 1))
	rotation_degrees.y = yaw
	pitch_node.rotation_degrees.x = lerpf(pitch_node.rotation_degrees.x, eff_pitch, clampf(delta * 8.0, 0, 1))
	# Hide the hero when the camera is pushed into it by walls.
	if target.get("visual") and target.state != "hidden":
		target.visual.visible = arm.get_hit_length() > 1.1
	var sprinting: bool = target.get("sprinting") == true
	cam.fov = lerpf(cam.fov, fov_base + (7.0 if sprinting else 0.0), delta * 4.0)
	# Shake
	var s := Fx.shake
	if s > 0.0:
		_shake_t += delta * 40.0
		cam.h_offset = sin(_shake_t * 1.3) * s * 0.18
		cam.v_offset = cos(_shake_t * 1.7) * s * 0.14
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _ceiling_low() -> bool:
	var space := get_world_3d().direct_space_state
	var from := target.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 3.2, 0), 1)
	return not space.intersect_ray(q).is_empty()


func forward_flat() -> Vector3:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	return -b.z


func right_flat() -> Vector3:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	return b.x


func snap_behind(heading_rad: float) -> void:
	yaw = rad_to_deg(heading_rad)
	pitch = -16.0
