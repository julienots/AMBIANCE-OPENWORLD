extends CanvasLayer
## Full in-game menu: missions, heroes (3D showcase, stats, skills, rank, equipment,
## skins, recruitment), inventory, base (build / reinforce / power), research, codex,
## travel map, options, and the panels of each base installation.

var _root: Control
var _tabs: VBoxContainer
var _content: VBoxContainer
var _title: Label
var _tab := "missions"
var _at_refuge := false
var _building: Node
var _sel_hero := ""
var _preview: HeroPreview

const TABS := [["missions", "Missions", "map"], ["heroes", "Héros", "attack"], ["inventory", "Inventaire", "medkit"],
	["base", "Base", "build"], ["research", "Recherche", "portal"], ["codex", "Codex", "invisibility"],
	["travel", "Carte", "map"], ["options", "Options", "cycle"]]


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var h := UiKit.hbox(16)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_top = 16
	h.offset_right = -20
	h.offset_bottom = -16
	_root.add_child(h)
	var side := UiKit.vbox(8)
	side.custom_minimum_size = Vector2(230, 0)
	h.add_child(side)
	var logo := UiKit.title("SYMBIOTE", 30)
	side.add_child(logo)
	_tabs = UiKit.vbox(6)
	side.add_child(UiKit.scroll(_tabs))
	side.add_child(UiKit.button("▶  Reprendre", close, 60))
	var main := UiKit.vbox(10)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(main)
	_title = UiKit.title("", 34)
	main.add_child(_title)
	_content = UiKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_content)
	Events.resources_changed.connect(func(): if visible and _tab in ["base", "research", "inventory", "building"]: _refresh())


func open(tab: String, at_refuge: bool) -> void:
	_at_refuge = at_refuge or Game.current_region == "base"
	_tab = tab if tab != "refuge" else "missions"
	if tab == "refuge":
		_tab = "heroes"
	visible = true
	get_tree().paused = true
	Pad.clear()
	_build_tabs()
	_refresh()
	Audio.play("ui_confirm", -8.0)


func open_building(b: Node) -> void:
	_building = b
	open("building", Game.current_region == "base")


func close() -> void:
	visible = false
	get_tree().paused = false
	_building = null
	Game.save_game()
	Pad.clear()


func _build_tabs() -> void:
	UiKit.clear(_tabs)
	if _at_refuge and Game.current_region != "base":
		_tabs.add_child(UiKit.button("⬇  Descendre à la base", func(): close(); _store(); Loader.goto_world("base", "from_city"), 56))
	for t in TABS:
		var b := UiKit.button("  " + t[1], _switch.bind(t[0]), 52)
		b.icon = load("res://assets/icons/%s.png" % t[2])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if t[0] == _tab:
			b.add_theme_color_override("font_color", UiKit.ACCENT)
		_tabs.add_child(b)
	_tabs.add_child(UiKit.button("  Menu principal", func(): close(); _store(); Game.save_game(); Loader.goto_menu(), 52))


func _store() -> void:
	var w := get_tree().get_first_node_in_group("world")
	if w:
		w.store_player_state()


func _switch(t: String) -> void:
	_tab = t
	_building = null
	_build_tabs()
	_refresh()


func _refresh() -> void:
	UiKit.clear(_content)
	_preview = null
	match _tab:
		"missions": _missions()
		"heroes": _heroes()
		"inventory": _inventory()
		"base": _base()
		"research": _research()
		"codex": _codex()
		"travel": _travel()
		"options": _options()
		"building": _building_panel()


# ------------------------------------------------------------------------------ missions

