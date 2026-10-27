class_name WeatherEvent
extends RefCounted
## One hazardous weather event: a strong-wind (gale) area, an area of
## thunderstorm risk, a single thunderstorm cell, or a tropical cyclone.
##
## An event is fully described by a few numbers fixed when it forms (identity,
## start time, lifetime, origin, track, size, strength, shape). Everything
## else (where it is, how strong, its outline, its gusts) is a pure function
## of game time, so asking never changes the event, and the same question gives
## the same answer whatever the frame rate, time acceleration or size of the
## simulation step, and after loading a save. See WeatherModel for where events
## come from and how their effects combine.
##
## Units: positions Vector2(longitude, latitude) in degrees; distances in
## nautical miles (nm); speeds in knots; times in game seconds (UTC); headings
## in degrees, 0 = north, clockwise (direction of travel); wind directions in
## the meteorological convention (where the wind blows FROM).

const KIND_GALE := &"gale"
const KIND_THUNDER_RISK := &"thunder_risk"
const KIND_THUNDERSTORM := &"thunderstorm"
const KIND_CYCLONE := &"cyclone"

const STAGE_NONE := &"none"            # not formed yet, or gone
const STAGE_DEVELOPING := &"developing"
const STAGE_ACTIVE := &"active"         # mature
const STAGE_DISSIPATING := &"dissipating"

## Default fractions of the lifetime spent developing and dissipating.
const DEVELOP_FRACTION := 0.25
const DISSIPATE_FRACTION := 0.3
## Gust episodes (thunderstorms): one chance per slot, each a smooth rise and
## fall lasting GUST_MIN..GUST_MAX seconds; several can follow each other.
const GUST_SLOT := 1200.0
const GUST_MIN := 480.0
const GUST_MAX := 1200.0
const GUST_CHANCE := 0.6
const NM_PER_DEGREE := 60.0

## Stable identity (also used for warnings and in saves): kind, area, slot.
var id: StringName
var kind: StringName
## Shown to the player: "Strong winds", "Thunderstorm", "Tropical storm Alba".
## Shown in the current language (I019); storms keep their given names.
var display_name := "":
	get:
		return Loc.t(display_name)
var start_time := 0.0
var lifetime := 3600.0
## Centre at start_time.
var origin := Vector2.ZERO
## Track: speed, heading at start, and how fast the heading turns
## (degrees per day; positive = to the right).
var speed_kn := 0.0
var heading_deg := 0.0
var turn_deg_per_day := 0.0
## Size at maturity (gale/cell/risk: outer edge; cyclone: radius of gales).
var radius_nm := 50.0
## Strength at maturity: gale = sustained wind at the core; thunderstorm =
## wind added by the storm's outflow at its core; cyclone = maximum sustained
## wind. Knots.
var peak_kn := 0.0
## Thunderstorm: extra wind in gusts at the core at the height of an episode.
var gust_kn := 0.0
## Gale: the direction its strong wind blows from.
var flow_from_deg := 0.0
## Cyclone: 1 northern hemisphere (counter-clockwise), -1 southern.
var hemisphere := 1
## Cyclone: radius of the strongest winds around the eye.
var eye_radius_nm := 25.0
## Outline irregularity: amplitude and phase of harmonics 2, 3 and 4 of the
## radius around the centre, and how fast the phases drift (radians per hour).
var shape := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var shape_drift := 0.0
## Fractions of the lifetime spent developing and dissipating.
var develop_fraction := DEVELOP_FRACTION
var dissipate_fraction := DISSIPATE_FRACTION
## Seed for the event's own variation (gusts).
var seed := 0
## The thunderstorm-risk area a cell belongs to (cells only).
var parent_id: StringName


func end_time() -> float:
	return start_time + lifetime


func is_active_at(time: float) -> bool:
	return time >= start_time and time < start_time + lifetime


## 0 at formation, 1 at the end.
func age_fraction(time: float) -> float:
	return clampf((time - start_time) / lifetime, 0.0, 1.0)


