class_name MagicAnchorDeployment
extends RefCounted
## Letting the Magic Anchor go (Revision 0.105b): the deployment's own rules
## around the shared circular TimingCheck (the fishing reel's dial, none of
## its catch state).
##
## The checks needed follow the wind (GameSession.magic_anchor_checks: 1 in
## ordinary conditions, 2 when it blows, 3 in a gale or storm); the target arc
## is a little narrower in harder wind but never narrower than ARC_STORM_DEG.
## The needle's speed never changes and nothing fails at random.
##
## A miss costs MISS_MINUTES of game time (hauling back and paying out
## again); MISSES_ALLOWED misses end the attempt: the anchor has not bitten,
## the boat is still unanchored and drifting with the weather, and the
## captain may try again or cancel. Cancelling is always allowed (nothing is
## let go). Success hands the anchoring to GameSession.drop_magic_anchor -
## the one anchored state - with each Perfect worth a small, bounded holding
## bonus there (AnchorState.MAGIC_BONUS_MAX_KN); the existing holding and drag
## model stays authoritative, so a perfect deployment is no promise of
## safety in later weather.

const MISS_MINUTES := 5.0
const MISSES_ALLOWED := 3
const ARC_CALM_DEG := 70.0
const ARC_BLOWING_DEG := 58.0
const ARC_STORM_DEG := 48.0

var check: TimingCheck
var attempts := 0


## A fresh attempt for `checks` good turns (1..3); `seed` places the arcs.
func _init(checks := 1, seed := 0) -> void:
	start(checks, seed)


func start(checks: int, seed: int) -> void:
	attempts += 1
	check = TimingCheck.new(checks, arc_for(checks), seed + attempts)
	check.line_control = MISSES_ALLOWED


static func arc_for(checks: int) -> float:
	match checks:
		1:
			return ARC_CALM_DEG
		2:
			return ARC_BLOWING_DEG
	return ARC_STORM_DEG


func is_over() -> bool:
	return check.is_over()


func succeeded() -> bool:
	return check.result == TimingCheck.RESULT_LANDED


func failed() -> bool:
	return check.result == TimingCheck.RESULT_ESCAPED


## How firmly it went down (0..1) for the holding model: a success is always
## at least a fair set; Perfects add to it.
func set_quality() -> float:
	return clampf(0.6 + 0.4 * float(check.perfects) / float(maxi(check.checks_needed, 1)), 0.0, 1.0)
