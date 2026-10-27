class_name FishmongerMenu
extends TradePanel
## The fishmonger (I020): the one place a catch is sold. Each fish in the
## cool box with its price (the fishing catalogue's own, by weight), sold
## one by one or all at once; paid at once, exactly once. Trophies and the
## species records stay in the Captain's Log: they are the catch's history.


func _ready() -> void:
	var who := HarbourTrades.fishmonger_name(GameSession.get_location_id())
	_build_trade("Fishmonger", Loc.t("%s at the fish counter weighs each fish and pays on the spot. Your trophies and records stay in the Captain's Log.") % who)
	GameSession.fishing_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var catalog := FishingCatalog.get_default()
	var hold := GameSession.get_fishing().hold
	if hold.is_empty():
		var empty := Label.new()
		empty.name = "Empty"
		empty.text = "The cool box is empty. Come back with a catch!"
		empty.theme_type_variation = &"MutedLabel"
		_list.add_child(empty)
	for fish: Dictionary in hold:
		var uid := int(fish.uid)
		var price := catalog.price(fish.species, float(fish.kg))
		var button := _row(str(uid), Loc.format("%s, %.1f kg", [catalog.get_species_name(fish.species), float(fish.kg)]),
			catalog.rarity_name(fish.species), _sell.bind(uid))
		button.text = Loc.t("Sell (%s)") % GameSession.format_money(price)
	var total := 0
	for fish: Dictionary in hold:
		total += catalog.price(fish.species, float(fish.kg))
	var all := find_child("SellAllButton", true, false) as Button
	if all == null:
		all = _button("SellAllButton", "", _sell_all)
		_buttons.move_child(all, 0)
	all.text = Loc.t("Sell all (%s)") % GameSession.format_money(total)
	all.disabled = hold.is_empty() or not GameSession.has_facility(HarbourFacilities.FISHMONGER)
	refresh()


func refresh() -> void:
	super.refresh()
	var open := GameSession.has_facility(HarbourFacilities.FISHMONGER)
	for id: String in _rows:
		(_rows[id] as Button).disabled = not open


func _sell(uid: int) -> void:
	var result := GameSession.sell_fish(uid)
	if result.error != "":
		notify(result.error)
		return
	SessionLog.write("fishing_sold", {"count": 1, "price": result.price, "port": String(GameSession.get_location_id())})
	notify(Loc.t("Sold for %s.") % GameSession.format_money(int(result.price)))


func _sell_all() -> void:
	var result := GameSession.sell_catch()
	if result.error != "":
		notify(result.error)
		return
	SessionLog.write("fishing_sold", {"count": result.count, "price": result.total, "port": String(GameSession.get_location_id())})
	notify(Loc.t("Sold %d fish for %s.") % [int(result.count), GameSession.format_money(int(result.total))])
