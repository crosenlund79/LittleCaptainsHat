class_name CoastalGeography
extends RefCounted
## Where the water really is near a coast (Revision 0.105b), for anchoring.
##
## The routing raster (NavGrid) is deliberately coarse on the world chart
## (about 5 nm cells, "navigable" only where a whole cell is clear of land),
## so it cannot say how close to a shore the water goes. This service reads a
## fine raster of the same OpenStreetMap land polygons
## (data/navigation/coast/, 1/120 degree, about 0.5 nm north-south; built by
## tools/navigation/build_coast.py) and answers, near any point on Earth:
##   - is_water(geo): water in the fine raster and not land on a coarser
##     regional chart (Europe) covering it - both must agree, so an anchorage
##     is never drawn on the chart's land; where a regional chart is much
##     finer than this raster (Denmark), that chart decides;
##   - is_clear(geo): water with no land in the four neighbouring fine cells
##     (at least ~0.3 nm from the shore): where a boat may lie and pass;
##   - shore_distance_nm(geo, max): continuous distance to the nearest land
##     (to the edge of the nearest land cell), for depth and the rule "not too
##     close to the shore";
##   - approach(geo): a short way (at most approach_max_nm()) through clear water
##     from geo to water the router already uses (a navigable routing cell),
##     found by a breadth-first search over fine cells and pulled tight. The
##     router uses it to reach an anchorage the coarse raster cannot express;
##     the anchorage overlay uses the same search, so both always agree. A
##     narrow entrance (less than about a cell wide) is never passed.
##   - fetch_nm(geo, from_deg): open water upwind, for shelter.
## Tiles are decompressed on first use and kept (at most CACHE_TILES).

const PATH := "res://data/navigation/coast/coast.bin"
const MAGIC := "LCHC"
const SOUTH := -72
const NORTH := 80
const TILES_X := 360
const TILES_Y := NORTH - SOUTH
const WATER_TILE := 0
const LAND_TILE := 1
const MIXED_TILE := 2
const CACHE_TILES := 512
## The longest approach from routing water to an anchorage (nm): at least
## APPROACH_MIN_NM, and on coarse routing charts twice their cell size (the
## world chart keeps only water a whole ~5 nm cell clear of land, as harbour
## approaches allow for too).
const APPROACH_MIN_NM := 6.0
const APPROACH_CELLS := 2.2
const FETCH_MAX_NM := 8.0
const FETCH_STEP_NM := 0.25

static var _default: CoastalGeography

var res := 120
var _index := PackedByteArray()
var _offsets := {}  # tile key -> [offset, size]
var _file := PackedByteArray()
var _tiles := {}  # tile key -> PackedByteArray (res*res bits, rows north to south, MSB first; 1 = land)
var _tile_order: Array[int] = []
var loaded := false
## Counters for tests and the benchmark.
var tiles_decoded := 0


static func get_default() -> CoastalGeography:
	if _default == null:
		_default = CoastalGeography.new()
		_default.load_file(PATH)
	return _default


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("CoastalGeography: %s is missing; near-shore anchoring falls back to the routing chart." % path)
		return false
	_file = FileAccess.get_file_as_bytes(path)
	if _file.size() < 16 or _file.slice(0, 4).get_string_from_ascii() != MAGIC:
		push_warning("CoastalGeography: %s is not a coast raster." % path)
		_file = PackedByteArray()
		return false
	res = _file.decode_u32(8)
	var mixed := _file.decode_u32(12)
	_index = _file.slice(16, 16 + TILES_X * TILES_Y)
	var table := 16 + TILES_X * TILES_Y
	var n := 0
	for i in _index.size():
		if _index[i] == MIXED_TILE:
			_offsets[i] = [_file.decode_u32(table + n * 8), _file.decode_u32(table + n * 8 + 4)]
			n += 1
	loaded = n == mixed
	return loaded


## Fine cell (column from 180°W, row from 80°N) of `geo`, longitude wrapped.
func cell_of(geo: Vector2) -> Vector2i:
	var lon := fposmod(geo.x + 180.0, 360.0)
	return Vector2i(floori(lon * res), floori((float(NORTH) - geo.y) * res))


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) / res - 180.0, float(NORTH) - (cell.y + 0.5) / res)


