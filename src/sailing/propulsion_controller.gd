class_name PropulsionController
extends RefCounted
## Automatic choice between sailing and motoring (pure logic, no state of its
## own). Called by Simulation at every evaluation point with the potential
## sail-only speed for the current position, heading and wind.
##
## Rules (all thresholds from VesselProfile):
## - The potential sailing speed is averaged over time with an exponential
##   moving average (time constant ~1 game hour). The update uses elapsed game
##   time, so it does not depend on frame rate or time acceleration.
## - Sail -> engine when the average drops below engine_start_below_kn, after
##   at least min_sail_time_s under sail.
## - Near-stall: if the potential stays below stall_below_kn for stall_delay_s,
##   the engine starts regardless of the average or minimum time.
## - Engine -> sail when the average has stayed above engine_stop_above_kn for
##   engine_stop_confirm_s, the current potential is above it too, and the
##   engine has run at least min_engine_time_s.
## The gap between 3.5 and 6 kn plus the minimum times is the hysteresis that
## prevents cycling. While motoring the potential keeps being evaluated.
## - A course change of more than heading_reset_deg (new route leg, waypoint,
##   change of course) restarts the averaging from the new heading's potential,
##   so an old average from a different point of sail is not kept.


static func evaluate(state: PropulsionState, profile: VesselProfile, now: float, heading_deg: float,
		wind: WindField.Sample, force_reset := false) -> PropulsionState:
	var next := state.duplicate_state()
	var angle := WindField.relative_angle(heading_deg, wind.from_deg)
	var potential := profile.sail_speed_kn(wind.speed_kn, angle)
	var dt := maxf(now - state.last_evaluation_time, 0.0) if state.initialised else 0.0
	var turned := state.initialised and absf(WindField.relative_angle(state.heading_deg, heading_deg)) > profile.heading_reset_deg

	if not state.initialised:
		next.initialised = true
		next.average_potential_kn = potential
		next.mode_seconds = 0.0
		next.stall_seconds = 0.0
		next.favorable_seconds = 0.0
		next.mode = PropulsionState.MODE_ENGINE if potential < profile.engine_start_below_kn else PropulsionState.MODE_SAIL
		next.engine_reason = PropulsionState.REASON_START if next.mode == PropulsionState.MODE_ENGINE else PropulsionState.REASON_NONE
	else:
		# The previous potential held for the whole interval just elapsed.
		var alpha := 1.0 - exp(-dt / profile.averaging_time_s)
		next.average_potential_kn += (state.potential_kn - state.average_potential_kn) * alpha
		next.stall_seconds = state.stall_seconds + dt if state.potential_kn < profile.stall_below_kn else 0.0
		next.favorable_seconds = state.favorable_seconds + dt if next.average_potential_kn > profile.engine_stop_above_kn else 0.0
		next.mode_seconds = state.mode_seconds + dt
		if turned or force_reset:
			next.average_potential_kn = potential
			next.stall_seconds = 0.0
			next.favorable_seconds = 0.0
		_decide(next, profile, potential)

	next.potential_kn = potential
	next.speed_kn = profile.engine_speed_kn if next.is_motoring() else potential
	next.last_evaluation_time = now
	next.heading_deg = heading_deg
	next.wind_from_deg = wind.from_deg
	next.wind_speed_kn = wind.speed_kn
	next.true_wind_angle = angle
	next.spinnaker = next.sails_set() and profile.wants_spinnaker(angle)
	return next


static func _decide(state: PropulsionState, profile: VesselProfile, potential: float) -> void:
	if state.mode == PropulsionState.MODE_SAIL:
		var stalled := potential < profile.stall_below_kn and state.stall_seconds >= profile.stall_delay_s
		var poor := state.average_potential_kn < profile.engine_start_below_kn and state.mode_seconds >= profile.min_sail_time_s
		if stalled or poor:
			state.mode = PropulsionState.MODE_ENGINE
			state.engine_reason = PropulsionState.REASON_STALL if stalled else PropulsionState.REASON_POOR
			state.mode_seconds = 0.0
			state.favorable_seconds = 0.0
	else:
		if state.mode_seconds >= profile.min_engine_time_s and state.favorable_seconds >= profile.engine_stop_confirm_s \
				and potential > profile.engine_stop_above_kn:
			state.mode = PropulsionState.MODE_SAIL
			state.engine_reason = PropulsionState.REASON_NONE
			state.mode_seconds = 0.0
			state.stall_seconds = 0.0
