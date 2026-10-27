class_name VhfRadio
extends RefCounted
## The VHF radio (I019, The Captain's Watch): now and then, underway, a call
## on channel 16. Two kinds, both optional to answer:
##   - assist: a sailing yacht a few miles off has trouble (no engine, a
##     fouled propeller, a broken rudder line) and asks a vessel to stand by
##     until the coastguard's boat arrives. Standing by keeps the boat where
##     it is for a couple of hours (the voyage pauses; weather, stores and the
##     clock go on). Thanked with renown and a small gift, once.
##   - forecast: a fishing boat asks whether anyone has the latest forecast.
##     Sharing it is a kindness worth a little renown, once.
##
## Calls are a pure function of (the voyage's departure time, the game's
## SLOT_SECONDS slot, the wind seed): at most one per slot, at a fixed time
## inside it. Each call's key is kept with the voyage once it has come, so a
## load, sleep or Long Passage never brings the same call twice, and a
## reward is paid at most once per call (its award id).

const SLOT_SECONDS := 6.0 * 3600.0
const ASSIST_CHANCE := 0.08
## In hazardous weather people need help more often.
const ASSIST_CHANCE_HAZARD := 0.16
const FORECAST_CHANCE := 0.12
## A call not answered within this time is taken by another vessel.
const ANSWER_WITHIN_SECONDS := 3600.0
const KIND_ASSIST := &"assist"
const KIND_FORECAST := &"forecast"
const PROBLEMS := ["an engine that will not start", "a rope around the propeller", "a broken rudder line"]


## The call of `slot` on a voyage that left at `departed_at`, or {}:
## {"id", "kind", "slot", "due" (game time), "vessel", "problem", "distance_nm",
## "bearing", "hours", "renown", "money", "hazardous"}.
static func call_for_slot(departed_at: float, slot: int, seed: int, hazardous: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(departed_at), slot, seed, "vhf"])
	var roll := rng.randf()
	var kind := &""
	var assist := ASSIST_CHANCE_HAZARD if hazardous else ASSIST_CHANCE
	if roll < assist:
		kind = KIND_ASSIST
	elif roll < assist + FORECAST_CHANCE:
		kind = KIND_FORECAST
	if kind == &"":
		return {}
	var call := {"id": "%d:%d" % [int(departed_at), slot], "kind": kind, "slot": slot,
		"due": slot * SLOT_SECONDS + rng.randf_range(0.1, 0.8) * SLOT_SECONDS,
		"vessel": TrafficModel.NAMES[rng.randi_range(0, TrafficModel.NAMES.size() - 1)],
		"problem": rng.randi_range(0, PROBLEMS.size() - 1), "distance_nm": snappedf(rng.randf_range(2.0, 6.0), 0.1),
		"bearing": rng.randf_range(0.0, 360.0), "hazardous": hazardous}
	if kind == KIND_ASSIST:
		call["hours"] = 3 if hazardous else 2
		call["renown"] = 6 if hazardous else 4
		call["money"] = 200 if hazardous else 120
	else:
		call["hours"] = 0
		call["renown"] = 1
		call["money"] = 0
	return call


## What is heard on the radio.
static func describe(call: Dictionary) -> String:
	var where := WindField.compass_name(float(call.bearing))
	if call.kind == KIND_ASSIST:
		return Loc.t("PAN-PAN, PAN-PAN. This is the sailing yacht %s, %s nm to the %s of you. We have %s and are drifting. No one is hurt. We ask a vessel nearby to stand by until the coastguard's boat arrives, about %d hours.") % [
			call.vessel, Loc.decimal(float(call.distance_nm)), where, Loc.t(PROBLEMS[int(call.problem)]), int(call.hours)]
	return Loc.t("Channel 16: the fishing boat %s, %s nm to the %s, asks if any vessel has the latest forecast for these waters.") % [
		call.vessel, Loc.decimal(float(call.distance_nm)), where]


## What answering asks of the captain, before choosing.
static func describe_commitment(call: Dictionary) -> String:
	if call.kind == KIND_ASSIST:
		return Loc.t("Answering means heaving to nearby for about %d hours: the voyage waits, the weather does not. Declining is fine: another vessel will answer.") % int(call.hours)
	return Loc.t("A quick reply on the radio. Nothing else is asked of you.")
