extends Node
## Static game data. Everything that defines content lives here so that adding a hero,
## an enemy, a building or a mission is a data change, not a code change.

const RARITIES := {
	"commun": {"name": "Commun", "color": Color(0.72, 0.75, 0.8), "order": 0},
	"rare": {"name": "Rare", "color": Color(0.3, 0.65, 1.0), "order": 1},
	"epique": {"name": "Épique", "color": Color(0.72, 0.4, 1.0), "order": 2},
	"legendaire": {"name": "Légendaire", "color": Color(1.0, 0.72, 0.15), "order": 3},
	"mythique": {"name": "Mythique", "color": Color(1.0, 0.3, 0.55), "order": 4},
	"abyssal": {"name": "Abyssal", "color": Color(0.85, 0.08, 0.2), "order": 5},
}

const RESOURCES := {
	"metal": {"name": "Métal", "icon": "⬢", "color": Color(0.7, 0.74, 0.8), "use": "Construction, réparations, équipements"},
	"crystal": {"name": "Cristaux énergétiques", "icon": "◆", "color": Color(0.3, 0.9, 1.0), "use": "Générateurs, pouvoirs, recherche"},
	"electronics": {"name": "Composants électroniques", "icon": "▣", "color": Color(0.4, 1.0, 0.5), "use": "Tourelles, gadgets, surveillance"},
	"materials": {"name": "Matériaux de construction", "icon": "▤", "color": Color(0.8, 0.62, 0.4), "use": "Bâtiments, renforts, barricades"},
	"samples": {"name": "Échantillons symbiotiques", "icon": "●", "color": Color(0.85, 0.15, 0.3), "use": "Recherche, améliorations des héros"},
	"spores": {"name": "Spores", "icon": "✺", "color": Color(0.6, 1.0, 0.3), "use": "Soins, antidotes, laboratoire"},
	"alloy": {"name": "Alliages rares", "icon": "⬟", "color": Color(1.0, 0.75, 0.3), "use": "Équipements avancés, ultimes"},
	"data": {"name": "Données scientifiques", "icon": "≡", "color": Color(0.75, 0.6, 1.0), "use": "Recherche, signaux de recrutement"},
}

