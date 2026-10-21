extends Node
## Automated play-test: starts a fresh game in a region, drives the player through Pad,
## captures screenshots and prints a report. Run:
## godot --path game res://src/tests/play_test.tscn -- region=city shots=build/screens/x

var region := "city"
var out_dir := "res://../build/screens/play"
var script_name := "basic"
var _t := 0.0
var _shot := 0
var _log: PackedStringArray = []
var _errors := 0


func _ready() -> void:
	# Survive the scene change triggered by Loader.goto_world.
	if get_parent() != get_tree().root:
		reparent.call_deferred(get_tree().root)
		await get_tree().process_frame
		await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"region": region = kv[1]
				"out": out_dir = kv[1]
				"script": script_name = kv[1]
	if script_name == "flow":
		await _run_flow()
		get_tree().quit()
		return
	Save.delete(9)
	Game.start_new_game()
	Game.profile.flags["tutorial_city"] = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var t0 := Time.get_ticks_msec()
	Loader.goto_world(region, "start")
	while get_tree().get_first_node_in_group("world") == null or not get_tree().get_first_node_in_group("world").ready_to_play:
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 240000:
			print("TIMEOUT waiting for world")
			get_tree().quit(1)
			return
	print("[test] region %s ready in %d ms" % [region, Time.get_ticks_msec() - t0])
	await _run()
	print("[test] done. screenshots=%d" % _shot)
	get_tree().quit()


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var p := ProjectSettings.globalize_path(out_dir + "/%02d_%s.png" % [_shot, name])
	img.save_png(p)
	_shot += 1
	print("[test] screenshot ", p)


func wait(t: float) -> void:
	var e := 0.0
	while e < t:
		await get_tree().process_frame
		e += get_process_delta_time()


func hold_move(v: Vector2, t: float) -> void:
	var e := 0.0
	while e < t:
		Pad.move = v
		await get_tree().process_frame
		e += get_process_delta_time()
	Pad.move = Vector2.ZERO


func _run() -> void:
	match script_name:
		"base": await _run_base()
		"touch": await _run_touch()
		_: await _run_basic()


func _run_flow() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Save.delete(0)
	get_tree().change_scene_to_file("res://src/boot/boot.tscn")
	await wait(1.2)
	await shot("boot_logo")
	await wait(2.5)
	await shot("boot_title")
	var t0 := Time.get_ticks_msec()
	while get_tree().current_scene == null or get_tree().current_scene.name != "MainMenu":
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 60000:
			print("[test] FAIL main menu never shown")
			return
	print("[test] main menu reached after boot")
	await wait(1.5)
	await shot("main_menu")
	get_tree().current_scene._start_new()
	while get_tree().get_first_node_in_group("world") == null or not get_tree().get_first_node_in_group("world").ready_to_play:
		await get_tree().process_frame
	print("[test] world reached: ", Game.current_region, " mission ", Game.active_mission_id())
	await wait(1.0)
	await shot("world_start")
	var w := get_tree().get_first_node_in_group("world")
	w.open_menu()
	await wait(0.4)
	await shot("menu_missions")
	w.menu._switch("heroes")
	await wait(1.0)
	await shot("menu_heroes")
	w.menu._switch("base")
	await wait(0.3)
	await shot("menu_base")
	w.menu._switch("options")
	await wait(0.3)
	await shot("menu_options")
	w.menu.close()
	await wait(0.3)
	print("[test] paused after close: ", get_tree().paused, " save exists: ", Save.has_save())


func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _run_touch() -> void:
	## Drives the game only through real screen-touch events, like a phone.
	var w := get_tree().get_first_node_in_group("world")
	var p: Node3D = w.player
	var vs := get_viewport().get_visible_rect().size
	print("[touch] viewport ", vs, " touch control size ", w.hud.touch.size, " pos ", w.hud.touch.position, " attack btn ", w.hud.touch._btn_center("attack"))
	await wait(0.5)
	await shot("touch_idle")
	var start := p.global_position
	var j := Vector2(170, vs.y - 170)
	touch(0, j, true)
	await wait(0.05)
	for i in 10:
		drag(0, j + Vector2(0, -8 * (i + 1)), Vector2(0, -8))
		await wait(0.02)
	await wait(0.3)
	print("[touch] Pad.move during drag: ", Pad.move, " touch_active ", Pad.touch_active)
	await shot("touch_joystick")
	await wait(1.5)
	touch(0, j + Vector2(0, -80), false)
	await wait(0.2)
	print("[touch] moved %.2f m with the joystick" % p.global_position.distance_to(start))
	var yaw0: float = w.cam_rig.yaw
	var c := Vector2(vs.x * 0.6, vs.y * 0.4)
	touch(1, c, true)
	for i in 10:
		drag(1, c + Vector2(15 * (i + 1), 0), Vector2(15, 0))
		await wait(0.02)
	touch(1, c + Vector2(150, 0), false)
	await wait(0.2)
	print("[touch] camera yaw changed by %.1f deg" % (w.cam_rig.yaw - yaw0))
	var ab: Vector2 = w.hud.touch._btn_center("attack")
	var anim0: String = p.anim.current_animation
	touch(2, ab, true)
	await wait(0.05)
	touch(2, ab, false)
	await wait(0.1)
	print("[touch] attack button -> player state %s anim %s (was %s)" % [p.state, p.anim.current_animation, anim0])