func _missions() -> void:
	_title.text = "Missions"
	var v := UiKit.vbox(12)
	_content.add_child(UiKit.scroll(v))
	var am := Game.active_mission_id()
	if am != "":
		var m: Dictionary = DB.MISSIONS[am]
		var p := UiKit.panel(Vector2.ZERO, Color(0.12, 0.1, 0.04, 0.95), UiKit.ACCENT)
		var pv := UiKit.vbox(6)
		p.add_child(pv)
		pv.add_child(UiKit.title("EN COURS : " + m.title, 24))
		pv.add_child(UiKit.text(m.desc, 17))
		var st := Game.mission_state(am)
		for i in m.objectives.size():
			var o: Dictionary = m.objectives[i]
			var done := int(st.progress[i]) if i < st.progress.size() else 0
			var ok := done >= int(o.count)
			pv.add_child(UiKit.text(("✔ " if ok else "○ ") + "%s  (%d/%d)" % [o.text, done, o.count], 17, Color(0.5, 1, 0.6) if ok else Color(0.9, 0.9, 0.95)))
		pv.add_child(UiKit.text("Région : " + DB.REGIONS[m.region].name + "   ·   Récompenses : " + _rewards_text(m.rewards), 15, Color(0.75, 0.72, 0.6)))
		v.add_child(p)
	v.add_child(UiKit.title("Disponibles", 22, Color.WHITE))
	for id in DB.MISSIONS:
		var st := Game.mission_state(id)
		if st.get("status", "") != "available" or id == am:
			continue
		var m: Dictionary = DB.MISSIONS[id]
		var row := UiKit.panel()
		var h := UiKit.hbox()
		row.add_child(h)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind = {"main": "Histoire", "side": "Secondaire", "repeat": "Rejouable"}[m.type]
		info.add_child(UiKit.title("%s  · %s" % [m.title, kind], 20, Color.WHITE if m.type == "main" else Color(0.7, 0.85, 1.0)))
		info.add_child(UiKit.text(m.desc, 15))
		info.add_child(UiKit.text(DB.REGIONS[m.region].name + "  ·  " + _rewards_text(m.rewards), 14, Color(0.7, 0.68, 0.6)))
		h.add_child(info)
		h.add_child(UiKit.button("Suivre", func(): Game.start_mission(id); _refresh(), 52))
		v.add_child(row)
	var done := []
	for id in DB.MISSIONS:
		if Game.mission_state(id).get("status", "") == "done":
			done.append(DB.MISSIONS[id].title)
	if not done.is_empty():
		v.add_child(UiKit.text("Terminées : " + ", ".join(done), 15, Color(0.55, 0.8, 0.6)))


func _rewards_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in r:
		if k == "xp":
			parts.append("%d XP" % r.xp)
		elif k == "hero":
			parts.append("Héros : " + DB.HEROES[r.hero].name)
		elif k.begins_with("fragments_"):
			parts.append("%d fragments de %s" % [r[k], DB.HEROES[k.substr(10)].name])
		elif DB.RESOURCES.has(k):
			parts.append("%s %d" % [DB.RESOURCES[k].icon, r[k]])
	return ", ".join(parts)


# ------------------------------------------------------------------------------ heroes

