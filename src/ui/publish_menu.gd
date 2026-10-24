class_name PublishMenu
extends SimplePanel
## Publish a travel update (social media): shows the unpublished renown, the
## rate, the earnings and the funds before and after, and asks for
## confirmation. The transaction itself is GameSession.publish_travel_update();
## this dialog only reports the confirmation.

signal publish_confirmed

var _publish: Button


func _ready() -> void:
	var quote := GameSession.get_publish_quote()
	_build("Publish travel update")
	_label("Info", "Share your recent passages online. Unpublished renown becomes income at %s per renown point. Your lifetime renown stays as it is." %
		GameSession.format_money(int(quote.rate)), &"MutedLabel")
	_label("Renown", "Unpublished renown: %d   ·   lifetime renown: %d" % [quote.renown, GameSession.get_lifetime_renown()])
	_label("Earnings", "%d renown × %s = %s" % [quote.renown, GameSession.format_money(int(quote.rate)), GameSession.format_money(int(quote.euros))],
		&"HeaderLabel")
	_label("Funds", "Funds %s → %s" % [GameSession.format_money(int(quote.funds)), GameSession.format_money(int(quote.funds_after))])
	if not String(quote.error).is_empty():
		_label("Note", quote.error, &"MutedLabel")
	_button("CancelButton", "Cancel", close)
	_publish = _button("PublishButton", "Publish for %s" % GameSession.format_money(int(quote.euros)), publish_confirmed.emit, 220.0)
	_publish.disabled = not String(quote.error).is_empty()


func get_publish_button() -> Button:
	return _publish


func focus_default() -> void:
	if _publish.disabled:
		(_buttons.get_node("CancelButton") as Button).grab_focus()
	else:
		_publish.grab_focus()
