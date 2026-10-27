class_name SailmakerMenu
extends TradePanel
## The sailmaker (I020). Two things, kept apart and plainly labelled:
##   - care: the boat-care rigging and sail service (the same service as the
##     boatyard's, the same wear, price and time; no second model);
##   - looks: new sailcloth for this boat (classic cream, tanbark, harbour
##     blue). Purely a look: the sails draw exactly as before. Each boat keeps
##     its own; a cloth already cut for this boat is bent on again for free.

signal time_requested(minutes: float)


func _ready() -> void:
	_build_trade("Sailmaker", Loc.t("The sail loft smells of canvas and beeswax. Care for the %s's sails, or a new look.") %
		GameSession.get_vessel_definition().display_name)
	_heading("CareHeading", "Care (the boat sails better)")
	_row("service", Loc.t(BoatCare.SERVICE_NAMES[BoatCare.SERVICE_RIG]),
		"Sails restitched, sheets and halyards renewed, the rig checked: worn sails and rigging cost speed.", _service)
	_heading("LookHeading", "Sailcloth (a look only: no change in speed)")
	for cloth: Dictionary in HarbourTrades.get_sail_cloths():
		_row("cloth_%s" % cloth.id, Loc.t(String(cloth.name)), Loc.t(String(cloth.text)), _order.bind(String(cloth.id)))
	refresh()


func refresh() -> void:
	super.refresh()
	if _rows.is_empty():
		return
	var open := GameSession.has_facility(HarbourFacilities.SAILMAKER)
	var funds := GameSession.get_funds()
	var service := _rows["service"] as Button
	var refusal := GameSession.service_refusal(BoatCare.SERVICE_RIG)
	var quote := GameSession.service_quote(BoatCare.SERVICE_RIG)
	service.text = Loc.t("Service (%s)") % GameSession.format_money(int(quote.cost))
	service.disabled = not open or refusal != ""
	service.tooltip_text = refusal
	var current := GameSession.get_sail_cloth()
	for cloth: Dictionary in HarbourTrades.get_sail_cloths():
		var button := _rows["cloth_%s" % cloth.id] as Button
		var price := GameSession.sail_cloth_price(String(cloth.id))
		if String(cloth.id) == current:
			button.text = "On the boat"
			button.disabled = true
		else:
			button.text = Loc.t("Bend on again (free)") if price == 0 else Loc.t("Order (%s)") % GameSession.format_money(price)
			button.disabled = not open or price > funds


func _service() -> void:
	var result := GameSession.perform_service(BoatCare.SERVICE_RIG)
	if result.error != "":
		notify(result.error)
		return
	time_requested.emit(float(result.minutes))
	SessionLog.write("boat_service", {"service": String(BoatCare.SERVICE_RIG), "cost": result.cost, "minutes": result.minutes,
		"port": String(GameSession.get_location_id()), "shop": "sailmaker"})
	notify(Loc.t("%s done: %s, %s.") % [Loc.t(BoatCare.SERVICE_NAMES[BoatCare.SERVICE_RIG]), GameSession.format_money(int(result.cost)),
		Simulation.format_duration(float(result.minutes) * 60.0)])
	refresh()


func _order(cloth: String) -> void:
	var price := GameSession.sail_cloth_price(cloth)
	var error := GameSession.order_sail_cloth(cloth)
	if error != "":
		notify(error)
		return
	SessionLog.write("sail_cloth", {"cloth": cloth, "cost": price, "vessel": String(GameSession.get_vessel_id())})
	notify(Loc.t("The %s now carries %s sails.") % [GameSession.get_vessel_definition().display_name,
		Loc.t(String(HarbourTrades.get_sail_cloth(cloth).name)).to_lower()])
	refresh()
