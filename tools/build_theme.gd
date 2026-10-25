extends SceneTree
## Generates res://assets/ui/next_harbor_theme.tres, the shared UI theme.
##
## The theme is built in code so the palette and spacing live in one readable
## place. Re-run after editing this file:
##   godot --headless --path . -s res://tools/build_theme.gd
## (Run `godot --headless --path . --import` first on a fresh checkout.)

const OUTPUT := "res://assets/ui/next_harbor_theme.tres"

const NAVY := Color("#102D3B")
const NAVY_LIGHT := Color("#18394A")
const NAVY_HOVER := Color("#21495B")
const TEAL := Color("#3F7880")
const SEAFOAM := Color("#A6C4C9")
const CREAM := Color("#EFE5CC")
const BRASS := Color("#C79F6D")

const FONT_REGULAR := "res://assets/fonts/Barlow-Regular.ttf"
const FONT_MEDIUM := "res://assets/fonts/Barlow-Medium.ttf"
const FONT_SEMIBOLD := "res://assets/fonts/Barlow-SemiBold.ttf"
## The display font (Visual Identity V01): hand lettering for the title,
## decorative headings, signs and secret achievement names only. Barlow stays
## the functional font for every number, menu, dialog and description.
const FONT_DISPLAY := "res://assets/fonts/PatrickHand-Regular.ttf"


func _initialize() -> void:
	var theme := Theme.new()
	var regular: Font = load(FONT_REGULAR)
	var medium: Font = load(FONT_MEDIUM)
	var semibold: Font = load(FONT_SEMIBOLD)
	theme.default_font = regular
	theme.default_font_size = 22

	_labels(theme, medium, semibold)
	_display(theme, regular)
	_buttons(theme, medium)
	_panels(theme)
	_ranges(theme)
	_popups(theme)
	_tabs(theme, medium)

	var err := ResourceSaver.save(theme, OUTPUT)
	print("Saved theme: ", OUTPUT, " (", error_string(err), ")")
	quit(0 if err == OK else 1)


func _labels(theme: Theme, medium: Font, semibold: Font) -> void:
	theme.set_color("font_color", "Label", CREAM)
	_variation(theme, "TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", semibold)
	theme.set_font_size("font_size", "TitleLabel", 40)
	theme.set_color("font_color", "TitleLabel", CREAM)
	_variation(theme, "HeaderLabel", "Label")
	theme.set_font("font", "HeaderLabel", semibold)
	theme.set_font_size("font_size", "HeaderLabel", 26)
	theme.set_color("font_color", "HeaderLabel", BRASS)
	_variation(theme, "MutedLabel", "Label")
	theme.set_font_size("font_size", "MutedLabel", 19)
	theme.set_color("font_color", "MutedLabel", SEAFOAM)
	_variation(theme, "KeyLabel", "Label")
	theme.set_font("font", "KeyLabel", medium)
	theme.set_font_size("font_size", "KeyLabel", 18)
	theme.set_color("font_color", "KeyLabel", NAVY)
	theme.set_stylebox("normal", "KeyLabel", _box(BRASS, Color.TRANSPARENT, 0, 4, Vector4(8, 2, 8, 2)))


## Type variations that use the display font. Patrick Hand has no arrows and
## a few other symbols, so Barlow is its fallback for any such character.
func _display(theme: Theme, fallback: Font) -> void:
	var display := FontVariation.new()
	display.base_font = load(FONT_DISPLAY)
	display.fallbacks = [fallback]
	# The game's title on the main menu, under the logo.
	_variation(theme, "DisplayTagline", "Label")
	theme.set_font("font", "DisplayTagline", display)
	theme.set_font_size("font_size", "DisplayTagline", 34)
	theme.set_color("font_color", "DisplayTagline", SEAFOAM)
	# Decorative headings (the Captain's Log title and its section headings).
	_variation(theme, "DisplayHeader", "Label")
	theme.set_font("font", "DisplayHeader", display)
	theme.set_font_size("font_size", "DisplayHeader", 34)
	theme.set_color("font_color", "DisplayHeader", BRASS)
	# A name worth celebrating (a secret achievement that was found).
	_variation(theme, "DisplayName", "Label")
	theme.set_font("font", "DisplayName", display)
	theme.set_font_size("font_size", "DisplayName", 30)
	theme.set_color("font_color", "DisplayName", CREAM)


