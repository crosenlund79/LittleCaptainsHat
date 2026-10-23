# Iteration 002: The First Voyage (Report)

**Engine:** Godot **4.7.2 stable** (official Linux build), GDScript, Compatibility renderer.

**Test environment:** a Linux container, running Godot headless, plus Xvfb with Mesa
llvmpipe (software OpenGL) for rendered runs.

**No Windows machine was available**, and nothing was played by a human. Every
"verified" statement below comes from automated checks or from screenshots of
automated runs.

## 1. Implemented functionality

Each item is marked **[T]** (implemented and tested by automated checks), **[T+S]**
(tested and also checked visually in screenshots) or **[U]** (implemented but not
verified).

- **European chart** [T+S]
  - Coverage from Iceland to Cyprus and from North Africa to the North Cape: 25°W–37°E,
    33°N–72°N. This covers Scandinavia, the British Isles, the North Sea, the Baltic,
    the Atlantic coast, Biscay, Iberia and the Mediterranean.
  - Built from Natural Earth coastlines, with country and sea labels and an adaptive
    graticule.
  - Existing controls are kept: wheel, keys and buttons zoom; drag and keys pan; and
    "Find boat", the cursor coordinate readout and distance display all work. There is
    a new "All Europe" button.
- **15 ports** [T]: Copenhagen, Kiel, Gothenburg, Bergen, Helsinki, Portsmouth, Dublin,
  Brest, Lisbon, Gibraltar, Barcelona, Marseille, Naples, Piraeus and Reykjavík. Each
  is a `PortData` resource with real coordinates.
- **Automatic sea routing** [T+S]
  - Routes start at the vessel's position (a port or a position at sea), end at the
    destination, and never cross land.
  - They follow the coast around islands and peninsulas and are made of multiple
    rhumb-line segments; the distance is measured along the course.
  - All 105 port pairs route successfully.
- **Land validation of complete segments** [T]
  - Uses a supercover raster traversal.
  - Every route is also cross-checked in tests against the vector coastline.
  - Harbour approaches are bounded (≤ 2 nm berth link, ≤ 10 nm approach).
- **Waypoint editing** [T+S]
  - Add a waypoint by dragging the course line, move it by dragging, remove it by
    right-click, Delete or the button. Selecting a waypoint highlights it.
  - Changes recalculate live, and distance and sailing time update.
  - Invalid edits are drawn as BLOCKED legs or crossed waypoints, with the reason
    explained, and cannot be applied.
  - All editing is on a draft: Apply commits it, Discard reverts it, and leaving with
    unapplied changes asks first.
- **Game clock** [T]: starts 1 May 2026, 08:00 UTC. At 1×, 1 real second is 1 game
  minute (configurable). Time acceleration is 1× / 5× / 20× from the HUD and the chart.
  The clock runs in the cabin, on deck and on the chart, and stops while paused.
- **Voyage simulation** [T]: a constant 5 kn (from `VesselProfile`). The
  `moored` / `underway` / `arrived` states are explicit. Departure happens at the helm
  (or with Set sail on the chart) after a confirmation. Progress follows the validated
  route.
- **Arrival** [T+S]: the voyage stops exactly at the destination, the location
  updates, the vessel is placed at the port, and the HUD and a notification announce
  it. The next voyage starts from there.
- **Sleeping** [T]: the berth offers 4, 6 or 8 hours. Sleep advances the same
  simulation, stops on arrival or at a new warning, and reports the time slept.
- **Weather warnings** [T+S]
  - Four static demonstration areas, shown on the chart with a name, a
    CAUTION/DANGER/FAIR tag and a dashed or solid outline.
  - A warning is given when the remaining course reaches a noteworthy area within
    5 hours of sailing. It appears as a HUD banner with View chart / Dismiss plus a
    notification.
  - Each condition is warned about once per course; acceleration drops to 1×; sleep
    is interrupted.
  - Weather has no other effect.
- **Changing course at sea** [T+S]
  - Edit the remaining course or pick a new destination on the chart, then press
    Change course.
  - The new course is planned from the vessel's current position; there is no
    teleport, and the clock, boat area and player position are preserved.
  - Remaining distance and weather are recalculated. Invalid changes leave the voyage
    intact.
- **HUD** [T+S]: area, location or status, clock with time controls, a voyage panel
  (destination, speed, distance to go, ETA, progress bar), the warning banner and the
  interaction prompt.
