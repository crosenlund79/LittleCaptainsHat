extends RefCounted
## Session state, routes, ports, projection and geographic maths.


func run(t: Node) -> void:
	var catalog := PortCatalog.get_default()
	t.check(catalog != null and catalog.ports.size() >= 150,
		"port catalog loads about 150 European harbours (Iteration 006; got %d)" % catalog.ports.size())
	t.check(catalog.has_port(&"copenhagen") and catalog.has_port(&"kiel"), "Copenhagen and Kiel use stable ids")

	# Geographic maths and projection.
	var cph := catalog.get_port(&"copenhagen").get_geo_position()
	var kiel := catalog.get_port(&"kiel").get_geo_position()
	var nm := GeoMath.distance_nm(cph, kiel)
	t.check(nm > 105.0 and nm < 125.0, "Copenhagen-Kiel great-circle distance is ~116 nm (got %.1f)" % nm)
	var projection := MapProjection.new(160.0)
	var round_trip := projection.map_to_geo(projection.geo_to_map(kiel))
	t.check(round_trip.distance_to(kiel) < 0.0001, "projection round-trips geographic coordinates")
	t.check(projection.geo_to_map(cph).y < projection.geo_to_map(kiel).y, "north is up in map space")

	# Session state serialization round trip.
	var state := SessionState.create_new(&"copenhagen", SessionState.AREA_INTERIOR, &"start")
	state.player_position = Vector2(12.5, -40.25)
	state.has_player_position = true
	state.planned_route = t.make_route(&"copenhagen", &"kiel", [Vector2(12.6, 54.6)] as Array[Vector2])
	t.check(state.planned_route != null, "a sea route with a waypoint can be planned")
	var errors: Array[String] = []
	var json := JSON.stringify(state.to_dict())
	var restored := SessionState.from_dict(JSON.parse_string(json), errors)
	t.check(restored != null and errors.is_empty(), "session state survives a JSON round trip")
	if restored:
		t.check_eq(restored.to_dict(), state.to_dict(), "restored state equals the original")
		t.check_eq(restored.planned_route.waypoints.size(), 1, "route waypoints are preserved")

	# A spawn point is stored instead of a position when none is known yet.
	var fresh := SessionState.create_new(&"copenhagen", SessionState.AREA_EXTERIOR, &"from_cabin")
	var fresh_restored := SessionState.from_dict(fresh.to_dict(), errors)
	t.check(fresh_restored != null and not fresh_restored.has_player_position
		and fresh_restored.spawn_point == &"from_cabin", "spawn point round-trips when no position is known")

	# Invalid data is rejected as a whole.
	var cases := {
		"non-object session": "nope",
		"missing boat": {"player": {"spawn_point": "start"}, "navigation": {"location_id": "kiel"}},
		"unknown boat area": _with(state, ["boat", "area"], "engine_room"),
		"non-numeric position": _with(state, ["player", "position", "x"], "12"),
		"infinite position": _with(state, ["player", "position", "y"], INF),
		"unknown location": _with(state, ["navigation", "location_id"], "atlantis"),
		"route to unknown port": _with(state, ["navigation", "planned_route", "destination"], "atlantis"),
		"route path not ending at destination": _with(state, ["navigation", "planned_route", "destination"], "gibraltar"),
		"bad waypoint": _with(state, ["navigation", "planned_route", "waypoints"], [{"lon": 500, "lat": 0}]),
		"invalid clock": _with(state, ["clock", "time_scale"], 7),
		"unknown vessel status": _with(state, ["vessel", "status"], "sinking"),
		"underway without voyage": _with(state, ["vessel", "status"], "underway"),
	}
	for case_name: String in cases:
		var case_errors: Array[String] = []
		var result := SessionState.from_dict(cases[case_name], case_errors)
		t.check(result == null and not case_errors.is_empty(), "rejects invalid session data: " + case_name)

	# Route planning through GameSession.
	GameSession.start_new_session()
	t.check(not GameSession.plan_route_to(&"copenhagen").is_empty(), "cannot plan a route to the current port")
	t.check(not GameSession.plan_route_to(&"atlantis").is_empty(), "cannot plan a route to an unknown port")
	t.check_eq(GameSession.plan_route_to(&"kiel"), "", "can plan a route to Kiel")
	t.check_eq(GameSession.get_planned_route().destination_port_id, &"kiel", "planned route points at Kiel")
	t.check(GameSession.has_unsaved_changes(), "planning a route marks the session as changed")
	GameSession.clear_planned_route()
	t.check(GameSession.get_planned_route() == null, "route can be cleared")
	GameSession.end_session()
	t.check(not GameSession.is_active(), "session can be ended")


## Copy of the state's dictionary with one nested value replaced.
func _with(state: SessionState, path: Array, value: Variant) -> Dictionary:
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var node: Variant = data
	for i in path.size() - 1:
		node = node[path[i]]
	node[path[path.size() - 1]] = value
	return data
