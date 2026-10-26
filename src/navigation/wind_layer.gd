class_name WindLayer
extends Node2D
## The chart's wind overlay: arrows showing where the wind blows TO, coloured
## by speed, over a faint speed tint of the sea. Both read the one central
## weather query (WeatherModel: the sustained effective wind, storms included)
## for the time shown, so the chart always agrees with the simulation, HUD and
## sails.
##
## Performance: arrows sit on an absolute lattice in map space whose spacing
## is a power-of-two step chosen for ~ARROW_SPACING_PX on screen. Panning
## therefore reuses the same lattice points (cached samples) and only newly
## visible points are sampled; the density stays constant at any zoom. Wind
## time is refreshed every REFRESH_GAME_SECONDS of game time, not every frame.
##
## The tint is drawn by a separate node placed between the water and the
## land fill (see `tint`), so it only shows on water. It is a small image with
## one pixel per lattice point, drawn with linear filtering, so speeds blend
## smoothly instead of showing blocks. Arrows are skipped on land using the
## navigation raster.

const ARROW_SPACING_PX := 72.0
const BASE_SPACING := 8.0  # map units; lattice spacings are BASE_SPACING * 2^n
const REFRESH_GAME_SECONDS := 600.0
const CALM_KN := 1.0
## Speed bands (upper bound in knots, colour), also used by the legend.
const BANDS: Array = [
	[5.0, Color("#8FA9B3")],
	[10.0, Color("#6FB3B8")],
	[15.0, Color("#7FB89A")],
	[20.0, Color("#C9C277")],
	[25.0, Color("#E0A84E")],
	[INF, Color("#E06A4E")],
]
const TINT_ALPHA := 0.2
const ARROW_OUTLINE := Color(0.03, 0.09, 0.12, 0.85)

## Drawn under the land fill (set up by MapView).
var tint := Node2D.new()
## Geographic bounds of the chart (only sea inside it is drawn).
var map_bounds := Rect2()
var map_view: MapView

var _time := -INF
## The tint picture and the lattice area it covers (reused while panning).
## Kept alive here: the renderer uses it after _draw returns.
var _tint_texture: ImageTexture
var _tint_key := ""
var _tint_from := Vector2i.ZERO
var _tint_to := Vector2i.ZERO
var _tint_spacing := 1.0
var _cache := {}
var _grid: NavGrid


func _ready() -> void:
	tint.name = "WindTint"
	tint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tint.draw.connect(_draw_tint)
	var router := SeaRouter.get_default()
	_grid = router.grid if router else null


## Band colour for a wind speed.
static func color_for(speed_kn: float) -> Color:
	for band: Array in BANDS:
		if speed_kn < band[0]:
			return band[1]
	return BANDS[BANDS.size() - 1][1]


## Redraws for the current view (call when the camera moves or zooms).
func refresh_view() -> void:
	if visible:
		queue_redraw()
		tint.queue_redraw()


## Re-samples when the game time has moved on enough (throttled).
func update_time(game_time: float, force := false) -> void:
	if force or absf(game_time - _time) >= REFRESH_GAME_SECONDS:
		_time = game_time
		_cache.clear()
		_tint_key = ""
		refresh_view()


func set_shown(shown: bool) -> void:
	visible = shown
	tint.visible = shown
	refresh_view()


## Wind at a map lattice point and whether it is at sea: [Sample, bool]
## (cached for the current wind time).
func _point(key: Vector3i, map_point: Vector2) -> Array:
	var entry: Array = _cache.get(key, [])
	if entry.is_empty():
		if _cache.size() > 20000:
			_cache.clear()
		var geo := GeoMath.normalize(map_view.projection.map_to_geo(map_point))
		var sea := _grid == null or _grid.cell_class_at_geo(geo) != NavGrid.LAND
		entry = [WeatherModel.get_default().sample(geo, _time, GameSession.get_wind_seed()), sea]
		_cache[key] = entry
	return entry


## Lattice spacing (map units) and the visible lattice index range, grown by
## `margin` lattice steps on every side.
func _lattice(divisions: int, margin := 0) -> Dictionary:
	var s := 1.0 / map_view.camera.zoom.x
	var level := roundi(log(ARROW_SPACING_PX * s / BASE_SPACING) / log(2.0))
	var spacing := BASE_SPACING * pow(2.0, level) / divisions
	var view := get_viewport_rect().size
	var top_left := map_view.screen_to_map(Vector2.ZERO)
	var bottom_right := map_view.screen_to_map(view)
	var area := Rect2(top_left, bottom_right - top_left).grow(margin * spacing).intersection(map_bounds)
	return {
		"spacing": spacing, "level": level * 4 + divisions, "s": s,
		"from": Vector2i((area.position / spacing).floor()), "to": Vector2i((area.end / spacing).ceil()),
	}


