class_name TimingCheck
extends RefCounted
## A circular timing check (Revision 0.105b, extracted from the Iteration 18
## reel): a needle goes round a dial at one constant speed; press while it is
## inside the target arc. Each good press is one check; the check succeeds
## after `checks_needed` of them. After each good press the arc moves to a new
## place on the dial, well ahead of the needle. Inside the arc a smaller
## Perfect zone; what a Perfect is worth is the encounter's business.
##
## Misses: `line_control` misses are allowed; the check fails only when all are
## used. Not pressing costs nothing: the needle just goes round again. Presses
## come at most every DEBOUNCE seconds (a held or bouncing key is one press).
## If nothing is pressed for IDLE_SECONDS the check fails. Real time, so 20x
## never rushes it. The needle never speeds up and nothing fails at random.
##
## Pure state, no encounter rules: the fishing reel (ReelTiming) and the
## Magic Anchor (MagicAnchorDeployment) each wrap it with their own.
## RESULT_LANDED / RESULT_ESCAPED are its success / failure (the names come
## from the reel it began as).

## Degrees per second; one turn of the dial takes 1.8 s. Never varies.
const SPEED_DEG := 200.0
const LINE_CONTROL := 3
## The Perfect zone is this share of the target arc (at least PERFECT_MIN_DEG).
const PERFECT_SHARE := 0.3
const PERFECT_MIN_DEG := 10.0
const DEBOUNCE := 0.15
const IDLE_SECONDS := 60.0

const RESULT_NONE := &""
const RESULT_LANDED := &"landed"
const RESULT_ESCAPED := &"escaped"

const PRESS_NONE := &""
const PRESS_PERFECT := &"perfect"
const PRESS_HIT := &"hit"
const PRESS_MISS := &"miss"

var checks_needed := 1
## Misses allowed before the check fails (LINE_CONTROL unless an encounter asks otherwise).
var line_control := LINE_CONTROL
var arc_deg := 60.0
## The needle, degrees clockwise from the top of the dial, 0..360.
var angle := 0.0
## The middle of the target arc, degrees.
var target_deg := 180.0
var hits := 0
var perfects := 0
var misses := 0
var elapsed := 0.0
var result: StringName = RESULT_NONE
## The latest press's outcome (for the dial's flash).
var last_press: StringName = PRESS_NONE
var _since_press := 0.0
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


## `checks` presses needed, `arc` the target arc in degrees; `seed` places
## the arcs (deterministic).
func _init(checks := 1, arc := 60.0, seed := 0) -> void:
	checks_needed = maxi(checks, 1)
	arc_deg = clampf(arc, 10.0, 180.0)
	_rng.seed = seed
	target_deg = fposmod(angle + _rng.randf_range(150.0, 230.0), 360.0)


func is_over() -> bool:
	return result != RESULT_NONE


func get_perfect_deg() -> float:
	return maxf(arc_deg * PERFECT_SHARE, PERFECT_MIN_DEG)


func get_line_control() -> int:
	return line_control - misses


## Angular distance from the needle to the arc's middle (0..180).
func distance_to_target(at := -1.0) -> float:
	var a := angle if at < 0.0 else at
	return absf(wrapf(a - target_deg, -180.0, 180.0))


func is_in_arc(at := -1.0) -> bool:
	return distance_to_target(at) <= arc_deg / 2.0


func is_in_perfect(at := -1.0) -> bool:
	return distance_to_target(at) <= get_perfect_deg() / 2.0


## Advances the needle by `delta` real seconds.
func step(delta: float) -> void:
	if is_over() or delta <= 0.0:
		return
	elapsed += delta
	_since_press += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	angle = fposmod(angle + SPEED_DEG * delta, 360.0)
	if _since_press >= IDLE_SECONDS:
		result = RESULT_ESCAPED


## The captain presses now. Returns PRESS_PERFECT, PRESS_HIT, PRESS_MISS, or
## PRESS_NONE when the press does not count (over, or within DEBOUNCE).
func press() -> StringName:
	if is_over() or _cooldown > 0.0:
		return PRESS_NONE
	_cooldown = DEBOUNCE
	_since_press = 0.0
	if is_in_arc():
		var perfect := is_in_perfect()
		hits += 1
		if perfect:
			perfects += 1
		last_press = PRESS_PERFECT if perfect else PRESS_HIT
		if hits >= checks_needed:
			result = RESULT_LANDED
		else:
			# The next arc, well ahead of the needle.
			target_deg = fposmod(angle + _rng.randf_range(130.0, 250.0), 360.0)
		return last_press
	misses += 1
	last_press = PRESS_MISS
	if misses >= line_control:
		result = RESULT_ESCAPED
	return last_press
