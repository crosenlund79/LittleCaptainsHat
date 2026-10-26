class_name Daylight
extends RefCounted
## Day and night (Iteration 17): where the sun is for the boat, from the game
## clock (UTC) and the boat's position. A simple, documented approximation,
## no astronomy library:
## - local solar time = UTC + longitude / 15 hours (so sailing across the
##   Pacific the sun keeps rising in the morning wherever the boat is);
## - solar declination = -23.44° × cos(2π (day of year + 10) / 365);
## - elevation = asin(sin φ sin δ + cos φ cos δ cos h), h the hour angle.
## It gives believable dawns and dusks, long summer evenings in the north and
## the midnight sun above the Arctic Circle in June. No moon, no time zones.
##
## Phases by sun elevation: night below -6° (past civil twilight), dawn and
## dusk between -6° and +6° (morning or evening), day above.

const NIGHT := &"night"
const DAWN := &"dawn"
const DAY := &"day"
const DUSK := &"dusk"
## Unix time of 2000-01-01 00:00 UTC (day-of-year reference).
const EPOCH_2000 := 946684800.0
const TROPICAL_YEAR_DAYS := 365.2422

## Outside light by sun elevation (degrees): [elevation, colour]. Moonless
## night is a deep blue, twilight a dusky violet, sunrise and sunset warm.
const OUTSIDE: Array = [
	[-18.0, Color(0.26, 0.31, 0.47)],
	[-6.0, Color(0.36, 0.40, 0.57)],
	[-1.0, Color(0.66, 0.58, 0.66)],
	[3.0, Color(0.98, 0.78, 0.62)],
	[9.0, Color(1.0, 0.92, 0.80)],
	[18.0, Color(1.0, 1.0, 1.0)],
]


static func local_solar_hours(longitude: float, unix_time: float) -> float:
	return fposmod(fposmod(unix_time, 86400.0) / 3600.0 + longitude / 15.0, 24.0)


static func day_of_year(unix_time: float) -> float:
	return fposmod((unix_time - EPOCH_2000) / 86400.0, TROPICAL_YEAR_DAYS)


## The sun's elevation above the horizon (degrees) at `geo` (lon, lat).
static func sun_elevation(geo: Vector2, unix_time: float) -> float:
	var declination := deg_to_rad(-23.44 * cos(TAU * (day_of_year(unix_time) + 10.0) / 365.0))
	var hour_angle := deg_to_rad((local_solar_hours(geo.x, unix_time) - 12.0) * 15.0)
	var latitude := deg_to_rad(clampf(geo.y, -89.9, 89.9))
	var s := sin(latitude) * sin(declination) + cos(latitude) * cos(declination) * cos(hour_angle)
	return rad_to_deg(asin(clampf(s, -1.0, 1.0)))


static func phase(geo: Vector2, unix_time: float) -> StringName:
	var elevation := sun_elevation(geo, unix_time)
	if elevation < -6.0:
		return NIGHT
	if elevation > 6.0:
		return DAY
	return DAWN if local_solar_hours(geo.x, unix_time) < 12.0 else DUSK


## How much daylight there is, 0 (night) .. 1 (full day), smooth through twilight.
static func daylight(elevation: float) -> float:
	return smoothstep(-8.0, 10.0, elevation)


## The colour of the light outside for a sun elevation, dimmed and greyed by
## an overcast sky (0 clear .. 1 stormy).
static func outside_colour(elevation: float, overcast := 0.0) -> Color:
	var colour: Color = OUTSIDE[0][1]
	for i in range(1, OUTSIDE.size()):
		var a: Array = OUTSIDE[i - 1]
		var b: Array = OUTSIDE[i]
		if elevation <= b[0]:
			colour = (a[1] as Color).lerp(b[1], clampf((elevation - a[0]) / (b[0] - a[0]), 0.0, 1.0))
			break
		colour = b[1]
	var grey := Color(colour.get_luminance(), colour.get_luminance(), colour.get_luminance())
	return colour.lerp(grey, overcast * 0.5) * (1.0 - overcast * 0.22)


## The base light in the cabin (before its lamps): daylight through the
## hatches and ports by day, dim and a little warm at night, so the lamps'
## pools stand out without the corners going black.
static func inside_colour(elevation: float, overcast := 0.0) -> Color:
	var day := daylight(elevation) * (1.0 - overcast * 0.35)
	return Color(0.42, 0.39, 0.45).lerp(Color(0.94, 0.92, 0.88), day)
