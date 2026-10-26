class_name AnchorageLayer
extends Node2D
## The chart's anchorage overlay (Revision 0.105b): soft translucent water
## where the boat could anchor, like the weather highlights - teal where the
## normal anchor reaches the bottom, amber where only the Magic Anchor will
## (deep water near a coast). Nothing is painted elsewhere; hovering explains.
##
## Exactly the rule of AnchorSite.evaluate / GameSession.anchorage_spot for a
## waypoint (clear water at least MIN_SHORE_NM off, a checked approach from
## the router's water, the depth from DepthService), evaluated at the centre of
## every 1/60 degree (~1 nm) cell - so a waypoint dropped in a teal area is a
## normal anchorage. Shelter depends on the wind on arrival and is shown on
## hover, not painted.
##
## Cost, bounded:
##   - only at close zoom (SHOW_PX_PER_DEG), only while switched on, only the
##     1 degree tiles in view (plus a margin), and only coastal ones (tiles
##     with no land within reach are skipped at once);
##   - each tile is worked out in steps within FRAME_BUDGET_USEC per frame,
##     nearest the screen centre first, on local arrays (land, clear water,
##     reachability by one breadth-first search from the router's water,
##     equivalent to CoastalGeography.approach); the result is a small
##     texture, kept (at most MAX_TILES, oldest dropped);
##   - nothing is recomputed while panning back and forth; the rule does not
##     depend on the time or the weather, so a tile never goes stale.

signal tile_completed(key: Vector2i)

const SHOW_PX_PER_DEG := 700.0
const STEP := 2  # fine cells per overlay cell (1/60 degree)
const FRAME_BUDGET_USEC := 3000
const MAX_TILES := 48
const NORMAL := 1
const MAGIC := 2
const NORMAL_COLOUR := Color(0.3, 0.82, 0.74, 0.42)
const MAGIC_COLOUR := Color(0.98, 0.72, 0.28, 0.42)

var map_view: MapView
var shown := false
## Kept tiles: Vector2i(tile_x, tile_y) -> {"texture", "cells" (PackedByteArray classes)}.
var _tiles := {}
var _order: Array[Vector2i] = []
var _job: TileJob
var _wanted: Array[Vector2i] = []
## Counters (tests, benchmark).
var tiles_computed := 0
var cells_evaluated := 0
var last_tile_usec := 0
## The layer's own work in the busiest frame (usec), and per stage of the
## last tile (land, clear+seeds, reach, classify).
var max_frame_usec := 0
## The layer's own work per busy frame (usec, the last FRAME_SAMPLES).
var frame_usec := PackedInt32Array()
const FRAME_SAMPLES := 4000
var last_stage_usec := PackedInt32Array([0, 0, 0, 0, 0])
var max_step_usec := PackedInt32Array([0, 0, 0, 0, 0])


func set_shown(on: bool) -> void:
	shown = on
	refresh_view()


func is_zoomed_in() -> bool:
	return map_view != null and map_view.get_px_per_degree() >= SHOW_PX_PER_DEG


func is_active() -> bool:
	return shown and is_zoomed_in()


## The view moved: which tiles are wanted now (nearest the centre first).
func refresh_view() -> void:
	visible = is_active()
	_wanted.clear()
	if visible:
		var rect := map_view.get_visible_geo_rect().grow(0.25)
		var centre := rect.get_center()
		for ty in range(floori(rect.position.y), ceili(rect.end.y)):
			for tx in range(floori(rect.position.x), ceili(rect.end.x)):
				var key := Vector2i(posmod(tx + 180, 360), CoastalGeography.NORTH - 1 - ty)
				if key.y < 0 or key.y >= CoastalGeography.TILES_Y:
					continue
				if not key in _wanted:
					_wanted.append(key)
		_wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _tile_centre(a).distance_squared_to(_unwrapped(centre)) < _tile_centre(b).distance_squared_to(_unwrapped(centre)))
	set_process(visible)
	queue_redraw()


static func _unwrapped(geo: Vector2) -> Vector2:
	return Vector2(fposmod(geo.x + 180.0, 360.0) - 180.0, geo.y)


static func _tile_centre(key: Vector2i) -> Vector2:
	return Vector2(key.x - 180 + 0.5, CoastalGeography.NORTH - key.y - 0.5)


## Whether every wanted tile is ready (tests).
func is_complete() -> bool:
	if not is_active():
		return true
	for key in _wanted:
		if not _tiles.has(key):
			return false
	return true


