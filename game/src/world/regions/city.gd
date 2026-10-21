extends "res://src/world/regions/region_base.gd"
## Region A — La Mégapole abandonnée.
## 5x5 blocks of 40 m separated by 14 m streets. Place Lumière (centre) hosts the refuge
## and the hatch to the underground base. A metro station lies under block (3,1).

const PITCH := 54.0
const BLOCK := 40.0
const ROAD := 14.0
const X0 := -142.0


func block_center(i: int, j: int) -> Vector3:
	return Vector3(-108.0 + i * PITCH, 0, -108.0 + j * PITCH)


func street(k: int) -> float:
	return X0 + ROAD * 0.5 + k * PITCH


func build(world: Node3D) -> void:
	setup(world, 1337)
	w.bounds = AABB(Vector3(-150, -12, -150), Vector3(300, 80, 300))
	w.configure_env({
		"top_color": Color(0.02, 0.025, 0.06), "horizon_color": Color(0.2, 0.11, 0.15), "glow_color": Color(0.55, 0.16, 0.12),
		"fog_color": Color(0.09, 0.07, 0.1), "fog_density": 0.012, "ambient": Color(0.5, 0.47, 0.66), "ambient_energy": 1.15,
		"sun_color": Color(0.7, 0.75, 1.0), "sun_energy": 0.8, "sun_rot": Vector3(-42, 30, 0), "visibility": 0.55,
		"fog_layers": 2, "ground_fog_color": Color(0.32, 0.28, 0.34), "ground_fog_density": 0.22, "ground_fog_height": 0.3,
		"motes": Color(1.0, 0.55, 0.3, 0.6), "motes_amount": 30, "motes_size": 0.06,
		"ambient_sounds": ["distant_scream", "metal_creak", "crawler_chitter", "distant_alarm", "wind_gust"],
		"room": 0.35, "reverb": 0.06,
	})
	base_materials()
	await progress(0.05, "Rues et trottoirs…")
	_ground()
	await progress(0.15, "Gratte-ciel…")
	var k := 0
	for i in 5:
		for j in 5:
			if i == 2 and j == 2:
				_plaza()
			elif i == 3 and j == 1:
				_metro_block()
			elif i == 0 and j == 4:
				_contaminated_block()
			else:
				_city_block(i, j)
			k += 1
			if k % 5 == 0:
				await progress(0.15 + 0.6 * k / 25.0, "Gratte-ciel…")
	await progress(0.8, "Véhicules et débris…")
	_streets_dressing()
	_gates()
	_rooftops()
	_enemy_zones()
	await progress(1.0, "")


# ------------------------------------------------------------------------------ ground

func _ground() -> void:
	var size := 284.0
	for k in 6:
		var z := street(k)
		geo.box(Vector3(0, -0.25, z), Vector3(size, 0.5, ROAD), "ground_asphalt", 0.0, true, "concrete", 1.0)
		for s in range(-13, 14):
			geo.box(Vector3(s * 10.0 + 2.5, 0.01, z), Vector3(4.0, 0.02, 0.25), "line_paint", 0.0, false)
	for k in 6:
		var x := street(k)
		for j in 5:
			var zc := -108.0 + j * PITCH
			geo.box(Vector3(x, -0.25, zc), Vector3(ROAD, 0.5, BLOCK), "ground_asphalt", 0.0, true, "concrete", 1.0)
	for i in 5:
		for j in 5:
			if i == 3 and j == 1:
				continue
			var c := block_center(i, j)
			geo.box(c + Vector3(0, -0.25, 0), Vector3(BLOCK, 0.5, BLOCK), "ground_sidewalk" if not (i == 2 and j == 2) else "ground_sidewalk", 0.0, true, "concrete", 1.0)
			# Curb lines (visual only)
			for s in [-1, 1]:
				geo.box(c + Vector3(s * BLOCK * 0.5, 0.03, 0), Vector3(0.3, 0.06, BLOCK), "concrete", 0.0, false)
				geo.box(c + Vector3(0, 0.03, s * BLOCK * 0.5), Vector3(BLOCK, 0.06, 0.3), "concrete", 0.0, false)
	# Outer walls: collapsed overpasses and barricades close the map.
	for s in [-1, 1]:
		geo.box(Vector3(s * 146.0, 6.0, 0), Vector3(4.0, 12.0, 300.0), "concrete")
		geo.box(Vector3(0, 6.0, s * 146.0), Vector3(300.0, 12.0, 4.0), "concrete")