## Land in the fine raster at a fine cell (outside 72°S..80°N: land).
func is_land_cell(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= TILES_Y * res:
		return true
	var cx := posmod(cell.x, TILES_X * res)
	var key := (cell.y / res) * TILES_X + cx / res
	if not loaded:
		return false
	var kind := _index[key]
	if kind != MIXED_TILE:
		return kind == LAND_TILE
	var tile: PackedByteArray = _tiles.get(key, PackedByteArray())
	if tile.is_empty():
		tile = _decode(key)
	var bit := (cell.y % res) * res + cx % res
	return (tile[bit >> 3] >> (7 - (bit & 7))) & 1 == 1


func _decode(key: int) -> PackedByteArray:
	# Kept bit-packed (decompressing is native and fast; bits are read on use).
	var entry: Array = _offsets[key]
	var tile := _file.slice(entry[0], entry[0] + entry[1]).decompress(res * res / 8, FileAccess.COMPRESSION_DEFLATE)
	_tiles[key] = tile
	_tile_order.append(key)
	tiles_decoded += 1
	if _tile_order.size() > CACHE_TILES:
		_tiles.erase(_tile_order.pop_front())
	return tile


## Water at `geo` from the best source covering it: a regional chart much
## finer than this raster (Denmark, 1/360 degree) is the authority there - its
## narrow harbour channels are real water the routes use; elsewhere the fine
## raster decides, and a coarser regional chart (Europe) may still veto (both
## must agree, so an anchorage is never drawn on the chart's own land).
func _water_at(geo: Vector2, land_cell: bool) -> bool:
	var router := SeaRouter.get_loaded()
	if router != null and router.grid != null:
		var regional := router.grid.grid_at(geo)  # the world grid itself where no region covers
		if regional != router.grid:
			var regional_class := regional.cell_class_at_geo(geo)
			if regional.cells_per_degree >= res * 2.0:
				return regional_class != NavGrid.LAND
			if regional_class == NavGrid.LAND:
				return false
	return not land_cell


func is_water(geo: Vector2) -> bool:
	return _water_at(geo, is_land_cell(cell_of(geo)))


func _cell_water(cell: Vector2i) -> bool:
	return _water_at(cell_center(cell), is_land_cell(cell))


## Water with water on all four sides (a boat's width from the shore).
func is_clear_cell(cell: Vector2i) -> bool:
	if not _cell_water(cell):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _cell_water(cell + d):
			return false
	return true


func is_clear(geo: Vector2) -> bool:
	return is_clear_cell(cell_of(geo))


## Size of a fine cell at latitude `lat`: (east-west nm, north-south nm).
func cell_nm(lat: float) -> Vector2:
	var ns := 60.0 / res
	return Vector2(ns * maxf(cos(deg_to_rad(lat)), 0.05), ns)


## Distance (nm) from `geo` to the nearest land cell's edge, at most `max_nm`
## (returned when there is none so close). Continuous in `geo`.
func shore_distance_nm(geo: Vector2, max_nm := 3.0) -> float:
	var info := shore_info(geo, max_nm)
	return float(info.distance)


## {"distance" (nm, as shore_distance_nm), "land_share" (share of land cells
## within share_nm: 0 open coast .. 1 enclosed bay)}.
func shore_info(geo: Vector2, max_nm := 3.0, share_nm := 1.5) -> Dictionary:
	var size := cell_nm(geo.y)
	var centre := cell_of(geo)
	var lon := fposmod(geo.x + 180.0, 360.0)
	# The point in cell units.
	var px := lon * res
	var py := (float(NORTH) - geo.y) * res
	var rx := ceili(max_nm / size.x) + 1
	var ry := ceili(max_nm / size.y) + 1
	var nearest := max_nm
	var land := 0
	var total := 0
	var small := minf(size.x, size.y)
	# Outward ring by ring (Chebyshev rings of cells); stop once no cell further
	# out can be nearer than the land found, nor inside the land-share circle.
	for r in maxi(rx, ry) + 1:
		if r >= 2 and (r - 1) * small > maxf(nearest, share_nm):
			break
		for dy in range(-mini(r, ry), mini(r, ry) + 1):
			var row_edge := absi(dy) == r
			var dx := -mini(r, rx)
			while dx <= mini(r, rx):
				if not row_edge and absi(dx) != r:
					dx = mini(r, rx)  # inside the ring: jump to its east side
					if absi(dx) != r:
						break
				var c := centre + Vector2i(dx, dy)
				# Gap from the point to this cell's rectangle, in nm.
				var gx := maxf(maxf(float(c.x) - px, px - float(c.x + 1)), 0.0) * size.x
				var gy := maxf(maxf(float(c.y) - py, py - float(c.y + 1)), 0.0) * size.y
				var d := sqrt(gx * gx + gy * gy)
				if d <= max_nm:
					var water := _cell_water(c)
					if d <= share_nm:
						total += 1
						land += 0 if water else 1
					if not water:
						nearest = minf(nearest, d)
				dx += 1
	return {"distance": nearest, "land_share": float(land) / maxf(total, 1)}


## Whether a straight line stays in clear water (sampled every ~0.1 nm).
func is_line_clear(a: Vector2, b: Vector2) -> bool:
	var nm := GeoMath.rhumb_distance_nm(a, b)
	var steps := maxi(ceili(nm / 0.1), 1)
	var delta := GeoMath.normalize(b) - GeoMath.normalize(a)
	delta.x = wrapf(delta.x, -180.0, 180.0)
	for i in steps + 1:
		if not is_clear(a + delta * (float(i) / steps)):
			return false
	return true


## A way from `geo` (in clear water) to water the router uses: the points
## [geo, ..., routing water], pulled tight, at most approach_max_nm() long; or
## [] when there is none. [geo] alone when geo is routing water already.
func approach(geo: Vector2, is_routing_water := Callable(), max_nm := -1.0) -> PackedVector2Array:
	# `is_routing_water(geo) -> bool` and `max_nm` replace the router's water
	# and limit (tests use a synthetic coast).
	if not is_routing_water.is_valid():
		is_routing_water = SeaRouter.get_default().is_point_navigable
	if is_routing_water.call(geo):
		return PackedVector2Array([geo])
	var start := cell_of(geo)
	if not is_clear_cell(start):
		return PackedVector2Array()
	var limit := _approach_cells(geo) if max_nm < 0.0 else floori(max_nm / (60.0 / res))
	var came := {start: start}
	var depth := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var found := Vector2i(-1, -1)
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if is_routing_water.call(cell_center(cell)):
			found = cell
			break
		if int(depth[cell]) >= limit:
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + d
			if not came.has(next) and is_clear_cell(next):
				came[next] = cell
				depth[next] = int(depth[cell]) + 1
				queue.append(next)
	if found.x < 0:
		return PackedVector2Array()
	var cells: Array[Vector2] = []
	var at := found
	while at != start:
		cells.push_front(_continuous(cell_center(at), geo))
		at = came[at]
	cells.push_front(geo)
	# Pull tight.
	var result := PackedVector2Array([geo])
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not is_line_clear(cells[i], cells[j]):
			j -= 1
		result.append(cells[j])
		i = j
	return result


## How many fine-cell steps the approach may take (north-south cells, the
## longer side, so the limit in nm is never exceeded).
func _approach_cells(geo: Vector2) -> int:
	return floori(approach_max_nm(geo) / (60.0 / res))


## How far an anchorage may lie from the router's water at `geo` (nm).
static func approach_max_nm(geo: Vector2) -> float:
	var router := SeaRouter.get_default()
	return maxf(APPROACH_MIN_NM, APPROACH_CELLS * SeaRouter._cell_nm(router.grid.grid_at(geo)))


## `point` with its longitude moved next to `near`'s (no jump at the Date Line).
static func _continuous(point: Vector2, near: Vector2) -> Vector2:
	return Vector2(near.x + wrapf(point.x - near.x, -180.0, 180.0), point.y)


## Open water upwind of `geo` (nm, at most FETCH_MAX_NM): the wind comes from
## `from_deg`. Measured on the fine raster.
func fetch_nm(geo: Vector2, from_deg: float) -> float:
	var bearing := deg_to_rad(from_deg)
	var d := FETCH_STEP_NM
	while d <= FETCH_MAX_NM:
		if not is_water(AnchorSite.offset(geo, bearing, d)):
			return d
		d += FETCH_STEP_NM
	return FETCH_MAX_NM
