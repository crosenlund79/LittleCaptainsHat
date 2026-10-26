# Iteration 001: Core Game Foundation & Visual Identity (Report)

Engine: Godot **4.7.2 stable** (official Linux build), GDScript, Compatibility renderer.
Test environment: Linux container, Godot headless, plus Xvfb with Mesa llvmpipe
(software OpenGL 4.5) for rendered runs. **No Windows machine was available.**

## 1. Implemented features

- **Visual identity.** "The Harbor Line" logo: a sloop above a single course line that
  sweeps to a brass waypoint. Wordmark in Barlow SemiBold, converted to outlines.
  - Primary logo (dark and light variants), compact symbol, and app icon (symbol on a
    navy tile), all SVG with transparent PNG exports.
  - Restrained palette (navy, teal, seafoam, cream, brass) and a shared Theme for buttons,
    sliders, panels, dialogs, slot entries, toasts and prompts.
  - The logo is used on the main menu, the static boot splash, the README, the HUD and
    pause menu (symbol), and as the project and window icon.
- **Application shell.** One main scene with a screen host, a fade transition router,
  HUD, modal stack and notification layers.
- **Main menu.**
  - New Game, Continue and Settings.
  - Continue is disabled without a valid save and shows the newest slot.
  - Load Game is disabled while all slots are empty.
  - Quit stops audio, then quits.
- **Boat.** A ~33 ft sloop in two separate scenes, built from placeholder geometry:
  - *Cabin*: companionway steps, engine box, galley, nav station, two settees and table,
    storage lockers, bulkhead with doorway, V-berth.
  - *Deck*: cockpit with benches and grating, wheel on a pedestal, coachroof with
    companionway hatch, mast with boom and rigging, side decks, foredeck, anchor locker,
    pulpit and pushpit, swim ladder. The boat is moored at a pontoon.
- **Player.** `CharacterBody2D` token with WASD/arrows, normalized diagonals,
  constant speed, collision and spawn points.
- **Interaction framework.**
  - Proximity sensor focuses the nearest interactable (name tie-break) and highlights it.
  - HUD prompt shows `[E] verb`.
  - Messages need no code (an `Interactable` with a `message`).
  - Bed, helm, navigation table and companionway (both directions) all work.
- **Chart (world map).**
  - Real coastline data (Natural Earth 1:10m, clipped to the Western Baltic and simplified),
    graticule with labels, country and sea labels.
  - Mercator projection kept separate from the geographic data.
  - Zoom (wheel, keys, buttons), pan (drag, keys) and "Find boat".
  - Copenhagen and Kiel ports with stable ids; boat marker at the current location.
  - Selecting a port shows its details and distance; plot, change and clear the course.
  - The course is drawn as a dashed line with an arrow, and the cursor's lat/lon is shown.
- **Planned routes.** Origin, destination and a waypoint list (serialized, no UI yet);
  stored in the session and saved.
- **HUD.** Area and location, planned route with distance, interaction prompt,
  notifications and a Menu button.
- **Pause menu.** Resume, Save, Load, Settings and Return to Main Menu.
  - Gameplay pauses and Esc goes back one level.
  - Settings returns to the pause menu.
  - "Unsaved progress" confirmations before loading or leaving.
- **Save/load.**
  - Three slots with metadata (time, area, location, destination).
  - Overwrite confirmation and safe writes (tmp, verify, `.bak`, rename).
  - Validation of every field; detection of corrupted and unsupported saves; atomic apply.
- **Settings.**
  - Five bus sliders (percent, 0 = mute) with test buttons, applied live.
  - Windowed, Fullscreen and Borderless window modes; VSync; interface scale 80–130%.
  - Restore Defaults, Apply, and Back with a discard confirmation.
  - Stored in `user://settings.cfg`, separate from saves, with validation and defaults.
- **Audio.**
  - Master, Music, Ambience, SFX and UI buses.
  - AudioManager with music (with fades), replaceable looping ambience, and a pooled
    one-shot player for SFX and UI.
  - Automatic UI click on buttons; per-area ambience.
  - Temporary synthetic test sounds, clearly labelled.
- **Documentation and tests.** README, ARCHITECTURE, this report, a self-contained test
  runner with 4 suites, and a two-process restart check.

## 2. Important implementation decisions

- **4 autoloads** (Settings, Audio, GameSession, SaveManager). Scene switching is not
  global: it lives in the `App` shell, the only code that switches screens. Screens
  communicate by signals that `App` wires up when it creates them.
- **Single screen host.** The router frees the old screen before creating the new one,
  so duplicate players are impossible by construction (also verified by tests).
- **State-first areas.** The boat area is session state. A scene shows it, and the
  player position is mirrored into the session every physics frame, so the state stays
  valid while the chart (or any other screen) is shown.