# --------------------------------------------------------------------------------------------
# HEROES
# Ability kinds are implemented in src/combat/abilities.gd
# --------------------------------------------------------------------------------------------
const HEROES := {
	"vortex": {
		"name": "Vortex", "title": "Le Pulsar", "rarity": "epique", "role": "Distance / Contrôle",
		"color": Color(0.25, 0.95, 1.0), "model": "res://assets/models/heroes/vortex.glb",
		"story": "Technicienne du réacteur central de la mégapole, Lyra Okoye a survécu à l'explosion qui a libéré les symbiotes. Son corps stocke désormais l'énergie pure du cœur du réacteur. Elle se bat pour réparer ce qu'elle n'a pas pu empêcher.",
		"stats": {"hp": 100, "energy": 100, "atk": 12, "def": 4, "speed": 6.0},
		"primary": {"kind": "bolt", "name": "Tir énergétique", "dmg": 1.0, "range": 18.0},
		"abilities": [
			{"id": "shockwave", "name": "Onde de choc", "kind": "shockwave", "cost": 25, "cd": 6.0, "dmg": 2.2, "radius": 5.0, "knock": 9.0, "status": "stun", "status_t": 0.8, "desc": "Repousse et étourdit les ennemis proches."},
			{"id": "barrier", "name": "Bouclier temporaire", "kind": "shield", "cost": 30, "cd": 12.0, "absorb": 60, "duration": 5.0, "desc": "Absorbe les dégâts pendant 5 s."},
			{"id": "pulse", "name": "Salve pulsar", "kind": "projectile", "cost": 20, "cd": 4.0, "dmg": 1.6, "count": 5, "spread": 30.0, "speed": 26.0, "desc": "Cinq projectiles en éventail."},
		],
		"ultimate": {"id": "gravstorm", "name": "Tempête gravitationnelle", "kind": "gravity_storm", "dmg": 0.9, "radius": 9.0, "duration": 5.0, "desc": "Une tempête aspire et broie les ennemis."},
		"passive": {"id": "overcharge", "name": "Surcharge", "desc": "Chaque 4e tir énergétique inflige double dégâts.", "kind": "every_nth", "n": 4, "mult": 2.0},
		"unlock": {"type": "start"},
	},
	"noctis": {
		"name": "Noctis", "title": "L'Ombre Errante", "rarity": "legendaire", "role": "Assassin / Furtivité",
		"color": Color(0.78, 0.35, 1.0), "model": "res://assets/models/heroes/noctis.glb",
		"story": "Personne ne connaît son vrai nom. Noctis traverse les ombres comme d'autres traversent une pièce. Depuis l'invasion, il chasse les symbiotes la nuit et laisse derrière lui des marques violettes pour guider les survivants.",
		"stats": {"hp": 85, "energy": 110, "atk": 15, "def": 3, "speed": 6.6},
		"primary": {"kind": "melee", "name": "Lames jumelles", "dmg": 1.0, "range": 2.4},
		"abilities": [
			{"id": "shadowstep", "name": "Téléportation courte", "kind": "teleport", "cost": 20, "cd": 5.0, "distance": 8.0, "dmg": 1.8, "desc": "Apparaît derrière la cible la plus proche et frappe."},
			{"id": "shadowblades", "name": "Lames d'ombre", "kind": "blades", "cost": 25, "cd": 6.0, "dmg": 2.6, "radius": 4.0, "angle": 140.0, "status": "mark", "status_t": 6.0, "desc": "Tranche en arc et marque les ennemis (+30 % dégâts)."},
			{"id": "veil", "name": "Invisibilité", "kind": "invisibility", "cost": 35, "cd": 16.0, "duration": 6.0, "desc": "Invisible aux symbiotes pendant 6 s. Attaquer rompt le voile."},
		],
		"ultimate": {"id": "darkdomain", "name": "Domaine obscur", "kind": "dark_domain", "dmg": 0.6, "radius": 10.0, "duration": 7.0, "desc": "Une zone d'ombre ralentit, marque et aveugle les ennemis."},
		"passive": {"id": "backstab", "name": "Frappe dans le dos", "desc": "+60 % de dégâts sur les ennemis qui ne vous voient pas.", "kind": "backstab", "mult": 1.6},
		"unlock": {"type": "mission", "value": "m05_lab_power"},
	},
	"pyra": {
		"name": "Pyra", "title": "La Braise Vivante", "rarity": "epique", "role": "Dégâts de zone",
		"color": Color(1.0, 0.5, 0.1), "model": "res://assets/models/heroes/pyra.glb",
		"story": "Pompière volontaire, Inès Varga a plongé dans un brasier pour sauver une famille. Elle en est ressortie en flammes, mais vivante. Les spores symbiotiques brûlent à son contact : elle est devenue la terreur des nids.",
		"stats": {"hp": 95, "energy": 100, "atk": 14, "def": 4, "speed": 6.1},
		"primary": {"kind": "bolt", "name": "Projectiles enflammés", "dmg": 0.9, "range": 15.0, "status": "burn"},
		"abilities": [
			{"id": "firewall", "name": "Mur de feu", "kind": "wall", "cost": 30, "cd": 9.0, "dmg": 0.8, "length": 8.0, "duration": 5.0, "status": "burn", "desc": "Un mur de flammes bloque et brûle les ennemis."},
			{"id": "blastdash", "name": "Ruée explosive", "kind": "dash", "cost": 20, "cd": 5.0, "distance": 9.0, "dmg": 2.0, "radius": 3.0, "status": "burn", "desc": "Fonce et explose à l'arrivée."},
			{"id": "inferno", "name": "Anneau d'embrasement", "kind": "shockwave", "cost": 25, "cd": 7.0, "dmg": 2.0, "radius": 4.5, "knock": 5.0, "status": "burn", "status_t": 4.0, "desc": "Un anneau de feu enflamme les ennemis proches."},
		],
		"ultimate": {"id": "meteor", "name": "Météore incandescent", "kind": "meteor", "dmg": 9.0, "radius": 8.0, "delay": 1.2, "desc": "Un météore s'abat sur la zone ciblée."},
		"passive": {"id": "kindling", "name": "Combustion", "desc": "Les ennemis en feu subissent +25 % de dégâts.", "kind": "vs_status", "status": "burn", "mult": 1.25},
		"unlock": {"type": "mission", "value": "m03_forest_nest"},
	},
	"bastion": {
		"name": "Bastion", "title": "Le Mur de la Ville", "rarity": "rare", "role": "Tank / Protection",
		"color": Color(1.0, 0.8, 0.25), "model": "res://assets/models/heroes/bastion.glb",
		"story": "Ancien agent de sécurité du métro, Marcus Dahl portait l'armure expérimentale « Égide » le soir de l'invasion. Il a tenu seul les portes de la station Opéra pendant trois jours. Les survivants l'appellent le Mur.",
		"stats": {"hp": 150, "energy": 90, "atk": 10, "def": 9, "speed": 5.4},
		"primary": {"kind": "melee", "name": "Coup de bouclier", "dmg": 1.15, "range": 2.6},
		"abilities": [
			{"id": "frontshield", "name": "Bouclier frontal", "kind": "shield", "cost": 20, "cd": 8.0, "absorb": 120, "duration": 6.0, "desc": "Lève le bouclier : absorbe 120 dégâts."},
			{"id": "taunt", "name": "Provocation", "kind": "taunt", "cost": 15, "cd": 10.0, "radius": 12.0, "duration": 5.0, "def_bonus": 6, "desc": "Attire tous les ennemis proches et augmente la défense."},
			{"id": "seismic", "name": "Onde sismique", "kind": "seismic", "cost": 25, "cd": 7.0, "dmg": 2.4, "length": 10.0, "width": 2.5, "status": "stun", "status_t": 1.2, "desc": "Une fissure traverse le sol et étourdit."},
		],
		"ultimate": {"id": "fortress", "name": "Forteresse énergétique", "kind": "fortress", "radius": 6.0, "duration": 8.0, "dmg": 0.5, "desc": "Un dôme bloque les ennemis et soigne à l'intérieur."},
		"passive": {"id": "bulwark", "name": "Rempart", "desc": "Réduit de 25 % les dégâts frontaux.", "kind": "front_reduction", "mult": 0.75},
		"unlock": {"type": "mission", "value": "m01_first_steps"},
	},
	"rift": {
		"name": "Rift", "title": "La Fracture", "rarity": "mythique", "role": "Mobilité / Contrôle",
		"color": Color(1.0, 0.3, 0.85), "model": "res://assets/models/heroes/rift.glb",
		"story": "Sujet R-0 du complexe scientifique. Rift ne se souvient que d'un laboratoire blanc et d'une porte qui s'ouvrait sur le vide. Son corps est une fissure dans l'espace, et la fissure s'agrandit.",
		"stats": {"hp": 90, "energy": 120, "atk": 13, "def": 4, "speed": 6.4},
		"primary": {"kind": "bolt", "name": "Éclat dimensionnel", "dmg": 1.05, "range": 16.0},
		"abilities": [
			{"id": "dimdash", "name": "Dash dimensionnel", "kind": "dash", "cost": 15, "cd": 3.0, "distance": 10.0, "dmg": 1.0, "radius": 1.5, "phase": true, "desc": "Traverse les ennemis en phase."},
			{"id": "portal", "name": "Portail de déplacement", "kind": "portal", "cost": 25, "cd": 2.0, "range": 30.0, "desc": "Pose un portail. Réactiver pour y revenir (30 m max)."},
			{"id": "unstable", "name": "Projectile instable", "kind": "projectile", "cost": 25, "cd": 6.0, "dmg": 3.5, "count": 1, "speed": 14.0, "explode": 4.0, "status": "slow", "desc": "Explose en ralentissant la zone."},
		],
		"ultimate": {"id": "singularity", "name": "Singularité", "kind": "singularity", "dmg": 1.2, "radius": 10.0, "duration": 4.0, "desc": "Un trou noir aspire tout, puis explose."},
		"passive": {"id": "phase", "name": "Déphasage", "desc": "Les esquives rechargent 20 % du temps de recharge des pouvoirs.", "kind": "dodge_cdr", "value": 0.2},
		"unlock": {"type": "fragments", "value": 30},
	},
	"porteur": {
		"name": "Le Porteur", "title": "Hôte Abyssal", "rarity": "abyssal", "role": "Combattant / Survie",
		"color": Color(1.0, 0.1, 0.15), "model": "res://assets/models/heroes/porteur.glb",
		"story": "Il a été infecté, comme des milliers d'autres. Mais au lieu de le dévorer, le symbiote l'a écouté. Le Porteur connaît la voix de l'Abysse et sait qu'elle ment. Les autres héros ne lui font pas confiance. Pas encore.",
		"stats": {"hp": 120, "energy": 100, "atk": 16, "def": 6, "speed": 6.2},
		"primary": {"kind": "melee", "name": "Griffes symbiotiques", "dmg": 1.1, "range": 3.0},
		"abilities": [
			{"id": "tentacles", "name": "Tentacules offensifs", "kind": "blades", "cost": 20, "cd": 5.0, "dmg": 2.2, "radius": 6.0, "angle": 80.0, "pull": true, "desc": "Frappe à distance et attire les ennemis."},
			{"id": "regen", "name": "Régénération", "kind": "regen", "cost": 30, "cd": 14.0, "heal": 45, "duration": 4.0, "desc": "Régénère 45 PV en 4 s."},
			{"id": "bind", "name": "Immobilisation", "kind": "root", "cost": 25, "cd": 9.0, "radius": 6.0, "duration": 3.0, "dmg": 0.8, "desc": "Des racines noires immobilisent les ennemis."},
		],
		"ultimate": {"id": "abyssform", "name": "Forme abyssale", "kind": "transform", "duration": 10.0, "mult": 1.8, "desc": "Se transforme : dégâts ×1,8, vol de vie, portée accrue."},
		"passive": {"id": "symbiosis", "name": "Symbiose", "desc": "Chaque élimination rend 6 PV.", "kind": "heal_on_kill", "value": 6},
		"unlock": {"type": "mission", "value": "m09_architect"},
	},
	"spark": {
		"name": "Spark", "title": "Le Coursier", "rarity": "commun", "role": "Polyvalent",
		"color": Color(0.55, 0.85, 1.0), "model": "res://assets/models/heroes/spark.glb",
		"story": "Coursier à vélo électrique, Théo Ndiaye a pris une décharge du réseau en surcharge pendant l'invasion. Il court plus vite que tout le monde et il est toujours le premier volontaire.",
		"stats": {"hp": 90, "energy": 100, "atk": 11, "def": 4, "speed": 6.8},
		"primary": {"kind": "bolt", "name": "Arc électrique", "dmg": 0.95, "range": 14.0},
		"abilities": [
			{"id": "zip", "name": "Sprint électrique", "kind": "dash", "cost": 15, "cd": 4.0, "distance": 8.0, "dmg": 1.0, "radius": 2.0, "status": "stun", "desc": "Fonce en électrocutant le passage."},
			{"id": "chain", "name": "Éclair en chaîne", "kind": "projectile", "cost": 20, "cd": 5.0, "dmg": 1.8, "count": 3, "spread": 18.0, "speed": 30.0, "status": "stun", "desc": "Trois éclairs étourdissants."},
			{"id": "battery", "name": "Batterie de secours", "kind": "regen", "cost": 0, "cd": 18.0, "heal": 25, "energy": 40, "duration": 2.0, "desc": "Récupère PV et énergie."},
		],
		"ultimate": {"id": "overload", "name": "Surtension", "kind": "gravity_storm", "dmg": 0.7, "radius": 7.0, "duration": 4.0, "desc": "Un champ électrique frappe tout autour."},
		"passive": {"id": "quick", "name": "Jambes de foudre", "desc": "+15 % de vitesse de sprint et d'endurance.", "kind": "stamina", "mult": 1.15},
		"unlock": {"type": "mission", "value": "m02_supplies"},
	},
	"sylve": {
		"name": "Sylve", "title": "La Botaniste", "rarity": "rare", "role": "Soutien / Résistance",
		"color": Color(0.6, 1.0, 0.45), "model": "res://assets/models/heroes/sylve.glb",
		"story": "Chercheuse en botanique, le Dr Aïko Mbeki a modifié ses propres cellules pour résister aux spores. Une écorce vivante la protège. Elle cherche dans la forêt contaminée le secret d'un remède.",
		"stats": {"hp": 110, "energy": 100, "atk": 10, "def": 7, "speed": 5.8},
		"primary": {"kind": "bolt", "name": "Graine épineuse", "dmg": 0.9, "range": 15.0, "status": "slow"},
		"abilities": [
			{"id": "thorns", "name": "Ronces", "kind": "root", "cost": 20, "cd": 7.0, "radius": 5.0, "duration": 2.5, "dmg": 1.2, "desc": "Des ronces immobilisent et blessent."},
			{"id": "bloom", "name": "Floraison", "kind": "regen", "cost": 30, "cd": 12.0, "heal": 55, "duration": 5.0, "desc": "Soigne sur la durée et purifie les spores."},
			{"id": "pollen", "name": "Nuée de pollen", "kind": "wall", "cost": 25, "cd": 9.0, "dmg": 0.5, "length": 6.0, "duration": 6.0, "status": "slow", "desc": "Un nuage ralentit et masque le joueur."},
		],
		"ultimate": {"id": "grove", "name": "Bosquet ancestral", "kind": "fortress", "radius": 7.0, "duration": 9.0, "dmg": 0.4, "desc": "Une forêt protectrice soigne et repousse."},
		"passive": {"id": "sporeproof", "name": "Immunité aux spores", "desc": "Insensible aux zones contaminées.", "kind": "spore_immune"},
		"unlock": {"type": "challenge", "value": "kills_200"},
	},
}

