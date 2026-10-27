class_name TrafficModel
extends RefCounted
## Maritime traffic (I019, The Captain's Watch): other vessels at sea, made
## up deterministically where and when they are looked for. Nothing runs for
## the whole world and nothing is saved.
##
## The sea is cut into CELL_DEG cells and time into WINDOW_SECONDS windows.
## Each (cell, window) holds a few vessels (more near harbours, few on the
## open ocean), each on a straight track through a point of navigable water
## in the cell, at a steady speed for its kind, passing that point at a time
## inside the window and sailing at most LIFETIME_SECONDS in all (the track
## ends where it would meet land). A vessel is a pure
## function of (cell, window, slot, seed): asking twice, after a load, while
## asleep or in Long Passage always gives the same ships in the same places.
## Track definitions are cached (bounded); positions are computed on demand.
##
## Not a shipping database or a navigation AI: plausible, readable traffic
## for awareness and the occasional warning. Not a certified instrument.

const CELL_DEG := 1.0
const WINDOW_SECONDS := 3.0 * 3600.0
## How long each vessel is on its track (centred on its time at the point).
const LIFETIME_SECONDS := 4.0 * 3600.0
## At most this many vessels per cell and window (busy waters).
const MAX_PER_CELL := 8
## Harbours within this distance of a cell make it busier.
const BUSY_RADIUS_NM := 90.0
const CACHE_LIMIT := 4096
## A track starting within this distance of the boat stays unseen for its
## first hour (ships come over the horizon, not out of nowhere).
const HIDDEN_START_NM := 12.0
## Track shape: up to TRACK_ATTEMPTS tries, checked on water every
## LIFETIME_SECONDS / 2 / TRACK_STEPS each way, at least MIN_TRACK_SECONDS long.
const TRACK_ATTEMPTS := 4
const TRACK_STEPS := 8
const MIN_TRACK_SECONDS := 3600.0

## [id, display name (Loc), [min kn, max kn], needs harbours nearby]
const KINDS := [
	[&"cargo", "Cargo ship", [11.0, 16.0], false],
	[&"tanker", "Tanker", [10.0, 13.0], false],
	[&"ferry", "Ferry", [14.0, 18.0], true],
	[&"fishing", "Fishing boat", [4.0, 7.0], true],
	[&"yacht", "Sailing yacht", [4.5, 7.0], true],
]
const NAMES := ["Nordlys", "Baltic Star", "Margrethe", "Sea Swallow", "Ocean Breeze", "Kristina", "Polar Wind", "Havørn",
	"Silver Tern", "Morning Light", "Atlantic Way", "Freja", "Blue Heron", "Stella Maris", "Seagull", "Westerly", "Ingrid",
	"Southern Cross", "Lighthouse", "Tidewater", "Aurora", "Kittiwake", "Fair Wind", "Cormorant"]

static var _default: TrafficModel

var _tracks := {}
var _density := {}


static func get_default() -> TrafficModel:
	if _default == null:
		_default = TrafficModel.new()
	return _default


## The vessels within `range_nm` of `geo` at `time`: [{"id", "kind", "name",
## "geo", "course", "speed_kn", "offset_nm" (east/north of `geo`)}],
## nearest first.
func vessels_near(geo: Vector2, time: float, seed: int, range_nm: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var lat_cos := maxf(cos(deg_to_rad(geo.y)), 0.05)
	# A track reaches at most half its lifetime at the top speed from its point.
	var reach := range_nm + 18.0 * LIFETIME_SECONDS / 7200.0
	var dlat := ceili(reach / 60.0 / CELL_DEG)
	var dlon := ceili(reach / (60.0 * lat_cos) / CELL_DEG)
	var cx := floori(geo.x / CELL_DEG)
	var cy := floori(geo.y / CELL_DEG)
	var w0 := floori((time - LIFETIME_SECONDS / 2.0) / WINDOW_SECONDS)
	var w1 := floori((time + LIFETIME_SECONDS / 2.0) / WINDOW_SECONDS)
	for j in range(cy - dlat, cy + dlat + 1):
		if j < -80 or j > 79:
			continue
		for i in range(cx - dlon, cx + dlon + 1):
			var ci := posmod(i + 180, 360) - 180
			for w in range(w0, w1 + 1):
				for track: Dictionary in _cell_tracks(ci, j, w, seed):
					var dt: float = time - float(track.passes_at)
					if dt < float(track.from) or dt > float(track.to):
						continue
					var vessel_geo := ChartPlotter._geo_at(track.point, track.velocity * dt / 3600.0)
					var offset := ChartPlotter._nm_offset(geo, vessel_geo)
					if offset.length() > range_nm:
						continue
					# No ship appears out of nowhere beside the boat: in its first
					# hour, one whose track began within sight of here is not seen.
					var age := dt - float(track.from)
					if age < 3600.0 and (offset - track.velocity * age / 3600.0).length() < HIDDEN_START_NM:
						continue
					found.append({"id": track.id, "kind": track.kind, "name": track.name, "geo": GeoMath.normalize(vessel_geo),
						"course": track.course, "speed_kn": track.speed_kn, "offset_nm": offset, "age_h": age / 3600.0})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.offset_nm as Vector2).length() < (b.offset_nm as Vector2).length())
	return found


