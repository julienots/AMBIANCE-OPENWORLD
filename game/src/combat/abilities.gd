class_name Abilities
## Implements every ability "kind" referenced in DB.HEROES. Each cast has a real gameplay
## effect (damage, control, mobility, defence) plus its own visual and sound.

const Projectile := preload("res://src/combat/projectile.gd")
const Zone := preload("res://src/combat/zone.gd")


static func cast(p: Node, a: Dictionary, is_ult := false) -> bool:
	var kind: String = a.kind
	var col: Color = p.hero.color
	var tree: SceneTree = p.get_tree()
	var root: Node = p.get_parent()
	var aim: Vector3 = p.aim_direction()
	var target: Node3D = p.current_target
	match kind:
		"projectile":
			var count := int(a.get("count", 1))
			var spread := float(a.get("spread", 0.0))
			for i in count:
				var ang := 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
				var dir := aim.rotated(Vector3.UP, deg_to_rad(ang))
				Projectile.spawn(root, p.muzzle_position(), dir * float(a.get("speed", 22.0)), {
					"owner_node": p, "mult": float(a.dmg), "color": col, "explode": float(a.get("explode", 0.0)),
					"status": a.get("status", ""), "kind": "ability", "radius": 0.45 if a.get("explode", 0.0) > 0 else 0.3,
					"homing": target if count == 1 else null, "life": 2.0})
			p.play_action("cast", 0.4)
			Audio.play_at("energy_bolt" if a.get("status", "") != "stun" else "electric", p.global_position, -2.0)
		"shockwave":
			p.play_action("heavy" if kind == "shockwave" else "cast_up", 0.5)
			await tree.create_timer(0.22).timeout
			if not is_instance_valid(p):
				return false
			Fx.ring(p.global_position + Vector3.UP * 0.1, float(a.radius) * 1.1, col, 0.4)
			Fx.impact(p.global_position + Vector3.UP * 0.5, col, 1.4)
			Fx.add_shake(0.35)
			Audio.play_at("shockwave" if a.get("status", "") != "burn" else "fire_cast", p.global_position)
			for e in Combat.in_radius(tree, p.global_position, float(a.radius)):
				Combat.hit(p, e, float(a.dmg), {"kind": "ability", "knock": float(a.get("knock", 6.0)), "status": a.get("status", ""), "status_t": float(a.get("status_t", 1.0)), "color": col})
		"shield":
			p.add_shield(float(a.absorb), float(a.duration))
			p.play_action("block", 0.35)
			Audio.play_at("shield_up", p.global_position)
		"dash":
			p.dash(float(a.distance), 0.22, bool(a.get("phase", false)))
			Audio.play_at("dash" if a.get("status", "") != "stun" else "electric", p.global_position)
			var hit_set := {}
			var t := 0.0
			while t < 0.24:
				await tree.physics_frame
				if not is_instance_valid(p):
					return false
				t += p.get_physics_process_delta_time()
				for e in Combat.in_radius(tree, p.global_position, float(a.get("radius", 1.5))):
					if not hit_set.has(e):
						hit_set[e] = true
						Combat.hit(p, e, float(a.dmg) * 0.6, {"kind": "ability", "status": a.get("status", ""), "status_t": 1.0, "color": col, "knock": 3.0})
			if a.get("status", "") == "burn" or float(a.get("radius", 0)) >= 3.0:
				Fx.explosion(p.global_position + Vector3.UP * 0.5, float(a.radius) * 0.7, col)
				Audio.play_at("explosion", p.global_position, -3.0)
				for e in Combat.in_radius(tree, p.global_position, float(a.radius)):
					Combat.hit(p, e, float(a.dmg), {"kind": "ability", "status": a.get("status", ""), "status_t": 3.0, "color": col, "knock": 7.0})
		"teleport":
			var tgt: Node3D = target if target else Combat.best_target(tree, p.global_position, aim, float(a.distance) + 2.0, 160.0)
			Fx.smoke_puff(p.global_position + Vector3.UP, Color(0.15, 0.05, 0.25, 0.8), 1.4, 8)
			Audio.play_at("teleport", p.global_position)
			if tgt:
				var behind: Vector3 = tgt.global_position - tgt.global_transform.basis.z * (tgt.hit_radius + 1.0)
				p.teleport_to(behind, tgt.global_position)
				Combat.hit(p, tgt, float(a.dmg), {"kind": "ability", "color": col, "status": "stun", "status_t": 0.6})
			else:
				p.teleport_to(p.global_position + aim * float(a.distance), p.global_position + aim * (float(a.distance) + 1.0))
			Fx.smoke_puff(p.global_position + Vector3.UP, Color(0.15, 0.05, 0.25, 0.8), 1.4, 8)
			p.play_action("attack3", 0.4)
		"blades":
			p.play_action("attack3", 0.45)
			Audio.play_at("shadow_blades" if not a.get("pull", false) else "transform", p.global_position, -2.0)
			await tree.create_timer(0.15).timeout
			if not is_instance_valid(p):
				return false
			var fwd := aim
			Fx.ring(p.global_position + Vector3.UP * 1.0, float(a.radius), col, 0.3)
			for e in Combat.in_cone(tree, p.global_position, fwd, float(a.radius), float(a.angle)):
				Combat.hit(p, e, float(a.dmg), {"kind": "ability", "status": a.get("status", ""), "status_t": float(a.get("status_t", 3.0)), "color": col})
				if a.get("pull", false) and e.can_be_moved():
					e.external_push((p.global_position - e.global_position).normalized() * 14.0)
				Fx.hit_spark(e.global_position + Vector3.UP * e.aim_height, col, true)
		"invisibility":
			p.set_invisible(float(a.duration))
			Audio.play_at("invis", p.global_position)
			Fx.smoke_puff(p.global_position + Vector3.UP, Color(0.2, 0.05, 0.3, 0.7), 1.5, 10)
		"wall":
			var pos: Vector3 = p.global_position + aim * 3.0
			var z := Zone.spawn(root, pos, {"owner_node": p, "shape": "wall", "wall_length": float(a.length), "duration": float(a.duration),
				"mult": float(a.dmg), "status": a.get("status", ""), "status_t": 2.0, "color": col, "tick": 0.5})
			z.look_at(pos + aim, Vector3.UP)
			z.rotate_object_local(Vector3.UP, PI / 2)
			p.play_action("cast", 0.4)
			Audio.play_at("fire_cast" if a.get("status", "") == "burn" else "roots", pos)
		"taunt":
			for e in Combat.in_radius(tree, p.global_position, float(a.radius)):
				e.taunt(p, float(a.duration))
			p.add_temp_def(float(a.get("def_bonus", 5)), float(a.duration))
			Fx.ring(p.global_position + Vector3.UP * 0.2, float(a.radius), col, 0.6)
			p.play_action("pose", 0.6)
			Audio.play_at("shield_hit", p.global_position)
			Events.noise.emit(p.global_position, float(a.radius) * 2.0, p)
		"seismic":
			p.play_action("heavy", 0.5)
			await tree.create_timer(0.25).timeout
			if not is_instance_valid(p):
				return false
			var start: Vector3 = p.global_position
			var dir := aim
			var hit_set := {}
			var steps := int(float(a.length) / 1.5)
			Audio.play_at("colossus_slam", start, -4.0)
			Fx.add_shake(0.4)
			for i in steps:
				var at: Vector3 = start + dir * (1.5 * (i + 1))
				Fx.dig_debris(at, Color(0.5, 0.45, 0.4))
				Fx.hit_spark(at + Vector3.UP * 0.2, col)
				for e in Combat.in_radius(tree, at, float(a.width)):
					if not hit_set.has(e):
						hit_set[e] = true
						Combat.hit(p, e, float(a.dmg), {"kind": "ability", "status": a.get("status", ""), "status_t": float(a.get("status_t", 1.0)), "color": col, "knock": 4.0})
				await tree.create_timer(0.05).timeout
		"portal":
			if p.portal_point != Vector3.INF and p.global_position.distance_to(p.portal_point) <= float(a.range):
				Fx.smoke_puff(p.global_position + Vector3.UP, Color(0.6, 0.2, 0.7, 0.8), 1.3, 8)
				p.teleport_to(p.portal_point, p.portal_point + aim)
				p.clear_portal()
				Audio.play_at("teleport", p.global_position)
			else:
				p.place_portal(p.global_position)
				Audio.play_at("portal", p.global_position)
			p.play_action("cast", 0.3)
		"regen":
			p.heal_over_time(float(a.get("heal", 30)), float(a.duration))
			if a.has("energy"):
				p.energy = minf(p.max_energy, p.energy + float(a.energy))
			Audio.play_at("regen", p.global_position)
			Fx.heal_fx(p.global_position + Vector3.UP, col)
			p.play_action("cast_up", 0.5)
		"root":
			p.play_action("cast_up", 0.5)
			Audio.play_at("roots", p.global_position)
			Fx.ring(p.global_position + Vector3.UP * 0.1, float(a.radius), col, 0.5)
			for e in Combat.in_radius(tree, p.global_position, float(a.radius)):
				e.apply_status("root", float(a.duration))
				Combat.hit(p, e, float(a.get("dmg", 0.5)), {"kind": "ability", "color": col})
				Fx.dig_debris(e.global_position, Color(0.1, 0.06, 0.12))
		# ------------------------------------------------------------------ ultimates
		"gravity_storm":
			var at := _ult_point(p, target, aim, 6.0)
			Zone.spawn(root, at, {"owner_node": p, "radius": float(a.radius), "duration": float(a.duration), "mult": float(a.dmg),
				"pull": 5.0, "color": col, "tick": 0.35, "status": "slow", "status_t": 0.6})
			p.play_action("cast_up", 0.8)
			Audio.play_at("ult_cast", at)
			Fx.add_shake(0.5)
		"dark_domain":
			Zone.spawn(root, p.global_position, {"owner_node": p, "radius": float(a.radius), "duration": float(a.duration), "mult": float(a.dmg),
				"status": "mark", "status_t": 3.0, "color": col, "tick": 0.6, "hide_player": true})
			for e in Combat.in_radius(tree, p.global_position, float(a.radius)):
				e.apply_status("slow", float(a.duration))
			p.play_action("cast_up", 0.8)
			Audio.play_at("invis", p.global_position, 3.0)
			Audio.play_at("ult_cast", p.global_position, -4.0)
		"meteor":
			var at := _ult_point(p, target, aim, 9.0)
			Fx.ring(at + Vector3.UP * 0.1, float(a.radius), Color(1, 0.3, 0.1), float(a.delay))
			Audio.play_at("meteor", at, 2.0)
			p.play_action("cast_up", 0.8)
			await tree.create_timer(float(a.delay)).timeout
			if not is_instance_valid(p):
				return false
			Fx.explosion(at + Vector3.UP, float(a.radius) * 0.8, col)
			Fx.add_shake(1.0)
			for e in Combat.in_radius(tree, at, float(a.radius)):
				Combat.hit(p, e, float(a.dmg), {"kind": "ability", "status": "burn", "status_t": 5.0, "color": col, "knock": 12.0, "poise": 200.0})
			Zone.spawn(root, at, {"owner_node": p, "radius": float(a.radius) * 0.7, "duration": 4.0, "mult": 0.4, "status": "burn", "color": Color(1, 0.4, 0.1), "tick": 0.5})
		"fortress":
			Zone.spawn(root, p.global_position, {"owner_node": p, "radius": float(a.radius), "duration": float(a.duration), "mult": float(a.dmg),
				"pull": -9.0, "color": col, "tick": 0.6, "heal_player": 6.0})
			p.add_shield(80.0, float(a.duration))
			p.play_action("block", 0.6)
			Audio.play_at("shield_up", p.global_position, 4.0)
		"singularity":
			var at := _ult_point(p, target, aim, 8.0) + Vector3.UP * 1.2
			Zone.spawn(root, at, {"owner_node": p, "radius": float(a.radius), "duration": float(a.duration), "mult": float(a.dmg) * 0.3,
				"pull": 9.0, "color": col, "tick": 0.4, "explode_end": float(a.dmg) * 4.0})
			p.play_action("cast_up", 0.8)
			Audio.play_at("singularity", at, 2.0)
		"transform":
			p.start_transform(float(a.duration), float(a.mult))
			Audio.play_at("transform", p.global_position, 3.0)
			Fx.dissolve_burst(p.global_position + Vector3.UP, col, 1.6)
			Fx.add_shake(0.6)
		_:
			push_warning("Unknown ability kind " + kind)
			return false
	Events.noise.emit(p.global_position, 14.0, p)
	return true


static func _ult_point(p: Node, target: Node3D, aim: Vector3, dist: float) -> Vector3:
	if target and is_instance_valid(target) and target.global_position.distance_to(p.global_position) < 20.0:
		return target.global_position
	return p.global_position + aim * dist
