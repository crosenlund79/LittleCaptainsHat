class_name NavGrid
extends RefCounted
## The navigability raster: which parts of the chart a vessel may sail through.
##
## Cells are laid out in Mercator space (CELLS_PER_DEGREE per Mercator degree),
## so a rhumb line is a straight line through the grid and can be checked
## exactly, cell by cell. Each cell holds one of three classes:
##   NAVIGABLE (255): no land in any part of the cell. Routes may pass.
##   APPROACH  (128): mostly water. Only usable for bounded harbour approaches.
##   LAND      (0):   everything else, including the area outside the chart.
## The raster is generated from the same coastline polygons the chart draws
## (tools/navigation/build_navigation_data.py).

const NAVIGABLE := 255
const APPROACH := 128
const LAND := 0

const DEFAULT_MASK := "res://data/navigation/europe_navmask.png"
const DEFAULT_META := "res://data/navigation/europe_navmask.json"

var columns := 0
var rows := 0
var cells_per_degree := 60.0
var west := 0.0
var mercator_north := 0.0
var _cells := PackedByteArray()


static func load_from(mask_path: String, meta_path: String) -> NavGrid:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	var bytes := FileAccess.get_file_as_bytes(mask_path)
	if not meta is Dictionary or bytes.is_empty():
		push_error("Navigation data missing: %s / %s" % [mask_path, meta_path])
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		push_error("Navigation mask unreadable: %s" % mask_path)
		return null
	image.convert(Image.FORMAT_L8)
	var grid := NavGrid.new()
	grid.columns = image.get_width()
	grid.rows = image.get_height()
	grid.cells_per_degree = float(meta.cells_per_mercator_degree)
	grid.west = float(meta.bounds.west)
	grid.mercator_north = float(meta.mercator_north)
	grid._cells = image.get_data()
	if grid.columns != int(meta.columns) or grid.rows != int(meta.rows):
		push_error("Navigation mask size does not match its metadata.")
		return null
	return grid


# --- Coordinates -----------------------------------------------------------------------

## Geographic Vector2(lon, lat) to continuous cell coordinates (column, row).
func geo_to_cell(geo: Vector2) -> Vector2:
	var lat := deg_to_rad(clampf(geo.y, -85.0, 85.0))
	var mercator_y := rad_to_deg(log(tan(PI / 4.0 + lat / 2.0)))
	return Vector2((geo.x - west) * cells_per_degree, (mercator_north - mercator_y) * cells_per_degree)


func cell_to_geo(cell: Vector2) -> Vector2:
	var mercator_y := deg_to_rad(mercator_north - cell.y / cells_per_degree)
	return Vector2(west + cell.x / cells_per_degree, rad_to_deg(2.0 * atan(exp(mercator_y)) - PI / 2.0))


## Geographic centre of the cell (column, row).
func cell_center_geo(column: int, row: int) -> Vector2:
	return cell_to_geo(Vector2(column + 0.5, row + 0.5))


# --- Queries ------------------------------------------------------------------------------

func get_class_at(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= columns or row >= rows:
		return LAND
	return _cells[row * columns + column]


func cell_class_at_geo(geo: Vector2) -> int:
	var cell := geo_to_cell(geo)
	return get_class_at(floori(cell.x), floori(cell.y))


func is_navigable(geo: Vector2) -> bool:
	return cell_class_at_geo(geo) == NAVIGABLE


## True if the straight line between two cell-space points only passes through
## cells of at least `min_class`. Every cell the line touches is checked
## (supercover traversal); when the line passes exactly through a cell corner,
## both side cells must qualify. Mirrors segment_clear() in the data builder.
func is_line_clear(from: Vector2, to: Vector2, min_class := NAVIGABLE) -> bool:
	var ix := floori(from.x)
	var iy := floori(from.y)
	var ex := floori(to.x)
	var ey := floori(to.y)
	if get_class_at(ix, iy) < min_class:
		return false
	var dx := to.x - from.x
	var dy := to.y - from.y
	var step_x := 1 if dx > 0.0 else (-1 if dx < 0.0 else 0)
	var step_y := 1 if dy > 0.0 else (-1 if dy < 0.0 else 0)
	var t_delta_x := absf(1.0 / dx) if dx != 0.0 else INF
	var t_delta_y := absf(1.0 / dy) if dy != 0.0 else INF
	var t_max_x := INF
	var t_max_y := INF
	if dx != 0.0:
		t_max_x = ((ix + 1 - from.x) if dx > 0.0 else (from.x - ix)) * t_delta_x
	if dy != 0.0:
		t_max_y = ((iy + 1 - from.y) if dy > 0.0 else (from.y - iy)) * t_delta_y
	var guard := absi(ex - ix) + absi(ey - iy) + 2
	while (ix != ex or iy != ey) and guard > 0:
		guard -= 1
		if absf(t_max_x - t_max_y) < 1e-9:
			if get_class_at(ix + step_x, iy) < min_class or get_class_at(ix, iy + step_y) < min_class:
				return false
			ix += step_x
			iy += step_y
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		elif t_max_x < t_max_y:
			ix += step_x
			t_max_x += t_delta_x
		else:
			iy += step_y
			t_max_y += t_delta_y
		if get_class_at(ix, iy) < min_class:
			return false
	return true


func is_geo_line_clear(from: Vector2, to: Vector2, min_class := NAVIGABLE) -> bool:
	return is_line_clear(geo_to_cell(from), geo_to_cell(to), min_class)
