extends Node
## Player settings (graphics, audio, controls, horror intensity). Stored in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Économique", "Équilibré", "Élevé", "Ultra"]

var data := {
	"quality": -1,              # -1 = auto-detect on first launch
	"render_scale": 1.0,
	"fps_cap": 60,
	"shadows": true,
	"outlines": true,
	"particles": 1.0,           # density multiplier
	"draw_distance": 1.0,
	"post_fx": true,
	"vol_master": 0.9,
	"vol_music": 0.7,
	"vol_sfx": 0.9,
	"vol_ambience": 0.8,
	"vol_scare": 0.8,           # volume of sudden horror stings
	"cam_sensitivity": 1.0,
	"cam_invert_y": false,
	"button_scale": 1.0,
	"ui_opacity": 0.85,
	"aim_assist": 0.7,
	"auto_sprint": true,        # pushing the stick to the edge sprints
	"shake": 1.0,               # camera shake intensity
	"horror_fx": 1.0,           # vignette / distortion / grain intensity
	"vibration": true,
	"show_fps": false,
	"layout": {},               # custom touch button positions: name -> [x, y] (anchor-relative)
}

const PRESETS := [
	{"render_scale": 0.7, "shadows": false, "outlines": false, "particles": 0.4, "draw_distance": 0.6, "post_fx": false, "fps_cap": 30},
	{"render_scale": 0.85, "shadows": true, "outlines": true, "particles": 0.7, "draw_distance": 0.8, "post_fx": true, "fps_cap": 30},
	{"render_scale": 1.0, "shadows": true, "outlines": true, "particles": 1.0, "draw_distance": 1.0, "post_fx": true, "fps_cap": 60},
	{"render_scale": 1.0, "shadows": true, "outlines": true, "particles": 1.4, "draw_distance": 1.35, "post_fx": true, "fps_cap": 60},
]


func _ready() -> void:
	load_settings()
	if int(data.quality) < 0:
		apply_preset(detect_quality())
	apply()


func detect_quality() -> int:
	## Conservative guess from the GPU name and core count. Ultra is never auto-selected.
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var cores := OS.get_processor_count()
	if OS.has_feature("mobile") or OS.has_feature("android"):
		if gpu.contains("adreno (tm) 7") or gpu.contains("adreno (tm) 8") or gpu.contains("immortalis") or gpu.contains("mali-g7"):
			return 2
		if cores >= 8 and (gpu.contains("adreno (tm) 6") or gpu.contains("mali-g5")):
			return 1
		return 0
	if gpu.contains("llvmpipe") or gpu.contains("swiftshader"):
		return 1
	return 2


func apply_preset(q: int) -> void:
	q = clampi(q, 0, PRESETS.size() - 1)
	data.quality = q
	for k in PRESETS[q]:
		data[k] = PRESETS[q][k]


func set_value(key: String, value) -> void:
	data[key] = value
	apply()
	save_settings()


func apply() -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(float(data.render_scale), 0.5, 1.0)
		vp.msaa_3d = Viewport.MSAA_2X if int(data.quality) >= 2 else Viewport.MSAA_DISABLED
	Engine.max_fps = int(data.fps_cap)
	Mats.outline_enabled = bool(data.outlines)
	for bus in [["Master", "vol_master"], ["Music", "vol_music"], ["SFX", "vol_sfx"], ["Ambience", "vol_ambience"], ["Scare", "vol_scare"]]:
		var idx := AudioServer.get_bus_index(bus[0])
		if idx >= 0:
			var v := float(data[bus[1]])
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)
	changed.emit()


func get_v(key: String, default = null):
	return data.get(key, default)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in data.keys():
		if cfg.has_section_key("settings", k):
			data[k] = cfg.get_value("settings", k)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in data:
		cfg.set_value("settings", k, data[k])
	cfg.save(PATH)
