class_name FishFight
extends RefCounted
## Landing a fish (Iteration 13): a small, forgiving tension game.
##
## Hold "reel" to bring the fish in; reeling raises the line's tension, the
## fish's runs raise it too, and letting go eases it. Keep the tension out of
## the red until the fish is in. The line only breaks after the tension has
## stayed at the top for BREAK_SECONDS, with a clear warning from WARN (so
## there is always time to ease off). Strong wind and a fast boat (trolling)
## add a little tension of their own. Real time, so 20x never rushes it.

const WARN := 0.8
const TOP := 0.95
const BREAK_SECONDS := 1.6
## After this long the fish slips the hook (rare: only if the captain never reels).
const GIVE_UP_SECONDS := 60.0

const RESULT_NONE := &""
const RESULT_LANDED := &"landed"
const RESULT_BROKE := &"broke"
const RESULT_ESCAPED := &"escaped"

var strength := 0.5
var wind_kn := 0.0
var speed_kn := 0.0
var tension := 0.15
var progress := 0.0
var elapsed := 0.0
## Seconds the tension has been at the top (counts down when eased).
var strain := 0.0
var result: StringName = RESULT_NONE
var _phase := 0.0


func _init(fish_strength := 0.5, wind := 0.0, speed := 0.0, phase := 0.0) -> void:
	strength = clampf(fish_strength, 0.05, 1.0)
	wind_kn = wind
	speed_kn = speed
	_phase = phase


## The fish's pull now (0..1): steady effort plus occasional runs.
func pull() -> float:
	var run := maxf(sin(elapsed * 1.7 + _phase), 0.0) * maxf(sin(elapsed * 0.6 + _phase * 2.0), 0.0)
	var conditions := maxf(wind_kn - 15.0, 0.0) / 50.0 + speed_kn / 25.0
	return clampf(0.2 + strength * 0.35 + run * strength * 0.45 + conditions, 0.0, 1.0)


func is_warning() -> bool:
	return result == RESULT_NONE and tension >= WARN


func is_over() -> bool:
	return result != RESULT_NONE


## Advances the fight by `delta` seconds, reeling or not.
func step(delta: float, reeling: bool) -> void:
	if is_over() or delta <= 0.0:
		return
	elapsed += delta
	var p := pull()
	if reeling:
		tension += (0.22 + p * 0.85) * delta
		if tension < TOP:
			progress += (0.17 - strength * 0.07) * delta
	else:
		tension -= 0.75 * delta
		progress = maxf(progress - 0.015 * strength * delta, 0.0)
	tension = clampf(tension, p * 0.35, 1.0)
	if tension >= TOP:
		strain += delta
	else:
		strain = maxf(strain - delta * 2.0, 0.0)
	if strain >= BREAK_SECONDS:
		result = RESULT_BROKE
	elif progress >= 1.0:
		progress = 1.0
		result = RESULT_LANDED
	elif elapsed >= GIVE_UP_SECONDS:
		result = RESULT_ESCAPED
