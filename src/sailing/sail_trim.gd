class_name SailTrim
extends RefCounted
## Sail trim (Iteration 18): a small, optional sailing skill. The captain can
## leave the trimming to the crew ("auto": the boat sails exactly as the
## sailing model says, as before) or set the sheets by hand on a slider from
## -1 (eased right out) to +1 (sheeted hard in).
##
## The best setting follows the wind's angle to the boat: sheeted in when
## close-hauled, eased for a run, in between on a reach; in a strong wind a
## little flatter (tighter). How close the captain's setting is to the best
## one changes the sailing speed modestly: up to BONUS faster when well
## trimmed, down to PENALTY slower when far off. Only the sailing speed: the
## sailing model's potential (and with it the choice between sail and engine)
## is untouched, so trim can never make an unsuitable point of sail fast, nor
## start or stop the engine. Under engine trim does nothing.
##
## Pure functions of (setting, wind angle, wind speed): the simulation applies
## the factor where it evaluates the sails (on its fixed grid, and at once
## when the captain moves the sheets), so fast time sails the same.

## At best this much faster than the crew's trim (6 %).
const BONUS := 0.06
## At worst this much slower (10 %).
const PENALTY := 0.10
## Within this distance of the best setting the sails are "well trimmed".
const WELL := 0.15
## From this distance on the full penalty applies.
const FAR := 0.6


## The best setting (-1..1) for the true wind angle (degrees, either side)
## and the wind speed (kn).
static func best(angle_deg: float, wind_kn: float) -> float:
	var a := absf(angle_deg)
	var trim := clampf((95.0 - a) / 60.0, -1.0, 1.0) * 0.9
	trim += 0.12 * clampf((wind_kn - 18.0) / 12.0, 0.0, 1.0)
	return clampf(trim, -1.0, 1.0)


## Setting minus the best setting: > 0 too tight, < 0 too loose.
static func error(trim: float, angle_deg: float, wind_kn: float) -> float:
	return clampf(trim, -1.0, 1.0) - best(angle_deg, wind_kn)


## The sailing speed factor: 1.0 with the crew's trim; with the captain's,
## 1 + BONUS when spot on, falling smoothly to 1 - PENALTY at FAR off.
static func factor(auto: bool, trim: float, angle_deg: float, wind_kn: float) -> float:
	if auto:
		return 1.0
	var off := minf(absf(error(trim, angle_deg, wind_kn)) / FAR, 1.0)
	return 1.0 + BONUS - (BONUS + PENALTY) * pow(off, 1.5)


## A word for the sails now: "Trimmed by the crew", "Well trimmed", "Too tight"
## or "Too loose".
static func feedback(auto: bool, trim: float, angle_deg: float, wind_kn: float) -> String:
	if auto:
		return "Trimmed by the crew"
	var e := error(trim, angle_deg, wind_kn)
	if absf(e) <= WELL:
		return "Well trimmed"
	return "Too tight" if e > 0.0 else "Too loose"


## The effect in whole percent (+6 ... -10; 0 with the crew's trim).
static func percent(auto: bool, trim: float, angle_deg: float, wind_kn: float) -> int:
	return roundi((factor(auto, trim, angle_deg, wind_kn) - 1.0) * 100.0)
