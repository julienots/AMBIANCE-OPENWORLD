extends RefCounted
## Shared helpers for region builders: deterministic RNG, material palette and
## reusable structures (buildings, vehicles, debris, lamps, interactables).

const Door := preload("res://src/world/interact/door.gd")
const HideSpot := preload("res://src/world/interact/hide_spot.gd")
const Lamp := preload("res://src/world/interact/lamp.gd")
const Loot := preload("res://src/world/interact/loot.gd")
const Generator := preload("res://src/world/interact/generator.gd")
const Gate := preload("res://src/world/interact/gate.gd")
const Refuge := preload("res://src/world/interact/refuge.gd")
const AudioLog := preload("res://src/world/interact/audio_log.gd")
const Nest := preload("res://src/world/interact/nest.gd")
const Vent := preload("res://src/world/interact/vent.gd")
const Npc := preload("res://src/world/interact/npc.gd")
const Ladder := preload("res://src/world/interact/ladder.gd")
const Trigger := preload("res://src/world/interact/trigger.gd")
const Zone := preload("res://src/combat/zone.gd")

var rng := RandomNumberGenerator.new()
var w: Node3D
var geo: Geo
var _uid := 0


func setup(world: Node3D, seed_value: int) -> void:
	w = world
	geo = world.geo
	rng.seed = seed_value


func progress(p: float, text := "") -> void:
	Loader.set_progress(0.05 + p * 0.65, text)
	await w.get_tree().process_frame


func uid(prefix: String) -> String:
	_uid += 1
	return "%s_%s_%d" % [w.region_id, prefix, _uid]


func add(node: Node3D, pos: Vector3, rot_y := 0.0) -> Node3D:
	w.props.add_child(node)
	node.global_position = pos
	node.rotation.y = rot_y
	return node


# ------------------------------------------------------------------------------ materials

