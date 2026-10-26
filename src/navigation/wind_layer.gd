class_name WindLayer
extends Node2D
## The chart's wind overlay: arrows showing where the wind blows TO, coloured
## by speed, over a faint speed tint of the sea. Both read the one central
## weather query (WeatherModel.sample_wind: the sustained effective wind,
## storms included, exactly as the simulation sees it) for the snapshot time
## shown, so the chart agrees with the simulation, HUD and sails.
##
## Iteration 17: a cached snapshot, not a live field.
## - Time: the overlay shows one snapshot time, on a SNAPSHOT_STEP grid:
##   Now (the current half hour) or up to MAX_OFFSET_STEPS steps before or
##   after it (the read-only wind time navigator). Forecast snapshots only
##   include weather already formed at the current time, like every other
##   forecast in the game. A new Now snapshot is taken when the clock crosses
##   a step, at most once per NOW_MIN_REAL_SECONDS of real time (fast clocks
##   and Long Passage never queue up intermediate snapshots).
## - Space: arrows sit on an absolute lattice in map space (half-octave
##   spacing steps near the zoom band's spacing on screen), grouped in CHUNK x CHUNK
##   chunks. Each chunk is sampled once per snapshot and kept (bounded by
##   MAX_SNAPSHOTS and MAX_CHUNKS), so panning back and forth and stepping
##   between snapshot times reuse samples.
## - Work: missing chunks are sampled in _process within FRAME_BUDGET_USEC per
##   frame, nearest the screen centre first. Until a new snapshot time is
##   complete for the view, the previous one stays on screen (no hitches, no
##   half-updated field). Nothing runs while the overlay is hidden or the
##   chart is closed: the sailing weather never depends on this node.
## - Land: whether a lattice point is sea, land or deep inland never changes,
##   so it is cached once per chunk for all times (static, shared).
## - Zoom: below HIDE_PX_PER_DEG (with hysteresis up to SHOW_PX_PER_DEG) no
##   wind is drawn and `detail_hidden` tells the chart to say "Zoom in to see
##   wind details."; the arrow spacing on screen widens at continental scale
##   and tightens at coastal scale (ZOOM_BANDS). Thresholds: see
##   ITERATION_17_REPORT.md (measured).
##
## The tint is drawn by a separate node placed between the water and the land
## fill (see `tint`), so it only shows on water. It is a small image with one
## pixel per lattice point, drawn with linear filtering.

signal snapshot_changed
signal detail_changed(hidden: bool)

const SNAPSHOT_STEP := 1800.0
const MAX_OFFSET_STEPS := 4
const NOW_MIN_REAL_SECONDS := 1.0
const CHUNK := 8
const FRAME_BUDGET_USEC := 3000
const MAX_SNAPSHOTS := 10
const MAX_CHUNKS := 600
const MAX_LAND_CHUNKS := 8000
const BASE_SPACING := 8.0  # map units; lattice spacings are BASE_SPACING * 2^(n/2)
## Most lattice points in view (a very large window gets a coarser lattice).
const MAX_VIEW_POINTS := 1500
## Wind detail by zoom (screen pixels per degree of longitude):
## [from px/deg, arrow spacing on screen in px].
const ZOOM_BANDS: Array = [[0.0, 110.0], [40.0, 72.0], [200.0, 56.0]]
const HIDE_PX_PER_DEG := 9.0
const SHOW_PX_PER_DEG := 11.0
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
const SEA := 0
const COAST := 1  # land next to the sea: sampled for the tint, no arrow
const INLAND := 2
const OUTSIDE := 3

## Land class per lattice chunk, Vector3i(level, cx, cy) -> PackedByteArray.
static var _land := {}

## Drawn under the land fill (set up by MapView).
var tint := Node2D.new()
## Map-space bounds of the chart (only sea inside it is drawn).
var map_bounds := Rect2()
var map_view: MapView
## True while zoomed out beyond useful wind detail (nothing drawn).
var detail_hidden := false
## Chunks sampled so far (profiling and tests).
var chunks_sampled := 0

