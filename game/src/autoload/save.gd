extends Node
## Robust save system.
## - JSON payload wrapped in an envelope {version, checksum, saved_at, data}
## - atomic write: write to .tmp, verify by reading back, rotate current -> .bak, rename .tmp -> current
## - on load: verify checksum; fall back to .bak if the main file is corrupt
## - forward migrations keyed by version: older saves are upgraded, never erased

const VERSION := 3
const DIR := "user://saves"

var last_error := ""


func slot_path(slot: int) -> String:
	return "%s/slot%d.json" % [DIR, slot]


func has_save(slot := 0) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


func write(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var payload := JSON.stringify(data)
	var env := {"version": VERSION, "checksum": payload.md5_text(), "saved_at": Time.get_unix_time_from_system(), "data": payload}
	var text := JSON.stringify(env)
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "Impossible d'écrire %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
		push_error(last_error)
		return false
	f.store_string(text)
	f.close()
	# Verify what actually reached the disk before replacing the previous save.
	if _read_envelope(tmp).is_empty():
		last_error = "Vérification de la sauvegarde échouée"
		push_error(last_error)
		return false
	var da := DirAccess.open(DIR)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			da.remove(path.get_file() + ".bak")
		da.rename(path.get_file(), path.get_file() + ".bak")
	var err := da.rename(tmp.get_file(), path.get_file())
	if err != OK:
		last_error = "Renommage échoué: %s" % error_string(err)
		push_error(last_error)
		return false
	return true


func read(slot := 0) -> Dictionary:
	## Returns the migrated data dictionary, or {} if no valid save exists.
	var path := slot_path(slot)
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if not FileAccess.file_exists(candidate):
			continue
		var env := _read_envelope(candidate)
		if env.is_empty():
			push_warning("Sauvegarde corrompue ignorée: " + candidate)
			continue
		var data = JSON.parse_string(env.data)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		return migrate(data, int(env.get("version", 1)))
	return {}


func _read_envelope(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var env = JSON.parse_string(text)
	if typeof(env) != TYPE_DICTIONARY or not env.has("data") or not env.has("checksum"):
		return {}
	if String(env.data).md5_text() != env.checksum:
		return {}
	return env


func delete(slot := 0) -> void:
	var da := DirAccess.open(DIR)
	if da == null:
		return
	for suffix in ["", ".bak", ".tmp"]:
		var name := slot_path(slot).get_file() + suffix
		if da.file_exists(name):
			da.remove(name)


func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var v := from_version
	if v < 2:
		# v2 introduced per-hero equipment and the codex structure.
		for id in data.get("heroes", {}):
			var h: Dictionary = data.heroes[id]
			if not h.has("equipment"):
				h["equipment"] = {"arme": "", "armure": "", "gadget": ""}
		if not data.has("codex"):
			data["codex"] = {}
		v = 2
	if v < 3:
		# v3 introduced research queues and base power bookkeeping.
		var base: Dictionary = data.get("base", {})
		if not base.has("failures"):
			base["failures"] = []
		if not data.has("research"):
			data["research"] = {"done": []}
		data["base"] = base
		v = 3
	data["version"] = VERSION
	return data