func base_materials() -> void:
	geo.env_mat("ground_asphalt", Color(0.17, 0.17, 0.2), Color(0.12, 0.12, 0.15), {"noise_scale": 0.08, "grit": 0.8})
	geo.env_mat("ground_sidewalk", Color(0.36, 0.35, 0.38), Color(0.3, 0.29, 0.32), {"noise_scale": 0.2})
	geo.env_mat("ground_dirt", Color(0.22, 0.18, 0.14), Color(0.16, 0.13, 0.1), {"noise_scale": 0.1, "grit": 0.9})
	geo.env_mat("ground_grass", Color(0.16, 0.22, 0.13), Color(0.12, 0.17, 0.1), {"noise_scale": 0.06})
	geo.env_mat("ground_goo", Color(0.05, 0.03, 0.06), Color(0.08, 0.04, 0.08), {"corruption": 1.0, "noise_scale": 0.12})
	geo.env_mat("line_paint", Color(0.85, 0.75, 0.3), Color(0.7, 0.62, 0.25), {"grit": 0.9})
	geo.env_mat("bld_a", Color(0.42, 0.4, 0.45), Color(0.34, 0.33, 0.38), {"windows": 1.0, "window_lit": 0.12})
	geo.env_mat("bld_b", Color(0.48, 0.36, 0.3), Color(0.4, 0.3, 0.26), {"windows": 1.0, "window_lit": 0.08, "window_color": Color(0.7, 0.85, 1.0)})
	geo.env_mat("bld_c", Color(0.3, 0.36, 0.42), Color(0.25, 0.3, 0.35), {"windows": 1.0, "window_lit": 0.15, "window_size": Vector2(3.0, 3.6)})
	geo.env_mat("bld_d", Color(0.5, 0.47, 0.4), Color(0.42, 0.4, 0.34), {"windows": 1.0, "window_lit": 0.05})
	geo.env_mat("bld_corrupt", Color(0.25, 0.22, 0.27), Color(0.18, 0.15, 0.2), {"windows": 1.0, "window_lit": 0.02, "corruption": 0.7, "window_color": Color(1.0, 0.2, 0.3)})
	geo.env_mat("roof", Color(0.25, 0.25, 0.28), Color(0.2, 0.2, 0.22), {"noise_scale": 0.3})
	geo.env_mat("concrete", Color(0.45, 0.45, 0.47), Color(0.38, 0.38, 0.4), {"noise_scale": 0.25})
	geo.env_mat("metal", Color(0.4, 0.42, 0.46), Color(0.32, 0.34, 0.38), {"specular_amount": 0.4})
	geo.env_mat("metal_dark", Color(0.16, 0.17, 0.2), Color(0.12, 0.12, 0.15), {"specular_amount": 0.3})
	geo.env_mat("rust", Color(0.45, 0.25, 0.15), Color(0.32, 0.2, 0.14), {"noise_scale": 0.4})
	geo.env_mat("wood", Color(0.42, 0.3, 0.2), Color(0.34, 0.24, 0.16), {"noise_scale": 0.5})
	geo.env_mat("rubble", Color(0.38, 0.36, 0.34), Color(0.3, 0.28, 0.26), {"noise_scale": 0.5, "grit": 1.0})
	geo.env_mat("tile_white", Color(0.75, 0.76, 0.78), Color(0.68, 0.7, 0.72), {"noise_scale": 0.3})
	geo.env_mat("glow_sign_red", Color(1.0, 0.2, 0.25), Color(1.0, 0.3, 0.3), {"emission_energy": 2.0})
	geo.env_mat("glow_sign_cyan", Color(0.2, 0.9, 1.0), Color(0.3, 0.95, 1.0), {"emission_energy": 2.0})
	geo.env_mat("glow_sign_yellow", Color(1.0, 0.8, 0.2), Color(1.0, 0.85, 0.3), {"emission_energy": 2.0})
	for c in [["car_red", Color(0.6, 0.12, 0.1)], ["car_blue", Color(0.12, 0.25, 0.5)], ["car_white", Color(0.75, 0.75, 0.76)],
			["car_yellow", Color(0.85, 0.65, 0.12)], ["car_green", Color(0.18, 0.35, 0.22)], ["car_black", Color(0.1, 0.1, 0.12)]]:
		geo.env_mat(c[0], c[1], c[1].darkened(0.15), {"specular_amount": 0.5, "noise_scale": 0.6, "grit": 0.4})
	geo.env_mat("glass_dark", Color(0.08, 0.1, 0.14), Color(0.1, 0.13, 0.17), {"specular_amount": 0.8})
	geo.env_mat("tire", Color(0.06, 0.06, 0.07), Color(0.05, 0.05, 0.06))


# ------------------------------------------------------------------------------ structures

func building(pos: Vector3, size: Vector3, mat: String, opts := {}) -> void:
	## A city building: body, roof slab, parapet, rooftop clutter, optional broken top,
	## optional ground-floor shopfront with a real interior and loot.
	var cx := pos.x
	var cz := pos.z
	var h := size.y
	var broken: bool = opts.get("broken", rng.randf() < 0.25)
	if opts.get("shop", false):
		_shop(pos, size, mat, opts)
	else:
		geo.box(Vector3(cx, h * 0.5, cz), size, mat, 0.0, true, "concrete", 0.55)
	if broken and h > 14.0:
		# Torn upper floors: stepped missing chunks.
		var bx := size.x * rng.randf_range(0.3, 0.55)
		var bz := size.z * rng.randf_range(0.3, 0.55)
		geo.box(Vector3(cx - size.x * 0.25, h + 2.5, cz - size.z * 0.25), Vector3(bx, 5.0, bz), mat, 0.0, false)
		geo.box(Vector3(cx + size.x * 0.2, h + 1.2, cz + size.z * 0.2), Vector3(bx * 0.6, 2.4, bz * 0.7), "rubble", 0.2, false)
	geo.box(Vector3(cx, h + 0.15, cz), Vector3(size.x + 0.4, 0.3, size.z + 0.4), "roof", 0.0, true, "concrete", 1.0)
	for s in [-1, 1]:
		geo.box(Vector3(cx + s * size.x * 0.5, h + 0.75, cz), Vector3(0.35, 1.2, size.z + 0.4), "concrete")
		geo.box(Vector3(cx, h + 0.75, cz + s * size.z * 0.5), Vector3(size.x + 0.4, 1.2, 0.35), "concrete")
	for i in rng.randi_range(1, 3):
		var p := Vector3(cx + rng.randf_range(-size.x * 0.3, size.x * 0.3), h + 0.3, cz + rng.randf_range(-size.z * 0.3, size.z * 0.3))
		geo.box(p + Vector3(0, 0.7, 0), Vector3(rng.randf_range(1.5, 3.0), 1.4, rng.randf_range(1.5, 2.5)), "metal", rng.randf() * TAU)
	if rng.randf() < 0.3:
		var p := Vector3(cx + size.x * 0.25, h + 0.3, cz - size.z * 0.25)
		for lx in [-1, 1]:
			for lz in [-1, 1]:
				geo.box(p + Vector3(lx * 0.9, 1.5, lz * 0.9), Vector3(0.2, 3.0, 0.2), "rust")
		geo.box(p + Vector3(0, 4.2, 0), Vector3(2.8, 2.6, 2.8), "wood")
	# Signs on a few facades
	if rng.randf() < 0.35:
		var sm: String = ["glow_sign_red", "glow_sign_cyan", "glow_sign_yellow"][rng.randi() % 3]
		geo.box(Vector3(cx, rng.randf_range(4.0, 8.0), cz - size.z * 0.5 - 0.2), Vector3(size.x * 0.4, 1.0, 0.2), sm, 0.0, false)