func _heroes() -> void:
	_title.text = "Collection de héros"
	if _sel_hero == "":
		_sel_hero = Game.profile.active_hero
	var h := UiKit.hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(h)
	# Card list
	var list := UiKit.vbox(6)
	list.custom_minimum_size = Vector2(250, 0)
	var ids := DB.HEROES.keys()
	ids.sort_custom(func(a, b): return DB.RARITIES[DB.HEROES[a].rarity].order < DB.RARITIES[DB.HEROES[b].rarity].order)
	for id in ids:
		var d: Dictionary = DB.HEROES[id]
		var owned := Game.hero_owned(id)
		var b := UiKit.button(("" if owned else "🔒 ") + d.name + ("  ★" if id == Game.profile.active_hero else ""), func(): _sel_hero = id; _refresh(), 50)
		var rc := DB.rarity_color(d.rarity)
		var sb := UiKit._sb(Color(rc.r * 0.25, rc.g * 0.25, rc.b * 0.25, 0.95) if owned else Color(0.08, 0.08, 0.1), rc if id == _sel_hero else rc * Color(1, 1, 1, 0.4))
		b.add_theme_stylebox_override("normal", sb)
		list.add_child(b)
	var ls := UiKit.scroll(list)
	ls.custom_minimum_size = Vector2(260, 0)
	ls.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(ls)
	var d: Dictionary = DB.HEROES[_sel_hero]
	var st := Game.hero_state(_sel_hero)
	_preview = HeroPreview.new(Vector2(330, 470))
	h.add_child(_preview)
	_preview.show_model(d.model, d.color)
	var info := UiKit.vbox(8)
	h.add_child(UiKit.scroll(info))
	var rc := DB.rarity_color(d.rarity)
	info.add_child(UiKit.title(d.name, 38, d.color.lightened(0.3)))
	info.add_child(UiKit.text("%s  ·  %s  ·  %s" % [d.title, DB.RARITIES[d.rarity].name, d.role], 17, rc))
	if st.owned:
		info.add_child(UiKit.text("Niveau %d  (%d/%d XP)   ·   Rang %s   ·   Points de compétence : %d" % [st.level, st.xp, Game.hero_xp_to_next(st.level), "★".repeat(int(st.rank)), st.skill_points], 16, Color(1, 0.9, 0.6)))
	else:
		info.add_child(UiKit.text("Non recruté — " + _unlock_text(_sel_hero), 16, Color(1, 0.55, 0.45)))
	var stats := Game.hero_stats(_sel_hero)
	info.add_child(UiKit.text("PV %d   ·   Énergie %d   ·   Attaque %d   ·   Défense %d   ·   Vitesse %.1f" % [stats.hp, stats.energy, stats.atk, stats.def, stats.speed], 16))
	info.add_child(UiKit.text(d.story, 15, Color(0.75, 0.75, 0.82)))
	info.add_child(UiKit.title("Pouvoirs", 20, Color.WHITE))
	info.add_child(_ability_row(d.primary.kind if d.primary.kind != "melee" else "attack", d.primary.name, "Attaque principale"))
	for a in d.abilities:
		info.add_child(_ability_row(a.kind, a.name, "%s  (énergie %d, recharge %ds)" % [a.desc, a.cost, a.cd]))
	info.add_child(_ability_row(d.ultimate.kind, "ULTIME : " + d.ultimate.name, d.ultimate.desc))
	info.add_child(_ability_row("regen", "Passif : " + d.passive.name, d.passive.desc))
	if st.owned:
		var row := UiKit.hbox()
		if _sel_hero != Game.profile.active_hero:
			var can_switch := _at_refuge
			row.add_child(UiKit.button("Jouer ce héros" if can_switch else "Changer au refuge / base", func(): _set_active(_sel_hero), 54, can_switch))
		var rcost := Game.rank_cost(_sel_hero)
		var rb := UiKit.button("Rang supérieur (niv. %d requis)" % (int(st.rank) * 5), func(): Game.rank_up(_sel_hero); _refresh(), 54, Game.can_rank_up(_sel_hero))
		row.add_child(rb)
		row.add_child(UiKit.cost_label(rcost))
		info.add_child(row)
		info.add_child(UiKit.title("Arbre de compétences", 20, Color.WHITE))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for tier in range(1, 5):
			for branch in ["Puissance", "Survie", "Pouvoirs"]:
				for s in DB.SKILLS:
					if s.branch == branch and s.tier == tier:
						var learned: bool = s.id in st.skills
						var b := UiKit.button(("✔ " if learned else "") + s.name + "\n" + s.desc, func(): Game.learn(_sel_hero, s.id); _refresh(), 64, Game.can_learn(_sel_hero, s.id) or learned)
						b.custom_minimum_size = Vector2(230, 64)
						b.add_theme_font_size_override("font_size", 15)
						if learned:
							b.add_theme_stylebox_override("normal", UiKit._sb(Color(0.15, 0.3, 0.15), Color(0.4, 1, 0.5)))
						grid.add_child(b)
		info.add_child(grid)
		info.add_child(UiKit.title("Équipement", 20, Color.WHITE))
		for slot in ["arme", "armure", "gadget"]:
			var eq: String = st.equipment.get(slot, "")
			var row2 := UiKit.hbox()
			row2.add_child(UiKit.text("%s : %s" % [slot.capitalize(), DB.EQUIPMENT[eq].name if eq != "" else "—"], 16))
			for owned_eq in Game.profile.equipment_owned:
				if DB.EQUIPMENT[owned_eq].slot == slot:
					row2.add_child(UiKit.button(("Retirer " if eq == owned_eq else "Équiper ") + DB.EQUIPMENT[owned_eq].name, func(): Game.equip(_sel_hero, owned_eq); _apply_player_stats(); _refresh(), 46))
			info.add_child(row2)
		info.add_child(UiKit.title("Apparences", 20, Color.WHITE))
		var srow := UiKit.hbox()
		for sk in [["default", "Classique", 1], ["eclipse", "Éclipse", 3], ["prisme", "Prisme", 5]]:
			var unlocked := int(st.rank) >= int(sk[2])
			srow.add_child(UiKit.button(("✔ " if st.skin == sk[0] else "") + sk[1] + ("" if unlocked else " (rang %d)" % sk[2]), func(): st.skin = sk[0]; _apply_player_stats(); _refresh(), 46, unlocked))
		info.add_child(srow)
	info.add_child(UiKit.title("Signal de recrutement", 20, Color.WHITE))
	info.add_child(UiKit.text("Optionnel : 6 données scientifiques pour capter un signal de héros (fragments aléatoires). Tous les héros s'obtiennent aussi par les missions et défis.", 14, Color(0.7, 0.7, 0.78)))
	info.add_child(UiKit.button("Scanner un signal (données 6)", _recruit_signal, 50, Game.res("data") >= 6))


func _ability_row(icon_name: String, name: String, desc: String) -> Control:
	var h := UiKit.hbox(10)
	var ic := UiKit.icon(icon_name if ResourceLoader.exists("res://assets/icons/%s.png" % icon_name) else "attack", 36, DB.HEROES[_sel_hero].color)
	h.add_child(ic)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.text(name, 17, Color.WHITE))
	v.add_child(UiKit.text(desc, 14, Color(0.72, 0.72, 0.8)))
	h.add_child(v)
	return h


