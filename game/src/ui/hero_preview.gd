class_name HeroPreview
extends SubViewportContainer
## Turntable 3D presentation of a hero (or creature) inside the UI. Drag to rotate.

var _vp: SubViewport
var _pivot: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _cam: Camera3D
var _spin := 0.4
var _drag := false
var _ring: MeshInstance3D
var model_path := ""


func _init(sz := Vector2(420, 520)) -> void:
	custom_minimum_size = sz
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.size = Vector2i(sz)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.38, 0.55)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.95, 0.88)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.55, 0.65, 1.0)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 32
	_cam.position = Vector3(0, 1.15, 5.4)
	_cam.rotation_degrees.x = -4
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_ring = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.95
	cm.height = 0.06
	_ring.mesh = cm
	_vp.add_child(_ring)


func show_model(path: String, color: Color, anim := "pose", symbiote := false, scale_to := 2.0) -> void:
	model_path = path
	if _model:
		_model.queue_free()
	_model = (load(path) as PackedScene).instantiate()
	_pivot.add_child(_model)
	Mats.apply(_model, false, symbiote)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for n in ["pose", "idle", "spawn"]:
			if _anim.has_animation(n) and n != "spawn":
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		if _anim.has_animation("spawn") and anim == "pose":
			_anim.play("spawn")
			_anim.queue(anim)
		elif _anim.has_animation(anim):
			_anim.play(anim)
		elif _anim.has_animation("idle"):
			_anim.play("idle")
	# Fit tall creatures in frame.
	var aabb := AABB()
	for mi in Mats.find_meshes(_model):
		aabb = aabb.merge(mi.get_aabb())
	var h := maxf(aabb.size.y, 1.0)
	var s := clampf(scale_to / h, 0.25, 1.4)
	_model.scale = Vector3.ONE * s
	_ring.material_override = Mats.toon(color * 0.6, 2.0, {"pulse_speed": 2.0})
	_pivot.rotation.y = 0.35


func _process(delta: float) -> void:
	if not _drag and _pivot:
		_pivot.rotation.y += delta * _spin


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_drag = event.pressed
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag:
		_pivot.rotation.y += event.relative.x * 0.01
