extends RefCounted
## Iteration 005a: the unified weather model. Sampling (determinism,
## conventions, the background outside events, spatial falloff), moving
## irregular severe-weather areas, thunderstorms (lifecycle, outflow, gust
## episodes), seasonal tropical-cyclone risk and active cyclones, propulsion
## and voyages with all three boats, warnings and their deduplication, time-step
## independence (1×, 20×, one large step, sleep, save/load), pause, and the
## save format (v6) with migration from v5.

const START := 1777622400.0  # Fri 1 May 2026, 08:00 UTC (the game's start)
const DAY := 86400.0
## The European chart region (the wind climatology's area, a little larger
## than the chart's sea area).
const EUROPE := Rect2(-27.0, 31.0, 66.0, 42.0)
## On the Copenhagen -> Kiel course (where Iteration 002's demo area was).
const ROUTE_POINT := Vector2(12.2, 54.78)

var t: Node
var model: WeatherModel


func run(runner: Node) -> void:
	t = runner
	model = WeatherModel.get_default()
	Simulation.auto_advance = false
	# Sampling with the real (generated) weather: no wind override.
	WindField.get_default().test_override = Callable()
	WeatherFixtures.clear()
	_test_sampling_basics()
	_test_generated_areas()
	_test_generated_thunderstorms()
	_test_cyclone_risk()
	_test_generated_cyclones()
	# Controlled scenarios: calm background plus fixtures.
	t.use_calm_wind()
	_test_fixture_conventions()
	_test_thunderstorm_fixture()
	_test_cyclone_fixture()
	_test_sailing_all_vessels()
	_test_warnings_and_dedup()
	_test_time_step_consistency()
	_test_pause()
	_test_save_load_and_migration()
	WeatherFixtures.clear()
	Simulation.auto_advance = true
	GameSession.end_session()


# --- Sampling ----------------------------------------------------------------------

func _test_sampling_basics() -> void:
	var a := model.sample(Vector2(-9.0, 47.0), START + 5.0 * DAY, 7)
	var events_before := model.active_events(START + 5.0 * DAY, 7).map(func(e: WeatherEvent) -> Dictionary: return e.describe(START + 5.0 * DAY))
	var b := model.sample(Vector2(-9.0, 47.0), START + 5.0 * DAY, 7)
	t.check_eq(a.to_dict(), b.to_dict(), "[weather] the same place and time give the same weather")
	var events_after := model.active_events(START + 5.0 * DAY, 7).map(func(e: WeatherEvent) -> Dictionary: return e.describe(START + 5.0 * DAY))
	t.check_eq(events_after, events_before, "[weather] reading the weather does not change it")
	# A fresh model (as after a restart) gives identical weather: it depends only on the seed.
	var fresh := WeatherModel.load_from(WeatherModel.DEFAULT_PATH)
	var same := true
	for i in 60:
		var geo := Vector2(-20.0 + i, 35.0 + (i % 30))
		var time := START + i * 7.3 * 3600.0
		same = same and fresh.sample(geo, time, 3).to_dict() == model.sample(geo, time, 3).to_dict()
	t.check(same, "[weather] a fresh model gives identical weather for the same seed")
	var differs := false
	for i in 60:
		var time := START + i * 13.0 * 3600.0
		differs = differs or model.active_events(time, 3).size() != model.active_events(time, 4).size()
	t.check(differs, "[weather] another seed gives other weather")
	# Outside every event the weather is exactly the background wind (as in I004b).
	var checked := 0
	var equal := true
	for i in 400:
		var geo := Vector2(-20.0 + (i * 7) % 55, 35.0 + (i * 3) % 34)
		var time := START + i * 5.1 * 3600.0
		var sample := model.sample(geo, time, 1)
		if not sample.event_id.is_empty() or sample.thunder_possible:
			continue
		var background := WindField.get_default().sample(geo, time, 1)
		checked += 1
		equal = equal and absf(sample.speed_kn - background.speed_kn) < 1e-4 and absf(angle_difference(deg_to_rad(sample.from_deg), deg_to_rad(background.from_deg))) < 1e-4
	t.check(checked > 200 and equal, "[weather] away from weather events the wind is the I004b background wind (%d places)" % checked)
	t.check(a.gust_kn >= a.speed_kn, "[weather] gusts are never below the sustained wind")
	t.check(Simulation.get_wind_at(Vector2(12.0, 55.0)) is WeatherSample, "[weather] the simulation's wind query is the weather model")


func _year_events(kind: StringName, seed := 1, days := 365, step_hours := 3) -> Dictionary:
	var found := {}
	for h in range(0, days * 24, step_hours):
		var time := START + h * 3600.0
		for event in model.active_events(time, seed):
			if event.kind == kind and not found.has(event.id):
				found[event.id] = event
	return found