func _buttons(theme: Theme, medium: Font) -> void:
	var margins := Vector4(20, 10, 20, 10)
	for type: String in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		theme.set_font(&"font", type, medium)
		theme.set_color(&"font_color", type, CREAM)
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, Color.WHITE)
		theme.set_color(&"font_focus_color", type, CREAM)
		theme.set_color(&"font_hover_pressed_color", type, Color.WHITE)
		theme.set_color(&"font_disabled_color", type, Color(SEAFOAM, 0.4))
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _box(NAVY_LIGHT, Color(SEAFOAM, 0.35), 2, 6, margins))
		theme.set_stylebox("hover", type, _box(NAVY_HOVER, SEAFOAM, 2, 6, margins))
		theme.set_stylebox("pressed", type, _box(TEAL, SEAFOAM, 2, 6, margins))
		theme.set_stylebox("hover_pressed", type, _box(TEAL, CREAM, 2, 6, margins))
		theme.set_stylebox("disabled", type, _box(Color(NAVY_LIGHT, 0.5), Color(SEAFOAM, 0.12), 2, 6, margins))
		theme.set_stylebox("focus", type, _box(Color.TRANSPARENT, BRASS, 2, 6, margins, false))
	# Flat toggles (checkboxes) have no box, only the focus ring.
	var flat := StyleBoxEmpty.new()
	flat.set_content_margin_all(6)
	for type: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, flat)
		theme.set_stylebox("focus", type, _box(Color.TRANSPARENT, BRASS, 2, 6, Vector4(6, 6, 6, 6), false))

	# Large menu buttons for the main and pause menus.
	_variation(theme, "BigButton", "Button")
	theme.set_font_size("font_size", "BigButton", 26)
	var menu_margins := Vector4(28, 14, 28, 14)
	theme.set_stylebox("normal", "BigButton", _box(Color(NAVY_LIGHT, 0.85), Color(SEAFOAM, 0.25), 2, 8, menu_margins))
	theme.set_stylebox("hover", "BigButton", _box(NAVY_HOVER, SEAFOAM, 2, 8, menu_margins))
	theme.set_stylebox("pressed", "BigButton", _box(TEAL, CREAM, 2, 8, menu_margins))
	theme.set_stylebox("disabled", "BigButton", _box(Color(NAVY_LIGHT, 0.4), Color(SEAFOAM, 0.1), 2, 8, menu_margins))
	theme.set_stylebox("focus", "BigButton", _box(Color.TRANSPARENT, BRASS, 3, 8, menu_margins, false))

	# Slot entries in the save/load dialog: left aligned, two lines of text.
	_variation(theme, "SlotButton", "Button")
	theme.set_font_size("font_size", "SlotButton", 21)
	theme.set_constant("h_separation", "SlotButton", 16)


func _panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _box(Color(NAVY, 0.97), Color(SEAFOAM, 0.3), 2, 12, Vector4(36, 30, 36, 30)))
	theme.set_stylebox("panel", "Panel", _box(Color(NAVY, 0.97), Color(SEAFOAM, 0.3), 2, 12, Vector4.ZERO))
	_variation(theme, "HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", _box(Color(NAVY, 0.82), Color(SEAFOAM, 0.22), 1, 8, Vector4(16, 10, 16, 10)))
	_variation(theme, "PromptPanel", "PanelContainer")
	theme.set_stylebox("panel", "PromptPanel", _box(Color(NAVY, 0.9), BRASS, 2, 8, Vector4(18, 10, 18, 10)))
	_variation(theme, "ToastPanel", "PanelContainer")
	theme.set_stylebox("panel", "ToastPanel", _box(Color(NAVY_LIGHT, 0.95), Color(SEAFOAM, 0.5), 1, 8, Vector4(22, 12, 22, 12)))
	# The chart's sidebar: the dialog look with tighter margins.
	_variation(theme, "SidebarPanel", "PanelContainer")
	theme.set_stylebox("panel", "SidebarPanel", _box(Color(NAVY, 0.97), Color(SEAFOAM, 0.3), 2, 12, Vector4(26, 22, 26, 22)))
	_variation(theme, "SectionPanel", "PanelContainer")
	theme.set_stylebox("panel", "SectionPanel", _box(Color(NAVY_LIGHT, 0.6), Color.TRANSPARENT, 0, 8, Vector4(20, 14, 20, 14)))
	var separator := StyleBoxLine.new()
	separator.color = Color(SEAFOAM, 0.25)
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_constant("separation", "HSeparator", 12)


