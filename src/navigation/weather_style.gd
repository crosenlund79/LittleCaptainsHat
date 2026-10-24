class_name WeatherStyle
extends RefCounted
## How weather events look on the chart: colour, outline style, glyph and
## label per kind. Presentation only: what is drawn is always the event's real
## outline from WeatherModel (WeatherEvent.outline), never an approximation.
## Used by the map overlay (MapView) and the legend in the Weather tab, so both
## stay the same. To restyle, change the table below (see DEV_GUIDES/WEATHER.md).
##
## Kinds are told apart by more than colour: outline style (solid, dashed,
## dotted), a glyph (wind lines, cloud, lightning bolt, spiral) and a label.

const STYLES := {
	WeatherEvent.KIND_GALE: {"color": Color("#E0A84E"), "fill": 0.14, "outline": "solid", "core": true, "label": "STRONG WINDS"},
	WeatherEvent.KIND_THUNDER_RISK: {"color": Color("#B9A7D8"), "fill": 0.06, "outline": "dashed", "core": false, "label": "THUNDERSTORM RISK"},
	WeatherEvent.KIND_THUNDERSTORM: {"color": Color("#D46A9A"), "fill": 0.26, "outline": "solid", "core": true, "label": "THUNDERSTORM"},
	WeatherEvent.KIND_CYCLONE: {"color": Color("#E06A4E"), "fill": 0.2, "outline": "solid", "core": true, "label": "CYCLONE"},
}
## Seasonal cyclone-risk areas (not events): dotted outline, no glyph fill.
const CYCLONE_RISK := {"color": Color("#E06A4E"), "label": "CYCLONE SEASON RISK"}
const SHADOW := Color(0.04, 0.12, 0.16, 0.7)


static func style(kind: StringName) -> Dictionary:
	return STYLES.get(kind, STYLES[WeatherEvent.KIND_GALE])


## The label for an event at `time` ("GALE", "SEVERE SQUALLS", "HURRICANE ALBA").
static func label(event: WeatherEvent, time: float) -> String:
	match event.kind:
		WeatherEvent.KIND_GALE:
			return event.display_name.to_upper()
		WeatherEvent.KIND_THUNDERSTORM:
			return "SEVERE SQUALLS" if event.peak_kn + event.gust_kn >= WeatherModel.SEVERE_STORM_KN else "THUNDERSTORM"
		WeatherEvent.KIND_CYCLONE:
			return ("%s %s" % [event.cyclone_category(time).get_slice(" (", 0), event.display_name]).to_upper()
	return style(event.kind).label


## Draws a closed outline in the kind's style. `width` in canvas units.
static func draw_outline(canvas: CanvasItem, points: PackedVector2Array, kind_style: String, color: Color, width: float) -> void:
	if points.size() < 3:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	match kind_style:
		"dashed":
			for i in range(1, closed.size()):
				canvas.draw_dashed_line(closed[i - 1], closed[i], color, width, width * 4.0, true, true)
		"dotted":
			for i in range(1, closed.size()):
				canvas.draw_dashed_line(closed[i - 1], closed[i], color, width, width * 1.5, true, true)
		_:
			canvas.draw_polyline(closed, color, width, true)


## The kind's glyph centred at `at`, `size` across (canvas units).
static func draw_glyph(canvas: CanvasItem, kind: StringName, at: Vector2, size: float, color: Color) -> void:
	var u := size / 2.0
	var w := maxf(size * 0.09, 1.0)
	match kind:
		WeatherEvent.KIND_GALE:  # three wind lines with hooked ends
			for i in 3:
				var y := (i - 1) * u * 0.55
				var length := u * (1.0 - absf(i - 1) * 0.25)
				canvas.draw_line(at + Vector2(-length, y), at + Vector2(length * 0.6, y), color, w, true)
				canvas.draw_arc(at + Vector2(length * 0.6, y - u * 0.2), u * 0.2, PI * 0.5, -PI * 0.75, 8, color, w, true)
		WeatherEvent.KIND_THUNDER_RISK:  # cloud outline
			canvas.draw_arc(at + Vector2(-u * 0.35, u * 0.1), u * 0.4, PI * 0.5, PI * 1.6, 12, color, w, true)
			canvas.draw_arc(at + Vector2(u * 0.1, -u * 0.15), u * 0.5, PI * 1.05, PI * 2.0, 14, color, w, true)
			canvas.draw_arc(at + Vector2(u * 0.55, u * 0.15), u * 0.35, PI * 1.5, PI * 2.5, 12, color, w, true)
			canvas.draw_line(at + Vector2(-u * 0.35, u * 0.5), at + Vector2(u * 0.55, u * 0.5), color, w, true)
		WeatherEvent.KIND_THUNDERSTORM:  # lightning bolt
			var bolt := PackedVector2Array([at + Vector2(u * 0.2, -u), at + Vector2(-u * 0.45, u * 0.1), at + Vector2(u * 0.05, u * 0.1),
				at + Vector2(-u * 0.25, u), at + Vector2(u * 0.5, -u * 0.2), at + Vector2(0, -u * 0.2), at + Vector2(u * 0.2, -u)])
			canvas.draw_colored_polygon(bolt, color)
		WeatherEvent.KIND_CYCLONE:  # spiral with two arms
			for arm in 2:
				var points := PackedVector2Array()
				for i in 16:
					var t := i / 15.0
					var angle := arm * PI + t * PI * 1.4
					points.append(at + Vector2(cos(angle), sin(angle)) * u * (0.2 + 0.8 * t))
				canvas.draw_polyline(points, color, w, true)
			canvas.draw_circle(at, u * 0.18, color)
