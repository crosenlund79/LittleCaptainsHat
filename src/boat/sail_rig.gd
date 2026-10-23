class_name SailRig
extends Node2D
## The deck's sails, seen from above: mainsail on the boom, jib on the
## forestay and, on deep downwind angles, the spinnaker forward of the bow.
##
## The rig only presents state: it reads the propulsion state (mode, true wind
## angle, spinnaker) from GameSession every frame and never decides anything
## itself, so it looks the same whichever scene was open when the state changed.
## Trim follows the wind smoothly; on entering the scene it snaps to the
## current state (no animation from a stale pose).
##
## Boat frame: +x is forward (bow at x = 500), -y is port, +y is starboard.
## Sails lie on the leeward side: wind from starboard puts them to port.

const SAIL := Color("#EFE5CC")
const SAIL_SHADE := Color("#D8CDB1")
const SAIL_EDGE := Color("#8C7E5E")
const BOOM := Color("#5E6B70")
const COVER := Color("#3F7880")
const SPINNAKER := Color("#C79F6D")
const SPINNAKER_STRIPE := Color("#EFE5CC")
const SHEET := Color(0.937, 0.898, 0.8, 0.7)

## Mast step and boom geometry (matches the deck scene's mast fixture).
const MAST := Vector2(182, 0)
const BOOM_LENGTH := 400.0
const JIB_TACK := Vector2(470, 0)
const JIB_FOOT := 290.0
## How far the spinnaker's leading edge bellies forward of its tack-clew line.
const SPINNAKER_DEPTH := 520.0
## Main: boom angle from the centreline = clamp(|twa| * 0.55 - 17, 5, 50) degrees.
const MAIN_MIN_DEG := 5.0
const MAIN_MAX_DEG := 50.0
const JIB_MIN_DEG := 6.0
const JIB_MAX_DEG := 38.0
## How fast the trim follows the wind (1/s) and the spinnaker hoists/drops.
const TRIM_RATE := 1.6
const HOIST_RATE := 0.8

## Current pose (eased towards the target).
var main_angle_deg := 0.0      # signed: - = boom to port, + = boom to starboard
var jib_angle_deg := 0.0
var set_amount := 0.0          # 0 = furled, 1 = sails drawing
var spinnaker_amount := 0.0    # 0 = down, 1 = fully set
var _twa := 0.0


func _ready() -> void:
	snap()


func _process(delta: float) -> void:
	var target := _target()
	var k := 1.0 - exp(-TRIM_RATE * delta)
	main_angle_deg = lerpf(main_angle_deg, target.main, k)
	jib_angle_deg = lerpf(jib_angle_deg, target.jib, k)
	set_amount = move_toward(set_amount, target.set, delta * HOIST_RATE * 1.5)
	spinnaker_amount = move_toward(spinnaker_amount, target.spinnaker, delta * HOIST_RATE)
	_twa = target.twa
	queue_redraw()


## Jumps to the current state without animating (scene entry, loading).
func snap() -> void:
	var target := _target()
	main_angle_deg = target.main
	jib_angle_deg = target.jib
	set_amount = target.set
	spinnaker_amount = target.spinnaker
	_twa = target.twa
	queue_redraw()


## Side the sails are on: "port", "starboard" or "" when furled/centred.
func get_sail_side() -> String:
	if set_amount < 0.5 or absf(main_angle_deg) < 0.5:
		return ""
	return "port" if main_angle_deg < 0.0 else "starboard"


func is_furled() -> bool:
	return set_amount < 0.01


func is_spinnaker_visible() -> bool:
	return spinnaker_amount > 0.01


## Target pose for the current propulsion state.
func _target() -> Dictionary:
	var target := {"main": 0.0, "jib": 0.0, "set": 0.0, "spinnaker": 0.0, "twa": 0.0}
	if not GameSession.is_active() or not GameSession.is_underway():
		return target
	var state := GameSession.get_propulsion()
	if not state.initialised or not state.sails_set():
		return target
	var twa := state.true_wind_angle
	# Leeward: wind from starboard (+) -> sails to port (-).
	var lee := -1.0 if twa >= 0.0 else 1.0
	var a := absf(twa)
	target.main = lee * clampf(a * 0.55 - 17.0, MAIN_MIN_DEG, MAIN_MAX_DEG)
	target.jib = lee * clampf(a * 0.4 - 10.0, JIB_MIN_DEG, JIB_MAX_DEG)
	target.set = 1.0
	target.spinnaker = 1.0 if state.spinnaker else 0.0
	target.twa = twa
	return target


func _draw() -> void:
	_draw_jib()
	_draw_main()
	if spinnaker_amount > 0.01:
		_draw_spinnaker()