## All arrows are batched into four draw calls (shaft outlines, shafts, head
## outlines, heads), which keeps redraws cheap while panning.
func _draw() -> void:
	if map_view == null:
		return
	var lattice := _lattice(1)
	var spacing: float = lattice.spacing
	var s: float = lattice.s
	var length := ARROW_SPACING_PX * 0.56 * s
	var width := 2.6 * s
	var head := 8.0 * s + width * 1.5
	var shafts := PackedVector2Array()
	var shaft_colors := PackedColorArray()
	var heads := PackedVector2Array()
	var head_colors := PackedColorArray()
	var inner := PackedVector2Array()
	var inner_colors := PackedColorArray()
	for iy in range(lattice.from.y, lattice.to.y):
		for ix in range(lattice.from.x, lattice.to.x):
			var at := Vector2((ix + 0.5) * spacing, (iy + 0.5) * spacing)
			if not map_bounds.has_point(at):
				continue
			var entry := _point(Vector3i(ix, iy, lattice.level), at)
			if not entry[1]:
				continue  # on land
			var wind: WindField.Sample = entry[0]
			var color := color_for(wind.speed_kn)
			if wind.speed_kn < CALM_KN:
				draw_arc(at, 4.0 * s, 0.0, TAU, 16, color, 1.5 * s)
				continue
			# Mercator is conformal: a compass direction is the same angle on the chart.
			var to := deg_to_rad(wind.to_deg())
			var direction := Vector2(sin(to), -cos(to))
			var side := Vector2(-direction.y, direction.x)
			var tip := at + direction * length * 0.5
			var head_base := tip - direction * head
			shafts.append(at - direction * length * 0.5)
			shafts.append(head_base)
			shaft_colors.append(color)
			heads.append_array([tip + direction * 1.5 * s, head_base + side * (head * 0.55 + 1.5 * s) - direction * s,
				head_base - side * (head * 0.55 + 1.5 * s) - direction * s])
			inner.append_array([tip, head_base + side * head * 0.55, head_base - side * head * 0.55])
			for i in 3:
				head_colors.append(ARROW_OUTLINE)
				inner_colors.append(color)
	if shafts.is_empty():
		return
	var outline_colors := PackedColorArray()
	outline_colors.resize(shaft_colors.size())
	outline_colors.fill(ARROW_OUTLINE)
	draw_multiline_colors(shafts, outline_colors, width + 2.5 * s)
	_draw_triangles(heads, head_colors)
	draw_multiline_colors(shafts, shaft_colors, width)
	_draw_triangles(inner, inner_colors)


func _draw_triangles(points: PackedVector2Array, colors: PackedColorArray) -> void:
	var indices := PackedInt32Array()
	indices.resize(points.size())
	for i in points.size():
		indices[i] = i
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)


## The tint image is built for the visible area plus a margin and reused
## until the view leaves that area (or zoom level or wind time change).
func _draw_tint() -> void:
	if map_view == null:
		return
	var visible_lattice := _lattice(2)
	var key := "%d|%s" % [visible_lattice.level, _time]
	var covered: bool = key == _tint_key and _tint_from.x <= visible_lattice.from.x and _tint_from.y <= visible_lattice.from.y \
		and _tint_to.x >= visible_lattice.to.x and _tint_to.y >= visible_lattice.to.y
	if not covered:
		_build_tint(_lattice(2, 12), key)
	if _tint_texture == null:
		return
	var rect := Rect2(Vector2(_tint_from) * _tint_spacing, Vector2(_tint_to - _tint_from) * _tint_spacing)
	var clipped := rect.intersection(map_bounds)
	var source := Rect2((clipped.position - rect.position) / _tint_spacing, clipped.size / _tint_spacing)
	tint.draw_texture_rect_region(_tint_texture, clipped, source)


func _build_tint(lattice: Dictionary, key: String) -> void:
	var spacing: float = lattice.spacing
	var from: Vector2i = lattice.from
	var size: Vector2i = lattice.to - from
	_tint_key = key
	_tint_from = from
	_tint_to = lattice.to
	_tint_spacing = spacing
	if size.x <= 0 or size.y <= 0:
		_tint_texture = null
		return
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var ix := from.x + x
			var iy := from.y + y
			var at := Vector2((ix + 0.5) * spacing, (iy + 0.5) * spacing)
			var wind: WindField.Sample = _point(Vector3i(ix, iy, lattice.level), at)[0]
			var color := color_for(wind.speed_kn)
			color.a = TINT_ALPHA
			image.set_pixel(x, y, color)
	# Pixel centres sit on the lattice points (linear filtering blends them).
	_tint_texture = ImageTexture.create_from_image(image)