func _test_generated_areas() -> void:
	var max_active := 0
	for h in range(0, 365 * 24, 6):
		max_active = maxi(max_active, model.active_events(START + h * 3600.0, 1).size())
	t.check(max_active > 3 and max_active <= 40, "[areas] the number of active events stays modest (at most %d at once over a year)" % max_active)
	var gales := _year_events(WeatherEvent.KIND_GALE)
	t.check(gales.size() > 50, "[areas] strong-wind areas form through the year (%d)" % gales.size())
	var gale: WeatherEvent = gales.values()[gales.size() / 2]
	var mid := gale.start_time + gale.lifetime * 0.5
	t.check(not gale.is_active_at(gale.start_time - 1.0) and gale.is_active_at(gale.start_time) and not gale.is_active_at(gale.end_time()),
		"[areas] an area forms and later dissipates (bounded lifetime %.0f h)" % (gale.lifetime / 3600.0))
	t.check(gale.stage_at(gale.start_time + gale.lifetime * 0.1) == WeatherEvent.STAGE_DEVELOPING and gale.stage_at(mid) == WeatherEvent.STAGE_ACTIVE
		and gale.stage_at(gale.start_time + gale.lifetime * 0.9) == WeatherEvent.STAGE_DISSIPATING, "[areas] developing, active, dissipating")
	t.check(gale.life_factor(gale.start_time + gale.lifetime * 0.1) < gale.life_factor(mid) and gale.life_factor(gale.start_time + gale.lifetime * 0.95) < gale.life_factor(mid),
		"[areas] it strengthens and weakens")
	var moved := GeoMath.distance_nm(gale.center_at(mid), gale.center_at(mid + 6.0 * 3600.0))
	t.check(absf(moved - gale.speed_kn * 6.0) < gale.speed_kn * 6.0 * 0.1 + 1.0, "[areas] it moves coherently (%.0f nm in 6 h at %.0f kn)" % [moved, gale.speed_kn])
	var jumps := 0.0
	for i in 60:
		var a := gale.start_time + gale.lifetime * i / 60.0
		jumps = maxf(jumps, GeoMath.distance_nm(gale.center_at(a), gale.center_at(a + 600.0)))
	t.check(jumps < gale.speed_kn * 600.0 / 3600.0 * 1.2 + 0.1, "[areas] no jumps along its track")
	t.check(gale.radius_at(gale.start_time + gale.lifetime * 0.1) < gale.radius_at(mid), "[areas] it grows while developing")
	# Irregular, evolving outline that is exactly the area's extent.
	var radii := PackedFloat32Array()
	for i in 36:
		radii.append(gale.outline_radius(TAU * i / 36.0, mid))
	var spread: float = (Array(radii).max() - Array(radii).min()) / gale.outer_radius(mid)
	t.check(spread > 0.1, "[areas] the outline is irregular, not a circle (radius varies %.0f%%)" % (spread * 100.0))
	var later := gale.outline_radius(1.0, mid + 12.0 * 3600.0) / gale.outer_radius(mid + 12.0 * 3600.0)
	t.check(absf(later - gale.outline_radius(1.0, mid) / gale.outer_radius(mid)) > 0.001, "[areas] its shape changes over time")
	var on_edge := true
	var outline := gale.outline(mid, 24)
	for p in outline:
		on_edge = on_edge and absf(gale.normalized_distance(p, mid) - 1.0) < 0.03
	t.check(on_edge, "[areas] the drawn outline is where its effect ends (normalized distance 1)")
	var inside := model.sample(gale.center_at(mid), mid, 1)
	var just_outside := model.sample(gale.ring(mid, 1.15, 8)[0], mid, 1)
	t.check(inside.speed_kn > just_outside.speed_kn or inside.speed_kn >= gale.peak_kn * 0.95,
		"[areas] the wind is strongest in the core (%.0f kn) and back to normal outside (%.0f kn)" % [inside.speed_kn, just_outside.speed_kn])
	var european := 0
	for event: WeatherEvent in gales.values():
		european += 1 if EUROPE.has_point(event.origin) else 0
	t.check_eq(european, gales.size(), "[areas] strong-wind areas form in the European sea areas")


