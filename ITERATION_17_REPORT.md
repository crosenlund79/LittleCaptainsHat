# Iteration 17: Let There Be Light

Lighting, atmosphere, three navigation views and the I016 findings. Version
**0.104a**, save format **12** (unchanged). Verified on Linux only; **Windows
acceptance is pending the Captain's own test** (`WINDOWS_ACCEPTANCE_17.md`).

The requirement-by-requirement status, with evidence and limitations, is in
`ITERATION_17_REQUIREMENTS.md`. The assignment is kept verbatim in
`ITERATION_17_ASSIGNMENT.md`.

## 1. Starting repository state

- Repository `crosenlund79/LittleCaptainsHat`, branch
  `claude/friendly-fermat-dey23f` (the only one touched; the archived Next
  Harbor repository was not opened).
- Baseline: commit `e0bcb07` (Iteration 16, 0.103a, "Shipyard Efficiency
  report"), clean working tree. The baseline suites passed, apart from one
  pre-existing intermittent failure in `test_gameplay_flow` (an exact
  comparison of round-tripped floating-point values) that also fails about one
  run in four on the untouched I016 code; the check now compares with a 1e-9
  relative tolerance, which is the same check minus the noise (section 33).
- Captain-owned artwork was not modified (the fender stowage works on a
  runtime copy of the deck texture; the art files' checksums are tested).
  No force-push, reset or history rewrite; every checkpoint is a normal commit.

## 2. Final game version

**0.104a** (`GameVersion.DISPLAY`; `MACHINE` 0.104.1;
`project.godot` `application/config/version`). A feature milestone after
0.103a, per the version policy.

## 3. Save format

**Format 12, unchanged.** Nothing new needs saving:

- the time of day is derived from the game clock and the boat's longitude;
- the weather is a pure function of position, time and the world seed, so a
  load reproduces it exactly (section 29);
- the quicksave is an ordinary format-12 save in its own file
  (`quicksave.json`, slot 9), separate from the manual slots;
- the captain's place aboard and the area were already saved; loading now
  validates that place against the boat (section 29).

Older saves load unchanged (`test_save_manager`, `test_voyage_persistence`,
and the two-process restart check).

## 4. Commit and checkpoint list

| Checkpoint | Commit | Time (UTC) |
|---|---|---|
| Baseline (I016) | `e0bcb07` | |
| A: world chart wrap fix, coverage test, benchmark baseline | `48c520e` | 03:42 |
| B: cached wind snapshots, wind-only query, time navigator | `307afa7` | 03:56 |
| D: deck follows the heading, safe reloads underway, F5/F9 | `1b520c1` | 04:15 |
| C: Dreamer's Map, voyage daydreams, regional working chart | `35e2625` | 04:34 |
| G: sailing panel, chartplotter, course-change pulse, action wheel | `ba29e5c` | 04:45 |
| E: day and night, cabin lamps, harbour lights, soft shadows | `d76193c` | 04:58 |
| F: wind, water, rain, lightning and thunder; muffled below | `f7b95cf` | 05:05 |
| H: overhead rig, fenders, facilities preview, harbours by country, docking | `5c5573b` | 05:23 |
| I: final verification, screenshots, benchmarks, documentation, 0.104a | see section 40 | |

D was done before C because the visual-turn and save-underway defects were
gameplay bugs the Captain had reported; C, G, E, F and H then followed.

## I016 Windows Findings — Chart Rendering and Wind Architecture

### 5. World-chart rendering defect: root cause

The world chart draws three copies of the world (west, main, east) so the
Date Line wraps. In I016 the west and east copies only **contained land within
40° of the ±180° seam**; the rest of each copy was left empty to save draw
calls. Panning west or east by more than a fraction of a world width brought
those empty parts of a side copy into view, so Australia, Asia or the Americas
showed **rectangular blocks of empty sea** or appeared shifted, and the
effect grew with each turn of the globe. The fix: all three copies share the
same land tile set (the same textures and meshes, drawn at three offsets), so
any longitude of any copy is complete; the camera is still wrapped into the
main copy's range so it never drifts.

`tests/suites/test_world_chart_render.gd` (new) renders the chart and sweeps
2.2 full turns west and east, at world and regional zooms over Australia, New
Zealand and the Pacific, checks for land where the land raster says land is,
and picks harbours after long pans. It **fails on the I016 code** and passes
now.

### 6. Before/after chart screenshots

`docs/screenshots/iteration17/32_world_chart_before_after.png`: the same view
after panning west and east, I016 code (left: blocks of empty sea over
Australia/Asia) and I017 (right: complete). Also 03 (Australia and the Pacific
after 26 pans) and 04 (the Date Line).

### 7. Weather architecture findings

The I016 note that "the whole world's wind is calculated" was audited:

- **Sailing weather was already local and on demand.** `WeatherModel.sample`
  is a point query at the boat's position and time; nothing computes a world
  grid. The weather events (systems, fronts, thunderstorm cells) are listed
  per 15-minute bucket, about **10 events worldwide**, costing **0.5 ms cold
  and 2 µs warm**; each sample skips events whose reach box does not contain
  it (about 0.38 events checked per sample near Denmark). No optimization of
  the sailing weather is claimed, because none was needed.
- **The chart's wind overlay was the cost.** It re-sampled the whole visible
  lattice every 10 game minutes in a single frame: **1051 ms** for the
  Denmark region and **158 ms** for the whole world (headless), the hitches
  the Captain saw at 20× time.
- Three uses were separated: authoritative sailing weather
  (`WeatherModel.sample`), forecast and route checks (the same model with a
  "known at" time), and chart visualization (`WeatherModel.sample_wind`, a
  wind-only query sharing `_compose()` with `sample()`, so the arrows are the
  exact wind the boat sails in).

### 8. Local and on-demand computation

- Sailing samples only at the boat, per simulation step (about 6,500 samples
  per sailed day, headless benchmark).
- Long Passage samples along the travelled path in the same steps; the
  existing equivalence test (12 h/s against twenty-minute steps: same
  arrival, miles, worst weather and wear) still passes.
- Passage Readiness consults the forecast only along the route and only as far
  as the forecast reaches (`FORECAST_HOURS`); the sailing panel samples one
  point on the next leg.
- Closing the chart stops all chart wind work; the overlay runs only while it
  is shown (`test_wind_overlay [close]`).

### 9. Wind performance before and after

Headless, the same machine and benchmark (`tests/benchmark_17.gd`;
`docs/benchmarks/iteration17_before_*.json`, `…_checkpointB_*.json`,
`…_after_*.json`). Measured:

| Measure (headless) | Before (I016) | After Checkpoint B | Final |
|---|---|---|---|
| Forced full wind re-sample, Denmark region | 1051 ms | 36 ms | 36 ms |
| Forced full wind re-sample, coastal | 1178 ms | 63 ms | 66 ms |
| Forced full wind re-sample, continental | 493 ms | 31 ms | 33 ms |
| Forced full wind re-sample, whole world | 158 ms | 7 ms (no wind drawn) | 7 ms (no wind drawn) |
| Chart reopen (mean of 8) | ~471 ms | ~199 ms | ~205 ms |
| Chart first open | 2209 ms | 1802 ms | 2019 ms |
| Pan with wind on, Denmark region, ms/frame | 11.3 | 7.1 | 6.9 |
| Sailing simulation, ms per sailed day | 499 | 481 | 514 (runs vary 514–534) |

In play the re-sample is not done in one frame at all: it is spread over
frames within a **3 ms budget**, so the forced figure is the worst case. The
rendered run uses software OpenGL (llvmpipe) under Xvfb; its absolute frame
times (40–100 ms/frame for everything, wind on or off) measure the software
renderer more than the game, so only the relative differences are reported
(section 36).

### 10. Snapshot caching design

`src/navigation/wind_layer.gd`:

- a **snapshot** is the model's wind at one time, on the half-hour
  (`SNAPSHOT_STEP` 1800 s); up to 10 snapshots are kept;
- each snapshot is filled in **8×8 lattice chunks**, sampled lazily for the
  chunks in view, within 3 ms per frame (the arrows appear within a moment);
  at most 600 chunks are kept;
- a **static land-class cache** (sea / coast / inland per lattice point, up to
  8000 chunks) means land is never sampled and arrows are only on water;
- small pans reuse every chunk already sampled; standing still samples
  nothing; at 20× the NOW snapshot follows the clock at most once a real
  second and only when the half-hour changes.

### 11. Adaptive wind thresholds

Measured on the benchmark views: the lattice steps by half-octaves of 8 map
units, chosen per zoom band so no more than **1500 points** are in view. Below
**9 pixels per degree** (the whole-world view) the detail is hidden and the
legend says **"Zoom in to see wind details."**; it comes back above **11
px/°** (hysteresis, so it does not flicker at the edge).

### 12. Wind time-preview controls

On the working chart: **◀ 30 min / Now / 30 min ▶**, up to two hours back or
ahead in 30-minute steps. Labels: **NOW**, **PAST MODEL SNAPSHOT**,
**FORECAST** (forecasts add "Estimated conditions. Actual wind may differ.").
Forecast snapshots use "known at now", so they are what the model forecasts,
not the future truth. Previewing is read-only: the clock, the boat, the seed
and the whole saved state are unchanged (`test_wind_overlay [navigator]`);
reopening the chart starts at NOW. Screenshot 30.

## Navigation

### 13. Cabin world map

A framed world map hangs on each cabin wall (`src/boat/cabin_world_map.gd`,
placed in all four cabins, clear of the hat and the cat's place). Walking up
to it highlights the frame (no circle); **E** opens the **Dreamer's Map**: the
whole world, pan and zoom, names, harbours by zoom, search, select, the name,
country and story, **Visited / Not visited yet** and the services. It has
**no wind, no weather areas and no wind switch**, and samples no weather while
panning (`test_navigation_views [dream]`). Screenshots 01 (all four boats),
02–05.

### 14. Voyage daydreaming

**Imagine this voyage** (`src/navigation/voyage_daydream.gd`) asks the real
router for the route, then writes a short reflection: the distance, and up to
three **real harbours** that lie near the route, in order along it, with a
modest variety of tones (curious, hopeful, cautious, excited, thoughtful). No
place is invented. It is cached per destination and changes nothing: time,
money, stores and course are untouched. The route is drawn dashed. **Plan it
at the chart table** opens the working chart with that harbour selected.
Screenshot 06.

### 15. Regional navigation station

The chart table now opens on the region around the boat, about **400 nm
across** (latitude-aware), with the boat, coast, harbours, the route, the
waypoints, the **next turn ring**, heading, distance and the weather and wind.
Zooming out still reaches every harbour, and plotting still uses the global
router: route distance is never limited by the display. Screenshot 07.

### 16. Cockpit chartplotter

**P** on deck (or the action wheel) shows a small chartplotter at the bottom
left (`src/ui/chart_plotter.gd`): coast from the router's navigation grid
(96×96 raster, rebuilt a few rows per frame and only after moving 20 % of the
range), the course, the next-turn ring, the boat and the local wind; ranges 5,
12, 30 and 80 nm. Only on deck and underway. Screenshot 08.

### 17. Worldwide routing regression

All three views use the one worldwide chart, harbour catalogue and router.
`test_routing` (every pair of European harbours and every international
harbour from Copenhagen), `test_world_voyage` (Copenhagen → Papeete via
Panama across the Date Line) and `test_world_chart_render` pass in the final
regression (section 33). The next turn is the same in the chart ring, the
sailing panel, the chartplotter and the voyage path (`test_navigation_views`,
`test_cockpit_ui`).

## Lighting

### 18. Lighting implementation

`src/boat/boat_lighting.gd`: a `CanvasModulate` sets the ambient light of the
area from the time of day and the weather; `PointLight2D` lamps with soft
falloff textures are placed **at each boat's own fixtures, found by name**
(saloon table, galley, chart table, berth), so they follow any later
personalization. The Anchor Ambience no longer owns its own CanvasModulate
(two conflicted); it still computes its tint, which feeds the lighting.
Interactable highlights are compensated so they stay readable at night.

### 19. Time-of-day model

`src/world/daylight.gd`: the sun's elevation from the game clock (UTC), the
boat's longitude (local solar time = UTC + longitude / 15), its latitude and
the day of the year (declination), so the Faroes in June barely get dark and
the tropics have short dusks. Phases: night, dawn, day, dusk. Overcast and
rain dim the day (factor 0.3 at full overcast). The light eases towards the
target (no jumps); at Long Passage speeds the easing slows so a day passes as
a gentle swell, not a strobe; a load jumps straight to the right hour.

### 20. Interior and exterior lighting

- **Cabin by night**: warm pools at the table, galley, chart table and berth;
  corners darker, never black. **By day**: bright, lamps off, cool light from
  the hatches. All four boats. Screenshots 12–14.
- **Deck by night**: cool and dim; the helm instruments glow softly, light
  spills from the companionway, red/green/white navigation lights; the
  interaction highlight on the helm stays clear. Screenshots 15–17.
- **Soft shadows and depth**: each fixture casts a soft offset shadow (larger
  for higher layers), and the captain and companions have a soft contact
  shadow. Before/after: `31_lighting_before_after.png` (I016 left, I017 right,
  cabin and deck at night).

### 21. Harbour lighting

Quay lamps and pontoon lights from the shared `HarbourDressing` positions, so
every harbour has them; lit at night while moored, parented to the mooring (so
they glide in with it on arrival). Warm and modest: inhabited, not floodlit.
Screenshot 18.

## Atmosphere

### 22. Weather visuals and audio

- `src/audio/weather_audio.gd`: a breeze loop and water along the hull by the
  wind and the boat's speed, a strong-wind loop above 20 kn (full at 45 kn),
  rain from the weather that brings it (heavy in thunderstorms and squalls,
  steady in gales, showers where thunder is possible). Fades of 3 s; no
  harsh drone (loops are soft and band-limited).
- **Thunderstorms**: lightning brightens the scene briefly through the
  lighting (`BoatLighting.flash`), thunder follows after the distance's delay,
  sharper and louder when near, later and lower when far.
- **Visual cues**: wind streaks drift across the deck relative to the actual
  wind; rain falls on deck in rain (`src/boat/weather_visuals.gd`).
- **Accessibility**: Settings → *Reduce flashing* (one soft glow per strike)
  and *Lightning flash* 0–100 % (0 = no flash, thunder still heard).
- **Sounds**: original, generated deterministically by
  `tools/generate_weather_audio.py`; provenance in
  `assets/audio/weather/README.md`.

Screenshots 19–22.

### 23. Cabin acoustics

An **Outside** audio bus (low-pass filter, sent to Ambience) carries wind,
rain, water and thunder. Below deck its cutoff closes to 650 Hz and it drops
5 dB; on deck it opens again. The SFX bus is unfiltered, ready for the I019
alarms (not built). The cabin brightens a little with lightning.

## Gameplay correctness

### 24. Visual boat-turning fix

Root cause: the deck view picked its eight-direction view only when certain
signals fired (departure, area change), **not when the heading changed at a
waypoint**, so the boat kept the old course on screen. The deck area now
checks the heading's octant each frame and re-applies the view when it
changes, keeping the captain at the same place aboard (relative to the boat).
`test_sailing_correctness [orientation]` covers the captain amidships, at the
bow and the stern, successive turns, a cabin round trip and after a load; it
fails without the fix. Screenshots 23a/23b.

### 25. Player and sail layering

The sails, boom and rigging are drawn at z 20, above the captain (z 10), and
turn see-through (45 %) while the captain stands under them, solid again
otherwise (`test_presentation [rig]`). Screenshot 24.

### 26. Fender findings

The white objects over the starboard side are **fenders painted into each
boat's deck art** (2–3 per boat), not stray props. They are shown in harbour,
**stowed underway** (cleared from a runtime copy of the texture; the art file
is untouched and its checksum is tested), back out on arrival and after
loading a harbour save (`test_presentation [fenders]`). Screenshots 25, 26.

## Usability

### 27. Right-side HUD

The **Sailing** panel (`src/ui/sailing_panel.gd`) underway: speed, heading,
wind now, the next leg's forecast wind (labelled estimate), the next turn
(time, distance, new course), distance and ETA; on the last leg "No more
turns: <harbour> ahead". Collapsible; it lets clicks through to the weather
warning and the Long Passage panel. A course change of more than 5° by the
autopilot briefly highlights the heading (one gentle pulse with Reduce
flashing). Screenshot 09.

### 28. Action wheel

**Q** opens a context-aware wheel (`src/ui/action_wheel.gd`): at the helm
(chartplotter, sailing details, anchor, chart, go below, Captain's Log), in the
cabin (sleep, world map, chart table, provisions, go on deck, Captain's Log).
A/D or arrows choose, E/Enter uses, Q/Esc closes, the mouse works, nothing
under it reacts. **"Q actions"** is in the bottom help strip. Screenshot 10
(and 09 for the help strip).

## Persistence

### 29. Save/load and weather persistence

- Loading underway puts the captain back in the saved area at the saved place
  relative to the boat, validated against the deck's lifeline polygon (or the
  pontoon): an invalid place falls back to the helm, never overboard.
  Covered at the helm, bow, stern, in the cabin, after a course change, at
  anchor and in a gale at night (`test_sailing_correctness [save]`).
- The weather is a pure function of (position, time, world seed); nothing is
  rerolled on load. The same save sailed twice gives identical wind, position
  and condition for 12 hours (`[weather]`), also across processes (section
  35).

### 30. F5 and F9

**F5** quicksaves (own file, manual slots untouched), at most once per second,
refused with a short message while a menu is open. **F9** asks, then restores
the quicksave exactly. The developer test panel moved from F9 to **F10**
(editor runs only). The quicksave is listed in Load Game.
(`test_sailing_correctness [quick]`.)

## Harbours

### 31. Harbour facilities and visited list

Selecting a harbour (working chart and Dreamer's Map) shows its tier and
services from `HarbourFacilities` (groceries, boatyard, haul-out, go ashore);
a test checks all harbours list exactly the services in their data and that
nothing is invented (no fuel). Captain's Log → Harbours: grouped by country
with "N of M visited", countries open and close, filters All / Visited / Not
visited. Screenshots 27, 28.

### 32. Docking animation

Arriving awake shows the deck: the captain at the helm, the engine on, the
harbour gliding in alongside over a few seconds; any key skips it; then
harbour play resumes. One arrival only; nothing is consumed or counted twice.
Sleeping through an arrival is unchanged (you wake in the cabin). Screenshot
29.

## Verification

### 33. Automated test results

**Full regression** (headless, every suite including the all-pairs routing
test), run on the final code before the last two changes below:
**3838 checks passed, 0 failed**, exit code 0, 870 s.

After it, two things changed and their suites were run again:

- the late lighting tuning (quay and pontoon lamps, fixture shadows,
  overcast factor): `test_lighting` 37/37, `test_presentation` 55/55,
  `test_atmosphere` 19/19;
- the chartplotter now loads the navigation grid on first use instead of at
  start-up (section 36): `test_cockpit_ui` 32/32.

Rendered suites (Xvfb, software OpenGL) were run per checkpoint
(`test_world_chart_render`, `test_wind_overlay`, `test_navigation_views`,
`test_cockpit_ui`, `test_lighting`, `test_atmosphere`, `test_presentation`)
and passed. Skipped by design: the window-mode checks need a real display
(reported as skipped by the runner).

New suites: `test_world_chart_render`, `test_wind_overlay`,
`test_sailing_correctness`, `test_navigation_views`, `test_cockpit_ui`,
`test_lighting`, `test_atmosphere`, `test_presentation`. Existing tests were
not weakened; changed checks: `test_gameplay_flow` (1e-9 relative tolerance
for a pre-existing flake, see section 1), `test_upkeep_ui` (F10),
`test_captains_log` (new harbour list), `test_branding` and `test_diagnostics`
(0.104a).

### 34. Rendered review

`docs/screenshots/iteration17/` (rendered at 1600×900, Xvfb, software
OpenGL, by `tests/screenshots_17.tscn`): the thirty requested views, with 01
for all four boats, 09 and 11 in one image (the panel and the help strip
together), 23 as a before/after pair, and 31/32 the lighting and chart
before/after comparisons. Each was looked at:

- **Navigation (01–07, 27, 30, 32)**: the frame hangs in each of the four
  cabins; the Dreamer's Map shows complete land after 26 pans, across the
  Date Line, with Papeete's details and a dashed daydream route; the station
  chart opens regionally around Copenhagen; Skagen's services; the wind
  navigator on FORECAST with the uncertainty note.
- **Cockpit (08–10)**: the chartplotter, the Sailing panel beside the Long
  Passage panel without overlap, "Q actions" in the help strip, the wheel.
- **Light (12–18, 31)**: noon bright, dusk warm, night with warm pools and
  dark corners; the deck at night cool with red/green lights and the helm
  glow; the harbour with quay lamps. The before/after shows the change is
  lighting, not repainting: the art reads as itself.
- **Weather (19–22)**: rain streaks and wind streaks on deck in severe
  squalls, the cabin dimmed. In stills the lightning flash is hard to see
  (it lasts a fraction of a second and the shot catches its decay); the
  flash itself is verified by `test_atmosphere`.
- **Boat (23a/b, 24–26, 29)**: the deck before and after an autopilot turn;
  the captain visible under the boom and sail; fenders out moored, gone
  underway; the docking arrival with the harbour alongside.
- **Noticed**: in the Wing 33 cabin the cat's ear just overlaps the lower
  corner of the map frame (the cat sits below it). Left as is; worth a look
  in the acceptance test (3A).

### 35. Two-process restart

`tests/restart_17.tscn`, run as two separate processes (write, quit, read):
three saves underway — on deck near the bow, in the cabin, and after
searching for poor weather. **PASS**: in each case the captain was loaded into
the right area at the exact place aboard, the boat's position, time, route
and progress were as saved, the weather was identical, and six hours later
the boat was where the first process had it, in the same weather.

The deck save happened to be in **strong wind (25 kn, gusts 33 kn)**, so a
rough-weather save is covered. The deliberate search for worse weather (a
gale or a thunderstorm along the next 8 days of the passage) found none, so a
saved thunderstorm was not tested across processes; storms are covered
in-process by `test_sailing_correctness` (a gale at night) and
`test_atmosphere`.

### 36. Performance and memory

Benchmarks: `tests/benchmark_17.gd`, the same scenarios before (I016 code,
`iteration17_before_*.json`) and after (`iteration17_after_*.json`), on the
same container. **Headless** measures the game's CPU work (frames are capped
at about 6.9 ms there, so frame times at that value mean "no extra work").
**Rendered** uses software OpenGL (llvmpipe) under Xvfb: every frame is
drawn by the CPU, so absolute frame times are far higher than on any GPU,
and runs vary by ±10 %.

Headless, measured:

| | Before | After |
|---|---|---|
| App start-up to the menu | 115 ms | 176 ms |
| Chart first open | 2209 ms | 2019 ms |
| Chart reopen (mean of 8) | 472 ms | 205 ms |
| Forced wind re-sample, Denmark region | 1051 ms | 36 ms |
| Chart frames, all views, wind on/off | 6.9–12.1 ms | 6.9–9.7 ms |
| Deck underway, ms/frame | 8.5 | 9.0 |
| Sailing simulation, ms per day | 499 | 514 |
| Long Passage, ms per game day | 462 | 474 |
| Save / load | 1.1 / 5.1 ms | 1.1 / 3.4 ms |
| Memory at the end | 198 MB | 208 MB |

Rendered (software OpenGL), measured:

| | Before | After |
|---|---|---|
| Forced wind re-sample, Denmark region | 787 ms | 92 ms |
| Chart reopen (mean of 8) | 607 ms | 382 ms |
| Chart frames | 41–101 ms | 45–106 ms (within run-to-run variation) |
| Deck underway (the benchmark's moment is at night) | 35 ms | 80 ms |
| Memory at the end | 188 MB | 198 MB |

Findings:

- **Start-up**: the first after-run measured 892 ms: the chartplotter
  loaded the worldwide navigation grid when the HUD was built. It now loads
  it on first use (the chart's first open needs it anyway); start-up is
  176 ms. The remaining ~60 ms are the new HUD panels and audio set-up
  (*estimate*, from timing the components separately).
- **Night deck under software rendering**: a probe on the same deck at 13:00
  and 23:00 found the night lamps cost about 22 ms per frame on llvmpipe
  (57 → 33 ms with them hidden; the I016 code measures 31–33 ms there). No
  single lamp is responsible; it is the 2D renderer's light pass. By day
  frames are unchanged (35 ms both). On a GPU five small additive lights are
  normally cheap, but this is **not verified**; the Windows check 14A asks
  for the frame rate on deck at night.
- **Memory**: +10 MB (new sounds, light textures, wind caches; all bounded).
- Sailing and Long Passage differ by a few percent, within the run-to-run
  spread (three after-runs: 534, 525, 514 ms per sailed day).

### 37. Shipyard Efficiency — Where the Time Went

Every Godot run in this build went through one wrapper that logs its wall
time and exit code (`i17_timing.log`, kept outside the repository), so the
numbers below are **measured** unless marked *estimate*. The log is from the
start of I017 (03:16 UTC) to the start of the final regression; the final
regression, benchmarks and screenshot runs of Checkpoint I are listed in
sections 33, 36 and 34.

**Measured totals**: 138 logged Godot runs, **47.1 minutes** of Godot wall
time. (Two rendered baseline benchmark runs of 137 s and 169 s at 03:35–03:39
were logged without an exit code and are not in the 138.)

**1. Major phases** (Godot time per checkpoint; measured):

| Checkpoint | Runs | Godot time | Share | Note |
|---|---|---|---|---|
| A: chart fix and baseline | 13 | 390 s | 14 % | includes one 300 s hang (below) |
| B: wind overlay | 16 | 316 s | 11 % | one rendered benchmark, 150 s |
| C: navigation views | 23 | 284 s | 10 % | |
| D: sailing correctness | 24 | 530 s | 19 % | the gameplay_flow flake hunt (below) |
| E: lighting | 19 | 296 s | 10 % | |
| F: atmosphere | 9 | 116 s | 4 % | |
| G: cockpit and wheel | 15 | 198 s | 7 % | |
| H: presentation | 13 | 547 s | 19 % | the regression without routing, 388 s |
| I: delivery (so far) | 6 | 152 s | 5 % | screenshots ×2, restart test |

Wall-clock from start to Checkpoint H was about 2 h 07 min (03:16 → 05:23,
from commit times); Godot runs were therefore roughly a third of it
(*estimate*: the rest was reading, writing code and documentation, which is
not timed).

**2. Measured command durations**: a single suite run headless takes 3–26 s
(most 7–12 s, much of it start-up and loading the world chart); a rendered
suite run under Xvfb 14–19 s; the screenshot run 64–66 s; the rendered
benchmark 137–169 s; the headless regression without routing 388 s.

**3. Expensive tests** (measured, per run): `test_eight_directions` 51 s,
`test_world_voyage` 50 s, `test_harbour_life` 41 s, `test_gameplay_flow`
24–26 s. `test_routing` (every pair of harbours) dominates the full
regression and was therefore left to the final run (section 33).

**4. Expensive rendering and screenshot steps**: the 30-shot screenshot run
(64–66 s, run twice: the second time after the deck-shadow and harbour-light
tuning); rendered benchmarks (137–169 s each, three runs); rendered visual
suites 15–19 s each, 44 rendered runs in all.

**5. Repeated geography and data generation**: none was regenerated in I017
(the world and Denmark data from I016 were reused as committed). Each
Godot start does load the world chart and the routing graph again; that
start-up is part of every run above (*estimate*: 3–5 s of each headless run,
judging by the shortest runs at 3–4 s).

**6. Caching opportunities**: the land-class cache for the wind overlay and
the per-destination daydream cache are in the game already. In the shipyard:
a persistent import cache is already used; the world chart and routing graph
could be loaded once per test process rather than once per suite.

**7. Unnecessary repeated work** (measured):

- **One 300 s hang** (A, "repro render after fix", killed by its timeout):
  a rendered reproduction script never quit and ran until its 300 s timeout;
  the next run of the same script finished in 10 s. 300 s, 11 % of all Godot
  time, for nothing.
- **Iterating new tests**: 30 runs (441 s) were early versions of the new
  suites (v1, v2, debug) failing on the test itself rather than the game.
- **5 fail-fast aborts** (a parse error caught within 3 s and the run
  killed): the wrapper saved the full timeout each time.
- **The gameplay_flow flake**: about 4 runs (~100 s) in D chasing a failure
  that turned out to be pre-existing (it fails 1 run in 4 on the I016 code
  too, checked on a separate worktree).
- `test_eight_directions` and `test_harbour_life` were each run in both D and
  E (184 s) because both checkpoints touched the deck.

**8. Recommended improvements** (up to five):

1. Give every rendered helper script a short timeout (≤ 120 s) and a
   "first frame drawn" guard, so a hang costs seconds, not five minutes.
2. Load the world chart and routing graph once per test process (a shared
   fixture) to cut a few seconds from every suite run.
3. Split `test_routing`'s all-pairs check into a fast sample for checkpoint
   runs and the full set for the final regression.
4. Tag suites by subsystem so a checkpoint reruns only the suites its files
   touch (D and E would not both have run the deck suites).
5. Fix flaky checks when first seen on the baseline (as done here) rather
   than re-running them.

### 38. Known limitations

- **Windows not tested**: all verification is on Linux (headless and
  software-rendered). The lighting under a real GPU, the audio on Windows
  devices and the chart on the Captain's machine are for the acceptance test.
- **Rain is derived**: the weather model has no rain field; rain is played
  and drawn for the weather that brings it (heavy in thunderstorms, squalls
  and tropical storms, steady in gales, showers where thunder is possible),
  so its timing is plausible, not measured.
- **Synthetic sounds**: the weather sounds are generated, not recordings.
- **Software renderer**: rendered frame times measure llvmpipe; the GPU
  figures will differ.
- **Night lamps and frame time**: under software rendering the night lamps
  add about 22 ms per frame on deck (section 36); expected to be minor on a
  graphics card but not verified (Windows check 14A2).
- **No saved thunderstorm across processes** (section 35).
- **Shadows are soft overlays**, not true light occlusion: lamps light through
  furniture, and the deck light on the coachroof is a pool, not a shaped
  beam.
- The docking presentation is a short glide, not a manoeuvre.

### 39. Pending Windows acceptance

**Not yet tested on Windows.** `WINDOWS_ACCEPTANCE_17.md` lists 15 sections
(1A–15A) with PASS / FAIL / PARTIAL / NOT TESTED and space for comments.
Iteration 17 is not claimed as accepted until the Captain's results come
back. Scope: nothing from I018–I021 was started (no Fishing 2.0, alarms,
shops, personalization or difficulty modes); the cabin wall map is the
authorized navigation feature only.

### 40. Final commit and push verification

@@PUSH@@
