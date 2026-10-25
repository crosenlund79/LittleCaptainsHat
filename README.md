<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/branding/little_captains_hat_logo.svg">
    <img src="assets/branding/little_captains_hat_logo_on_light.svg" alt="Little Captain's Hat" width="420">
  </picture>
</p>

# Little Captain's Hat

*Small boat. Wide world. Hold onto your hat.*

A cozy 2D sailing adventure about making a home on the water and exploring
the world at your own pace. You live aboard a small cruising sailboat, plan
voyages and prepare for the next destination; the game is not about steering
across every mile of ocean. Sailing is mostly peaceful, the weather can turn
dangerous, and every mishap can be recovered from.

**Little Captain's Hat is the provisional name.** The game was developed as
**Next Harbor** up to Iteration 006. The iteration reports up to
[ITERATION_006_REPORT.md](ITERATION_006_REPORT.md) are historical documents
and keep the old name. Saves from Next Harbor can be imported (see *Saves*).

Current version: **0.100a, Visual Identity V01: A Little Personality**
(see `VISUAL_IDENTITY_V01_REPORT.md`):
- the **captain's hat**: it hangs on a hook in every cabin. Wear it (E at the
  hook), take it off (H), and mind the wind on deck: in strong wind it may blow
  away, after a fair warning ("Better hold onto your hat!"). Replacements cost
  €15 at the harbour grocery store;
- seven **secret achievements** about the hat, hidden in the Captain's Log until
  you find them, and short *Notable moments* in the log;
- the new name, logo and a hand-lettered display font (Patrick Hand) for the
  title and decorative headings; Barlow stays the font for everything you read
  closely;
- the game keeps its saves in its own folder, and can copy saves over from Next
  Harbor.

Version numbers follow the convention 0.100a, 0.100b (fixes within a
milestone), 0.101a (the next feature milestone), 0.200a (a large step); see
`src/app/game_version.gd`.

Iteration 006: Making Waves built the loop Sail, arrive, record, earn renown,
publish, get paid, and sail again:
- a **Captain's Log** (**L**, or the pause menu) records your distance,
  voyages, harbours visited, longest passage, rescues and recent passages;
- 16 optional **sailing objectives**, tracked automatically, pay **renown**
  (lifetime renown never decreases);
- **Publish travel update** turns unpublished renown into money (€2 per
  renown), in harbour, from the log or the work station;
- **163 European harbours** (from 15), with a decluttered chart and a
  *Find a harbour…* search.

Earlier iterations built:
- 005c: remote work (€25 an hour) and the paid grocery store;
- 005b: boat condition and weather damage, rescue at sea (€1,000), money, food
  and water, and the October 24 playtest corrections;
- 005a: one deterministic weather model with moving gales, thunderstorms and
  seasonal tropical cyclones;
- 004b: the owner's cat artwork, the refined catamaran cabin, developer guides;
- 004: three boats, the boatyard, sprite-ready vessel art;
- 003b: ship's cat or dog, adjustable sleep, sail check, chart sidebar, simulation
  pause;
- 003: wind, sails, automatic propulsion;
- 002: sea routes, voyages, game clock, weather warnings;
- 001: boat, menus, save/load, settings, audio.

Iteration 005b adds:
- **boat condition** (0-100 %, per boat): Sound, Worn, Damaged, Critical. It is
  shown in the HUD and the boatyard, and drawn as scuffs, cracks and damaged
  planking on deck and below.
- **weather damage**: gales, storms and squall gusts cost condition while
  underway. Ordinary weather and "strong winds" do not. The result is the same
  at any speed, while sleeping and after loading.
- **rescue at sea**: at 0 % one rescue brings you, the boat and the companion
  back to Copenhagen. The boat is repaired, and €1,000 is deducted (never more
  than you have).
- **money**: €10,000 to start, shown in the HUD. The rescue fee is the only cost
  for now.
- **food and water**: 14 days of each, one day used per game day (in harbour
  too). A **provisions station** at every galley shows the days left. The food
  crates and water cans drawn there empty as they are used. There are warnings
  when low, and no departure with empty stores.
- **harbour services**: free **Repair vessel** in the boatyard. Restocking became
  the paid grocery store in Iteration 005c.
