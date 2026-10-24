class_name WeatherExposure
extends RefCounted
## What weather the boat has been in, for how long (plain saved data, owned by
## SessionState, changed only by GameSession on the simulation's evaluation
## grid while underway).
##
## Updated every Simulation.EVALUATION_INTERVAL (5 game minutes) while
## underway, so it is the same at any time acceleration, while sleeping and
## after loading. Reset in port. Nothing in Iteration 005a acts on it; it is
## the record later systems (e.g. vessel condition) read.

## Current hazard level (WeatherModel.HAZARD_*) and since when (game seconds).
var level := WeatherModel.HAZARD_NORMAL
var since := 0.0
## Classification and the responsible event of the current exposure.
var classification: StringName = WeatherModel.CLASS_FAIR
var event_id: StringName
## Strongest sustained wind and gust (knots) during the current exposure.
var peak_sustained_kn := 0.0
var peak_gust_kn := 0.0
## Last evaluation time this record was updated at.
var updated_at := 0.0


## Records the weather at the boat at `time`. A new exposure starts when the
## hazard level or the responsible event changes.
func record(sample: WeatherSample, time: float) -> void:
	if sample.hazard != level or sample.event_id != event_id:
		level = sample.hazard
		event_id = sample.event_id
		since = time
		peak_sustained_kn = 0.0
		peak_gust_kn = 0.0
	classification = sample.classification
	peak_sustained_kn = maxf(peak_sustained_kn, sample.speed_kn)
	peak_gust_kn = maxf(peak_gust_kn, sample.gust_kn)
	updated_at = time


## Back to normal (in port).
func reset(time: float) -> void:
	level = WeatherModel.HAZARD_NORMAL
	since = time
	classification = WeatherModel.CLASS_FAIR
	event_id = &""
	peak_sustained_kn = 0.0
	peak_gust_kn = 0.0
	updated_at = time


## Seconds spent in the current exposure up to `time`.
func duration(time: float) -> float:
	return maxf(time - since, 0.0)


func duplicate_exposure() -> WeatherExposure:
	var copy := WeatherExposure.new()
	copy.level = level
	copy.since = since
	copy.classification = classification
	copy.event_id = event_id
	copy.peak_sustained_kn = peak_sustained_kn
	copy.peak_gust_kn = peak_gust_kn
	copy.updated_at = updated_at
	return copy


func to_dict() -> Dictionary:
	return {"level": level, "since": since, "classification": String(classification), "event_id": String(event_id),
		"peak_sustained_kn": peak_sustained_kn, "peak_gust_kn": peak_gust_kn, "updated_at": updated_at}


static func from_dict(data: Variant, errors: Array[String]) -> WeatherExposure:
	if not data is Dictionary:
		errors.append("invalid weather exposure")
		return null
	var exposure := WeatherExposure.new()
	for key in ["level", "since", "peak_sustained_kn", "peak_gust_kn", "updated_at"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			errors.append("invalid weather exposure value: %s" % key)
			return null
	exposure.level = clampi(int(data.level), WeatherModel.HAZARD_NORMAL, WeatherModel.HAZARD_SEVERE)
	exposure.since = float(data.since)
	exposure.peak_sustained_kn = float(data.peak_sustained_kn)
	exposure.peak_gust_kn = float(data.peak_gust_kn)
	exposure.updated_at = float(data.updated_at)
	exposure.classification = StringName(str(data.get("classification", "fair")))
	exposure.event_id = StringName(str(data.get("event_id", "")))
	return exposure