func _unlock_text(id: String) -> String:
	var u: Dictionary = DB.HEROES[id].unlock
	match u.type:
		"mission": return "terminer « %s »" % DB.MISSIONS[u.value].title
		"fragments": return "réunir %d fragments (%d/%d)" % [u.value, Game.hero_state(id).fragments, u.value]
		"challenge": return "éliminer 200 symbiotes (%d/200)" % Game.profile.stats.kills
	return ""


func _recruit_signal() -> void:
	if not Game.spend({"data": 6}):
		return
	var pool := []
	for id in DB.HEROES:
		if not Game.hero_owned(id):
			pool.append(id)
	if pool.is_empty():
		Game.add_res("crystal", 6)
		Events.toast.emit("Tous les héros sont recrutés : +6 cristaux", "objective")
	else:
		var id: String = pool.pick_random()
		var n := randi_range(3, 8)
		Game.add_fragments(id, n)
		if not Game.hero_owned(id):
			Events.toast.emit("Signal capté : %d fragments de %s" % [n, DB.HEROES[id].name], "hero")
	Audio.play("ui_reward")
	_refresh()


func _set_active(id: String) -> void:
	Game.profile.active_hero = id
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.setup_hero(id)
		Fx.dissolve_burst(p.global_position + Vector3.UP, DB.HEROES[id].color, 1.5)
	Events.toast.emit("%s est prêt au combat" % DB.HEROES[id].name, "hero")
	_refresh()


func _apply_player_stats() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.hero_id == _sel_hero:
		var hp_frac: float = p.hp / p.max_hp
		p.setup_hero(_sel_hero)
		p.hp = p.max_hp * hp_frac


# ------------------------------------------------------------------------------ inventory

func _inventory() -> void:
	_title.text = "Inventaire"
	var v := UiKit.vbox(8)
	_content.add_child(UiKit.scroll(v))
	v.add_child(UiKit.text("Capacité de stockage : %d par ressource" % Game.capacity(), 15, Color(0.7, 0.7, 0.8)))
	for k in DB.RESOURCES:
		var r: Dictionary = DB.RESOURCES[k]
		var h := UiKit.hbox()
		h.add_child(UiKit.text("%s  %s : %d" % [r.icon, r.name, Game.res(k)], 18, r.color, false))
		var u := UiKit.text("→ " + r.use, 15, Color(0.7, 0.7, 0.78))
		h.add_child(u)
		v.add_child(h)
	v.add_child(UiKit.title("Objets", 22, Color.WHITE))
	for it in DB.ITEMS:
		var d: Dictionary = DB.ITEMS[it]
		var h := UiKit.hbox()
		h.add_child(UiKit.icon(it, 34))
		h.add_child(UiKit.text("%s ×%d/%d — %s" % [d.name, Game.item_count(it), Game.item_max(it), d.desc], 16))
		v.add_child(h)
	v.add_child(UiKit.title("Équipements possédés", 22, Color.WHITE))
	if Game.profile.equipment_owned.is_empty():
		v.add_child(UiKit.text("Aucun. Fabriquez-en à l'atelier de la base.", 15, Color(0.7, 0.7, 0.78)))
	for e in Game.profile.equipment_owned:
		v.add_child(UiKit.text("• %s (%s) — %s" % [DB.EQUIPMENT[e].name, DB.EQUIPMENT[e].slot, DB.EQUIPMENT[e].desc], 16))
	var s: Dictionary = Game.profile.stats
	v.add_child(UiKit.title("Statistiques", 22, Color.WHITE))
	v.add_child(UiKit.text("Éliminations %d · Morts %d · Blocs creusés %d · Constructions %d · Captures %d · Temps caché %ds · Temps de jeu %d min" % [
		s.kills, s.deaths, s.dug, s.built, s.captures, int(s.time_hidden), int(Game.profile.play_time / 60.0)], 16))


# ------------------------------------------------------------------------------ base

