extends Node3D
## Invisible area: mission "reach" / "escape" events and scripted horror moments.

var tag := ""
var kind := "reach"               # reach | escape | scare | chase
var radius := 5.0
var once := true
var scare_sound := ""
var callback: Callable
var _done := false


func _ready() -> void:
	add_to_group("trigger")


func _physics_process(_delta: float) -> void:
	if _done:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or p.global_position.distance_to(global_position) > radius:
		return
	if kind in ["reach", "escape"]:
		Events.mission_event.emit(kind, tag, 1)
	if scare_sound != "":
		Audio.play_at(scare_sound, global_position + Vector3(randf_range(-6, 6), 2, randf_range(-6, 6)), 0.0, 40.0)
		Events.jumpscare.emit(0.3)
	if callback.is_valid():
		callback.call()
	if once:
		_done = true
