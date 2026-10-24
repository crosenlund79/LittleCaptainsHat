class_name WeatherFixtures
extends RefCounted
## Test helper: deterministic synthetic weather events, added to the one
## weather model as fixtures (WeatherModel.fixture_events). Events made here
## behave exactly like generated ones (same WeatherEvent code), but their
## place, time and strength are chosen by the test.
##
##   WeatherFixtures.use([WeatherFixtures.gale(...)])   # only these events
##   WeatherFixtures.clear()                            # back to normal

## Replaces the fixtures with `events`. With `generated` false (default) the
## randomly formed weather is switched off, so only the fixtures exist.
static func use(events: Array, generated := false) -> void:
	var model := WeatherModel.get_default()
	model.fixture_events.clear()
	for event: WeatherEvent in events:
		model.fixture_events.append(event)
	model.generated_enabled = generated
	model.clear_cache()
	Simulation.invalidate_estimates()


static func clear() -> void:
	var model := WeatherModel.get_default()
	model.fixture_events.clear()
	model.generated_enabled = true
	model.clear_cache()
	Simulation.invalidate_estimates()


static func _base(id: String, kind: StringName, center: Vector2, radius_nm: float, start: float, hours: float) -> WeatherEvent:
	var event := WeatherEvent.new()
	event.id = StringName(id)
	event.kind = kind
	event.origin = center
	event.radius_nm = radius_nm
	event.start_time = start
	event.lifetime = hours * 3600.0
	event.seed = hash(id)
	# Long-lived fixtures (days and more) are fully developed almost at once.
	if hours > 48.0:
		event.develop_fraction = 1.0 / hours
		event.dissipate_fraction = 1.0 / hours
	return event


## A strong-wind / gale area. Round unless `irregular`.
static func gale(id: String, center: Vector2, radius_nm: float, peak_kn: float, start: float, hours: float,
		heading := 0.0, speed_kn := 0.0, flow_from := 250.0, irregular := false) -> WeatherEvent:
	var event := _base(id, WeatherEvent.KIND_GALE, center, radius_nm, start, hours)
	event.peak_kn = peak_kn
	event.heading_deg = heading
	event.speed_kn = speed_kn
	event.flow_from_deg = flow_from
	event.display_name = "Gale" if peak_kn >= 34.0 else "Strong winds"
	if irregular:
		event.shape = PackedFloat32Array([0.18, 0.4, 0.1, 1.9, 0.06, 3.1])
		event.shape_drift = 0.03
	return event


## A thunderstorm cell (developing, active, dissipating over `hours`).
static func thunderstorm(id: String, center: Vector2, radius_nm: float, peak_kn: float, gust_kn: float, start: float,
		hours: float, heading := 90.0, speed_kn := 12.0) -> WeatherEvent:
	var event := _base(id, WeatherEvent.KIND_THUNDERSTORM, center, radius_nm, start, hours)
	event.peak_kn = peak_kn
	event.gust_kn = gust_kn
	event.heading_deg = heading
	event.speed_kn = speed_kn
	event.display_name = "Thunderstorm"
	return event


## An area of thunderstorm risk (no cells of its own as a fixture).
static func thunder_risk(id: String, center: Vector2, radius_nm: float, start: float, hours: float) -> WeatherEvent:
	var event := _base(id, WeatherEvent.KIND_THUNDER_RISK, center, radius_nm, start, hours)
	event.display_name = "Thunderstorm risk"
	return event


## A tropical cyclone.
static func cyclone(id: String, center: Vector2, peak_kn: float, start: float, hours: float, hemisphere := 1,
		heading := 290.0, speed_kn := 12.0, turn := 8.0) -> WeatherEvent:
	var event := _base(id, WeatherEvent.KIND_CYCLONE, center, 160.0, start, hours)
	event.peak_kn = peak_kn
	event.hemisphere = hemisphere
	event.heading_deg = heading
	event.speed_kn = speed_kn
	event.turn_deg_per_day = turn
	event.eye_radius_nm = 25.0
	event.display_name = "Test"
	return event
