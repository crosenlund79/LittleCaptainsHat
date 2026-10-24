class_name VesselCondition
extends RefCounted
## Names and bands for a boat's overall condition (0-100 %, one general
## seaworthiness value per boat; see SessionState.vessel_conditions). The
## value itself is owned by SessionState and changed through GameSession.

const FULL := 100.0

const BAND_SOUND := &"sound"        # 76-100
const BAND_WORN := &"worn"          # 41-75
const BAND_DAMAGED := &"damaged"    # 16-40
const BAND_CRITICAL := &"critical"  # 1-15 (0 means a rescue)
const BANDS: Array[StringName] = [BAND_SOUND, BAND_WORN, BAND_DAMAGED, BAND_CRITICAL]
const NAMES := {BAND_SOUND: "Sound", BAND_WORN: "Worn", BAND_DAMAGED: "Damaged", BAND_CRITICAL: "Critical"}


## The band of `percent`. Upper limits use the shown (rounded up) value, so a
## boat displayed as "76 %" is still sound and "15 %" is critical.
static func band_of(percent: float) -> StringName:
	var shown := ceilf(percent - 1e-6)
	if shown > 75.0:
		return BAND_SOUND
	if shown > 40.0:
		return BAND_WORN
	if shown > 15.0:
		return BAND_DAMAGED
	return BAND_CRITICAL


static func band_name(percent: float) -> String:
	return NAMES[band_of(percent)]


## "87 % · Sound". Rounded up, so a boat only shows 0 % when it is lost.
static func describe(percent: float) -> String:
	return "%d %% · %s" % [ceili(percent - 1e-6), band_name(percent)]
