extends "res://src/world/interact/interactable.gd"
## A placed base installation. Visual is assembled from primitives; behaviour depends on
## its type (turret fires, lamp lights, trap hurts, door blocks, generator powers, elevator
## moves the player, the others open their management panel). Buildings have HP: raiders
## can break them; broken buildings stop working until repaired.

const Projectile := preload("res://src/combat/projectile.gd")
const DoorScript := preload("res://src/world/interact/door.gd")
const LampScript := preload("res://src/world/interact/lamp.gd")

var entry: Dictionary              # reference into Game.profile.base.buildings
var type := "generator"
var data: Dictionary
var terrain: Node
var _fire_t := 0.0
var _head: Node3D
var _status_light: MeshInstance3D
var _label: Label3D
var _lamp: Node3D
var _door: Node3D
var _loop: AudioStreamPlayer3D
var hit_radius := 1.0
var alive := true


func setup(e: Dictionary, t: Node) -> void:
	entry = e
	type = e.type
	data = DB.BUILDINGS[type]
	terrain = t


func _build() -> void:
	add_to_group("base_building")
	interact_range = 2.6 if not data.get("small", false) else 1.8
	if not entry.has("hp"):
		entry["hp"] = max_hp()
	var fp: Vector2i = data.size
	var w := fp.x * 2.0
	var d := fp.y * 2.0
	var accent := _accent()
	match type:
		"command":
			_box(Vector3(w * 0.8, 0.9, d * 0.5), Vector3(0, 0.45, 0), Color(0.25, 0.28, 0.33))
			_box(Vector3(w * 0.7, 1.0, 0.1), Vector3(0, 1.4, -d * 0.2), Color(0.1, 0.2, 0.25), 0.0)
			for i in 3:
				_box(Vector3(w * 0.2, 0.6, 0.05), Vector3((i - 1) * w * 0.24, 1.45, -d * 0.2 - 0.06), accent, 1.6)
			_box(Vector3(0.3, 2.6, 0.3), Vector3(w * 0.4, 1.3, d * 0.3), Color(0.3, 0.3, 0.33))
			_box(Vector3(0.6, 0.15, 0.6), Vector3(w * 0.4, 2.65, d * 0.3), accent, 2.0)
		"generator":
			_box(Vector3(1.5, 1.3, 1.5), Vector3(0, 0.65, 0), Color(0.3, 0.35, 0.3))
			_cyl(0.45, 1.0, Vector3(0, 1.8, 0), Color(0.2, 0.75, 0.95), 2.0)
			for i in 4:
				_box(Vector3(0.08, 1.2, 1.55), Vector3(-0.6 + i * 0.4, 0.65, 0), Color(0.15, 0.15, 0.17))
		"lab":
			_box(Vector3(w * 0.9, 0.9, 0.8), Vector3(0, 0.45, 0), Color(0.8, 0.82, 0.85))
			for i in 3:
				_cyl(0.18, 0.5, Vector3(-1.2 + i * 1.2, 1.15, 0), [Color(0.3, 1.0, 0.4), Color(0.9, 0.2, 0.3), Color(0.4, 0.6, 1.0)][i], 2.0)
			_box(Vector3(1.0, 0.7, 0.08), Vector3(1.0, 1.5, 0.35), Color(0.2, 0.9, 0.7), 1.5)
		"containment":
			_box(Vector3(w * 0.9, 0.2, d * 0.8), Vector3(0, 0.1, 0), Color(0.3, 0.3, 0.35))
			_cyl(0.9, 2.2, Vector3(-1.0, 1.3, 0), Color(0.3, 0.8, 1.0), 0.4, true)
			_cyl(0.9, 2.2, Vector3(1.0, 1.3, 0), Color(0.3, 0.8, 1.0), 0.4, true)
			var n := mini(2, Game.profile.base.creatures.size())
			for i in n:
				var blob := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.5
				s.height = 0.9
				blob.mesh = s
				blob.material_override = Mats.symbiote({"vein_strength": 2.0, "breathe": 0.05})
				blob.position = Vector3(-1.0 + i * 2.0, 0.9, 0)
				add_child(blob)
		"workshop":
			_box(Vector3(1.8, 0.1, 1.0), Vector3(0, 0.95, 0), Color(0.5, 0.38, 0.25))
			for x in [-0.8, 0.8]:
				_box(Vector3(0.1, 0.95, 0.9), Vector3(x, 0.47, 0), Color(0.3, 0.3, 0.32))
			_box(Vector3(0.4, 0.3, 0.3), Vector3(-0.4, 1.15, 0), Color(0.6, 0.15, 0.1))
			_box(Vector3(0.1, 0.5, 0.1), Vector3(0.5, 1.25, 0.1), Color(0.6, 0.6, 0.62))
			_box(Vector3(1.6, 1.0, 0.08), Vector3(0, 1.8, 0.45), Color(0.35, 0.3, 0.25))
		"infirmary":
			_box(Vector3(0.9, 0.5, 1.8), Vector3(0, 0.45, 0), Color(0.9, 0.92, 0.95))
			_box(Vector3(0.7, 0.15, 0.5), Vector3(0, 0.78, -0.55), Color(0.7, 0.8, 0.9))
			_box(Vector3(0.5, 0.12, 0.12), Vector3(0.6, 1.6, 0.8), Color(1.0, 0.2, 0.2), 2.0)
			_box(Vector3(0.12, 0.5, 0.12), Vector3(0.6, 1.6, 0.8), Color(1.0, 0.2, 0.2), 2.0)
		"armory":
			_box(Vector3(1.7, 2.0, 0.6), Vector3(0, 1.0, 0.3), Color(0.25, 0.27, 0.3))
			for i in 4:
				_box(Vector3(0.12, 1.2, 0.12), Vector3(-0.6 + i * 0.4, 1.1, 0.0), Color(0.55, 0.55, 0.6))
		"watch":
			_box(Vector3(0.3, 2.5, 0.3), Vector3(0, 1.25, 0), Color(0.3, 0.3, 0.33))
			_head = Node3D.new()
			_head.position.y = 2.6
			add_child(_head)
			var dish := _box(Vector3(1.2, 0.8, 0.1), Vector3(0, 0, 0), Color(0.6, 0.62, 0.65))
			dish.reparent(_head, false)
			var tip := _box(Vector3(0.15, 0.15, 0.4), Vector3(0, 0, -0.25), accent, 2.0)
			tip.reparent(_head, false)
		"turret":
			_cyl(0.5, 0.8, Vector3(0, 0.4, 0), Color(0.3, 0.32, 0.36))
			_head = Node3D.new()
			_head.position.y = 1.0
			add_child(_head)
			var body := _box(Vector3(0.6, 0.45, 0.7), Vector3.ZERO, Color(0.45, 0.48, 0.52))
			body.reparent(_head, false)
			for x in [-0.15, 0.15]:
				var barrel := _box(Vector3(0.1, 0.1, 0.8), Vector3(x, 0, -0.6), Color(0.15, 0.15, 0.17))
				barrel.reparent(_head, false)
			var eye := _box(Vector3(0.2, 0.08, 0.05), Vector3(0, 0.12, -0.37), Color(1, 0.2, 0.15), 2.5)
			eye.reparent(_head, false)
		"storage":
			for i in 3:
				_box(Vector3(0.8, 0.7, 0.8), Vector3(-0.4 + (i % 2) * 0.8, 0.35 + (i / 2) * 0.7, 0), Color(0.45, 0.35, 0.22))
		"training":
			_box(Vector3(w * 0.9, 0.1, d * 0.8), Vector3(0, 0.05, 0), Color(0.2, 0.3, 0.5))
			_cyl(0.3, 1.8, Vector3(-1.0, 0.9, 0), Color(0.7, 0.5, 0.3))
			_box(Vector3(0.9, 0.12, 0.12), Vector3(-1.0, 1.4, 0), Color(0.7, 0.5, 0.3))
			_box(Vector3(1.4, 0.1, 0.2), Vector3(1.0, 1.0, 0), Color(0.6, 0.6, 0.65))
		"lamp":
			_lamp = LampScript.new()
			_lamp.style = "base"
			_lamp.radius = 9.0
			_lamp.energy = 2.2
			_lamp.color = Color(1.0, 0.9, 0.7)
			add_child(_lamp)
		"door":
			_door = DoorScript.new()
			_door.width = 1.9
			_door.height = 1.95
			_door.color = Color(0.4, 0.45, 0.5)
			add_child(_door)
		"trap":
			_box(Vector3(1.6, 0.06, 1.6), Vector3(0, 0.03, 0), Color(0.25, 0.25, 0.27))
			for i in 9:
				var sp := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.08
				cm.height = 0.35
				sp.mesh = cm
				sp.material_override = Mats.toon(Color(0.7, 0.7, 0.75), 0.0, {"specular_amount": 0.5})
				sp.position = Vector3(-0.5 + (i % 3) * 0.5, 0.2, -0.5 + (i / 3) * 0.5)
				add_child(sp)
		"elevator":
			_box(Vector3(1.8, 0.15, 1.8), Vector3(0, 0.08, 0), Color(0.75, 0.6, 0.15))
			for x in [-0.85, 0.85]:
				_box(Vector3(0.12, 3.0, 0.12), Vector3(x, 1.5, 0.85), Color(0.3, 0.3, 0.32))
	if type not in ["lamp", "door", "trap"]:
		_status_light = _box(Vector3(0.12, 0.12, 0.12), Vector3(w * 0.45, 0.3, -d * 0.45), Color(0.2, 1.0, 0.3), 3.0)
		_label = Label3D.new()
		_label.font_size = 36
		_label.pixel_size = 0.005
		_label.outline_size = 8
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.position = Vector3(0, 2.9, 0)
		_label.modulate = Color(0.9, 0.95, 1.0, 0.9)
		add_child(_label)
	if type not in ["door", "trap", "lamp"]:
		static_box(self, Vector3(w * 0.85, 1.2, d * 0.7), Vector3(0, 0.6, 0), "metal")
	if type == "generator" and not broken():
		_loop = Audio.attach_loop(self, "generator_hum", -8.0, 16.0)
	refresh()


