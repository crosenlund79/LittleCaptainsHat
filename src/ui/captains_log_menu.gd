class_name CaptainsLogMenu
extends SimplePanel
## The Captain's Log (L, or the pause menu): the player's statistics and
## renown, recent passages, the harbours visited and the sailing objectives.
## It only reads GameSession; nothing here changes the game. The panel has a
## fixed size; long lists scroll.

const PANEL_SIZE := Vector2(1080, 0)
const TABS_SIZE := Vector2(1020, 560)
const TAB_LOG := 0
const TAB_HARBOURS := 1
const TAB_OBJECTIVES := 2

## The player asked to publish a travel update (Log tab).
signal publish_requested

var _tabs: TabContainer


func _ready() -> void:
	_build("Captain's Log", PANEL_SIZE.x)
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.custom_minimum_size = TABS_SIZE
	_box.add_child(_tabs)
	_tabs.add_child(_build_log_tab())
	_tabs.add_child(_build_harbours_tab())
	_tabs.add_child(_build_objectives_tab())
	_button("CloseButton", "Close", close)


func show_tab(index: int) -> void:
	_tabs.current_tab = clampi(index, 0, _tabs.get_tab_count() - 1)


func get_current_tab_name() -> String:
	return _tabs.get_current_tab_control().name


func focus_default() -> void:
	_tabs.get_tab_bar().grab_focus()


# --- Log tab ---------------------------------------------------------------------

func _build_log_tab() -> Control:
	var list := _tab_page("Log")
	var log := GameSession.get_captains_log()
	var grid := GridContainer.new()
	grid.name = "Statistics"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	var longest := log.longest
	var longest_text := "—"
	if not longest.is_empty():
		longest_text = "%s nm  (%s)" % [_nm(longest.nm), _passage_name(longest)]
	var catalog := PortCatalog.get_default()
	var stats := [
		["Distance sailed", "%s nm" % _nm(GameSession.get_total_nm_sailed()), "DistanceValue"],
		["Voyages completed", str(log.voyages_completed), "VoyagesValue"],
		["Harbours visited", "%d of %d" % [log.get_distinct_harbours(), catalog.ports.size()], "HarboursValue"],
		["Harbour arrivals", str(log.arrivals), "ArrivalsValue"],
		["Longest passage", longest_text, "LongestValue"],
		["Rescues", str(GameSession.get_rescue_count()), "RescuesValue"],
		["Renown", "%d  (%d unpublished)" % [GameSession.get_lifetime_renown(), GameSession.get_unpublished_renown()], "RenownValue"],
	]
	for stat: Array in stats:
		var name_label := Label.new()
		name_label.text = stat[0]
		name_label.theme_type_variation = &"MutedLabel"
		grid.add_child(name_label)
		var value := Label.new()
		value.name = stat[2]
		value.text = stat[1]
		value.custom_minimum_size = Vector2(320, 0)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(value)
	var renown_row := HBoxContainer.new()
	renown_row.add_theme_constant_override("separation", 16)
	list.add_child(renown_row)
	var quote := GameSession.get_publish_quote()
	var publish := Button.new()
	publish.name = "PublishButton"
	publish.text = "Publish travel update (%s)…" % GameSession.format_money(int(quote.euros)) if int(quote.euros) > 0 else "Publish travel update…"
	publish.disabled = not String(quote.error).is_empty()
	publish.tooltip_text = quote.error
	publish.pressed.connect(publish_requested.emit)
	renown_row.add_child(publish)
	var hint := Label.new()
	hint.name = "PublishHint"
	hint.theme_type_variation = &"MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.text = quote.error if not String(quote.error).is_empty() else \
		"Turns your %d unpublished renown into income (%s per renown)." % [quote.renown, GameSession.format_money(int(quote.rate))]
	renown_row.add_child(hint)
	if GameSession.is_underway():
		_add_text(list, "UnderwayNote", "Under way to %s: %s nm sailed on this voyage so far." % [
			catalog.get_display_name(GameSession.get_voyage_destination_id()), _nm(GameSession.get_voyage_sailed_nm())], &"MutedLabel")
	_add_text(list, "RecentTitle", "Recent passages", &"HeaderLabel")
	var passages := VBoxContainer.new()
	passages.name = "Passages"
	passages.add_theme_constant_override("separation", 6)
	list.add_child(passages)
	if log.voyages.is_empty():
		_add_text(passages, "NoPassages", "No passages yet. Plot a course at the chart table and set sail.", &"MutedLabel")
	for i in range(log.voyages.size() - 1, -1, -1):
		_add_text(passages, "Passage%d" % (log.voyages.size() - 1 - i), describe_passage(log.voyages[i]))
	return list.get_parent()


## One line of the passage list.
static func describe_passage(record: Dictionary) -> String:
	var vessel := VesselCatalog.get_default().get_vessel(StringName(record.vessel))
	var vessel_name: String = vessel.display_name if vessel else String(record.vessel)
	var outcome := "arrived" if record.outcome == String(CaptainsLog.OUTCOME_ARRIVED) else "lost at sea, crew rescued"
	return "%s  ·  %s  ·  %s nm  ·  %s  ·  %s, %s" % [_passage_name(record), Simulation.format_duration(float(record.ended) - float(record.departed)),
		_nm(record.nm), vessel_name, outcome, Simulation.format_game_time(record.ended, false)]


