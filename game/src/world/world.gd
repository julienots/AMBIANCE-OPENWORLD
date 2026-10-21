extends Node3D
## The playable world. Builds the current region (procedurally, over several frames with
## real progress on the loading screen), bakes navigation, spawns the player, the camera,
## the HUD and the creatures, and runs region-wide systems (spawning, trail, ambience).

const PlayerScene := preload("res://src/player/player.tscn")
const CameraScene := preload("res://src/player/camera_rig.tscn")
const HudScript := preload("res://src/ui/hud.gd")
const MenuScript := preload("res://src/ui/game_menu.gd")

const ENEMY_SCRIPTS := {
	"crawler": "res://src/enemies/crawler.gd", "stalker": "res://src/enemies/stalker.gd",
	"colossus": "res://src/enemies/colossus.gd", "mimic": "res://src/enemies/mimic.gd",
	"burrower": "res://src/enemies/burrower.gd", "abyssal": "res://src/enemies/abyssal.gd",
	"devourer": "res://src/enemies/devourer.gd", "colosse_fendu": "res://src/enemies/boss.gd",
	"reine_spores": "res://src/enemies/boss.gd", "gardien": "res://src/enemies/boss.gd",
	"architecte": "res://src/enemies/boss.gd",
}

var region_id := "city"
var region: RefCounted
var geo: Geo
var props: Node3D
var enemies_root: Node3D
var nav: NavigationRegion3D
var env: Environment
var sun: DirectionalLight3D
var player: CharacterBody3D
var cam_rig: Node3D
var hud: CanvasLayer
var menu: CanvasLayer
var spawn_points := {}           # gate id -> Transform3D
var spawn_zones: Array = []      # see add_spawn_zone
var markers := {}                # objective tag -> Vector3
var ambient_visibility := 0.6
var bounds := AABB(Vector3(-150, -20, -150), Vector3(300, 80, 300))
var ready_to_play := false
var _trail: Array = []           # [{p, t}]
var _trail_t := 0.0
var _spawn_t := 0.0
var _clock := 0.0
var _ambient_t := 8.0
var ambient_sounds: Array = []   # random distant sounds for the region


func _ready() -> void:
	add_to_group("world")
	add_to_group("fx_root")
	region_id = Game.current_region
	if Game.profile.is_empty():
		Game.start_new_game()
	Game.profile.player.region = region_id
	if not region_id in Game.profile.regions_seen:
		Game.profile.regions_seen.append(region_id)
	_setup_environment()
	nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	add_child(nav)
	geo = Geo.new(nav)
	geo.draw_distance = 140.0 * float(Settings.get_v("draw_distance", 1.0))
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	Loader.set_progress(0.05, "Génération de la région…")
	await get_tree().process_frame
	var script: GDScript = load(DB.REGIONS[region_id].builder)
	region = script.new()
	await region.build(self)
	Loader.set_progress(0.7, "Assemblage de la géométrie…")
	await get_tree().process_frame
	geo.build()
	Loader.set_progress(0.78, "Calcul de la navigation des créatures…")
	await get_tree().process_frame
	await _bake_navigation()
	Loader.set_progress(0.9, "Réveil des symbiotes…")
	await get_tree().process_frame
	_spawn_player()
	_initial_spawns()
	if region.has_method("post_spawn"):
		region.post_spawn(self)
	Loader.set_progress(1.0, "")
	var r: Dictionary = DB.REGIONS[region_id]
	Audio.set_region_music(r.music, r.ambience)
	Events.region_entered.emit(region_id)
	ready_to_play = true
	Loader.hide_loading()
	if region.has_method("on_enter"):
		region.on_enter(self)
	Game.save_game()


# ------------------------------------------------------------------------------ environment

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sm.set_shader_parameter("noise_tex", Mats.NOISE)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.glow_enabled = int(Settings.get_v("quality", 1)) >= 1
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = bool(Settings.get_v("shadows", true))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)