- **playtest corrections**: a better-proportioned Halcyon 40 cabin with a
  clearly marked exit; the cat no longer blocks stations (face the cat to pet
  it); a fixed-size boatyard panel.
- **developer test tools** (F9, only when run from the Godot editor): test
  storms, squalls, condition levels, the real rescue, stores and time, for
  [WINDOWS_ACCEPTANCE_I005.md](WINDOWS_ACCEPTANCE_I005.md).

![Rescued at Sea](docs/screenshots/97_rescue_dialog.png)
![Provisions in the cabin](docs/screenshots/90_provisions_after_sleep.png)
![Storm damage on the trimaran](docs/screenshots/88_damage_petrel_36_15.png)

Iteration 005a added:
- **one weather model** (`WeatherModel`): every wind value in the game, from the
  sails to the ETA, comes from it. The old demonstration circles are gone;
- **moving, irregular weather areas**: strong-wind and gale areas over the
  Atlantic, Biscay, North Sea, Baltic, the Mistral and the Meltemi. They form,
  strengthen, drift, change shape and fade over a day or two;
- **thunderstorms**: areas of thunderstorm risk where storm cells develop, peak
  and dissipate within hours, with outflow winds and gust bursts. Strong cells
  are **severe squalls**;
- **hazard levels**: Normal, Caution, Dangerous, Severe, from sustained wind and
  gusts;
- **warnings** at the boat, for storms nearby and for weather up to about
  6 hours ahead on the course. Each is given once, and again only if it gets
  worse. They wake you and drop time to 1×. Storms that have not formed yet
  cannot be foreseen;
- **tropical cyclone seasons** per ocean basin and hemisphere, following the game
  date, and the occasional active cyclone, never in European waters;
- **the chart's weather overlay and Weather tab**: real outlines with labels,
  glyphs and outline styles (not colour alone), a legend, and the hazards along
  the course;
- **storm sounds**: a wind loop that rises with the wind and distant thunder near
  storms (placeholders, on the Ambience bus).

Weather hazards do not damage the boat yet: there is no boat condition, damage,
rescue, money or provisions (planned for Iteration 005b).

![Weather on the chart near Copenhagen](docs/screenshots/70_weather_chart_copenhagen.png)
![The Weather tab with its legend](docs/screenshots/71_weather_tab.png)

Iteration 004b added:
- **the ship's cat drawn by the owner** (`Visuals/Cat/`). It rests, naps on its
  back, stretches now and then, looks up when you come close, and sits up purring
  with hearts when petted. The poses are configured in data, so the art can be
  replaced without code;
- **a refined Halcyon 40 cabin**: a clearly drawn saloon door to the deck, an
  L-shaped galley, a U-settee with table, a nav station, a full-width owner's
  berth, and a guest cabin with heads, shower and bunk;
- **developer guides** in [DEV_GUIDES/](DEV_GUIDES/README.md): practical
  instructions for sprites, companion poses, vessel art, audio and future
  modding, also readable in the game from the main menu in development builds.

Iteration 004 introduced the Starling 33 monohull, the Halcyon 40 catamaran and
the Petrel 36 trimaran, the boatyard, and named visual slots with procedural
fallback art.

