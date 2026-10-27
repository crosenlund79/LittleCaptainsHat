class_name AnchoragePrompt
extends SimplePanel
## Arriving at an anchorage waypoint (Iteration 18): "We've arrived at our
## anchorage. Ready to drop anchor?" The boat has stopped and waits. The
## captain can go to the windlass and anchor the usual way (with its usual
## checks: the anchor is never set by itself), wait a little (the boat stays,
## and the choice stays on the action wheel), or sail on along the course.
## Shown once, when the boat arrives; never again on loading a game.

signal anchor_requested
signal sail_on_requested

var _site: Label


func _ready() -> void:
	_build("Our anchorage", 600.0)
	_label("Question", "We've arrived at our anchorage. Ready to drop anchor?", &"HeaderLabel")
	_site = _label("Site", describe_site(), &"MutedLabel")
	_button("AnchorButton", "Drop anchor", func() -> void:
		close()
		anchor_requested.emit())
	_button("WaitButton", "Not yet", close)
	_button("SailOnButton", "Sail on", func() -> void:
		close()
		sail_on_requested.emit())


## The anchorage now, in words (the existing anchoring rule).
static func describe_site() -> String:
	var site := GameSession.evaluate_anchorage()
	var text := String(site.get("reason", ""))
	return Loc.t("%s\nThe boat waits here; the action wheel (Q) has the anchor and \"Sail on\" whenever you are ready.") % text


func focus_default() -> void:
	var button := find_child("AnchorButton", true, false) as Button
	if button:
		button.grab_focus()
