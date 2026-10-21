extends Interactable
## Light source: lights the area (player visibility), repels light-averse crawlers, can be
## switched off to sneak, and flickers when the Devourer is close or the power is out.

var on := true
var radius := 9.0
var color := Color(1.0, 0.82, 0.55)
var energy := 2.2
var switchable := false
var repels := true
var style := "street"            # street | ceiling | lantern | base | crystal
var power_group := ""            # tied to a generator
var _light: OmniLight3D
var _bulb: MeshInstance3D
var _flicker_t := 0.0
var _base_energy := 2.2


func _build() -> void:
	add_to_group("light_source")
	interact_range = 1.8
	enabled = switchable
	_base_energy = energy
	var h := 0.0
	match style:
		"street":
			var pole := box_mesh(Vector3(0.18, 5.2, 0.18), Color(0.2, 0.22, 0.25))
			pole.position.y = 2.6
			add_child(pole)
			var arm := box_mesh(Vector3(0.12, 0.12, 1.4), Color(0.2, 0.22, 0.25))
			arm.position = Vector3(0, 5.15, -0.65)
			add_child(arm)
			h = 5.0
			_bulb = box_mesh(Vector3(0.5, 0.18, 0.7), color, 3.0)
			_bulb.position = Vector3(0, 5.0, -1.2)
			static_box(self, Vector3(0.3, 5.0, 0.3), Vector3(0, 2.5, 0), "metal")
		"ceiling":
			h = 0.0
			_bulb = box_mesh(Vector3(1.2, 0.08, 0.25), color, 3.0)
		"lantern":
			var post := box_mesh(Vector3(0.12, 1.2, 0.12), Color(0.3, 0.25, 0.2))
			post.position.y = 0.6
			add_child(post)
			h = 1.3
			_bulb = box_mesh(Vector3(0.3, 0.35, 0.3), color, 3.0)
			_bulb.position.y = 1.35
		"crystal":
			h = 0.6
			_bulb = MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.6, 1.4, 0.6)
			_bulb.mesh = pm
			_bulb.material_override = Mats.toon(color, 2.5, {"pulse_speed": 1.5})
			_bulb.position.y = 0.7
		_:
			h = 2.2
			_bulb = box_mesh(Vector3(0.35, 0.35, 0.35), color, 3.0)
			_bulb.position.y = 2.2
			var post := box_mesh(Vector3(0.1, 2.2, 0.1), Color(0.25, 0.25, 0.28))
			post.position.y = 1.1
			add_child(post)
	add_child(_bulb)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = energy
	_light.omni_range = radius
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.position = _bulb.position + Vector3(0, -0.2, 0)
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 50.0
	_light.distance_fade_length = 15.0
	add_child(_light)
	if power_group != "":
		Events.mission_event.connect(_on_mission_event)
	_apply()


func _on_mission_event(kind: String, target: String, _n: int) -> void:
	if kind == "power" and target == power_group:
		set_on(true)


func set_on(v: bool) -> void:
	on = v
	_apply()


func _apply() -> void:
	_light.visible = on
	(_bulb.material_override as ShaderMaterial).set_shader_parameter("emission_energy", 3.0 if on else 0.0)


func light_at(p: Vector3) -> float:
	if not on:
		return 0.0
	var d := p.distance_to(_light.global_position)
	return clampf(1.2 - d / radius, 0.0, 1.0)


func get_prompt(_p: Node) -> String:
	return "Éteindre la lumière" if on else "Allumer la lumière"


func interact(_p: Node) -> void:
	set_on(not on)
	Audio.play_at("flicker", global_position, -4.0)


func _process(delta: float) -> void:
	if not on:
		return
	_flicker_t -= delta
	if _flicker_t > 0.0:
		return
	_flicker_t = 0.08
	var dev := get_tree().get_first_node_in_group("devourer")
	var near: bool = dev != null and dev.global_position.distance_to(global_position) < 14.0 and dev.visible
	if near or randf() < 0.004:
		_light.light_energy = _base_energy * (0.1 if randf() < 0.5 else randf_range(0.4, 1.0))
		if randf() < 0.05:
			Audio.play_at("flicker", global_position, -12.0, 20.0)
	else:
		_light.light_energy = _base_energy
