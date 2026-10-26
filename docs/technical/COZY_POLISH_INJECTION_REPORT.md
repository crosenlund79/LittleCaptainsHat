# Injection 1: Cozy Polish, Navigation & Quality of Life

A standalone polish pass on version **0.105b** (the version and the save format, **12**, are unchanged). The Vintage Chartroom / Harbor Dusk look and the soundtrack integration are kept as they were.

| | |
|---|---|
| Branch | `claude/friendly-fermat-dey23f` |
| Start commit (remote HEAD, verified clean) | `975ed9c` Soundtrack C: report, Ship's Library entry |
| Checkpoints | `c974297` Cozy 1 (canals, chart zoom, stray waypoints) · `f3a97a0` Cozy 2 (debris, Q menu, coffee, holders, sleep, pins, provisions, compact HUD, loading screen) · `f456291` Cozy 3 (Petrel holder, handler fixes, test updates) |
| Final commit | the commit that adds this report ("Cozy 4"); the final hash is given in the delivery message |
| Version / save format | 0.105b / 12, unchanged. The galley state gained one optional key, `coffee` (see *Saves*) |
| Windows acceptance | **pending**: everything below was verified on Linux (headless and rendered at 1600×900 under xvfb) |

Each item below is marked **DONE** or **PARTIAL**. No item was dropped, and nothing from I019 was started.

---

## 2. Floating things at sea: DONE

**Before:** at sea the deck showed only wave crests and a few water rings. Floating things existed only in harbours.

**Now:** `WaterLife` keeps a fixed pool of **16** floating things while underway (`SEA_DRIFTERS`):
- Kinds: seaweed, driftwood, a floating leaf, foam, kelp and a feather.
- Each gets its own size, angle, slow spin, colour and wind-drift factor.
- Decorative only: no collision and no interaction.

**Motion.** They move in the boat's own frame:
- Astern at the boat's speed (`FLOW_PX_PER_KN` = 9 px per knot, the same flow the wave crests use).
- Plus a small drift with the wind, rotated into the boat's heading.
- Because the deck art always lies bow-to-+x and the course-facing view rotates the camera, "astern" is correct at every heading and in both views.

**Spawning and pooling.**
- One that falls behind the view comes back ahead of the bow at a random distance (up to 60 % of a view width beyond the edge), so the spacing never repeats like a conveyor belt.
- New ones are never placed over the hull: the beam band of the boat is measured once from its lifeline and kept clear.
- Becalmed (under 0.3 kn) or after drifting far off, they come back anywhere in view instead.
- The pool is never reallocated: zero allocations per frame.

**Moored:** the harbour's own drifting things are drawn instead, unchanged.

**Tests:** `test_cozy_polish` `[debris]`:
- 16 in view, 100 % moving astern at two headings: 343° in the normal view and 91° in the course-facing view.
- Becalmed they lie still. At 2 and 7 kn they pass at −9 and −31.5 px per half second, exactly in proportion.
- 300 respawns were never placed over the hull.
- Moored shows harbour drifters.

**Screenshots:** `cozy_debris_day`, `cozy_debris_underway`, `cozy_debris_course_view`.

## 3. Chart zoom limit: DONE

**Cause.** On the world chart the smallest zoom only kept the map *one world wide* (`free.x / world_width`). The chart's data runs 72° S to 80° N, so on a wide window zooming out left empty bands above and below the data. The vertical clamp also only kept the camera *centre* inside the bounds, not the view's edges.

**Fix** (`MapView`):
- The minimum zoom is the larger of "one world wide" and "the data's full height fills the free view".
- The vertical clamp keeps the view's top and bottom edges on the data.
- Both are re-applied when the window changes size (`size_changed`).

**Scope.** Wheel, keyboard and button zoom all go through `_set_zoom`, so they share the limit. Horizontal wrapping across the Date Line, centring, panning and course drawing are untouched. Nothing is masked: the view simply never goes beyond the data.

**Tests:** `[zoom]`:
- Zoomed right out, the view spans 72.0° S to 80.0° N.
- Panned to either pole, there is still no empty band.
- It zooms back in close to Kiel.
- `get_min_zoom()` is exposed for the check.

## 4. Canals: DONE (with documented limits)