# Skill tree (shared template, 3 branches x 4 tiers). Effects are additive modifiers.
const SKILLS := [
	{"id": "atk1", "branch": "Puissance", "tier": 1, "name": "Force accrue", "desc": "+10 % dégâts", "mods": {"atk_mult": 0.10}},
	{"id": "atk2", "branch": "Puissance", "tier": 2, "name": "Coups critiques", "desc": "+12 % chance de critique", "mods": {"crit": 0.12}},
	{"id": "atk3", "branch": "Puissance", "tier": 3, "name": "Enchaînement", "desc": "+25 % dégâts du 3e coup", "mods": {"finisher_mult": 0.25}},
	{"id": "atk4", "branch": "Puissance", "tier": 4, "name": "Exécuteur", "desc": "Exécutions possibles sous 25 % PV", "mods": {"execute_threshold": 0.10}},
	{"id": "def1", "branch": "Survie", "tier": 1, "name": "Endurance", "desc": "+20 PV max", "mods": {"hp_flat": 20}},
	{"id": "def2", "branch": "Survie", "tier": 2, "name": "Réflexes", "desc": "Fenêtre d'esquive parfaite +50 %", "mods": {"perfect_window": 0.5}},
	{"id": "def3", "branch": "Survie", "tier": 3, "name": "Peau dure", "desc": "+4 défense", "mods": {"def_flat": 4}},
	{"id": "def4", "branch": "Survie", "tier": 4, "name": "Second souffle", "desc": "Survit une fois par mission à un coup fatal", "mods": {"second_wind": 1}},
	{"id": "pow1", "branch": "Pouvoirs", "tier": 1, "name": "Réservoir", "desc": "+20 énergie max", "mods": {"energy_flat": 20}},
	{"id": "pow2", "branch": "Pouvoirs", "tier": 2, "name": "Concentration", "desc": "-15 % temps de recharge", "mods": {"cdr": 0.15}},
	{"id": "pow3", "branch": "Pouvoirs", "tier": 3, "name": "Amplification", "desc": "+20 % dégâts des pouvoirs", "mods": {"ability_mult": 0.20}},
	{"id": "pow4", "branch": "Pouvoirs", "tier": 4, "name": "Éveil", "desc": "L'ultime se charge 30 % plus vite", "mods": {"ult_gain": 0.30}},
]

