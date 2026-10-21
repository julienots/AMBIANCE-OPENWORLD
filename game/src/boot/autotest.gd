extends Node
## Exported-build smoke test (launch with `-- autotest=<region>`): new game, load the
## region, walk forward, save, print a report and quit with an exit code.

var region := "city"


func _ready() -> void:
	Game.start_new_game()
	Loader.goto_world(region, "start")
	var t0 := Time.get_ticks_msec()
	while get_tree().get_first_node_in_group("world") == null or not get_tree().get_first_node_in_group("world").ready_to_play:
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 120000:
			print("[autotest] FAIL timeout")
			get_tree().quit(1)
			return
	var w := get_tree().get_first_node_in_group("world")
	print("[autotest] region %s ready in %d ms, enemies %d" % [region, Time.get_ticks_msec() - t0, Combat.enemies(get_tree()).size()])
	var start: Vector3 = w.player.global_position
	var e := 0.0
	while e < 4.0:
		Pad.move = Vector2(0, -1)
		await get_tree().process_frame
		e += get_process_delta_time()
	Pad.move = Vector2.ZERO
	var moved: float = w.player.global_position.distance_to(start)
	var saved := Game.save_game()
	print("[autotest] moved %.1f m, fps %d, save %s, music %s" % [moved, Engine.get_frames_per_second(), saved, Audio.current_state()])
	var ok := moved > 3.0 and saved
	print("[autotest] " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
