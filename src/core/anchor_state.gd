class_name AnchorState
extends RefCounted
## The anchor (Iteration 13): whether the boat lies at anchor, where, on how
## much chain, how well it was set and how it is holding.
##
## Anchoring happens during a voyage, off a coast: the voyage pauses where the
## boat is and continues when the anchor is raised. Plain data in
## SessionState, written only by GameSession (and its anchor checks, called by
## Simulation on its fixed evaluation grid).

const HOLDING_WELL := &"well"
const HOLDING_FAIR := &"fair"
const HOLDING_POOR := &"poor"
const HOLDING_DRAGGING := &"dragging"
const HOLDINGS: Array[StringName] = [HOLDING_WELL, HOLDING_FAIR, HOLDING_POOR, HOLDING_DRAGGING]
## Chain out per depth (scope): the choices offered.
const SCOPES: Array[int] = [3, 5, 7]

var active := false
## Where the anchor holds the boat (lon, lat); dragging moves it.
var position := Vector2.ZERO
var scope := 5
## How well the anchor was set (0..1, from the setting interaction).
var set_quality := 0.5
var holding: StringName = HOLDING_WELL
## Distance dragged since anchoring (nm).
var dragged_nm := 0.0
## The anchor alarm is sounding (poor holding or dragging), until answered.
var alarm := false
var anchored_at := 0.0
## Anchor checks have been made up to this game time (Simulation only).
var checked_until := 0.0
## Dragging was seen on this stay (for "first answered dragging").
var dragged_this_stay := false


func duplicate_state() -> AnchorState:
	var copy := AnchorState.new()
	copy.active = active
	copy.position = position
	copy.scope = scope
	copy.set_quality = set_quality
	copy.holding = holding
	copy.dragged_nm = dragged_nm
	copy.alarm = alarm
	copy.anchored_at = anchored_at
	copy.checked_until = checked_until
	copy.dragged_this_stay = dragged_this_stay
	return copy


func to_dict() -> Dictionary:
	return {"active": active, "position": {"lon": position.x, "lat": position.y}, "scope": scope, "set_quality": set_quality,
		"holding": String(holding), "dragged_nm": dragged_nm, "alarm": alarm, "anchored_at": anchored_at,
		"checked_until": checked_until, "dragged_this_stay": dragged_this_stay}


static func from_dict(data: Variant, errors: Array[String]) -> AnchorState:
	if not data is Dictionary:
		errors.append("missing anchor record")
		return null
	var state := AnchorState.new()
	var position: Variant = data.get("position")
	if not data.get("active") is bool or not data.get("alarm") is bool or not data.get("dragged_this_stay") is bool \
			or not position is Dictionary or not _is_number(position.get("lon")) or not _is_number(position.get("lat")) \
			or not StringName(str(data.get("holding"))) in HOLDINGS or not _is_number(data.get("scope")) or not int(data.scope) in SCOPES:
		errors.append("invalid anchor record")
		return null
	for key in ["set_quality", "dragged_nm", "anchored_at", "checked_until"]:
		if not _is_number(data.get(key)):
			errors.append("invalid anchor record (%s)" % key)
			return null
	state.active = data.active
	state.position = Vector2(float(position.lon), float(position.lat))
	state.scope = int(data.scope)
	state.set_quality = clampf(float(data.set_quality), 0.0, 1.0)
	state.holding = StringName(data.holding)
	state.dragged_nm = maxf(float(data.dragged_nm), 0.0)
	state.alarm = data.alarm and state.active
	state.anchored_at = float(data.anchored_at)
	state.checked_until = float(data.checked_until)
	state.dragged_this_stay = data.dragged_this_stay
	return state


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
