extends Node
## Central game state: the player profile and every rule that reads or changes it.
## Gameplay systems call these functions; nothing else writes into `profile`.

const SLOT := 0
const AUTOSAVE_INTERVAL := 60.0
const BASE_CAPACITY := 300
const MAX_HERO_LEVEL := 30
const MAX_PLAYER_LEVEL := 40

var profile: Dictionary = {}
var current_region := "city"
var spawn_gate := ""            # gate id to spawn at after a region change ("" = saved position)
var session_flags := {}         # per-run flags (not saved)
var _autosave_t := 0.0
var loaded := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.mission_event.connect(_on_mission_event)


# ------------------------------------------------------------------------------------------
# Profile lifecycle
# ------------------------------------------------------------------------------------------

func new_profile() -> Dictionary:
	var heroes := {}
	for id in DB.HEROES:
		heroes[id] = {"owned": DB.HEROES[id].unlock.type == "start", "level": 1, "xp": 0, "rank": 1,
			"skill_points": 0, "skills": [], "skin": "default", "fragments": 0,
			"equipment": {"arme": "", "armure": "", "gadget": ""}}
	var res := {}
	for r in DB.RESOURCES:
		res[r] = 0
	res.metal = 12
	res.materials = 12
	res.crystal = 4
	var missions := {}
	for id in DB.MISSIONS:
		missions[id] = {"status": "locked", "progress": []}
	missions["m01_first_steps"].status = "available"
	for id in ["r01_hunt"]:
		missions[id].status = "available"
	return {
		"version": Save.VERSION,
		"created": Time.get_unix_time_from_system(),
		"play_time": 0.0,
		"player": {"level": 1, "xp": 0, "region": "city", "pos": [], "hp": -1.0},
		"active_hero": "vortex",
		"heroes": heroes,
		"resources": res,
		"items": {"flare": 2, "medkit": 2, "decoy": 1},
		"equipment_owned": [],
		"base": {"level": 1, "buildings": [], "cells": {}, "next_id": 1, "failures": [], "creatures": [], "raid_timer": 420.0},
		"research": {"done": [], "current": "", "progress": 0.0},
		"missions": missions,
		"active_mission": "m01_first_steps",
		"codex": {},
		"logs": [],
		"regions_seen": ["city"],
		"opened": [],            # world containers already looted (ids)
		"stats": {"kills": 0, "deaths": 0, "dug": 0, "built": 0, "escapes": 0, "captures": 0, "time_hidden": 0.0},
		"flags": {},
	}


func start_new_game() -> void:
	profile = new_profile()
	current_region = "city"
	spawn_gate = "start"
	loaded = true
	save_game()


func load_game() -> bool:
	var data := Save.read(SLOT)
	if data.is_empty():
		return false
	profile = _merge_defaults(new_profile(), data)
	current_region = profile.player.get("region", "city")
	spawn_gate = ""
	loaded = true
	return true


func _merge_defaults(defaults: Dictionary, data: Dictionary) -> Dictionary:
	## Adds keys introduced by newer content (new heroes, missions, resources) without touching saved values.
	for k in defaults:
		if not data.has(k):
			data[k] = defaults[k]
		elif typeof(defaults[k]) == TYPE_DICTIONARY and typeof(data[k]) == TYPE_DICTIONARY and k in ["heroes", "missions", "resources", "stats", "player", "base", "research"]:
			for sub in defaults[k]:
				if not data[k].has(sub):
					data[k][sub] = defaults[k][sub]
	return data


func save_game() -> bool:
	if profile.is_empty():
		return false
	return Save.write(SLOT, profile)


func _process(delta: float) -> void:
	if not loaded or get_tree().paused:
		return
	profile.play_time += delta
	_tick_research(delta)
	_tick_containment(delta)
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		var w := get_tree().get_first_node_in_group("world")
		if w and w.has_method("store_player_state"):
			w.store_player_state()
		save_game()


# ------------------------------------------------------------------------------------------
# Resources & items
# ------------------------------------------------------------------------------------------

func capacity() -> int:
	return BASE_CAPACITY + 150 * building_level_sum("storage")


func res(id: String) -> int:
	return int(profile.resources.get(id, 0))


