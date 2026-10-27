class_name VhfDialog
extends SimplePanel
## A call on the VHF radio (I019, The Captain's Watch): what is heard, what
## answering asks of the captain, and Answer or Decline. Declining is always
## fine: another vessel answers. Answering an assist call stands the boat by
## for a couple of hours; the thanks are paid once per call.

signal answered(result: Dictionary)

var call := {}


func _ready() -> void:
	_build(Loc.t("VHF radio, channel 16"), 640.0)
	_label("Heard", VhfRadio.describe(call), &"")
	_label("Commitment", VhfRadio.describe_commitment(call), &"MutedLabel")
	var assist: bool = call.get("kind", &"") == VhfRadio.KIND_ASSIST
	_button("AnswerButton", Loc.t("Answer and stand by") if assist else Loc.t("Share the forecast"), _answer.bind(true))
	_button("DeclineButton", Loc.t("Let another vessel answer"), _answer.bind(false))


func _answer(accept: bool) -> void:
	var result := GameSession.answer_vhf(call, accept)
	close()
	answered.emit(result)


func focus_default() -> void:
	var button := find_child("AnswerButton", true, false) as Button
	if button:
		button.grab_focus()
