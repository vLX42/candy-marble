extends Node
## Autoload: phone tilt controls for the web build.
##
## A tiny script in the page listens to the browser's deviceorientation event
## (on iPhone it asks for permission on the first tap, which iOS requires).
## vector() turns the phone's tilt, relative to how it was held when the level
## started, into a screen-space direction: tip the top edge away to roll up
## the screen, tip the right edge down to roll right. Portrait and landscape
## both work. Without tilt data, touch_stick() gives a drag-anywhere stick.

## Degrees of tilt for full speed (divided by the sensitivity setting).
const FULL_TILT := 18.0
const DEADZONE := 1.5

const JS := """
(function () {
  if (window.candyTilt) return;
  window.candyTilt = { beta: 0, gamma: 0, angle: 0, n: 0, asked: false, denied: false };
  function angle() {
    if (screen.orientation && typeof screen.orientation.angle === 'number') return screen.orientation.angle;
    return typeof window.orientation === 'number' ? window.orientation : 0;
  }
  window.addEventListener('deviceorientation', function (e) {
    if (e.beta === null || e.gamma === null) return;
    var t = window.candyTilt;
    t.beta = e.beta; t.gamma = e.gamma; t.angle = angle(); t.n++;
  });
  function ask() {
    var t = window.candyTilt;
    if (t.asked) return;
    t.asked = true;
    if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
      DeviceOrientationEvent.requestPermission().then(function (r) { if (r !== 'granted') t.denied = true; })
        .catch(function () { t.denied = true; });
    }
  }
  document.addEventListener('touchend', ask, { passive: true });
  document.addEventListener('click', ask);
})();
"""

var _web := false
var _tilt: JavaScriptObject
var _neutral := Vector2.ZERO   # calibrated (right, down) tilt in screen space
var _calibrated := false
var _last_n := -1
var _fresh := 0.0
## Touch stick: where the finger went down and where it is now.
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	if _web:
		JavaScriptBridge.eval(JS, true)
		_tilt = JavaScriptBridge.get_interface("candyTilt")


## True on phones and tablets (touch screen, no need for a keyboard).
func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


## Tilt readings are arriving from the phone.
func active() -> bool:
	return _web and _tilt != null and _fresh > 0.0 and Settings.control_mode == "tilt"


func _process(delta: float) -> void:
	_fresh = maxf(0.0, _fresh - delta)
	if _web and _tilt:
		var n: int = int(_tilt.n)
		if n != _last_n:
			_last_n = n
			_fresh = 1.0
			if not _calibrated:
				calibrate()


## Raw tilt mapped to screen space: x = right edge down, y = top edge towards you.
func _screen_tilt() -> Vector2:
	if _tilt == null:
		return Vector2.ZERO
	return screen_tilt(float(_tilt.beta), float(_tilt.gamma), int(_tilt.angle))


## Device beta / gamma (degrees) and screen rotation angle -> screen-space tilt.
static func screen_tilt(beta: float, gamma: float, angle: int) -> Vector2:
	match posmod(angle, 360):
		90:
			return Vector2(beta, -gamma)
		270:
			return Vector2(-beta, gamma)
		180:
			return Vector2(-gamma, -beta)
		_:
			return Vector2(gamma, beta)


## Remember how the phone is held right now as "flat".
func calibrate() -> void:
	_neutral = _screen_tilt()
	_calibrated = _tilt != null and int(_tilt.n) > 0


## Direction to roll, length 0..1, in screen space (y down).
func vector() -> Vector2:
	if not active():
		return Vector2.ZERO
	return tilt_to_input(_screen_tilt() - _neutral, Settings.tilt_sensitivity)


static func tilt_to_input(t: Vector2, sensitivity: float) -> Vector2:
	var full := FULL_TILT / maxf(sensitivity, 0.2)
	var out := Vector2.ZERO
	for axis in 2:
		var v := t[axis]
		var s := signf(v)
		var m := maxf(0.0, absf(v) - DEADZONE) / (full - DEADZONE)
		out[axis] = s * minf(m, 1.0)
	return out.limit_length(1.0)


# --- touch stick (fallback) ------------------------------------------------------

func stick_vector() -> Vector2:
	if _stick_id < 0:
		return Vector2.ZERO
	var d := (_stick_pos - _stick_origin) / 90.0
	return d.limit_length(1.0) if d.length() > 0.12 else Vector2.ZERO


func stick_state() -> Array:
	return [_stick_id >= 0, _stick_origin, _stick_pos]


## Called by the game with touches that no button took.
func handle_touch(event: InputEvent) -> bool:
	var t := event as InputEventScreenTouch
	if t:
		if t.pressed and _stick_id < 0:
			_stick_id = t.index
			_stick_origin = t.position
			_stick_pos = t.position
			return true
		if not t.pressed and t.index == _stick_id:
			_stick_id = -1
			return true
	var d := event as InputEventScreenDrag
	if d and d.index == _stick_id:
		_stick_pos = d.position
		return true
	return false


func release_stick() -> void:
	_stick_id = -1


## Web only: publish the marble's state on window.candyTilt for browser tests.
func report(pos: Vector3, level_time: float, input: Vector2) -> void:
	if _tilt == null:
		return
	_tilt.ballx = pos.x
	_tilt.bally = pos.y
	_tilt.ballz = pos.z
	_tilt.time = level_time
	_tilt.active = active()
	_tilt.inx = input.x
	_tilt.iny = input.y


## Tilt data asked for but not allowed (iPhone "Don't allow").
func denied() -> bool:
	return _web and _tilt != null and bool(_tilt.denied)