func press_interact(n: int, dt := 0.16) -> void:
	for i in n:
		Pad.press("interact")
		await wait(dt)


func _run_base() -> void:
	var w := get_tree().get_first_node_in_group("world")
	var p: Node3D = w.player
	var base = w.get_meta("base")
	for k in ["metal", "materials", "crystal", "electronics"]:
		Game.add_res(k, 60, true)
	await wait(0.8)
	await shot("base_spawn")
	# Face east toward the rock and dig a tunnel.
	p._heading = -PI / 2
	var before: int = Game.profile.stats.dug
	for cell in 5:
		await press_interact(14)
		await hold_move(Vector2(1, 0), 0.6)
	print("[test] dug cells: ", Game.profile.stats.dug - before, " player ", p.global_position)
	await shot("base_dug")
	p._heading = PI / 2
	base.start_placement("generator")
	await wait(0.5)
	print("[test] placement prompt: ", base.build_ctl.get_prompt(p))
	Pad.press("interact")
	await wait(0.5)
	print("[test] buildings: ", Game.buildings().size(), " power ", Game.power_balance())
	base.start_placement("command")
	p._heading = 0.0
	await wait(0.5)
	print("[test] placement prompt 2: ", base.build_ctl.get_prompt(p))
	Pad.press("interact")
	await wait(0.5)
	print("[test] buildings: ", Game.buildings().size(), " power ", Game.power_balance())
	await shot("base_built")
	base.raid.start(2)
	print("[test] raid diggers: ", base.raid.diggers.size())
	await wait(15.0)
	for d in base.raid.diggers:
		if is_instance_valid(d):
			print("[test] digger at ", d.global_position, " path left ", d.get_meta("path").size(), " state ", d.state)
	await shot("base_raid")
	report_perf()


func _run_basic() -> void:
	var w := get_tree().get_first_node_in_group("world")
	var p: Node3D = w.player
	print("[test] player at ", p.global_position, " hero ", p.hero_id, " fps ", Engine.get_frames_per_second())
	await wait(1.0)
	await shot("spawn")
	await hold_move(Vector2(0, -1), 2.5)
	print("[test] after move: ", p.global_position)
	await shot("moved")
	Pad.look = Vector2(400, 0)
	await wait(0.5)
	await shot("look")
	Pad.press("attack")
	await wait(0.3)
	Pad.press("attack")
	await wait(0.3)
	Pad.press("ability1")
	await wait(0.6)
	await shot("combat")
	print("[test] enemies alive: ", Combat.enemies(get_tree()).size(), " fps ", Engine.get_frames_per_second())
	report_perf()
	for n in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		n.visible = false
	await shot("no_particles")


func report_breakdown() -> void:
	var cats := {}
	for mi in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var n: Node = mi
		var cat := "other"
		while n:
			if n.name in ["Geometry", "Props", "Enemies", "Player", "CameraRig"]:
				cat = n.name
				break
			n = n.get_parent()
		var surf: int = mi.mesh.get_surface_count() if mi.mesh else 0
		var passes := 0
		for s in surf:
			var m: Material = mi.get_active_material(s)
			passes += 1 + (1 if m and m.next_pass else 0)
		if not cats.has(cat):
			cats[cat] = [0, 0]
		cats[cat][0] += 1
		cats[cat][1] += passes
	var lights := get_tree().root.find_children("*", "OmniLight3D", true, false).filter(func(l): return l.is_visible_in_tree()).size()
	var parts := get_tree().root.find_children("*", "CPUParticles3D", true, false).filter(func(l): return l.is_visible_in_tree()).size()
	print("[perf] meshes by category [instances, surface passes]: ", cats, " omni lights: ", lights, " particle systems: ", parts)


func report_perf() -> void:
	report_breakdown()
	print("[perf] draw calls=%d objects=%d primitives=%d vram=%.1fMB static_mem=%.1fMB" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
