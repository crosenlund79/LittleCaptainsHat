# Iteration 003: Wind, Sails & Propulsion (Report)

**Engine:** Godot **4.7.2 stable** (official Linux build), GDScript, Compatibility renderer.

**Test environment:** a Linux container, running Godot headless, plus Xvfb with Mesa
llvmpipe (software OpenGL) for rendered runs. There is no sound device.

**No Windows machine was available**, nothing was played by a human, and no audio
was heard. Every "verified" statement below comes from automated checks or from
screenshots of automated runs.

## 1. Implemented functionality

### Wind field

- **One deterministic wind for Europe.** It covers 25°W–37°E, 33–72°N and is
  continuous, with a single query point: `WindField.sample(geo, time, seed)`, used
  through `Simulation.get_wind_at()`.
  - **Convention:** meteorological. `from_deg` is where the wind comes from; chart
    arrows point where it blows to.
- **Climatology.** About 40 anchors are blended smoothly, so there are no region
  borders. They include:
  - Atlantic westerlies;
  - northerly Portuguese trades;
  - the Mistral and the Meltemi;
  - a lighter, more changeable Baltic.
- **Slow weather on top.** Travelling waves veer and back the wind and strengthen or
  weaken it. A lull wave sweeps light-air patches across sea areas, so some voyages
  meet calms and motor.
- **Measured over 30 days** (wind direction is where it comes from):

  | Area | Mean direction | Mean speed |
  |---|---|---|
  | North Atlantic | 249° | 14.5 kn |
  | Off Portugal | 323° | 10.8 kn |
  | Aegean | 341° | 11.6 kn |
  | Gulf of Lion | 306° | 10.4 kn |

  - The Baltic is lighter than the Atlantic, with spells below 3 kn 14 % of the
    time.
  - Across the region and over 30 days, speeds stay between 0.3 and 25.9 kn.

### Sailing performance (`VesselProfile`)

- **Polar.** The potential sailing speed depends on true wind speed and angle:
  - capped at **10 kn**;
  - **0 kn** inside 35° of the wind;
  - a light-air ramp from 0.8 to 3 kn of wind.
- **Examples:**
  - 12 kn of wind on the beam gives 7.1 kn;
  - 6 kn of wind gives 4.5 kn (marginal);
  - 10 kn of boat speed needs about 25 kn of wind on a broad reach.
- **Relative wind angle.** It is signed, from 0 to 180 on each side: + is wind
  from starboard, − is from port.
- **Spinnaker.** It is automatic at 115–180° while sailing, with a bounded speed
  bonus (×1.12, still capped at 10 kn).

### Automatic propulsion: sail or engine, never both

`PropulsionController` decides at every evaluation point. The actual thresholds are
all `VesselProfile` exports:

| Rule | Value |
|---|---|
| Engine speed | **5 kn** |
| Rolling average of the potential sailing speed | exponential, time constant **3600 game s** (one hour) |
| Engine starts (insufficient performance) | average **< 3.5 kn**, after at least **900 s** under sail |
| Engine starts (becalmed or head to wind) | potential **< 0.5 kn** for **600 s** |
| Engine stops | average **> 6.0 kn** for **1200 s**, current potential > 6.0 kn, and at least **1800 s** of motoring |
| Leaving port | engine if the potential is < 3.5 kn, otherwise sail |
| Course change of more than **30°**, or a change of course | the average restarts from the new heading; the timers reset |

- The potential is evaluated while motoring too.
- **Hysteresis:** the 3.5–6 kn gap plus the minimum times.
- **Measured timings:**
  - a lasting drop from 7 to 2.5 kn starts the engine after 1 h 35 min;
  - a calm starts it after 10 min;
  - a returning 7.5 kn breeze stops it after 1 h 40 min;
  - wind flipping between 3 and 6.5 kn every 30 min for 48 h causes **0 switches**.

### The simulation

- **Single timeline.** `Simulation.advance()` evaluates wind and propulsion only at
  fixed evaluation points:
  - an absolute grid every 300 game seconds;
  - every route vertex;
  - departure, a change of course, and loading a migrated save.

  Speed is constant between them, so arrival, warnings, vertices and grid points
  are solved exactly.
