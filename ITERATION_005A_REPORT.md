# Iteration 005a: The Dangerous Sea (Report)

**Baseline:** Iteration 004b, commit `c57af32`, branch
`claude/determined-brahmagupta-3v95mx`.

**Engine:** Godot 4.7.2 stable, GDScript, Compatibility renderer.

**Test environment:** Linux container, Godot headless, plus Xvfb with Mesa
llvmpipe for rendered runs.

**Not tested on Windows.** Nothing in this iteration has been run on Windows
by the developer or the owner. Everything below was verified with automated
checks in the environment above and with screenshots from automated runs.

Throughout this report:
- **Implemented** means the code exists and is used by the game;
- **Tested** means an automated check covers it (suite named);
- **Visually reviewed** means a rendered screenshot was looked at;
- **Untested** is said explicitly where it applies.

## 1. Implementation summary

- **One weather model** (`WeatherModel`) is now the only source of wind and
  hazardous weather. Propulsion, ETA, warnings, sleep interruption, the chart
  overlay, the Weather tab, the HUD and the weather sounds all read it.
  *Implemented, tested (`test_weather`: "the simulation's wind query is the
  weather model"; `test_weather_ui`).*
- **The old demonstration circles are retired**: `WeatherCondition`,
  `WeatherCatalog` and `data/weather/demo_conditions.tres` are deleted.
  *Tested (`test_weather_ui`: "the old demonstration weather circles are gone").*
- **Moving, irregular severe-weather areas** (strong winds / gales) that form,
  strengthen, drift along curved tracks, change shape and dissipate.
  *Tested (`test_weather` "[areas]").*
- **Thunderstorms**: thunderstorm-risk areas, inside which storm cells form,
  live a few hours (developing → active → dissipating), blow outflow winds and
  bring smooth gust episodes; strong cells are "severe squalls".
  *Tested (`test_weather` "[storms]", "[thunderstorm]").*
- **Hazard levels** Normal / Caution / Dangerous / Severe from sustained wind
  and gusts. *Tested.*
- **Warnings** at the boat, for thunderstorms nearby, and along the course up
  to 6 h ahead, de-duplicated per event and level, escalating only when worse;
  they wake a sleeper and drop time to 1×. *Tested (`test_weather`
  "[warnings]", `test_simulation`, `test_weather_ui` "[sleep]",
  `test_gameplay_flow`).*
- **Tropical cyclones**: seasonal risk per basin and hemisphere from the game
  date, and a minimal active cyclone (track, intensification, decay, rotation
  by hemisphere). None can reach the European chart. *Tested (`test_weather`
  "[cyclones]", "[cyclone]").*
- **Determinism** across 1×, 20×, one large step, sleep, pause and save/load.
  *Tested (`test_weather` "[time]", "[pause]", "[saves]"; `restart_check`
  across two processes).*
- **Save format 6** with migration from 5. *Tested ("[migration]").*
- **Chart Weather tab and overlay** with a legend, labels, glyphs and outline
  styles, so kinds do not rely on colour. *Tested and visually reviewed.*
- **Restrained audio**: a storm-wind loop and occasional thunder on the Ambience
  bus. *Tested (plays and stops); not listened to (no audio output in the test
  environment).*
- **Documentation**: README, ARCHITECTURE, `DEV_GUIDES/WEATHER.md` (new),
  `DEV_GUIDES/AUDIO.md`, the guide index.

Nothing from Iteration 005b was implemented (§19).

## 2. Architectural changes

```
WindField (background, unchanged)  ─┐
data/weather/weather_events.json ──► WeatherModel ─► WeatherSample
                                      │                ▲
                                      └ WeatherEvent    │ Simulation.get_weather_at()
                                                         │   ├ propulsion (sustained wind)
                                                         │   ├ ETA, route_hazards()
                                                         │   ├ _assess_weather(): exposure + warnings
                                                         │ MapView overlay, WindLayer, WorldMap tab,
                                                         │ HUD, App weather audio
```

- New classes in `src/weather/`: `WeatherModel`, `WeatherEvent`,
  `WeatherSample` (extends `WindField.Sample`), `WeatherExposure`.
- New presentation classes in `src/navigation/`: `WeatherStyle` (one style table
  for map and legend) and `WeatherLegend`.
- `Simulation` keeps its single timeline and its absolute 300 s evaluation grid.
  The weather is assessed at every grid point and at departure
  (`_assess_weather`), replacing the old "warning at a progress distance" event
  boundary.
- `WindField` remains, but only as the background layer: nothing reads it except
  `WeatherModel.sample()`.
- `GameSession` gained `update_weather_exposure()` / `get_weather_exposure()`;
  `SessionState` gained `weather_model_version` and `weather_exposure`.
- Test helper `tests/helpers/weather_fixtures.gd` builds deterministic events
  for tests (`WeatherModel.fixture_events`).

## 3. Legacy weather-system retirement

- **Removed:** `src/weather/weather_condition.gd`, `src/weather/weather_catalog.gd`
  (and `.uid` files), `data/weather/demo_conditions.tres`; the map's
  `WEATHER_COLORS` circle drawing; all "encounter" code in `Simulation`.
- **Strategy:** there is no compatibility layer. The four demonstration circles
  were display-and-warning-only data with no effect on sailing; keeping them
  alongside the real model would have meant two contradicting sources.
- **Saves:** old warned ids (`strong_winds_western_baltic`, …) are cleared by the
  v5 → v6 migration, so the new weather is announced normally (§14).
- **Tests that used the old circles** now use a fixture of the new model at the
  same place (a 9 nm strong-wind area between Møn and Rügen, 26 kn), so the
  Iteration 002 acceptance scenario keeps its meaning. Adaptations are listed in
  §16.

## 4. Unified weather-data interface

```
WeatherModel.get_default().sample(geo: Vector2, time: float, seed: int, known_at := INF) -> WeatherSample
WeatherModel.get_default().active_events(time, seed, known_at := INF) -> Array[WeatherEvent]
WeatherModel.get_default().events_of_kind(time, kind, seed) / find_event(id, time, seed)
WeatherModel.get_default().cyclone_risk(geo, time) -> {risk: 0..1, basin}
Simulation.get_weather_at(geo, time := now, known_at := INF) -> WeatherSample   # with the session's seed
Simulation.get_weather_at_vessel() -> WeatherSample
Simulation.get_wind_at(geo) -> WeatherSample                                     # old name kept
Simulation.route_hazards(path, from_nm, horizon_hours) -> Array[Dictionary]
GameSession.get_weather_exposure() -> WeatherExposure
```

`WeatherSample`: `from_deg`, `speed_kn` (sustained, meteorological "from"
convention, unchanged), `gust_kn`, `background_from_deg`, `background_kn`,
`hazard` (0–3), `classification`, `event_id`, `event_kind`, `event_name`,
`thunder_possible`, `thunder_active`, `cyclone_risk`, `cyclone_basin`;
`get_label()`, `get_hazard_name()`, `to_dict()`.

Sampling is a pure function of (position, time, seed): reading never changes
anything. *Tested ("reading the weather does not change it", "a fresh model
gives identical weather").*

## 5. Wind and gust behaviour

- **Background:** the Iteration 003/004b wind field, unchanged. Away from
  events the sustained wind is exactly the old wind. *Tested ("away from weather
  events the wind is the I004b background wind").*
- **Gusts:** sustained × 1.25 in ordinary wind, up to × 1.35 inside gale areas;
  thunderstorms add gust episodes on top (below). Gusts are never below the
  sustained wind. *Tested.*
- **Propulsion uses the sustained wind only**; gusts are information (HUD,
  warnings, hazard level). This keeps the Iteration 003 hysteresis meaningful.
  *Tested ("gusts alone do not make the engine cycle").*
- **Hazard levels:** sustained 22 / 34 / 48 kn or gusts 30 / 41 / 56 kn →
  Caution / Dangerous / Severe (Beaufort 6, 8, 10). Being in a thunderstorm-risk
  area is at least Caution; the core of a severe cell is at least Dangerous.
- **Conventions:** `from_deg` is where the wind comes from; chart arrows point
  where it blows. *Tested ("[conventions]").*

## 6. Severe-weather event representation

`WeatherEvent` (`src/weather/weather_event.gd`) is plain data plus closed-form
functions of game time:

- identity and kind (`gale`, `thunder_risk`, `thunderstorm`, `cyclone`), display
  name, seed, parent (cells → risk area);
- **lifecycle:** start, lifetime, `develop_fraction` (0.25), `dissipate_fraction`
  (0.3); `stage_at()` and a smooth `life_factor()` (0 → 1 → 0);
- **track:** origin, speed, heading and turn rate; `center_at()` is the closed
  form of a constant-turn track, so positions are exact at any time;
- **size and shape:** radius (grows while developing), three harmonics with
  drifting phase give an irregular outline (radius 0.6–1.4 of nominal);
  `outline(time)` is what the chart draws, and the outline is exactly where the
  event's effect ends (normalized distance 1). *Tested ("the drawn outline is
  where its effect ends").*

**Formation** (`WeatherModel`): each zone in `weather_events.json` may form one
event per slot (12 h for gales and risk areas, 24 h for cyclones, 1 h for cells
within a risk area), decided by a generator seeded from hash(seed, kind, zone,
slot), scaled by the month's season factor. Only slots that can still hold a
living event are visited. *Tested: formation through the year, bounded counts
("at most N at once over a year"), coherent movement, no jumps, irregular and
changing outline, dissipation.*

Gale zones: North Atlantic, Bay of Biscay and Iberian Atlantic, North Sea and
Skagerrak, Baltic, Gulf of Lion (Mistral), Aegean (Meltemi); more in winter
(Meltemi in summer).

## 7. Thunderstorm lifecycle

- **Risk areas** form in five convective zones, mostly in summer. *Tested
  ("thunderstorms are a summer feature").*
- **Cells** form inside a risk area's outline (an hourly chance), radius 6–18 nm,
  life 2–5 h, drifting with the area. *Tested ("every cell forms inside a
  thunderstorm-risk area", "a cell lives a few hours").*
- **Stages:** developing (wind builds), active, dissipating (back to the
  background). *Tested ("its wind builds, peaks and is gone afterwards").*
- **Outflow:** wind blowing out of the cell, strongest at the centre and fading
  to the edge (along the cell's track at the exact centre). *Tested ("the centre
  is much worse than the edge").*
- **Gust episodes:** in 20-minute slots, a 60 % chance of an 8–20 minute sin²
  burst, so gusts rise and fall smoothly. *Tested ("gusts come in episodes",
  "each episode rises and falls smoothly").*
- **Severity:** cells with outflow + gusts ≥ 40 kn are "severe squalls"
  (Dangerous in the core); weaker cells are "thunderstorm" (Caution). Most are
  moderate. *Tested.*
- `thunder_active` is set near an active cell; thunder sounds use it.

## 8. Seasonal cyclone risk

`WeatherModel.cyclone_risk(geo, time)` returns 0–1 and the basin name: the
basin's monthly season factor (by the **game date** and the basin's hemisphere)
inside its risk area, faded over 3° at the edge. Seven basins: North Atlantic,
Eastern Pacific, Western Pacific, North Indian, South Indian, Australian, South
Pacific.

*Tested:* North Atlantic high in September and nil in February; South Indian
the reverse; the game date (not the computer's) decides; both hemispheres
present; no risk anywhere in European waters (Baltic, North Sea, Mediterranean,
Biscay). The Weather tab shows "Tropical cyclone season: … risk (basin)" when
the boat is in a risk area (*implemented; not reachable in normal play, since
all ports are in Europe*).

## 9. Active cyclone logic

- Cyclones form in a basin's genesis area in its season, persist 4–11 days,
  move along a curving track, intensify and then weaken (peak 40–130 kn), with
  a calm eye, maximum winds at the eye wall and decay outside (Rankine-like),
  turning counter-clockwise in the north and clockwise in the south.
- They are pure functions of time like every event, so they persist across
  save/load with nothing extra saved.
- The North Atlantic basin's limit ends a cyclone 12 h after it crosses 36° N
  or 36° W, so none reach the European chart. *Tested over three years of
  generated weather: "none ever reaches the European chart".*
- Categories: tropical depression, tropical storm, hurricane category 1–5
  (Saffir–Simpson limits).
- *Tested* with generated cyclones and a controlled fixture: rotation by
  hemisphere, eye-wall maximum, movement along its track, safe dissipation.
- *Visually untested:* cyclones are outside the European chart, so no rendered
  screenshot shows one. Their drawing uses the same overlay code as the other
  kinds.

## 10. Weather-to-propulsion integration

- `Simulation.evaluate_propulsion()` samples `get_weather_at_vessel()` and gives
  the controller its sustained wind. *Tested on all three boats (Starling 33,
  Halcyon 40, Petrel 36) sailing Copenhagen → Kiel through a 38 kn gale fixture:
  propulsion uses the model's wind at every evaluation, the gale reaches the
  boat, the spinnaker only on its angles, no rapid sail/engine switching, the
  voyage reaches Kiel.*
- The Iteration 003 controller, hysteresis, reassessment and spinnaker rules are
  unchanged and their existing suites pass (§16).
- The ETA (`estimate_route_seconds`) samples the model with `known_at = now`.

## 11. Warning and sleep integration

- **When:** at every evaluation point while underway (absolute 300 s grid) and
  at departure. The same points regardless of time acceleration or sleep.
- **What** (at most one new warning per point, in this order):
  1. hazardous weather at the boat ("Dangerous conditions at the boat (gale):
     wind WSW 40 kn, gusts 54 kn.");
  2. a thunderstorm within 15 nm of its edge ("Severe squalls nearby: 6 nm to
     the SW, moving E.");
  3. the nearest hazard on the course within 6 h of sailing ("Gale ahead on
     your route in about 3–4 h: wind up to 38 kn, gusts 51 kn."). Thunderstorm
     risk is worded as a risk.
- **Forecast honesty:** route hazards use `known_at = now`: existing weather is
  projected along its track, but storms that have not formed are not foreseen.
  The chart says so.
- **De-duplication:** keys `event>level` and `event>near` in the voyage's warned
  list; an event is announced again only if its level rises. *Tested ("a storm
  on the course gives a few warnings, not one per tick", "each warning is given
  once", escalation).*
- **Sleep:** a warning stops `Simulation.sleep()`; the player wakes in the cabin
  by the V-berth, the boat is where the voyage says, the game time is the
  warning's, a pause stays a pause, and the same warning does not wake again.
  *Tested (`test_weather_ui` "[sleep]", `test_life_aboard`, `test_simulation`,
  `test_gameplay_flow`).*
- **Exposure record** (`WeatherExposure`): level, since when, classification,
  event, peak sustained wind and gusts; updated at every evaluation point, reset
  on departure and arrival, saved. Recorded only, for I005b. *Tested.*

## 12. Chart and HUD changes

- **Overlay:** every active event is drawn from its real outline: fill, outline
  (solid for gales and storms, dashed for risk areas), a dotted core ring
  (gales, storms; the eye for cyclones), a glyph (wind lines, cloud, lightning
  bolt, spiral) and a label ("GALE", "THUNDERSTORM RISK", "SEVERE SQUALLS",
  "HURRICANE …") when large enough on screen. Refreshed every 5 game minutes,
  in map space (pan and zoom do not rebuild it). *Tested (shapes = model events,
  real outlines, labels, cores; pan/zoom; pause; movement over time) and
  visually reviewed.*
- **Weather tab:** wind at the boat with gusts, label, hazard level and
  cyclone-season risk; nearby thunderstorms; hazards along the course
  (12 h horizon) with level, time, distance and expected wind; the explanation
  that the forecast covers existing weather only; the legend. The tab title
  counts the hazards, e.g. "Weather (2)". *Tested and visually reviewed.*
- **HUD:** "Wind WSW 40 kn, gusts 54 · Gale" (gusts shown when they stand out,
  the label from Caution). *Tested and visually reviewed.*
- **Sound:** storm-wind loop (Ambience bus, −30 to −6 dB between 20 and 45 kn,
  10 dB quieter below deck) and thunder every 8–25 s near an active
  thunderstorm. Only aboard. *Tested (plays in a gale, stops when the wind
  drops, silent in the main menu); not listened to.*
- **Fixed on the way:** the overlay compared Unix-second times with
  `is_equal_approx`, whose relative tolerance at ~1.8 × 10⁹ s is hours, so it
  refreshed only every few game hours. It now compares exactly. *Tested ("the
  overlay follows every 5 game minutes").*
- Unchanged as required: boatyard, main menu, companion UI, sleep selector,
  guide viewer, chart controls and sidebar structure (their suites pass).

## 13. Time-step consistency

- Weather events are pure functions of (seed, time); the simulation samples at
  fixed absolute points. So the voyage, warnings and exposure are the same at
  1× (one-minute steps), 20× (large frame steps), one multi-hour `advance()`,
  sleep, and a save/load in the middle. *Tested ("[time] … gives the same
  voyage, warnings and weather exposure as 1×" for `20x`, `large`, `sleep`,
  `save`).*
- Short-lived storms cannot be skipped: every grid point is visited by every
  step size, and the route forecast samples every 2 nm.
- **Pause:** the clock, the weather and the storms stand still; they move on
  when resumed. *Tested (`test_weather` "[pause]", `test_weather_ui`
  "paused with the chart open").*

## 14. Persistence and migration

- **Save format 6.** New section `"weather": {"model_version": 1, "exposure":
  {...}}`, required on load. The weather itself is **not** saved: it is
  recomputed from `wind.seed`. No drawing geometry is saved. *Tested.*
- **v5 → v6** (`SaveManager._migrate_5_to_6`): adds the weather section with a
  fresh Normal exposure starting at the saved time; clears
  `voyage.warned_conditions` (they named the retired circles). Position,
  progress, time, vessel, companion, pause and route are untouched; the seed is
  kept so the weather continues. Older saves chain 1 → … → 6. *Tested.*
- **Across processes:** `tests/restart_check.tscn` now also checks that the
  same weather (every active event's id, centre, radius and strength, and the
  full sample at the boat) and the exposure record come back in a new process.

## 15. Files changed

Compared with `c57af32` (Iteration 004b).

**Added**
- `data/weather/weather_events.json`
- `src/weather/weather_model.gd`, `weather_event.gd`, `weather_sample.gd`,
  `weather_exposure.gd` (+ `.uid`)
- `src/navigation/weather_style.gd`, `weather_legend.gd` (+ `.uid`)
- `assets/audio/placeholder/storm_wind.wav`, `thunder.wav` (+ `.import`,
  generated by `tools/generate_placeholder_audio.py`)
- `tests/helpers/weather_fixtures.gd`, `tests/suites/test_weather.gd`,
  `tests/suites/test_weather_ui.gd` (+ `.uid`)
- `DEV_GUIDES/WEATHER.md`, `ITERATION_005A_REPORT.md`
- `docs/screenshots/70_weather_chart_copenhagen.png`, `71_weather_tab.png`,
  `72_hud_gale.png`

**Removed**
- `src/weather/weather_condition.gd`, `src/weather/weather_catalog.gd` (+ `.uid`)
- `data/weather/demo_conditions.tres`

**Modified**
- `src/core/simulation.gd` (weather assessment, warnings, route hazards, ETA),
  `src/core/game_session.gd`, `src/core/session_state.gd`
- `src/persistence/save_manager.gd` (v6, migration)
- `src/navigation/map_view.gd` (overlay), `world_map.gd` and `world_map.tscn`
  (Weather tab), `wind_layer.gd` (samples the model)
- `src/ui/hud.gd` (gusts and label), `src/app/app.gd` (weather audio)
- `tools/generate_placeholder_audio.py` (two new sounds; the others unchanged)
- Tests: `test_runner.gd`, `restart_check.gd`, `test_simulation.gd`,
  `test_sailing.gd`, `test_voyage_persistence.gd`, `test_life_aboard.gd`,
  `test_gameplay_flow.gd`, `test_dev_guides.gd`, `test_companion_art.gd`
- Docs: `README.md`, `ARCHITECTURE.md`, `DEV_GUIDES/README.md`,
  `DEV_GUIDES/AUDIO.md`
- Regenerated screenshots in `docs/screenshots/` from the rendered run.

Owner artwork (`Visuals/`) is untouched.

## 16. Actual automated test results

All runs on the final code of this iteration (Linux, Godot 4.7.2).

| Run | Result |
|---|---|
| Headless, all 19 suites (`godot --headless --path . res://tests/test_runner.tscn`) | **1480 passed, 0 failed**, exit code 0 |
| Rendered, all suites under Xvfb with screenshots | 1486 passed, 1 failed (see below) |
| `tests/restart_check.tscn`, write then read in two processes | **18/18 passed** (16 before, plus 2 new weather checks) |
| `test_weather` alone | 133 passed, 0 failed |
| `test_weather_ui` alone | 30 passed, 0 failed |
| `test_dev_guides` alone, after copying the screenshots | 55 passed, 0 failed |

The one rendered failure was `test_dev_guides`: "every link in README.md
resolves", because the README links the two new screenshots that this same
rendered run produced, and they were not yet copied into `docs/screenshots/`.
After copying, the check passes (the headless run above, and `test_dev_guides`
alone). No other check failed.

Compared with Iteration 004b (1341 headless, 1349 rendered, restart 16/16):
the new `test_weather` and `test_weather_ui` suites, the escalation and legacy
checks, and two restart checks were added. No previous test was removed; the
adaptations are listed below.

Fixed during this iteration's final runs: the gameplay-flow fixture placement
(the edited course passes the old area's spot outside its radius), the chart
overlay refresh bug (§12), and a pre-existing message-format error in
`test_companion_art`.

**Test adaptations** (only where behaviour genuinely changed):
- `test_simulation`: the strong-wind area is now a fixture of the weather model
  at the old place. The warning is checked to come about 6 h of sailing
  (30 nm at 5 kn) before the area at an evaluation point, at exactly the same
  point at 20× and when sleeping, instead of exactly 25 nm (the old 5 h
  distance rule). The old "speed is still 5 kn inside the area (no weather
  effects)" became "inside the area the wind is the area's, propulsion uses it,
  the exposure record knows".
- `test_sailing`: the warning-horizon check now checks sailing time and distance
  ahead rather than distance = hours × current speed.
- `test_voyage_persistence`: fixture, the new warned-key format
  (`test_strong_winds>1`), and an added exposure restore check.
- `test_life_aboard`, `test_gameplay_flow`: the weather that interrupts the
  sleep is a fixture forming an hour into the sleep, on the course ahead (in
  `test_gameplay_flow` placed 40 nm ahead on the actual course, since the
  waypoint-edited course passes the old spot outside a 9 nm area).
- `test_dev_guides`: the new guide and report are in its lists.
- `test_companion_art`: a pre-existing string-format error in one check message
  (an array passed to `%` without wrapping) fixed; the check itself is unchanged.

## 17. Rendered screenshot results

Rendered run under Xvfb (1920×1080, OpenGL 3 on llvmpipe). New screenshots,
looked at:

- `docs/screenshots/70_weather_chart_copenhagen.png`: chart south of
  Copenhagen with an irregular gale area on the Kiel course (glyph, core ring,
  "GALE"), a dashed thunderstorm-risk area, and a severe-squalls cell with
  outflow arrows. Labels readable; the sidebar is unchanged.
- `docs/screenshots/71_weather_tab.png`: the Weather tab with "Weather (2)",
  wind at the boat, the gale (dangerous) and the risk area along the course,
  the forecast note and the four-row legend.
- `docs/screenshots/72_hud_gale.png`: the cabin with the HUD reading
  "Wind WSW 40 kn, gusts 54 · Gale".

Existing screenshots that show weather (`16_weather_warning`,
`17_chart_reroute`, `34_chart_sidebar_weather`) now show the new model's
fixture areas.

The rendered run produced 83 screenshots; all 63 existing files in
`docs/screenshots/` were refreshed from it and the three new ones added. The
weather ones (16, 17, 34, 70–72) were looked at. In `34_chart_sidebar_weather`
the test forces one wind everywhere (30 kn), so the whole course is listed as
"Strong winds … now"; that is the test's fixture, not generated weather.
Not visually reviewed: a cyclone on the chart (none in Europe), thunder and
storm sounds (no audio output), Windows rendering.

## 18. Known limitations

- The weather is synthetic and statistical, not real meteorology or a forecast
  service. Fronts, pressure systems, rain, fog and visibility are not modelled.
- There are no waves or sea state; weather only changes the wind.
- Weather does not harm the boat or the player (I005b).
- The chart shows the weather **now** (refreshed every 5 game minutes); it does
  not animate or show a forecast. Route hazards and warnings are estimates
  along the course at the estimated speed.
- Thunderstorms that have not formed cannot be warned about in advance; a
  sleeping player is woken when one forms close enough or on the course.
- The cyclone system is minimal: no landfall effects, no extratropical
  transition, and no cyclone is ever visible on the European chart, so its
  drawing was not visually reviewed.
- Weather areas are drawn over land (they are weather, not sea areas).
- Sounds are synthetic placeholders and were not listened to in this
  environment.
- Gale and storm frequency was tuned by inspection of generated statistics and
  the rendered chart, not against climate data.
- Not run on Windows.

## 19. Deliberately excluded features

Not implemented, as required (I005b and later): hull or vessel condition,
weather damage, damage overlays, repairs, emergency rescue, rescue
teleportation to Copenhagen, money, a starting balance, rescue cost, food and
water provisions, consumption, restocking, health or survival, inventory,
shops or economy. Also not implemented: worldwide map, new start scenarios,
new boats, wave physics, mod support, human companions. The boatyard, main
menu, companion UI, sleep selector, guide viewer and core chart controls were
not redesigned. Iteration 005b was not started.

## 20. Git branch, commit and push status

- Branch: `claude/determined-brahmagupta-3v95mx`.
- Checkpoint commits: `caa3ee0` (one deterministic weather model: checkpoints
  A–C and most of D), `041419d` (weather UI tests, overlay refresh fix), and a
  final commit with the documentation, this report, screenshots, the
  escalation and restart checks.
- Pushed to `origin/claude/determined-brahmagupta-3v95mx`; the final commit
  hash is the branch head (see `git log`). No pull request was created.

## 21. Integration guidance for I005b

Use the existing model; do not add a second source of weather.

- **Local sustained wind:** `Simulation.get_weather_at_vessel().speed_kn` and
  `.from_deg` (or `Simulation.get_weather_at(geo, time)`). This is what the boat
  sails in.
- **Local gusts:** `.gust_kn` on the same `WeatherSample` (includes thunderstorm
  gust episodes).
- **Hazard severity:** `.hazard` (`WeatherModel.HAZARD_NORMAL` … `HAZARD_SEVERE`),
  `.classification` (`gale`, `squall`, `hurricane`, …) and
  `WeatherModel.wind_hazard(sustained, gust)` for custom thresholds (e.g. per
  boat in `VesselProfile`).
- **Exposure over simulated time:** `GameSession.get_weather_exposure()`
  (`level`, `since`, `duration(now)`, `peak_sustained_kn`, `peak_gust_kn`,
  `event_id`). It is updated in `Simulation._assess_weather()` at every
  evaluation point (absolute 300 s grid while underway), so anything derived
  there (damage accumulation) is independent of time acceleration and sleep.
  Hook damage in right after `GameSession.update_weather_exposure(here)`, and
  save it in its own `SessionState` section.
- **Active events:** `WeatherModel.get_default().active_events(time, seed)`,
  `events_of_kind(time, kind, seed)`, `find_event(id, time, seed)`;
  `WeatherEvent.describe(time)` for a plain summary. `Simulation.weather_warning`
  carries `event_id`, `hazard`, `classification`, `hours`, `distance_nm`.
- **Deterministic storms in tests:** `WeatherFixtures.use([...])` with
  `WeatherFixtures.gale(...)`, `thunderstorm(...)`, `thunder_risk(...)` or
  `cyclone(...)` (place, size, strength, start and lifetime chosen by the test;
  generated weather off), then `WeatherFixtures.clear()`. For generated weather,
  a fixed `wind.seed` reproduces every event exactly.
