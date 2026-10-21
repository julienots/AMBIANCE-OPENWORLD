extends Node
## Base raids: burrowers tunnel through the rock toward an installation, cell by cell
## (reinforced walls are impassable), surface inside the base and attack. The watch post
## gives early warning; turrets, traps, doors and the player defend.

var base
var terrain: DigTerrain
var active := false
var diggers: Array = []
var _t := 0.0
var _warned := false
var survive_t := 0.0


func tick(delta: float) -> void:
	var b: Dictionary = Game.profile.base
	if not active:
		if Game.buildings().is_empty():
			return
		b.raid_timer = float(b.get("raid_timer", 420.0)) - delta
		var warn := 10.0 + 50.0 * Game.building_level_sum("watch")
		if b.raid_timer <= warn and not _warned:
			_warned = true
			Audio.play("alarm_base", -2.0)
			Events.base_alert.emit("Vibrations détectées : une attaque approche !")
			Events.toast.emit("⚠ Attaque de fouisseurs dans %d s" % int(b.raid_timer), "warn")
		if b.raid_timer <= 0.0:
			start()
		return
	survive_t += delta
	Game.set_objective_progress("survive", int(survive_t))
	Audio.request_state("combat", 2.0)
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		for d in diggers:
			if is_instance_valid(d) and d.alive and d.get("raid_mode"):
				_advance(d)
	diggers = diggers.filter(func(d): return is_instance_valid(d) and d.alive)
	if diggers.is_empty():
		end(true)


func start(count := -1) -> void:
	if active:
		return
	active = true
	_warned = false
	survive_t = 0.0
	if count < 0:
		count = 2 + Game.base_level()
	Audio.play("alarm_base", 0.0)
	Events.toast.emit("⚠ ATTAQUE ! Défendez la base", "warn")
	var targets := get_tree().get_nodes_in_group("base_building")
	for i in count:
		var start_cell := _spawn_cell()
		if start_cell.x < 0:
			continue
		var tgt: Node3D = targets.pick_random() if not targets.is_empty() else null
		var goal := terrain.cell_at(tgt.global_position + Vector3.UP * 0.5) if tgt else Vector3i(20, 12, 20)
		var path := _find_path(start_cell, goal)
		if path.is_empty():
			Events.toast.emit("Un fouisseur bute sur vos parois renforcées", "objective")
			continue
		var w := get_tree().get_first_node_in_group("world")
		var e = w.spawn_enemy("burrower", terrain.cell_floor(start_cell), {"raid_mode": true})
		e.set_meta("path", path)
		e.set_meta("dig_t", 0.0)
		diggers.append(e)


func end(won: bool) -> void:
	active = false
	Game.profile.base.raid_timer = randf_range(420.0, 600.0)
	if won:
		Events.toast.emit("Attaque repoussée !", "mission")
		Game.add_res("samples", 2)
		Game.add_xp(80)
		Events.mission_event.emit("survive", "raid", 999)
		Game.set_objective_progress("survive", 9999)


func _spawn_cell() -> Vector3i:
	## A solid cell far from any open space at a floor level used by the base.
	for attempt in 40:
		var c := Vector3i(randi_range(2, DigTerrain.NX - 3), 12, randi_range(2, DigTerrain.NZ - 3))
		if not terrain.diggable(c):
			continue
		var near_air := false
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				if terrain.get_cell(c + Vector3i(dx, 0, dz)) == DigTerrain.AIR:
					near_air = true
		if not near_air:
			return c
	return Vector3i(-1, -1, -1)


func _find_path(a: Vector3i, b: Vector3i) -> Array:
	## A* on the horizontal cell grid at the base floor level; digging costs by hardness.
	var y := a.y
	var open := {Vector2i(a.x, a.z): 0.0}
	var came := {}
	var g := {Vector2i(a.x, a.z): 0.0}
	var goal := Vector2i(b.x, b.z)
	var iters := 0
	while not open.is_empty() and iters < 4000:
		iters += 1
		var cur: Vector2i = open.keys()[0]
		var best := INF
		for k in open:
			var f: float = open[k]
			if f < best:
				best = f
				cur = k
		open.erase(cur)
		if cur.distance_to(goal) <= 1.5:
			var path := [Vector3i(cur.x, y, cur.y)]
			while came.has(cur):
				cur = came[cur]
				path.push_front(Vector3i(cur.x, y, cur.y))
			return path
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			var cell := Vector3i(n.x, y, n.y)
			var t := terrain.get_cell(cell)
			if t == DigTerrain.BEDROCK or t == DigTerrain.REINFORCED:
				continue
			var cost: float = g[cur] + 1.0 + (terrain.hardness(cell) if t != DigTerrain.AIR else 0.0)
			if not g.has(n) or cost < g[n]:
				g[n] = cost
				came[n] = cur
				open[n] = cost + n.distance_to(goal)
	return []


func _advance(d: Node) -> void:
	var path: Array = d.get_meta("path")
	if path.is_empty():
		d.raid_mode = false
		d._surface()
		return
	var next: Vector3i = path[0]
	var t := terrain.get_cell(next)
	if t != DigTerrain.AIR:
		var dt: float = d.get_meta("dig_t") + 0.25
		d.set_meta("dig_t", dt)
		if dt >= terrain.hardness(next) * 1.4:
			d.set_meta("dig_t", 0.0)
			terrain.set_cell(next, DigTerrain.AIR)
			if terrain.get_cell(next + Vector3i(0, 1, 0)) != DigTerrain.BEDROCK:
				terrain.set_cell(next + Vector3i(0, 1, 0), DigTerrain.AIR)
			Fx.dig_debris(terrain.cell_center(next), Color(0.4, 0.35, 0.3))
			Audio.play_at("dig", terrain.cell_center(next), -2.0, 35.0)
		return
	path.pop_front()
	d.global_position = terrain.cell_floor(next)
	# Surface once it breaks into the open base.
	var open_n := 0
	for dd in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if terrain.get_cell(next + dd) == DigTerrain.AIR:
			open_n += 1
	if open_n >= 2 and path.size() < 4:
		d.raid_mode = false
		d.target = get_tree().get_first_node_in_group("player")
		d._surface()