**Cause.** The routing charts are rasters: 12 cells/degree worldwide, 60 cells/degree for Europe. A ship canal is far narrower than a cell, so Kiel and Suez simply did not exist.
- Kiel → Cuxhaven went round Skagen (495 nm).
- On the world chart the Gulf of Suez is also closed at the Strait of Gubal, and Bab-el-Mandeb is narrower than a cell. Limassol → Nouméa therefore went round the Cape of Good Hope (13,344 nm).

**Fix.** `data/navigation/canals.json` lists each passage as approximate real centreline points with place names. `SeaRouter` adds them to the routing graph as a chain of nodes linked to open water at both entrances. This is a documented gameplay abstraction, recorded in the file's `note`.

| Link | Route (approximate real points) |
|---|---|
| **Kiel Canal** | Kiel Fjord → Holtenau locks → Levensau → Landwehr → Sehestedt → Schacht-Audorf → Rendsburg → Breiholz → Oldenbüttel → Hochdonn → Burg → Brunsbüttel locks → the Elbe |
| **Suez Canal** | off Port Said → Port Said → Ras el Esh → El Qantara → Ballah → Lake Timsah → Deversoir → Great and Little Bitter Lakes → Port Tewfik → down the Gulf of Suez → Strait of Gubal → open Red Sea |
| **Bab-el-Mandeb** (strait) | Red Sea → west of Perim → Gulf of Aden |
| **Panama** | unchanged: carved into the world chart as before |

**One rule, shared everywhere:**
- A segment is accepted on land only when both of its ends lie on the *same canal reach* (`is_canal_segment`, within 0.3 nm of it).
- `is_afloat` accepts canal water.
- The planner, `validate_route`, the voyage simulation (travel), loading a save mid-canal, the chart drawing and arrival all use this same rule.
- A straight line across the land next to a canal is still refused (tested).
- The chart draws each canal as a faint sea-foam line (not on the Dream World map). The Date Line handling is untouched.

**Route examples (tested):**

| Route | Distance | Notes |
|---|---|---|
| Kiel → Cuxhaven | 70 nm | was 495 nm round Skagen |
| Bremerhaven → Kiel | 99 nm | |
| Limassol → Nouméa | 9,285 nm | through Suez, the Red Sea and Bab-el-Mandeb; was 13,344 nm |
| Colón → Panama City | 30 nm | Panama preserved |

**Kiel → Cuxhaven sailed in full:**
- Afloat at every step. The berth link from Kiel's port coordinate into the fjord predates this work and is allowed by `validate_route`.
- Saved and loaded inside the canal: same position, same voyage.
- Arrives at Cuxhaven.

**Stockholm: verified, nothing to repair.** I checked the code, data, docs and tests before touching anything:
- No Stockholm passage is defined anywhere in the project.
- Stockholm harbour itself is in `tools/navigation/harbours_rejected.csv`: it was rejected in I006 because the routing chart has no approach through the inner archipelago, and the README states the inner Stockholm archipelago is not navigable.
- What *is* defined works: Nynäshamn → Sundsvall, Nynäshamn → Mariehamn, Nynäshamn → Helsinki and Visby → Luleå all plan and validate (tested `[stockholm]`).
- I did not invent a passage from the word "Stockholm".

**Geodata honesty:**
- Canal points are approximate (not for navigation).
- Locks, transit rules, tolls and traffic are not modelled.
- There are no harbours in the Red Sea or the Indian Ocean yet, so Suez helps only long passages to the east.

**Tests:** `test_cozy_polish` `[canals]`, `[kiel]`, `[suez]`, `[panama]`, `[stockholm]`. `test_routing` passes 397/397: its graph-consistency and land-crossing checks exempt canal reaches by the same rule.

**Screenshots:** `cozy_chart_kiel_canal`, `cozy_chart_suez`.

## 5. Q menu: DONE

**Renamed labels:**

| Before | After |
|---|---|
| "Open the chart" | **Charts** |
| "Trim the sails" | **Trim sails** |
| moored "Captain's Log" | **log** (underway it is still "Captain's Log") |

Actions, ids and shortcuts are unchanged, with no duplicates.

**Check marks.** *Chart plotter* and *Sailing details* carry a themed CheckBox check mark. It is read from the real state each time the wheel opens: `ChartPlotter.shown` and `not SailingPanel.collapsed`. There is no second state variable, so a change made elsewhere (for example the P key) shows at once. Choosing the item toggles it directly.

