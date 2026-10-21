extends Interactable
## Audio log / journal. Plays a static-laden recording and shows its transcript.

var log_id := "log_lab_1"


func _build() -> void:
	interact_range = 2.0
	if log_id in Game.profile.get("logs", []):
		enabled = false
	var dev := box_mesh(Vector3(0.35, 0.12, 0.25), Color(0.2, 0.2, 0.22))
	dev.position.y = 0.95
	add_child(dev)
	var led := box_mesh(Vector3(0.05, 0.05, 0.05), Color(1.0, 0.3, 0.2), 4.0 if enabled else 0.0)
	led.position = Vector3(0.12, 1.03, -0.08)
	add_child(led)
	var stand := box_mesh(Vector3(0.6, 0.9, 0.5), Color(0.35, 0.33, 0.3))
	stand.position.y = 0.45
	add_child(stand)


func get_prompt(_p: Node) -> String:
	return "Écouter le journal audio"


func interact(_p: Node) -> void:
	enabled = false
	Game.profile.logs.append(log_id)
	Audio.play("flicker", -6.0)
	Audio.play("whisper", -14.0)
	var l: Dictionary = DB.AUDIO_LOGS[log_id]
	Events.log_found.emit(log_id)
	Events.mission_event.emit("collect_log", l.region, 1)
	Game.add_res("data", 1)
