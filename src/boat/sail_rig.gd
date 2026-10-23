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
## Sails "breathe": while set they move very slightly around their trim
## (fullness, a fraction of a degree of angle, a gentle ripple along the
## leech), the spinnaker a little more. The motion runs on real time, is
## purely cosmetic and never reaches the simulation: speed and propulsion
## come only from PropulsionState. Furled sails do not move.
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
## Spinnaker: pole length from the mast and how far the sail's leading edge
## bellies forward of its tack-clew line (the front edge flies ~1.5 hull
## half-lengths ahead of the mast, well beyond the bow).
const SPINNAKER_POLE := 270.0
const SPINNAKER_DEPTH := 560.0
## While the spinnaker flies, the deck view eases this far forward so the
## whole sail stays on screen (the stern still fits).
const SPINNAKER_VIEW_SHIFT := 110.0
## Sail motion (amplitudes at full set; frequencies in Hz, deliberately slow).
const MAIN_SWAY_DEG := 0.8
const JIB_SWAY_DEG := 1.2
const MAIN_BREATH := 0.06
const JIB_BREATH := 0.08
const SPINNAKER_BREATH := 0.07
const SPINNAKER_SWAY_DEG := 2.5
const LEECH_RIPPLE_PX := 2.0
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
## Real seconds of sail motion (cosmetic only).
var animation_time := 0.0
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
	animation_time += delta
	_frame_view()
	queue_redraw()


## Jumps to the current state without animating (scene entry, loading).
func snap() -> void:
	var target := _target()
	main_angle_deg = target.main
	jib_angle_deg = target.jib
	set_amount = target.set
	spinnaker_amount = target.spinnaker
	_twa = target.twa
	_frame_view()
	queue_redraw()


## Shifts the deck camera forward with the spinnaker (presentation only).
func _frame_view() -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera:
		camera.offset.x = SPINNAKER_VIEW_SHIFT * spinnaker_amount


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


# --- Geometry -----------------------------------------------------------------------

## Everything drawn, for the current pose at animation time `time` (defaults
## to now). Tests use it to check attachment points and motion.
func get_shape(time := -1.0) -> Dictionary:
	var t := animation_time if time < 0.0 else time
	return {"main": _main_shape(t), "jib": _jib_shape(t), "spinnaker": _spinnaker_shape(t)}


func _main_shape(t: float) -> Dictionary:
	var motion := set_amount
	var angle := deg_to_rad(main_angle_deg + motion * MAIN_SWAY_DEG * sin(t * TAU * 0.13) * signf(main_angle_deg))
	var clew := MAST + Vector2(-cos(angle), sin(angle)) * BOOM_LENGTH
	var lee := signf(main_angle_deg) if main_angle_deg != 0.0 else 1.0
	var chord := clew - MAST
	var normal := _leeward_normal(chord, lee)
	var fullness := 0.13 * set_amount * (1.0 + motion * MAIN_BREATH * sin(t * TAU * 0.21 + 0.7))
	var control := (MAST + clew) / 2.0 + normal * chord.length() * fullness * 2.0
	var leech := _rippled(_curve(MAST, clew, control, 18), normal, motion * LEECH_RIPPLE_PX * 0.6, t, 0.9)
	return {"head": MAST, "clew": clew, "leech": leech, "foot_control": (MAST + clew) / 2.0 + normal * chord.length() * fullness * 0.4}


func _jib_shape(t: float) -> Dictionary:
	var motion := set_amount * (1.0 - spinnaker_amount)
	var angle := deg_to_rad(jib_angle_deg + motion * JIB_SWAY_DEG * sin(t * TAU * 0.17 + 1.9) * signf(jib_angle_deg))
	var clew := JIB_TACK + Vector2(-cos(angle), sin(angle)) * JIB_FOOT
	var lee := signf(jib_angle_deg) if jib_angle_deg != 0.0 else 1.0
	var chord := clew - JIB_TACK
	var normal := _leeward_normal(chord, lee)
	var fullness := 0.3 * (1.0 + motion * JIB_BREATH * sin(t * TAU * 0.27 + 2.4))
	var control := (JIB_TACK + clew) / 2.0 + normal * chord.length() * fullness
	var leech := _rippled(_curve(JIB_TACK, clew, control, 16), normal, motion * LEECH_RIPPLE_PX, t, 1.1)
	return {"tack": JIB_TACK, "clew": clew, "leech": leech, "foot_control": (JIB_TACK + clew) / 2.0 + normal * chord.length() * 0.05}


