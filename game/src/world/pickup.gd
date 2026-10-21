class_name Pickup
extends Node3D
## Resource orb dropped by creatures and containers. Pops out, then is drawn to the player.

var res_id := "metal"
var amount := 1
var _t := 0.0
var _vel := Vector3.ZERO
var _mesh: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, id: String, n: int) -> void:
	var p := Pickup.new()
	p.res_id = id
	p.amount = n
	parent.add_child(p)
	p.global_position = pos
	p._vel = Vector3(randf_range(-2.5, 2.5), randf_range(3.0, 5.0), randf_range(-2.5, 2.5))


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.16
	m.height = 0.32
	m.radial_segments = 8
	m.rings = 4
	_mesh.mesh = m
	var col: Color = DB.RESOURCES[res_id].color
	_mesh.material_override = Mats.toon(col, 1.6, {"pulse_speed": 6.0})
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if _t < 0.5 or p == null:
		_vel.y -= 12.0 * delta
		global_position += _vel * delta
		if global_position.y < _ground_y() + 0.3:
			global_position.y = _ground_y() + 0.3
			_vel = _vel * 0.4
			_vel.y = absf(_vel.y)
		return
	var to: Vector3 = p.global_position + Vector3.UP - global_position
	if to.length() < 0.6 or _t > 6.0:
		Game.add_res(res_id, amount)
		Audio.play("pickup", -10.0, 0.15)
		queue_free()
		return
	var spd := 4.0 + _t * 10.0
	global_position += to.normalized() * minf(spd * delta, to.length())
	_mesh.rotation.y += delta * 6.0


func _ground_y() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 20.0, Combat.LAYER_WORLD)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position.y if not r.is_empty() else global_position.y - 1.0
