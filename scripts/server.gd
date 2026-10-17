extends Node
## The dedicated server's scene: nothing to draw, the Net autoload does the work.
## Prints a heartbeat to the log now and then (docker logs).

var _t := 0.0


func _ready() -> void:
	Engine.physics_ticks_per_second = 10


func _process(delta: float) -> void:
	_t += delta
	if _t > 300.0:
		_t = 0.0
		print("[%s] %d in the lobby, %s" % [Time.get_datetime_string_from_system(), Net.players.size(), Net.phase])