# --------------------------------------------------------------------------------------------
# ENEMIES
# --------------------------------------------------------------------------------------------
const ENEMIES := {
	"crawler": {
		"name": "Symbiote rampant", "family": "rampant", "threat": 1, "model": "res://assets/models/monsters/crawler.glb",
		"scale": 1.0, "hp": 40, "dmg": 8, "speed": 3.2, "run_speed": 7.5, "sight": 14.0, "fov": 140.0, "hearing": 1.2,
		"attack_range": 1.6, "attack_cd": 1.4, "radius": 0.45, "height": 0.6, "poise": 10, "xp": 12,
		"drops": {"samples": [0, 1], "metal": [0, 2]}, "weak": "abdomen", "light_aversion": 0.0, "climbs": true,
		"desc": "Petit et rapide, il rampe sur les murs et sous les débris avant de bondir.",
		"strategy": "Restez mobile : sa morsure est faible mais il attaque en groupe. Son abdomen lumineux est fragile.",
	},
	"stalker": {
		"name": "Symbiote traqueur", "family": "traqueur", "threat": 2, "model": "res://assets/models/monsters/stalker.glb",
		"scale": 1.0, "hp": 110, "dmg": 16, "speed": 2.6, "run_speed": 8.2, "sight": 22.0, "fov": 110.0, "hearing": 1.6,
		"attack_range": 2.4, "attack_cd": 1.8, "radius": 0.5, "height": 1.9, "poise": 30, "xp": 35,
		"drops": {"samples": [1, 2], "electronics": [0, 1]}, "weak": "back", "light_aversion": 0.2,
		"desc": "Il repère sa proie, la suit à distance et attend qu'elle s'isole.",
		"strategy": "Ne lui tournez pas le dos. Les coups dans le dos lui infligent des dégâts doublés.",
	},
	"colossus": {
		"name": "Symbiote colosse", "family": "colosse", "threat": 4, "model": "res://assets/models/monsters/colossus.glb",
		"scale": 1.0, "hp": 420, "dmg": 34, "speed": 2.2, "run_speed": 5.2, "sight": 18.0, "fov": 120.0, "hearing": 0.8,
		"attack_range": 3.6, "attack_cd": 3.0, "radius": 1.1, "height": 3.0, "poise": 120, "xp": 120,
		"drops": {"samples": [3, 5], "alloy": [0, 1], "metal": [2, 5]}, "weak": "core", "light_aversion": 0.0,
		"desc": "Une montagne de chair capable de renverser des véhicules.",
		"strategy": "Esquivez ses frappes au sol, puis visez le cœur lumineux exposé quand il chancelle.",
	},
	"mimic": {
		"name": "Symbiote imitateur", "family": "imitateur", "threat": 3, "model": "res://assets/models/monsters/mimic.glb",
		"scale": 1.0, "hp": 90, "dmg": 20, "speed": 1.6, "run_speed": 7.0, "sight": 10.0, "fov": 160.0, "hearing": 1.0,
		"attack_range": 2.0, "attack_cd": 1.6, "radius": 0.45, "height": 1.8, "poise": 25, "xp": 45,
		"drops": {"samples": [1, 3], "data": [0, 1]}, "weak": "head", "light_aversion": 0.4,
		"desc": "Il imite la silhouette et la voix des survivants pour attirer ses proies.",
		"strategy": "Un « survivant » qui ne répond pas aux questions est suspect. Une lampe braquée le force à se révéler.",
	},
	"burrower": {
		"name": "Symbiote fouisseur", "family": "fouisseur", "threat": 3, "model": "res://assets/models/monsters/burrower.glb",
		"scale": 1.0, "hp": 150, "dmg": 22, "speed": 4.0, "run_speed": 6.5, "sight": 6.0, "fov": 360.0, "hearing": 2.2,
		"attack_range": 2.8, "attack_cd": 2.2, "radius": 0.6, "height": 2.0, "poise": 40, "xp": 55,
		"drops": {"samples": [2, 3], "crystal": [1, 2]}, "weak": "mouth", "light_aversion": 0.0, "burrows": true,
		"desc": "Aveugle, il se déplace sous terre en suivant les vibrations.",
		"strategy": "Restez immobile ou accroupi pour devenir silencieux. Frappez sa gueule quand il surgit.",
	},
	"abyssal": {
		"name": "Symbiote abyssal", "family": "abyssal", "threat": 5, "model": "res://assets/models/monsters/abyssal.glb",
		"scale": 1.0, "hp": 900, "dmg": 45, "speed": 3.0, "run_speed": 6.0, "sight": 24.0, "fov": 200.0, "hearing": 1.5,
		"attack_range": 5.0, "attack_cd": 3.5, "radius": 1.5, "height": 2.5, "poise": 200, "xp": 400,
		"drops": {"alloy": [2, 4], "crystal": [4, 8], "samples": [4, 6]}, "weak": "lure", "light_aversion": 0.0, "rare": true,
		"desc": "Un prédateur des profondeurs, rarement aperçu. Ses leurres lumineux attirent les imprudents.",
		"strategy": "Ses leurres sont son point faible. Ne restez jamais face à sa gueule.",
	},
	"devourer": {
		"name": "Le Dévoreur", "family": "devoreur", "threat": 6, "model": "res://assets/models/monsters/devourer.glb",
		"scale": 1.0, "hp": 2500, "dmg": 60, "speed": 2.4, "run_speed": 5.0, "max_run_speed": 8.6, "sight": 26.0, "fov": 120.0,
		"hearing": 2.5, "attack_range": 2.6, "attack_cd": 2.5, "radius": 0.55, "height": 3.2, "poise": 9999, "xp": 0,
		"drops": {}, "weak": "light", "light_aversion": 1.0,
		"desc": "Personne ne l'a vu de près et survécu sans fuir. Il écoute. Il attend. Il revient toujours.",
		"strategy": "Ne le combattez pas : fuyez, cachez-vous, coupez sa ligne de vue. Les fusées éclairantes l'aveuglent quelques secondes.",
	},
	# Bosses
	"colosse_fendu": {
		"name": "Le Colosse fendu", "family": "colosse", "threat": 5, "boss": true, "model": "res://assets/models/monsters/colosse_fendu.glb",
		"scale": 1.0, "hp": 2200, "dmg": 40, "speed": 2.4, "run_speed": 6.0, "sight": 40.0, "fov": 360.0, "hearing": 3.0,
		"attack_range": 4.5, "attack_cd": 2.4, "radius": 1.5, "height": 4.0, "poise": 400, "xp": 600,
		"drops": {"alloy": [3, 4], "samples": [6, 8], "metal": [10, 12]}, "weak": "core",
		"desc": "Un colosse dont la poitrine s'est ouverte sur un cœur incandescent.",
		"strategy": "Phase 1 : esquivez les frappes. Phase 2 : détruisez les excroissances. Phase 3 : le cœur est exposé après chaque charge.",
	},
	"reine_spores": {
		"name": "La Reine des spores", "family": "reine", "threat": 5, "boss": true, "model": "res://assets/models/monsters/reine_spores.glb",
		"scale": 1.0, "hp": 2600, "dmg": 30, "speed": 1.8, "run_speed": 3.0, "sight": 40.0, "fov": 360.0, "hearing": 3.0,
		"attack_range": 6.0, "attack_cd": 2.8, "radius": 2.2, "height": 4.5, "poise": 500, "xp": 700,
		"drops": {"spores": [12, 16], "samples": [6, 8], "alloy": [2, 3]}, "weak": "sacs",
		"desc": "Mère de la forêt contaminée. Ses sacs de spores engendrent sans cesse de nouveaux rampants.",
		"strategy": "Crevez les sacs lumineux sur son dos pour l'affaiblir. Restez hors des nuages de spores.",
	},
	"gardien": {
		"name": "Le Gardien du laboratoire", "family": "gardien", "threat": 5, "boss": true, "model": "res://assets/models/monsters/gardien.glb",
		"scale": 1.0, "hp": 2400, "dmg": 35, "speed": 2.8, "run_speed": 7.0, "sight": 40.0, "fov": 360.0, "hearing": 3.0,
		"attack_range": 3.5, "attack_cd": 2.2, "radius": 1.0, "height": 3.0, "poise": 350, "xp": 650,
		"drops": {"electronics": [8, 12], "alloy": [3, 4], "data": [4, 6]}, "weak": "core",
		"desc": "Un robot de confinement possédé par le symbiote qu'il devait garder.",
		"strategy": "Coupez les générateurs de l'arène pour désactiver son blindage, puis frappez.",
	},
	"architecte": {
		"name": "L'Architecte symbiotique", "family": "architecte", "threat": 6, "boss": true, "model": "res://assets/models/monsters/architecte.glb",
		"scale": 1.0, "hp": 5000, "dmg": 45, "speed": 0.0, "run_speed": 0.0, "sight": 60.0, "fov": 360.0, "hearing": 3.0,
		"attack_range": 12.0, "attack_cd": 2.6, "radius": 3.0, "height": 7.0, "poise": 9999, "xp": 1500,
		"drops": {"alloy": [8, 10], "data": [10, 12], "samples": [10, 12]}, "weak": "core",
		"desc": "La conscience qui coordonne tous les symbiotes. Elle construit quelque chose sous la ville.",
		"strategy": "Détruisez les nœuds qui l'alimentent pour exposer son noyau.",
	},
}

