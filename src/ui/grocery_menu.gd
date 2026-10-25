class_name GroceryMenu
extends SimplePanel
## The harbour grocery store: fill food and water up to 14 days each, paying
## GameSession.PROVISIONS_PRICE_PER_DAY per missing day (food and water
## counted together). One purchase fills both; it is refused when the money
## is not enough. Every harbour has one (the pontoon's grocery station, or the
## provisions panel and the boatyard).
##
## Its counter also sells a replacement captain's hat (Visual Identity V01),
## in its own row with its own price, so the provisions figures above are
## exactly as before.

var _stores: Label
var _price: Label
var _note: Label
var _buy: Button
var _hat_info: Label
var _buy_hat: Button


func _ready() -> void:
	var place := GameSession.get_location()
	_build("Grocery store" + (" · %s" % place.display_name if place else ""))
	_label("Info", "Fresh food and water, filled up to %d days each. %s per missing day of food or of water." % [
		roundi(Provisions.CAPACITY_DAYS), GameSession.format_money(GameSession.PROVISIONS_PRICE_PER_DAY)], &"MutedLabel")
	_stores = _label("Stores", "")
	_price = _label("Price", "", &"HeaderLabel")
	_note = _label("Note", "")
	_box.add_child(HSeparator.new())
	var hat_row := HBoxContainer.new()
	hat_row.name = "HatRow"
	hat_row.add_theme_constant_override("separation", 14)
	_box.add_child(hat_row)
	_hat_info = Label.new()
	_hat_info.name = "HatInfo"
	_hat_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hat_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hat_info.custom_minimum_size = Vector2(300, 0)
	hat_row.add_child(_hat_info)
	_buy_hat = Button.new()
	_buy_hat.name = "BuyHatButton"
	_buy_hat.custom_minimum_size = Vector2(240, 0)
	_buy_hat.pressed.connect(_on_buy_hat)
	hat_row.add_child(_buy_hat)
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
	_refresh_hat(harbour, funds)


func _refresh_hat(harbour: bool, funds: int) -> void:
	var price := GameSession.get_hat_price()
	var owned := GameSession.get_hat().is_owned()
	_buy_hat.text = "Buy captain's hat (%s)" % GameSession.format_money(price)
	_buy_hat.disabled = not harbour or owned or price > funds
	if owned:
		_hat_info.text = "Captain's hats: you already have yours."
	elif price > funds:
		_hat_info.text = "Captain's hats, %s. Not enough money right now." % GameSession.format_money(price)
	else:
		_hat_info.text = "A replacement captain's hat, %s. Hold onto this one." % GameSession.format_money(price)


func get_buy_button() -> Button:
	return _buy


func get_buy_hat_button() -> Button:
	return _buy_hat


func _on_buy_hat() -> void:
	var price := GameSession.get_hat_price()
	var error := GameSession.buy_hat()
	notify(error if not error.is_empty() else "Bought a new captain's hat for %s. Press H to put it on." % GameSession.format_money(price))
	refresh()


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