func _process(_delta: float) -> void:
	if not is_active():
		return
	var started := Time.get_ticks_usec()
	var had_work := _job != null or not is_complete()
	_fill(started)
	var spent := Time.get_ticks_usec() - started
	max_frame_usec = maxi(max_frame_usec, spent)
	if had_work and frame_usec.size() < FRAME_SAMPLES:
		frame_usec.append(spent)


func _fill(started: int) -> void:
	while Time.get_ticks_usec() - started < FRAME_BUDGET_USEC:
		if _job == null:
			var next := Vector2i(-1, -1)
			for key in _wanted:
				if not _tiles.has(key):
					next = key
					break
			if next.x < 0:
				return
			_job = TileJob.new(next, self)
		if _job.step(started + FRAME_BUDGET_USEC):
			_store(_job)
			_job = null


func _store(job: TileJob) -> void:
	_tiles[job.key] = {"texture": job.texture, "cells": job.classes}
	_order.erase(job.key)
	_order.append(job.key)
	while _order.size() > MAX_TILES:
		var old: Vector2i = _order.pop_front()
		if not old in _wanted:
			_tiles.erase(old)
		else:
			_order.append(old)
			break
	tiles_computed += 1
	cells_evaluated += job.evaluated
	last_tile_usec = job.usec
	last_stage_usec = job.stage_usec
	for i in 5:
		max_step_usec[i] = maxi(max_step_usec[i], job.step_max_usec[i])
	queue_redraw()
	tile_completed.emit(job.key)


## Computes every wanted tile at once (tests, benchmark).
func complete_now() -> void:
	refresh_view()
	for key in _wanted:
		if not _tiles.has(key):
			var job := TileJob.new(key, self)
			while not job.step(Time.get_ticks_usec() + 1000000000):
				pass
			_store(job)


## The overlay's class at `geo` (0 none, NORMAL, MAGIC) where its tile is
## ready, or -1.
func class_at(geo: Vector2) -> int:
	var coast := CoastalGeography.get_default()
	var cell := coast.cell_of(geo)
	var key := Vector2i(cell.x / coast.res, cell.y / coast.res)
	if not _tiles.has(key):
		return -1
	var cells: PackedByteArray = _tiles[key].cells
	var side := coast.res / STEP
	return cells[((cell.y % coast.res) / STEP) * side + (cell.x % coast.res) / STEP]


func get_tile_count() -> int:
	return _tiles.size()


func _draw() -> void:
	if not is_active():
		return
	for key in _wanted:
		if not _tiles.has(key):
			continue
		var texture: Texture2D = _tiles[key].texture
		if texture == null:
			continue
		var west := float(key.x - 180)
		var north := float(CoastalGeography.NORTH - key.y)
		var a := map_view._near_view(map_view.projection.geo_to_map(Vector2(west + 0.5, north)))
		var top_left := map_view.projection.geo_to_map(Vector2(west, north))
		var bottom_right := map_view.projection.geo_to_map(Vector2(west + 1.0, north - 1.0))
		var shift := a.x - map_view.projection.geo_to_map(Vector2(west + 0.5, north)).x
		draw_texture_rect(texture, Rect2(top_left + Vector2(shift, 0), bottom_right - top_left), false)


