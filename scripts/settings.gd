extends Node
## Autoload: player settings, saved to user://settings.cfg.
## F11 or Alt+Enter toggles fullscreen from anywhere.

signal changed

const PATH := "user://settings.cfg"
const ZOOMS := [14.0, 18.0, 23.0]
const ZOOM_NAMES := ["Close", "Normal", "Far"]

var fullscreen := false
## Rotate the playfield so the track ahead of the ball points up the screen.
var camera_follow := true
var zoom := 1
var music_volume := 0.8
var sfx_volume := 0.9
## High = SSAO, glow and soft shadows. Low for weaker machines.
var graphics_high := true


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		camera_follow = cfg.get_value("camera", "follow", camera_follow)
		zoom = cfg.get_value("camera", "zoom", zoom)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		graphics_high = cfg.get_value("display", "graphics_high", graphics_high)
	_apply()


func camera_size() -> float:
	return ZOOMS[clampi(zoom, 0, ZOOMS.size() - 1)]


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_apply()
	save()
	changed.emit()


func toggle_fullscreen() -> void:
	set_value("fullscreen", not fullscreen)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "graphics_high", graphics_high)
	cfg.set_value("camera", "follow", camera_follow)
	cfg.set_value("camera", "zoom", zoom)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(PATH)


func _apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


## Applies the graphics setting to an Environment and a sun.
func apply_graphics(env: Environment, sun: DirectionalLight3D) -> void:
	env.ssao_enabled = graphics_high
	env.glow_enabled = graphics_high
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if graphics_high \
			else DirectionalLight3D.SHADOW_ORTHOGONAL


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_F11 or (key.physical_keycode == KEY_ENTER and key.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