## The authoritative clock as last given (update_time) and the step offset
## the player selected (0 = Now).
var _now := -INF
var _offset := 0
## The Now step currently in use and when (real msec) it was taken.
var _now_step := -INF
var _now_taken_msec := -1000000
## Snapshot being sampled, and the one on screen: Vector2i(time step, known step or -1).
var _target := Vector2i(-2147483648, -1)
var _shown := Vector2i(-2147483648, -1)
## Vector2i snapshot key -> {Vector3i(level, cx, cy): PackedFloat32Array([from, speed] per point)}
var _snapshots := {}
var _snapshot_order: Array[Vector2i] = []
var _tint_texture: ImageTexture
var _tint_rect := Rect2()
var _tint_key := ""
var _grid: NavGrid


func _ready() -> void:
	tint.name = "WindTint"
	tint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tint.draw.connect(_draw_tint)
	var router := SeaRouter.get_default()
	_grid = router.grid if router else null
	set_process(visible)


## Band colour for a wind speed.
static func color_for(speed_kn: float) -> Color:
	for band: Array in BANDS:
		if speed_kn < band[0]:
			return band[1]
	return BANDS[BANDS.size() - 1][1]


## Forgets the cached land classes (tests that swap the navigation grid).
static func clear_land_cache() -> void:
	_land.clear()


## Redraws for the current view (call when the camera moves or zooms).
func refresh_view() -> void:
	if visible:
		_update_detail()
		queue_redraw()
		tint.queue_redraw()


## The authoritative clock moved to `game_time`. Takes a new Now snapshot
## when it crosses a step (throttled in real time). With `force`, the view is
## sampled completely right away (tests and the benchmark).
func update_time(game_time: float, force := false) -> void:
	_now = game_time
	var step := floorf(game_time / SNAPSHOT_STEP)
	if step != _now_step and (force or _now_step == -INF
			or Time.get_ticks_msec() - _now_taken_msec >= NOW_MIN_REAL_SECONDS * 1000.0):
		_now_step = step
		_now_taken_msec = Time.get_ticks_msec()
		_retarget()
	if force:
		_fill(INF)


## Shows the snapshot for `game_time` as Now, sampled completely at once.
func force_snapshot(game_time: float) -> void:
	_now_step = -INF
	update_time(game_time, true)


func set_shown(shown: bool) -> void:
	visible = shown
	tint.visible = shown
	set_process(shown)
	refresh_view()


## Snapshot offset in SNAPSHOT_STEP steps from Now (-MAX_OFFSET_STEPS..MAX_OFFSET_STEPS).
func set_offset_steps(steps: int) -> void:
	steps = clampi(steps, -MAX_OFFSET_STEPS, MAX_OFFSET_STEPS)
	if steps != _offset:
		_offset = steps
		_retarget()


func get_offset_steps() -> int:
	return _offset


## The game time of the selected snapshot.
func get_snapshot_time() -> float:
	return (_now_step + _offset) * SNAPSHOT_STEP if _now_step != -INF else _now


## "NOW", "PAST MODEL SNAPSHOT" or "FORECAST".
func snapshot_label() -> String:
	if _offset == 0:
		return "NOW"
	return "FORECAST" if _offset > 0 else "PAST MODEL SNAPSHOT"


## True when the selected snapshot is fully sampled and shown for the view.
func is_complete() -> bool:
	return _shown == _target and _missing_chunks().is_empty()


func _retarget() -> void:
	var known := int(_now_step) if _offset > 0 else -1
	var target := Vector2i(int(_now_step) + _offset, known)
	if target == _target:
		return
	_target = target
	if not _snapshots.has(target):
		_snapshots[target] = {}
	_snapshot_order.erase(target)
	_snapshot_order.append(target)
	# Oldest first, never the one on screen.
	var i := 0
	while _snapshot_order.size() > MAX_SNAPSHOTS and i < _snapshot_order.size():
		var old: Vector2i = _snapshot_order[i]
		if old == _shown or old == _target:
			i += 1
			continue
		_snapshot_order.remove_at(i)
		_snapshots.erase(old)
	if _shown.x == -2147483648 or _snapshots[target].size() > 0 and _missing_chunks().is_empty():
		_show_target()
	snapshot_changed.emit()