**Tests:** `[wheel]` checks the labels, the absence of the old labels, check marks matching the state, toggling, and a change made elsewhere showing. **Screenshot:** `cozy_wheel_checks`.

## 6. Coffee and the hat in hand: DONE

**Making and carrying coffee.** Making coffee (galley) now puts the mug **in hand**. The sailor draws it at the right hand, with the arm steadying it.

**Hands.** The hat already had a CARRIED state (under the arm). Free hands are counted as `2 − hat carried − mug carried`; nothing else was added to the hat state.

**With both hands full:**
- Fishing, cooking, the anchor, sail trim, taking the hat off and petting are refused, with one short friendly line: "Your hands are full: the hat and a mug of coffee. Put your hat back on (H) or set the coffee down first."
- The line is shown once, not stacked on repeated presses.
- Menus, the chart, walking, the helm, sleep, saving and every other control stay available.
- Putting the hat back on (H) frees a hand.

**Where the mug can go:**
- **Deck:** a brass cup holder on the starboard coaming by the helm, on all four boats. It is placed clear of the helm (≥ 44 px) and its station never takes E from the helm.
  - The Petrel 36's helm stands aft of its wheel, closed in by the wheel and the cockpit bench. Its deck places the holder itself (`Layout/CupHolderSpot`) beside the bench, where the player can stand.
  - The vessels suite's walk check confirms every holder can be walked to on all four boats.
- **Cabin:** going below with the mug works. It can be set down on the saloon table, and a "Your coffee" station there picks it up again.
- **Wheel actions:** "Coffee in the holder" / "Set coffee down", "Take your coffee", and **Finish the coffee** (dispose).

**Simplicity, persistence and traps:**
- There is no temperature, caffeine, spilling, recipes or other mechanics.
- The mug's place (`carried`, `holder`, `table` or none) is one field of the galley state, so it survives cabin/deck changes and save/load.
- There is only ever one mug, so there is nothing to duplicate.
- Every state has a way out (finish it anywhere it is held, pick it up wherever it stands), so there are no permanent traps.
- The companions (including Snøvs) are unchanged; only petting with both hands full is politely refused.

**Tests:** `[coffee]` runs per boat for all 4:
- holder placed by the helm and clear of it;
- mug in hand, hat in the other hand;
- full hands refuse once and kindly;
- the hat back on frees a hand;
- holder and table both work.

`[save]` covers the mug's place being saved and loaded, and an old save without it.

**Screenshots:** `cozy_coffee_in_hand`, `cozy_hands_full`, `cozy_cup_holder`.

## 7. Provisions art: DONE

**Audit.** There are two provision types: **food** (days) and **water** (days). They are drawn by `ProvisionDisplay` on the galley shelf, previously as plain coloured blocks. There are no Captain-owned provision PNGs; the optional PNG override path (`<art_folder>/cabin/provisions_<level>.png`) is kept and still wins when a PNG exists.

**Now:**
- Food slots are illustrated **bread, apples, a jar and cheese**.
- Water slots are **jugs** whose window shows the level.
- A used slot keeps a faint outline, so the shelf still reads as "how much is left".
- The FOOD · WATER label is tinted by level and stays readable.

Quantities, consumption and saves are untouched, and there are no new categories.

**Screenshot:** `cozy_cabin_compact` (the shelf, top left of the cabin).

## 8. Sleep duration remembered: DONE

The sleep dialog opens on the duration chosen last.
- It is kept in the **settings file** (`[gameplay] sleep_hours`, per player and machine), not in the save.
- The value is validated and clamped to 1–12 h when read.
- First use defaults to 6 h.
- The ± buttons change it without writing to disk; Sleep writes it.

**Tests:** `[sleep]`: first use 6 h, reopened at the last choice, kept across a settings reload, an impossible stored value (99) clamped.

Suites written for the old fixed default now set 6 h explicitly before they open the dialog: `test_gameplay_flow`, `test_life_aboard`, `test_chart_and_pause`.

## 9. Visited-harbour pins on the Dream World map: DONE