func _base() -> void:
	_title.text = "Base souterraine"
	var v := UiKit.vbox(8)
	_content.add_child(UiKit.scroll(v))
	var pw := Game.power_balance()
	v.add_child(UiKit.text("Niveau de base : %d   ·   Énergie : %d produits / %d consommés %s   ·   Prochaine attaque estimée : %d s" % [
		Game.base_level(), pw.x, pw.y, "" if Game.base_powered() else "⚠ DÉFICIT", int(Game.profile.base.get("raid_timer", 0))], 17,
		Color(0.6, 1, 0.7) if Game.base_powered() else Color(1, 0.5, 0.4)))
	var in_base := Game.current_region == "base"
	if not in_base:
		v.add_child(UiKit.text("Rendez-vous dans la base (trappe du refuge) pour creuser et construire.", 17, Color(1, 0.8, 0.5)))
	else:
		var w := get_tree().get_first_node_in_group("world")
		var base = w.get_meta("base") if w and w.has_meta("base") else null
		if base and Game.has_research("reinforce"):
			var dig: Node = base.dig
			v.add_child(UiKit.toggle("Mode renfort (paroi : matériaux 2 + métal 1)", dig.get("mode") == "reinforce", func(on): dig.set("mode", "reinforce" if on else "dig")))
	for t in DB.BUILDINGS:
		var d: Dictionary = DB.BUILDINGS[t]
		var row := UiKit.panel()
		var h := UiKit.hbox()
		row.add_child(h)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count := Game.count_buildings(t)
		info.add_child(UiKit.title("%s%s" % [d.name, "  (×%d)" % count if count > 0 else ""], 19, Color.WHITE))
		info.add_child(UiKit.text(d.desc + ("  · énergie %+d" % d.power if d.power != 0 else ""), 14))
		info.add_child(UiKit.cost_label(d.cost))
		h.add_child(info)
		var reason := Game.building_lock_reason(t)
		var can := in_base and reason == "" and Game.can_afford(d.cost)
		var label := "Construire" if reason == "" else reason
		h.add_child(UiKit.button(label, func():
			var w := get_tree().get_first_node_in_group("world")
			close()
			w.get_meta("base").start_placement(t), 52, can))
		v.add_child(row)


# ------------------------------------------------------------------------------ research

func _research() -> void:
	_title.text = "Recherche scientifique"
	var v := UiKit.vbox(8)
	_content.add_child(UiKit.scroll(v))
	var r: Dictionary = Game.profile.research
	if not Game.has_building("lab"):
		v.add_child(UiKit.text("Construisez un laboratoire symbiotique dans la base pour mener des recherches.", 17, Color(1, 0.8, 0.5)))
	if r.get("current", "") != "":
		v.add_child(UiKit.text("En cours : %s — %d %%%s" % [DB.RESEARCH[r.current].name, int(100.0 * r.progress / Game.research_time(r.current)),
			"" if Game.base_powered() else "  (en pause : énergie insuffisante)"], 18, UiKit.ACCENT))
	for id in DB.RESEARCH:
		var d: Dictionary = DB.RESEARCH[id]
		var row := UiKit.panel()
		var h := UiKit.hbox()
		row.add_child(h)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var done := Game.has_research(id)
		info.add_child(UiKit.title(("✔ " if done else "") + d.name, 19, Color(0.5, 1, 0.6) if done else Color.WHITE))
		info.add_child(UiKit.text(d.desc, 14))
		if not d.requires.is_empty():
			info.add_child(UiKit.text("Prérequis : " + ", ".join(d.requires.map(func(x): return DB.RESEARCH[x].name)), 13, Color(0.7, 0.7, 0.78)))
		info.add_child(UiKit.cost_label(d.cost))
		h.add_child(info)
		if not done:
			var ok = Game.research_available(id) and r.get("current", "") == "" and Game.has_building("lab") and Game.can_afford(d.cost)
			h.add_child(UiKit.button("Lancer (%ds)" % int(Game.research_time(id)), func(): Game.start_research(id); _refresh(), 52, ok))
		v.add_child(row)


# ------------------------------------------------------------------------------ codex

func _codex() -> void:
	_title.text = "Codex des symbiotes"
	var v := UiKit.vbox(10)
	_content.add_child(UiKit.scroll(v))
	var any := false
	for id in DB.ENEMIES:
		var e := Game.codex_entry(id)
		var d: Dictionary = DB.ENEMIES[id]
		if not e.seen and e.kills == 0:
			continue
		any = true
		var row := UiKit.panel()
		var h := UiKit.hbox(14)
		row.add_child(h)
		var info := UiKit.vbox(3)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tier := Game.mastery_tier(d.family)
		info.add_child(UiKit.title(d.name, 22, Color(1, 0.5, 0.5) if d.get("boss", false) else Color.WHITE))
		info.add_child(UiKit.text("Menace %s   ·   Éliminés %d   ·   Étudiés %d   ·   Maîtrise %s (+%d %% dégâts)" % ["☠".repeat(int(d.threat)), e.kills, e.studied, "◆".repeat(tier) + "◇".repeat(3 - tier), tier * 5], 15, Color(1, 0.85, 0.6)))
		info.add_child(UiKit.text(d.desc, 15))
		info.add_child(UiKit.text(("Stratégie : " + d.strategy) if tier >= 1 or e.studied > 0 else "Stratégie : étudiez davantage cette créature (maîtrise 1).", 15, Color(0.6, 0.9, 1.0)))
		h.add_child(info)
		var pv := HeroPreview.new(Vector2(170, 200))
		h.add_child(pv)
		pv.show_model(d.model, Color(0.8, 0.1, 0.2), "idle", true, 2.0)
		v.add_child(row)
	if not any:
		v.add_child(UiKit.text("Aucune créature observée pour l'instant.", 17))