## One tile, worked out in resumable steps.
class TileJob extends RefCounted:
	var key: Vector2i
	var layer: AnchorageLayer
	var coast: CoastalGeography
	var depths: DepthService
	var router: SeaRouter
	var res := 120
	var margin := 0
	var x0 := 0  # window origin (fine cells)
	var y0 := 0
	var w := 0
	var h := 0
	var water := PackedByteArray()
	var clear := PackedByteArray()
	## Per window cell: the nearest land column at or left of it in its row
	## (-1: none), at or right of it (w: none); land cells before it in its row.
	var prev_land := PackedInt32Array()
	var next_land := PackedInt32Array()
	var land_prefix := PackedInt32Array()
	var dist := PackedInt32Array()
	var queue := PackedInt32Array()
	var head := 0
	var limit := 0
	var stage := 0
	var cursor := 0
	var classes := PackedByteArray()
	var texture: ImageTexture
	var evaluated := 0
	var usec := 0
	var stage_usec := PackedInt32Array([0, 0, 0, 0, 0])
	var step_max_usec := PackedInt32Array([0, 0, 0, 0, 0])
	var skip := false
	## No regional chart anywhere in the window: the fine raster alone decides
	## water, and the world routing chart navigability (asked once per routing
	## cell, not per fine cell). Same answers, much less work.
	var world_only := false
	var _routing := {}

	func _init(tile_key: Vector2i, owner: AnchorageLayer) -> void:
		key = tile_key
		layer = owner
		coast = CoastalGeography.get_default()
		depths = DepthService.get_default()
		router = SeaRouter.get_default()
		res = coast.res
		var centre := AnchorageLayer._tile_centre(key)
		limit = floori(CoastalGeography.approach_max_nm(centre) / (60.0 / res))
		var east_west := coast.cell_nm(centre.y + (0.5 if centre.y >= 0.0 else -0.5)).x
		margin = maxi(limit, ceili(DepthService.SHORE_CAP_NM / east_west) + 2) + 1
		x0 = key.x * res - margin
		y0 = key.y * res - margin
		w = res + 2 * margin
		h = res + 2 * margin
		classes.resize((res / STEP) * (res / STEP))
		world_only = true
		for corner: Vector2 in [Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0, y0 + h), Vector2(x0 + w, y0 + h), Vector2(x0 + w / 2, y0 + h / 2)]:
			if router.grid.grid_at(coast.cell_center(Vector2i(corner))) != router.grid:
				world_only = false
		# A tile with no land anywhere near: nothing to paint.
		skip = true
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var ty: int = key.y + dy
				if ty < 0 or ty >= CoastalGeography.TILES_Y:
					skip = false
					continue
				if coast._index[ty * CoastalGeography.TILES_X + posmod(key.x + dx, CoastalGeography.TILES_X)] != CoastalGeography.WATER_TILE:
					skip = false

	## Works until `deadline` (ticks usec); true when the tile is done.
	func step(deadline: int) -> bool:
		var started := Time.get_ticks_usec()
		if skip:
			texture = null
			return true
		while Time.get_ticks_usec() < deadline:
			var stage_started := Time.get_ticks_usec()
			var this_stage := stage
			_run_stage(deadline)
			var spent := Time.get_ticks_usec() - stage_started
			stage_usec[mini(this_stage, 4)] += spent
			step_max_usec[mini(this_stage, 4)] = maxi(step_max_usec[mini(this_stage, 4)], spent)
			if stage == 5:
				usec += Time.get_ticks_usec() - started
				return true
		usec += Time.get_ticks_usec() - started
		return false

	func _run_stage(deadline: int) -> void:
			match stage:
				0:  # land / water for the window, a row at a time
					if water.is_empty():
						water.resize(w * h)
						clear.resize(w * h)
						dist.resize(w * h)
						dist.fill(-1)
					var y := cursor
					for x in w:
						var cell := Vector2i(x0 + x, y0 + y)
						var wet := not coast.is_land_cell(cell) if world_only else coast._cell_water(cell)
						water[y * w + x] = 1 if wet else 0
					cursor += 1
					if cursor >= h:
						stage = 1
						cursor = 0
				1:  # clear water and the router's water (seeds), a row at a time
					var y := cursor
					if prev_land.is_empty():
						prev_land.resize(w * h)
						next_land.resize(w * h)
						land_prefix.resize(w * h + 1)
					var last := -1
					var count := 0
					for x in w:
						var i := y * w + x
						if water[i] == 0:
							last = x
						prev_land[i] = last
						land_prefix[i] = count
						count += 1 - water[i]
					var following := w
					for x in range(w - 1, -1, -1):
						if water[y * w + x] == 0:
							following = x
						next_land[y * w + x] = following
					if y > 0 and y < h - 1:
						for x in range(1, w - 1):
							var i := y * w + x
							if water[i] == 1 and water[i - 1] == 1 and water[i + 1] == 1 and water[i - w] == 1 and water[i + w] == 1:
								clear[i] = 1
								if _routing_water(coast.cell_center(Vector2i(x0 + x, y0 + y))):
									dist[i] = 0
									queue.append(i)
					cursor += 1
					if cursor >= h:
						stage = 2
				2:  # how far each clear cell is from the router's water
					var n := 0
					while head < queue.size() and (n < 256 or Time.get_ticks_usec() < deadline):
						var i := queue[head]
						head += 1
						n += 1
						if dist[i] >= limit:
							continue
						for j in [i - 1, i + 1, i - w, i + w]:
							if clear[j] == 1 and dist[j] < 0:
								dist[j] = dist[i] + 1
								queue.append(j)
					if head >= queue.size():
						stage = 3
						cursor = 0
				3:  # classify each overlay cell, one at a time
					var side := res / STEP
					var row := cursor / side
					var col := cursor % side
					classes[cursor] = _classify(margin + col * STEP + STEP / 2, margin + row * STEP + STEP / 2)
					cursor += 1
					if cursor >= side * side:
						stage = 4
				4:
					_make_texture()
					stage = 5

	## SeaRouter.is_point_navigable, remembered per routing cell when only the
	## world chart covers the window.
	func _routing_water(geo: Vector2) -> bool:
		if not world_only:
			return router.is_point_navigable(geo)
		var cell := router.grid.geo_to_cell(geo)
		var key := Vector2i(floori(cell.x), floori(cell.y))
		if not _routing.has(key):
			_routing[key] = router.grid.get_class_at(key.x, key.y) == NavGrid.NAVIGABLE
		return _routing[key]

	## The class of the fine cell at window (x, y), by the waypoint rule.
	func _classify(x: int, y: int) -> int:
		var i := y * w + x
		if clear[i] == 0 or dist[i] < 0:
			return 0
		evaluated += 1
		var geo := coast.cell_center(Vector2i(x0 + x, y0 + y))
		var info := _shore_info(x, y, geo)
		var shore := float(info.distance)
		if shore < AnchorSite.MIN_SHORE_NM:
			return 0
		var depth := DepthService.estimate(geo, shore, float(info.land_share)) if not depths.has_data() else float(depths.sample(geo).depth_m)
		if depth >= AnchorSite.MIN_DEPTH_M and depth <= AnchorSite.NORMAL_MAX_DEPTH_M:
			return AnchorageLayer.NORMAL
		if shore < AnchorSite.COASTAL_NM:
			return AnchorageLayer.MAGIC
		return 0

	## CoastalGeography.shore_info on the window's arrays, the same result:
	## the nearest land in each row from the precomputed nearest land columns,
	## the land share from row prefix counts (boundary cells tested exactly as
	## shore_info does).
	func _shore_info(x: int, y: int, geo: Vector2) -> Dictionary:
		var size := coast.cell_nm(geo.y)
		var max_nm := DepthService.SHORE_CAP_NM
		var share_nm := 1.5
		var ry := ceili(max_nm / size.y) + 1
		var nearest := max_nm
		var land := 0
		var total := 0
		for dy in range(-ry, ry + 1):
			var cy := y + dy
			if cy < 0 or cy >= h:
				return coast.shore_info(geo, max_nm, share_nm)  # (never: the window has the margin)
			var gy := maxf(absf(dy) - 0.5, 0.0) * size.y
			if gy > max_nm:
				continue
			var row := cy * w
			for c: int in [prev_land[row + x], next_land[row + x]]:
				if c < 0 or c >= w:
					continue
				var gx := maxf(absf(c - x) - 0.5, 0.0) * size.x
				var d := sqrt(gx * gx + gy * gy)
				if d <= max_nm:
					nearest = minf(nearest, d)
			if gy <= share_nm:
				var reach := floori(sqrt(maxf(share_nm * share_nm - gy * gy, 0.0)) / size.x + 0.5)
				while _within(reach + 1, gy, size.x, share_nm):
					reach += 1
				while reach >= 1 and not _within(reach, gy, size.x, share_nm):
					reach -= 1
				var a := maxi(x - reach, 0)
				var b := mini(x + reach, w - 1)
				total += b - a + 1
				land += land_prefix[row + b] + (1 - water[row + b]) - land_prefix[row + a]
		return {"distance": nearest, "land_share": float(land) / maxf(total, 1)}

	## Whether a cell `dx` columns away (gap gy north-south) is inside the
	## land-share circle, by shore_info's own test.
	static func _within(dx: int, gy: float, cell_x: float, share_nm: float) -> bool:
		var gx := maxf(absf(dx) - 0.5, 0.0) * cell_x
		return sqrt(gx * gx + gy * gy) <= share_nm

	func _make_texture() -> void:
		var side := res / STEP
		var any := false
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		# Transparent in a neutral colour, so the smoothing below never makes
		# dark fringes.
		image.fill(Color(0.55, 0.78, 0.62, 0.0))
		for row in side:
			for col in side:
				var c := classes[row * side + col]
				if c == AnchorageLayer.NORMAL:
					image.set_pixel(col, row, AnchorageLayer.NORMAL_COLOUR)
					any = true
				elif c == AnchorageLayer.MAGIC:
					image.set_pixel(col, row, AnchorageLayer.MAGIC_COLOUR)
					any = true
		# Soft edges, like the weather highlights (once per tile).
		image.resize(side * 2, side * 2, Image.INTERPOLATE_BILINEAR)
		texture = ImageTexture.create_from_image(image) if any else null