The Dream World map (the cabin's daydream map) shows a small **red pin** for every harbour the captain has actually visited.
- The pins come from the Captain's Log's visited set, which is already saved, so they need no save change.
- Each harbour has one pin.
- Pins are drawn in screen space from geo positions, so they stay aligned while zooming and panning, Date Line included.
- At broad zoom, pins closer than 16 px merge into one pin with a count.
- Hovering shows the harbour name or names.
- The dream colours are untouched, and the navigation chart shows no pins (tested).

**Tests:** `[pins]`: one per visited harbour and none for others; merged at world zoom (3 groups for 4 pins); separated closer in; absent from the navigation chart.

**Screenshots:** `cozy_pins_world`, `cozy_pins_close`.

## 10. Palermo → Limassol stray "blocked" line: DONE

**Cause.**
- On the chart, a mouse **press** on the course line inserted a waypoint at once (`MapView` emitted `route_pressed` on press, and `WorldMap` called `insert_waypoint`).
- At ocean zoom the 8 px pick tolerance is several nautical miles, so a plain click near the line could drop a waypoint on Sicily, Crete or the Peloponnese.
- The legs to and from that waypoint could not be routed and were drawn as straight red dashed "BLOCKED" lines over the still-valid course: two overlays at once, with no clear explanation.

**Fix:**
- A waypoint is only added by **dragging** the course line (beyond the click slop). A plain click behaves like a click on the map.
- A waypoint let go on land moves to the nearest open water within 15 nm, with a one-line explanation ("Waypoint 1 was on land: moved to the nearest open water.").
- If there is no open water that close, the waypoint is not added ("That spot is on land, far from open water: no waypoint added there.").
- A blocked leg, which can still arise, is labelled "BLOCKED (not applied)".
- Replotting replaces the draft completely, so no stale line is left.

The I018 route-wrap fix, previews, dragging waypoints and right-click removal are unchanged.

**Tests:**
- `[replan]`: a click on the line adds nothing; a waypoint on land is moved or removed with no blocked line left; plotting twice leaves one clean course.
- `test_gameplay_flow`'s waypoint-editing steps were updated from "waypoint on Møn makes the course invalid" to "waypoint on Møn moves to open water, course stays valid, nothing marked blocked".

**Screenshot:** `cozy_palermo_limassol`.

## 11. Compact UI: DONE

All values are in UI units of the 1920×1080 layout. The interface is scaled to fit at 1600×900, where it was checked; the measured values at 1600×900 are 0.833 of these.

**Location tab (upper left):** from 533 × 101 to **461 × 88**.
- The symbol is 34 px instead of 52.
- The title is 22 pt.
- The two detail lines are 17 pt instead of 19.
- Tighter spacing.

**Time controls / clock bar:** from 520 to **412** wide.
- 18 pt clock.
- 40 px `MapButton` speed buttons.

**Sleep dialog:** from 520+ to **380** wide.
- Header-style title.
- Compact ± buttons.

All text stays readable at 1600×900 (see the screenshots).

**Tests:** `[compact]`. **Screenshots:** `cozy_cabin_compact`, `cozy_sleep_compact`.

## 12. Startup loading screen: DONE (engine limit noted)

**Honest limit first.** Godot shows its **boot splash** while the engine itself starts, and no game scene can draw before that. The boot splash is now the game's own logo on the Vintage Chartroom paper colour (`project.godot` `boot_splash/*`), so the start looks on-brand from the first frame.

**Then the game's `LoadingScreen` takes over:**
- The logo (the day or night version), the tagline, and a calm horizon: slow waves, a lighthouse with a turning beam, and a little sailboat bobbing.
- A status line names each **real** loading step as it runs:
  1. "Reading the harbour list…"
  2. "Unrolling the charts of the world…" (the routing charts, the heavy step)
  3. "Making the cabin ready…"
- The charts load on a **worker thread** (`WorkerThreadPool`), so the screen keeps animating.
- When the work is done it says "Ready. Welcome aboard." and fades out (0.45 s) into the main menu.

**What it deliberately does not do:**
- No progress bar, no artificial delay, nothing blocking the UI thread.
- Clicks and keys pass through to the menu.
- It is shown once per launch and never without a display (tests and servers).

**Screenshot:** `cozy_loading_screen`, captured from a real cold start at frame 3 while step 2 of 3 was running.

## 13. Not done by request

The performance pass was not touched: slow sleep, day/night stalls, slowdowns, harbour transitions, leaks, filesystem writes, baselines and the Long Passage redesign.

---

## Saves

- The save format stays **12** (tested).
- The galley state writes one new key, `"coffee"`, with the value `""`, `"carried"`, `"holder"` or `"table"`. It is read as optional and validated. Saves from before have no key and load with no mug (tested).
- Visited-harbour pins use the existing Captain's Log data.
- The sleep duration is in the settings file, not the save.

## Files changed

**Data:**
- `data/navigation/canals.json` (new): the Kiel, Suez and Bab-el-Mandeb links.

**Navigation:**
- `src/navigation/sea_router.gd`: canal links, `canal_at`, `is_canal_segment`, `is_afloat`, validation.
- `src/navigation/geo_math.gd`: `distance_to_segment_nm`.
- `src/navigation/map_view.gd`: zoom limit and clamp, canal drawing, drag-only waypoint insertion, visited pins.
- `src/navigation/world_map.gd`: waypoint snapping to water, visited pins on the Dream World map.

**At sea and aboard:**
- `src/water/water_life.gd`: floating things at sea.
- `src/aboard/coffee_mug.gd` (new): the mug and the cup holder.
- `src/boat/boat_area.gd`: cup holders, the table mug, hands checks.
- `src/vessels/petrel_36/deck.tscn`: the Petrel's cup-holder spot.
- `src/boat/provision_display.gd`: illustrated provisions.
- `src/core/game_session.gd`, `src/core/galley_state.gd`: the coffee's place and the hands.
- `src/player/player.gd`, `src/player/sailor_drawing.gd`: the mug in hand.

**Interface:**
- `src/app/app.gd`: Q-menu labels and checks, coffee actions, hands checks, the loading screen.
- `src/ui/action_wheel.gd`: check marks.
- `src/ui/loading_screen.gd` (new).
- `src/ui/hud.gd`, `src/ui/hud.tscn`, `src/ui/time_controls.gd`, `src/ui/sleep_menu.gd`, `src/ui/sleep_menu.tscn`: compact UI and remembered sleep.

**Settings and project:**
- `src/settings/settings_manager.gd`: `sleep_hours`.
- `project.godot`: boot splash.

**Tests:**
- `tests/suites/test_cozy_polish.gd` (new, registered in `tests/test_runner.gd`).
- `tests/suites/test_routing.gd`: canal exemption.
- `tests/suites/test_gameplay_flow.gd`, `test_life_aboard.gd`, `test_chart_and_pause.gd`: remembered sleep and waypoint snapping.

**Docs:**
- this report, `docs/README.md` link, `docs/screenshots/cozy_polish/` (15 screenshots).

## Verification (targeted, not the full regression)

Runs on Linux with Godot 4.7.2:
- **Parse / startup:** the project imports clean, and the game starts and runs the loading screen in a rendered run.
- **`test_cozy_polish`:** 49 checks, 0 failed (headless), and 49/49 again in the rendered screenshot run at 1600×900.
- **Related suites**, run together (22 suites): **2,262 checks, 0 failed**. The suites were:
  - cockpit_ui, sail_trim, settings_and_audio, living_world, hat, galley_and_anchor, vessels;
  - captains_log, branding, chart_and_pause, navigation_views, gameplay_flow;
  - save_manager, voyage_persistence, cozy_patch, chartroom_ui, soundtrack;
  - fishing, routing, life_aboard, catamaran_cabin, cozy_polish.
- **One timing-sensitive check:** in an earlier combined run, `test_chartroom_ui`'s "steady at night: no restyling" failed once while the night blend was still easing in under load. It passed on its own (34/34) and in the later combined run. It is unrelated to this work and is mentioned for honesty.
- **Final edits re-checked:** the last two small edits (the mug redrawn in hand when set down; the full-hands line shown once) were re-checked by the cozy suite and a focused rerun of the hat, galley, fishing, cockpit and sail-trim suites.

The **full regression was not run**, by request, and is not claimed. **Windows acceptance is pending.**

## Limitations

- **Canals:**
  - The points are approximate; locks, transit rules, tolls and traffic are not modelled.
  - There are no Red Sea or Indian Ocean harbours yet.
  - Stockholm's inner archipelago stays unnavigable, as documented since I006.
- **Loading screen:** the engine's boot splash (now on-brand) necessarily comes first. With warm caches the loading takes only a fraction of a second, so the screen is brief by design.
- **Floating things:** decorative and drawn under the hull. A thing drifting sideways with the wind may pass under the boat, but it is never placed there.
- **Cup holder:** placed automatically on three boats and by the deck scene on the Petrel 36. A future boat with an unusual cockpit may need its own `CupHolderSpot`.