func _test_generated_thunderstorms() -> void:
	var risks := _year_events(WeatherEvent.KIND_THUNDER_RISK)
	var cells := _year_events(WeatherEvent.KIND_THUNDERSTORM, 1, 365, 1)
	t.check(risks.size() > 20 and cells.size() > 20, "[storms] thunderstorm-risk areas (%d) and storm cells (%d) form" % [risks.size(), cells.size()])
	var summer := 0
	var winter := 0
	for cell: WeatherEvent in cells.values():
		var month: int = Time.get_datetime_dict_from_unix_time(int(cell.start_time)).month
		summer += 1 if month in [6, 7, 8] else 0
		winter += 1 if month in [12, 1, 2] else 0
	t.check(summer > winter * 2, "[storms] thunderstorms are a summer feature (%d in June-August, %d in December-February)" % [summer, winter])
	var in_parent := true
	var severities := {"mild": 0, "severe": 0}
	for cell: WeatherEvent in cells.values():
		var parent := model.find_event(cell.parent_id, cell.start_time)
		in_parent = in_parent and parent != null and parent.normalized_distance(cell.origin, cell.start_time) < 1.0
		severities["severe" if cell.peak_kn + cell.gust_kn >= WeatherModel.SEVERE_STORM_KN else "mild"] += 1
	t.check(in_parent, "[storms] every cell forms inside a thunderstorm-risk area")
	t.check(severities.mild > severities.severe and severities.severe > 0, "[storms] most storms are moderate, some are severe (%s)" % severities)
	var cell: WeatherEvent = cells.values()[0]
	t.check(cell.lifetime >= 2.0 * 3600.0 and cell.lifetime <= 5.0 * 3600.0, "[storms] a cell lives a few hours (%.1f h)" % (cell.lifetime / 3600.0))


func _test_cyclone_risk() -> void:
	var sept := START + 130.0 * DAY  # 8 September 2026
	var feb := START + 290.0 * DAY   # 15 February 2027
	var atlantic := Vector2(-50.0, 15.0)
	var south_indian := Vector2(70.0, -15.0)
	t.check(model.cyclone_risk(atlantic, sept).risk > 0.6 and model.cyclone_risk(atlantic, feb).risk < 0.05,
		"[cyclones] North Atlantic risk is high in September, nil in February")
	t.check(model.cyclone_risk(south_indian, feb).risk > 0.6 and model.cyclone_risk(south_indian, sept).risk < 0.05,
		"[cyclones] South Indian Ocean risk is high in February, nil in September (other hemisphere, other season)")
	t.check_eq(model.cyclone_risk(atlantic, sept).basin, "North Atlantic", "[cyclones] the risk names its basin")
	var european := 0.0
	for place in [Vector2(19.0, 57.0), Vector2(3.0, 56.0), Vector2(5.0, 40.0), Vector2(-9.0, 45.0), Vector2(25.0, 37.0), Vector2(-15.0, 34.0)]:
		for month in 12:
			european = maxf(european, model.cyclone_risk(place, START + month * 30.0 * DAY).risk)
	t.check_eq(european, 0.0, "[cyclones] no tropical-cyclone risk anywhere in European waters (Baltic, North Sea, Mediterranean, Biscay)")
	t.check(model.get_basin_names().size() >= 6, "[cyclones] basins in both hemispheres (%s)" % ", ".join(model.get_basin_names()))
	# The game date, not the computer's date, decides the season.
	t.check(model.cyclone_risk(atlantic, sept).risk != model.cyclone_risk(atlantic, feb).risk, "[cyclones] seasonality follows the game date")


func _test_generated_cyclones() -> void:
	var cyclones := _year_events(WeatherEvent.KIND_CYCLONE, 1, 3 * 365, 6)
	t.check(cyclones.size() > 20, "[cyclones] active tropical cyclones form in their basins (%d in three years)" % cyclones.size())
	var in_europe := 0
	var in_basin := true
	for event: WeatherEvent in cyclones.values():
		for i in 20:
			var time := event.start_time + event.lifetime * i / 19.0
			if EUROPE.has_point(event.center_at(time)):
				in_europe += 1
		in_basin = in_basin and model.cyclone_risk(event.origin, event.start_time).risk > 0.0
	t.check_eq(in_europe, 0, "[cyclones] none ever reaches the European chart (no Baltic or North Sea hurricanes)")
	t.check(in_basin, "[cyclones] each forms in a basin in its season")
	var event: WeatherEvent = cyclones.values()[cyclones.size() / 3]
	var jumps := 0.0
	var peak_at := 0.0
	var peak := 0.0
	for i in 200:
		var time := event.start_time + event.lifetime * i / 200.0
		jumps = maxf(jumps, GeoMath.distance_nm(event.center_at(time), event.center_at(time + 1800.0)))
		if event.life_factor(time) > peak:
			peak = event.life_factor(time)
			peak_at = i / 200.0
	t.check(jumps < event.speed_kn * 0.5 * 1.2 + 0.1, "[cyclones] it moves steadily (at most %.1f nm per 30 min at %.0f kn)" % [jumps, event.speed_kn])
	t.check(peak_at > 0.1 and peak_at < 0.9, "[cyclones] it intensifies, then weakens (peak at %d%% of its life)" % roundi(peak_at * 100.0))
	t.check(event.life_factor(event.end_time()) == 0.0 and model.find_event(event.id, event.end_time() + 1.0) == null, "[cyclones] it dissipates and is gone")


