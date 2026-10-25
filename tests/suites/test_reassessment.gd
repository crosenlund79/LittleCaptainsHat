extends RefCounted
## Propulsion reassessment (Iteration 003b): after a change of course and on
## the helm's "Check sail configuration". Fresh conditions may decide at once,
## but the minimum times per mode still prevent rapid switching, and repeated
## checks never reset the controller's timers.

const BEAM := 100.0
const APP := preload("res://src/app/app.gd")

var t: Node
var profile: VesselProfile


func run(runner: Node) -> void:
	t = runner
	profile = VesselProfile.get_default()
	Simulation.auto_advance = false
	_test_controller_reassessment()
	_test_heading_reset_keeps_stall()
	_test_course_change_at_sea()
	_test_helm_check()
	_test_helm_cannot_force()
	Simulation.auto_advance = true
	t.use_calm_wind()
	GameSession.end_session()


## Wind on the beam (heading north) giving `potential` knots of sailing speed.
func _wind_for(potential: float, from := BEAM) -> WindField.Sample:
	if potential <= 0.0:
		return WindField.Sample.make(from, 0.0)
	var low := 0.0
	var high := 60.0
	for i in 60:
		var mid := (low + high) / 2.0
		if profile.sail_speed_kn(mid, from) < potential:
			low = mid
		else:
			high = mid
	return WindField.Sample.make(from, high)


## Runs the controller every 300 s with a constant potential.
func _hold(state: PropulsionState, potential: float, seconds: float) -> PropulsionState:
	var time := state.last_evaluation_time
	var end := time + seconds
	while time < end - 1e-6:
		time += 300.0
		state = PropulsionController.evaluate(state, profile, time, 0.0, _wind_for(potential))
	return state


func _start(potential: float) -> PropulsionState:
	return PropulsionController.evaluate(PropulsionState.new(), profile, 0.0, 0.0, _wind_for(potential))


func _test_controller_reassessment() -> void:
	# Motoring for an hour in light air, then a reassessment in a good breeze.
	var motoring := _hold(_start(2.0), 2.0, 3600.0)
	var now := motoring.last_evaluation_time + 60.0
	var normal := PropulsionController.evaluate(motoring, profile, now, 0.0, _wind_for(7.5))
	t.check(normal.is_motoring(), "without a reassessment a good breeze needs to be confirmed first (still motoring)")
	var fresh := PropulsionController.evaluate(motoring, profile, now, 0.0, _wind_for(7.5), true, true)
	t.check(fresh.sails_set(), "a reassessment in clearly good conditions sets the sails at once")
	var marginal := PropulsionController.evaluate(motoring, profile, now, 0.0, _wind_for(5.0), true, true)
	t.check(marginal.is_motoring(), "a reassessment in marginal conditions (5 kn) keeps the engine (hysteresis)")

	# Just started the engine: even clearly good conditions wait for the minimum engine time.
	var just_started := _hold(_start(7.0), 0.0, 900.0)  # becalmed: engine after 10 min
	t.check(just_started.is_motoring() and just_started.mode_seconds < profile.min_engine_time_s,
		"(setup) the engine has only just started")
	var too_soon := PropulsionController.evaluate(just_started, profile, just_started.last_evaluation_time + 60.0, 0.0,
		_wind_for(8.0), true, true)
	t.check(too_soon.is_motoring(), "the minimum engine time still applies to a reassessment (no rapid cycling)")

	# Sailing for an hour, then a course change into poor wind.
	var sailing := _hold(_start(7.0), 7.0, 3600.0)
	var poor := PropulsionController.evaluate(sailing, profile, sailing.last_evaluation_time + 60.0, 0.0, _wind_for(2.0), true, true)
	t.check(poor.is_motoring() and poor.engine_reason == PropulsionState.REASON_POOR,
		"a reassessment in clearly poor conditions starts the engine at once (no hour-long wait on stale history)")
	var head_to_wind := PropulsionController.evaluate(sailing, profile, sailing.last_evaluation_time + 60.0, 0.0,
		WindField.Sample.make(0.0, 15.0), true, true)
	t.check(head_to_wind.is_motoring() and head_to_wind.engine_reason == PropulsionState.REASON_STALL,
		"turning head to wind: engine at once, reason 'becalmed or head to wind'")
	var just_set := _hold(_start(7.0), 7.0, 300.0)
	var early := PropulsionController.evaluate(just_set, profile, just_set.last_evaluation_time + 60.0, 0.0, _wind_for(2.0), true, true)
	t.check(early.sails_set(), "the minimum sailing time still applies to a reassessment")


func _test_heading_reset_keeps_stall() -> void:
	var becalmed := _hold(_start(7.0), 0.0, 600.0)
	t.check(becalmed.sails_set() and becalmed.stall_seconds > 0.0, "(setup) becalmed under sail, stall timer running")
	var turned := PropulsionController.evaluate(becalmed, profile, becalmed.last_evaluation_time + 300.0, 90.0, _wind_for(0.0), true)
	t.check(turned.stall_seconds >= becalmed.stall_seconds, "turning while still becalmed does not reset the stall timer")
	var turned_good := PropulsionController.evaluate(becalmed, profile, becalmed.last_evaluation_time + 300.0, 0.0, _wind_for(7.0), true)
	t.check_eq(turned_good.stall_seconds, 0.0, "turning into wind ends the stall")