# ------------------------------------------------------------------------------ travel

func _travel() -> void:
	_title.text = "Carte du monde"
	var v := UiKit.vbox(10)
	_content.add_child(UiKit.scroll(v))
	v.add_child(UiKit.text("Le voyage rapide n'est possible que depuis un refuge ou la base. Ailleurs, rejoignez les passages entre régions.", 15, Color(0.7, 0.7, 0.78)))
	for id in DB.REGIONS:
		var r: Dictionary = DB.REGIONS[id]
		var row := UiKit.panel()
		var h := UiKit.hbox()
		row.add_child(h)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var unlocked := Game.region_unlocked(id)
		info.add_child(UiKit.title(r.name + ("  (vous êtes ici)" if id == Game.current_region else ""), 20, Color.WHITE if unlocked else Color(0.6, 0.6, 0.65)))
		info.add_child(UiKit.text(r.desc + ("" if unlocked else "  — 🔒 " + Game.region_lock_reason(id)), 15))
		h.add_child(info)
		var can = unlocked and _at_refuge and id != Game.current_region and id in Game.profile.regions_seen
		h.add_child(UiKit.button("Voyager", func(): close(); _store(); Game.save_game(); Loader.goto_world(id, "refuge" if id == "city" else "start"), 52, can))
		v.add_child(row)


# ------------------------------------------------------------------------------ options

func _options() -> void:
	_title.text = "Options"
	var v := UiKit.vbox(8)
	_content.add_child(UiKit.scroll(v))
	v.add_child(UiKit.title("Graphismes", 22, Color.WHITE))
	var q := UiKit.hbox()
	for i in Settings.QUALITY_NAMES.size():
		var name: String = Settings.QUALITY_NAMES[i]
		q.add_child(UiKit.button(("✔ " if int(Settings.get_v("quality")) == i else "") + name, func():
			Settings.apply_preset(i)
			Settings.apply()
			Settings.save_settings()
			_refresh(), 50))
	v.add_child(q)
	v.add_child(UiKit.text("Économique : 30 FPS, sans ombres · Équilibré : 30 FPS · Élevé : 60 FPS · Ultra : effets denses (appareils récents). Certaines options s'appliquent au prochain chargement de région.", 14, Color(0.7, 0.7, 0.78)))
	v.add_child(UiKit.slider("Échelle de rendu", Settings.get_v("render_scale"), 0.5, 1.0, 0.05, func(x): Settings.set_value("render_scale", x)))
	v.add_child(UiKit.slider("Densité des particules", Settings.get_v("particles"), 0.2, 1.5, 0.1, func(x): Settings.set_value("particles", x)))
	v.add_child(UiKit.slider("Distance d'affichage", Settings.get_v("draw_distance"), 0.5, 1.5, 0.1, func(x): Settings.set_value("draw_distance", x)))
	v.add_child(UiKit.toggle("Ombres", Settings.get_v("shadows"), func(x): Settings.set_value("shadows", x)))
	v.add_child(UiKit.toggle("Contours cartoon", Settings.get_v("outlines"), func(x): Settings.set_value("outlines", x)))
	v.add_child(UiKit.toggle("Post-traitement", Settings.get_v("post_fx"), func(x): Settings.set_value("post_fx", x)))
	v.add_child(UiKit.toggle("Afficher les FPS", Settings.get_v("show_fps"), func(x): Settings.set_value("show_fps", x)))
	v.add_child(UiKit.title("Audio", 22, Color.WHITE))
	for a in [["Volume général", "vol_master"], ["Musique", "vol_music"], ["Effets", "vol_sfx"], ["Ambiances", "vol_ambience"], ["Sons soudains (horreur)", "vol_scare"]]:
		v.add_child(UiKit.slider(a[0], Settings.get_v(a[1]), 0.0, 1.0, 0.05, func(x): Settings.set_value(a[1], x)))
	v.add_child(UiKit.title("Contrôles", 22, Color.WHITE))
	v.add_child(UiKit.slider("Sensibilité caméra", Settings.get_v("cam_sensitivity"), 0.3, 2.5, 0.05, func(x): Settings.set_value("cam_sensitivity", x)))
	v.add_child(UiKit.toggle("Inverser l'axe vertical", Settings.get_v("cam_invert_y"), func(x): Settings.set_value("cam_invert_y", x)))
	v.add_child(UiKit.slider("Taille des boutons", Settings.get_v("button_scale"), 0.7, 1.5, 0.05, func(x): Settings.set_value("button_scale", x)))
	v.add_child(UiKit.slider("Opacité de l'interface", Settings.get_v("ui_opacity"), 0.3, 1.0, 0.05, func(x): Settings.set_value("ui_opacity", x)))
	v.add_child(UiKit.slider("Assistance à la visée", Settings.get_v("aim_assist"), 0.0, 1.0, 0.05, func(x): Settings.set_value("aim_assist", x)))
	v.add_child(UiKit.toggle("Sprint auto (joystick au bord)", Settings.get_v("auto_sprint"), func(x): Settings.set_value("auto_sprint", x)))
	v.add_child(UiKit.toggle("Vibrations", Settings.get_v("vibration"), func(x): Settings.set_value("vibration", x)))
	var lay := UiKit.hbox()
	lay.add_child(UiKit.button("Personnaliser la disposition", _edit_layout, 50))
	lay.add_child(UiKit.button("Disposition par défaut", func():
		var w := get_tree().get_first_node_in_group("world")
		if w:
			w.hud.touch.reset_layout(), 50))
	v.add_child(lay)
	v.add_child(UiKit.title("Horreur", 22, Color.WHITE))
	v.add_child(UiKit.slider("Secousses de caméra", Settings.get_v("shake"), 0.0, 1.0, 0.05, func(x): Settings.set_value("shake", x)))
	v.add_child(UiKit.slider("Effets visuels d'horreur", Settings.get_v("horror_fx"), 0.0, 1.0, 0.05, func(x): Settings.set_value("horror_fx", x)))