func _ranges(theme: Theme) -> void:
	var track := _box(Color(NAVY_LIGHT, 1.0), Color(SEAFOAM, 0.25), 1, 4, Vector4(0, 4, 0, 4))
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(TEAL, Color.TRANSPARENT, 0, 4, Vector4(0, 4, 0, 4)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(SEAFOAM, Color.TRANSPARENT, 0, 4, Vector4(0, 4, 0, 4)))
	theme.set_icon("grabber", "HSlider", _circle_icon(22, CREAM, NAVY))
	theme.set_icon("grabber_highlight", "HSlider", _circle_icon(22, Color.WHITE, BRASS))
	theme.set_icon("grabber_disabled", "HSlider", _circle_icon(22, Color(SEAFOAM, 0.4), NAVY))
	theme.set_stylebox("focus", "HSlider", _box(Color.TRANSPARENT, BRASS, 2, 6, Vector4.ZERO, false))
	theme.set_stylebox("background", "ProgressBar", _box(NAVY_LIGHT, Color(SEAFOAM, 0.25), 1, 4, Vector4.ZERO))
	theme.set_stylebox("fill", "ProgressBar", _box(BRASS, Color.TRANSPARENT, 0, 4, Vector4.ZERO))


func _popups(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", _box(NAVY, SEAFOAM, 1, 6, Vector4(6, 6, 6, 6)))
	theme.set_stylebox("hover", "PopupMenu", _box(TEAL, Color.TRANSPARENT, 0, 4, Vector4(10, 4, 10, 4)))
	theme.set_color("font_color", "PopupMenu", CREAM)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_stylebox("panel", "TooltipPanel", _box(NAVY, SEAFOAM, 1, 4, Vector4(10, 6, 10, 6)))
	theme.set_color("font_color", "TooltipLabel", CREAM)


## Tabs (the chart's sidebar): flat, the selected tab underlined in brass.
func _tabs(theme: Theme, medium: Font) -> void:
	var margins := Vector4(18, 8, 18, 10)
	var selected := _box(NAVY_LIGHT, BRASS, 0, 6, margins)
	selected.border_width_bottom = 3
	selected.corner_radius_bottom_left = 0
	selected.corner_radius_bottom_right = 0
	var unselected := _box(Color(NAVY_LIGHT, 0.35), Color(SEAFOAM, 0.15), 0, 6, margins)
	unselected.border_width_bottom = 1
	unselected.corner_radius_bottom_left = 0
	unselected.corner_radius_bottom_right = 0
	var hovered := _box(NAVY_HOVER, SEAFOAM, 0, 6, margins)
	hovered.border_width_bottom = 1
	hovered.corner_radius_bottom_left = 0
	hovered.corner_radius_bottom_right = 0
	for type: String in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, selected)
		theme.set_stylebox("tab_unselected", type, unselected)
		theme.set_stylebox("tab_hovered", type, hovered)
		theme.set_stylebox("tab_disabled", type, unselected)
		theme.set_stylebox("tab_focus", type, _box(Color.TRANSPARENT, BRASS, 2, 6, margins, false))
		theme.set_font("font", type, medium)
		theme.set_font_size("font_size", type, 21)
		theme.set_color("font_selected_color", type, CREAM)
		theme.set_color("font_unselected_color", type, SEAFOAM)
		theme.set_color("font_hovered_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color(SEAFOAM, 0.4))
	theme.set_stylebox("panel", "TabContainer", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 14, 0, 0)))
	theme.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	theme.set_constant("side_margin", "TabContainer", 0)
	# Slim scroll bars (tab contents scroll; the sidebar itself never does).
	var track := _box(Color(NAVY_LIGHT, 0.6), Color.TRANSPARENT, 0, 4, Vector4(4, 0, 4, 0))
	var grabber := _box(Color(SEAFOAM, 0.45), Color.TRANSPARENT, 0, 4, Vector4(4, 0, 4, 0))
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(SEAFOAM, Color.TRANSPARENT, 0, 4, Vector4(4, 0, 4, 0)))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(CREAM, Color.TRANSPARENT, 0, 4, Vector4(4, 0, 4, 0)))


func _variation(theme: Theme, variation: String, base: String) -> void:
	theme.set_type_variation(variation, base)


func _box(bg: Color, border: Color, border_width: int, radius: int, margins: Vector4, draw_center := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.draw_center = draw_center
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	box.anti_aliasing = true
	return box


func _circle_icon(size: int, fill: Color, rim: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	var radius := size / 2.0 - 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var color := fill if d < radius - 2.5 else rim
			color.a *= clampf(radius - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