func _start_voyage(from: StringName, to: StringName) -> void:
	GameSession.start_new_session()
	t.board(&"starling_33")  # timings written for the Wing 33's speeds
	if from != GameSession.START_LOCATION:
		var state := GameSession.get_state_snapshot()
		state.location_id = from
		state.vessel_position = PortCatalog.get_default().get_port(from).get_geo_position()
		GameSession.replace_state(state)
	GameSession.plan_route_to(to)
	GameSession.depart()


func _test_course_change_at_sea() -> void:
	# Copenhagen -> Kiel runs roughly south; a fresh southerly makes it a beat
	# (motoring), and the change of course towards Gothenburg (north) a run.
	t.set_wind(185.0, 22.0)
	_start_voyage(&"copenhagen", &"kiel")
	Simulation.advance(3.0 * 3600.0)
	var before := GameSession.get_propulsion()
	var position := GameSession.get_vessel_position()
	var progress_time := GameSession.get_game_time()
	t.check(before.is_motoring(), "(setup) motoring into a head wind on the way to Kiel (%s)" % before.describe())
	var error := GameSession.change_course(&"gothenburg", [] as Array[Vector2])
	var after := GameSession.get_propulsion()
	t.check(error.is_empty(), "the change of course is accepted")
	t.check(GameSession.get_vessel_position().distance_to(position) < 1e-9 and GameSession.get_game_time() == progress_time,
		"the vessel stays where it is and no time passes")
	t.check(after.last_evaluation_time == GameSession.get_game_time() and absf(after.heading_deg - Simulation.get_current_heading()) < 1e-6,
		"the new heading is assessed at once (%.0f° -> %.0f°)" % [before.heading_deg, after.heading_deg])
	t.check(after.sails_set() and after.potential_kn > profile.engine_stop_above_kn,
		"good conditions on the new heading set the sails at once, without the hour of stale history (%s)" % after.describe())
	t.check(is_equal_approx(after.average_potential_kn, after.potential_kn), "the rolling average restarts on the new heading")
	var hud_speed := GameSession.get_vessel_speed_kn()
	t.check(is_equal_approx(hud_speed, after.potential_kn), "the reported speed follows the new propulsion state")
	Simulation.advance(3600.0)
	t.check(GameSession.get_propulsion().sails_set(), "no switching back and forth after the change of course")


func _test_helm_check() -> void:
	t.set_wind(185.0, 14.0)
	_start_voyage(&"copenhagen", &"kiel")
	Simulation.advance(2.0 * 3600.0)
	var motoring := GameSession.get_propulsion()
	t.check(motoring.is_motoring(), "(setup) motoring to Kiel against the wind")
	# The wind veers to the north-west: a good breeze on the current heading.
	t.set_wind(320.0, 16.0)
	var position := GameSession.get_vessel_position()
	var result := Simulation.reassess_propulsion()
	t.check(result.changed and GameSession.get_propulsion().sails_set(),
		"checking the sails at the helm sets them when the conditions are clearly good now")
	t.check(GameSession.get_vessel_position() == position and GameSession.get_voyage().route.destination_port_id == &"kiel",
		"the check changes neither position nor course")
	var message := APP.describe_reassessment(result)
	t.check(message.begins_with("Sailing conditions favourable"), "the helm reports the result (%s)" % message)

	# Repeated checks right after the switch cannot bring the engine back (minimum sailing time).
	t.set_wind(0.0, 2.0)
	var switches := 0
	for i in 10:
		Simulation.advance(60.0)
		var check := Simulation.reassess_propulsion()
		switches += 1 if check.changed else 0
	t.check_eq(switches, 0, "ten checks within the minimum sailing time do not switch the mode")
	var unchanged := APP.describe_reassessment(Simulation.reassess_propulsion())
	t.check(unchanged.begins_with("Light wind"), "the helm explains why nothing changed yet (%s)" % unchanged)


func _test_helm_cannot_force() -> void:
	# Sailing well: checking cannot start the engine.
	t.set_wind(270.0, 15.0)
	_start_voyage(&"copenhagen", &"kiel")
	Simulation.advance(3600.0)
	var sailing := GameSession.get_propulsion()
	t.check(sailing.sails_set(), "(setup) sailing well")
	for i in 5:
		Simulation.reassess_propulsion()
	t.check(GameSession.get_propulsion().sails_set(), "checks never start the engine in good sailing conditions")
	t.check(APP.describe_reassessment(Simulation.reassess_propulsion()).begins_with("Sails are drawing well"),
		"the helm confirms good sailing")

	# Motoring in light air: checking cannot set the sails, and does not reset timers.
	t.set_wind(270.0, 3.0)
	_start_voyage(&"copenhagen", &"kiel")
	Simulation.advance(1800.0)
	var before := GameSession.get_propulsion()
	t.check(before.is_motoring(), "(setup) motoring in light air")
	Simulation.advance(600.0)
	var mid := GameSession.get_propulsion()
	for i in 5:
		Simulation.reassess_propulsion()
	var after := GameSession.get_propulsion()
	t.check(after.is_motoring(), "checks never stop the engine when sailing would be too slow")
	t.check(after.mode_seconds >= mid.mode_seconds and after.average_potential_kn > 0.0,
		"checks do not reset the controller's timers")
	t.check(APP.describe_reassessment(Simulation.reassess_propulsion()).begins_with("Insufficient sailing performance"),
		"the helm explains that it keeps motoring")
	t.check(Simulation.reassess_propulsion().is_empty() == false, "a check underway always returns a result")
	GameSession.end_session()
	GameSession.start_new_session()
	t.check(Simulation.reassess_propulsion().is_empty(), "in port there is nothing to check")
