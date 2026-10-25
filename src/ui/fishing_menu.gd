class_name FishingMenu
extends SimplePanel
## The fishing rod (Iteration 13). Three faces:
##   - the rod: where you are fishing, how one fishes here (from a still boat,
##     or trolling), the lure, the line out or in, waiting for a bite, and the
##     cool box (release or sell a fish);
##   - the fight, when a fish is on: a tension bar and a progress bar; hold E
##     (or the Reel button) to reel in, let go to ease off. The bar turns red
##     with "Ease off!" well before the line could break;
##   - the catch: what came aboard and where it went.
## GameSession does every change; the App spends waiting time (wait_requested).

signal wait_requested(minutes: float)

const TENSION_OK := Color("#7ba05b")
const TENSION_WARN := Color("#c8553d")
## Waiting for a bite takes at most this long (game minutes).
const WAIT_MINUTES := 60.0

var _fight: FishFight
var _fight_box: VBoxContainer
var _rod_box: VBoxContainer
var _tension: ProgressBar
var _progress: ProgressBar
var _fight_label: Label
var _reel_button: Button
var _reel_held := false
var _info: Label
var _lure: OptionButton
var _line_button: Button
var _wait_button: Button
var _hold_box: VBoxContainer
var _outcome: Label
var _last_result := {}


