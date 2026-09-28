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
## Show a see-through marble replaying your best run on each level.
var ghost := true
## Phones: "tilt" (gyroscope) or "stick" (drag anywhere).
var control_mode := "tilt"
var tilt_sensitivity := 1.0
## Arcade timer: one countdown for the whole run; each level adds time,
## leftovers carry over, zero is game over (like the 1984 arcade game).
var arcade := false


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var cfg := ConfigFile.new()
	var loaded := cfg.load(PATH) == OK
	if not loaded and DisplayServer.is_touchscreen_available():
		# Phones: start with the lighter graphics.
		graphics_high = false
	if loaded:
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		camera_follow = cfg.get_value("camera", "follow", camera_follow)
		zoom = cfg.get_value("camera", "zoom", zoom)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		graphics_high = cfg.get_value("display", "graphics_high", graphics_high)
		ghost = cfg.get_value("game", "ghost", ghost)
		control_mode = cfg.get_value("game", "control_mode", control_mode)
		tilt_sensitivity = cfg.get_value("game", "tilt_sensitivity", tilt_sensitivity)
		arcade = cfg.get_value("game", "arcade", arcade)
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
	cfg.set_value("game", "ghost", ghost)
	cfg.set_value("game", "control_mode", control_mode)
	cfg.set_value("game", "tilt_sensitivity", tilt_sensitivity)
	cfg.set_value("game", "arcade", arcade)
	cfg.save(PATH)


func _apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	if DisplayServer.get_name() == "headless":
		return
	# "-- --windowed": never go fullscreen this run (tests, screenshots).
	if "--windowed" in OS.get_cmdline_user_args():
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


## The web build runs on the Compatibility renderer (WebGL 2). Its sky shader
## can't draw the screen gradient there (it comes out one flat colour), so on
## that renderer the sky you see is a gradient card fixed far behind the world,
## facing the camera and filling the view. The real sky stays on behind it for
## the reflections that light the walls. The card's stops are tuned so the
## screen shows what Forward+ shows (measured top to bottom), and the ambient
## light is retuned to match. Call this on every Environment after setting it
## up; it does nothing on Forward+.
const COMPAT_AMBIENT := 0.85   # measured best against Forward+ on the title screen
const SKY_ON_SCREEN := ["#b6dcf3", "#b9dcf2", "#c3daef", "#d0d9ed", "#dbd5ea", "#e6d1e6", "#eecfe3", "#f5cde2", "#f6ccdf"]


static func match_renderer(env: Environment, parent: Node) -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	env.ambient_light_energy *= COMPAT_AMBIENT
	parent.add_child(SkyCard.new())


## The web renderer's sky: a camera-facing gradient card at the far end of the view.
class SkyCard extends MeshInstance3D:
	func _ready() -> void:
		name = "SkyBackdrop"
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var grad := Gradient.new()
		var offsets := PackedFloat32Array()
		var colors := PackedColorArray()
		for k in SKY_ON_SCREEN.size():
			offsets.append(k / float(SKY_ON_SCREEN.size() - 1))
			colors.append(Color(SKY_ON_SCREEN[k]))
		grad.offsets = offsets
		grad.colors = colors
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 4
		tex.height = 256
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = tex
		mat.disable_fog = true
		mat.texture_repeat = false   # or the top and bottom rows blend into each other
		mesh = QuadMesh.new()
		material_override = mat

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var view := get_viewport().get_visible_rect().size
		var h := cam.size if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else 100.0
		var w := h * view.x / maxf(view.y, 1.0)
		var depth := cam.far * 0.9
		global_transform = cam.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3(w, h, 1.0)), Vector3(0, 0, -depth))


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
