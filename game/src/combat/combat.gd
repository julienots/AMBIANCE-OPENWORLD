class_name Combat
## Shared combat helpers: target queries and the damage pipeline used by every attack.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_INTERACT := 8


static func enemies(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e) and e.alive)


static func in_radius(tree: SceneTree, pos: Vector3, r: float) -> Array:
	var out: Array = []
	for e in enemies(tree):
		var d = (e.global_position - pos)
		d.y *= 0.5
		if d.length() <= r + e.hit_radius:
			out.append(e)
	return out


static func in_cone(tree: SceneTree, pos: Vector3, dir: Vector3, r: float, angle_deg: float) -> Array:
	var out: Array = []
	var cosv := cos(deg_to_rad(angle_deg * 0.5))
	dir.y = 0
	dir = dir.normalized()
	for e in in_radius(tree, pos, r):
		var to: Vector3 = e.global_position - pos
		to.y = 0
		if to.length() < e.hit_radius + 0.6 or to.normalized().dot(dir) >= cosv:
			out.append(e)
	return out


static func best_target(tree: SceneTree, pos: Vector3, dir: Vector3, max_dist: float, cone_deg := 90.0) -> Node3D:
	## Aim assist: nearest enemy weighted by angle from the facing direction, with line of sight.
	var best: Node3D = null
	var best_score := INF
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	for e in enemies(tree):
		var to: Vector3 = e.global_position - pos
		var dist := to.length()
		if dist > max_dist:
			continue
		var flat := Vector3(to.x, 0, to.z).normalized()
		var ang := rad_to_deg(acos(clampf(flat.dot(dir), -1.0, 1.0)))
		if ang > cone_deg * 0.5:
			continue
		if not has_los(e.get_world_3d(), pos + Vector3.UP * 1.2, e.global_position + Vector3.UP * e.aim_height):
			continue
		var score := dist * (1.0 + ang / 45.0)
		if score < best_score:
			best_score = score
			best = e
	return best


static func has_los(world: World3D, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, LAYER_WORLD)
	return world.direct_space_state.intersect_ray(q).is_empty()


static func hit(player: Node, target: Node, mult: float, opts := {}) -> float:
	## Computes and applies player damage to an enemy. Returns the dealt amount.
	if target == null or not is_instance_valid(target) or not target.alive:
		return 0.0
	var st: Dictionary = player.stats
	var dmg: float = st.atk * mult
	var kind: String = opts.get("kind", "melee")
	if kind == "ability":
		dmg *= 1.0 + float(st.get("ability_mult", 0.0))
	if player.transformed:
		dmg *= player.transform_mult
	var crit := randf() < float(st.get("crit", 0.05)) + (0.5 if player.counter_ready() else 0.0)
	if crit:
		dmg *= 1.75
	if player.counter_ready() and kind != "dot":
		dmg *= 2.0
		player.use_counter()
	if target.has_status("mark"):
		dmg *= 1.3
	var passive: Dictionary = player.hero.passive
	match passive.get("kind", ""):
		"backstab":
			if not target.is_aware_of_player():
				dmg *= float(passive.mult)
		"vs_status":
			if target.has_status(passive.status):
				dmg *= float(passive.mult)
	dmg *= 1.0 + Game.family_damage_bonus(target.family)
	var info := {
		"amount": dmg, "source": player, "pos": opts.get("pos", target.global_position + Vector3.UP * target.aim_height),
		"dir": opts.get("dir", (target.global_position - player.global_position).normalized()),
		"kind": kind, "crit": crit, "status": opts.get("status", ""), "status_t": opts.get("status_t", 3.0),
		"knock": opts.get("knock", 0.0), "poise": opts.get("poise", 10.0 * mult), "color": opts.get("color", player.hero.color),
	}
	var dealt: float = target.take_damage(info)
	if dealt > 0.0:
		player.on_dealt_damage(dealt, target, kind)
	return dealt
