extends Node
## Global signal bus. Systems communicate through these signals instead of direct references.

# Perception
signal noise(pos: Vector3, radius: float, source: Node)
signal light_flash(pos: Vector3, radius: float, duration: float)  # flares, explosions

# Combat
signal enemy_damaged(enemy: Node, amount: float, crit: bool)
signal enemy_killed(enemy: Node, enemy_id: String, family: String)
signal enemy_spotted_player(enemy: Node)
signal player_damaged(amount: float)
signal player_died
signal combo_changed(count: int)
signal boss_started(boss: Node, title: String)
signal boss_phase(boss: Node, phase: int)
signal boss_defeated(boss: Node, boss_id: String)

# Progression / economy
signal resources_changed
signal items_changed
signal xp_gained(amount: int)
signal player_level_up(level: int)
signal hero_level_up(hero_id: String, level: int)
signal hero_unlocked(hero_id: String)
signal codex_updated(enemy_id: String)
signal research_completed(research_id: String)

# Missions / world
signal mission_event(kind: String, target: String, amount: int)
signal mission_updated(mission_id: String)
signal mission_completed(mission_id: String)
signal objective_marker(pos: Vector3, label: String)
signal region_entered(region_id: String)
signal interaction_available(prompt: String, target: Node)
signal interaction_cleared(target: Node)
signal toast(text: String, kind: String)
signal log_found(log_id: String)

# Horror / stealth
signal threat_level(level: float)       # 0 calm .. 1 being chased
signal devourer_state(state: String)
signal player_hidden(hidden: bool)
signal jumpscare(intensity: float)

# Base
signal base_alert(text: String)
signal base_power_changed(available: int, used: int)
signal base_changed
signal cell_dug(cell: Vector3i, kind: int)
