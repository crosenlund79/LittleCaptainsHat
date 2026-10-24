class_name GroceryMenu
extends SimplePanel
## The harbour grocery store: fill food and water up to 14 days each, paying
## GameSession.PROVISIONS_PRICE_PER_DAY per missing day (food and water
## counted together). One purchase fills both; it is refused when the money
## is not enough. Every harbour has one (the pontoon's grocery station, or the
## provisions panel and the boatyard).

var _stores: Label
var _price: Label
var _note: Label
var _buy: Button


func _ready() -> void:
	var place := GameSession.get_location()
	_build("Grocery store" + (" · %s" % place.display_name if place else ""))
	_label("Info", "Fresh food and water, filled up to %d days each. %s per missing day of food or of water." % [
		roundi(Provisions.CAPACITY_DAYS), GameSession.format_money(GameSession.PROVISIONS_PRICE_PER_DAY)], &"MutedLabel")
	_stores = _label("Stores", "")
	_price = _label("Price", "", &"HeaderLabel")
	_note = _label("Note", "")
	_button("CloseButton", "Close", close)
	_buy = _button("BuyButton", "Buy", _on_buy, 240.0)
	refresh()


func refresh() -> void:
	var provisions := GameSession.get_provisions()
	var price := GameSession.get_provisions_price()
	var funds := GameSession.get_funds()
	_stores.text = "Aboard: food %s, water %s. Missing: %.1f days in all." % [Provisions.format_days(provisions.food_days),
		Provisions.format_days(provisions.water_days), GameSession.get_missing_provision_days()]
	_price.text = "Price %s  ·  Funds %s" % [GameSession.format_money(price), GameSession.format_money(funds)]
	if price > 0 and price <= funds:
		_price.text += " → %s" % GameSession.format_money(funds - price)
	_buy.text = "Buy for %s" % GameSession.format_money(price)
	var harbour := GameSession.is_moored_in_harbour()
	_buy.disabled = not harbour or provisions.is_full() or price > funds
	if not harbour:
		_note.text = "The grocery store is in harbour; you are at sea."
	elif provisions.is_full():
		_note.text = "Food and water are already full."
	elif price > funds:
		_note.text = "Not enough money: you need %s. Remote work at the boat's work station earns %s an hour." % [
			GameSession.format_money(price), GameSession.format_money(GameSession.REMOTE_WORK_PAY_PER_HOUR)]
	else:
		_note.text = "Food and water will be full (%d days each)." % roundi(Provisions.CAPACITY_DAYS)


func get_buy_button() -> Button:
	return _buy


func _on_buy() -> void:
	var price := GameSession.get_provisions_price()
	var error := GameSession.buy_provisions()
	notify(error if not error.is_empty() else "Bought food and water for %s. Stores full: %s each." % [
		GameSession.format_money(price), Provisions.format_days(Provisions.CAPACITY_DAYS)])
	refresh()


func focus_default() -> void:
	if _buy.disabled:
		(find_child("CloseButton", true, false) as Button).grab_focus()
	else:
		_buy.grab_focus()
