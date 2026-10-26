class_name DevGuidesMenu
extends ModalPanel
## Developer resources: the guides in DEV_GUIDES/, listed by title and shown
## as readable text (MarkdownLite). Development builds only (see DevGuides);
## not a gameplay feature.

@onready var _list: VBoxContainer = %GuideList
@onready var _title: Label = %GuideTitle
@onready var _content: RichTextLabel = %Content

var guides: Array[Dictionary] = []
var current_path := ""


func _ready() -> void:
	%CloseButton.pressed.connect(close)
	_disable_ligatures()
	guides = DevGuides.list_guides()
	var group := ButtonGroup.new()
	for guide in guides:
		var button := Button.new()
		button.name = String(guide.file).get_basename()
		button.text = guide.title
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = &"TocButton"  # a contents list, not a wall of buttons
		button.custom_minimum_size = Vector2(300, 40)
		button.pressed.connect(show_guide.bind(guide.path))
		_list.add_child(button)
	# A change of mood re-renders the open guide in the new colours, at the
	# same place in the text.
	UiTheme.palette_changed.connect(_on_palette_changed)
	if guides.is_empty():
		_title.text = "No developer guides"
		_content.text = "The guides are read from %s, which is not available in this build. Open the project in Godot (or run it with godot --path .) to read them." % DevGuides.guides_dir
	else:
		show_guide(guides[0].path)


## Shows the guide at `path` (a message if it cannot be read).
func show_guide(path: String) -> void:
	current_path = path
	for i in guides.size():
		(_list.get_child(i) as Button).set_pressed_no_signal(guides[i].path == path)
	var text := DevGuides.read(path)
	if text.is_empty():
		_title.text = path.get_file()
		_content.text = "This guide could not be read: %s" % path
		return
	_title.text = DevGuides.title_of(text, path.get_file())
	_shown_path = path
	_content.text = MarkdownLite.to_bbcode(text)
	_content.scroll_to_line(0)


## Guides quote commands such as `--headless`; Barlow's ligatures would show
## "--" as a dash, so the viewer's fonts turn them off.
var _shown_path := ""


func _on_palette_changed() -> void:
	if _shown_path == "":
		return
	var bar := _content.get_v_scroll_bar()
	var at := bar.value
	_content.text = MarkdownLite.to_bbcode(DevGuides.read(_shown_path))
	bar.value = at


func _disable_ligatures() -> void:
	var server := TextServerManager.get_primary_interface()
	var features := {}
	for tag in ["liga", "calt", "dlig"]:
		features[server.name_to_tag(tag)] = 0
	for font_name in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font", &"mono_font"]:
		var variation := FontVariation.new()
		variation.base_font = _content.get_theme_font(font_name)
		variation.opentype_features = features
		_content.add_theme_font_override(font_name, variation)


func focus_default() -> void:
	%CloseButton.grab_focus()