![The ship's cat in its four poses](docs/screenshots/54_cat_pose_resting.png)
![The refined catamaran cabin](docs/screenshots/51_catamaran_cabin.png)
![The boatyard](docs/screenshots/40_boatyard_halcyon_40.png)
![The catamaran with its spinnaker set](docs/screenshots/44_deck_spinnaker_halcyon_40.png)
![The trimaran on a beam reach](docs/screenshots/43_deck_sailing_petrel_36.png)
![The catamaran's saloon and hulls](docs/screenshots/42_cabin_halcyon_40.png)

## Engine

- **Godot 4.7.2 (stable)**, GDScript only, no plugins or add-ons.
- Renderer: *Compatibility* (OpenGL 3), the most widely supported option for 2D on Windows.
- Reference resolution 1920×1080, stretch mode `canvas_items` / aspect `expand`.
- Target platform: Windows desktop (developed and tested on Linux, see the iteration reports).

## Opening and running

1. Install [Godot 4.7.x](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager choose **Import**, select this folder's `project.godot`, and open it.
   The first import takes a few seconds.
3. Press **F5** (Run Project). The main scene is `res://src/app/app.tscn`.

From the command line:

```sh
godot --path .                                           # run the game
godot --headless --path . res://tests/test_runner.tscn   # run the automated tests
```

## Controls

| Action | Keys / mouse |
|---|---|
| Move | **W A S D** or **arrow keys** |
| Interact | **E** (e.g. pet the cat or dog, sleep at the berth, check the sails at the helm, visit the boatyard from the pontoon side of the deck) |
| Boatyard: browse boats | **Up / Down** (or click a boat), **Move aboard …** to choose |
| Pause menu / back | **Esc** |
| Pause / time acceleration | **Pause** and **1× / 5× / 20×** in the time bar at the top (on deck, in the cabin and on the chart). Pause stops the clock; Pause again, or a speed, continues |
| Chart: pan | drag with the mouse, or **W A S D** / arrows |
| Chart: zoom | mouse wheel, **+ / −**, **Page Up / Page Down**, or the toolbar buttons |
| Chart: choose destination | click a port, then **Plot course to …** |
| Chart: add a waypoint | press on the course line and drag |
| Chart: move a waypoint | drag the diamond-shaped waypoint marker |
| Chart: remove a waypoint | right-click it, or select it and press **Delete** / **Remove waypoint** |
| Chart: show/hide wind | **Wind** switch in the toolbar |
| Chart: sleep | **Sleep** button in the side panel |
| Sleep dialog: duration | **<** / **>** buttons (or Left / Right): 1–12 hours |
| Cat beside a station | stand at the station to use it; **face the cat** (the arrow on your token) to pet it |
| Provisions | **E** at the galley's provisions station (every cabin) |
| Captain's hat | **E** at its hook in the cabin: put it on or hang it up. **H** aboard: take it off (under your arm) or put it back on |
| Captain's Log | **L** (aboard or on the chart), or **Captain's Log** in the pause menu: Log, Harbours and Objectives tabs; *Publish travel update…* |
| Chart: find a harbour | type in **Find a harbour…** on the Course tab, then click a result (works for harbours hidden at the current zoom) |
| Developer test tools | **F9** (only when run from the Godot editor; see [WINDOWS_ACCEPTANCE_I005.md](WINDOWS_ACCEPTANCE_I005.md)) |

Menus work with the mouse and keyboard (Tab / arrow keys to move focus, Enter / Space to press).

## Playing a voyage

1. **Plan.** At the **navigation table** in the cabin, press **E** to open the chart of
   Europe. Click a destination port and press **Plot course to …**. The game
   calculates a sea route around coasts and islands, shows its distance and an
   estimated time with the expected wind, and lists any weather along it. The
   chart shows the wind as arrows (pointing where the wind blows) coloured by
   strength; the cursor readout shows the wind under the mouse.

   The sidebar has a header that is always visible (voyage status, distance, ETA)
   and three tabs:
   - **Course:** destination, course and waypoints;
   - **Weather:** the wind at the boat and the weather along the course;
   - **Details:** position, projection and help.

   Its footer always holds **Apply/Change course**, **Discard**, **Set sail**,
   **Sleep** and **Back**.
2. **Adjust (optional).** Drag the course line to add waypoints, drag waypoints to
   move them, right-click to remove them. The legs on either side are recalculated
   at once. A waypoint on land, or a leg that cannot be sailed, is marked **BLOCKED**
   with a red cross and explained in the side panel; such a course cannot be applied.
   Nothing changes until you press **Apply course**. **Discard** returns to the
   current course.
3. **Depart.** Take the **helm** on deck (or press **Set sail** on the chart) and
   confirm. The autopilot sails the course and the boat decides for itself how to
   make way:
   - **Sailing** speed depends on the wind's strength and angle: up to about 10 kn,
     about 3.5 kn in marginal conditions, nothing head to wind.
   - On deck the mainsail and jib are trimmed to the wind on the leeward side.
   - With the wind 115–180° off the bow, the **spinnaker** is set ahead of the bow.
   - When the wind stays too light (averaged over about an hour below 3.5 kn), or
     the boat is becalmed or head to wind for 10 minutes, the **engine** starts:
     5 kn, sails furled, engine sound.
   - The engine stops again once the wind has been good (above 6 kn of sailing
     speed) for a while.

   The HUD shows destination, distance to go, a wind-aware ETA, speed, sail or
   engine with the reason, and the local wind. The pontoon is left behind and the
   chart shows the boat's actual position.

   **Check sail configuration** at the helm (press **E** there while underway) makes
   the boat assess the current heading and wind at once. If the conditions are now
   clearly good or poor, sails or engine change straight away. It is a check, not an
   engine switch: it never forces a mode the conditions don't justify. The usual
   minimum times (15 min under sail, 30 min under engine) still apply, so it cannot
   make the boat switch back and forth. A change of course at sea triggers the same
   check automatically.
4. **Live aboard.** Walk around the cabin and deck while the voyage continues.
   1 real second is 1 game minute at **1×**. Use **5×** or **20×** to go faster, or
   **Pause** to stop the clock: the boat, wind and time wait while you look around
   or plan on the chart. Sleeping still works while paused (it moves time on by the
   hours you choose) and the game stays paused afterwards.
5. **Look after the boat and the crew.** The HUD shows the hull condition,
   money, food and water. Check the stores at the galley's provisions station.
   In harbour, the boatyard repairs the boat for free. Food and water are
   bought at the **grocery store** on the pontoon (€10 per missing day, food and
   water counted together, up to 14 days each), also reachable from the
   provisions panel and the boatyard. Earn money with **remote work** at the
   cabin's work station while moored: 1–8 hours at €25 per hour; time passes
   and the stores are used as usual. Heavy weather
   at sea costs condition. If it reaches zero you are rescued back to
   Copenhagen for €1,000.
6. **Sleep.** Use the berth in the cabin, or the **Sleep** button on the chart. Choose
   1–12 hours with the arrows. The dialog shows when you will wake. The boat sails
   on while you sleep, and you are woken early on arrival or when a weather warning
   comes in. Wherever you went to sleep, you wake in the cabin beside the V-berth.
7. **Weather.** The chart shows the weather as it is now: strong-wind and gale
   areas, thunderstorm-risk areas, thunderstorms and (outside Europe) tropical
   cyclones, each with its outline, label and symbol, and a legend in the
   Weather tab. Weather moves and changes with time. The boat sails in that
   weather: a gale is a lot of wind. A warning appears with **View chart** and
   **Dismiss** when the weather at the boat becomes hazardous, when a
   thunderstorm is close, or when hazardous weather lies within about
   **6 hours of sailing** on the course. Accelerated time drops back to 1× and a
   sleep is cut short. The forecast only knows weather that already exists:
   a thunderstorm can form with little warning.
8. **Change course at sea.** Open the chart while underway, edit the remaining course
   or pick another destination, and press **Change course**. The new course starts
   where the boat is. If no sea route exists, the current voyage is kept unchanged.
9. **Arrive.** On arrival you get a notification, the HUD shows **Arrived at …**, and
   the next voyage starts from there.

## What works

- **Main menu** with the Next Harbor logo: New Game, Continue (most recent valid save),
  Load Game, Settings, Quit.
- **Three boats**, each with its own deck and cabin, player movement, collision and
  interactions (berth, navigation table, helm, companionway, boatyard):
  - **Starling 33**, the monohull you start with: up to 10 kn, 5 kn under engine;
  - **Halcyon 40**, a catamaran with a bridgedeck saloon and two hulls: fast reaching,
    poorer upwind, 6.5 kn under its twin engines;
  - **Petrel 36**, a trimaran with a central cabin hull and two floats: the fastest,
    up to 14 kn, 5.5 kn under its outboard.
- **Boatyard** (in harbour only): the station by the pontoon opens it. It shows each
  boat's preview, hull type, description, specs and a comparison table (top speed,
  speed in 12 kn of wind at 45°, 90° and 150°, engine speed), all computed from the
  boats' sailing data. Changing boats is free and keeps the time, the harbour, the
  companion and your progress; you step aboard on deck. Underway the boatyard is
  closed.
- **European chart** (Iceland to Cyprus, North Cape to North Africa) from Natural Earth
  coastlines. It has zoom, pan, "All Europe", "Find boat", a cursor coordinate readout
  and **163 harbours** from the Arctic to Cyprus (Iteration 006). Major harbours are
  shown at every zoom; smaller ones appear as you zoom in, and names never overlap.
  Every harbour can be found with the search on the Course tab.
- **Sea routing** that never crosses land, through straits such as the Øresund, Great
  Belt, Dover, Gibraltar and Bonifacio. Routes have editable waypoints,
  and distances are measured along the actual course.
- **Game clock** starting Friday 1 May 2026, 08:00 UTC, with 1× / 5× / 20× acceleration.
  It pauses with the pause menu and runs in the cabin, on deck and on the chart.
- **Voyages**: departure, continuous travel, arrival, sleeping, weather warnings and
  changing course at sea.
- **Weather** (Iteration 005a): one deterministic model for all of Europe and the
  tropical basins. Moving gale areas, thunderstorm risk areas with storm cells
  and gusts, seasonal tropical cyclones; hazard levels Normal / Caution /
  Dangerous / Severe; deduplicated warnings at the boat, nearby and along the
  course; storm sounds. The same weather at 1×, 20×, while sleeping and after
  loading.
- **Wind** for all of Europe (25°W–37°E, 33–72°N): deterministic and continuous,
  changing slowly with time, with plausible regional character. Examples: westerlies
  in the Atlantic, northerlies off Portugal, the Mistral and the Meltemi, and a
  lighter, more changeable Baltic. It is shown on the chart with arrows, a speed
  tint and a legend.
- **Sailing and motoring**: wind-dependent speed (up to ~10 kn), an automatic
  sail/engine choice with hysteresis, an automatic spinnaker, sails drawn on deck
  by wind angle and side, and an engine sound loop (loud on deck, muffled below,
  never restarting on scene changes, following the SFX volume).
- **Ship's companion**: on New Game you choose a **cat** or a **dog** (the cat is
  preselected). It lives in the cabin of whichever boat you sail and rests in a few
  spots of its own, moving to another spot every few game hours.
  - The cat is drawn with the owner's artwork in four poses: resting, napping on
    its back, stretching, and alert.
  - Walk up to it and it looks up. Press **E** to pet it: the cat sits up, purrs
    and shows hearts; the dog pants happily.
  - There are no stats, needs or bonuses; it is company.
- **Captain's Log** (Iteration 006): distance sailed, voyages, harbours visited (of
  163), arrivals, longest passage, rescues, lifetime and unpublished renown, the latest
  50 passages and the harbours visited, all taken from the real voyage events.
