class_name DepthData
extends RefCounted
## An installed bathymetry subset (Revision 0.105b, tiers A/B of
## DepthService), made by tools/navigation/build_depth.py from a bounded
## download of a real model (e.g. GEBCO). None is installed in this build;
## the reader is tested with synthetic data.
##
## File: "LCHD", uint32 version, uint32 cells_per_degree, uint32 source
## (0 regional, 1 global), uint32 tile_count; uint8 index[152][360] (row 0 =
## 79..80 N, column 0 = 180 W; 1 where a tile is present); uint32 offset,
## uint32 size per present tile in index order; zlib-deflated int16
## elevations (metres, negative below sea level), res x res, rows north to
## south. Tiles are decompressed on first use and kept.

const MAGIC := "LCHD"
const NORTH := 80
const TILES_X := 360
const TILES_Y := 152

var res := 60
var source: StringName = DepthService.SOURCE_GLOBAL
var _index := PackedByteArray()
var _offsets := {}
var _file := PackedByteArray()
var _tiles := {}


static func load_from(path: String) -> DepthData:
	if not FileAccess.file_exists(path):
		return null
	var data := DepthData.new()
	data._file = FileAccess.get_file_as_bytes(path)
	if data._file.size() < 20 or data._file.slice(0, 4).get_string_from_ascii() != MAGIC:
		push_warning("DepthData: %s is not a depth file; using game estimates." % path)
		return null
	data.res = data._file.decode_u32(8)
	data.source = DepthService.SOURCE_REGIONAL if data._file.decode_u32(12) == 0 else DepthService.SOURCE_GLOBAL
	var count := data._file.decode_u32(16)
	data._index = data._file.slice(20, 20 + TILES_X * TILES_Y)
	var table := 20 + TILES_X * TILES_Y
	var n := 0
	for i in data._index.size():
		if data._index[i] == 1:
			data._offsets[i] = [data._file.decode_u32(table + n * 8), data._file.decode_u32(table + n * 8 + 4)]
			n += 1
	if n != count:
		push_warning("DepthData: %s is damaged; using game estimates." % path)
		return null
	return data


## North-south size of a data cell (nm).
func cell_nm(_lat: float) -> float:
	return 60.0 / res


## Depth (m, positive) at `geo`, bilinear; NAN where there are no data.
func sample(geo: Vector2) -> float:
	var x := fposmod(geo.x + 180.0, 360.0) * res - 0.5
	var y := (float(NORTH) - geo.y) * res - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var v := [_at(x0, y0), _at(x0 + 1, y0), _at(x0, y0 + 1), _at(x0 + 1, y0 + 1)]
	for value: float in v:
		if is_nan(value):
			return NAN
	var fx := x - x0
	var fy := y - y0
	var elevation := lerpf(lerpf(v[0], v[1], fx), lerpf(v[2], v[3], fx), fy)
	return -elevation


func _at(cx: int, cy: int) -> float:
	if cy < 0 or cy >= TILES_Y * res:
		return NAN
	cx = posmod(cx, TILES_X * res)
	var key := (cy / res) * TILES_X + cx / res
	if not _offsets.has(key):
		return NAN
	var tile: PackedByteArray = _tiles.get(key, PackedByteArray())
	if tile.is_empty():
		var entry: Array = _offsets[key]
		tile = _file.slice(entry[0], entry[0] + entry[1]).decompress(res * res * 2, FileAccess.COMPRESSION_DEFLATE)
		_tiles[key] = tile
	return float(tile.decode_s16(((cy % res) * res + cx % res) * 2))