func _shop(pos: Vector3, size: Vector3, mat: String, opts: Dictionary) -> void:
	## Building whose ground floor is an explorable store, open toward -Z.
	var cx := pos.x
	var cz := pos.z
	var h := size.y
	var fh := 4.5
	var t := 0.4
	# Upper floors
	geo.box(Vector3(cx, fh + (h - fh) * 0.5, cz), Vector3(size.x, h - fh, size.z), mat, 0.0, true, "concrete", 0.8)
	# Ground floor walls (front has an opening)
	geo.box(Vector3(cx, fh * 0.5, cz + size.z * 0.5 - t * 0.5), Vector3(size.x, fh, t), "concrete")
	geo.box(Vector3(cx - size.x * 0.5 + t * 0.5, fh * 0.5, cz), Vector3(t, fh, size.z), "concrete")
	geo.box(Vector3(cx + size.x * 0.5 - t * 0.5, fh * 0.5, cz), Vector3(t, fh, size.z), "concrete")
	var open_w := minf(5.0, size.x * 0.45)
	var side := (size.x - open_w) * 0.5
	geo.box(Vector3(cx - size.x * 0.5 + side * 0.5, fh * 0.5, cz - size.z * 0.5 + t * 0.5), Vector3(side, fh, t), "concrete")
	geo.box(Vector3(cx + size.x * 0.5 - side * 0.5, fh * 0.5, cz - size.z * 0.5 + t * 0.5), Vector3(side, fh, t), "concrete")
	geo.box(Vector3(cx, fh - 0.6, cz - size.z * 0.5 + t * 0.5), Vector3(open_w, 1.2, t), "concrete")
	geo.box(Vector3(cx, 0.05, cz), Vector3(size.x - t * 2, 0.1, size.z - t * 2), "tile_white", 0.0, true, "concrete", 1.0)
	geo.box(Vector3(cx, fh - 0.1, cz), Vector3(size.x, 0.2, size.z), "concrete", 0.0, false)
	# Shelves, counter
	for i in 3:
		var sx := cx - size.x * 0.3 + i * size.x * 0.3
		geo.box(Vector3(sx, 0.9, cz + size.z * 0.15), Vector3(0.7, 1.8, size.z * 0.4), "metal_dark", 0.0, true, "metal")
	geo.box(Vector3(cx + size.x * 0.25, 0.55, cz - size.z * 0.25), Vector3(2.5, 1.1, 0.8), "wood", 0.0, true, "metal")
	var l := Lamp.new()
	l.style = "ceiling"
	l.radius = 7.0
	l.energy = 1.4
	l.switchable = false
	l.color = Color(0.85, 0.95, 1.0)
	add(l, Vector3(cx, fh - 0.25, cz))
	var lt := Loot.new()
	lt.uid = uid("shop")
	lt.table = opts.get("loot", {"metal": [1, 3], "electronics": [0, 2], "materials": [1, 2]})
	lt.items = opts.get("items", {})
	add(lt, Vector3(cx - size.x * 0.3, 0.1, cz - size.z * 0.3), rng.randf() * TAU)
	var hs := HideSpot.new()
	hs.kind = "locker"
	add(hs, Vector3(cx + size.x * 0.5 - 0.9, 0.1, cz + size.z * 0.3), -PI / 2)