- **Objectives and renown**: introductory, exploration, challenge and weather
  objectives (for example: the first hundred miles, 5 harbours, a 200 nm passage,
  a passage without damage, arriving after heavy weather), plus first visits to new
  harbours. Each pays renown once (repeatable ones once per qualifying voyage).
- **Social-media income**: in harbour, *Publish travel update* converts all
  unpublished renown into money at €2 per renown, with a confirmation. Your
  lifetime renown stays.
- **Developer guides** (development builds only): a **Developer guides** button in
  the main menu's top-right corner opens the guides from `DEV_GUIDES/`.
- **Pause menu**, **save/load** (3 slots), **settings** (audio, display, interface scale),
  audio buses and placeholder sounds, as in Iteration 001.

## Saves

- Stored as JSON in the game's own folder: `user://saves/slot_1.json` … `slot_3.json`.
  On Windows that is `%APPDATA%\Little Captains Hat\saves\` (project setting
  `application/config/custom_user_dir_name`, so a future change of name cannot
  move the saves). Settings are `%APPDATA%\Little Captains Hat\settings.cfg`.
- **Saves from Next Harbor** stay where they were:
  `%APPDATA%\Godot\app_userdata\Next Harbor\saves\`. The new game never writes
  there. When saves exist in that folder, the main menu shows **Import Next
  Harbor saves…**. It asks first and then only *copies*: each save goes into the
  slot with the same number if it is free, otherwise into the next free slot,
  otherwise it is skipped and you are told. A slot in use is never overwritten,
  a save already imported is not copied again, and the original files are never
  changed. Old settings are not imported (set them again once).
  To import by hand instead, copy `slot_N.json` from the old folder into the new
  one while the game is closed.
- A save holds everything needed to resume, including mid-voyage:
  - the game clock and time acceleration;
  - the boat's position and status, and the exact course being sailed with the
    progress along it;
  - sail or engine and the automatic controller's state, and the wind seed (the
    weather itself is recomputed from it, so it is the same after loading);
  - the weather warnings already given, and how long the boat has been in its
    current weather (for Iteration 005b);
  - the boat area and player position;
  - the ship's companion (cat or dog, resting spot and when it next moves);
  - the boat you sail (by its stable id, e.g. `halcyon_40`);
  - money, food and water, each boat's condition, and the rescues so far.
- Loading resumes exactly where you saved. **No time passes while the game is closed.**
- Save format version 10 (independent of the game version). **Older saves still load:**
  - Iteration 006 saves (v9 and v8) get the captain's hat: the original, on its hook.
  - Iteration 005a saves (v6) start the new systems as a new game does: €10,000,
    14 days of food and water, every boat at 100 %. A voyage underway is kept.
  - Iteration 004/004b saves (v5) get the new weather section. Their old
    warnings belonged to the retired demonstration areas and are cleared, so
    the new weather is announced normally.
  - Iteration 003b saves (v4) load aboard the Starling 33 monohull.
  - A save naming a boat this version does not know loads aboard the Starling 33,
    and you are told.
  - Iteration 003 saves (v3) get a ship's cat (the default companion).
  - Iteration 002 saves (v2) keep their voyage. Sail or engine is decided from the
    wind where and when the boat was saved.
  - Iteration 001 saves (v1): the boat is placed in its port at the default start
    time, and an old planned route is recalculated as a sea route. If that is
    impossible, the old route is removed and you are told.
- Writes are safe (temporary file, verify, keep `.bak`, then replace). Damaged or invalid
  saves are reported and never change the running game.

## Settings

Unchanged from Iteration 001: stored in `user://settings.cfg` (in the game's own folder), separate from saves;
changes preview immediately, **Apply** saves them, **Back** asks before discarding.
Volumes are percentages (0% mutes). Window modes: Windowed, Fullscreen (exclusive),
Borderless fullscreen. Interface scale 80–130% scales menus and HUD only.