func _city_block(i: int, j: int) -> void:
	var c := block_center(i, j)
	var mats := ["bld_a", "bld_b", "bld_c", "bld_d"]
	var lots := [Vector3(-10, 0, -10), Vector3(10, 0, -10), Vector3(-10, 0, 10), Vector3(10, 0, 10)]
	var empty := rng.randi() % 4 if rng.randf() < 0.6 else -1
	for li in 4:
		var lp: Vector3 = c + lots[li]
		if li == empty:
			# Parking lot / rubble field
			for n in rng.randi_range(1, 3):
				car(lp + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), rng.randf() * TAU, "", true)
			debris(lp, 7.0, 6)
			if rng.randf() < 0.5:
				var lt := Loot.new()
				lt.uid = uid("crate")
				add(lt, lp + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), rng.randf() * TAU)
			continue
		var h := rng.randf_range(12.0, 46.0) if not (abs(i - 2) <= 1 and abs(j - 2) <= 1) else rng.randf_range(10.0, 28.0)
		var size := Vector3(rng.randf_range(13.0, 17.5), h, rng.randf_range(13.0, 17.5))
		var shop := li < 2 and rng.randf() < 0.45
		building(lp, size, mats[rng.randi() % 4], {"shop": shop, "broken": rng.randf() < 0.3})
		if not shop and rng.randf() < 0.35:
			var hs := HideSpot.new()
			hs.kind = "locker"
			add(hs, lp + Vector3(0, 0, -size.z * 0.5 - 0.6), PI)
	# Street furniture
	if rng.randf() < 0.6:
		lamp(c + Vector3(-BLOCK * 0.5 + 1.0, 0, -BLOCK * 0.5 + 1.0), PI / 4, {"radius": 10.0, "energy": 2.0, "on": rng.randf() < 0.55})


func _plaza() -> void:
	var c := Vector3.ZERO
	geo.box(c + Vector3(0, 0.02, 0), Vector3(34, 0.04, 34), "tile_white", 0.0, false)
	# Fountain
	geo.box(c + Vector3(0, 0.4, 12), Vector3(7, 0.8, 7), "concrete", 0.0, true)
	geo.box(c + Vector3(0, 1.6, 12), Vector3(1.2, 2.4, 1.2), "concrete")
	geo.box(c + Vector3(0, 3.0, 12), Vector3(3.0, 0.3, 3.0), "concrete")
	# Sandbag walls around the refuge
	for a in range(0, 360, 30):
		var r := deg_to_rad(a)
		if a in [90, 270]:
			continue
		geo.box(c + Vector3(cos(r) * 11.0, 0.55, sin(r) * 11.0), Vector3(4.5, 1.1, 1.0), "wood", -r + PI / 2)
	var rf := Refuge.new()
	add(rf, c + Vector3(0, 0, 0))
	w.add_marker("refuge", c)
	for a in range(45, 360, 90):
		var r := deg_to_rad(a)
		lamp(c + Vector3(cos(r) * 8.5, 0, sin(r) * 8.5), r, {"style": "base", "radius": 11.0, "energy": 2.6, "color": Color(0.9, 1.0, 0.85), "repels": true})
	var hatch := Gate.new()
	hatch.target_region = "base"
	hatch.target_gate = "from_city"
	hatch.label = "Trappe de la base"
	add(hatch, c + Vector3(2.2, 0, -3.5))
	w.add_marker("gate_base", c + Vector3(2.2, 0, -3.5))
	w.add_marker("dig", c + Vector3(2.2, 0, -3.5))
	w.add_marker("build", c + Vector3(2.2, 0, -3.5))
	w.spawn_points["refuge"] = Transform3D(Basis(Vector3.UP, PI), c + Vector3(0, 0.3, 4.0))
	w.spawn_points["from_base"] = Transform3D(Basis(Vector3.UP, PI), c + Vector3(3.5, 0.3, -2.0))
	w.spawn_points["start"] = Transform3D(Basis(Vector3.UP, 0.0), Vector3(-27, 0.3, 78))
	var log := AudioLog.new()
	log.log_id = "log_city_1"
	add(log, c + Vector3(-1.5, 0, 1.5))
	# Stash of essentials for new survivors
	var lt := Loot.new()
	lt.uid = "city_refuge_stash"
	lt.table = {"metal": [3, 3], "materials": [3, 3]}
	lt.items = {"flare": 1, "medkit": 1}
	add(lt, c + Vector3(-3.0, 0, -3.0))
	# Benches & planters
	for p in [Vector3(-14, 0, -14), Vector3(14, 0, -14), Vector3(-14, 0, 14), Vector3(14, 0, 14)]:
		geo.box(p + Vector3(0, 0.5, 0), Vector3(3.0, 1.0, 3.0), "concrete")
		geo.box(p + Vector3(0, 1.4, 0), Vector3(2.4, 0.8, 2.4), "ground_grass", 0.0, false)