- **Step independence.** The result does not depend on step size. This was verified
  on a 12-hour voyage with a sail → engine → sail sequence:
  - 1× (1-second steps), 5×, 20×, sleep and a single 12-hour step gave the same
    position (to 1e-6 nm);
  - the same switch times (to 1 ms);
  - the same final state.
- **Wind-aware ETA.** It walks the remaining route in 5 nm steps with the expected
  wind. Lisbon → Gibraltar in a steady wind: the estimate was **0.7 %** off the
  actual arrival. It is shown as "about …" in the departure dialog, chart and HUD.
- **Weather warnings.** They work as before. The 5-hour horizon uses the current
  speed. Warnings still wake a sleeper and drop the time scale to 1×.

### Presentation

- **Chart wind overlay** (`WindLayer`):
  - arrows coloured by speed band, pointing where the wind blows, on a lattice of
    about 72 px at every zoom (adaptive density), skipped on land;
  - a smooth speed tint over water only;
  - a legend (knots, 6 bands);
  - a **Wind** toggle in the toolbar, remembered while the game runs;
  - the cursor readout includes the wind under the mouse.
- **HUD.** It shows:
  - game time and time scale;
  - destination, distance to go and a wind-aware ETA;
  - the actual speed;
  - the propulsion mode with its reason, for example:
    - "Under sail · broad reach · 8.2 kn · spinnaker set"
    - "Motoring · insufficient sailing performance · 5.0 kn"
    - "Motoring · becalmed or head to wind · 5.0 kn"
  - the local wind, e.g. "Wind SE 14 kn · 135° starboard".
- **Sails on deck** (`SailRig`, replacing the static sail cover). It is driven only
  by the saved propulsion state:
  - the mainsail on its boom and the jib, both trimmed by wind angle on the
    **leeward side**: wind from starboard puts them to port, and from port to
    starboard;
  - **furled when motoring or moored**: sail cover on the boom, jib rolled on the
    forestay;
  - the **spinnaker** when the state says so: forward of the mast and beyond the
    bow, pole to windward, swung to leeward on a broad reach and centred dead
    downwind, with the jib rolled away while it flies;
  - trim eases smoothly, and entering the deck snaps to the current state.
- **Engine sound.** It is a seamless 2 s loop on the existing **SFX** bus, so the
  SFX and Master volumes apply. There are two sample-aligned layers:
  - open air, −6 dB, on deck;
  - low-passed, −16 dB, in the cabin and at the chart.

  The layers are cross-faded over 1.5 s and never restarted on scene changes
  (verified frame by frame). They fade out when the sails are set, on arrival and
  in the main menu.

### Saves

- **Format version 3** adds the wind seed and the full propulsion and controller
  state. Loading restores the mode exactly; it is not re-decided.
- **Iteration 002 saves (v2) mid-voyage** load with seed 1 and a fresh controller,
  which decides at once from the wind at the saved position and time.
- **Iteration 001 saves (v1)** still load (1 → 2 → 3).
- **No offline travel:** no time passes and the boat does not move on loading.
- **Validation** rejects unknown modes and out-of-range values.

## 2. Architectural changes

- **New data and logic:**
  - `WindField` (`src/weather/`), the only wind source;
  - `PropulsionState` and `PropulsionController` (`src/sailing/`), plain data and
    pure logic;
  - `VesselProfile` now holds the polar, spinnaker, engine and controller
    parameters. `cruising_speed_kn` was removed.
- **`SessionState`:** `vessel_speed_kn` was replaced by `propulsion` and `wind_seed`.
- **`GameSession`:**
  - the `propulsion_changed` signal;
  - the Simulation-only `set_propulsion()`;
  - read-only accessors.

  It remains the only writer.
- **`Simulation.advance()`** was rewritten around evaluation points, as an
  event-driven piecewise-constant integration. Added:
  - `evaluate_propulsion()`;
  - `estimate_route_seconds()` and `get_eta()` (cached, invalidated on a new
    voyage, a course change or a loaded game);
  - `get_wind_at()` and `get_current_heading()`.
- **`AudioManager`:** generic named loops (`play_loop`, `stop_loop`,
  `is_loop_playing`) with fades. `App.update_engine_audio()` maps state and screen
  to engine volume.