const FAMILIES := {
	"rampant": {"name": "Rampants", "tiers": [5, 20, 50]},
	"traqueur": {"name": "Traqueurs", "tiers": [3, 12, 30]},
	"colosse": {"name": "Colosses", "tiers": [1, 5, 12]},
	"imitateur": {"name": "Imitateurs", "tiers": [2, 8, 20]},
	"fouisseur": {"name": "Fouisseurs", "tiers": [2, 8, 20]},
	"abyssal": {"name": "Abyssaux", "tiers": [1, 2, 4]},
	"devoreur": {"name": "Le Dévoreur", "tiers": [1, 3, 6]},
	"reine": {"name": "Reine", "tiers": [1, 2, 3]},
	"gardien": {"name": "Gardien", "tiers": [1, 2, 3]},
	"architecte": {"name": "Architecte", "tiers": [1, 2, 3]},
}

# --------------------------------------------------------------------------------------------
# ITEMS & EQUIPMENT
# --------------------------------------------------------------------------------------------
const ITEMS := {
	"flare": {"name": "Fusée éclairante", "desc": "Éclaire une zone 20 s. Aveugle le Dévoreur et fait fuir les créatures sensibles à la lumière.", "max": 5},
	"decoy": {"name": "Leurre sonore", "desc": "Émet des bruits pendant 8 s pour attirer les monstres.", "max": 5},
	"medkit": {"name": "Trousse de soins", "desc": "Rend 50 PV.", "max": 5},
	"cell": {"name": "Cellule d'énergie", "desc": "Rend 50 énergie.", "max": 5},
	"smoke": {"name": "Grenade fumigène", "desc": "Un nuage épais coupe les lignes de vue pendant 10 s.", "max": 3},
	"barricade": {"name": "Kit de barricade", "desc": "Barricade une porte ouverte.", "max": 3},
	"capture": {"name": "Capsule de confinement", "desc": "Capture une créature étourdie et la transfère dans votre salle de confinement.", "max": 3},
	"mine": {"name": "Mine de proximité", "desc": "Explose au passage d'une créature.", "max": 4},
}

const EQUIPMENT := {
	"amp_gauntlet": {"name": "Gantelet amplificateur", "slot": "arme", "desc": "+15 % dégâts de base", "mods": {"atk_mult": 0.15}},
	"shock_core": {"name": "Noyau de choc", "slot": "arme", "desc": "+10 % critique, coups chargés étourdissent", "mods": {"crit": 0.10, "heavy_stun": 1}},
	"weave_vest": {"name": "Gilet tissé", "slot": "armure", "desc": "+3 défense, +15 PV", "mods": {"def_flat": 3, "hp_flat": 15}},
	"alloy_plate": {"name": "Plastron en alliage", "slot": "armure", "desc": "+6 défense", "mods": {"def_flat": 6}},
	"spore_filter": {"name": "Filtre à spores", "slot": "armure", "desc": "Immunité aux zones contaminées", "mods": {"spore_immune": 1}},
	"silent_boots": {"name": "Bottes silencieuses", "slot": "gadget", "desc": "-40 % de bruit des pas", "mods": {"noise_mult": -0.4}},
	"heart_monitor": {"name": "Moniteur cardiaque", "slot": "gadget", "desc": "Indique la direction des menaces proches", "mods": {"threat_radar": 1}},
	"power_cell": {"name": "Pile de surcharge", "slot": "gadget", "desc": "+25 énergie, régénération d'énergie +30 %", "mods": {"energy_flat": 25, "energy_regen": 0.3}},
}

