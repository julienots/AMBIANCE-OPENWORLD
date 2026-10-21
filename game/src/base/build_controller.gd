extends Node3D
## Placement mode for base installations: a ghost footprint snaps to the floor cells in
## front of the player, green when valid. Interact confirms, dodge cancels.

var terrain: DigTerrain
var base                           # base region builder (RefCounted)
var type := ""
var interact_range := 6.0
var enabled := false
var _ghost: MeshInstance3D
var _anchor := Vector3i(-1, -1, -1)
var _valid := false
var _reason := ""


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost.material_override = m
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.top_level = true
	add_child(_ghost)
	_ghost.visible = false


func begin(t: String) -> void:
	type = t
	enabled = true
	add_to_group("interactable")
	var fp: Vector2i = DB.BUILDINGS[t].size
	var bm := BoxMesh.new()
	bm.size = Vector3(fp.x * DigTerrain.SX - 0.1, 2.0, fp.y * DigTerrain.SZ - 0.1)
	_ghost.mesh = bm
	_ghost.visible = true
	Events.toast.emit("Placez « %s » · Interagir = construire · Esquive = annuler" % DB.BUILDINGS[t].name, "objective")


func end() -> void:
	enabled = false
	type = ""
	_ghost.visible = false
	remove_from_group("interactable")


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if p.state == "dodge":
		end()
		Events.toast.emit("Construction annulée", "warn")
		return
	var fp: Vector2i = DB.BUILDINGS[type].size
	var ahead: Vector3 = p.global_position + p.facing() * (1.5 + fp.y * 1.0) + Vector3.UP * 0.4
	_anchor = terrain.cell_at(ahead)
	# Snap the anchor down onto the floor.
	for i in 3:
		if terrain.get_cell(_anchor) == DigTerrain.AIR and terrain.get_cell(_anchor + Vector3i(0, -1, 0)) == DigTerrain.AIR:
			_anchor.y -= 1
	_valid = _check(fp)
	var center := terrain.cell_floor(_anchor) + Vector3((fp.x - 1) * DigTerrain.SX * 0.5, 1.0, (fp.y - 1) * DigTerrain.SZ * 0.5)
	_ghost.global_position = center
	global_position = center
	(_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.4, 0.35) if _valid else Color(1.0, 0.2, 0.15, 0.35)


func _check(fp: Vector2i) -> bool:
	_reason = ""
	for dx in fp.x:
		for dz in fp.y:
			var c := _anchor + Vector3i(dx, 0, dz)
			if not terrain.is_floor_cell(c):
				_reason = "Creusez plus d'espace (sol plat + 2 m de hauteur)"
				return false
			if base.cell_occupied(c):
				_reason = "Emplacement occupé"
				return false
	if not Game.can_afford(DB.BUILDINGS[type].cost):
		_reason = "Ressources insuffisantes : " + DB.cost_text(DB.BUILDINGS[type].cost)
		return false
	return true


func can_interact(_p: Node) -> bool:
	return enabled


func get_prompt(_p: Node) -> String:
	return ("Construire : " + DB.BUILDINGS[type].name) if _valid else _reason


func interact(_p: Node) -> void:
	if not _valid:
		Audio.play("ui_error", -6.0)
		Events.toast.emit(_reason, "warn")
		return
	Game.spend(DB.BUILDINGS[type].cost)
	base.place_building(type, _anchor)
	end()
