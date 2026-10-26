class_name DepthService
extends RefCounted
## How deep the water is, for anchoring (Revision 0.105b): the one place the
## game asks. Gameplay guidance only - never navigation-grade.
##
## Three tiers, each answer labelled with where it came from:
##   A  regional data  - a detailed regional bathymetry file, where one is
##                       installed (none in this build);
##   B  global data    - a global bathymetric model subset (e.g. GEBCO),
##                       where one is installed (none in this build): data/
##                       navigation/depth/depth.bin, made by
##                       tools/navigation/build_depth.py. Such values are
##                       mostly interpolated, not soundings, and say so;
##   C  game estimate  - everywhere else (in 0.105b: everywhere): a smooth,
##                       deterministic estimate, the same at the same place in
##                       every game and after every restart.
## No real bathymetry could be obtained for this build (see
## docs/revisions/v0.105b/REVISION_0_105B_REPORT.md section 5), so every depth shown is a GAME
## ESTIMATE and is labelled as one.
##
## The estimate: depth grows with distance from the shore,
##   depth = 3 m + 17 m * slope * shore_nm ^ 0.9   (shore_nm capped at 6),
## (3 m at the water's edge: the boats' harbour approaches and channels are
## sailable water, so the estimate never calls them too shallow),
## where `slope` varies smoothly over the world (a fixed-seed value-noise field
## on a 0.75 degree lattice, contrast-stretched and mapped geometrically to
## 0.55..3.2 (gentler in the shallow shelf seas, SHELF_SEAS): gentle shelves to steep island
## flanks) and is reduced in enclosed bays (much land around: shallower). It
## never depends on the game's seed, the time or the boat. Near shore it is
## shallow but not always (steep coasts are deep a few cables off); a mile
## out on a steep coast it can be 50 m or more.

const SOURCE_REGIONAL := &"regional_data"
const SOURCE_GLOBAL := &"global_data"
const SOURCE_ESTIMATE := &"game_estimate"
const DATA_PATH := "res://data/navigation/depth/depth.bin"
const SHORE_CAP_NM := 6.0
const SLOPE_RANGE := Vector2(0.55, 3.2)
const LATTICE_DEG := 0.75
const NOISE_SEED := 105

static var _default: DepthService
var coast: CoastalGeography
var _data: DepthData


static func get_default() -> DepthService:
	if _default == null:
		_default = DepthService.new(CoastalGeography.get_default())
		_default.load_data(DATA_PATH)
	return _default


func _init(coastal: CoastalGeography = null) -> void:
	coast = coastal


## Installs an optional bathymetry file (tiers A/B). Returns whether it loaded.
func load_data(path: String) -> bool:
	_data = DepthData.load_from(path)
	return _data != null


func has_data() -> bool:
	return _data != null


## The depth at `geo`: {"depth_m", "source", "label", "shore_nm"}. On land
## (or where the coast raster says land) depth_m is 0 and source "".
func sample(geo: Vector2) -> Dictionary:
	if not coast.is_water(geo):
		return {"depth_m": 0.0, "source": &"", "label": "land", "shore_nm": 0.0}
	var info := coast.shore_info(geo, SHORE_CAP_NM, 1.5)
	var shore := float(info.distance)
	if _data:
		var value := _data.sample(geo)
		# Data only where it has something to say and is not too coarse for
		# the near-shore water (within one data cell of land, estimate).
		if not is_nan(value) and value > 0.0 and shore >= _data.cell_nm(geo.y):
			return {"depth_m": value, "source": _data.source, "label": source_label(_data.source), "shore_nm": shore}
	return {"depth_m": estimate(geo, shore, float(info.land_share)), "source": SOURCE_ESTIMATE,
		"label": source_label(SOURCE_ESTIMATE), "shore_nm": shore}


## The game estimate for a point `shore_nm` from land with `land_share` of
## land around it (see the class notes).
static func estimate(geo: Vector2, shore_nm: float, land_share: float) -> float:
	# Contrast-stretched (blending four corners bunches values in the middle)
	# and spread geometrically, so gentle and steep coasts are both common.
	var n := smoothstep(0.2, 0.8, value_noise(geo))
	var slopes := _slope_range(geo)
	var slope := exp(lerpf(log(slopes.x), log(slopes.y), n))
	slope *= lerpf(1.0, 0.55, clampf((land_share - 0.2) / 0.4, 0.0, 1.0))
	return 3.0 + 17.0 * slope * pow(clampf(shore_nm, 0.0, SHORE_CAP_NM), 0.9)


## Shallow shelf seas (broad, well-known geography, not survey data): the
## estimate's slope range there, gentle instead of the world's 0.55..3.2.
## [west, south, east, north, slope min, slope max]; first match wins.
const SHELF_SEAS := [
	[8.0, 54.3, 13.2, 58.2, 0.35, 0.75],    # Danish straits and the Kattegat (mean depth ~20 m)
	[9.0, 53.5, 30.0, 66.0, 0.45, 1.3],     # the Baltic (mean ~55 m)
	[-4.0, 51.0, 9.0, 56.5, 0.45, 1.0],     # southern North Sea and the German Bight
]


static func _slope_range(geo: Vector2) -> Vector2:
	for sea: Array in SHELF_SEAS:
		if geo.x >= sea[0] and geo.y >= sea[1] and geo.x <= sea[2] and geo.y <= sea[3]:
			return Vector2(sea[4], sea[5])
	return SLOPE_RANGE


## Smooth deterministic noise in 0..1 (bilinear with smoothstep on a fixed
## lattice; longitude wraps).
static func value_noise(geo: Vector2) -> float:
	var x := fposmod(geo.x + 180.0, 360.0) / LATTICE_DEG
	var y := (geo.y + 90.0) / LATTICE_DEG
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := smoothstep(0.0, 1.0, x - x0)
	var fy := smoothstep(0.0, 1.0, y - y0)
	var columns := roundi(360.0 / LATTICE_DEG)
	var a := _hash01(posmod(x0, columns), y0)
	var b := _hash01(posmod(x0 + 1, columns), y0)
	var c := _hash01(posmod(x0, columns), y0 + 1)
	var d := _hash01(posmod(x0 + 1, columns), y0 + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _hash01(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263 + NOISE_SEED * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## How a depth's source is written for the player.
static func source_label(source: StringName) -> String:
	match source:
		SOURCE_REGIONAL:
			return "regional depth data (modelled)"
		SOURCE_GLOBAL:
			return "global depth model (mostly interpolated)"
		SOURCE_ESTIMATE:
			return "GAME ESTIMATE"
	return ""


## "about 9 m" / "about 85 m": rounded, never a false precision.
static func describe_depth(depth_m: float) -> String:
	if depth_m < 10.0:
		return "about %d m" % maxi(roundi(depth_m), 1)
	if depth_m < 100.0:
		return "about %d m" % (roundi(depth_m / 5.0) * 5)
	return "about %d m" % (roundi(depth_m / 50.0) * 50)