# --- Controlled scenarios ----------------------------------------------------------

func _test_fixture_conventions() -> void:
	WeatherFixtures.use([WeatherFixtures.gale("fx_gale", ROUTE_POINT, 20.0, 30.0, START - 3600.0, 24.0 * 30.0, 0.0, 0.0, 270.0)])
	var core := model.sample(ROUTE_POINT, START, 1)
	t.check(absf(core.speed_kn - 30.0) < 0.5 and absf(angle_difference(deg_to_rad(core.from_deg), deg_to_rad(270.0))) < 0.05,
		"[conventions] a westerly gale: wind FROM 270° at 30 kn in the core (%.0f° %.1f kn)" % [core.from_deg, core.speed_kn])
	t.check(core.to_vector().x > 29.0 and absf(core.to_vector().y) < 1.0, "[conventions] it blows TO the east (chart arrows point east)")
	t.check(core.hazard == WeatherModel.HAZARD_CAUTION and core.classification == WeatherModel.CLASS_STRONG_WIND and core.event_id == &"fx_gale",
		"[conventions] 30 kn is 'strong winds' (caution), from the gale event")
	t.check(absf(core.gust_kn - 30.0 * WeatherModel.GALE_GUST_FACTOR) < 0.5, "[conventions] gusts %.0f kn (sustained × %.2f)" % [core.gust_kn, WeatherModel.GALE_GUST_FACTOR])
	# Spatial falloff: strongest at the core, smooth, nothing outside.
	var speeds := PackedFloat32Array()
	var continuous := true
	var previous := -1.0
	for i in 60:
		var geo := ROUTE_POINT + Vector2(i * 0.5 / (60.0 * cos(deg_to_rad(ROUTE_POINT.y))), 0.0)  # 0.5 nm steps east
		var speed := model.sample(geo, START, 1).speed_kn
		speeds.append(speed)
		if previous >= 0.0:
			continuous = continuous and absf(speed - previous) < 3.0
		previous = speed
	var monotonic := true
	for i in range(1, speeds.size()):
		monotonic = monotonic and speeds[i] <= speeds[i - 1] + 1e-4
	t.check(monotonic and speeds[0] > 29.0 and speeds[speeds.size() - 1] < 0.01, "[conventions] the wind falls off from the core to nothing outside the area")
	t.check(continuous, "[conventions] without jumps (0.5 nm steps)")
	t.check(model.sample(ROUTE_POINT, START + 24.0 * 31.0 * 3600.0, 1).speed_kn < 0.01, "[conventions] after the event has dissipated the wind is back to the background")