func _edit_layout() -> void:
	var w := get_tree().get_first_node_in_group("world")
	if w == null:
		return
	close()
	get_tree().paused = true
	var touch: Control = w.hud.touch
	touch.edit_mode = true
	touch.process_mode = Node.PROCESS_MODE_ALWAYS
	var done := UiKit.button("✔ Terminer la disposition", func(): pass, 60)
	done.theme = UiKit.theme()
	done.set_anchors_preset(Control.PRESET_CENTER_TOP)
	done.position = Vector2(-160, 120)
	done.size = Vector2(320, 60)
	w.hud.add_child(done)
	done.pressed.connect(func():
		touch.edit_mode = false
		touch.process_mode = Node.PROCESS_MODE_INHERIT
		touch._save_layout()
		get_tree().paused = false
		done.queue_free())
	Events.toast.emit("Faites glisser les boutons pour les déplacer", "objective")


# ------------------------------------------------------------------------------ building panels

func _building_panel() -> void:
	if _building == null or not is_instance_valid(_building):
		_switch("base")
		return
	var b: Node = _building
	var d: Dictionary = b.data
	_title.text = "%s — niveau %d" % [d.name, b.level()]
	var v := UiKit.vbox(10)
	_content.add_child(UiKit.scroll(v))
	v.add_child(UiKit.text(d.desc, 17))
	v.add_child(UiKit.text("Intégrité : %d/%d   ·   %s" % [int(b.entry.hp), int(b.max_hp()), "Alimenté" if b.powered() else "⚠ Sans courant"], 16, Color(0.6, 1, 0.7) if b.powered() else Color(1, 0.6, 0.4)))
	if d.has("upgrade") and b.level() < int(d.max_level):
		var cost: Dictionary = {}
		for k in d.upgrade:
			cost[k] = int(d.upgrade[k]) * b.level()
		var row := UiKit.hbox()
		row.add_child(UiKit.button("Améliorer au niveau %d" % (b.level() + 1), func():
			if Game.spend(cost):
				b.entry.level = b.level() + 1
				b.entry.hp = b.max_hp()
				b.refresh()
				Audio.play("build_complete")
				Events.base_changed.emit()
				_refresh(), 52, Game.can_afford(cost)))
		row.add_child(UiKit.cost_label(cost))
		v.add_child(row)
	match b.type:
		"command":
			v.add_child(UiKit.text("Le niveau du centre de commandement débloque les installations avancées et augmente la taille des raids repoussables.", 15))
			var pw := Game.power_balance()
			v.add_child(UiKit.text("Énergie : %d / %d · Installations : %d · Créatures confinées : %d" % [pw.x, pw.y, Game.buildings().size(), Game.profile.base.creatures.size()], 16))
		"generator":
			v.add_child(UiKit.text("Produit %d unités d'énergie. Un générateur en panne coupe tourelles, lumières et recherche." % (int(d.power) + (b.level() - 1) * 3), 16))
		"lab":
			v.add_child(UiKit.button("Ouvrir la recherche", func(): _switch("research"), 54))
		"workshop":
			_workshop(v)
		"infirmary":
			v.add_child(UiKit.button("Soins complets", func():
				var p := get_tree().get_first_node_in_group("player")
				if p:
					p.heal(p.max_hp)
					p.energy = p.max_energy
				Audio.play("heal")
				_refresh(), 54))
			v.add_child(UiKit.text("Bonus permanent : +%d %% PV max pour tous les héros." % (5 * Game.building_level_sum("infirmary")), 15))
		"armory":
			v.add_child(UiKit.text("Emplacements d'objets : +%d par type. Équipez vos héros depuis la collection." % Game.building_level_sum("armory"), 16))
			v.add_child(UiKit.button("Ouvrir la collection", func(): _switch("heroes"), 54))
		"containment":
			var cr: Array = Game.profile.base.creatures
			v.add_child(UiKit.text("Créatures confinées : %d. Elles produisent un échantillon toutes les 90 s (par créature)." % cr.size(), 16))
			for i in cr.size():
				var id: String = cr[i]
				var row := UiKit.hbox()
				row.add_child(UiKit.text(DB.ENEMIES[id].name, 16))
				row.add_child(UiKit.button("Étudier (données +3, maîtrise)", func():
					cr.remove_at(i)
					Game.codex_entry(id).studied += 2
					Game.add_res("data", 3)
					Events.codex_updated.emit(id)
					_refresh(), 48))
				v.add_child(row)
		"watch":
			var rt := int(Game.profile.base.get("raid_timer", 0))
			v.add_child(UiKit.text("Prochaine attaque estimée dans %d s. Alerte anticipée : %d s." % [rt, 10 + 50 * Game.building_level_sum("watch")], 16))
			if Game.has_research("sonar"):
				v.add_child(UiKit.text("Sonar actif : les fouisseurs sont révélés par leurs vibrations.", 15))
		"storage":
			v.add_child(UiKit.text("Capacité actuelle : %d par ressource." % Game.capacity(), 16))
		"training":
			var hid: String = Game.profile.active_hero
			var cost := {"samples": 4, "crystal": 4}
			var row := UiKit.hbox()
			row.add_child(UiKit.button("Entraîner %s (+%d XP)" % [DB.HEROES[hid].name, 150 * b.level()], func():
				if Game.spend(cost):
					Game.add_hero_xp(hid, 150 * b.level())
					Audio.play("levelup", -4.0)
					_refresh(), 54, Game.can_afford(cost)))
			row.add_child(UiKit.cost_label(cost))
			v.add_child(row)
		"turret":
			v.add_child(UiKit.text("Portée %d m · Dégâts %d par tir." % [15 + 3 * b.level(), 9 + 5 * b.level()], 16))