func stage_at(time: float) -> StringName:
	if not is_active_at(time):
		return STAGE_NONE
	var a := age_fraction(time)
	if a < develop_fraction:
		return STAGE_DEVELOPING
	if a > 1.0 - dissipate_fraction:
		return STAGE_DISSIPATING
	return STAGE_ACTIVE


## Strength through the lifecycle: rises smoothly while developing, 1 while
## mature, falls smoothly while dissipating; 0 outside the lifetime.
func life_factor(time: float) -> float:
	if not is_active_at(time):
		return 0.0
	var a := age_fraction(time)
	return smoothstep(0.0, develop_fraction, a) * (1.0 - smoothstep(1.0 - dissipate_fraction, 1.0, a))


## Where the centre is at `time` (along a gently curving track).
func center_at(time: float) -> Vector2:
	var hours := clampf(time - start_time, 0.0, lifetime) / 3600.0
	var h0 := deg_to_rad(heading_deg)
	var turn := deg_to_rad(turn_deg_per_day) / 24.0  # radians per hour
	var east := 0.0
	var north := 0.0
	if absf(turn) < 1e-6:
		east = speed_kn * hours * sin(h0)
		north = speed_kn * hours * cos(h0)
	else:
		east = speed_kn / turn * (cos(h0) - cos(h0 + turn * hours))
		north = speed_kn / turn * (sin(h0 + turn * hours) - sin(h0))
	var lat := origin.y + north / NM_PER_DEGREE
	var mid_lat := deg_to_rad((origin.y + lat) / 2.0)
	return Vector2(origin.x + east / (NM_PER_DEGREE * maxf(cos(mid_lat), 0.05)), lat)


## Heading of travel at `time` (degrees).
func heading_at(time: float) -> float:
	var hours := clampf(time - start_time, 0.0, lifetime) / 3600.0
	return fposmod(heading_deg + turn_deg_per_day * hours / 24.0, 360.0)


## Size at `time`: grows while developing, spreads a little while dissipating.
func radius_at(time: float) -> float:
	var a := age_fraction(time)
	var grow := 0.55 + 0.45 * smoothstep(0.0, develop_fraction, a)
	var spread := 1.0 + 0.3 * smoothstep(1.0 - dissipate_fraction, 1.0, a)
	return radius_nm * grow * spread


## Offset from the centre to `geo` in nm: Vector2(east, north).
func offset_nm(geo: Vector2, time: float) -> Vector2:
	var center := center_at(time)
	var dx := wrapf(geo.x - center.x, -180.0, 180.0)
	return Vector2(dx * NM_PER_DEGREE * cos(deg_to_rad((geo.y + center.y) / 2.0)), (geo.y - center.y) * NM_PER_DEGREE)


## The outline radius in direction `bearing` (radians from north) at `time`.
func outline_radius(bearing: float, time: float) -> float:
	var hours := (time - start_time) / 3600.0
	var factor := 1.0
	for k in 3:
		factor += shape[k * 2] * sin((k + 2) * bearing + shape[k * 2 + 1] + shape_drift * hours * (k + 1))
	return outer_radius(time) * clampf(factor, 0.6, 1.4)


## The radius of the event's area at `time` before irregularity (cyclones: the
## radius of gale-force winds, which shrinks as it weakens).
func outer_radius(time: float) -> float:
	if kind != KIND_CYCLONE:
		return radius_at(time)
	var vmax := peak_kn * life_factor(time)
	if vmax <= 34.0:
		return maxf(eye_radius_nm * 1.5, radius_nm * 0.25)
	return clampf(eye_radius_nm * pow(vmax / 34.0, 1.0 / 0.55), eye_radius_nm * 1.5, radius_nm * 1.4)


## Distance from the centre in units of the (irregular) outline: 0 at the
## centre, 1 on the outline.
func normalized_distance(geo: Vector2, time: float) -> float:
	var offset := offset_nm(geo, time)
	var distance := offset.length()
	if distance < 1e-6:
		return 0.0
	return distance / outline_radius(atan2(offset.x, offset.y), time)