func car(pos: Vector3, rot: float, color_mat := "", wrecked := false) -> void:
	var m = color_mat if color_mat != "" else ["car_red", "car_blue", "car_white", "car_yellow", "car_green", "car_black"][rng.randi() % 6]
	var b := Basis(Vector3.UP, rot)
	var tilt := rng.randf_range(-0.06, 0.06) if wrecked else 0.0
	geo.box(pos + b * Vector3(0, 0.7, 0), Vector3(1.9, 0.75, 4.3), m, rot, true, "metal", 0.85, tilt)
	geo.box(pos + b * Vector3(0, 1.35, 0.25), Vector3(1.7, 0.6, 2.2), "glass_dark" if not wrecked else m, rot, true, "metal", 1.0)
	geo.box(pos + b * Vector3(0, 1.66, 0.25), Vector3(1.65, 0.05, 2.0), m, rot, false)
	for wx in [-0.9, 0.9]:
		for wz in [-1.35, 1.35]:
			geo.box(pos + b * Vector3(wx, 0.35, wz), Vector3(0.3, 0.7, 0.7), "tire", rot, false)
	geo.box(pos + b * Vector3(0, 0.75, -2.16), Vector3(1.6, 0.18, 0.05), "glow_sign_yellow" if not wrecked else "metal_dark", rot, false)


func debris(center: Vector3, radius: float, count: int) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var d := rng.randf() * radius
		var s := Vector3(rng.randf_range(0.4, 1.8), rng.randf_range(0.2, 0.9), rng.randf_range(0.4, 1.8))
		geo.box(center + Vector3(cos(a) * d, s.y * 0.5, sin(a) * d), s, "rubble" if rng.randf() < 0.7 else "rust", rng.randf() * TAU, s.y > 0.5)


func barrier(pos: Vector3, rot: float, length := 4.0) -> void:
	geo.box(pos + Vector3(0, 0.5, 0), Vector3(length, 1.0, 0.5), "concrete", rot)
	geo.box(pos + Vector3(0, 1.05, 0), Vector3(length, 0.12, 0.55), "glow_sign_red", rot, false)


func lamp(pos: Vector3, rot := 0.0, opts := {}) -> Node3D:
	var l := Lamp.new()
	for k in opts:
		l.set(k, opts[k])
	return add(l, pos, rot)


func goo_patch(center: Vector3, radius: float, dps := 6.0) -> void:
	## Contaminated ground: damages players without spore protection.
	for i in 5:
		var a := rng.randf() * TAU
		var d := rng.randf() * radius * 0.6
		var s := radius * rng.randf_range(0.45, 0.8)
		geo.box(center + Vector3(cos(a) * d, 0.04, sin(a) * d), Vector3(s, 0.08, s * rng.randf_range(0.6, 1.0)), "ground_goo", rng.randf() * TAU, false)
	var z := Zone.new()
	z.radius = radius
	z.duration = 1e9
	z.hostile = true
	z.hostile_dps = dps
	z.mult = 0.0
	z.color = Color(0.7, 0.1, 0.3)
	w.props.add_child(z)
	z.global_position = center
	z.get_child(0).visible = false
	var smoke := Node3D.new()
	add(smoke, center)
	Fx.symbiote_smoke(smoke, Color(0.15, 0.04, 0.12, 0.45), 2.5, 12, 1.0)
