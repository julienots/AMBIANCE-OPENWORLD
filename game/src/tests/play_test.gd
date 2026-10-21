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
		_: await _run_basic()


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


func report_perf() -> void:
	print("[perf] draw calls=%d objects=%d primitives=%d vram=%.1fMB static_mem=%.1fMB" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
