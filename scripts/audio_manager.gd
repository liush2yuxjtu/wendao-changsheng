extends Node
## 生成式背景音乐（古琴五声音阶随机游走 + 低音铺底）与音效。音频由 tools/make_audio.py 合成。

const SFX_NAMES := ["tap", "break_ok", "break_major", "break_fail", "event", "win", "lose", "item", "craft", "death"]

var muted := false: set = set_muted

var _qin: Array[AudioStream] = []
var _sfx := {}
var _music_pool: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _drone: AudioStreamPlayer
var _t := 0.0
var _next := 2.0
var _idx := 4
var _phrase := 0


func _ready() -> void:
	for i in 10:
		_qin.append(load("res://assets/audio/qin_%02d.ogg" % i))
	for n in SFX_NAMES:
		_sfx[n] = load("res://assets/audio/sfx_%s.ogg" % n)
	for i in 6:
		_music_pool.append(_new_player())
	for i in 4:
		_sfx_pool.append(_new_player())
	_drone = _new_player()
	var ds: AudioStreamOggVorbis = load("res://assets/audio/drone.ogg")
	ds.loop = true
	_drone.stream = ds
	_drone.volume_db = -22.0
	_drone.play()


func _new_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func set_muted(v: bool) -> void:
	muted = v
	AudioServer.set_bus_mute(0, v)


func _process(delta: float) -> void:
	if muted:
		return
	_t += delta
	if _t >= _next:
		_t = 0.0
		_step()


## 一句 4~7 个音，句间留白 3~6 秒；音高在五声音阶上随机游走
func _step() -> void:
	if _phrase <= 0:
		_phrase = randi_range(4, 7)
		_next = randf_range(3.0, 6.0)
		return
	_phrase -= 1
	_idx = clampi(_idx + [-2, -1, -1, 0, 1, 1, 2].pick_random(), 0, _qin.size() - 1)
	_play(_music_pool, _qin[_idx], randf_range(-13.0, -8.0), randf_range(0.997, 1.003))
	if randf() < 0.2 and _idx >= 5:
		_play(_music_pool, _qin[_idx - 5], -15.0)
	_next = [0.6, 0.9, 0.9, 1.2, 1.2, 1.8].pick_random()


func play_sfx(sfx_name: String) -> void:
	if muted or not _sfx.has(sfx_name):
		return
	_play(_sfx_pool, _sfx[sfx_name], -4.0)


func _play(pool: Array[AudioStreamPlayer], stream: AudioStream, db: float, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = pool[0]
	for q in pool:
		if not q.playing:
			p = q
			break
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
