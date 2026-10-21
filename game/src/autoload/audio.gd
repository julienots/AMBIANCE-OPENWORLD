extends Node
## Audio manager: buses, pooled 2D/3D one-shots with random variants, loops,
## state-driven music crossfades (explore / combat / chase / boss / silence) and ambience.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const AMB_DIR := "res://assets/audio/ambience"
const POOL_3D := 20
const POOL_2D := 10

var _variants := {}          # base name -> Array[AudioStream]
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur := ""
var _amb: AudioStreamPlayer
var _amb_cur := ""
var explore_track := "explore_city"
var _state := "explore"
var _state_t := 0.0
var _state_req := {}         # state -> expiry time (seconds since start)
var _reverb: AudioEffectReverb
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_index_sfx()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.panning_strength = 1.0
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80
		add_child(m)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	add_child(_amb)
	Settings.apply()


func _setup_buses() -> void:
	for b in ["Music", "SFX", "Ambience", "Scare"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.4
	_reverb.wet = 0.08
	_reverb.dry = 1.0
	AudioServer.add_bus_effect(sfx, _reverb)
	var lim := AudioEffectHardLimiter.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), lim)


func set_space(room: float, wet: float) -> void:
	## Region acoustics: small for streets, large and wet for caves.
	_reverb.room_size = room
	_reverb.wet = wet


func _index_sfx() -> void:
	for file in _list(SFX_DIR):
		if not file.ends_with(".wav"):
			continue
		var base := file.get_basename()
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			base = parts[0]
		var st: AudioStream = load(SFX_DIR + "/" + file)
		if st:
			if not _variants.has(base):
				_variants[base] = []
			_variants[base].append(st)


func _list(dir: String) -> PackedStringArray:
	return ResourceLoader.list_directory(dir)


func has_sound(name: String) -> bool:
	return _variants.has(name)


func stream(name: String) -> AudioStream:
	var v: Array = _variants.get(name, [])
	return v.pick_random() if not v.is_empty() else null


func play(name: String, vol_db := 0.0, pitch_var := 0.06, bus := "SFX") -> AudioStreamPlayer:
	var st := stream(name)
	if st == null:
		return null
	var p: AudioStreamPlayer = _pool2d[0]
	for c in _pool2d:
		if not c.playing:
			p = c
			break
	p.stream = st
	p.volume_db = vol_db
	p.bus = bus
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
	return p


func play_at(name: String, pos: Vector3, vol_db := 0.0, max_dist := 60.0, pitch_var := 0.08, bus := "SFX") -> AudioStreamPlayer3D:
	var st := stream(name)
	if st == null:
		return null
	var p: AudioStreamPlayer3D = null
	var oldest := -1.0
	for c in _pool3d:
		if not c.playing:
			p = c
			break
		if c.get_playback_position() > oldest:
			oldest = c.get_playback_position()
			p = c
	p.stream = st
	p.global_position = pos
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.bus = bus
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
	return p


func attach_loop(parent: Node3D, name: String, vol_db := 0.0, max_dist := 30.0) -> AudioStreamPlayer3D:
	## Loop owned by a scene node (generator hum, creature breathing…). Freed with its parent.
	var st := stream(name)
	if st == null:
		return null
	st = st.duplicate()
	if st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * st.mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.unit_size = 5.0
	p.bus = "SFX"
	p.autoplay = true
	parent.add_child(p)
	return p


func scare(name: String, vol_db := 0.0) -> void:
	## Sudden horror sting routed through the "Scare" bus (its volume is a user setting).
	play(name, vol_db, 0.02, "Scare")


# ------------------------------------------------------------------------- music

func set_region_music(track: String, amb: String) -> void:
	explore_track = track
	_state_req.clear()
	_state = ""
	_apply_state("explore")
	set_ambience(amb)


func request_state(state: String, hold := 3.0) -> void:
	## Called repeatedly by gameplay (e.g. while enemies are aggressive). Highest priority wins.
	_state_req[state] = _clock + hold


func _process(delta: float) -> void:
	_clock += delta
	var order := ["boss", "chase", "silence", "combat"]
	var want := "explore"
	for s in order:
		if _state_req.get(s, -1.0) > _clock:
			want = s
			break
	if want != _state:
		_state_t += delta
		# Leaving a tense state waits a bit so the music does not flicker.
		if _state_t > (2.5 if _state in ["combat", "chase", "boss"] else 0.0):
			_apply_state(want)
	else:
		_state_t = 0.0


func _apply_state(s: String) -> void:
	_state = s
	_state_t = 0.0
	match s:
		"explore": play_music(explore_track, 2.5)
		"combat": play_music("combat", 0.8)
		"chase": play_music("chase", 0.3)
		"boss": play_music("boss", 1.0)
		"silence": play_music("", 1.5)


func current_state() -> String:
	return _state


func play_music(name: String, fade := 1.5) -> void:
	if name == _music_cur:
		return
	_music_cur = name
	var old := _music_a if _music_a.playing and _music_a.volume_db > -40 else _music_b
	var new := _music_b if old == _music_a else _music_a
	var tw := create_tween().set_parallel(true)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, fade)
		tw.chain().tween_callback(old.stop)
	if name == "":
		return
	var st: AudioStream = load("%s/%s.ogg" % [MUSIC_DIR, name])
	if st == null:
		return
	st = st.duplicate()
	if st is AudioStreamOggVorbis:
		st.loop = true
	new.stream = st
	new.volume_db = -40.0
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", 0.0, fade)


func set_ambience(name: String) -> void:
	if name == _amb_cur:
		return
	_amb_cur = name
	if name == "":
		_amb.stop()
		return
	var st: AudioStream = load("%s/%s.ogg" % [AMB_DIR, name])
	if st == null:
		return
	st = st.duplicate()
	st.loop = true
	_amb.stream = st
	_amb.volume_db = -30
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", 0.0, 2.0)


func stop_all() -> void:
	play_music("", 1.0)
	set_ambience("")
