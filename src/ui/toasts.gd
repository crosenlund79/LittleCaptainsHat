class_name Toasts
extends VBoxContainer
## Short, non-blocking notifications that fade out on their own. Works while
## the game is paused, so menus can report results (e.g. "Game saved").

const MAX_VISIBLE := 3
const DEFAULT_DURATION := 3.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_message(text: String, duration := DEFAULT_DURATION) -> void:
	while get_child_count() >= MAX_VISIBLE:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 420
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	add_child(panel)
	var tween := panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


func get_messages() -> PackedStringArray:
	var result := PackedStringArray()
	for panel in get_children():
		if not panel.is_queued_for_deletion():
			result.append((panel.get_child(0) as Label).text)
	return result
