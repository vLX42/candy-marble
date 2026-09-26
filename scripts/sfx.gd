class_name Sfx
extends Node
## Tiny synthesized sound effects, so the prototype has audio without assets.
## Replace with real samples later by swapping the streams in _ready().

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []


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
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db: float = -6.0) -> void:
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db
			p.play()
			return


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
