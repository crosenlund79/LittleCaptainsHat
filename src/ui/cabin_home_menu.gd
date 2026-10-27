class_name CabinHomeMenu
extends TradePanel
## "Make it home" (I020): which of the Captain's cabin things are shown
## aboard this boat. Opened in the cabin (action wheel); the panel stands to
## the side without dimming, so the cabin itself is the preview: a thing
## appears or is put away at once, in the place found for it (CabinDecor),
## never over a station, the galley, the chart table, a berth or the
## companion's spots. Every boat keeps its own choice; things not yet bought
## say where to find them (the chandlery).


func _ready() -> void:
	_build_trade("Make it home", Loc.t("The small things that make the %s yours. Each appears in the cabin at once; put it away any time.") %
		GameSession.get_vessel_definition().display_name, 620.0)
	# A preview, not a pause: the cabin stays in view beside the panel.
	var dim := get_node_or_null(^"Dim") as Control
	if dim:
		dim.visible = false
	for child in get_children():
		if child is CenterContainer:
			(child as Control).set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
			(child as Control).offset_left = -700.0
	for item: Dictionary in HarbourTrades.get_decor():
		_row(String(item.id), Loc.t(String(item.name)), Loc.t(String(item.text)), _toggle.bind(String(item.id)))
	refresh()


func refresh() -> void:
	super.refresh()
	if _rows.is_empty():
		return
	var shown := GameSession.get_cabin_decor()
	for item: Dictionary in HarbourTrades.get_decor():
		var id := String(item.id)
		var button := _rows[id] as Button
		if not GameSession.get_home().owns_decor(id):
			button.text = Loc.t("At the chandlery (%s)") % GameSession.format_money(int(item.price))
			button.disabled = true
		else:
			button.text = "Put away" if id in shown else "Show it"
			button.disabled = false


func _toggle(id: String) -> void:
	var shown := not id in GameSession.get_cabin_decor()
	var error := GameSession.set_cabin_decor(id, shown)
	if error != "":
		notify(error)
	SessionLog.write("decor_shown", {"item": id, "shown": shown, "vessel": String(GameSession.get_vessel_id())})
	refresh()
