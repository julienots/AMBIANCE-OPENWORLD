extends CanvasLayer
## In-game menu (placeholder until the full menu lands).

var _root: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(_tab: String, _at_refuge: bool) -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