## The spinnaker: a big crescent flying ahead of the bow. Its tack is at the
## end of the pole (from the mast, out to windward), its clew is sheeted to
## the leeward quarter and its head is held by the halyard from the mast. On a
## broad reach it is swung out to leeward; dead downwind it is centred ahead.
func _spinnaker_shape(t: float) -> Dictionary:
	var lee := -1.0 if _twa >= 0.0 else 1.0
	var run := clampf((absf(_twa) - 115.0) / 65.0, 0.0, 1.0)
	var amount := spinnaker_amount
	var motion := amount
	# Pole angle from the centreline: forward on a reach, squared back running.
	var pole_angle := deg_to_rad(lerpf(22.0, 58.0, run))
	var tack := MAST + Vector2(cos(pole_angle), -lee * sin(pole_angle)) * SPINNAKER_POLE
	var clew := Vector2(lerpf(470.0, 400.0, run), lee * lerpf(215.0, 205.0, run))
	clew += Vector2(0.0, lee * motion * 6.0 * sin(t * TAU * 0.11 + 0.5))
	var swing := deg_to_rad(lerpf(30.0, 0.0, run) + motion * SPINNAKER_SWAY_DEG * sin(t * TAU * 0.09))
	var ahead := Vector2(cos(swing), lee * sin(swing))
	# Hoisting: grow out from the bow.
	tack = JIB_TACK.lerp(tack, amount)
	clew = JIB_TACK.lerp(clew, amount)
	var center := (tack + clew) / 2.0
	var depth := SPINNAKER_DEPTH * amount * (1.0 + motion * SPINNAKER_BREATH * sin(t * TAU * 0.12 + 1.3))
	var front_control := center + ahead * depth
	var back_control := center + ahead * depth * 0.55
	var front := _curve(tack, clew, front_control, 24)
	return {
		"tack": tack, "clew": clew, "head": _bezier(tack, front_control, clew, 0.5), "front": front,
		"back_control": back_control, "center": center, "ahead": ahead, "depth": depth, "lee": lee,
	}


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	var shape := get_shape()
	_draw_jib(shape.jib)
	_draw_main(shape.main)
	if spinnaker_amount > 0.01:
		_draw_spinnaker(shape.spinnaker)


func _draw_main(shape: Dictionary) -> void:
	var clew: Vector2 = shape.clew
	if set_amount > 0.01:
		# Sail: from the mast to the boom end, bellied to leeward.
		var leech: PackedVector2Array = shape.leech
		var outline := leech.duplicate()
		outline.append_array(_inner(_curve(clew, MAST, shape.foot_control, 8)))
		draw_colored_polygon(outline, Color(SAIL, set_amount))
		draw_polyline(leech, Color(SAIL_EDGE, set_amount), 2.0, true)
		# Battens.
		for t in [0.3, 0.55, 0.8]:
			var on_boom := MAST.lerp(clew, t)
			var on_leech := leech[roundi(t * (leech.size() - 1))]
			draw_line(on_boom, on_leech, Color(SAIL_SHADE, set_amount), 2.0, true)
		# Main sheet to the traveller in the cockpit.
		draw_line(clew, Vector2(-360, 0), Color(SHEET, set_amount * 0.8), 1.5, true)
	# Boom (and the sail cover on it when furled).
	draw_line(MAST, clew, BOOM, 7.0, true)
	if set_amount < 0.99:
		draw_line(MAST + (clew - MAST) * 0.03, clew - (clew - MAST) * 0.04, Color(COVER, 1.0 - set_amount), 16.0, true)