func _show_target() -> void:
	_shown = _target
	_tint_key = ""
	queue_redraw()
	tint.queue_redraw()


func _process(_delta: float) -> void:
	if map_view == null or detail_hidden:
		return
	_fill(FRAME_BUDGET_USEC)


## Samples missing chunks of the target snapshot for the view, within
## `budget_usec`, and switches to it once the view is complete.
func _fill(budget_usec: float) -> void:
	if map_view == null or _target.x == -2147483648:
		return
	_update_detail()
	if detail_hidden:
		return
	var missing := _missing_chunks()
	if missing.is_empty():
		if _shown != _target:
			_show_target()
		return
	var start := Time.get_ticks_usec()
	var lattice := _lattice()
	var chunks: Dictionary = _snapshots[_target]
	var sampled := false
	for key: Vector3i in missing:
		if chunks.size() >= MAX_CHUNKS:
			chunks.clear()  # bounded; the view's chunks come back next frames
		chunks[key] = _sample_chunk(key, lattice.spacing)
		sampled = true
		if Time.get_ticks_usec() - start >= budget_usec:
			break
	if _missing_chunks().is_empty():
		_show_target()
	elif sampled and _shown == _target:
		queue_redraw()  # newly panned-in area of the snapshot on screen
		_tint_key = ""
		tint.queue_redraw()


## The visible chunks (plus one ring) the target snapshot lacks, nearest the
## centre of the screen first.
func _missing_chunks() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if map_view == null or detail_hidden or not _snapshots.has(_target):
		return result
	var lattice := _lattice()
	var chunks: Dictionary = _snapshots[_target]
	var from: Vector2i = lattice.chunk_from - Vector2i.ONE
	var to: Vector2i = lattice.chunk_to + Vector2i.ONE
	for cy in range(from.y, to.y):
		for cx in range(from.x, to.x):
			var key := Vector3i(lattice.level, cx, cy)
			if not chunks.has(key):
				result.append(key)
	var centre: Vector2 = (Vector2(from + to) - Vector2.ONE) / 2.0
	result.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector2(a.y, a.z).distance_squared_to(centre) < Vector2(b.y, b.z).distance_squared_to(centre))
	return result


## Wind for every sea (and coastal land) point of one chunk at the target
## snapshot: [from_deg, speed_kn] per point, NAN where nothing is drawn.
func _sample_chunk(key: Vector3i, spacing: float) -> PackedFloat32Array:
	var classes := _land_of(key, spacing)
	var data := PackedFloat32Array()
	data.resize(CHUNK * CHUNK * 2)
	data.fill(NAN)
	var model := WeatherModel.get_default()
	var seed := GameSession.get_wind_seed()
	var time := _target.x * SNAPSHOT_STEP
	var known := _target.y * SNAPSHOT_STEP if _target.y >= 0 else INF
	for j in CHUNK:
		for i in CHUNK:
			var index := j * CHUNK + i
			if classes[index] >= INLAND:
				continue
			var at := _point_at(key.y * CHUNK + i, key.z * CHUNK + j, spacing)
			var wind := model.sample_wind(map_view.projection.map_to_geo(at), time, seed, known)
			data[index * 2] = wind.x
			data[index * 2 + 1] = wind.y
	chunks_sampled += 1
	return data


