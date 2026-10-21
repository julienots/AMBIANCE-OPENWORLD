extends "res://src/world/regions/region_base.gd"
## The underground base: a diggable rock volume where the player carves tunnels and rooms,
## places installations, manages power and survives raids.

const DigCtl := preload("res://src/base/dig_controller.gd")
const BuildCtl := preload("res://src/base/build_controller.gd")
const Building := preload("res://src/base/base_building.gd")
const Raid := preload("res://src/base/raid.gd")

var terrain: DigTerrain
var dig: Node3D
var build_ctl: Node3D
var raid: Node
var nodes := {}                     # building id -> node
var _nav_t := 0.0


func build(world: Node3D) -> void:
	setup(world, 77)
	w.bounds = AABB(Vector3(-42, -26, -42), Vector3(84, 30, 84))
	w.configure_env({"no_sky": true, "fog_color": Color(0.03, 0.025, 0.03), "fog_density": 0.03,
		"ambient": Color(0.5, 0.42, 0.4), "ambient_energy": 0.9, "sun": false, "visibility": 0.35,
		"motes": Color(0.9, 0.8, 0.6, 0.4), "motes_amount": 25, "motes_size": 0.05,
		"ambient_sounds": ["drip", "burrower_rumble", "metal_creak"], "room": 0.8, "reverb": 0.25})
	await progress(0.1, "Creusement de la roche…")
	terrain = DigTerrain.new()
	terrain.name = "Terrain"
	w.nav.add_child(terrain)
	terrain.generate(Game.profile.base.cells)
	await progress(0.4, "Maillage des galeries…")
	terrain.build_all()
	await progress(0.7, "Installations…")
	var chamber := terrain.cell_floor(Vector3i(20, 12, 20))
	w.spawn_points["start"] = Transform3D(Basis(), chamber + Vector3(0, 0.3, 3.0))
	w.spawn_points["from_city"] = w.spawn_points["start"]
	w.spawn_points["refuge"] = w.spawn_points["start"]
	var hatch := Gate.new()
	hatch.target_region = "city"
	hatch.target_gate = "from_base"
	hatch.label = "Remonter (Mégapole)"
	add(hatch, chamber + Vector3(0, 0, -1.0))
	# Permanent work lights in the first chamber
	for p in [Vector3(-4.5, 0, -4.5), Vector3(4.5, 0, 4.5)]:
		lamp(chamber + p, 0.0, {"style": "lantern", "radius": 10.0, "energy": 2.2, "color": Color(1.0, 0.85, 0.6)})
	lamp(terrain.cell_floor(Vector3i(31, 6, 20)), 0.0, {"style": "crystal", "radius": 9.0, "energy": 1.6, "color": Color(0.3, 0.9, 1.0)})
	for e in Game.profile.base.buildings:
		_spawn_building(e)
	dig = DigCtl.new()
	dig.terrain = terrain
	w.props.add_child(dig)
	build_ctl = BuildCtl.new()
	build_ctl.terrain = terrain
	build_ctl.base = self
	w.props.add_child(build_ctl)
	raid = Raid.new()
	raid.base = self
	raid.terrain = terrain
	w.add_child(raid)
	w.add_marker("dig", chamber + Vector3(6, 0, 0))
	w.add_marker("build", chamber)
	w.add_marker("gate_city", chamber)
	w.set_meta("base", self)
	Events.base_changed.connect(_refresh_all)
	Events.research_completed.connect(func(_r): _refresh_all())
	await progress(1.0, "")


func on_enter(world: Node3D) -> void:
	Events.toast.emit("Base souterraine · Maintenez Interagir face à la roche pour creuser", "objective")
	if Game.active_mission_id() == "r02_defend":
		raid.start(3)


func _spawn_building(e: Dictionary) -> Node3D:
	var b := Building.new()
	b.setup(e, terrain)
	var fp: Vector2i = DB.BUILDINGS[e.type].size
	var anchor := Vector3i(e.cell[0], e.cell[1], e.cell[2])
	var pos := terrain.cell_floor(anchor) + Vector3((fp.x - 1) * DigTerrain.SX * 0.5, 0, (fp.y - 1) * DigTerrain.SZ * 0.5)
	add(b, pos, float(e.get("rot", 0.0)))
	nodes[int(e.id)] = b
	return b


func cell_occupied(c: Vector3i) -> bool:
	for e in Game.profile.base.buildings:
		var fp: Vector2i = DB.BUILDINGS[e.type].size
		if c.y == int(e.cell[1]) and c.x >= int(e.cell[0]) and c.x < int(e.cell[0]) + fp.x and c.z >= int(e.cell[2]) and c.z < int(e.cell[2]) + fp.y:
			return true
	return false


func start_placement(type: String) -> void:
	build_ctl.begin(type)


func place_building(type: String, anchor: Vector3i) -> void:
	var b: Dictionary = Game.profile.base
	var e := {"id": int(b.next_id), "type": type, "cell": [anchor.x, anchor.y, anchor.z], "level": 1}
	b.next_id = int(b.next_id) + 1
	b.buildings.append(e)
	var node := _spawn_building(e)
	Audio.play_at("build_complete", node.global_position)
	Fx.smoke_puff(node.global_position + Vector3.UP, Color(0.5, 0.48, 0.45, 0.6), 2.5, 10)
	Game.profile.stats.built += 1
	Events.toast.emit("%s construit" % DB.BUILDINGS[type].name, "objective")
	Events.mission_event.emit("build", type, 1)
	Events.base_changed.emit()
	Game.save_game()


func reinforce_cell(c: Vector3i) -> void:
	terrain.set_cell(c, DigTerrain.REINFORCED)


func _refresh_all() -> void:
	var p := Game.power_balance()
	Events.base_power_changed.emit(p.x, p.y)
	for id in nodes:
		if is_instance_valid(nodes[id]):
			nodes[id].refresh()


func tick(world: Node3D, delta: float) -> void:
	dig.enabled = not build_ctl.enabled
	raid.tick(delta)
	Game.profile.base.cells = terrain.changes
	_nav_t -= delta
	if terrain.nav_dirty and _nav_t <= 0.0 and not w.nav.is_baking():
		_nav_t = 2.0
		terrain.nav_dirty = false
		w.nav.bake_navigation_mesh(true)