# Workshop recipes: id -> {kind: item|equipment|defense, out, cost, requires (building level or research)}
const RECIPES := {
	"flare": {"kind": "item", "cost": {"crystal": 2, "materials": 1}, "amount": 2},
	"decoy": {"kind": "item", "cost": {"electronics": 1, "metal": 2}, "amount": 1},
	"medkit": {"kind": "item", "cost": {"spores": 2, "materials": 1}, "amount": 1},
	"cell": {"kind": "item", "cost": {"crystal": 3}, "amount": 1},
	"smoke": {"kind": "item", "cost": {"spores": 1, "materials": 2}, "amount": 1, "research": "chem"},
	"barricade": {"kind": "item", "cost": {"materials": 4, "metal": 2}, "amount": 1},
	"capture": {"kind": "item", "cost": {"electronics": 3, "alloy": 1, "crystal": 2}, "amount": 1, "research": "containment"},
	"mine": {"kind": "item", "cost": {"metal": 3, "electronics": 1, "crystal": 1}, "amount": 2, "research": "explosives"},
	"amp_gauntlet": {"kind": "equipment", "cost": {"metal": 12, "crystal": 6, "electronics": 3}},
	"shock_core": {"kind": "equipment", "cost": {"alloy": 3, "crystal": 8, "electronics": 4}, "research": "overcharge"},
	"weave_vest": {"kind": "equipment", "cost": {"materials": 10, "metal": 6}},
	"alloy_plate": {"kind": "equipment", "cost": {"alloy": 4, "metal": 14}, "research": "alloys"},
	"spore_filter": {"kind": "equipment", "cost": {"spores": 8, "electronics": 3}, "research": "chem"},
	"silent_boots": {"kind": "equipment", "cost": {"materials": 6, "samples": 3}},
	"heart_monitor": {"kind": "equipment", "cost": {"electronics": 6, "data": 2}},
	"power_cell": {"kind": "equipment", "cost": {"crystal": 10, "alloy": 2}, "research": "overcharge"},
}

# --------------------------------------------------------------------------------------------
# BASE
# size: footprint in cells (x, z); power: + produces / - consumes
# --------------------------------------------------------------------------------------------
const BUILDINGS := {
	"command": {"name": "Centre de commandement", "size": Vector2i(2, 2), "power": -1, "cost": {"metal": 10, "materials": 10, "electronics": 2},
		"max_level": 5, "unique": true, "desc": "Gère la base. Son niveau débloque les autres installations.",
		"upgrade": {"metal": 15, "materials": 12, "electronics": 4, "alloy": 1}},
	"generator": {"name": "Générateur", "size": Vector2i(1, 1), "power": 6, "cost": {"metal": 8, "crystal": 4},
		"max_level": 3, "desc": "Produit de l'énergie. Peut tomber en panne lors des attaques.", "upgrade": {"metal": 10, "crystal": 6, "electronics": 2}},
	"lab": {"name": "Laboratoire symbiotique", "size": Vector2i(2, 1), "power": -2, "cost": {"metal": 10, "electronics": 6, "samples": 3},
		"max_level": 3, "requires_base": 1, "desc": "Recherche de technologies à partir d'échantillons et de données.", "upgrade": {"electronics": 6, "data": 3, "samples": 4}},
	"containment": {"name": "Salle de confinement", "size": Vector2i(2, 1), "power": -2, "cost": {"metal": 14, "alloy": 1, "electronics": 4},
		"max_level": 3, "requires_base": 2, "desc": "Sécurise les créatures capturées : elles produisent des échantillons.", "upgrade": {"alloy": 2, "metal": 10}},
	"workshop": {"name": "Atelier", "size": Vector2i(1, 1), "power": -1, "cost": {"metal": 6, "materials": 6},
		"max_level": 3, "desc": "Fabrique objets, équipements et défenses.", "upgrade": {"metal": 10, "electronics": 3}},
	"infirmary": {"name": "Infirmerie", "size": Vector2i(1, 1), "power": -1, "cost": {"materials": 8, "spores": 3},
		"max_level": 3, "desc": "Soigne entièrement. Chaque niveau augmente les PV max de 5 %.", "upgrade": {"spores": 5, "materials": 6}},
	"armory": {"name": "Armurerie", "size": Vector2i(1, 1), "power": 0, "cost": {"metal": 10, "materials": 4},
		"max_level": 3, "requires_base": 1, "desc": "Gère les équipements. Chaque niveau ajoute +1 emplacement d'objets.", "upgrade": {"metal": 10, "alloy": 1}},
	"watch": {"name": "Poste de surveillance", "size": Vector2i(1, 1), "power": -1, "cost": {"electronics": 6, "metal": 4},
		"max_level": 3, "requires_base": 1, "desc": "Détecte les attaques à l'avance et révèle les fouisseurs.", "upgrade": {"electronics": 6, "data": 2}},
	"turret": {"name": "Tourelle automatique", "size": Vector2i(1, 1), "power": -1, "cost": {"metal": 8, "electronics": 4},
		"max_level": 3, "requires_research": "turrets", "desc": "Tire sur les créatures à portée. Nécessite de l'énergie.", "upgrade": {"metal": 6, "electronics": 4, "crystal": 2}},
	"storage": {"name": "Stockage", "size": Vector2i(1, 1), "power": 0, "cost": {"materials": 10},
		"max_level": 5, "desc": "Augmente la capacité de stockage des ressources (+150 par niveau).", "upgrade": {"materials": 10, "metal": 4}},
	"training": {"name": "Salle d'entraînement", "size": Vector2i(2, 1), "power": -1, "cost": {"metal": 8, "materials": 10},
		"max_level": 3, "requires_base": 2, "desc": "Convertit des ressources en expérience de héros.", "upgrade": {"metal": 8, "alloy": 1}},
	"lamp": {"name": "Lampe", "size": Vector2i(1, 1), "power": 0, "cost": {"metal": 1, "crystal": 1}, "small": true,
		"max_level": 1, "desc": "Éclaire. Les rampants évitent les zones éclairées."},
	"door": {"name": "Porte blindée", "size": Vector2i(1, 1), "power": 0, "cost": {"metal": 6, "materials": 2},
		"max_level": 3, "desc": "Bloque un tunnel. Peut être endommagée.", "upgrade": {"metal": 6, "alloy": 1}},
	"trap": {"name": "Piège à pointes", "size": Vector2i(1, 1), "power": 0, "cost": {"metal": 4, "materials": 2}, "small": true,
		"max_level": 2, "desc": "Blesse et ralentit les créatures.", "upgrade": {"metal": 4}},
	"elevator": {"name": "Ascenseur", "size": Vector2i(1, 1), "power": -1, "cost": {"metal": 12, "electronics": 3},
		"max_level": 1, "requires_base": 2, "desc": "Relie les niveaux de la base le long d'un puits creusé."},
}