## Sea / coast / inland / outside for each point of a chunk (cached for all times).
func _land_of(key: Vector3i, spacing: float) -> PackedByteArray:
	var cached: PackedByteArray = _land.get(key, PackedByteArray())
	if not cached.is_empty():
		return cached
	if _land.size() >= MAX_LAND_CHUNKS:
		_land.clear()
	# Class of a ring one point wider than the chunk, to find coastal land.
	var side := CHUNK + 2
	var land := PackedByteArray()
	land.resize(side * side)
	for j in side:
		for i in side:
			var at := _point_at(key.y * CHUNK + i - 1, key.z * CHUNK + j - 1, spacing)
			var geo := GeoMath.normalize(map_view.projection.map_to_geo(at))
			land[j * side + i] = 1 if _grid and _grid.cell_class_at_geo(geo) == NavGrid.LAND else 0
	var classes := PackedByteArray()
	classes.resize(CHUNK * CHUNK)
	for j in CHUNK:
		for i in CHUNK:
			var at := _point_at(key.y * CHUNK + i, key.z * CHUNK + j, spacing)
			var value := SEA
			if not map_bounds.has_point(at):
				value = OUTSIDE
			elif land[(j + 1) * side + i + 1]:
				value = INLAND
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if not land[(j + 1 + dy) * side + i + 1 + dx]:
							value = COAST
			classes[j * CHUNK + i] = value
	_land[key] = classes
	return classes


static func _point_at(ix: int, iy: int, spacing: float) -> Vector2:
	return Vector2((ix + 0.5) * spacing, (iy + 0.5) * spacing)


## Screen pixels per degree of longitude at the current zoom.
func _px_per_degree() -> float:
	return map_view.camera.zoom.x * map_view.units_per_degree


func _update_detail() -> void:
	if map_view == null:
		return
	var px := _px_per_degree()
	var hidden := px < (SHOW_PX_PER_DEG if detail_hidden else HIDE_PX_PER_DEG)
	if hidden != detail_hidden:
		detail_hidden = hidden
		_tint_key = ""
		detail_changed.emit(hidden)


## Arrow spacing on screen (px) for the current zoom band.
func _spacing_px() -> float:
	var px := _px_per_degree()
	var spacing: float = ZOOM_BANDS[0][1]
	for band: Array in ZOOM_BANDS:
		if px >= band[0]:
			spacing = band[1]
	return spacing


## Lattice spacing (map units), level and the visible lattice/chunk ranges.
func _lattice() -> Dictionary:
	var s := 1.0 / map_view.camera.zoom.x
	var view := get_viewport_rect().size
	# Half-octave steps keep the spacing on screen within ~19 % of the band's.
	var level := roundi(2.0 * log(_spacing_px() * s / BASE_SPACING) / log(2.0))
	while view.x * view.y / pow(BASE_SPACING * pow(2.0, level / 2.0) / s, 2.0) > MAX_VIEW_POINTS:
		level += 1
	var spacing := BASE_SPACING * pow(2.0, level / 2.0)
	var top_left := map_view.screen_to_map(Vector2.ZERO)
	var bottom_right := map_view.screen_to_map(view)
	var area := Rect2(top_left, bottom_right - top_left).intersection(map_bounds)
	var from := Vector2i((area.position / spacing).floor())
	var to := Vector2i((area.end / spacing).ceil())
	return {
		"spacing": spacing, "level": level, "s": s, "from": from, "to": to,
		"chunk_from": Vector2i(floori(from.x / float(CHUNK)), floori(from.y / float(CHUNK))),
		"chunk_to": Vector2i(floori((to.x - 1) / float(CHUNK)) + 1, floori((to.y - 1) / float(CHUNK)) + 1),
	}


## Data of a chunk for drawing: the shown snapshot's, else the target's
## (an area newly panned into while a snapshot change is pending).
func _chunk_data(key: Vector3i) -> PackedFloat32Array:
	var shown: Dictionary = _snapshots.get(_shown, {})
	if shown.has(key):
		return shown[key]
	var target: Dictionary = _snapshots.get(_target, {})
	return target.get(key, PackedFloat32Array())


