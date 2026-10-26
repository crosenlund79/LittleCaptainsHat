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
## Life at anchor (0.102b): the quiet moments this stay has already had
## ("settled", "evening:<day>", "wake:<day>", "pet"), so none repeats after a
## reload. Optional in saves (older saves have none); bounded.
var moments: Array[String] = []
const MAX_MOMENTS := 16
## Revision 0.105b (optional in saves; older saves: a normal anchor, depth
## unknown). Which anchor is down ("normal" or "magic"), the depth where it
## went down and where that depth came from (DepthService source: in this
## build a game estimate), and the small holding bonus a well-placed Magic
## Anchor earned (knots, at most MAGIC_BONUS_MAX_KN). One anchored state for
## every kind: the same holding and drag model applies.
const KIND_NORMAL := &"normal"
const KIND_MAGIC := &"magic"
const MAGIC_BONUS_MAX_KN := 3.0
var kind: StringName = KIND_NORMAL
var depth_m := -1.0
var depth_source: StringName = &""
var bonus_kn := 0.0


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
	copy.moments = moments.duplicate()
	copy.kind = kind
	copy.depth_m = depth_m
	copy.depth_source = depth_source
	copy.bonus_kn = bonus_kn
	return copy


func to_dict() -> Dictionary:
	return {"active": active, "position": {"lon": position.x, "lat": position.y}, "scope": scope, "set_quality": set_quality,
		"holding": String(holding), "dragged_nm": dragged_nm, "alarm": alarm, "anchored_at": anchored_at,
		"checked_until": checked_until, "dragged_this_stay": dragged_this_stay, "moments": moments.duplicate(),
		"kind": String(kind), "depth_m": depth_m, "depth_source": String(depth_source), "bonus_kn": bonus_kn}


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
	var moments: Variant = data.get("moments", [])
	if moments is Array:
		for moment: Variant in moments:
			if moment is String and not moment in state.moments and state.moments.size() < MAX_MOMENTS:
				state.moments.append(moment)
	# 0.105b optional fields (absent in older saves: a normal anchor).
	state.kind = KIND_MAGIC if str(data.get("kind", "")) == String(KIND_MAGIC) else KIND_NORMAL
	state.depth_m = float(data.depth_m) if _is_number(data.get("depth_m")) else -1.0
	state.depth_source = StringName(str(data.get("depth_source", ""))) if data.get("depth_source") is String else &""
	state.bonus_kn = clampf(float(data.bonus_kn), 0.0, MAGIC_BONUS_MAX_KN) if _is_number(data.get("bonus_kn")) else 0.0
	return state


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