- **Save/load** [T]
  - Format version 2 stores the clock, time scale, vessel status, position and speed,
    and the active voyage: its route geometry, progress, course revision and the
    weather warnings already given.
  - Iteration 001 saves are migrated.
  - Inconsistent voyage data is rejected without touching the running game.
- **Deck** [T+S]: the pontoon and mooring lines are shown only in port, and the
  pontoon label names the current port.

## 2. Architectural changes

- **New autoload `Simulation`.** It is the single timeline: the clock, voyage
  advancement, arrival, warning events and sleep. It is event-driven, so step size does
  not change results, and pausable. It writes state only through `GameSession`.
- **`SessionState` gained a `clock` section, a `vessel` section and a voyage under
  `navigation`.** `GameSession` gained intent methods (`depart`, `change_course`,
  `set_planned_route`, `set_time_scale`, …) and Simulation-only hooks.
- **New data classes and services:**
  - `Voyage`, `VesselProfile` and `NavGrid`;
  - `SeaRouter`, which does planning and validation;
  - `WeatherCondition` and `WeatherCatalog`.
- **`PlannedRoute` was refactored** (a significant change): it now holds an origin
  position (port optional), the calculated `path` and the waypoint indices. Its
  `create()` was removed, and `describe()` and the distance now use the path. Route
  geometry is saved, so the course sailed is always the course that was shown and
  validated.
- **`GeoMath`** gained rhumb-line distance and interpolation, path length, cumulative
  distances and point-along-path.
- **`MapView` and `WorldMap` were rewritten** around display state and a draft/commit
  editing model; `MapView` emits input events only. The Baltic dataset was replaced
  by Europe.
- **`App`** wires up departure, the helm, sleep, warnings, arrival and the
  leave-chart confirmation. The HUD now reads state every frame instead of being
  refreshed by signals.
- **`BoatArea`** routes `bed` and `helm` to signals (they previously only showed
  messages) and controls the deck's mooring node.
- **Static default caches** (`PortCatalog`, `SeaRouter`, `WeatherCatalog`) are released
  in `GameSession._exit_tree()` to avoid script reference leaks at exit.
- **`SaveManager`** moved to `SAVE_VERSION = 2` with `_migrate_1_to_2`, writes JSON at
  full float precision, and shows "At sea → destination" in slot metadata.

## 3. Files created or modified

**Created**

```
src/core/simulation.gd
src/navigation/{nav_grid,sea_router,voyage,vessel_profile}.gd
src/weather/{weather_condition,weather_catalog}.gd
src/ui/{time_controls.gd,sleep_menu.gd,sleep_menu.tscn}
data/navigation/europe_land.json, europe_navmask.png (+ .import "keep"), europe_navmask.json, europe_route_graph.json
data/navigation/ports/*.tres (13 new ports)
data/vessel/starter_sloop.tres
data/weather/demo_conditions.tres
tools/navigation/build_navigation_data.py, tools/navigation/chart_labels.json
tests/suites/{test_routing,test_simulation,test_voyage_persistence}.gd
ITERATION_002_REPORT.md
docs/screenshots/* (refreshed)
```

**Modified**

```
project.godot (Simulation autoload)
src/core/{game_session,session_state}.gd
src/navigation/{planned_route,geo_math,map_view,world_map}.gd, world_map.tscn
src/app/{app.gd,app.tscn}
src/ui/{hud.gd,hud.tscn}
src/boat/{boat_area.gd,exterior.tscn,interior.tscn}
src/persistence/save_manager.gd
src/navigation/port_catalog.gd
data/navigation/port_catalog.tres
tools/build_theme.gd, assets/ui/next_harbor_theme.tres (ProgressBar style)
tests/test_runner.gd, tests/restart_check.gd
tests/suites/{test_data_model,test_save_manager,test_gameplay_flow}.gd
README.md, ARCHITECTURE.md, .gitignore
```

**Removed**

```
data/navigation/western_baltic_land.json
```

## 4. Routing algorithm selected and why

I chose a **precomputed sparse sea graph, searched with Godot's native `AStar2D`, then
shortened by string pulling, with every segment checked against one Mercator
navigability raster.**

- **Correctness first.** Routing and validation use the same raster and the same
  supercover line traversal. A test re-checks all 109,475 graph edges with the runtime
  code. The raster is generated from exactly the polygons the chart draws, and it is
  conservative: any land in a cell blocks it. As a result, accepted segments never
  touch drawn land. Tests verify this independently against the vector polygons for
  13 representative routes.
- **Rhumb-line segments.** These are straight on the Mercator chart and in the raster,
  so validation is exact and drawing, movement and distance agree.