## All arrows are batched into four draw calls (shaft outlines, shafts, head
## outlines, heads), which keeps redraws cheap while panning.
func _draw() -> void:
	if map_view == null or detail_hidden:
		return
	var lattice := _lattice()
	var spacing: float = lattice.spacing
	var s: float = lattice.s
	var length := _spacing_px() * 0.56 * s
	var width := 2.6 * s
	var head := 8.0 * s + width * 1.5
	var shafts := PackedVector2Array()
	var shaft_colors := PackedColorArray()
	var heads := PackedVector2Array()
	var head_colors := PackedColorArray()
	var inner := PackedVector2Array()
	var inner_colors := PackedColorArray()
	var from: Vector2i = lattice.from
	var to: Vector2i = lattice.to
	for cy in range(lattice.chunk_from.y, lattice.chunk_to.y):
		for cx in range(lattice.chunk_from.x, lattice.chunk_to.x):
			var key := Vector3i(lattice.level, cx, cy)
			var data := _chunk_data(key)
			if data.is_empty():
				continue
			var classes: PackedByteArray = _land.get(key, PackedByteArray())
			for j in CHUNK:
				var iy := cy * CHUNK + j
				if iy < from.y or iy >= to.y:
					continue
				for i in CHUNK:
					var ix := cx * CHUNK + i
					var index := j * CHUNK + i
					if ix < from.x or ix >= to.x or classes.is_empty() or classes[index] != SEA:
						continue
					var at := _point_at(ix, iy, spacing)
					var speed := data[index * 2 + 1]
					var color := color_for(speed)
					if speed < CALM_KN:
						draw_arc(at, 4.0 * s, 0.0, TAU, 16, color, 1.5 * s)
						continue
					# Mercator is conformal: a compass direction is the same angle on the chart.
					var bearing := deg_to_rad(data[index * 2] + 180.0)
					var direction := Vector2(sin(bearing), -cos(bearing))
					var side := Vector2(-direction.y, direction.x)
					var tip := at + direction * length * 0.5
					var head_base := tip - direction * head
					shafts.append(at - direction * length * 0.5)
					shafts.append(head_base)
					shaft_colors.append(color)
					heads.append_array([tip + direction * 1.5 * s, head_base + side * (head * 0.55 + 1.5 * s) - direction * s,
						head_base - side * (head * 0.55 + 1.5 * s) - direction * s])
					inner.append_array([tip, head_base + side * head * 0.55, head_base - side * head * 0.55])
					for k in 3:
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


## The tint image covers the visible chunks plus one ring, one pixel per
## lattice point; it is rebuilt only when the snapshot, zoom level, chunk
## range or available chunks change.
func _draw_tint() -> void:
	if map_view == null or detail_hidden:
		return
	var lattice := _lattice()
	var from: Vector2i = lattice.chunk_from - Vector2i.ONE
	var to: Vector2i = lattice.chunk_to + Vector2i.ONE
	var key := "%s|%s|%d|%s|%s" % [_shown, _target, lattice.level, from, to]
	if key != _tint_key:
		_tint_key = key
		_build_tint(from, to, lattice)
	if _tint_texture == null:
		return
	var clipped := _tint_rect.intersection(map_bounds)
	var source := Rect2((clipped.position - _tint_rect.position) / lattice.spacing, clipped.size / lattice.spacing)
	tint.draw_texture_rect_region(_tint_texture, clipped, source)


func _build_tint(from: Vector2i, to: Vector2i, lattice: Dictionary) -> void:
	var spacing: float = lattice.spacing
	var size := (to - from) * CHUNK
	if size.x <= 0 or size.y <= 0:
		_tint_texture = null
		return
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)  # transparent
	for cy in range(from.y, to.y):
		for cx in range(from.x, to.x):
			var data := _chunk_data(Vector3i(lattice.level, cx, cy))
			if data.is_empty():
				continue
			for j in CHUNK:
				for i in CHUNK:
					var speed := data[(j * CHUNK + i) * 2 + 1]
					if is_nan(speed):
						continue
					var color := color_for(speed)
					color.a = TINT_ALPHA
					image.set_pixel((cx - from.x) * CHUNK + i, (cy - from.y) * CHUNK + j, color)
	# Pixel centres sit on the lattice points (linear filtering blends them).
	_tint_rect = Rect2(Vector2(from * CHUNK) * spacing, Vector2(size) * spacing)
	_tint_texture = ImageTexture.create_from_image(image)
