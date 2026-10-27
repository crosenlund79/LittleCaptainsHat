class_name WeatherDamage
extends RefCounted
## How much heavy weather wears a boat down. Pure maths: the simulation calls
## damage_between() once per evaluation point while underway and hands the
## result to GameSession, which owns the boat's condition.
##
## Rate (percent of condition per hour of exposure), from one weather sample:
##   sustained  0.06 × (wind − 28 kn)^1.6        (only above 28 kn)
##   gusts      0.2  × (gust − 45 kn)            (only above 45 kn)
##   × the boat's VesselProfile.weather_damage_factor
## So an ordinary breeze and "strong winds" (caution) do nothing; a gale costs
## a few percent an hour and a storm or squall line much more:
##   30 kn, gusts 40      0.0 %/h     (caution: survivable)
##   34 kn, gusts 46      1.3 %/h     (gale threshold)
##   40 kn, gusts 54      5.0 %/h
##   48 kn, gusts 65     11.2 %/h     (storm threshold)
##   60 kn, gusts 78     22.0 %/h
##   squall: 22 kn with gust bursts to 55 kn: 2 %/h while the bursts last
##
## Integration: the weather is sampled every SUBSTEP (60 s) of absolute game
## time, at the boat, from the last time damage was applied up to now. Gust
## bursts last 8-20 minutes, so none falls between samples, and because the
## sample times are fixed on the clock the total is the same whether the
## stretch is applied in one 8-hour sleep or in 5-minute steps.

const SUBSTEP := 60.0
const SUSTAINED_FROM_KN := 28.0
const SUSTAINED_SCALE := 0.06
const SUSTAINED_EXPONENT := 1.6
const GUST_FROM_KN := 45.0
const GUST_SCALE := 0.2


## Percent of condition lost per hour in this weather.
static func rate_per_hour(sustained_kn: float, gust_kn: float, factor := 1.0) -> float:
	var rate := 0.0
	if sustained_kn > SUSTAINED_FROM_KN:
		rate += SUSTAINED_SCALE * pow(sustained_kn - SUSTAINED_FROM_KN, SUSTAINED_EXPONENT)
	if gust_kn > GUST_FROM_KN:
		rate += GUST_SCALE * (gust_kn - GUST_FROM_KN)
	return rate * factor


## Damage (percent) for the stretch of game time (from, to] at `geo`: the sum
## over the fixed sample times k × SUBSTEP inside it.
static func damage_between(from_time: float, to_time: float, geo: Vector2, seed: int, factor := 1.0) -> float:
	if to_time <= from_time:
		return 0.0
	var model := WeatherModel.get_default()
	var total := 0.0
	var k := floorf(from_time / SUBSTEP) + 1.0
	while k * SUBSTEP <= to_time + 1e-6:
		# The quick sample: exactly sample()'s wind and gusts (Turbocharge).
		var sample := model.sample_hazard(geo, k * SUBSTEP, seed)
		total += rate_per_hour(sample[1], sample[2], factor) * SUBSTEP / 3600.0
		k += 1.0
	return total