const RESEARCH := {
	"drill": {"name": "Foreuse améliorée", "cost": {"data": 2, "crystal": 4}, "requires": [], "desc": "Creusement 50 % plus rapide."},
	"turrets": {"name": "Tourelles automatiques", "cost": {"data": 3, "electronics": 4}, "requires": [], "desc": "Débloque la construction de tourelles."},
	"reinforce": {"name": "Parois renforcées", "cost": {"data": 2, "materials": 8}, "requires": [], "desc": "Permet de renforcer les parois (infranchissables pour les fouisseurs)."},
	"chem": {"name": "Chimie des spores", "cost": {"data": 3, "spores": 6}, "requires": [], "desc": "Débloque fumigènes et filtres à spores."},
	"uv_flares": {"name": "Fusées UV", "cost": {"data": 4, "crystal": 6}, "requires": ["chem"], "desc": "Les fusées durent 2× plus longtemps et aveuglent 2× plus."},
	"containment": {"name": "Confinement", "cost": {"data": 5, "samples": 8}, "requires": ["chem"], "desc": "Débloque les capsules de confinement."},
	"explosives": {"name": "Explosifs", "cost": {"data": 4, "metal": 8}, "requires": ["turrets"], "desc": "Débloque les mines de proximité."},
	"alloys": {"name": "Métallurgie des alliages", "cost": {"data": 5, "alloy": 2}, "requires": ["drill"], "desc": "Débloque le plastron en alliage."},
	"overcharge": {"name": "Surcharge cristalline", "cost": {"data": 6, "crystal": 10}, "requires": ["alloys"], "desc": "Équipements d'énergie avancés. Générateurs +2 énergie."},
	"symbiote_dna": {"name": "ADN symbiotique", "cost": {"data": 8, "samples": 15}, "requires": ["containment"], "desc": "+10 % dégâts contre toutes les familles étudiées."},
	"sonar": {"name": "Sonar", "cost": {"data": 5, "electronics": 6}, "requires": ["turrets"], "desc": "Le poste de surveillance révèle les créatures sur la boussole."},
}

# --------------------------------------------------------------------------------------------
# REGIONS
# --------------------------------------------------------------------------------------------
const REGIONS := {
	"city": {"name": "La Mégapole abandonnée", "builder": "res://src/world/regions/city.gd", "min_level": 1,
		"music": "explore_city", "ambience": "amb_city", "desc": "Gratte-ciel éventrés, rues fissurées, métro inondé."},
	"forest": {"name": "La Forêt contaminée", "builder": "res://src/world/regions/forest.gd", "min_level": 3, "requires": "m02_supplies",
		"music": "explore_forest", "ambience": "amb_forest", "desc": "Une forêt vivante noyée dans le brouillard."},
	"lab": {"name": "Le Complexe scientifique", "builder": "res://src/world/regions/lab.gd", "min_level": 5, "requires": "m04_signal",
		"music": "explore_lab", "ambience": "amb_lab", "desc": "Là où tout a commencé. Le Dévoreur y rôde."},
	"depths": {"name": "Les Profondeurs", "builder": "res://src/world/regions/depths.gd", "min_level": 7, "requires": "m06_devourer",
		"music": "explore_depths", "ambience": "amb_depths", "desc": "Cavernes cristallines et galeries inondées."},
	"forbidden": {"name": "La Zone interdite", "builder": "res://src/world/regions/forbidden.gd", "min_level": 12, "requires": "m08_depths_heart",
		"music": "explore_forbidden", "ambience": "amb_forbidden", "desc": "Le cœur de l'invasion. Personne n'en est revenu."},
	"base": {"name": "Base souterraine", "builder": "res://src/world/regions/base.gd", "min_level": 1,
		"music": "base", "ambience": "amb_base", "desc": "Votre refuge, creusé de vos mains."},
}