func _ready() -> void:
	_build("Fishing rod", 680.0)
	_rod_box = VBoxContainer.new()
	_rod_box.name = "Rod"
	_rod_box.add_theme_constant_override(&"separation", 10)
	_box.add_child(_rod_box)
	_info = Label.new()
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(600, 0)
	_rod_box.add_child(_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_rod_box.add_child(row)
	_lure = OptionButton.new()
	_lure.name = "Lure"
	_lure.custom_minimum_size = Vector2(260, 0)
	_lure.item_selected.connect(_on_lure_selected)
	row.add_child(_lure)
	_line_button = Button.new()
	_line_button.name = "LineButton"
	_line_button.custom_minimum_size = Vector2(170, 0)
	_line_button.pressed.connect(_on_line)
	row.add_child(_line_button)
	_wait_button = Button.new()
	_wait_button.name = "WaitButton"
	_wait_button.text = "Wait for a bite"
	_wait_button.tooltip_text = "Let time pass at the rod until a fish bites (at most an hour)."
	_wait_button.pressed.connect(func() -> void: wait_requested.emit(WAIT_MINUTES))
	row.add_child(_wait_button)
	_outcome = Label.new()
	_outcome.name = "Outcome"
	_outcome.theme_type_variation = &"HeaderLabel"
	_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome.custom_minimum_size = Vector2(600, 0)
	_outcome.visible = false
	_rod_box.add_child(_outcome)
	var hold_title := Label.new()
	hold_title.text = "Cool box"
	hold_title.theme_type_variation = &"MutedLabel"
	_rod_box.add_child(hold_title)
	_hold_box = VBoxContainer.new()
	_hold_box.name = "Hold"
	_rod_box.add_child(_hold_box)
	_build_fight()
	_button("CloseButton", "Close", close)
	GameSession.fishing_changed.connect(refresh)
	GameSession.fish_bite.connect(func(_bite: Dictionary) -> void: _start_fight_if_bite())
	refresh()
	_start_fight_if_bite()


func _build_fight() -> void:
	_fight_box = VBoxContainer.new()
	_fight_box.name = "Fight"
	_fight_box.add_theme_constant_override(&"separation", 10)
	_fight_box.visible = false
	_box.add_child(_fight_box)
	_fight_label = Label.new()
	_fight_label.name = "FightLabel"
	_fight_label.theme_type_variation = &"HeaderLabel"
	_fight_box.add_child(_fight_label)
	for pair in [["Line tension", "Tension"], ["Fish coming in", "Progress"]]:
		var label := Label.new()
		label.text = pair[0]
		label.theme_type_variation = &"MutedLabel"
		_fight_box.add_child(label)
		var bar := ProgressBar.new()
		bar.name = pair[1]
		bar.max_value = 1.0
		bar.step = 0.001
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(600, 26)
		_fight_box.add_child(bar)
		if pair[1] == "Tension":
			_tension = bar
		else:
			_progress = bar
	var hint := Label.new()
	hint.text = "Hold E (or the button) to reel in. Let go to ease the line when it turns red."
	hint.theme_type_variation = &"MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fight_box.add_child(hint)
	_reel_button = Button.new()
	_reel_button.name = "ReelButton"
	_reel_button.text = "Reel in (hold)"
	_reel_button.custom_minimum_size = Vector2(240, 44)
	_reel_button.button_down.connect(func() -> void: _reel_held = true)
	_reel_button.button_up.connect(func() -> void: _reel_held = false)
	_fight_box.add_child(_reel_button)


func refresh() -> void:
	if not is_inside_tree():
		return
	var fishing := GameSession.get_fishing()
	var catalog := FishingCatalog.get_default()
	var mode := GameSession.get_fishing_mode()
	var geo := GameSession.get_vessel_position()
	var region := FishingCatalog.region_at(geo).replace("_", " ")
	var how := "Trolling behind the boat at %.1f kn" % GameSession.get_vessel_speed_kn() if mode == FishingState.MODE_TROLLING \
		else ("Fishing from the anchored boat" if GameSession.is_anchored() else "Fishing from the moored boat")
	var fit := catalog.suitability(geo, mode, fishing.lure)
	var fit_text := "promising for this lure" if fit >= 1.0 else ("fair for this lure" if fit >= 0.7 else "not ideal for this lure")
	_info.text = "%s. Waters: %s%s, %s.%s" % [how, region.capitalize(), " (near the coast)" if catalog.is_coastal(geo) else "",
		fit_text, "  Line out." if fishing.line_out else ""]
	_lure.clear()
	for i in catalog.lures.size():
		var lure: Dictionary = catalog.lures[i]
		_lure.add_item("%s (%d)" % [lure.name, fishing.get_lure_count(lure.id)])
		if lure.id == fishing.lure:
			_lure.select(i)
	_lure.disabled = fishing.line_out
	_line_button.text = "Reel in the line" if fishing.line_out else "Let the line out"
	_wait_button.disabled = not fishing.line_out
	for child in _hold_box.get_children():
		child.queue_free()
	if fishing.hold.is_empty():
		var empty := Label.new()
		empty.text = "Empty."
		_hold_box.add_child(empty)
	var selling := GameSession.has_facility(HarbourFacilities.GROCERY)
	for fish in fishing.hold:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var label := Label.new()
		label.text = "%s, %.1f kg" % [catalog.get_species_name(fish.species), float(fish.kg)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var release := Button.new()
		release.text = "Release"
		release.pressed.connect(func() -> void: GameSession.release_fish(int(fish.uid)))
		row.add_child(release)
		if selling:
			var sell := Button.new()
			sell.text = "Sell (%s)" % GameSession.format_money(catalog.price(fish.species, float(fish.kg)))
			sell.pressed.connect(func() -> void:
				var result := GameSession.sell_fish(int(fish.uid))
				notify("Sold for %s." % GameSession.format_money(int(result.price)) if result.error == "" else String(result.error)))
			row.add_child(sell)
		_hold_box.add_child(row)


func focus_default() -> void:
	if _fight_box.visible:
		_reel_button.grab_focus()
	else:
		_line_button.grab_focus()


func _on_lure_selected(index: int) -> void:
	GameSession.select_lure(FishingCatalog.get_default().lures[index].id)


func _on_line() -> void:
	var out := not GameSession.is_line_out()
	var error := GameSession.set_line(out, GameSession.get_fishing().lure)
	if error != "":
		notify(error)
	else:
		SessionLog.write("fishing_line", {"out": out, "mode": String(GameSession.get_fishing_mode()), "lure": GameSession.get_fishing().lure})
		AudioManager.play_sfx(FishingSounds.cast() if out else FishingSounds.reel(), FishingSounds.DB)


# --- The fight ----------------------------------------------------------------------

func _start_fight_if_bite() -> void:
	var bite := GameSession.get_pending_bite()
	if bite.is_empty() or _fight != null:
		return
	var catalog := FishingCatalog.get_default()
	var wind := Simulation.get_weather_at_vessel().speed_kn
	_fight = FishFight.new(catalog.strength(bite.species, float(bite.kg)), wind, GameSession.get_vessel_speed_kn(), float(bite.time) * 0.01)
	_rod_box.visible = false
	_fight_box.visible = true
	_fight_label.text = "Fish on!"
	_reel_button.grab_focus()
	SessionLog.write("fishing_fight", {"species": bite.species, "kg": bite.kg})


func is_fighting() -> bool:
	return _fight != null and not _fight.is_over()


func get_fight() -> FishFight:
	return _fight


func _process(delta: float) -> void:
	if _fight == null or _fight.is_over():
		return
	var reeling := _reel_held or Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"ui_accept")
	step_fight(delta, reeling)


## Advances the fight (every frame; tests call it directly).
func step_fight(delta: float, reeling: bool) -> void:
	if _fight == null or _fight.is_over():
		return
	_fight.step(delta, reeling)
	_tension.value = _fight.tension
	_progress.value = _fight.progress
	var fill := StyleBoxFlat.new()
	fill.bg_color = TENSION_WARN if _fight.is_warning() else TENSION_OK
	fill.set_corner_radius_all(6)
	_tension.add_theme_stylebox_override(&"fill", fill)
	_fight_label.text = "Ease off! The line is close to breaking." if _fight.is_warning() else "Fish on! Reel it in."
	if _fight.is_over():
		_finish_fight()


func _finish_fight() -> void:
	var landed := _fight.result == FishFight.RESULT_LANDED
	var result := GameSession.finish_fight(landed, _fight.result == FishFight.RESULT_BROKE)
	_last_result = result
	SessionLog.write("fishing_result", {"result": String(_fight.result), "species": result.fish.get("species", ""),
		"kg": result.fish.get("kg", 0.0), "kept": result.kept})
	AudioManager.play_sfx(FishingSounds.splash() if landed else FishingSounds.snap(), FishingSounds.DB)
	_fight_box.visible = false
	_rod_box.visible = true
	_outcome.visible = true
	var lines := [String(result.text)]
	if result.new_species:
		lines.append("A new species for your log!")
	elif result.personal_best:
		lines.append("A new personal best!")
	if result.exceptional:
		lines.append("An exceptional fish.")
	if landed and result.kept:
		lines.append("It is in the cool box: cook it in the galley, release it, or sell it in harbour.")
	_outcome.text = "\n".join(lines)
	refresh()
	_line_button.grab_focus()


## After waiting at the rod (App): nothing yet, or why the wait ended (a bite
## starts the fight by itself).
func show_wait_result(result: Simulation.AdvanceResult) -> void:
	if result.bite or not is_inside_tree():
		return
	var waited := Simulation.format_duration(result.elapsed_seconds)
	match result.stopped_by:
		Simulation.STOP_WARNING:
			notify("After %s a weather warning came in. Check the conditions." % waited)
		Simulation.STOP_ANCHOR:
			notify("After %s the anchor alarm went: %s." % [waited, AnchorSite.holding_text(GameSession.get_anchor().holding).to_lower()])
		Simulation.STOP_ARRIVAL:
			notify("After %s the boat arrived." % waited)
		_:
			notify("After %s at the rod: nothing yet." % waited)
	refresh()


func get_last_result() -> Dictionary:
	return _last_result


func get_outcome_text() -> String:
	return _outcome.text if _outcome.visible else ""


func get_info_text() -> String:
	return _info.text