func _draw_jib(shape: Dictionary) -> void:
	if set_amount <= 0.01 or spinnaker_amount >= 0.99:
		# Rolled up on the forestay (roller furling).
		draw_line(MAST + Vector2(40, 0), JIB_TACK, Color(SAIL_SHADE, 0.9), 6.0, true)
		return
	var shown := set_amount * (1.0 - spinnaker_amount)
	var clew: Vector2 = shape.clew
	var outline: PackedVector2Array = shape.leech.duplicate()
	outline.append_array(_inner(_curve(clew, JIB_TACK, shape.foot_control, 6)))
	draw_colored_polygon(outline, Color(SAIL, shown))
	draw_polyline(outline, Color(SAIL_EDGE, shown), 2.0, true)
	# Jib sheet to the leeward winch.
	var lee := signf(jib_angle_deg) if jib_angle_deg != 0.0 else 1.0
	draw_line(clew, Vector2(-250, 120 * lee), Color(SHEET, shown * 0.8), 1.5, true)
	draw_line(MAST + Vector2(40, 0), JIB_TACK, Color(SAIL_SHADE, 1.0 - shown), 6.0, true)


func _draw_spinnaker(shape: Dictionary) -> void:
	var amount := spinnaker_amount
	var tack: Vector2 = shape.tack
	var clew: Vector2 = shape.clew
	var lee: float = shape.lee
	var front: PackedVector2Array = shape.front
	var outline := front.duplicate()
	outline.append_array(_inner(_curve(clew, tack, shape.back_control, 16)))
	# Rigging under the sail: pole (mast -> tack), halyard (mast -> head),
	# sheet (clew -> leeward quarter) and guy (tack -> windward quarter).
	draw_line(MAST, tack, Color(BOOM, amount), 5.0, true)
	draw_line(MAST, shape.head, Color(SHEET, 0.7 * amount), 1.5, true)
	draw_line(clew, Vector2(-430, lee * 150.0), Color(SHEET, 0.8 * amount), 1.5, true)
	draw_line(tack, Vector2(-430, -lee * 150.0), Color(SHEET, 0.6 * amount), 1.5, true)
	draw_colored_polygon(outline, Color(SPINNAKER, 0.95 * amount))
	for band in [0.3, 0.65]:
		var control: Vector2 = shape.center + shape.ahead * shape.depth * lerpf(0.55, 1.0, band)
		draw_polyline(_curve(tack, clew, control, 20), Color(SPINNAKER_STRIPE, 0.85 * amount), 7.0, true)
	draw_polyline(front, Color(SAIL_EDGE, amount), 2.0, true)
	# Corner fittings: the sail visibly hangs from its tack, clew and head.
	for corner: Vector2 in [tack, clew]:
		draw_circle(corner, 4.0, Color(BOOM, amount))


## A closing curve without its end points (they are already in the outline;
## repeated vertices make polygon triangulation fail).
static func _inner(points: PackedVector2Array) -> PackedVector2Array:
	return points.slice(1, points.size() - 1)


## Unit normal of `chord` pointing to the leeward side (`lee` = -1 port, +1 starboard).
static func _leeward_normal(chord: Vector2, lee: float) -> Vector2:
	var normal := Vector2(-chord.y, chord.x).normalized()
	return -normal if normal.y * lee < 0.0 else normal


## A gentle travelling ripple along a sail edge, zero at both ends.
static func _rippled(points: PackedVector2Array, normal: Vector2, amplitude: float, t: float, hz: float) -> PackedVector2Array:
	if amplitude <= 0.0:
		return points
	var out := points.duplicate()
	var last := out.size() - 1
	for i in range(1, last):
		var u := float(i) / last
		out[i] += normal * amplitude * sin(PI * u) * sin(TAU * (hz * t - u * 1.5))
	return out


static func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


static func _curve(a: Vector2, b: Vector2, control: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(_bezier(a, control, b, float(i) / steps))
	return points