## Project layout

```
assets/          branding, fonts (Barlow and Patrick Hand, OFL), the hat's art slots, UI theme, placeholder audio,
                 vessel art folders and templates (assets/vessels/<id>/)
data/navigation/ ports, coastlines, navigation raster and sea-route graph (generated)
data/weather/    weather event zones and cyclone basins (weather_events.json), wind climatology
data/vessel/     sailing performance profiles (polar, engine, controller thresholds)
data/vessels/    vessel definitions, the vessel catalog and visual profiles
src/app/         application shell (main scene) and screen transitions
src/core/        game session state and the simulation (game clock, voyages), provisions, boat condition
src/boat/        boat area logic, collision fixtures, sail rig, visual slots (visuals/)
src/vessels/     vessel definition and catalog; deck/cabin scenes per vessel (<id>/)
src/companion/   ship's companion: state (kind, resting spot), the cabin animal, pose art data types
src/dev/         developer guide index, developer test tools (F9) and weather fixtures
data/companions/ companion pose sets (cat_visuals.tres: pose -> image, placement, timing)
Visuals/Cat/     the owner's original cat drawings (used directly by the game)
DEV_GUIDES/      practical developer guides (sprites, companion, vessel art, audio, modding)
src/player/      player token
src/interaction/ interactables and the player's interaction sensor
src/navigation/  ports, routes, voyages, projection, sea router, chart screen, chart wind layer,
                 weather overlay style and legend
src/sailing/     propulsion state and the automatic sail/engine controller
src/weather/     the weather model, weather events, samples, exposure; the background wind field
src/ui/          menus, HUD, time controls, new-game and sleep dialogs, notifications, dialogs
src/audio/       audio manager
src/persistence/ save manager (format v7 + migration)
src/settings/    settings manager
tests/           self-contained test runner and suites
tools/           generators for the theme, logo exports, placeholder audio, navigation data,
                 vessel scenes, art templates and the demo sprite (tools/vessels/)
docs/            screenshots
```