- **Presentation reads state, never decides:**
  - `WindLayer` (chart);
  - `SailRig` (deck);
  - the HUD's wind and propulsion lines.
- **Shutdown:** `GameSession._exit_tree` now also releases `WindField` and
  `VesselProfile`. The process exits with no leaked objects or resources.

The details are in [ARCHITECTURE.md](../../technical/ARCHITECTURE.md), section "Wind, sailing
performance and propulsion".

## 3. Files created or modified

**New:**
- `data/weather/wind_climate.json`: anchors and wave parameters.
- `src/weather/wind_field.gd`: wind query, lattice, conventions.
- `src/sailing/propulsion_state.gd`, `src/sailing/propulsion_controller.gd`.
- `src/navigation/wind_layer.gd`: chart arrows, tint, caching.
- `src/boat/sail_rig.gd`: mainsail, jib, spinnaker.
- `assets/audio/placeholder/engine_hum.wav`, `engine_hum_muffled.wav` (+ `.import`
  with forward loop).
- `tests/suites/test_wind.gd`, `test_sailing.gd`, `test_sailing_presentation.gd`.
- `ITERATION_003_REPORT.md`, and screenshots `docs/screenshots/19_…` to `24_…`.

**Modified:**
- Core:
  - `src/core/session_state.gd`, `game_session.gd`, `simulation.gd`;
  - `src/persistence/save_manager.gd` (v3 migration).
- Navigation and vessel:
  - `src/navigation/vessel_profile.gd`, `data/vessel/starter_sloop.tres`;
  - `src/navigation/geo_math.gd` (`rhumb_bearing`);
  - `src/navigation/map_view.gd`, `world_map.gd`, `world_map.tscn` (wind layer,
    legend, toggle, readouts, ETA texts).
- UI, app and audio:
  - `src/ui/hud.gd`, `hud.tscn` (propulsion and wind lines, ETA);
  - `src/app/app.gd` (engine audio, departure estimate);
  - `src/audio/audio_manager.gd` (named loops);
  - `src/boat/exterior.tscn` (SailRig replaces SailCover).
- Tests:
  - `tests/test_runner.gd` (wind fixtures, new suites, exit cleanup);
  - `tests/suites/test_simulation.gd`;
  - `tests/restart_check.gd` (checks the propulsion state; no longer assumes 5 kn).
- Tools and docs:
  - `tools/generate_placeholder_audio.py` (engine loops);
  - `README.md`, `docs/technical/ARCHITECTURE.md`, `assets/audio/placeholder/README.md`;
  - refreshed `docs/screenshots/*`.

## 4. Tests executed

| # | What | Command |
|---|---|---|
| T1 | Import / compile | `godot --headless --path . --import` |
| T2 | Headless test suite | `godot --headless --path . res://tests/test_runner.tscn` |
| T3 | Rendered suite + screenshots | `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tests/test_runner.tscn -- --screenshots=DIR` |
| T4 | Restart persistence (2 processes) | `godot --headless --path . res://tests/restart_check.tscn -- --phase=write`, then `--phase=read` |

New suites:

- **`test_wind`:** conventions (FROM/TO, vectors, signed angles, compass names),
  determinism and seeds, range, spatial and temporal continuity, regional
  plausibility, query speed, the polar (head to wind, top speed, marginal, symmetry,
  monotonic, spinnaker angles and bonus).
- **`test_sailing`:**
  - **Controller:** the start decision, a sustained drop, a stall, short lulls,
    the engine stopping, hysteresis in both directions, no cycling, course-change
    reset and spinnaker state.
  - **Simulation timeline:** step independence at 1×, 5×, 20×, sleep and one step,
    with sail ↔ engine changes; ETA accuracy (wind and calm); warnings with
    variable speed; course change at sea.
  - **Persistence:** save/load of propulsion, continuing identically, rejection
    of invalid data, v2 migration with no offline travel.
- **`test_sailing_presentation`** (real `App`):
  - sails to port or starboard by wind side and eased by angle;
  - the spinnaker is up immediately on entering the deck (state-driven), and
    taken down when the wind comes forward;
  - furled when motoring;
  - engine loops: playing, SFX bus, seamless loop mode, not restarted across a
    scene change, quieter and muffled inside, stopped when sailing, on arrival and
    in the menu;
  - HUD texts;
  - chart overlay, legend, toggle, cursor readout and pan cost.