- **Performance.** European routes take 1–40 ms (worst case measured: Helsinki →
  Piraeus at 36 ms). All 105 port pairs take about 2.1 s in total. Loading the graph
  takes about 0.2–0.4 s, once.
- **Generality.** Any origin or destination inside the coverage works: ports,
  waypoints and positions at sea. Only data hints are used; there are no hand-authored
  routes.
- **Alternatives rejected:**
  - A* directly on the fine raster: too slow in GDScript.
  - `AStarGrid2D` on the raster: memory heavy at the resolution needed for straits.
  - A pure visibility graph: an O(n²) build, and narrow straits are hard to handle.

## 5. Geographic data sources and limitations

- **Source:** Natural Earth 1:10m Land (public domain). It is clipped to the bounds,
  simplified at 0.0035°, islets under about 1–2 km² are removed, and lakes are filled.
  The data is attributed in the README, the chart panel and the data files. Everything
  is local; no web services are used at runtime.
- **Raster resolution:** 60 cells per Mercator degree, about 1.9 km E-W everywhere
  and about 1.1 km N-S at 55°N. Water narrower than about two cells is closed.
- **Unreachable waters** (no route is ever faked):
  - Black Sea, Sea of Marmara and Sea of Azov (the Bosporus and Dardanelles are too
    narrow);
  - Gulf of Corinth and White Sea;
  - inner Oslofjord (Drøbak) and inner Stockholm archipelago;
  - many small fjords, sounds and lagoons.

  Oslo and Stockholm were therefore left out of the ports.
- **No canals.** For example, there is no Kiel Canal, so Kiel → Portsmouth sails
  around Skagen.
- **Harbour approaches** may graze the generalised coastline within the bounds above.
  For example, Kiel's approach follows the fjord for 5.1 nm.
- **Copenhagen → Kiel** passes the narrow Fehmarnsund south of Fehmarn. That gap is
  open in the generalised data, and the real sound is navigable, but I did not check
  bridge clearance; that is out of scope.
- **The chart edge** is treated as land, so routes stay inside the coverage.

## 6. Tests executed

All runs use Godot 4.7.2 from the repository root.

| # | Command | Covers |
|---|---|---|
| T1 | `godot --headless --path . --import` | All resources and scripts import |
| T2 | `godot --headless --path . --quit-after 60` | Boots to the main menu without errors or leaks |
| T3 | `godot --headless --path . res://tests/test_runner.tscn` | All 7 suites, headless |
| T4 | `xvfb-run godot --path . --rendering-driver opengl3 res://tests/test_runner.tscn -- --screenshots=DIR` | All suites with real rendering plus screenshots |
| T5 | `tests/restart_check.tscn --phase=write`, then `--phase=read` in a new process | Settings and an underway voyage survive an application restart |
| T6 | Ad-hoc performance probe under Xvfb (not committed) | Chart open time and frame time |

**Suites and what they cover:**

- **Data model:** state round trip, invalid v2 data, route planning through
  `GameSession`.
- **Routing:**
  - all graph edges are consistent with the runtime check;
  - all 15 harbour approaches;
  - Copenhagen → Kiel does not cross Zealand, and is longer than the straight line;
  - 13 representative routes, checked against the vector coastline;
  - straits: Gibraltar, Dover, Øresund, Bonifacio and the Great Belt;
  - all 105 port pairs;
  - a waypoint on land is rejected with the blocked leg identified, and a valid
    waypoint becomes a path vertex;
  - land-crossing routes are refused by `GameSession`;
  - the Black Sea, an inland start and an unknown destination fail fast.
- **Simulation:**
  - clock rates at 1×, 5× and 20×; pausing stops time;
  - start time, departure, 2 h giving exactly 10 nm, position on the route;
  - one 15 h step equals 900 one-minute steps;
  - arrival exactly at distance / speed; the next voyage starts from the arrival port;
  - sleep progress equals normal time; arrival during sleep;
  - warning exactly 25 nm (5 h) before the area, at both 1× and 20×; no early
    warning; no repeated warning; 20× drops back to 1×;
  - sleep is interrupted at the warning point;
  - no speed change inside the area; no warnings on a clear course;
  - invalid reroute leaves the voyage intact;
  - reroute from the current position (no teleport; clock, area and player kept),
    avoids the area, and arrives;
  - changing destination at sea.
- **Save manager:** the Iteration 001 checks, adapted.
- **Voyage persistence:**
  - saving underway, with slot metadata;
  - exact restore of the clock, time scale, position, progress, route, destination,
    area and player;
  - handled warnings are not repeated after loading; the loaded voyage continues to
    Kiel;
  - migration of an Iteration 001 save, with the route recalculated and settings
    untouched;
  - five kinds of corrupt voyage data rejected, with the active voyage unchanged.