func _test_thunderstorm_fixture() -> void:
	var storm := WeatherFixtures.thunderstorm("fx_cell", ROUTE_POINT, 10.0, 22.0, 24.0, START, 4.0, 90.0, 0.0)
	WeatherFixtures.use([storm])
	t.check(storm.stage_at(START + 0.5 * 3600.0) == WeatherEvent.STAGE_DEVELOPING and storm.stage_at(START + 2.0 * 3600.0) == WeatherEvent.STAGE_ACTIVE
		and storm.stage_at(START + 3.6 * 3600.0) == WeatherEvent.STAGE_DISSIPATING, "[thunderstorm] developing, active, dissipating")
	var developing := model.sample(ROUTE_POINT, START + 0.4 * 3600.0, 1)
	var active := model.sample(ROUTE_POINT, START + 2.0 * 3600.0, 1)
	var after := model.sample(ROUTE_POINT, START + 4.5 * 3600.0, 1)
	t.check(developing.speed_kn < active.speed_kn and active.speed_kn > 20.0 and after.speed_kn < 0.01,
		"[thunderstorm] its wind builds (%.0f kn), peaks (%.0f kn) and is gone afterwards (%.0f kn)" % [developing.speed_kn, active.speed_kn, after.speed_kn])
	var edge := model.sample(storm.ring(START + 2.0 * 3600.0, 0.8, 4)[0], START + 2.0 * 3600.0, 1)
	t.check(edge.speed_kn < active.speed_kn and edge.speed_kn > 0.0, "[thunderstorm] the centre is much worse than the edge (%.0f vs %.0f kn)" % [active.speed_kn, edge.speed_kn])
	t.check(active.thunder_active and active.classification == WeatherModel.CLASS_SQUALL and active.hazard >= WeatherModel.HAZARD_DANGEROUS,
		"[thunderstorm] in its core: severe squalls, dangerous (%s, %s)" % [active.get_label(), active.get_hazard_name()])
	# Gust episodes: smooth rise, peak, fall; several in a few hours; never skipped by time.
	var peaks := 0
	var max_step := 0.0
	var previous := storm.gust_envelope(START)
	var rising := false
	var highest := 0.0
	for i in range(1, 4 * 360):
		var time := START + i * 10.0
		var value := storm.gust_envelope(time)
		max_step = maxf(max_step, absf(value - previous))
		if value < previous and rising and previous > 0.3:
			peaks += 1
		rising = value > previous
		previous = value
		highest = maxf(highest, value)
	t.check(peaks >= 2 and highest > 0.5, "[thunderstorm] gusts come in episodes (%d peaks in 4 h)" % peaks)
	t.check(max_step < 0.08, "[thunderstorm] each episode rises and falls smoothly (largest change %.3f per 10 s)" % max_step)
	var best_gust := 0.0
	for i in 240:
		best_gust = maxf(best_gust, model.sample(ROUTE_POINT, START + 3600.0 + i * 30.0, 1).gust_kn)
	t.check(best_gust > active.speed_kn * WeatherModel.GUST_FACTOR + 8.0, "[thunderstorm] squall gusts well above the sustained wind (up to %.0f kn)" % best_gust)
	var mild := WeatherFixtures.thunderstorm("fx_mild", ROUTE_POINT, 10.0, 6.0, 8.0, START, 4.0, 90.0, 0.0)
	WeatherFixtures.use([mild])
	var mild_sample := model.sample(ROUTE_POINT, START + 2.0 * 3600.0, 1)
	t.check(mild_sample.hazard == WeatherModel.HAZARD_CAUTION and mild_sample.classification == WeatherModel.CLASS_THUNDERSTORM,
		"[thunderstorm] a mild storm is only 'caution' (%s)" % mild_sample.get_hazard_name())


func _test_cyclone_fixture() -> void:
	var north := WeatherFixtures.cyclone("fx_north", Vector2(-55.0, 18.0), 100.0, START, 96.0, 1)
	var south := WeatherFixtures.cyclone("fx_south", Vector2(80.0, -15.0), 100.0, START, 96.0, -1, 230.0, 10.0, -8.0)
	WeatherFixtures.use([north, south])
	var time := START + 48.0 * 3600.0
	var east_of_north := north.center_at(time) + Vector2(1.0, 0.0)
	var east_of_south := south.center_at(time) + Vector2(1.0, 0.0)
	var n := model.sample(east_of_north, time, 1)
	var s := model.sample(east_of_south, time, 1)
	t.check(n.to_vector().y > 0.0 and s.to_vector().y < 0.0,
		"[cyclone] counter-clockwise in the north, clockwise in the south (east of the eye: blowing %s / %s)" % [
			"north" if n.to_vector().y > 0.0 else "south", "south" if s.to_vector().y < 0.0 else "north"])
	var near := model.sample(north.center_at(time) + Vector2(0.0, 0.45), time, 1)  # ~27 nm, the eye wall
	var far := model.sample(north.center_at(time) + Vector2(0.0, 3.5), time, 1)    # ~210 nm
	t.check(near.speed_kn > 80.0 and far.speed_kn < near.speed_kn * 0.5, "[cyclone] strongest at the eye wall (%.0f kn), weaker far out (%.0f kn)" % [near.speed_kn, far.speed_kn])
	t.check(near.classification == WeatherModel.CLASS_HURRICANE and near.hazard == WeatherModel.HAZARD_SEVERE and near.event_kind == WeatherEvent.KIND_CYCLONE,
		"[cyclone] hurricane, severe")
	t.check(north.cyclone_category(time).begins_with("Hurricane (category"), "[cyclone] presentation label: %s" % north.cyclone_category(time))
	var moved := GeoMath.distance_nm(north.center_at(START), north.center_at(START + 24.0 * 3600.0))
	t.check(absf(moved - 12.0 * 24.0) < 12.0 * 24.0 * 0.05, "[cyclone] it moves along its track (%.0f nm in a day at 12 kn)" % moved)
	t.check(model.sample(north.center_at(time), START + 97.0 * 3600.0, 1).speed_kn < 0.01, "[cyclone] after it has dissipated, nothing remains")
	WeatherFixtures.use([])