func configure_env(c: Dictionary) -> void:
	## Region look: sky, fog, ambient, sun, ground fog sheets, floating motes, acoustics.
	var sm: ShaderMaterial = env.sky.sky_material
	for k in ["top_color", "horizon_color", "glow_color", "moon_color", "cloudiness", "stars"]:
		if c.has(k):
			sm.set_shader_parameter(k, c[k])
	env.fog_light_color = c.get("fog_color", Color(0.1, 0.1, 0.14))
	env.fog_density = c.get("fog_density", 0.015)
	env.fog_sky_affect = c.get("fog_sky", 0.6)
	env.ambient_light_color = c.get("ambient", Color(0.3, 0.3, 0.42))
	env.ambient_light_energy = c.get("ambient_energy", 0.6)
	if c.get("no_sky", false):
		env.background_mode = Environment.BG_COLOR
		env.background_color = c.get("fog_color", Color.BLACK)
	sun.light_color = c.get("sun_color", Color(0.65, 0.7, 1.0))
	sun.light_energy = c.get("sun_energy", 0.6)
	sun.rotation_degrees = c.get("sun_rot", Vector3(-50, 35, 0))
	sun.visible = c.get("sun", true)
	ambient_visibility = c.get("visibility", 0.6)
	Audio.set_space(c.get("room", 0.4), c.get("reverb", 0.08))
	for i in int(c.get("fog_layers", 0)):
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(bounds.size.x * 1.2, bounds.size.z * 1.2)
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/fog_layer.gdshader")
		m.set_shader_parameter("noise_tex", Mats.NOISE)
		m.set_shader_parameter("color", c.get("ground_fog_color", Color(0.5, 0.52, 0.6)))
		m.set_shader_parameter("density", float(c.get("ground_fog_density", 0.3)) * (1.0 - i * 0.25))
		m.set_shader_parameter("scale", 0.03 + i * 0.012)
		m.set_shader_parameter("wind", Vector2(0.01 + i * 0.004, 0.005 - i * 0.003))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = bounds.get_center() * Vector3(1, 0, 1) + Vector3(0, float(c.get("ground_fog_height", 0.4)) + i * 0.55, 0)
		add_child(mi)
	if c.has("motes"):
		var cam_follow := Node3D.new()
		cam_follow.name = "Motes"
		add_child(cam_follow)
		Fx.ambient_motes(cam_follow, c.motes, Vector3(18, 6, 18), int(c.get("motes_amount", 50)), c.get("motes_size", 0.1))
	ambient_sounds = c.get("ambient_sounds", [])


# ------------------------------------------------------------------------------ navigation

func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"navsource"
	nm.geometry_collision_mask = Combat.LAYER_WORLD
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.6
	nm.agent_max_slope = 46.0
	nm.region_min_size = 4.0
	nm.filter_baking_aabb = bounds
	nav.navigation_mesh = nm
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.3)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)
	var t0 := Time.get_ticks_msec()
	nav.bake_navigation_mesh(true)
	while nav.is_baking():
		await get_tree().process_frame
		Loader.set_progress(0.78 + minf(0.1, (Time.get_ticks_msec() - t0) / 60000.0), "Calcul de la navigation des créatures…")
	print("[world] navmesh baked in %d ms, polys=%d" % [Time.get_ticks_msec() - t0, nm.get_polygon_count()])


# ------------------------------------------------------------------------------ player

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	cam_rig = CameraScene.instantiate()
	cam_rig.target_path = player.get_path()
	add_child(cam_rig)
	player.cam_rig = cam_rig
	var xf: Transform3D = spawn_points.get("start", Transform3D(Basis(), Vector3(0, 1, 0)))
	var saved: Array = Game.profile.player.get("pos", [])
	if Game.spawn_gate != "" and spawn_points.has(Game.spawn_gate):
		xf = spawn_points[Game.spawn_gate]
	elif saved.size() == 3 and Game.spawn_gate == "":
		xf = Transform3D(Basis(), Vector3(saved[0], saved[1] + 0.5, saved[2]))
	player.global_position = xf.origin
	player._heading = xf.basis.get_euler().y
	cam_rig.global_position = xf.origin
	cam_rig.snap_behind(player._heading)
	var hp: float = Game.profile.player.get("hp", -1.0)
	if hp > 0.0:
		player.hp = minf(hp, player.max_hp)
	add_child(preload("res://src/player/desktop_input.gd").new())
	hud = HudScript.new()
	add_child(hud)
	hud.set_player(player)
	hud.touch.pause_pressed.connect(open_menu)
	menu = MenuScript.new()
	add_child(menu)
	_update_objective_marker()
	Events.mission_updated.connect(func(_m): _update_objective_marker())
	Events.mission_completed.connect(func(_m): _update_objective_marker())


func _update_objective_marker() -> void:
	var cur := Game.current_objective()
	hud.objective_pos = Vector3.INF
	if cur.is_empty():
		return
	var id := Game.active_mission_id()
	if DB.MISSIONS[id].region != region_id and region_id != "base":
		# Point toward the gate leading to the mission region.
		var gate_tag := "gate_" + DB.MISSIONS[id].region
		if markers.has(gate_tag):
			hud.objective_pos = markers[gate_tag]
		return
	for key in [cur.target, cur.type + "_" + cur.target, cur.type]:
		if markers.has(key):
			var m = markers[key]
			if m is Array:
				# Closest remaining marker (e.g. several caches / nests).
				var best := Vector3.INF
				for p in m:
					if best == Vector3.INF or player.global_position.distance_to(p) < player.global_position.distance_to(best):
						best = p
				hud.objective_pos = best
			else:
				hud.objective_pos = m
			return


func add_marker(tag: String, pos: Vector3, multi := false) -> void:
	if multi:
		if not markers.has(tag):
			markers[tag] = []
		markers[tag].append(pos)
	else:
		markers[tag] = pos


func store_player_state() -> void:
	if player == null or not player.alive:
		return
	var p := player.global_position if player.state != "hidden" else player.hiding_spot.exit_position()
	Game.profile.player.pos = [p.x, p.y, p.z]
	Game.profile.player.hp = player.hp
	Game.profile.player.region = region_id