func _accent() -> Color:
	return {"command": Color(0.3, 0.9, 1.0), "watch": Color(1.0, 0.3, 0.2), "lab": Color(0.4, 1.0, 0.6)}.get(type, Color(1.0, 0.8, 0.3))


func _box(size: Vector3, pos: Vector3, col: Color, em := 0.0) -> MeshInstance3D:
	var m := box_mesh(size, col, em)
	m.position = pos
	m.material_override.next_pass = Mats.outline_material() if Mats.outline_enabled and em == 0.0 else null
	add_child(m)
	return m


func _cyl(r: float, h: float, pos: Vector3, col: Color, em := 0.0, glass := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	if glass:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, 0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = col * 0.3
		mi.material_override = m
	else:
		mi.material_override = Mats.toon(col, em)
	mi.position = pos
	add_child(mi)
	return mi


# ------------------------------------------------------------------------------ state

func level() -> int:
	return int(entry.get("level", 1))


func max_hp() -> float:
	return 120.0 + 60.0 * (level() - 1) if type != "door" else 200.0 + 100.0 * (level() - 1)


func broken() -> bool:
	return bool(entry.get("broken", false))


func powered() -> bool:
	if broken():
		return false
	if int(data.power) >= 0:
		return true
	return Game.base_powered()


func refresh() -> void:
	entry["powered"] = powered() or int(data.power) >= 0
	if _status_light:
		var c := Color(0.2, 1.0, 0.3) if powered() else (Color(1.0, 0.15, 0.1) if broken() else Color(1.0, 0.7, 0.1))
		(_status_light.material_override as ShaderMaterial).set_shader_parameter("albedo", c)
	if _label:
		var t: String = data.name + ("  niv. %d" % level() if int(data.max_level) > 1 else "")
		if broken():
			t += "\n⚠ EN PANNE"
		elif not powered():
			t += "\n⚡ sans courant"
		_label.text = t
	if _lamp:
		_lamp.set_on(not broken() and Game.base_powered())
	if _loop:
		_loop.playing = not broken()


func get_prompt(_p: Node) -> String:
	if broken():
		return "Réparer %s (métal 4)" % data.name
	match type:
		"elevator": return "Ascenseur"
		"lamp": return "Lampe"
		"trap": return "Piège à pointes"
	return data.name


func can_interact(p: Node) -> bool:
	return type != "door" and type != "lamp" and enabled


func interact(p: Node) -> void:
	if broken():
		if Game.spend({"metal": 4}):
			entry.broken = false
			entry.hp = max_hp()
			Audio.play_at("build_complete", global_position)
			Events.toast.emit("%s réparé" % data.name, "objective")
			Events.base_changed.emit()
		else:
			Events.toast.emit("Pas assez de métal", "warn")
		return
	if type == "elevator":
		_ride(p)
		return
	var w := get_tree().get_first_node_in_group("world")
	if w and w.menu:
		w.menu.open_building(self)


func _ride(p: Node) -> void:
	## Moves the player to the next floor of the shaft above or below the elevator.
	if terrain == null:
		return
	var c: Vector3i = terrain.cell_at(global_position + Vector3.UP * 0.5)
	var best := Vector3i(-1, -1, -1)
	for dy in range(2, 20):
		for sgn in [1, -1]:
			var cc := c + Vector3i(0, dy * sgn, 0)
			if terrain.is_floor_cell(cc):
				best = cc
				break
		if best.x >= 0:
			break
	if best.x < 0:
		Events.toast.emit("Creusez un puits vertical au-dessus ou en dessous de l'ascenseur", "warn")
		return
	Audio.play_at("generator_start", global_position, -4.0)
	var tw := p.create_tween()
	tw.tween_property(p, "global_position", terrain.cell_floor(best) + Vector3.UP * 0.2, 1.6).set_trans(Tween.TRANS_SINE)


func take_damage(info: Dictionary) -> float:
	if broken():
		return 0.0
	entry.hp = float(entry.hp) - float(info.amount)
	Fx.hit_spark(global_position + Vector3.UP, Color(1, 0.6, 0.2))
	Audio.play_at("metal_clang", global_position, -4.0)
	if float(entry.hp) <= 0.0:
		entry.broken = true
		entry.hp = 0.0
		Fx.explosion(global_position + Vector3.UP, 1.5, Color(1, 0.5, 0.2))
		Events.base_alert.emit("%s est hors service !" % data.name)
		Events.toast.emit("%s est en panne ! Réparez-le." % data.name, "warn")
		if type == "door" and _door:
			_door.force_open(Vector3.FORWARD)
		Events.base_changed.emit()
	return info.amount


# ------------------------------------------------------------------------------ behaviour

func _process(delta: float) -> void:
	if broken():
		return
	match type:
		"turret":
			if not powered():
				return
			_fire_t -= delta
			var best: Node3D = null
			var bd := 15.0 + 3.0 * level()
			for e in Combat.enemies(get_tree()):
				if e.get("underground") == true:
					continue
				var dd = e.global_position.distance_to(global_position)
				if dd < bd and Combat.has_los(get_world_3d(), _head.global_position, e.global_position + Vector3.UP * e.aim_height):
					bd = dd
					best = e
			if best:
				var to := best.global_position - _head.global_position
				_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-to.x, -to.z), delta * 8.0)
				if _fire_t <= 0.0:
					_fire_t = maxf(0.25, 0.7 - 0.12 * level())
					Audio.play_at("turret_fire", _head.global_position, -6.0)
					Fx.hit_spark(_head.global_position - _head.global_transform.basis.z * 0.9, Color(1, 0.6, 0.3))
					best.take_damage({"amount": 9.0 + 5.0 * level(), "source": self, "pos": best.global_position + Vector3.UP, "kind": "ranged", "dir": to.normalized()})
		"trap":
			_fire_t -= delta
			if _fire_t <= 0.0:
				for e in Combat.in_radius(get_tree(), global_position, 1.3):
					_fire_t = 1.0
					e.take_damage({"amount": 15.0 + 10.0 * level(), "source": self, "kind": "melee", "status": "slow", "status_t": 2.0})
					Audio.play_at("hit_flesh", global_position, -4.0)
		"watch":
			if _head and powered():
				_head.rotation.y += delta * 0.8
		"generator":
			if _head == null:
				pass
