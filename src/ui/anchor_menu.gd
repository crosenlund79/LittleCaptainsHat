class_name AnchorMenu
extends SimplePanel
## The anchor at the windlass (Iteration 13).
##
## Not anchored: the anchorage here in the wind now (good / fair / poor /
## unsuitable, and why), the chain to let out (3, 5 or 7 times the depth) and
## "Drop anchor". Setting it is a short interaction: a marker swings across a
## bar and "Set it now" catches it; nearer the middle sets the anchor better.
## Anchored: how it is holding, more or less chain, setting it again, the
## alarm, and raising it to sail on.
##
## The model is a conservative gameplay rule without depth soundings (see
## AnchorSite); the panel says so. GameSession does every change; the App
## spends the time each job takes (`time_requested`).

signal time_requested(minutes: float)

## Game minutes for letting go and setting, adjusting, and weighing anchor.
const DROP_MINUTES := 15.0
const ADJUST_MINUTES := 10.0
const RAISE_MINUTES := 10.0
## How fast the setting marker swings (cycles per real second).
const SET_SPEED := 0.55
const HOLDING_COLOURS := {
	AnchorState.HOLDING_WELL: Color(0.75, 0.92, 0.7), AnchorState.HOLDING_FAIR: Color(0.93, 0.92, 0.86),
	AnchorState.HOLDING_POOR: Color(1.0, 0.86, 0.62), AnchorState.HOLDING_DRAGGING: Color(1.0, 0.62, 0.55),
}

var _site: Label
var _holding: Label
var _scope: OptionButton
var _set_box: VBoxContainer
var _set_bar: Control
var _set_button: Button
var _drop: Button
var _reset: Button
var _ack: Button
var _raise: Button
var _limits: Label
## The setting interaction: running, for dropping or re-setting.
var _setting := false
var _setting_for_drop := true
var _marker := 0.0
var _time := 0.0