**Developer guides:** [DEV_GUIDES/README.md](DEV_GUIDES/README.md) is the practical
manual for replacing art and sounds, the companion poses, and the vessel art
templates. **Rule:** whenever an iteration changes an asset workflow or a
documented system, the matching guide is updated in the same iteration.

See [ARCHITECTURE.md](ARCHITECTURE.md) for how it fits together, and
[ITERATION_006_REPORT.md](ITERATION_006_REPORT.md) with its Windows checklist
[WINDOWS_ACCEPTANCE_I006.md](WINDOWS_ACCEPTANCE_I006.md), [005c](ITERATION_005C_REPORT.md),
[005b](ITERATION_005B_REPORT.md), the Windows checklist
[WINDOWS_ACCEPTANCE_I005.md](WINDOWS_ACCEPTANCE_I005.md) (and the reports for
[005a](ITERATION_005A_REPORT.md), [004b](ITERATION_004B_REPORT.md), [004](ITERATION_004_REPORT.md),
[003b](ITERATION_003B_REPORT.md), the [003b hotfix](ITERATION_003B_UI_HOTFIX_REPORT.md),
[003](ITERATION_003_REPORT.md),
[002](ITERATION_002_REPORT.md) and [001](ITERATION_001_REPORT.md)) for what was
built and verified.

