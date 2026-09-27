class_name Sfx
extends Node
## Sound effects. Uses the designed sounds in audio/sfx/*.wav (made by
## tools/make_sfx.py) and falls back to tiny synthesized ones. Every play gets
## a slightly random pitch so repeated sounds don't feel mechanical. Also runs
## the marble's rolling loop.

const RATE := 22050
const FILES := ["roll", "land", "bonk", "pop", "splat", "boing", "boost", "checkpoint", "goal", "timeup",
	"tick", "go", "ui_hover", "ui_click", "ui_back", "coin", "cannon", "rush", "goo", "whoosh"]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _roll: AudioStreamPlayer
var _roll_level := 0.0


func _ready() -> void:
	_streams = {
		"boing": _wav(_sweep(0.28, 520.0, 170.0, "sine", 28.0)),
		"pop": _wav(_mix(_noise(0.12), _sweep(0.18, 320.0, 70.0, "sine"))),
		"boost": _wav(_sweep(0.35, 180.0, 900.0, "square")),
		"checkpoint": _wav(_notes([660.0, 990.0], 0.09)),
		"goal": _wav(_notes([523.0, 659.0, 784.0, 1047.0], 0.1)),
		"timeup": _wav(_notes([392.0, 330.0, 262.0], 0.18)),
		"tick": _wav(_sweep(0.04, 1200.0, 1200.0, "sine")),
		"coin": _wav(_notes([1319.0, 1760.0], 0.06)),
	}
	for n: String in FILES:
		var path := "res://audio/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	if _streams.has("roll"):
		var loop: AudioStreamWAV = (_streams.roll as AudioStreamWAV).duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = loop.data.size() / 2
		_roll = AudioStreamPlayer.new()
		_roll.stream = loop
		_roll.bus = "SFX"
		_roll.volume_db = -60.0
		add_child(_roll)


func has(sound: String) -> bool:
	return _streams.has(sound)


func play(sound: String, volume_db: float = -6.0, pitch_spread: float = 0.06) -> void:
	if not _streams.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
			p.play()
			return


## Rolling rumble: louder and higher the faster the marble rolls on the ground.
func set_roll(speed: float, grounded: bool, delta: float) -> void:
	if _roll == null:
		return
	var target := clampf(speed / 9.0, 0.0, 1.0) if grounded else 0.0
	_roll_level = move_toward(_roll_level, target, delta * (6.0 if target > _roll_level else 3.0))
	if _roll_level < 0.02:
		if _roll.playing:
			_roll.stop()
		return
	if not _roll.playing:
		_roll.play()
	_roll.volume_db = linear_to_db(_roll_level * 0.8)
	_roll.pitch_scale = 0.75 + _roll_level * 0.6


func stop_roll() -> void:
	_roll_level = 0.0
	if _roll:
		_roll.stop()


func _sweep(dur: float, f0: float, f1: float, wave: String, vibrato: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t) * (1.0 + 0.12 * sin(TAU * vibrato * i / RATE))
		phase += f / RATE
		var s := sin(TAU * phase)
		if wave == "square":
			s = clampf(s * 3.0, -1.0, 1.0) * 0.6
		out[i] = s * _env(i, n)
	return out


func _noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = randf_range(-1.0, 1.0) * _env(i, n) * 0.6
	return out


func _notes(freqs: Array, each: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f: float in freqs:
		var n := int(each * RATE)
		for i in n:
			# Triangle wave, soft and toy-like.
			var ph := fmod(f * i / RATE, 1.0)
			out.append((4.0 * absf(ph - 0.5) - 1.0) * _env(i, n) * 0.8)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(a.size(), b.size()))
	for i in out.size():
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out


func _env(i: int, n: int) -> float:
	var attack := minf(1.0, i / (0.005 * RATE))
	return attack * pow(1.0 - float(i) / n, 2.0)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
