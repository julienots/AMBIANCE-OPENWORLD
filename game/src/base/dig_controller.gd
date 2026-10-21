extends Node3D
## Contextual digging: targets the cell in front of the player (feet, head, below when
## crouching, above when looking up). Holding the interact button digs according to the
## rock hardness. Each cell gives resources and advances "dig" objectives.

var terrain: DigTerrain
var interact_range := 3.0
var target := Vector3i(-1, -1, -1)
var _progress := 0.0
var _crack: MeshInstance3D
var enabled := true
var mode := "dig"                  # dig | reinforce


func _ready() -> void:
	add_to_group("interactable")
	_crack = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(DigTerrain.SX * 1.02, DigTerrain.SY * 1.02, DigTerrain.SZ * 1.02)
	_crack.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.12)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crack.material_override = m
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crack)
	_crack.top_level = true


func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or terrain == null or not enabled or (p.state != "move" and p.state != "action"):
		target = Vector3i(-1, -1, -1)
		_crack.visible = false
		return
	var fwd: Vector3 = p.facing()
	var feet: Vector3 = p.global_position + Vector3.UP * 0.4
	var c := terrain.cell_at(feet + fwd * (DigTerrain.SX * 0.75 + 0.3))
	var candidates: Array = []
	var cam: Node = p.cam_rig
	if p.crouching:
		candidates = [c + Vector3i(0, -1, 0), c]
	elif cam and cam.pitch > 12.0:
		candidates = [c + Vector3i(0, 2, 0), c + Vector3i(0, 1, 0), c]
	else:
		candidates = [c, c + Vector3i(0, 1, 0)]
	var nt := Vector3i(-1, -1, -1)
	for cc in candidates:
		if terrain.get_cell(cc) != DigTerrain.AIR:
			nt = cc
			break
	if nt != target:
		target = nt
		_progress = 0.0
	if target.x >= 0:
		global_position = terrain.cell_center(target)
		_crack.global_position = global_position
		_crack.visible = true
	else:
		_crack.visible = false


func can_interact(_p: Node) -> bool:
	return enabled and target.x >= 0


func get_prompt(_p: Node) -> String:
	var t := terrain.get_cell(target)
	var info: Dictionary = DigTerrain.INFO[t]
	if mode == "reinforce" and terrain.diggable(target):
		return "Renforcer la paroi (%s)" % info.name
	if not terrain.diggable(target):
		return info.name + " (indestructible)"
	return "Creuser : %s %s" % [info.name, ("%d %%" % int(_progress * 100)) if _progress > 0 else ""]


func interact(p: Node) -> void:
	if mode == "reinforce" and terrain.diggable(target):
		if Game.spend({"materials": 2, "metal": 1}):
			terrain.set_cell(target, DigTerrain.REINFORCED)
			Audio.play_at("build_place", global_position, -4.0)
			Fx.hit_spark(global_position, Color(0.6, 0.8, 1.0))
		else:
			Events.toast.emit("Matériaux 2 + métal 1 requis", "warn")
		return
	if not terrain.diggable(target):
		Audio.play_at("metal_clang", global_position, -8.0)
		return
	var speed := 1.5 if Game.has_research("drill") else 1.0
	_progress += 0.15 * speed / maxf(terrain.hardness(target), 0.1)
	p.play_action("attack1" if randf() < 0.5 else "attack2", 0.2)
	Audio.play_at("dig", global_position, -6.0, 30.0, 0.15)
	Fx.dig_debris(global_position, DigTerrain.INFO[terrain.get_cell(target)].color)
	(_crack.material_override as StandardMaterial3D).albedo_color.a = 0.12 + 0.4 * _progress
	Events.noise.emit(global_position, 6.0, p)
	if _progress >= 1.0:
		_break_cell(p)


func _break_cell(p: Node) -> void:
	var t := terrain.get_cell(target)
	var drops := Game.roll_drops(DigTerrain.INFO[t].drops)
	terrain.set_cell(target, DigTerrain.AIR)
	Fx.smoke_puff(global_position, Color(0.4, 0.36, 0.32, 0.6), 2.0, 6)
	Fx.add_shake(0.08)
	if t == DigTerrain.CRYSTAL:
		Audio.play_at("crystal_chime", global_position)
	for k in drops:
		Pickup.spawn(p.get_parent(), global_position, k, drops[k])
	Game.profile.stats.dug += 1
	Events.mission_event.emit("dig", "", 1)
	Events.cell_dug.emit(target, t)
	_progress = 0.0
	target = Vector3i(-1, -1, -1)