func _contaminated_block() -> void:
	var c := block_center(0, 4)
	for li in 3:
		var lp = c + [Vector3(-10, 0, -10), Vector3(10, 0, -10), Vector3(-10, 0, 10)][li]
		building(lp, Vector3(15, rng.randf_range(14, 30), 15), "bld_corrupt", {"broken": true})
	goo_patch(c + Vector3(8, 0, 8), 9.0, 7.0)
	goo_patch(c + Vector3(-14, 0, 18), 5.0, 6.0)
	var nest := Nest.new()
	nest.mission_tag = "nest_city"
	add(nest, c + Vector3(10, 0, 10))
	var lt := Loot.new()
	lt.uid = uid("goo")
	lt.table = {"samples": [2, 3], "spores": [2, 4]}
	add(lt, c + Vector3(4, 0, 14))


func _metro_block() -> void:
	var c := block_center(3, 1)          # (54, 0, -54)
	# Ground slab with an opening for the stairs (x 46..52, z -64..-46)
	var x0 := c.x - BLOCK * 0.5
	var x1 := c.x + BLOCK * 0.5
	var z0 := c.z - BLOCK * 0.5
	var z1 := c.z + BLOCK * 0.5
	var ox0 := 46.0
	var ox1 := 52.0
	var oz0 := -64.0
	var oz1 := -46.0
	_slab(x0, ox0, z0, z1)
	_slab(ox1, x1, z0, z1)
	_slab(ox0, ox1, z0, oz0)
	_slab(ox0, ox1, oz1, z1)
	# Kiosk walls around the opening
	geo.box(Vector3(ox0 - 0.2, 1.2, (oz0 + oz1) * 0.5), Vector3(0.4, 2.4, oz1 - oz0), "metal_dark")
	geo.box(Vector3(ox1 + 0.2, 1.2, (oz0 + oz1) * 0.5), Vector3(0.4, 2.4, oz1 - oz0), "metal_dark")
	geo.box(Vector3((ox0 + ox1) * 0.5, 3.0, -55), Vector3(7.0, 0.3, 20.0), "metal_dark", 0.0, false)
	geo.box(Vector3((ox0 + ox1) * 0.5, 3.6, oz1 + 0.3), Vector3(6.0, 1.0, 0.3), "glow_sign_yellow", 0.0, false)
	geo.ramp(Vector3(49, 0.0, -46.5), Vector3(49, -7.0, -63.5), 5.6, 0.4, "concrete")
	# Station hall (floor top at y = -7, ceiling at y = -1)
	var hx0 := 36.0
	var hx1 := 82.0
	var hz0 := -80.0
	var hz1 := -62.0
	geo.box(Vector3((hx0 + hx1) * 0.5, -7.25, (hz0 + hz1) * 0.5), Vector3(hx1 - hx0, 0.5, hz1 - hz0), "tile_white", 0.0, true, "concrete", 1.0)
	geo.box(Vector3((hx0 + hx1) * 0.5, -0.85, (hz0 + hz1) * 0.5), Vector3(hx1 - hx0, 0.3, hz1 - hz0), "concrete", 0.0, true)
	geo.box(Vector3((hx0 + hx1) * 0.5, -4.0, hz0), Vector3(hx1 - hx0, 6.0, 0.6), "tile_white")
	geo.box(Vector3(hx1, -4.0, (hz0 + hz1) * 0.5), Vector3(0.6, 6.0, hz1 - hz0), "tile_white")
	# North wall with the ramp gap (x 46..52)
	geo.box(Vector3((hx0 + 46.0) * 0.5, -4.0, hz1), Vector3(46.0 - hx0, 6.0, 0.6), "tile_white")
	geo.box(Vector3((52.0 + hx1) * 0.5, -4.0, hz1), Vector3(hx1 - 52.0, 6.0, 0.6), "tile_white")
	# Ramp corridor walls under ground
	geo.box(Vector3(45.7, -3.5, -55), Vector3(0.6, 7.0, 18), "tile_white")
	geo.box(Vector3(52.3, -3.5, -55), Vector3(0.6, 7.0, 18), "tile_white")
	# Track pit along the south side
	geo.box(Vector3((hx0 + hx1) * 0.5, -7.05, -76.0), Vector3(hx1 - hx0, 0.1, 6.0), "metal_dark", 0.0, false)
	for rz in [-77.0, -75.0]:
		geo.box(Vector3((hx0 + hx1) * 0.5, -6.9, rz), Vector3(hx1 - hx0, 0.12, 0.15), "metal", 0.0, false)
	for n in 12:
		geo.box(Vector3(hx0 + 2 + n * 3.8, -6.95, -76.0), Vector3(0.4, 0.08, 3.4), "wood", 0.0, false)
	# Wrecked train
	geo.box(Vector3(70, -5.3, -76.0), Vector3(18, 3.2, 3.2), "metal", 0.03)
	geo.box(Vector3(70, -4.6, -74.35), Vector3(16, 1.0, 0.1), "glass_dark", 0.03, false)
	# Pillars & benches
	for n in 5:
		geo.box(Vector3(40 + n * 9.0, -4.0, -70.5), Vector3(0.8, 6.0, 0.8), "tile_white")
		geo.box(Vector3(44 + n * 9.0, -6.6, -66.0), Vector3(2.4, 0.5, 0.7), "wood")
	for n in 4:
		lamp(Vector3(42 + n * 11.0, -1.1, -70.0), 0.0, {"style": "ceiling", "radius": 8.0, "energy": 1.3, "color": Color(0.8, 0.95, 1.0), "on": n % 2 == 0, "switchable": true})
	for p in [Vector3(80.5, -7, -66), Vector3(80.5, -7, -70)]:
		var hs := HideSpot.new()
		hs.kind = "locker"
		add(hs, p, -PI / 2)
	var npc := Npc.new()
	npc.npc_name = "Dr Halvorsen"
	npc.mission_tag = "scientist"
	add(npc, Vector3(76, -7, -67), PI * 0.5)
	w.add_marker("scientist", Vector3(76, -7, -67))
	var tr := Trigger.new()
	tr.tag = "metro"
	tr.radius = 6.0
	add(tr, Vector3(49, -7, -66))
	w.add_marker("metro", Vector3(49, 0, -48))
	var lt := Loot.new()
	lt.uid = "city_metro_box"
	lt.table = {"electronics": [2, 3], "metal": [2, 3]}
	add(lt, Vector3(38.5, -7, -64))
	# West tunnel mouth → the Depths
	geo.box(Vector3(hx0, -4.0, -66.5), Vector3(0.6, 6.0, 9.0), "tile_white")
	var g := Gate.new()
	g.target_region = "depths"
	g.target_gate = "from_city"
	g.label = "Tunnel de service"
	add(g, Vector3(38.5, -7, -76), PI / 2)
	w.spawn_points["from_depths"] = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(41.0, -6.7, -76))
	w.add_marker("gate_depths", Vector3(49, 0, -48))
	# Station creatures: ambush crawlers under benches
	w.add_spawn_zone(Vector3(60, -7, -70), 10.0, {"crawler": 1.0}, 3, 90.0, {"ambusher": true})
	# Kiosk building on the rest of the block
	building(c + Vector3(-12, 0, 12), Vector3(12, 18, 12), "bld_c", {"shop": false})
	building(c + Vector3(12, 0, 12), Vector3(12, 26, 12), "bld_a", {"shop": false})


