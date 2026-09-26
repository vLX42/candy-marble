extends Node
## Autoload: remembers display settings and toggles fullscreen with F11 or
## Alt+Enter from anywhere in the game.

const PATH := "user://settings.cfg"

var fullscreen := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", false)
	_apply()


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)


func _apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_F11 or (key.physical_keycode == KEY_ENTER and key.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