func _ready() -> void:
	_build("Anchor", 700.0)
	_site = _label("Site", "")
	_holding = _label("Holding", "", &"HeaderLabel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_box.add_child(row)
	var chain := Label.new()
	chain.text = "Chain to let out"
	row.add_child(chain)
	_scope = OptionButton.new()
	_scope.name = "Scope"
	for scope in AnchorState.SCOPES:
		_scope.add_item("%d × the depth%s" % [scope, {3: " (short)", 5: " (usual)", 7: " (long, holds best)"}[scope]])
	_scope.select(1)
	_scope.item_selected.connect(_on_scope_selected)
	row.add_child(_scope)
	_set_box = VBoxContainer.new()
	_set_box.name = "Setting"
	_set_box.visible = false
	_box.add_child(_set_box)
	var hint := Label.new()
	hint.text = "Setting the anchor: back down gently. Press \"Set it now\" (or E) as the marker crosses the green middle."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(620, 0)
	_set_box.add_child(hint)
	_set_bar = Control.new()
	_set_bar.name = "SetBar"
	_set_bar.custom_minimum_size = Vector2(620, 30)
	_set_bar.draw.connect(_draw_set_bar)
	_set_box.add_child(_set_bar)
	_set_button = Button.new()
	_set_button.name = "SetButton"
	_set_button.text = "Set it now"
	_set_button.custom_minimum_size = Vector2(200, 40)
	_set_button.pressed.connect(func() -> void: catch_set())
	_set_box.add_child(_set_button)
	_limits = _label("Limits", "No depth soundings aboard this chart: anchoring is offered within %.1f nm of land, shelter is judged from the open water upwind, and the bottom is taken to be ordinary mixed ground everywhere." % AnchorSite.MAX_LAND_NM, &"MutedLabel")
	_button("CloseButton", "Close", close)
	_ack = _button("AckButton", "Alarm seen", _on_ack)
	_reset = _button("ResetButton", "Set it again", func() -> void: start_setting(false))
	_raise = _button("RaiseButton", "Raise anchor", _on_raise)
	_drop = _button("DropButton", "Drop anchor", func() -> void: start_setting(true), 200.0)
	GameSession.anchor_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	var anchored := GameSession.is_anchored()
	var refusal := GameSession.anchoring_refusal()
	if anchored:
		var anchor := GameSession.get_anchor()
		var site := GameSession.evaluate_anchorage()
		var wind := Simulation.get_weather_at_vessel()
		_site.text = "At anchor on %d × the depth of chain, %s. %s" % [anchor.scope, String(site.get("shelter", "")),
			Hud.describe_wind(wind) + "."]
		if anchor.dragged_nm > 0.0:
			_site.text += "  Dragged %.2f nm so far." % anchor.dragged_nm
		_holding.text = AnchorSite.holding_text(anchor.holding) + ("  ·  ALARM" if anchor.alarm else "")
		_holding.modulate = HOLDING_COLOURS.get(anchor.holding, Color.WHITE)
		_scope.select(AnchorState.SCOPES.find(anchor.scope))
	else:
		var site := GameSession.evaluate_anchorage() if GameSession.is_underway() else {}
		_site.text = refusal if refusal != "" else String(site.reason)
		_holding.text = {AnchorSite.CLASS_GOOD: "A good anchorage", AnchorSite.CLASS_FAIR: "A fair anchorage",
			AnchorSite.CLASS_POOR: "An exposed anchorage"}.get(StringName(site.get("class", "")), "No anchorage here")
		_holding.modulate = Color(1.0, 0.86, 0.62) if refusal != "" or site.get("class", "") == AnchorSite.CLASS_POOR else Color(0.93, 0.92, 0.86)
	_drop.visible = not anchored
	_drop.disabled = refusal != "" or _setting
	_raise.visible = anchored
	_raise.disabled = _setting
	_reset.visible = anchored
	_reset.disabled = _setting
	_ack.visible = anchored and GameSession.get_anchor().alarm
	_scope.disabled = _setting or (not anchored and refusal != "")


func focus_default() -> void:
	if _drop.visible and not _drop.disabled:
		_drop.grab_focus()
	elif _raise.visible:
		_raise.grab_focus()
	else:
		(find_child("CloseButton", true, false) as Button).grab_focus()


func get_scope() -> int:
	return AnchorState.SCOPES[maxi(_scope.selected, 0)]


func set_scope(scope: int) -> void:
	_scope.select(AnchorState.SCOPES.find(scope))
	_on_scope_selected(_scope.selected)


## More or less chain at anchor works out the holding again (a few minutes).
func _on_scope_selected(index: int) -> void:
	if not GameSession.is_anchored() or AnchorState.SCOPES[index] == GameSession.get_anchor().scope:
		return
	var holding := GameSession.adjust_anchor(AnchorState.SCOPES[index])
	AudioManager.play_sfx(FishingSounds.chain(), FishingSounds.DB)
	SessionLog.write("anchor", {"action": "scope", "scope": AnchorState.SCOPES[index], "holding": String(holding)})
	time_requested.emit(ADJUST_MINUTES)
	notify("%d × the depth of chain out: %s." % [AnchorState.SCOPES[index], AnchorSite.holding_text(holding).to_lower()])
	refresh()


## Begins the setting interaction (for dropping, or setting it again).
func start_setting(for_drop: bool) -> void:
	if for_drop and GameSession.anchoring_refusal() != "":
		notify(GameSession.anchoring_refusal())
		return
	_setting = true
	_setting_for_drop = for_drop
	_marker = 0.0
	_set_box.visible = true
	_set_button.grab_focus()
	if for_drop:
		AudioManager.play_sfx(FishingSounds.chain(), FishingSounds.DB)
	refresh()


func is_setting() -> bool:
	return _setting


## Where the marker is now (0..1 across the bar).
func get_marker() -> float:
	return 0.5 - 0.5 * cos(_marker * TAU)


## How well a catch at `marker` sets the anchor (1 in the middle).
static func set_quality_at(marker: float) -> float:
	return clampf(1.0 - absf(marker - 0.5) * 2.0, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	if _setting:
		_marker += delta * SET_SPEED
		_set_bar.queue_redraw()
		if Input.is_action_just_pressed(&"interact"):
			catch_set()


## Catches the marker now (or at `at`, tests): drops or re-sets the anchor.
func catch_set(at := -1.0) -> Dictionary:
	if not _setting:
		return {}
	var quality := set_quality_at(get_marker() if at < 0.0 else at)
	_setting = false
	_set_box.visible = false
	var result := {}
	if _setting_for_drop:
		result = GameSession.drop_anchor(get_scope(), quality)
		SessionLog.write("anchor", {"action": "drop", "scope": get_scope(), "set": snappedf(quality, 0.01), "error": result.error,
			"holding": String(result.holding), "class": String(result.site.get("class", ""))})
		if result.error != "":
			notify(result.error)
		else:
			time_requested.emit(DROP_MINUTES)
			notify("The anchor is down and %s: %s." % ["well set" if quality >= 0.7 else ("set" if quality >= 0.35 else "barely set"),
				AnchorSite.holding_text(result.holding).to_lower()])
	else:
		var holding := GameSession.adjust_anchor(get_scope(), quality)
		result = {"error": "", "holding": holding}
		SessionLog.write("anchor", {"action": "reset", "scope": get_scope(), "set": snappedf(quality, 0.01), "holding": String(holding)})
		time_requested.emit(ADJUST_MINUTES)
		notify("Set again: %s." % AnchorSite.holding_text(holding).to_lower())
	result["set_quality"] = quality
	refresh()
	return result


func _on_ack() -> void:
	GameSession.acknowledge_anchor_alarm()
	SessionLog.write("anchor", {"action": "acknowledge"})
	refresh()


func _on_raise() -> void:
	var error := GameSession.raise_anchor()
	if error != "":
		notify(error)
		return
	AudioManager.play_sfx(FishingSounds.chain(), FishingSounds.DB)
	SessionLog.write("anchor", {"action": "raise"})
	time_requested.emit(RAISE_MINUTES)
	notify("Anchor up. The voyage continues.")
	refresh()


func get_site_text() -> String:
	return _site.text


func get_holding_text() -> String:
	return _holding.text


func _draw_set_bar() -> void:
	var size := _set_bar.size
	_set_bar.draw_rect(Rect2(Vector2(0, 8), Vector2(size.x, size.y - 16)), Color(0.12, 0.16, 0.18))
	_set_bar.draw_rect(Rect2(Vector2(size.x * 0.35, 8), Vector2(size.x * 0.3, size.y - 16)), Color(0.48, 0.63, 0.36, 0.8))
	_set_bar.draw_rect(Rect2(Vector2(size.x * 0.45, 8), Vector2(size.x * 0.1, size.y - 16)), Color(0.6, 0.8, 0.45))
	var x := get_marker() * size.x
	_set_bar.draw_rect(Rect2(Vector2(x - 3, 0), Vector2(6, size.y)), Color(0.98, 0.95, 0.85))