func _workshop(v: VBoxContainer) -> void:
	v.add_child(UiKit.title("Fabrication", 22, Color.WHITE))
	for id in DB.RECIPES:
		var r: Dictionary = DB.RECIPES[id]
		var row := UiKit.panel()
		var h := UiKit.hbox()
		row.add_child(h)
		var is_item: bool = r.kind == "item"
		var d: Dictionary = DB.ITEMS[id] if is_item else DB.EQUIPMENT[id]
		h.add_child(UiKit.icon(id if is_item else "build", 40))
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var owned := ("  (×%d)" % Game.item_count(id)) if is_item else ("  ✔ possédé" if id in Game.profile.equipment_owned else "")
		info.add_child(UiKit.title(d.name + owned, 18, Color.WHITE))
		info.add_child(UiKit.text(d.desc, 14))
		info.add_child(UiKit.cost_label(r.cost))
		h.add_child(info)
		var lock := ""
		if r.has("research") and not Game.has_research(r.research):
			lock = "Recherche : " + DB.RESEARCH[r.research].name
		var can: bool = lock == "" and Game.can_afford(r.cost) and (not is_item and not id in Game.profile.equipment_owned or is_item and Game.item_count(id) < Game.item_max(id))
		h.add_child(UiKit.button(lock if lock != "" else "Fabriquer", func():
			if Game.spend(r.cost):
				if is_item:
					Game.add_item(id, int(r.amount))
				else:
					Game.profile.equipment_owned.append(id)
				Audio.play("build_place", -4.0)
				Events.toast.emit("Fabriqué : " + d.name, "item")
				_refresh(), 50, can))
		v.add_child(row)
