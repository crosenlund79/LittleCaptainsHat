extends SceneTree
## Iteration 18: how much the wind changes over the time navigator's steps.
## (sample_wind returns Vector2(from_deg, speed_kn).) Samples the authoritative WeatherModel on a grid over several sailing
## areas and many start times, and reports the mean and 90th-percentile
## change in the wind vector (knots) and direction (degrees, where above 4 kn)
## after 30 min, 1 h, 2 h, 3 h and 6 h - both the actual wind and the
## forecast as seen from Now (only weather already formed).
## Run: godot --headless --path . -s res://tools/weather/measure_wind_variation.gd

const AREAS := [Vector2(11.0, 56.0), Vector2(-5.0, 47.0), Vector2(-16.0, 28.0), Vector2(-40.0, 20.0), Vector2(-62.0, 14.0)]
const OFFSETS := [1800.0, 3600.0, 7200.0, 10800.0, 21600.0]
const START := 1777593600.0
const BAND_LIMITS := [5.0, 10.0, 15.0, 20.0, 25.0]


func _init() -> void:
	var model := WeatherModel.get_default()
	for known_mode in ["actual", "forecast"]:
		print("== %s ==" % known_mode)
		for offset: float in OFFSETS:
			var diffs: Array[float] = []
			var turns: Array[float] = []
			var speeds: Array[float] = []
			var band_changes := 0
			for area: Vector2 in AREAS:
				for start_i in 40:
					var now := START + start_i * 5.3 * 3600.0
					for gx in 5:
						for gy in 5:
							var geo := area + Vector2(gx * 1.5, gy * 1.5)
							var known := INF if known_mode == "actual" else now
							var a := model.sample_wind(geo, now, 7, known)
							var b := model.sample_wind(geo, now + offset, 7, known)
							var va := Vector2.from_angle(deg_to_rad(a.x)) * a.y
							var vb := Vector2.from_angle(deg_to_rad(b.x)) * b.y
							diffs.append(va.distance_to(vb))
							speeds.append(absf(a.y - b.y))
							if _band(a.y) != _band(b.y):
								band_changes += 1
							if a.y > 4.0 and b.y > 4.0:
								turns.append(absf(angle_difference(deg_to_rad(a.x), deg_to_rad(b.x))) * 180.0 / PI)
			diffs.sort()
			turns.sort()
			speeds.sort()
			var smean := 0.0
			for d in speeds:
				smean += d
			smean /= speeds.size()
			var mean := 0.0
			for d in diffs:
				mean += d
			mean /= diffs.size()
			var tmean := 0.0
			for d in turns:
				tmean += d
			tmean /= maxf(turns.size(), 1)
			print("  +%4.1f h: vector change mean %.2f kn, p90 %.2f kn; speed mean %.2f kn, p90 %.2f kn; direction mean %.1f°, p90 %.1f° colour band changes %.0f%% (n=%d)" % [offset / 3600.0, mean, diffs[int(diffs.size() * 0.9)], smean, speeds[int(speeds.size() * 0.9)], tmean, turns[int(turns.size() * 0.9)] if not turns.is_empty() else 0.0, 100.0 * band_changes / diffs.size(), diffs.size()])
	quit()


func _band(speed: float) -> int:
	# The overlay's colour bands (WindLayer.BANDS upper bounds, in knots).
	for i in BAND_LIMITS.size():
		if speed < BAND_LIMITS[i]:
			return i
	return BAND_LIMITS.size()
