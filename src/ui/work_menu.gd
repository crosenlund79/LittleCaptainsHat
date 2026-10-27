class_name WorkMenu
extends SimplePanel
## Remote work at the cabin's work station: choose 1-8 hours (arrows or
## Left/Right), see the pay and when you finish, and work. Only in harbour.
## The work itself is Simulation.work(); this dialog only reports the choice.

signal work_requested(hours: int)
## Publishing a travel update is offered here too (the same connection).
signal publish_requested

const DEFAULT_HOURS := 4

var hours := DEFAULT_HOURS

var _duration: Label
var _detail: Label
var _decrease: Button
var _increase: Button
var _work: Button


func _ready() -> void:
	_build("Remote work")
	_label("Info", Loc.t("Work online from the boat while moored: %s per completed hour. Time passes while you work, and food and water are used as usual.") %
		GameSession.format_money(GameSession.REMOTE_WORK_PAY_PER_HOUR), &"MutedLabel")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_decrease = Button.new()
	_decrease.name = "DecreaseButton"
	_decrease.text = "<"
	_decrease.custom_minimum_size = Vector2(56, 0)
	_decrease.pressed.connect(change_hours.bind(-1))
	_duration = Label.new()
	_duration.name = "DurationLabel"
	_duration.theme_type_variation = &"HeaderLabel"
	_duration.custom_minimum_size = Vector2(160, 0)
	_duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_increase = Button.new()
	_increase.name = "IncreaseButton"
	_increase.text = ">"
	_increase.custom_minimum_size = Vector2(56, 0)
	_increase.pressed.connect(change_hours.bind(1))
	row.add_child(_decrease)
	row.add_child(_duration)
	row.add_child(_increase)
	_box.add_child(row)
	_detail = _label("Detail", "")
	_button("CancelButton", "Cancel", close)
	var publish := _button("PublishButton", "Publish travel update…", publish_requested.emit, 200.0)
	publish.disabled = GameSession.get_unpublished_renown() <= 0
	publish.tooltip_text = Loc.t("%d unpublished renown") % GameSession.get_unpublished_renown()
	_work = _button("WorkButton", "Work", func() -> void: work_requested.emit(hours), 200.0)
	_update()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_left"):
		change_hours(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_right"):
		change_hours(1)
		get_viewport().set_input_as_handled()


func change_hours(delta: int) -> void:
	hours = clampi(hours + delta, GameSession.REMOTE_WORK_MIN_HOURS, GameSession.REMOTE_WORK_MAX_HOURS)
	_update()


func _update() -> void:
	var pay := hours * GameSession.REMOTE_WORK_PAY_PER_HOUR
	_duration.text = Loc.n("%d hour", "%d hours", hours) % hours
	_decrease.disabled = hours <= GameSession.REMOTE_WORK_MIN_HOURS
	_increase.disabled = hours >= GameSession.REMOTE_WORK_MAX_HOURS
	_work.text = Loc.t("Work %d h for %s") % [hours, GameSession.format_money(pay)]
	_detail.text = Loc.t("You finish at about %s.\nFunds now %s, afterwards %s.\nFood and water used: %s each.") % [
		Simulation.format_game_time(GameSession.get_game_time() + hours * 3600.0),
		GameSession.format_money(GameSession.get_funds()), GameSession.format_money(GameSession.get_funds() + pay),
		Provisions.format_days(hours / 24.0)]


func focus_default() -> void:
	_work.grab_focus()
