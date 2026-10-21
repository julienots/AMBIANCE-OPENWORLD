extends Interactable
## Emergency generator: hold to restart (noisy!). Powers lights and doors of its group.

var power_group := "lab_a"
var mission_tag := "lab_generator"
var uid := ""
var running := false
var _progress := 0.0
var _holding := false
var _hum: AudioStreamPlayer3D
var _light: MeshInstance3D


func _build() -> void:
	interact_range = 2.3
	var base := box_mesh(Vector3(1.6, 1.2, 1.0), Color(0.3, 0.38, 0.32))
	base.position.y = 0.6
	add_child(base)
	var top := box_mesh(Vector3(1.2, 0.4, 0.8), Color(0.75, 0.6, 0.12))
	top.position.y = 1.4
	add_child(top)
	for i in 3:
		var fin := box_mesh(Vector3(0.05, 0.8, 0.9), Color(0.15, 0.15, 0.17))
		fin.position = Vector3(-0.5 + i * 0.5, 0.6, 0)
		add_child(fin)
	_light = box_mesh(Vector3(0.18, 0.18, 0.05), Color(1.0, 0.15, 0.1), 2.5)
	_light.position = Vector3(0.6, 1.0, -0.52)
	add_child(_light)
	static_box(self, Vector3(1.6, 1.6, 1.0), Vector3(0, 0.8, 0), "metal")
	if uid != "" and uid in Game.profile.get("opened", []):
		_set_running(true, true)


func can_interact(_p: Node) -> bool:
	return not running


func get_prompt(_p: Node) -> String:
	return "Redémarrer le générateur (maintenir)" if _progress <= 0.0 else "Redémarrage… %d %%" % int(_progress * 100)


func interact(p: Node) -> void:
	# Each press adds progress; the HUD repeats presses while the button is held.
	_progress += 0.12
	Audio.play_at("metal_clang", global_position, -8.0)
	Events.noise.emit(global_position, 16.0, p)
	if _progress >= 1.0:
		_set_running(true, false)


func _set_running(v: bool, silent: bool) -> void:
	running = v
	(_light.material_override as ShaderMaterial).set_shader_parameter("albedo", Color(0.2, 1.0, 0.3))
	if not silent:
		Audio.play_at("generator_start", global_position, 2.0, 60.0)
		Events.noise.emit(global_position, 30.0, self)
		Events.mission_event.emit("activate", mission_tag, 1)
		Events.toast.emit("Générateur redémarré", "objective")
		if uid != "":
			Game.profile.opened.append(uid)
	Events.mission_event.emit("power", power_group, 1)
	_hum = Audio.attach_loop(self, "generator_hum", -6.0, 18.0)


func _process(delta: float) -> void:
	if not running and _progress > 0.0:
		_progress = maxf(0.0, _progress - delta * 0.05)