func _draw_main() -> void:
	var angle := deg_to_rad(main_angle_deg)
	var clew := MAST + Vector2(-cos(angle), sin(angle)) * BOOM_LENGTH
	if set_amount > 0.01:
		# Sail: from the mast to the boom end, bellied to leeward.
		var lee := signf(main_angle_deg) if main_angle_deg != 0.0 else 1.0
		var chord := clew - MAST
		var normal := Vector2(-chord.y, chord.x).normalized()
		if normal.y * lee < 0.0:
			normal = -normal
		var belly := normal * chord.length() * 0.13 * set_amount
		var outline := _curve(MAST, clew, (MAST + clew) / 2.0 + belly * 2.0, 18)
		outline.append_array(_inner(_curve(clew, MAST, (MAST + clew) / 2.0 + belly * 0.4, 8)))
		draw_colored_polygon(outline, Color(SAIL, set_amount))
		draw_polyline(_curve(MAST, clew, (MAST + clew) / 2.0 + belly * 2.0, 18), Color(SAIL_EDGE, set_amount), 2.0, true)
		# Battens.
		for t in [0.3, 0.55, 0.8]:
			var on_boom := MAST.lerp(clew, t)
			var on_leech := _bezier(MAST, (MAST + clew) / 2.0 + belly * 2.0, clew, t)
			draw_line(on_boom, on_leech, Color(SAIL_SHADE, set_amount), 2.0, true)
		# Main sheet to the traveller in the cockpit.
		draw_line(clew, Vector2(-360, 0), Color(SHEET, set_amount * 0.8), 1.5, true)
	# Boom (and the sail cover on it when furled).
	draw_line(MAST, clew, BOOM, 7.0, true)
	if set_amount < 0.99:
		draw_line(MAST + (clew - MAST) * 0.03, clew - (clew - MAST) * 0.04, Color(COVER, 1.0 - set_amount), 16.0, true)


func _draw_jib() -> void:
	if set_amount <= 0.01 or spinnaker_amount >= 0.99:
		# Rolled up on the forestay (roller furling).
		draw_line(MAST + Vector2(40, 0), JIB_TACK, Color(SAIL_SHADE, 0.9), 6.0, true)
		return
	var shown := set_amount * (1.0 - spinnaker_amount)
	var angle := deg_to_rad(jib_angle_deg)
	var clew := JIB_TACK + Vector2(-cos(angle), sin(angle)) * JIB_FOOT
	var lee := signf(jib_angle_deg) if jib_angle_deg != 0.0 else 1.0
	var chord := clew - JIB_TACK
	var normal := Vector2(-chord.y, chord.x).normalized()
	if normal.y * lee < 0.0:
		normal = -normal
	var leech_control := (JIB_TACK + clew) / 2.0 + normal * chord.length() * 0.3
	var outline := _curve(JIB_TACK, clew, leech_control, 16)
	outline.append_array(_inner(_curve(clew, JIB_TACK, (JIB_TACK + clew) / 2.0 + normal * chord.length() * 0.05, 6)))
	draw_colored_polygon(outline, Color(SAIL, shown))
	draw_polyline(outline, Color(SAIL_EDGE, shown), 2.0, true)
	# Jib sheet to the leeward winch.
	draw_line(clew, Vector2(-250, 120 * lee), Color(SHEET, shown * 0.8), 1.5, true)
	draw_line(MAST + Vector2(40, 0), JIB_TACK, Color(SAIL_SHADE, 1.0 - shown), 6.0, true)


## The spinnaker: a big crescent-shaped sail flying ahead of the bow, its pole
## out to windward and its clew sheeted to the leeward quarter. On a broad
## reach it is swung out to leeward; dead downwind it is centred ahead.
func _draw_spinnaker() -> void:
	var lee := -1.0 if _twa >= 0.0 else 1.0
	var run := clampf((absf(_twa) - 115.0) / 65.0, 0.0, 1.0)
	var amount := spinnaker_amount
	var tack := Vector2(lerpf(440.0, 340.0, run), -lee * lerpf(70.0, 185.0, run))
	var clew := Vector2(lerpf(300.0, 340.0, run), lee * lerpf(225.0, 185.0, run))
	var swing := deg_to_rad(lerpf(32.0, 0.0, run))
	var ahead := Vector2(cos(swing), lee * sin(swing))
	# Hoisting: grow out from the bow.
	var anchor := JIB_TACK
	tack = anchor.lerp(tack, amount)
	clew = anchor.lerp(clew, amount)
	var center := (tack + clew) / 2.0
	var front_control := center + ahead * SPINNAKER_DEPTH * amount
	var back_control := center + ahead * SPINNAKER_DEPTH * 0.55 * amount
	var front := _curve(tack, clew, front_control, 24)
	var outline := front.duplicate()
	outline.append_array(_inner(_curve(clew, tack, back_control, 16)))
	# Pole from the mast to the tack (under the sail), sheet and guy aft.
	draw_line(MAST, tack, Color(BOOM, amount), 5.0, true)
	draw_line(clew, Vector2(-430, lee * 150.0), Color(SHEET, 0.8 * amount), 1.5, true)
	draw_line(tack, Vector2(-430, -lee * 150.0), Color(SHEET, 0.6 * amount), 1.5, true)
	draw_colored_polygon(outline, Color(SPINNAKER, 0.95 * amount))
	for band in [0.3, 0.65]:
		var control := center + ahead * SPINNAKER_DEPTH * lerpf(0.55, 1.0, band) * amount
		draw_polyline(_curve(tack, clew, control, 20), Color(SPINNAKER_STRIPE, 0.85 * amount), 7.0, true)
	draw_polyline(front, Color(SAIL_EDGE, amount), 2.0, true)


## A closing curve without its end points (they are already in the outline;
## repeated vertices make polygon triangulation fail).
static func _inner(points: PackedVector2Array) -> PackedVector2Array:
	return points.slice(1, points.size() - 1)


static func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


static func _curve(a: Vector2, b: Vector2, control: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(_bezier(a, control, b, float(i) / steps))
	return points