func respawn_player() -> void:
	var xf: Transform3D = spawn_points.get("refuge", spawn_points.get("start", Transform3D(Basis(), Vector3.UP)))
	# Death penalty: part of the carried symbiote samples is lost.
	var lost := int(Game.res("samples") * 0.2)
	if lost > 0:
		Game.profile.resources.samples -= lost
		Events.toast.emit("%d échantillons perdus" % lost, "warn")
	for e in Combat.enemies(get_tree()):
		if e.global_position.distance_to(xf.origin) < 25.0 and e.id != "devourer":
			e.lose_player()
		e.lose_player()
	player.revive_at(xf.origin)
	cam_rig.snap_behind(xf.basis.get_euler().y)
	Game.save_game()


func open_menu() -> void:
	store_player_state()
	menu.open("missions", false)


func open_refuge_menu(_refuge: Node) -> void:
	menu.open("refuge", true)


# ------------------------------------------------------------------------------ enemies

func spawn_enemy(id: String, pos: Vector3, opts := {}) -> Node:
	var e: CharacterBody3D = load(ENEMY_SCRIPTS.get(id, "res://src/enemies/enemy.gd")).new()
	e.setup(id, pos)
	for k in opts:
		e.set(k, opts[k])
	enemies_root.add_child(e)
	return e


func add_spawn_zone(center: Vector3, radius: float, table: Dictionary, max_count: int, respawn := 45.0, opts := {}) -> void:
	spawn_zones.append({"center": center, "radius": radius, "table": table, "max": max_count, "respawn": respawn,
		"alive": [], "timer": 0.0, "opts": opts})


func _pick(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return table.keys()[0]


func _spawn_in_zone(z: Dictionary, initial: bool) -> void:
	for attempt in 8:
		var a := randf() * TAU
		var d := sqrt(randf()) * float(z.radius)
		var p: Vector3 = z.center + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var np := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
		if np.distance_to(p) > 4.0:
			continue
		if not initial and not _spawn_point_ok(np):
			continue
		if initial and player and np.distance_to(player.global_position) < 18.0:
			continue
		var id := _pick(z.table)
		var e := spawn_enemy(id, np + Vector3.UP * 0.2, z.opts)
		e.spawner = self
		e.home = z.center
		var pts: Array = []
		for i in 3:
			var pa := randf() * TAU
			pts.append(NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, z.center + Vector3(cos(pa), 0, sin(pa)) * float(z.radius) * 0.8))
		e.patrol_points = pts if id in ["stalker", "colossus"] else []
		z.alive.append(e)
		return


func _spawn_point_ok(p: Vector3) -> bool:
	## Never pop a creature into existence where the player could witness it.
	if player == null:
		return true
	var d := p.distance_to(player.global_position)
	if d < 32.0:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam and d < 90.0 and not cam.is_position_behind(p + Vector3.UP):
		var sp := cam.unproject_position(p + Vector3.UP)
		var vs := get_viewport().get_visible_rect().size
		if Rect2(Vector2.ZERO, vs).has_point(sp) and Combat.has_los(get_world_3d(), cam.global_position, p + Vector3.UP):
			return false
	return true


func _initial_spawns() -> void:
	for z in spawn_zones:
		for i in int(z.max):
			_spawn_in_zone(z, true)


func on_enemy_died(e: Node) -> void:
	for z in spawn_zones:
		z.alive.erase(e)


# ------------------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if not ready_to_play:
		return
	_clock += delta
	Pad.begin_frame()
	if Pad.consume("pause"):
		open_menu()
	# Player trail for the Devourer's searches.
	_trail_t -= delta
	if _trail_t <= 0.0 and player and player.alive:
		_trail_t = 1.0
		if _trail.is_empty() or _trail[-1].p.distance_to(player.global_position) > 2.0:
			_trail.append({"p": player.global_position, "t": _clock})
			if _trail.size() > 90:
				_trail.pop_front()
	# Respawns
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 3.0
		for z in spawn_zones:
			z.alive = z.alive.filter(func(e): return is_instance_valid(e) and e.alive)
			if z.alive.size() < int(z.max):
				z.timer += 3.0
				if z.timer >= float(z.respawn):
					z.timer = 0.0
					_spawn_in_zone(z, false)
	# Distant ambient sounds (unseen creatures, metal, wind…).
	_ambient_t -= delta
	if _ambient_t <= 0.0 and not ambient_sounds.is_empty() and player:
		_ambient_t = randf_range(9.0, 20.0)
		var a := randf() * TAU
		var pos := player.global_position + Vector3(cos(a), 0.3, sin(a)) * randf_range(18.0, 40.0)
		Audio.play_at(ambient_sounds.pick_random(), pos, -4.0, 70.0)
	var motes := get_node_or_null("Motes")
	if motes and player:
		motes.global_position = player.global_position
	if region and region.has_method("tick"):
		region.tick(self, delta)


func recent_trail(center: Vector3, radius: float, max_age: float) -> Array:
	var out: Array = []
	for i in range(_trail.size() - 1, -1, -1):
		var e: Dictionary = _trail[i]
		if _clock - e.t > max_age:
			break
		if e.p.distance_to(center) < radius:
			out.append(e.p)
	return out