# --------------------------------------------------------------------------------------------
# MISSIONS
# Objective types: reach, kill (target=enemy id or family or "any"), collect (resource), activate (tag),
# survive (seconds), escape (tag), rescue (npc tag), destroy (tag), boss (enemy id), build (building id),
# dig (count), capture (enemy id), research (count), talk (tag)
# --------------------------------------------------------------------------------------------
const MISSIONS := {
	"m01_first_steps": {"title": "Réveil", "type": "main", "region": "city",
		"desc": "Vous reprenez connaissance dans les ruines. Atteignez le refuge et apprenez à vous battre.",
		"objectives": [
			{"type": "reach", "target": "refuge", "count": 1, "text": "Atteindre le refuge de la place Lumière"},
			{"type": "kill", "target": "crawler", "count": 3, "text": "Éliminer 3 symbiotes rampants"},
			{"type": "dig", "target": "", "count": 6, "text": "Creuser 6 blocs sous le refuge (entrée de la base)"},
			{"type": "build", "target": "generator", "count": 1, "text": "Construire un générateur dans la base"},
		],
		"rewards": {"xp": 150, "metal": 10, "materials": 10, "hero": "bastion"}, "next": ["m02_supplies"]},
	"m02_supplies": {"title": "Ravitaillement", "type": "main", "region": "city",
		"desc": "Le refuge manque de tout. Fouillez la ville et ramenez des fournitures.",
		"objectives": [
			{"type": "collect", "target": "metal", "count": 15, "text": "Récupérer 15 métal"},
			{"type": "collect", "target": "electronics", "count": 4, "text": "Récupérer 4 composants"},
			{"type": "activate", "target": "supply_cache", "count": 2, "text": "Ouvrir 2 caches de ravitaillement"},
			{"type": "build", "target": "workshop", "count": 1, "text": "Construire un atelier"},
		],
		"rewards": {"xp": 220, "crystal": 6, "hero": "spark"}, "next": ["m03_forest_nest", "s01_rooftops", "m04_signal"]},
	"m03_forest_nest": {"title": "Le Nid", "type": "main", "region": "forest",
		"desc": "Des rampants sortent de la forêt chaque nuit. Trouvez leur nid et détruisez-le.",
		"objectives": [
			{"type": "reach", "target": "forest_den", "count": 1, "text": "Trouver la tanière dans le brouillard"},
			{"type": "destroy", "target": "nest", "count": 3, "text": "Détruire 3 nids symbiotiques"},
			{"type": "collect", "target": "spores", "count": 6, "text": "Récolter 6 spores"},
		],
		"rewards": {"xp": 320, "spores": 6, "samples": 4, "hero": "pyra"}, "next": ["m07_spore_queen"]},
	"m04_signal": {"title": "Le Signal", "type": "main", "region": "city",
		"desc": "Une balise émet depuis la station de métro. Quelqu'un est vivant.",
		"objectives": [
			{"type": "reach", "target": "metro", "count": 1, "text": "Descendre dans la station de métro"},
			{"type": "rescue", "target": "scientist", "count": 1, "text": "Escorter le Dr Halvorsen jusqu'au refuge"},
		],
		"rewards": {"xp": 300, "data": 4, "electronics": 4}, "next": ["m05_lab_power"]},
	"m05_lab_power": {"title": "Courant d'urgence", "type": "main", "region": "lab",
		"desc": "Le Dr Halvorsen a besoin des archives du complexe. Réactivez les générateurs. Ne faites pas de bruit.",
		"objectives": [
			{"type": "activate", "target": "lab_generator", "count": 3, "text": "Réactiver 3 générateurs"},
			{"type": "collect_log", "target": "lab", "count": 2, "text": "Trouver 2 journaux audio"},
			{"type": "escape", "target": "lab_exit", "count": 1, "text": "Fuir jusqu'à la porte de sécurité"},
		],
		"rewards": {"xp": 450, "data": 6, "alloy": 1, "hero": "noctis"}, "next": ["m06_devourer", "s03_guardian"]},
	"m06_devourer": {"title": "Ce qui rôde", "type": "main", "region": "lab",
		"desc": "Le Dévoreur garde l'ascenseur vers les profondeurs. Attirez-le dans la chambre de confinement et scellez-la.",
		"objectives": [
			{"type": "activate", "target": "lure_panel", "count": 1, "text": "Activer le leurre de la chambre de confinement"},
			{"type": "survive", "target": "", "count": 25, "text": "Survivre à la traque (25 s)"},
			{"type": "activate", "target": "seal_switch", "count": 1, "text": "Sceller la chambre"},
		],
		"rewards": {"xp": 600, "data": 8, "alloy": 2}, "next": ["m08_depths_heart"]},
	"m07_spore_queen": {"title": "La Reine", "type": "main", "region": "forest",
		"desc": "Les nids détruits ont réveillé leur mère.",
		"objectives": [{"type": "boss", "target": "reine_spores", "count": 1, "text": "Vaincre la Reine des spores"}],
		"rewards": {"xp": 800, "spores": 12, "alloy": 2}, "next": []},
	"m08_depths_heart": {"title": "Le Cœur des profondeurs", "type": "main", "region": "depths",
		"desc": "Les fouisseurs creusent vers votre base. Remontez leurs galeries et trouvez ce qui les guide.",
		"objectives": [
			{"type": "collect", "target": "crystal", "count": 12, "text": "Récolter 12 cristaux"},
			{"type": "kill", "target": "burrower", "count": 4, "text": "Éliminer 4 fouisseurs"},
			{"type": "boss", "target": "colosse_fendu", "count": 1, "text": "Vaincre le Colosse fendu"},
		],
		"rewards": {"xp": 1000, "alloy": 4, "crystal": 10}, "next": ["m09_architect"]},
	"m09_architect": {"title": "L'Architecte", "type": "main", "region": "forbidden",
		"desc": "Au centre de la zone interdite, l'Architecte construit une porte vers l'Abysse.",
		"objectives": [
			{"type": "destroy", "target": "node", "count": 3, "text": "Détruire 3 nœuds d'alimentation"},
			{"type": "boss", "target": "architecte", "count": 1, "text": "Vaincre l'Architecte symbiotique"},
		],
		"rewards": {"xp": 2000, "alloy": 8, "hero": "porteur"}, "next": []},
	# Side / repeatable
	"s01_rooftops": {"title": "Sur les toits", "type": "side", "region": "city",
		"desc": "Des survivants ont laissé des caches sur les toits.",
		"objectives": [{"type": "activate", "target": "roof_cache", "count": 3, "text": "Ouvrir 3 caches sur les toits"}],
		"rewards": {"xp": 200, "alloy": 1, "crystal": 4}, "next": []},
	"s03_guardian": {"title": "Le Gardien", "type": "side", "region": "lab",
		"desc": "Un robot de confinement possédé bloque l'aile des archives.",
		"objectives": [{"type": "boss", "target": "gardien", "count": 1, "text": "Vaincre le Gardien du laboratoire"}],
		"rewards": {"xp": 700, "electronics": 10, "data": 6, "fragments_rift": 10}, "next": []},
	"r01_hunt": {"title": "Chasse nocturne", "type": "repeat", "region": "city",
		"desc": "Éliminez des symbiotes pour sécuriser les rues.",
		"objectives": [{"type": "kill", "target": "any", "count": 10, "text": "Éliminer 10 symbiotes"}],
		"rewards": {"xp": 120, "samples": 2, "fragments_rift": 3}, "next": []},
	"r02_defend": {"title": "Tenir la base", "type": "repeat", "region": "base",
		"desc": "Une colonie de fouisseurs approche. Défendez la base.",
		"objectives": [{"type": "survive", "target": "raid", "count": 60, "text": "Repousser l'attaque (60 s)"}],
		"rewards": {"xp": 200, "metal": 8, "fragments_rift": 4}, "next": []},
	"r03_capture": {"title": "Spécimen vivant", "type": "repeat", "region": "city",
		"desc": "Le laboratoire a besoin d'un spécimen vivant.",
		"objectives": [{"type": "capture", "target": "any", "count": 1, "text": "Capturer une créature étourdie"}],
		"rewards": {"xp": 250, "data": 3, "fragments_rift": 5}, "next": []},
	"r04_depths": {"title": "Galerie inconnue", "type": "repeat", "region": "depths",
		"desc": "Explorez une galerie et ramenez des cristaux.",
		"objectives": [{"type": "collect", "target": "crystal", "count": 8, "text": "Récolter 8 cristaux"}],
		"rewards": {"xp": 180, "alloy": 1, "fragments_rift": 3}, "next": []},
}

const AUDIO_LOGS := {
	"log_lab_1": {"region": "lab", "title": "Dr Halvorsen — Jour 1", "text": "L'échantillon S-7 réagit à la lumière. Il recule. Pour la première fois, nous avons un moyen de le contrôler. Je recommande un éclairage permanent du secteur C."},
	"log_lab_2": {"region": "lab", "title": "Agent Ruiz — Sécurité", "text": "Quelque chose bouge dans les conduits. Les caméras ne voient rien, mais on l'entend. Il nous écoute. Je jure qu'il imite la voix de Pellerin."},
	"log_lab_3": {"region": "lab", "title": "Dr Halvorsen — Jour 9", "text": "Le sujet R-0 a ouvert une brèche. Ce n'est pas un portail : c'est une blessure. Et de l'autre côté, quelque chose a commencé à construire."},
	"log_city_1": {"region": "city", "title": "Message de détresse", "text": "Ici le refuge de la place Lumière. Nous avons de l'eau, de la lumière et une trappe vers les sous-sols. Venez. Ne courez pas dans les rues la nuit."},
	"log_forest_1": {"region": "forest", "title": "Carnet du Dr Mbeki", "text": "Les arbres respirent. Les spores ne tuent pas : elles transforment. La reine se trouve au centre du brouillard, là où même les oiseaux se taisent."},
	"log_depths_1": {"region": "depths", "title": "Foreur anonyme", "text": "On a percé une cavité à -400 mètres. Il y avait des structures. Des colonnes. Comme si quelqu'un avait creusé avant nous. Comme si quelqu'un creusait encore."},
}


func hero(id: String) -> Dictionary:
	return HEROES.get(id, {})


func enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


func mission(id: String) -> Dictionary:
	return MISSIONS.get(id, {})


func rarity_color(r: String) -> Color:
	return RARITIES.get(r, RARITIES.commun).color


func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%s %d" % [RESOURCES[k].name if RESOURCES.has(k) else k, cost[k]])
	return ", ".join(parts)