## The outline at `time` as geographic points (for the chart), `count` points.
func outline(time: float, count := 40) -> PackedVector2Array:
	var center := center_at(time)
	var points := PackedVector2Array()
	var lat_scale := maxf(cos(deg_to_rad(center.y)), 0.05)
	for i in count:
		var bearing := TAU * i / count
		var r := outline_radius(bearing, time)
		points.append(center + Vector2(sin(bearing) * r / (NM_PER_DEGREE * lat_scale), cos(bearing) * r / NM_PER_DEGREE))
	return points


## Outline scaled by `fraction` of the radius (e.g. the core ring).
func ring(time: float, fraction: float, count := 40) -> PackedVector2Array:
	var center := center_at(time)
	var points := PackedVector2Array()
	var lat_scale := maxf(cos(deg_to_rad(center.y)), 0.05)
	for i in count:
		var bearing := TAU * i / count
		var r := outline_radius(bearing, time) * fraction
		points.append(center + Vector2(sin(bearing) * r / (NM_PER_DEGREE * lat_scale), cos(bearing) * r / NM_PER_DEGREE))
	return points


## How far the event can affect anything (nm), for quick rejection.
func reach_nm() -> float:
	match kind:
		KIND_CYCLONE:
			return radius_nm * 2.4
		_:
			return radius_nm * 1.3 * 1.4  # largest spread × largest irregularity


## Thunderstorm gusts at `time`, 0..1: a train of smooth episodes (rise to a
## peak and fall back), several of which may follow each other. A pure
## function of time and the event's seed: never a jump between frames.
func gust_envelope(time: float) -> float:
	var value := 0.0
	var first := floori((time - GUST_MAX) / GUST_SLOT)
	var last := floori(time / GUST_SLOT)
	for slot in range(first, last + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|gust|%d" % [seed, slot])
		if rng.randf() > GUST_CHANCE:
			continue
		var begin := slot * GUST_SLOT + rng.randf() * GUST_SLOT
		var duration := rng.randf_range(GUST_MIN, GUST_MAX)
		var amplitude := rng.randf_range(0.5, 1.0)
		if time >= begin and time < begin + duration:
			value = maxf(value, amplitude * pow(sin(PI * (time - begin) / duration), 2.0))
	return value


## Tropical cyclone wind at `geo`: [speed_kn, from_deg]. A simplified vortex:
## rising to the maximum at the eye wall, falling off outside, turning
## counter-clockwise in the northern hemisphere (clockwise in the southern),
## spiralling slightly inwards.
func cyclone_wind(geo: Vector2, time: float) -> Array:
	var vmax := peak_kn * life_factor(time)
	var offset := offset_nm(geo, time)
	var r := offset.length()
	if vmax <= 0.0 or r > radius_nm * 2.4:
		return [0.0, 0.0]
	var speed := 0.0
	if r < eye_radius_nm:
		speed = vmax * r / eye_radius_nm
	else:
		speed = vmax * pow(eye_radius_nm / r, 0.55)
	speed *= 1.0 - smoothstep(radius_nm * 1.3, radius_nm * 2.4, r)
	if r < 1e-3:
		return [0.0, 0.0]
	var out := offset / r  # unit vector away from the centre (east, north)
	var tangent := Vector2(-out.y, out.x) * hemisphere  # counter-clockwise (N hemisphere)
	var to := tangent * cos(deg_to_rad(20.0)) - out * sin(deg_to_rad(20.0))  # 20° inflow
	var to_deg := rad_to_deg(atan2(to.x, to.y))
	return [speed, fposmod(to_deg + 180.0, 360.0)]


## Saffir-Simpson-like label for the cyclone at `time` (presentation only).
func cyclone_category(time: float) -> String:
	var v := peak_kn * life_factor(time)
	if v < 34.0:
		return Loc.t("Tropical depression")
	if v < 64.0:
		return Loc.t("Tropical storm")
	var category := 1
	for limit in [83.0, 96.0, 113.0, 137.0]:
		if v >= limit:
			category += 1
	return Loc.t("Hurricane (category %d)") % category


## Plain data for debugging and tests.
func describe(time: float) -> Dictionary:
	return {"id": String(id), "kind": String(kind), "name": display_name, "stage": String(stage_at(time)),
		"center": center_at(time), "radius_nm": outer_radius(time), "strength": life_factor(time)}