- **Earlier suites** run unchanged with a documented **calm-wind fixture**
  (`use_calm_wind()`): in a flat calm the boat motors at exactly 5 kn from
  departure, so their exact timing expectations remain valid.

## 5. Actual test results

- **T1:** no errors.
- **T2: 614 checks passed, 0 failed**, exit code 0, no leaks at exit. Checks per
  suite:

  | Suite | Checks |
  |---|---|
  | data model | 29 |
  | routing | 99 |
  | simulation | 82 |
  | wind | 41 |
  | sailing | 55 |
  | save manager | 28 |
  | voyage persistence | 36 |
  | settings/audio | 37 |
  | sailing presentation | 34 |
  | gameplay flow | 173 |

- **T3: 618 checks passed, 0 failed**, exit code 0. I reviewed the screenshots:
  - close reach;
  - beam reach with the wind from port (sails to starboard);
  - spinnaker on a broad reach and running;
  - motoring with sails furled;
  - cabin HUD while motoring and while sailing;
  - chart wind over Europe and zoomed in.

  The rendering problems they showed were fixed before the final run:
  - an oversized spinnaker;
  - a jib that matched the deck colour;
  - a blocky tint;
  - a tint texture that was freed before it was drawn.
- **T4:** both phases passed (14 checks, including the restored propulsion state),
  exit code 0.
- **Performance:**
  - a wind query takes 10–20 µs;
  - the first overlay draw takes 48 ms headless and 160 ms on software OpenGL;
  - panning with wind on costs about 7–9 ms per frame headless;
  - on llvmpipe, panning measured about 46 ms per frame without wind and 57–60 ms
    with it, down from about 76–81 ms before the arrows were batched and the tint
    image cached. Most of that is the software rasteriser.

  Real-GPU performance was **not measured**.

## 6. Known problems and limitations

- **Untested conditions:** not run on Windows; no human play; no audio heard. The
  engine sound's character, loudness balance and fades are verified only through
  player state and volumes.
- **The wind is synthetic.** It is plausible but not real weather or a forecast.
  The seed is always 1. The lattice clamps outside 27°W–39°E and 31–73°N.
- **No tacking.** A course leg straight into the wind is motored. The controller
  needs up to 10 minutes (stall delay) before the engine starts; until then the boat
  makes almost no way.
- **ETA ignores hysteresis.** It uses "sail if the potential is ≥ 3.5 kn, else
  motor" and the expected wind. It does not model the controller's averaging and
  delays, so in changeable wind it can be off by more than the 0.7 % seen in a
  steady wind. It refreshes every 2 nm or 30 game minutes.
- **Warning horizon depends on speed.** It uses the current speed, so a voyage that
  speeds up after a warning point arrives at the area a little sooner than 5 hours.
- **The spinnaker can cover the bow label** and part of the deck while it flies.
  The eased mainsail can reach the top of the view on deep downwind angles.
- **Chart arrows are sparse at the widest zoom.** Lattice points on land are skipped,
  so enclosed seas such as the Baltic show only a few arrows; zooming in fills them.

## 7. Features deliberately excluded

These were out of scope:

- manual sail or engine control, reefing and sail damage;
- tacking or gybing manoeuvres;
- fuel, engine wear, batteries;
- boatyards and repairs;
- currents, waves and tides;
- wind-dependent heel or motion of the deck;
- real weather data, forecasts and paid or external services;
- a debug or cheat UI for players (wind fixtures exist only in tests).

## 8. Architectural concerns for future iterations

- **Time-varying weather areas.** The demonstration weather areas and the wind
  field are separate models. A future real weather system should drive both, so
  warnings come from the same wind.
- **Manual control or tacking.** Either would extend `PropulsionState` (an override
  or tack state) and the router or controller. The presentation layers (HUD, rig,
  audio) already read only the state.
- **Bigger vessel profiles.** If more vessels are added, the polar could become a
  table resource. The current `Curve` plus formula is enough for one boat.