func _slab(x0: float, x1: float, z0: float, z1: float) -> void:
	geo.box(Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.5, z1 - z0), "ground_sidewalk", 0.0, true, "concrete", 1.0)


# ------------------------------------------------------------------------------ dressing

func _streets_dressing() -> void:
	for k in 6:
		var z := street(k)
		for n in rng.randi_range(4, 8):
			var x := rng.randf_range(-130, 130)
			car(Vector3(x, 0, z + rng.randf_range(-4, 4)), PI / 2 + rng.randf_range(-0.4, 0.4), "", rng.randf() < 0.4)
		var x2 := street(k)
		for n in rng.randi_range(3, 6):
			var zz := rng.randf_range(-130, 130)
			if abs(zz) < 20 and abs(x2) < 30:
				continue
			car(Vector3(x2 + rng.randf_range(-4, 4), 0, zz), rng.randf_range(-0.4, 0.4), "", rng.randf() < 0.4)
		for n in 3:
			debris(Vector3(rng.randf_range(-130, 130), 0, z), 4.0, 4)
		for n in 4:
			var lx := -130.0 + n * 70.0 + rng.randf_range(-6, 6)
			lamp(Vector3(lx, 0, z + ROAD * 0.5 - 0.6), PI, {"radius": 11.0, "energy": 2.2, "on": rng.randf() < 0.5})
	# Barricades from the first days of the invasion
	for p in [Vector3(-27, 0, -27), Vector3(27, 0, 27), Vector3(81, 0, -81), Vector3(-81, 0, 81)]:
		barrier(p + Vector3(-4, 0, 0), 0.0)
		barrier(p + Vector3(4, 0, 2), 0.2)
	# Burning wrecks: fire light + smoke columns
	for p in [Vector3(-81, 0, -40), Vector3(60, 0, 27), Vector3(-30, 0, -81), Vector3(108, 0, 81)]:
		car(p, rng.randf() * TAU, "car_black", true)
		var f := Node3D.new()
		add(f, p + Vector3(0, 1.2, 0))
		_fire(f)
	# Supply caches (mission m02)
	for p in [Vector3(-54, 0, 30), Vector3(54, 0, 27.5)]:
		var lt := Loot.new()
		lt.uid = uid("cache")
		lt.kind = "cache"
		lt.mission_tag = "supply_cache"
		lt.table = {"metal": [3, 5], "electronics": [1, 2], "crystal": [1, 2]}
		lt.items = {"medkit": 1, "flare": 1}
		add(lt, p)
		w.add_marker("supply_cache", p, true)