- **The chart is a full screen, not an overlay.** Esc closes it; saving happens from
  the pause menu in the boat.
- **SaveManager is independent of GameSession.** It takes and returns `SessionState`
  objects, which keeps it testable and lets `App` decide when to apply a load.
- **Real geography.** Natural Earth public-domain land polygons instead of invented
  coastlines, credited as simplified and "not for navigation".
- **Generated, reproducible assets.** The Theme (`tools/build_theme.gd`), logo SVGs
  (`tools/make_branding_svgs.py`, needs Python and fontTools), PNG exports
  (`tools/export_branding.gd`, uses Godot's own SVG renderer) and placeholder sounds
  (`tools/generate_placeholder_audio.py`) all come from scripts. The game uses the SVGs
  directly; the PNGs are not required at runtime except for the boot splash.
- **Interface scale** scales the UI CanvasLayers only, not the world.
  `UiScaleLayer` resizes its children to `viewport / scale` so layouts stay on screen.
- **Esc handled in one place** (`App._unhandled_input`) to avoid double handling.
- **Compatibility renderer**, for broad Windows GPU support in a 2D game.
- The two boat scenes were produced by a one-off layout generator script (not
  committed). The `.tscn` files are now the source of truth and are editable in Godot.

## 3. Relevant created files

```
project.godot, default_bus_layout.tres, .gitignore, .gitattributes, .editorconfig
README.md, docs/technical/ARCHITECTURE.md, ITERATION_001_REPORT.md, docs/screenshots/*.png
assets/branding/  next_harbor_logo(.svg, _on_light.svg), next_harbor_symbol.svg, next_harbor_icon.svg, png/*
assets/fonts/     Barlow-{Regular,Medium,SemiBold}.ttf, OFL.txt
assets/ui/        next_harbor_theme.tres
assets/audio/placeholder/  5 temporary .wav files + README.md
data/navigation/  port_catalog.tres, ports/{copenhagen,kiel}.tres, western_baltic_land.json
src/app/          app.gd, app.tscn, scene_router.gd
src/core/         game_session.gd, session_state.gd
src/boat/         boat_area.gd, boat_fixture.gd, interior.tscn, exterior.tscn
src/player/       player.gd, player.tscn
src/interaction/  interactable.gd, interaction_sensor.gd
src/navigation/   port_data.gd, port_catalog.gd, planned_route.gd, geo_math.gd, map_projection.gd,
                  map_view.gd, world_map.gd, world_map.tscn
src/ui/           ui_scale_layer.gd, modal_panel.gd, modal_stack.gd, confirm_dialog.(gd|tscn),
                  pause_menu.(gd|tscn), settings_menu.(gd|tscn), save_load_menu.(gd|tscn),
                  main_menu.(gd|tscn), hud.(gd|tscn), toasts.gd
src/audio/        audio_manager.gd
src/persistence/  save_manager.gd
src/settings/     settings_manager.gd
tests/            test_runner.(gd|tscn), restart_check.(gd|tscn), suites/*.gd
tools/            build_theme.gd, export_branding.gd, make_branding_svgs.py, generate_placeholder_audio.py
```

(`*.uid` and `*.import` files generated by Godot are committed as recommended for Godot 4.4+.)

## 4. Tests executed

All commands were run from the repository root with the Godot 4.7.2 Linux binary.

| # | Command | What it covers |
|---|---|---|
| T1 | `godot --headless --path . --import` | Every resource and script imports without errors |
| T2 | `godot --headless --editor --path . --quit-after 300` | Project opens in the editor without errors |
| T3 | `godot --headless --path . --quit-after 200` | Game boots to the main menu without errors |
| T4 | `godot --headless --path . res://tests/test_runner.tscn` | Full suite, headless (206 checks) |
| T5 | `xvfb-run godot --path . --rendering-driver opengl3 res://tests/test_runner.tscn -- --screenshots=DIR` | Full suite with a real window and rendering (210 checks) + screenshots |
| T6 | `godot --headless --path . res://tests/restart_check.tscn -- --phase=write`, then `--phase=read` in a **new process** | Settings and saves survive an application restart |

The end-to-end suite drives the real `app.tscn`. Key presses go through the engine
input pipeline (`Viewport.push_input`), buttons are clicked with simulated mouse
events at their on-screen position, and movement uses held input actions.

## 5. Actual test results

- T1, T2, T3: no errors or warnings.
- T4: **206 passed, 0 failed**, exit code 0. Window-mode checks are skipped because
  headless has no window.
- T5: **210 passed, 0 failed**, exit code 0. The VSync checks were **skipped** because
  this driver does not support VSync control (see below).
- T6: write phase exit 0; read phase **PASS** (9/9), exit 0.
- The only error lines in the logs were expected or environmental:
  - the deliberate failed-write test (`Cannot write user://test_saves/blocked/...`);
  - "All audio drivers failed, falling back to the dummy driver" (no sound device in the container);
  - "changing V-Sync mode is not supported by the graphics driver" (Xvfb/llvmpipe).

### Verified behaviour (by automated checks)

| Area | Verified |
|---|---|
| Application | project opens (editor), main menu loads, logo displayed, New Game starts in the cabin, Continue disabled without saves / loads the newest save, Quit exits the process with code 0 |
| Boat | movement left/right, normalized diagonals, collision with furniture, hull, berth, lifelines and pulpit; prompts appear and disappear; bed and helm messages; nav table opens the chart; companionway works both ways with correct spawn points; 3 round trips leave exactly 1 player and 1 screen |
| Interaction | closest of two interactables is focused, focus is stable, switches when moving |
| Map | opens/closes (Esc), zoom (API, mouse wheel), pan (mouse drag, keyboard), port selection by clicking its marker, plot, cannot plot to current port, clear, re-plot; HUD shows the route; player returns to the nav table position |
| Persistence | save to slots 1 and 2, overwrite with confirm/cancel, metadata, load restores area, position and route, empty slot disabled, damaged slot reported, failed load leaves state and scene untouched; unit tests for missing, corrupted, unsupported, invalid, incomplete and empty files, `.bak` fallback, failed write keeps the old save; New Game leaves slots untouched |
| Settings | slider applies to the bus immediately, 0% mutes, clamping, Apply writes the file, Restore Defaults, discard on Back reverts, invalid config values fall back, survives a process restart; window modes Fullscreen / Borderless / Windowed applied under Xvfb, windowed size restored |
| Audio | all 5 buses exist and route to Master; players on the right buses; one-shot pool does not grow; ambience start/replace/stop; music play/stop |
| Menus | Esc opens pause and pauses the game, player cannot move while paused, Resume unpauses, Settings → Back returns to the pause menu, Esc navigates back through dialogs, return to main menu with confirmation, UI scale 130% keeps menus on screen |

### Verified visually (screenshots from T5, reviewed)

Main menu, settings, cabin, berth prompt, chart with route, deck, pause menu at 100%
and 130% UI scale, settings discard dialog, save and load dialogs. A selection is in
`docs/screenshots/`.

## 6. Known problems

- **VSync on/off could not be verified**: the test display driver ignores swap
  control. The code calls `DisplayServer.window_set_vsync_mode`; this needs checking on Windows.
- **No audio was heard.** The container has no sound device. Bus volumes, mute and
  routing were checked through `AudioServer`, but actual audibility, loudness balance and
  loop smoothness of the placeholder sounds were not.
- **Not run on Windows**, and no Windows export was made. Window-mode behaviour on a
  real multi-monitor Windows desktop, DPI scaling and exclusive fullscreen are unverified.
- Mouse and keyboard were simulated through the engine's input pipeline, not by a human;
  feel (speed, collision smoothness, readability at different window sizes) needs a playtest.
- The straight course line from Copenhagen to Kiel crosses Zealand. This is expected for
  "origin → destination only" routes, but may look odd.
- While the chart has keyboard focus on a side-panel button, the arrow keys both move
  UI focus and pan the chart.

## 7. Incomplete or deliberately limited features

- Waypoints: present in the data model and save format, but cannot be placed on the chart.
- No saving from the chart screen (close it first). No autosave (not requested).
- Placeholder audio only, and no music in normal play (music is only audible through the test button).
- Boat art is simple placeholder geometry; no character animation.
- Out-of-scope systems (travel, time, weather, economy, needs, etc.) were not started.

## 8. Architectural concerns worth reviewing

- **`App` as coordinator** is about 230 lines now. As flows grow (travel, port
  services), consider splitting game-flow logic (new/load/continue) from menu wiring
  before it turns into a "god object".
- **Interaction routing by id** in `BoatArea` (a `match` on `interaction_id`) is fine
  for four objects. With many interaction types, a small handler resource or component
  per interactable would scale better.
- **Position written every physics frame** to `GameSession` is simple and robust, but
  it marks the session "unsaved" as soon as a new game starts. A different dirty-tracking
  rule may be wanted once autosave exists.
- **Area ids exist in two places**: `SessionState.BOAT_AREAS` and `app.tscn`'s
  `boat_area_scenes`. `App` reports a mismatch at startup, but it is still duplication.
- **Single region map.** `MapView` takes one coastline JSON. Worldwide coverage will need
  tiling or level-of-detail data, and probably a different projection strategy near the poles.
- **Theme by generator.** Editing the `.tres` in the editor would be overwritten by the
  next generator run. Choose one source of truth going forward.
