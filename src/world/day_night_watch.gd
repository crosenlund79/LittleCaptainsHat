class_name DayNightWatch
extends Node
## Dawn and dusk, gently (The Well-Run Ship). During ordinary play, when the
## sun at the boat starts the morning twilight (rises through NIGHT_BELOW) or
## the evening one (sinks through DAY_ABOVE), the game asks App to show the
## date card (TimePassage) and, under the black, lets the twilight pass with
## the normal simulation (Simulation.advance: stores, weather, wear and events
## exactly as always; it stops early for an event) until the day or the night
## has fully come. The interface and the boat's light then take the new hour
## at once, and the game fades back.
##
## Once per twilight: only a crossing seen in continuous play counts. A jump
## in time (sleep, loading, work, an outing ashore) is never mistaken for one,
## and nothing shows while a menu is open, the game or the passage clock runs
## (Long Passage), or another time passage is already on screen. Where the
## twilight lasts longer than MAX_SKIP_SECONDS (high latitudes in summer) no
## card is shown and the light simply changes slowly, as before.
##
## Pausable: when the game is paused (menus) it does not look.

## The same thresholds as the interface's day and night (UiTheme).
const NIGHT_BELOW := -6.0
const DAY_ABOVE := 4.0
## The longest twilight passed under the black (game seconds).
const MAX_SKIP_SECONDS := 2.0 * 3600.0
## A larger step of game time between two looks is a jump, not play.
const MAX_GAP_SECONDS := 1800.0

## Set by App: it shows the card (play_new_light) and knows the screen.
var app: Node

var _last_time := -1.0
var _last_elevation := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	GameSession.state_replaced.connect(forget)
	GameSession.session_started.connect(forget)


## Forgets the last look (after a load or a new game: no crossing yet).
func forget() -> void:
	_last_time = -1.0


func _process(_delta: float) -> void:
	if not GameSession.is_active():
		_last_time = -1.0
		return
	var now := GameSession.get_game_time()
	var geo := GameSession.get_vessel_position()
	var elevation := Daylight.sun_elevation(geo, now)
	var previous_time := _last_time
	var previous := _last_elevation
	_last_time = now
	_last_elevation = elevation
	if previous_time < 0.0 or now <= previous_time or now - previous_time > MAX_GAP_SECONDS:
		return
	var dawn := previous < NIGHT_BELOW and elevation >= NIGHT_BELOW
	var dusk := previous > DAY_ABOVE and elevation <= DAY_ABOVE
	if not (dawn or dusk) or not can_show():
		return
	var until := twilight_end(geo, now, dusk)
	if until > now:
		app.play_new_light(now, until, dusk)


## True when a card may show now: in play (aboard or at the chart), no menu,
## no screen change, no other time passage, no Long Passage, presentation on.
func can_show() -> bool:
	return TimePassage.is_shown() and app != null and app.can_show_time_passage() and not Simulation.is_passage_running() \
		and not GameSession.is_asleep()


## The game time the twilight that starts at `from` ends (the sun above
## DAY_ABOVE in the morning, below NIGHT_BELOW in the evening), or -1 when it
## lasts longer than MAX_SKIP_SECONDS. The boat's position is taken as fixed
## (it moves a few miles at most in that time).
static func twilight_end(geo: Vector2, from: float, evening: bool) -> float:
	var t := from
	while t - from <= MAX_SKIP_SECONDS:
		t += 60.0
		var elevation := Daylight.sun_elevation(geo, t)
		if (evening and elevation <= NIGHT_BELOW) or (not evening and elevation >= DAY_ABOVE):
			return t
	return -1.0