func _test_sailing_all_vessels() -> void:
	for id in VesselCatalog.get_default().get_ids():
		# A gale over the Copenhagen -> Kiel course, background calm.
		WeatherFixtures.use([WeatherFixtures.gale("fx_route_gale", ROUTE_POINT, 25.0, 36.0, START - 3600.0, 24.0 * 30.0, 0.0, 0.0, 300.0)])
		GameSession.start_new_session()
		GameSession.switch_vessel(id)
		GameSession.plan_route_to(&"kiel")
		GameSession.depart()
		var changes := [0]
		var on_change := func(_mode: StringName) -> void: changes[0] += 1
		GameSession.propulsion_changed.connect(on_change)
		var consistent := true
		var max_wind := 0.0
		var spinnaker_ok := true
		var profile := GameSession.get_vessel_profile()
		for i in 48 * 12:
			if not GameSession.is_underway():
				break
			Simulation.advance(Simulation.EVALUATION_INTERVAL)
			Simulation.advance(0.001)  # runs the evaluation due at this grid point
			if not GameSession.is_underway():
				break
			var state := GameSession.get_propulsion()
			var here := Simulation.get_weather_at_vessel()
			consistent = consistent and absf(state.wind_speed_kn - here.speed_kn) < 0.01
			max_wind = maxf(max_wind, here.speed_kn)
			spinnaker_ok = spinnaker_ok and (not state.spinnaker or profile.wants_spinnaker(state.true_wind_angle))
		GameSession.propulsion_changed.disconnect(on_change)
		t.check(consistent, "[sailing %s] propulsion uses the weather model's wind at every evaluation" % id)
		t.check(max_wind > 30.0, "[sailing %s] the gale's wind reached the boat (%.0f kn)" % [id, max_wind])
		t.check(spinnaker_ok, "[sailing %s] spinnaker only on its angles" % id)
		t.check(changes[0] <= 6, "[sailing %s] no rapid sail/engine switching through the weather (%d changes)" % [id, changes[0]])
		t.check_eq(GameSession.get_location_id(), &"kiel", "[sailing %s] the voyage reaches Kiel through the gale" % id)
	# Brief gusts never drive propulsion: a storm with strong gusts but a
	# moderate sustained wind does not make the engine start and stop.
	WeatherFixtures.use([WeatherFixtures.thunderstorm("fx_gusty", ROUTE_POINT, 25.0, 6.0, 30.0, START, 30.0, 90.0, 0.0)])
	GameSession.start_new_session()
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	var switches := [0]
	var count := func(_mode: StringName) -> void: switches[0] += 1
	GameSession.propulsion_changed.connect(count)
	Simulation.advance(30.0 * 3600.0)
	GameSession.propulsion_changed.disconnect(count)
	t.check(switches[0] <= 4, "[sailing] gusts alone do not make the engine cycle (%d changes)" % switches[0])
	WeatherFixtures.use([])


func _test_warnings_and_dedup() -> void:
	# A severe storm sitting on the course: one warning ahead, one more when it
	# turns dangerous at the boat, never repeated.
	WeatherFixtures.use([WeatherFixtures.thunderstorm("fx_storm", ROUTE_POINT, 12.0, 22.0, 26.0, START, 30.0, 0.0, 0.0)])
	GameSession.start_new_session()
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	var received: Array[Dictionary] = []
	var on_warning := func(w: Dictionary) -> void: received.append(w)
	Simulation.weather_warning.connect(on_warning)
	Simulation.advance(40.0 * 3600.0)
	Simulation.weather_warning.disconnect(on_warning)
	var keys := received.map(func(w: Dictionary) -> String: return w.key)
	t.check(received.size() >= 1 and received.size() <= 3, "[warnings] a storm on the course gives a few warnings, not one per tick (%s)" % ", ".join(keys))
	t.check(keys.size() == Array(keys).reduce(func(acc: Array, k: String) -> Array: return acc if k in acc else acc + [k], []).size(),
		"[warnings] each warning is given once")
	var texts := " / ".join(received.map(func(w: Dictionary) -> String: return w.text))
	t.check("ahead on your route" in texts or "nearby" in texts, "[warnings] it is announced ahead of the boat: %s" % texts)
	t.check("squalls" in texts.to_lower() and not "risk" in texts.to_lower(), "[warnings] an actual storm is named as such, not as a mere risk")
	t.check(received.any(func(w: Dictionary) -> bool: return w.hazard >= WeatherModel.HAZARD_DANGEROUS), "[warnings] the danger level is part of the warning")
	t.check(received.all(func(w: Dictionary) -> bool: return w.event_id == &"fx_storm"), "[warnings] they name the responsible event")

	# Escalation: the same event is announced again only when it gets worse.
	var here := PortCatalog.get_default().get_port(&"copenhagen").get_geo_position()
	var level := func(peak: float) -> void:
		WeatherFixtures.use([WeatherFixtures.gale("fx_level", here, 30.0, peak, START - 3600.0, 24.0 * 365.0)])
	level.call(26.0)
	received.clear()
	Simulation.weather_warning.connect(on_warning)
	GameSession.start_new_session()
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	var at_departure := received.map(func(w: Dictionary) -> String: return w.key)
	level.call(40.0)
	Simulation.advance(Simulation.EVALUATION_INTERVAL + 1.0)  # past the next evaluation point
	var escalated := received.map(func(w: Dictionary) -> String: return w.key)
	level.call(26.0)
	Simulation.advance(2.0 * Simulation.EVALUATION_INTERVAL)
	level.call(40.0)
	Simulation.advance(2.0 * Simulation.EVALUATION_INTERVAL)
	Simulation.weather_warning.disconnect(on_warning)
	var all_keys := received.map(func(w: Dictionary) -> String: return w.key)
	t.check(at_departure == ["fx_level>1"], "[warnings] strong winds at the boat are announced at departure (%s)" % [at_departure])
	t.check(escalated == ["fx_level>1", "fx_level>2"], "[warnings] the same area turning dangerous is announced again (%s)" % [escalated])
	t.check(all_keys == escalated, "[warnings] easing and worsening again to an announced level gives no repeat (%s)" % [all_keys])
	WeatherFixtures.use([])