func _fire(parent: Node3D) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 3.0
	l.omni_range = 12.0
	parent.add_child(l)
	var p := CPUParticles3D.new()
	p.amount = maxi(10, int(26 * Fx.density()))
	p.lifetime = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	p.mesh = q
	p.material_override = Fx._particle_mat(Fx.TEX_SMOKE, true, true)
	p.color_ramp = Fx._gradient(Color(2.2, 0.9, 0.3, 0.9), Color(0.5, 0.1, 0.05, 0.0))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.8, 0.2, 1.5)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	parent.add_child(p)
	var s := CPUParticles3D.new()
	s.amount = maxi(6, int(16 * Fx.density()))
	s.lifetime = 7.0
	var q2 := QuadMesh.new()
	q2.size = Vector2(4.0, 4.0)
	s.mesh = q2
	s.material_override = Fx._particle_mat(Fx.TEX_SMOKE, false, true)
	s.color_ramp = Fx._gradient(Color(0.12, 0.1, 0.1, 0.7), Color(0.1, 0.09, 0.1, 0.0))
	s.direction = Vector3.UP
	s.spread = 8.0
	s.initial_velocity_min = 2.0
	s.initial_velocity_max = 3.0
	s.gravity = Vector3(0.4, 0.3, 0)
	s.anim_speed_min = 0.3
	s.anim_speed_max = 0.3
	s.position.y = 1.5
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 2.5))
	s.scale_amount_curve = c
	parent.add_child(s)
	Audio.attach_loop(parent, "flare_loop", -10.0, 18.0)