func add_res(id: String, n: int, silent := false) -> int:
	if n == 0 or not DB.RESOURCES.has(id):
		return 0
	var before := res(id)
	var after := clampi(before + n, 0, capacity())
	profile.resources[id] = after
	var gained := after - before
	if gained > 0:
		Events.mission_event.emit("collect", id, gained)
		if not silent:
			Events.toast.emit("+%d %s" % [gained, DB.RESOURCES[id].name], "res:" + id)
	elif n > 0 and gained == 0 and not silent:
		Events.toast.emit("Stockage plein : %s" % DB.RESOURCES[id].name, "warn")
	Events.resources_changed.emit()
	return gained


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if DB.RESOURCES.has(k) and res(k) < int(cost[k]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		if DB.RESOURCES.has(k):
			profile.resources[k] = res(k) - int(cost[k])
	Events.resources_changed.emit()
	return true


func item_count(id: String) -> int:
	return int(profile.items.get(id, 0))


func item_max(id: String) -> int:
	return int(DB.ITEMS[id].max) + building_level_sum("armory")


func add_item(id: String, n := 1) -> int:
	var before := item_count(id)
	profile.items[id] = clampi(before + n, 0, item_max(id))
	Events.items_changed.emit()
	return profile.items[id] - before


func consume_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	profile.items[id] = item_count(id) - 1
	Events.items_changed.emit()
	return true


func roll_drops(drops: Dictionary, mult := 1.0) -> Dictionary:
	var out := {}
	for k in drops:
		var r: Array = drops[k]
		var n := int(round(randi_range(int(r[0]), int(r[1])) * mult))
		if n > 0:
			out[k] = n
	return out


# ------------------------------------------------------------------------------------------
# Player & hero progression
# ------------------------------------------------------------------------------------------

func player_level() -> int:
	return int(profile.player.level)


func xp_to_next(level: int) -> int:
	return int(200.0 * pow(level, 1.4))


func add_xp(n: int) -> void:
	if n <= 0:
		return
	var p: Dictionary = profile.player
	p.xp += n
	Events.xp_gained.emit(n)
	while p.level < MAX_PLAYER_LEVEL and p.xp >= xp_to_next(p.level):
		p.xp -= xp_to_next(p.level)
		p.level += 1
		Events.player_level_up.emit(p.level)
		Events.toast.emit("Niveau %d atteint !" % p.level, "level")
	add_hero_xp(profile.active_hero, int(n * 0.8))


func hero_state(id: String) -> Dictionary:
	return profile.heroes.get(id, {})


func hero_owned(id: String) -> bool:
	return bool(hero_state(id).get("owned", false))


func hero_xp_to_next(level: int) -> int:
	return int(100.0 * pow(level, 1.5))


func add_hero_xp(id: String, n: int) -> void:
	var h := hero_state(id)
	if h.is_empty() or not h.owned:
		return
	h.xp += n
	while h.level < MAX_HERO_LEVEL and h.xp >= hero_xp_to_next(h.level):
		h.xp -= hero_xp_to_next(h.level)
		h.level += 1
		h.skill_points += 1
		Events.hero_level_up.emit(id, h.level)
		Events.toast.emit("%s passe niveau %d (+1 point de compétence)" % [DB.HEROES[id].name, h.level], "level")


func unlock_hero(id: String) -> void:
	var h := hero_state(id)
	if h.is_empty() or h.owned:
		return
	h.owned = true
	Events.hero_unlocked.emit(id)
	Events.toast.emit("Nouveau héros recruté : %s !" % DB.HEROES[id].name, "hero")


func add_fragments(id: String, n: int) -> void:
	var h := hero_state(id)
	if h.is_empty():
		return
	h.fragments += n
	var need := int(DB.HEROES[id].unlock.get("value", 30)) if DB.HEROES[id].unlock.type == "fragments" else 30
	if not h.owned and h.fragments >= need:
		unlock_hero(id)


func rank_cost(id: String) -> Dictionary:
	var r := int(hero_state(id).rank)
	return {"samples": 4 * r, "crystal": 5 * r, "alloy": max(0, r - 1)}


func can_rank_up(id: String) -> bool:
	var h := hero_state(id)
	return h.owned and h.rank < 5 and h.level >= h.rank * 5 and can_afford(rank_cost(id))


func rank_up(id: String) -> bool:
	if not can_rank_up(id):
		return false
	spend(rank_cost(id))
	hero_state(id).rank += 1
	Events.toast.emit("%s : rang %d !" % [DB.HEROES[id].name, hero_state(id).rank], "hero")
	return true


func can_learn(id: String, skill_id: String) -> bool:
	var h := hero_state(id)
	if h.is_empty() or not h.owned or h.skill_points <= 0 or skill_id in h.skills:
		return false
	for s in DB.SKILLS:
		if s.id == skill_id:
			if s.tier == 1:
				return true
			for s2 in DB.SKILLS:
				if s2.branch == s.branch and s2.tier == s.tier - 1:
					return s2.id in h.skills
	return false


func learn(id: String, skill_id: String) -> bool:
	if not can_learn(id, skill_id):
		return false
	var h := hero_state(id)
	h.skills.append(skill_id)
	h.skill_points -= 1
	return true


func equip(id: String, equipment_id: String) -> void:
	var slot: String = DB.EQUIPMENT[equipment_id].slot
	var h := hero_state(id)
	h.equipment[slot] = "" if h.equipment.get(slot, "") == equipment_id else equipment_id


func hero_stats(id: String) -> Dictionary:
	## Final stats after level, rank, skills, equipment, base and research bonuses.
	var d: Dictionary = DB.HEROES[id]
	var h := hero_state(id)
	var lvl := int(h.get("level", 1))
	var rank := int(h.get("rank", 1))
	var mods := {"atk_mult": 0.0, "crit": 0.05, "finisher_mult": 0.0, "execute_threshold": 0.15, "hp_flat": 0, "def_flat": 0,
		"perfect_window": 0.0, "second_wind": 0, "energy_flat": 0, "cdr": 0.0, "ability_mult": 0.0, "ult_gain": 0.0,
		"noise_mult": 0.0, "energy_regen": 0.0, "spore_immune": 0, "threat_radar": 0, "heavy_stun": 0}
	for sid in h.get("skills", []):
		for s in DB.SKILLS:
			if s.id == sid:
				for k in s.mods:
					mods[k] = mods.get(k, 0) + s.mods[k]
	for slot in h.get("equipment", {}):
		var eid: String = h.equipment[slot]
		if eid != "" and DB.EQUIPMENT.has(eid):
			for k in DB.EQUIPMENT[eid].mods:
				mods[k] = mods.get(k, 0) + DB.EQUIPMENT[eid].mods[k]
	var lvl_mult := 1.0 + 0.06 * (lvl - 1)
	var rank_mult := 1.0 + 0.08 * (rank - 1)
	var infirmary := 1.0 + 0.05 * building_level_sum("infirmary")
	var s: Dictionary = d.stats
	var out := {
		"hp": (s.hp * lvl_mult * rank_mult + mods.hp_flat) * infirmary,
		"energy": s.energy + mods.energy_flat,
		"atk": s.atk * (1.0 + 0.07 * (lvl - 1)) * rank_mult * (1.0 + mods.atk_mult),
		"def": s.def + mods.def_flat + int(lvl / 5),
		"speed": s.speed,
	}
	out.merge(mods)
	return out


func family_damage_bonus(family: String) -> float:
	## Symbiote mastery: each codex tier reached for a family grants +5 % damage against it.
	var tier := mastery_tier(family)
	var bonus := 0.05 * tier
	if has_research("symbiote_dna") and tier > 0:
		bonus += 0.10
	return bonus


# ------------------------------------------------------------------------------------------
# Codex & mastery
# ------------------------------------------------------------------------------------------

func codex_entry(enemy_id: String) -> Dictionary:
	if not profile.codex.has(enemy_id):
		profile.codex[enemy_id] = {"seen": false, "kills": 0, "studied": 0}
	return profile.codex[enemy_id]


func codex_seen(enemy_id: String) -> void:
	var e := codex_entry(enemy_id)
	if not e.seen:
		e.seen = true
		Events.codex_updated.emit(enemy_id)
		Events.toast.emit("Codex : %s découvert" % DB.ENEMIES[enemy_id].name, "codex")


func family_kills(family: String) -> int:
	var n := 0
	for id in profile.codex:
		if DB.ENEMIES.has(id) and DB.ENEMIES[id].family == family:
			n += int(profile.codex[id].kills) + 3 * int(profile.codex[id].studied)
	return n


func mastery_tier(family: String) -> int:
	if not DB.FAMILIES.has(family):
		return 0
	var k := family_kills(family)
	var t := 0
	for th in DB.FAMILIES[family].tiers:
		if k >= th:
			t += 1
	return t


func _on_enemy_killed(_enemy: Node, enemy_id: String, family: String) -> void:
	if profile.is_empty():
		return
	var before := mastery_tier(family)
	codex_entry(enemy_id).kills += 1
	profile.stats.kills += 1
	var after := mastery_tier(family)
	if after > before:
		Events.toast.emit("Maîtrise %s : niveau %d (+5 %% dégâts)" % [DB.FAMILIES[family].name, after], "codex")
	Events.mission_event.emit("kill", enemy_id, 1)
	Events.mission_event.emit("kill", family, 1)
	Events.mission_event.emit("kill", "any", 1)
	if profile.stats.kills >= 200 and not hero_owned("sylve"):
		unlock_hero("sylve")


# ------------------------------------------------------------------------------------------
# Missions
# ------------------------------------------------------------------------------------------

func mission_state(id: String) -> Dictionary:
	return profile.missions.get(id, {})


func available_missions() -> Array:
	var out: Array = []
	for id in DB.MISSIONS:
		var st := mission_state(id)
		if st.get("status", "locked") in ["available", "active"]:
			out.append(id)
	return out


func start_mission(id: String) -> void:
	var st := mission_state(id)
	if st.is_empty() or st.status == "done" and DB.MISSIONS[id].type != "repeat":
		return
	if profile.active_mission != "" and profile.active_mission != id:
		var prev := mission_state(profile.active_mission)
		if prev.status == "active":
			prev.status = "available"
	st.status = "active"
	var objs: Array = DB.MISSIONS[id].objectives
	if st.progress.size() != objs.size():
		st.progress = []
		for o in objs:
			st.progress.append(0)
	profile.active_mission = id
	Events.mission_updated.emit(id)
	# Some objectives are already satisfied by the current state (e.g. a building that already exists).
	for i in objs.size():
		var o: Dictionary = objs[i]
		if o.type == "build":
			st.progress[i] = mini(int(o.count), count_buildings(o.target))
	_check_mission_done(id)


func active_mission_id() -> String:
	return profile.get("active_mission", "")


func current_objective(id := "") -> Dictionary:
	if id == "":
		id = active_mission_id()
	if id == "" or not DB.MISSIONS.has(id):
		return {}
	var st := mission_state(id)
	var objs: Array = DB.MISSIONS[id].objectives
	for i in objs.size():
		if i >= st.progress.size() or int(st.progress[i]) < int(objs[i].count):
			var o: Dictionary = objs[i].duplicate()
			o["index"] = i
			o["done"] = int(st.progress[i]) if i < st.progress.size() else 0
			return o
	return {}


func _on_mission_event(kind: String, target: String, amount: int) -> void:
	if profile.is_empty():
		return
	var id := active_mission_id()
	if id == "" or mission_state(id).get("status", "") != "active":
		return
	var cur := current_objective(id)
	if cur.is_empty():
		return
	# Objectives are sequential: only the current one advances.
	var matches: bool = cur.type == kind and (cur.target == "" or cur.target == target)
	if kind == "collect_log" and cur.type == "collect_log":
		matches = true
	if not matches:
		return
	var st := mission_state(id)
	var i: int = cur.index
	st.progress[i] = mini(int(cur.count), int(st.progress[i]) + amount)
	Events.mission_updated.emit(id)
	if int(st.progress[i]) >= int(cur.count):
		var nxt := current_objective(id)
		if not nxt.is_empty():
			Events.toast.emit("Objectif : " + nxt.text, "objective")
			if nxt.type == "build":
				st.progress[nxt.index] = mini(int(nxt.count), count_buildings(nxt.target))
	_check_mission_done(id)


func set_objective_progress(kind: String, value: int) -> void:
	## For timer objectives (survive): sets absolute progress.
	var cur := current_objective()
	if cur.is_empty() or cur.type != kind:
		return
	var st := mission_state(active_mission_id())
	st.progress[cur.index] = mini(int(cur.count), value)
	Events.mission_updated.emit(active_mission_id())
	_check_mission_done(active_mission_id())


func _check_mission_done(id: String) -> void:
	if not current_objective(id).is_empty():
		return
	var st := mission_state(id)
	if st.status != "active":
		return
	var m: Dictionary = DB.MISSIONS[id]
	st.status = "done" if m.type != "repeat" else "available"
	st.progress = []
	if m.type == "repeat":
		st["completions"] = int(st.get("completions", 0)) + 1
	profile.active_mission = ""
	var rw: Dictionary = m.rewards
	for k in rw:
		if k == "xp":
			add_xp(int(rw.xp))
		elif k == "hero":
			unlock_hero(rw.hero)
		elif k.begins_with("fragments_"):
			add_fragments(k.substr(10), int(rw[k]))
		elif DB.RESOURCES.has(k):
			add_res(k, int(rw[k]), true)
	for n in m.get("next", []):
		if mission_state(n).get("status", "") == "locked":
			mission_state(n).status = "available"
	# Unlock repeatable missions as the story progresses.
	if id == "m02_supplies":
		for r in ["r03_capture"]:
			mission_state(r).status = "available"
	if id == "m01_first_steps":
		mission_state("r02_defend").status = "available"
	if id == "m06_devourer":
		mission_state("r04_depths").status = "available"
	Events.mission_completed.emit(id)
	Events.toast.emit("Mission accomplie : %s" % m.title, "mission")
	# Chain straight into the next main mission.
	for n in m.get("next", []):
		if DB.MISSIONS[n].type == "main":
			start_mission(n)
			break
	save_game()


func region_unlocked(id: String) -> bool:
	var r: Dictionary = DB.REGIONS[id]
	if player_level() < int(r.min_level):
		return false
	if r.has("requires") and mission_state(r.requires).get("status", "") != "done":
		# The region that hosts the active mission is always reachable.
		var am := active_mission_id()
		if am == "" or DB.MISSIONS[am].region != id:
			return false
	return true


func region_lock_reason(id: String) -> String:
	var r: Dictionary = DB.REGIONS[id]
	if player_level() < int(r.min_level):
		return "Niveau %d requis" % int(r.min_level)
	if r.has("requires") and not region_unlocked(id):
		return "Mission requise : %s" % DB.MISSIONS[r.requires].title
	return ""


# ------------------------------------------------------------------------------------------
# Base
# ------------------------------------------------------------------------------------------

func buildings() -> Array:
	return profile.base.buildings


func count_buildings(type: String) -> int:
	var n := 0
	for b in buildings():
		if b.type == type:
			n += 1
	return n


func building_level_sum(type: String) -> int:
	if profile.is_empty():
		return 0
	var n := 0
	for b in buildings():
		if b.type == type and b.get("powered", true):
			n += int(b.level)
	return n


func has_building(type: String) -> bool:
	return count_buildings(type) > 0


func base_level() -> int:
	for b in buildings():
		if b.type == "command":
			return int(b.level)
	return 0


func power_balance() -> Vector2i:
	## x = produced, y = consumed (by buildings that are switched on)
	var prod := 0
	var use := 0
	for b in buildings():
		var p := int(DB.BUILDINGS[b.type].power)
		if p > 0:
			if not b.get("broken", false):
				prod += p + (int(b.level) - 1) * 3 + (2 if has_research("overcharge") else 0)
		else:
			use += -p
	return Vector2i(prod, use)


func building_lock_reason(type: String) -> String:
	var d: Dictionary = DB.BUILDINGS[type]
	if d.get("unique", false) and has_building(type):
		return "Déjà construit"
	if type != "command" and not has_building("command") and type != "generator":
		return "Nécessite un centre de commandement"
	if d.has("requires_base") and base_level() < int(d.requires_base):
		return "Centre de commandement niveau %d requis" % int(d.requires_base)
	if d.has("requires_research") and not has_research(d.requires_research):
		return "Recherche requise : %s" % DB.RESEARCH[d.requires_research].name
	return ""


func has_research(id: String) -> bool:
	return not profile.is_empty() and id in profile.research.done


func research_available(id: String) -> bool:
	if has_research(id):
		return false
	for r in DB.RESEARCH[id].requires:
		if not has_research(r):
			return false
	return true


func research_time(id: String) -> float:
	return 45.0 + 15.0 * DB.RESEARCH[id].requires.size()


func start_research(id: String) -> bool:
	if not research_available(id) or profile.research.current != "" or not has_building("lab"):
		return false
	if not spend(DB.RESEARCH[id].cost):
		return false
	profile.research.current = id
	profile.research.progress = 0.0
	Events.mission_event.emit("research", id, 0)
	return true


func _tick_research(delta: float) -> void:
	var r: Dictionary = profile.research
	if r.get("current", "") == "":
		return
	var lab := building_level_sum("lab")
	if lab <= 0 or not base_powered():
		return
	r.progress += delta * (1.0 + 0.5 * (lab - 1))
	if r.progress >= research_time(r.current):
		var id: String = r.current
		r.done.append(id)
		r.current = ""
		r.progress = 0.0
		Events.research_completed.emit(id)
		Events.toast.emit("Recherche terminée : %s" % DB.RESEARCH[id].name, "research")
		Events.mission_event.emit("research", id, 1)


func base_powered() -> bool:
	var p := power_balance()
	return p.x >= p.y and p.x > 0


func _tick_containment(delta: float) -> void:
	var creatures: Array = profile.base.get("creatures", [])
	if creatures.is_empty() or building_level_sum("containment") <= 0:
		return
	profile.base["sample_t"] = float(profile.base.get("sample_t", 0.0)) + delta * creatures.size()
	if profile.base.sample_t >= 90.0:
		profile.base.sample_t = 0.0
		add_res("samples", 1, true)
