class_name WeatherSample
extends WindField.Sample
## The weather at one place and time, as returned by WeatherModel.sample().
##
## It is a WindField.Sample, so everything that already uses wind (the
## propulsion controller, the sails, HUD and chart) keeps working: `from_deg`
## and `speed_kn` are the local SUSTAINED effective wind, i.e. the background
## wind with the sustained effect of any weather event (gale area, storm
## outflow, cyclone) included and gusts excluded. That is the wind the
## propulsion uses. Gusts are reported separately in `gust_kn`.

## Where and when (Vector2(lon, lat), game seconds).
var geo := Vector2.ZERO
var time := 0.0
## The undisturbed background wind (climatology and slow weather waves).
var background_from_deg := 0.0
var background_kn := 0.0
## Highest wind in gusts (knots, always >= speed_kn).
var gust_kn := 0.0
## WeatherModel.HAZARD_NORMAL / CAUTION / DANGEROUS / SEVERE.
var hazard := 0
## What it is: WeatherModel.CLASS_* (e.g. &"gale", &"thunderstorm").
var classification: StringName = &"fair"
## The event mainly responsible (empty when there is none).
var event_id: StringName
var event_kind: StringName
var event_name := ""
## Thunderstorms: possible here (inside a risk area or near a cell), or a
## storm cell is actually active here.
var thunder_possible := false
var thunder_active := false
## Seasonal tropical-cyclone risk here (0..1) and the basin's name ("" if none).
var cyclone_risk := 0.0
var cyclone_basin := ""


## A plain WindField.Sample of the sustained effective wind.
func to_wind() -> WindField.Sample:
	return WindField.Sample.make(from_deg, speed_kn)


func get_hazard_name() -> String:
	return WeatherModel.hazard_name(hazard)


func get_label() -> String:
	return WeatherModel.class_label(classification)


## Plain data (tests, debugging, future consumers).
func to_dict() -> Dictionary:
	return {"from_deg": from_deg, "speed_kn": speed_kn, "gust_kn": gust_kn, "background_from_deg": background_from_deg,
		"background_kn": background_kn, "hazard": hazard, "classification": String(classification),
		"event_id": String(event_id), "event_kind": String(event_kind), "thunder_possible": thunder_possible,
		"thunder_active": thunder_active, "cyclone_risk": cyclone_risk}
