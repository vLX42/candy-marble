class_name Scores
extends RefCounted
## Local high scores (fastest times) in user://scores.cfg.
## Keys: "level:<title>" for single levels, "run" for a full playthrough.
## Lower is better.

const PATH := "user://scores.cfg"
const KEEP := 5

var persist := true
var _cfg := ConfigFile.new()


func _init(save_to_disk: bool = true) -> void:
	persist = save_to_disk
	if persist:
		_cfg.load(PATH)


func top(key: String) -> Array:
	return _cfg.get_value("scores", key, [])


func best(key: String) -> float:
	var t := top(key)
	return t[0] if t.size() > 0 else -1.0


## Adds a time and returns its rank (0 = new best) or -1 if it didn't make the top list.
func submit(key: String, time: float) -> int:
	var t := top(key).duplicate()
	t.append(snappedf(time, 0.01))
	t.sort()
	t = t.slice(0, KEEP)
	_cfg.set_value("scores", key, t)
	if persist:
		_cfg.save(PATH)
	return t.find(snappedf(time, 0.01))


static func format_board(times: Array, highlight: int) -> String:
	var lines: PackedStringArray = []
	for k in times.size():
		lines.append("%s%d.  %.2f s" % ["> " if k == highlight else "   ", k + 1, times[k]])
	return "\n".join(lines)
