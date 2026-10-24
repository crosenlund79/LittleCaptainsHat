# Weather: tuning, styling and testing

Next Harbor has **one** weather model. Everything that needs wind or weather
asks it: the boat's speed and sail/engine choice, the ETA, the chart overlay,
the Weather tab, the HUD, the warnings, sleep interruptions and the storm
sounds. Never add a second source of wind or hazards; extend this one.

- Code: `src/weather/weather_model.gd` (the query), `src/weather/weather_event.gd`
  (one storm or area), `src/weather/weather_sample.gd` (the answer),
  `src/weather/weather_exposure.gd` (how long the boat has been in its weather).
- Data: `data/weather/weather_events.json` (where and when weather forms).
- Background wind: `src/weather/wind_field.gd` with `data/weather/wind_climate.json`.
- How it fits together: the *Weather model* section of
  [../ARCHITECTURE.md](../ARCHITECTURE.md).

## How weather is made (in one paragraph)

The sea is divided into zones (`gale_zones`, `convective_zones`) and tropical
cyclone basins (`cyclone_basins`). Every 12 hours (24 h for cyclones) each zone
"rolls a die" seeded with the game's wind seed, the zone and the time slot. If
it forms an event, that event's track, size, strength and lifetime are fixed at
that moment, and from then on everything about it is a formula of game time.
So the same seed always gives the same weather, in any order and at any speed,
and loading a save brings the same storms back.

## Tune where and how often weather forms

Edit `data/weather/weather_events.json`. Each gale zone looks like this:

```
{"name": "Bay of Biscay and Iberian Atlantic", "area": [-20, -3, 40, 49], "per_day": 0.3,
 "season": [1.5, 1.4, 1.2, 0.9, 0.6, 0.4, 0.35, 0.4, 0.7, 1.1, 1.4, 1.5],
 "heading": [40, 90], "speed_kn": [12, 24], "radius_nm": [100, 180],
 "peak_kn": [24, 40], "life_h": [20, 40], "flow_from": [200, 270]}
```

| Field | Meaning |
|---|---|
| `area` | where events form: west, east, south, north (degrees) |
| `per_day` | how many form per day on average, before the season factor |
| `season` | a factor per month, January first (1.0 = normal) |
| `heading`, `speed_kn` | which way and how fast the event drifts (ranges) |
| `radius_nm`, `peak_kn`, `life_h` | size, strongest sustained wind and lifetime (ranges) |
| `flow_from` | the direction the wind blows from inside the area |

`convective_zones` have the same shape; their events are thunderstorm-risk
areas. Thunderstorm cells inside them are set in the `convective` block
(`cell_every_h`, `cell_chance`, `cell_radius_nm`, `cell_life_h`,
`cell_peak_kn`, `cell_gust_kn`, `cell_severity_skew`). Cyclone strength, size
and lifetime ranges are in the `cyclone` block, their names in `cyclone_names`.
Cyclone basins add a `genesis` area, a larger
`risk_area` (for the "cyclone season" readout), a `hemisphere`, a
`turn_deg_per_day` and an optional `limit` that ends cyclones before they could
reach Europe.

After changing the file:
1. Run the game or the tests; the file is read on start.
2. If existing saves would now see different weather, increase `model_version`
   in the file (saves record it).
3. Run `test_weather` (below). It checks, among other things, that no cyclone
   ever reaches the European chart, that thunderstorms are mostly a summer
   feature and that cyclones form in their basins' seasons.

## Tune hazard levels and warnings

| What | Where |
|---|---|
| Wind and gust limits for Caution / Dangerous / Severe | `SUSTAINED_LIMITS`, `GUST_LIMITS` in `src/weather/weather_model.gd` |
| When a thunderstorm counts as "severe squalls" | `SEVERE_STORM_KN` in the same file |
| How far ahead warnings look (hours of sailing) | `WARNING_HORIZON_HOURS` in `src/core/simulation.gd` |
| How far ahead the Weather tab looks | `DISPLAY_HORIZON_HOURS` in the same file |
| When a nearby thunderstorm is announced | `NEARBY_STORM_NM` in the same file |

## Change how weather looks on the chart

All styling is in one table, `STYLES` in `src/navigation/weather_style.gd`:
colour, fill opacity, outline style (`solid`, `dashed`, `dotted`), whether a
core ring is drawn, and the label. The map overlay and the legend in the
Weather tab both use it, so they always match.

Keep kinds distinguishable **without colour**: each kind should differ in at
least its label and glyph, and preferably in its outline style. The glyphs
(wind lines, cloud, lightning bolt, spiral) are drawn in `draw_glyph()` in the
same file; they are vector drawings, so they stay sharp at any zoom.

## Change the storm sounds

See [AUDIO.md](AUDIO.md): `storm_wind.wav` and `thunder.wav` in
`assets/audio/placeholder/`.

## Test weather by hand

The generated weather is random but repeatable. For a known situation, tests
use **fixtures**: hand-made events added to the model.

```
WeatherFixtures.use([
    WeatherFixtures.gale("my_gale", Vector2(12.2, 54.8), 10.0, 38.0, start_time, 24.0),
    WeatherFixtures.thunderstorm("my_storm", Vector2(13.3, 55.2), 7.0, 22.0, 20.0, start_time, 4.0),
])
# ... play or test ...
WeatherFixtures.clear()
```

`tests/helpers/weather_fixtures.gd` builds gales, thunderstorm-risk areas,
thunderstorms and cyclones. With `use(events)` only these events exist; with
`use(events, true)` they are added to the generated weather. The test runner's
calm-wind fixture (`use_calm_wind()`) also switches the generated weather off.

## Run the weather tests

```
godot --headless --path . res://tests/test_runner.tscn -- --only=test_weather
godot --headless --path . res://tests/test_runner.tscn -- --only=test_weather_ui
```

`test_weather` covers the model, warnings and determinism; `test_weather_ui`
covers the chart, Weather tab, HUD, sound and sleep. With a display, add
`--screenshots=<folder>` to get the weather screenshots (`70_…` to `72_…`).

## Common mistakes

- **Comparing game times with `is_equal_approx`.** Game time is Unix seconds
  (about 1.8 billion); `is_equal_approx` then tolerates hours. Compare times
  with `==` or with an explicit tolerance in seconds.
- **Sampling `WindField` directly.** It is only the background; it does not
  know about gales or storms. Use `Simulation.get_weather_at()` or
  `WeatherModel.sample()`.
- **Changing weather state while reading it.** Sampling must never change
  anything. New weather data belongs in the JSON or in event formulas, not in
  counters updated by queries.