- **Settings and audio:** unchanged from Iteration 001.
- **Gameplay flow:** all of Iteration 001's UI flow, adapted, plus:
  - waypoint editing by mouse (drag on the course, drag onto land → invalid, drag
    back, right-click remove, the leave confirmation, Discard);
  - the **full acceptance scenario** (§15, steps 1–31) driven through the real UI.

## 7. Actual test results

- **T1 and T2:** no errors.
- **T3: 484 checks passed, 0 failed**, exit code 0. Window-mode checks are skipped
  headless.
- **T4: 488 checks passed, 0 failed**, exit code 0. VSync checks were skipped because
  the driver does not support VSync control, as in Iteration 001. I reviewed the
  screenshots of:
  - the chart: Europe view, planned course with a waypoint, invalid waypoint,
    underway view and reroute;
  - the deck underway, the weather warning in the HUD and the arrival in Kiel.
- **T5:** both phases passed (13/13 checks), exit code 0.
- **T6:** opening the chart takes about 0.4 s.
  - Frame time on **software** OpenGL is about 40–70 ms while panning, against
    23 ms for the cabin under the same renderer. The CPU-side overlay redraw is a
    few ms; the rest is the software rasteriser's fill rate.
  - Real-GPU performance was **not measured**.
- **Acceptance scenario:** every step passed in both T3 and T4. In the run:
  - Copenhagen → Kiel was 154 nm, and 156 nm with the waypoint;
  - the strong-wind warning interrupted sleep after 3 h 37 min;
  - after the course change the remaining course was 128 nm and avoided the area;
  - the boat arrived in Kiel on Sat 2 May 2026 at about 17:27 UTC.

## 8. Known problems

- **Not run on Windows,** and nothing was played by a human. Feel, readability at
  other window sizes and real-GPU performance are unverified.
- **VSync** could not be verified (environment), and **no audio was heard** (no
  sound device).
- **Toasts pile up.** A sleep that ends in arrival produces up to three notifications,
  stacked at the top centre.
- **The chart's draft lags a moving boat.** While editing at sea the draft starts
  where the boat was when the edit began. This is harmless, because Change course
  always replans from the current position, but the first leg can look slightly
  behind the boat.
- **No keyboard path to add waypoints.** The arrow keys pan the chart while a
  side-panel button has focus (also noted in Iteration 001).
- **The weather banner stays up** until it is dismissed, the boat arrives, or the
  chart is opened from it. It is not cleared automatically when the course is
  changed elsewhere.
- **One intermittent exit-time warning:** Iteration 001 noted an exit-time audio
  reference warning in the test harness. It was not observed again in this
  iteration's runs, but it was not investigated further.

## 9. Features deliberately excluded

These were out of scope or frozen, and were not started:

- economy, jobs, provisions, needs, fatigue;
- equipment, repairs, damage, sinking, death;
- sail trimming, wind physics, currents, tides, depths, grounding;
- moving or real weather, weather APIs;
- points of interest, quests, NPCs, port services;
- docking or harbour-entry animation;
- automatic onward voyages;
- offline time between sessions.

**Possible future features** (not implemented): a keyboard-driven waypoint editor;
showing the warning's area highlighted when the chart opens from the banner; ETA at
each waypoint.

## 10. Architectural concerns for future iterations

- **`App` keeps growing**: about 310 lines with the voyage flow. Splitting it into
  game-flow and menu-wiring parts is now worth doing.
- **`Simulation` with variable speed.** With constant speed, events are found
  analytically. Wind-dependent speed will need piecewise integration with more event
  boundaries; see ARCHITECTURE.md, "How future wind effects may change speed".
- **Weather encounters** are computed per course revision for static areas. Moving
  weather would make encounters depend on time and position together.
- **Navigation data is regenerated offline** (Python and Natural Earth). Changing the
  region or resolution means re-running the builder; the runtime tests verify the
  result. Worldwide coverage would need tiling of both the raster and the graph.
- **`PlannedRoute` serves two purposes**: the player's intent (waypoints and
  destination) and the computed geometry. If routing rules change between versions,
  saved paths stay as they were planned. That is intended, but it means old saves keep
  old geometry.
- **Two "dirty" sources.** The clock marks the session as unsaved every frame, so any
  running game always reports unsaved progress. This is fine now, but should be
  reconsidered if autosave arrives.