## The tracks of one cell and window (cached; pure function of the inputs).
func _cell_tracks(cell_x: int, cell_y: int, window: int, seed: int) -> Array:
	var key := Vector4i(cell_x, cell_y, window, seed)
	if _tracks.has(key):
		return _tracks[key]
	var router := SeaRouter.get_loaded()
	if router == null:
		return []  # the sea is not loaded yet: no ships (and nothing cached)
	if _tracks.size() >= CACHE_LIMIT:
		_tracks.clear()
	var tracks := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cell_x, cell_y, window, seed, "traffic"])
	var busy := _busyness(cell_x, cell_y)
	var count := mini(floori(busy * MAX_PER_CELL + rng.randf()), MAX_PER_CELL)
	for slot in count:
		var kinds := KINDS.filter(func(k: Array) -> bool: return not k[3] or busy >= 0.35)
		var kind: Array = kinds[rng.randi_range(0, kinds.size() - 1)]
		var speed := rng.randf_range(float(kind[2][0]), float(kind[2][1]))
		var passes_at := (window + rng.randf()) * WINDOW_SECONDS
		var name: String = NAMES[rng.randi_range(0, NAMES.size() - 1)]
		# A few tries for a point on the water and a course along it: in
		# narrow waters (sounds, belts, fjords) the track is cut where it
		# meets land, and kept when at least MIN_TRACK_SECONDS remain.
		for attempt in TRACK_ATTEMPTS:
			var point := Vector2(cell_x + rng.randf(), cell_y + rng.randf()) * CELL_DEG
			var course := rng.randf_range(0.0, 360.0)
			if not router.is_point_navigable(point):
				continue
			var velocity := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course))) * speed
			var span := [0.0, 0.0]
			for side in 2:
				var direction := -1.0 if side == 0 else 1.0
				for k in range(1, TRACK_STEPS + 1):
					var dt := direction * k * LIFETIME_SECONDS / 2.0 / TRACK_STEPS
					if not router.is_point_navigable(GeoMath.normalize(ChartPlotter._geo_at(point, velocity * dt / 3600.0))):
						break
					span[side] = dt
			if span[1] - span[0] < MIN_TRACK_SECONDS:
				continue
			tracks.append({"id": "%d:%d:%d:%d" % [cell_x, cell_y, window, slot], "kind": kind[0], "name": name, "point": point,
				"course": course, "speed_kn": speed, "velocity": velocity, "passes_at": passes_at, "from": span[0], "to": span[1]})
			break
	_tracks[key] = tracks
	return tracks


## 0..1: how busy a cell's waters are (harbours nearby make them busier).
func _busyness(cell_x: int, cell_y: int) -> float:
	var key := Vector2i(cell_x, cell_y)
	if _density.has(key):
		return _density[key]
	if _density.size() >= CACHE_LIMIT:
		_density.clear()
	var centre := Vector2(cell_x + 0.5, cell_y + 0.5) * CELL_DEG
	var near := 0
	var span := Vector2(BUSY_RADIUS_NM / (60.0 * maxf(cos(deg_to_rad(centre.y)), 0.1)), BUSY_RADIUS_NM / 60.0)
	for port: PortData in PortCatalog.get_default().ports_in_rect(Rect2(centre - span, span * 2.0)):
		if GeoMath.distance_nm(port.get_geo_position(), centre) <= BUSY_RADIUS_NM:
			near += 1
	var busy := clampf(0.1 + near * 0.12, 0.0, 1.0)
	_density[key] = busy
	return busy


static func kind_name(kind: StringName) -> String:
	for k in KINDS:
		if k[0] == kind:
			return Loc.t(k[1])
	return Loc.t("Vessel")


# --- Closest point of approach -----------------------------------------------------------

## Relative motion of a target (offset_nm east/north from us, its course and
## speed) against our own course and speed: {"cpa_nm", "tcpa_h" (negative:
## already passed), "distance_nm"}. Flat local geometry, fine at radar ranges.
static func approach(offset_nm: Vector2, course: float, speed_kn: float, own_course: float, own_speed_kn: float) -> Dictionary:
	var theirs := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course))) * speed_kn
	var ours := Vector2(sin(deg_to_rad(own_course)), cos(deg_to_rad(own_course))) * own_speed_kn
	var relative := theirs - ours
	var speed2 := relative.length_squared()
	var tcpa := -offset_nm.dot(relative) / speed2 if speed2 > 1e-6 else 0.0
	var cpa := (offset_nm + relative * maxf(tcpa, 0.0)).length()
	return {"cpa_nm": cpa, "tcpa_h": tcpa, "distance_nm": offset_nm.length()}