## One voyage through a moving thunderstorm and a gale, driven in different
## ways; meaningful outcomes must be identical.
func _drive(mode: String) -> Dictionary:
	GameSession.start_new_session()
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	var received: Array[String] = []
	var peak_gust := [0.0]
	var on_warning := func(w: Dictionary) -> void: received.append("%s@%d" % [w.key, roundi(GameSession.get_game_time())])
	Simulation.weather_warning.connect(on_warning)
	var end := GameSession.get_game_time() + 14.0 * 3600.0
	match mode:
		"1x":
			while GameSession.get_game_time() < end - 1e-6:
				Simulation.advance(minf(60.0, end - GameSession.get_game_time()))
				peak_gust[0] = maxf(peak_gust[0], GameSession.get_weather_exposure().peak_gust_kn)
		"20x":
			GameSession.set_time_scale(20)
			while GameSession.get_game_time() < end - 1e-6:
				GameSession.set_time_scale(20)
				var frame := minf(1.0, (end - GameSession.get_game_time()) / (20.0 * Simulation.game_seconds_per_real_second))
				Simulation.tick(frame)
				peak_gust[0] = maxf(peak_gust[0], GameSession.get_weather_exposure().peak_gust_kn)
		"large":
			Simulation.advance(end - GameSession.get_game_time())
		"sleep":
			while GameSession.get_game_time() < end - 1e-6:
				Simulation.sleep(minf(12.0, (end - GameSession.get_game_time()) / 3600.0))
		"save":
			Simulation.advance(5.0 * 3600.0)
			var saved := SaveManager.save_to_slot(3, GameSession.get_state_snapshot())
			t.check_eq(saved, OK, "(setup) saved in the middle of the storm")
			var saved_at := GameSession.get_game_time()
			Simulation.advance(2.0 * 3600.0)  # diverge, then load back
			GameSession.replace_state(SaveManager.load_from_slot(3).state)
			# What happened after the save never happened in the loaded game.
			var kept: Array[String] = []
			for w in received:
				if int(w.get_slice("@", 1)) <= saved_at:
					kept.append(w)
			received.assign(kept)
			Simulation.advance(end - GameSession.get_game_time())
	Simulation.weather_warning.disconnect(on_warning)
	var exposure := GameSession.get_weather_exposure()
	return {"progress": snappedf(GameSession.get_voyage_progress_nm(), 1e-6) if GameSession.is_underway() else -1.0,
		"location": String(GameSession.get_location_id()), "warnings": received, "mode": String(GameSession.get_propulsion().mode),
		"exposure": [exposure.level, roundi(exposure.since), String(exposure.event_id), snappedf(exposure.peak_gust_kn, 0.01)]}


func _test_time_step_consistency() -> void:
	# A storm cell (short-lived, 3 h) crossing the course, and a gale later on.
	var cell := WeatherFixtures.thunderstorm("fx_crossing", Vector2(12.45, 55.25), 8.0, 20.0, 24.0, START + 2.0 * 3600.0, 3.0, 120.0, 6.0)
	var gale := WeatherFixtures.gale("fx_later", ROUTE_POINT, 15.0, 30.0, START + 6.0 * 3600.0, 12.0, 0.0, 0.0, 280.0)
	WeatherFixtures.use([cell, gale])
	var reference := _drive("1x")
	t.check(not reference.warnings.is_empty(), "[time] the reference voyage meets the weather (%s)" % ", ".join(reference.warnings))
	for mode in ["20x", "large", "sleep", "save"]:
		var other := _drive(mode)
		t.check_eq(other, reference, "[time] %s gives the same voyage, warnings and weather exposure as 1×" % mode)
	SaveManager.delete_slot(3)


