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