## Known limitations

- The wind and weather are synthetic, not real weather and not a forecast. Sailing is simplified:
  - there is no manual sail or engine control (the helm only asks for a fresh
    check), no tacking (a head-to-wind leg is motored), and no fuel;
  - there are no currents, waves, depth or tides;
  - weather damage is one general condition value (no separate hull, engine,
    sail or rigging damage), and there are no waves, rain or visibility
    effects. Repairs are free; income is remote work and travel updates;
  - the chart shows the weather now; it does not animate a forecast;
  - the ETA is an estimate along the route with the expected wind. It ignores the
    controller's delays.
- The companion only rests and changes pose (no walking, no needs) and stays in the
  cabin. Its sounds are synthetic placeholders. The dog has no drawn artwork yet
  (it uses the placeholder drawing).
- **Routing coverage.** All 163 harbours are reachable (each is tested against the
  chart and router). Waters the chart
  data cannot represent are **not** navigable, and are reported as such instead of being
  crossed. These include:
  - the Black Sea, Sea of Marmara and Sea of Azov (the Bosporus and Dardanelles are too
    narrow for the data);
  - the Gulf of Corinth, the White Sea and the inner Oslofjord;
  - the inner Stockholm archipelago and many small sounds and fjords.

  Oslo, Stockholm and 15 other candidate harbours are therefore not in the list (see
  `tools/navigation/harbours_rejected.csv`). Canals such as the Kiel Canal are not
  modelled.
- Harbour coordinates often sit on generalised coastline. Each port gets a **bounded
  harbour approach**: up to 2 nm from the berth and at most 10 nm through mostly-water
  cells, which may graze the simplified coastline. All other legs stay strictly clear of land.
- The chart and the save files are game data, **not for real navigation**.
- All audio is temporary synthetic test sound. Boat graphics are still procedural
  placeholders: the sprite pipeline is ready, but only one demo sprite exists (the
  Starling's coachroof, not enabled by default).
- Boats are only swapped, never bought: money is only used for rescues; there is
  no maintenance, upgrades or decoration yet. The catamaran's and trimaran's layouts are first versions.
- Tested on Linux with Godot 4.7.2 (headless and under a virtual display with software
  OpenGL). Not run on Windows yet. VSync could not be verified in that environment.

## Credits and licences

- Harbour coordinates added in Iteration 006: [UN/LOCODE](https://unece.org/trade/cefact/unlocode-code-list-country-and-territory)
  (UNECE), via the `datasets/un-locode` code list; see `tools/navigation/harbours.csv`.
- Coastlines: [Natural Earth](https://www.naturalearthdata.com/) 1:10m land, public domain.
  Clipped, simplified and rasterised by `tools/navigation/build_navigation_data.py`,
  **not for navigation**.
- Fonts: [Barlow](https://github.com/jpt/barlow) by Jeremy Tribby, SIL Open Font License
  (`assets/fonts/OFL.txt`); [Patrick Hand](https://github.com/google/fonts/tree/main/ofl/patrickhand)
  by Patrick Wagesreiter, SIL Open Font License (`assets/fonts/OFL-PatrickHand.txt`). See
  `assets/fonts/README.md`.
- Logo, UI, scenes, weather data and placeholder sounds were made for this project.