static func _passage_name(record: Dictionary) -> String:
	var catalog := PortCatalog.get_default()
	var from := "at sea" if String(record.from).is_empty() else catalog.get_display_name(StringName(record.from))
	return "%s → %s" % [from, catalog.get_display_name(StringName(record.to))]


static func _nm(value: Variant) -> String:
	return "%.1f" % float(value)


# --- Harbours tab -----------------------------------------------------------------

func _build_harbours_tab() -> Control:
	var list := _tab_page("Harbours")
	var log := GameSession.get_captains_log()
	var catalog := PortCatalog.get_default()
	_add_text(list, "HarbourSummary", "You have visited %d of the %d harbours on the chart. A harbour counts once you arrive and moor there." % [
		log.get_distinct_harbours(), catalog.ports.size()], &"MutedLabel")
	_add_text(list, "VisitedTitle", "Visited", &"HeaderLabel")
	var visited := VBoxContainer.new()
	visited.name = "Visited"
	list.add_child(visited)
	for id in log.get_visited_ids():
		var entry: Dictionary = log.visited[String(id)]
		var port := catalog.get_port(id)
		var place := "%s, %s" % [port.display_name, port.country] if port else String(id)
		var first: float = entry.first
		var when := "before the log was kept" if first < 0.0 else "first %s" % Simulation.format_game_time(first, false)
		var arrivals := int(entry.arrivals)
		var visits := "start harbour" if arrivals == 0 and first >= 0.0 else "%d arrival%s" % [arrivals, "" if arrivals == 1 else "s"]
		_add_text(visited, "Harbour_%s" % id, "%s  ·  %s  ·  %s" % [place, when, visits])
	_add_text(list, "UnvisitedTitle", "Not yet visited", &"HeaderLabel")
	var names: Array[String] = []
	for port in catalog.ports:
		if not log.has_visited(port.id):
			names.append(port.display_name)
	names.sort()
	_add_text(list, "Unvisited", ", ".join(names) if not names.is_empty() else "None: you have been everywhere on the chart.", &"MutedLabel")
	return list.get_parent()


# --- Objectives tab -----------------------------------------------------------------

func _build_objectives_tab() -> Control:
	var list := _tab_page("Objectives")
	var catalog := ObjectiveCatalog.get_default()
	var progress := GameSession.get_objective_progress()
	var log := GameSession.get_captains_log()
	_add_text(list, "RenownSummary", "Renown: %d earned in all, %d not yet published. Objectives are tracked automatically and pay renown when a voyage completes them." % [
		progress.lifetime_renown, progress.unpublished_renown], &"MutedLabel")
	_add_text(list, "OpenTitle", "Objectives", &"HeaderLabel")
	var open := VBoxContainer.new()
	open.name = "Open"
	open.add_theme_constant_override("separation", 10)
	list.add_child(open)
	var done := VBoxContainer.new()
	done.name = "Completed"
	done.add_theme_constant_override("separation", 10)
	for objective in catalog.objectives:
		var count := progress.get_count(StringName(objective.id))
		if count == 0 or objective.repeatable:
			_add_objective(open, objective, describe_progress(objective, log, count))
		if count > 0:
			var entry: Dictionary = progress.completed[objective.id]
			var when := Simulation.format_game_time(float(entry.first), false)
			var times := "  ·  %d times" % count if count > 1 else ""
			_add_text(done, "Done_%s" % objective.id, "%s  ·  %d renown  ·  first %s%s" % [objective.title, objective.reward, when, times])
	_add_text(list, "CompletedTitle", "Completed", &"HeaderLabel")
	list.add_child(done)
	if done.get_child_count() == 0:
		_add_text(done, "NoneCompleted", "None yet.", &"MutedLabel")
	return list.get_parent()


func _add_objective(parent: Control, objective: Dictionary, status: String) -> void:
	var box := VBoxContainer.new()
	box.name = "Objective_%s" % objective.id
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var repeat := "  (repeatable)" if objective.repeatable else ""
	_add_text(box, "Title", "%s  ·  %d renown%s" % [objective.title, objective.reward, repeat])
	_add_text(box, "Detail", "%s  %s" % [objective.text, status], &"MutedLabel")


## The progress line for an objective in the list.
static func describe_progress(objective: Dictionary, log: CaptainsLog, count: int) -> String:
	if objective.repeatable and count > 0:
		return "Completed %d time%s so far." % [count, "" if count == 1 else "s"]
	var value := ObjectiveCatalog.get_progress(objective, log, GameSession.get_total_nm_sailed())
	match objective.type:
		ObjectiveCatalog.TYPE_TOTAL_DISTANCE:
			return "Progress: %s of %s nm." % [_nm(minf(value[0], value[1])), _nm(value[1])]
		ObjectiveCatalog.TYPE_VOYAGE_COUNT, ObjectiveCatalog.TYPE_VISIT_COUNT:
			return "Progress: %d of %d." % [mini(int(value[0]), int(value[1])), int(value[1])]
		ObjectiveCatalog.TYPE_PASSAGE_LENGTH:
			return "Longest passage so far: %s nm." % _nm(value[0])
	return "Not yet achieved."


# --- Helpers ----------------------------------------------------------------------

## A scrolling tab page named `title`; returns the list to fill.
func _tab_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	return list


func _add_text(parent: Control, node_name: String, text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(200, 0)
	parent.add_child(label)
	return label