func _rooftops() -> void:
	## Three buildings with fire escapes and survivor caches on their roofs (mission s01).
	var spots := [[Vector3(-54, 0, -54), 20.0], [Vector3(-108, 0, 0), 24.0], [Vector3(108, 0, -54), 22.0]]
	for s in spots:
		var p: Vector3 = s[0]
		var h: float = s[1]
		geo.box(p + Vector3(0, h * 0.5, 0), Vector3(16, h, 16), "bld_d", 0.0, true, "concrete", 0.55)
		geo.box(p + Vector3(0, h + 0.15, 0), Vector3(16.4, 0.3, 16.4), "roof", 0.0, true)
		var ld := Ladder.new()
		ld.height = h
		ld.top = p + Vector3(0, h + 0.4, -6.5)
		add(ld, p + Vector3(0, 0, -8.35), 0.0)
		var lt := Loot.new()
		lt.uid = uid("roof")
		lt.kind = "cache"
		lt.mission_tag = "roof_cache"
		lt.table = {"crystal": [2, 3], "alloy": [0, 1], "electronics": [1, 2]}
		add(lt, p + Vector3(3, h + 0.3, 3))
		w.add_marker("roof_cache", p + Vector3(0, 0, -8.5), true)
		lamp(p + Vector3(-5, h + 0.3, 5), 0.0, {"style": "lantern", "radius": 6.0, "energy": 1.5})


func _gates() -> void:
	var gf := Gate.new()
	gf.target_region = "forest"
	gf.target_gate = "from_city"
	add(gf, Vector3(0, 0, -139), 0.0)
	w.add_marker("gate_forest", Vector3(0, 0, -139))
	w.spawn_points["from_forest"] = Transform3D(Basis(), Vector3(0, 0.3, -132))
	var gl := Gate.new()
	gl.target_region = "lab"
	gl.target_gate = "from_city"
	add(gl, Vector3(139, 0, 0), PI / 2)
	w.add_marker("gate_lab", Vector3(139, 0, 0))
	w.spawn_points["from_lab"] = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(132, 0.3, 0))
	# Openings in the outer wall at both gates
	geo.box(Vector3(0, 0.6, -143.5), Vector3(8, 1.2, 1.0), "glow_sign_red", 0.0, false)


func _enemy_zones() -> void:
	w.add_spawn_zone(Vector3(-81, 0, -81), 14.0, {"crawler": 1.0}, 4, 40.0)
	w.add_spawn_zone(Vector3(81, 0, 81), 14.0, {"crawler": 1.0}, 4, 40.0)
	w.add_spawn_zone(Vector3(-27, 0, 27), 12.0, {"crawler": 1.0}, 3, 50.0, {"ambusher": true})
	w.add_spawn_zone(Vector3(-108, 0, 108), 14.0, {"crawler": 2.0, "stalker": 1.0}, 4, 45.0)
	w.add_spawn_zone(Vector3(-81, 0, 27), 18.0, {"stalker": 1.0}, 1, 120.0)
	w.add_spawn_zone(Vector3(81, 0, -27), 18.0, {"stalker": 1.0}, 2, 120.0)
	w.add_spawn_zone(Vector3(27, 0, -108), 10.0, {"mimic": 1.0}, 1, 180.0)
	w.add_spawn_zone(Vector3(-135, 0, -27), 10.0, {"mimic": 1.0}, 1, 180.0)
	w.add_spawn_zone(Vector3(108, 0, 0), 20.0, {"colossus": 1.0}, 1, 300.0)


func post_spawn(world: Node3D) -> void:
	# Tutorial guidance on a fresh game.
	if not Game.profile.flags.get("tutorial_city", false):
		Game.profile.flags["tutorial_city"] = true
		Game.start_mission("m01_first_steps")
		Events.toast.emit("Joystick gauche : se déplacer · Glisser à droite : caméra", "objective")
		Events.toast.emit("Atteignez le refuge de la place Lumière (flèche en haut)", "objective")