func _test_pause() -> void:
	WeatherFixtures.use([WeatherFixtures.thunderstorm("fx_paused", ROUTE_POINT, 10.0, 18.0, 20.0, START, 4.0, 90.0, 10.0)])
	GameSession.start_new_session()
	Simulation.advance(1.5 * 3600.0)
	var time := GameSession.get_game_time()
	var before := Simulation.get_weather_at(ROUTE_POINT).to_dict()
	var center := WeatherModel.get_default().find_event(&"fx_paused", time).center_at(time)
	GameSession.set_paused(true)
	for i in 30:
		Simulation.tick(1.0)
	t.check_eq(GameSession.get_game_time(), time, "[pause] paused: the clock stands still")
	t.check_eq(Simulation.get_weather_at(ROUTE_POINT).to_dict(), before, "[pause] the weather stays exactly the same")
	t.check(WeatherModel.get_default().find_event(&"fx_paused", GameSession.get_game_time()).center_at(GameSession.get_game_time()) == center,
		"[pause] storms do not move")
	GameSession.set_paused(false)
	Simulation.tick(1.0)
	t.check(GameSession.get_game_time() > time, "[pause] resumed: the weather moves on")


func _test_save_load_and_migration() -> void:
	WeatherFixtures.use([WeatherFixtures.thunderstorm("fx_saved", ROUTE_POINT, 12.0, 20.0, 24.0, START + 3600.0, 6.0, 0.0, 0.0)])
	GameSession.start_new_session(CompanionState.KIND_DOG)
	GameSession.switch_vessel(&"halcyon_40")
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(4.0 * 3600.0)
	GameSession.set_paused(true)
	var snapshot := GameSession.get_state_snapshot()
	var data := snapshot.to_dict()
	t.check(data.weather.model_version == 1 and data.weather.exposure is Dictionary, "[saves] the weather section (model version, exposure) is saved")
	t.check(not JSON.stringify(data).contains("outline"), "[saves] no drawing geometry is saved (it is rebuilt from the events)")
	t.check_eq(SaveManager.save_to_slot(2, snapshot), OK, "[saves] saved underway in bad weather")
	var here_before := Simulation.get_weather_at_vessel().to_dict()
	var loaded := SaveManager.load_from_slot(2)
	GameSession.replace_state(loaded.state)
	t.check_eq(Simulation.get_weather_at_vessel().to_dict(), here_before, "[saves] after loading, the weather at the boat is exactly the same")
	t.check(GameSession.is_paused() and GameSession.get_vessel_id() == &"halcyon_40" and GameSession.get_companion().kind == CompanionState.KIND_DOG,
		"[saves] pause, vessel and companion are kept")

	# A version 5 save (Iteration 004b): legacy warnings dropped, weather initialised.
	var v5: Dictionary = loaded.state.to_dict()
	v5.erase("weather")
	v5.navigation.voyage.warned_conditions = ["strong_winds_western_baltic", "storm_bay_of_biscay"]
	var file := FileAccess.open(SaveManager.save_dir.path_join("slot_3.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": "next_harbor_save", "version": 5, "game_version": "0.4.0",
		"saved_at_unix": 1790000000.0, "saved_at_utc": "2026-09-21T12:53:20Z", "session": v5}, "", true, true))
	file.close()
	var migrated := SaveManager.load_from_slot(3)
	t.check(migrated.is_ok(), "[migration] a version 5 save loads (%s)" % migrated.error)
	if migrated.is_ok():
		var state := migrated.state
		t.check(state.voyage.warned_conditions.is_empty(), "[migration] the legacy weather-area warnings are discarded")
		t.check(state.weather_exposure.level == WeatherModel.HAZARD_NORMAL and is_equal_approx(state.weather_exposure.since, state.game_time),
			"[migration] a fresh weather exposure record starts at the saved time")
		t.check(state.vessel_position.is_equal_approx(loaded.state.vessel_position) and is_equal_approx(state.voyage.progress_nm, loaded.state.voyage.progress_nm)
			and state.game_time == loaded.state.game_time and state.vessel_id == &"halcyon_40" and state.companion.kind == CompanionState.KIND_DOG
			and state.paused and state.voyage.route.destination_port_id == &"kiel",
			"[migration] position, progress, time, vessel, companion, pause and route are untouched")
		t.check(state.wind_seed == loaded.state.wind_seed, "[migration] the weather seed is kept, so the weather continues")
	GameSession.set_paused(false)
	SaveManager.delete_slot(2)
	SaveManager.delete_slot(3)
