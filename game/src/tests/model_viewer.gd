extends Node3D
## Visual check tool: renders a model in several animation poses to PNG.
## Usage: godot --path game res://src/tests/model_viewer.tscn -- model=res://... anims=idle,run out=user://x.png

var model_path := "res://assets/models/heroes/vortex.glb"
var anims := ["pose", "idle", "run", "attack1", "cast", "dodge", "spawn", "heavy"]
var times := [0.3, 0.3, 0.25, 0.42, 0.35, 0.4, 0.15, 0.55]
var out_path := "res://../build/screens/model.png"
var symb := false
var models: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2: continue
		match kv[0]:
			"model": model_path = kv[1]
			"anims": anims = Array(kv[1].split(","))
			"times": times = Array(kv[1].split(",")).map(func(x): return float(x))
			"out": out_path = kv[1]
			"symb": symb = kv[1] == "1"
			"models": models = Array(kv[1].split(","))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.07, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.3, 0.45)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	add_child(sun)
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-20, 160, 0)
	back.light_energy = 0.7
	back.light_color = Color(0.5, 0.6, 1.0)
	add_child(back)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40)
	floor.mesh = pm
	floor.material_override = Mats.toon(Color(0.25, 0.27, 0.3))
	add_child(floor)
	var scene: PackedScene = load(model_path)
	var n := anims.size()
	if not models.is_empty():
		n = models.size()
	var spacing := 1.6
	var radius := 1.0
	for i in n:
		var inst: Node3D = (load(models[i]) as PackedScene).instantiate() if not models.is_empty() else scene.instantiate()
		add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * spacing, 0, 0)
		Mats.apply(inst, false, symb)
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		var an: String = anims[i % anims.size()]
		if ap and ap.has_animation(an):
			ap.play(an)
			ap.seek(ap.current_animation_length * float(times[i % times.size()]), true)
			ap.pause()
		var aabb := _aabb(inst)
		radius = max(radius, aabb.size.y)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	var w := n * spacing
	cam.position = Vector3(0, radius * 0.55, max(w * 0.75, radius * 2.2) + 0.5)
	cam.look_at(Vector3(0, radius * 0.5, 0))
	get_viewport().size = Vector2i(1600, 700)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	img.save_png(ProjectSettings.globalize_path(out_path))
	print("saved ", out_path)
	get_tree().quit()

func _aabb(n: Node) -> AABB:
	var box := AABB()
	for mi in Mats.find_meshes(n):
		box = box.merge(mi.get_aabb())
	return box
