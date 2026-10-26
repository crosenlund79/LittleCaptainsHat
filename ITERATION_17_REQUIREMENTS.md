# Iteration 17 — Requirement Tracker

Linked to [ITERATION_17_ASSIGNMENT.md](ITERATION_17_ASSIGNMENT.md) (section
numbers in brackets). Status values: **TODO**, **IN PROGRESS**, **DONE**
(implemented *and* verified), **PARTIAL** (part done; limitation stated),
**NOT DONE** (with the reason). Evidence names a test suite, a check, a
screenshot in `docs/screenshots/iteration17/` or a measurement in
`docs/benchmarks/`.

## MAP — World rendering [§5D, §9]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| MAP-1 | No rectangular gaps or shifted land when panning toward Australia/Pacific from either direction | DONE | test_world_chart_render sweeps (west/east, world and regional); fails on I016 code | Linux rendering; Windows to confirm |
| MAP-2 | Repeated Date Line crossings, beyond one world width and back | DONE | test_world_chart_render: 2.2 turns each way, round trip |  |
| MAP-3 | Zoom around Australia/New Zealand; world ↔ regional scale switches | DONE | test_world_chart_render regional sweeps at Australia/Pacific latitudes; screenshot 17_map_australia_regional |  |
| MAP-4 | Reopen map and select destinations after extensive panning | DONE | test_world_chart_render: harbour picking after long pans |  |
| MAP-5 | Repeatable automated rendering-coverage regression test | DONE | tests/suites/test_world_chart_render.gd |  |
| MAP-6 | Rendered before/after evidence | DONE | docs/screenshots/iteration17/32_world_chart_before_after.png (I016 vs I017 after panning west and east); 03, 04 |  |
| MAP-7 | Worldwide routing and Date Line correctness preserved | TODO | | |

## WND — Wind and weather performance [§10–§15]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| WND-1 | Profile before restricting: simulation, events, chart sampling, geometry, draw, caches, stationary, pan/zoom, fast time | DONE | tests/benchmark_17.gd; docs/benchmarks/iteration17_before_*.json; sample cost breakdown in report | Rendered numbers on software GL (llvmpipe) |
| WND-2 | Separation: authoritative sailing weather / forecast-route sampling / chart visualization | DONE | WeatherModel.sample (sailing), Simulation forecasts with known_at (route), WeatherModel.sample_wind + WindLayer snapshot cache (chart) |  |
| WND-3 | Audit: sailing weather local/on-demand; documented honestly | DONE | Audit: samples are point queries; event list per 15-min bucket ~10 events worldwide, 0.5 ms cold / 2 µs warm; reach boxes skip far events (0.38 events checked per sample near Denmark) | Was already local; no optimisation claimed |
| WND-4 | Closing the chart stops chart wind work; sailing weather continues | DONE | test_wind_overlay [close]; WindLayer processes only while shown and in the open chart |  |
| WND-5 | Long passages sample along the travelled path; Long Passage equivalence kept | DONE | Simulation samples at the boat each step (~6,500 samples per sailed day, benchmark); test_long_passage equivalence (12 h/s vs twenty-minute steps) passes |  |
| WND-6 | Chart wind as a cached snapshot (spatial, time, resolution; bounded; reuse on small pans; no per-frame rebuild) | DONE | test_wind_overlay [overlay]: no chunks while stationary, small pans reuse, cached snapshot reuse, bounded caches |  |
| WND-7 | Adaptive density by zoom; thresholds measured; hysteresis; "Zoom in to see wind details." | DONE | test_wind_overlay [zoom]: hidden below 9 px/° (shown again above 11), notice, bounded lattice points |  |
| WND-8 | Wind snapshot controls: Previous/Next/Now, 30-min steps, ±2 h, NOW / PAST MODEL SNAPSHOT / FORECAST labels, uncertainty note | DONE | test_wind_overlay [navigator]; screenshot 17_wind_forecast |  |
| WND-9 | Forecast preview is read-only (no time, movement, stores, wear, events, weather, seeds, rewards) | DONE | test_wind_overlay: time, position, seed and whole saved state unchanged after previewing |  |
| WND-10 | Passage Readiness / cockpit forecasts limited to relevant samples | DONE | PassageReadiness consults the route forecast only up to FORECAST_HOURS; the sailing panel samples one point on the next leg; no world grid anywhere (report §7–8) |  |
| WND-11 | Before/after wind performance measured | DONE | docs/benchmarks/iteration17_checkpointB_*.json: forced full re-sample 1051 → 36 ms (Denmark region, headless); in play spread over frames at ≤ 3 ms |  |

## NAV — Navigation architecture [§4–§8]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| NAV-1 | Three interfaces share one geography, router, catalogue, vessel, voyage, weather, save | DONE | Dreamer's Map and working chart: two modes of WorldMap; chartplotter reads the same voyage and the router's navigation grid (test_navigation_views, test_cockpit_ui) |  |
| NAV-2 | Framed world map object in every cabin; contextual interaction; no circle | DONE | test_navigation_views [cabin]: all four boats, focusable, frame highlighted (no circle); screenshots cabin_world_map_* |  |
| NAV-3 | Cabin world map: whole world, pan, zoom, names, harbours by zoom, search, select, name/country/description, visited, return | DONE | test_navigation_views [dream]: world, pan across the Date Line, search, name/country/story, visited / not visited, back to the cabin |  |
| NAV-4 | Cabin map has no wind/weather overlay; static/cached | DONE | test_navigation_views [dream]: no wind layer, no weather areas, no wind sampling while panning |  |
| NAV-5 | Voyage daydreams: real route, distance, 2–3 real intermediate places, modest template variety, no invented names, read-only, cached | DONE | test_navigation_views [daydream]: real route, real harbours near it in order, cached, nothing changed, short hop, tones; src/navigation/voyage_daydream.gd |  |
| NAV-6 | Navigation station: regional working chart (~300–500 nm, latitude-aware), boat, coast, harbours, route segment, waypoints, next waypoint, heading, distance/course, weather, wind | DONE | test_navigation_views [station]: opens ~400 nm across at Copenhagen and Papeete (latitude-aware); next turn ring and "Steering … next turn" line; wind arrows only at sea | Weather/wind use the B overlay |
| NAV-7 | Global destinations still plannable from the station | DONE | test_navigation_views: "Plan it at the chart table" → working chart with the harbour selected; plotting uses the global router |  |
| NAV-8 | Cockpit chartplotter: lightweight, bounded, boat, heading, coast, route, next waypoint and distance, planned course, local wind; toggle from action wheel and a key | DONE | test_cockpit_ui [plotter]: P and the action wheel, deck underway only, coast raster from the navigation grid, the voyage's next turn, no world chart built; screenshot 17_chartplotter | Coast is a 96×96 raster (bounded), smoothed |
| NAV-9 | Same route in station, vessel, chartplotter and readiness | DONE | Next turn: chart ring = WorldMap.get_next_turn() = sailing panel = chartplotter = voyage path (test_navigation_views, test_cockpit_ui) |  |

## BOAT — Vessel graphics and movement [§26–§28]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| BOAT-1 | Boat visually turns with heading while the Captain is on deck (all listed scenarios) | DONE | test_sailing_correctness [orientation]: autopilot turns at waypoints with the captain amidships/bow/stern, successive turns, cabin round trip, after load; fails without the fix | Root cause: the deck camera re-turned only on route edits/voyage start |
| BOAT-2 | Player/sail and rigging depth order correct | DONE | test_presentation [rig]: rigging, boom and sails above the captain (z 20 vs 10); see-through while under the sail/boom; all boats share the rule |  |
| BOAT-3 | White side objects identified; fenders shown moored, stowed underway, correct after save/load | DONE | Identified as fenders painted in each boat's deck art (2–3 per boat); test_presentation [fenders]: out moored, stowed underway, out on arrival and after load; art files unchanged (MD5) | Stowing uses a runtime copy of the texture with the fenders cleared |

## SAVE — Persistence [§32–§34, §44]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| SAVE-1 | Save/load underway keeps the Captain aboard (all listed situations), relative positions, safe fallback | DONE | test_sailing_correctness [save]: helm, bow, stern, cabin, after a course change, at anchor, in a gale at night; invalid position falls back to the spawn point | Two-process check in 17I |
| SAVE-2 | Weather persistence: reload reproduces weather; no rerolling; documented | DONE | test_sailing_correctness [weather]: the same save sailed twice gives identical wind, position and condition for 12 h | Weather is a pure function of (position, time, seed); the seed is saved |
| SAVE-3 | F5 quicksave / F9 quickload with confirmation, no double-activation, defined policy | DONE | test_sailing_correctness [quick]: F5 once per press, own file, manual slots untouched, refused with a window open, F9 asks then restores exactly, repeated F9 ignored | Developer test panel moved from F9 to F10 |
| SAVE-4 | Two-process save/load verification (deck, cabin, storm) | DONE | tests/restart_17.tscn (write, quit, read): deck near the bow in strong wind (25 kn, gusts 33), cabin, and a third save; PASS | No gale/thunderstorm occurred in an 8-day search, so a saved storm was not tested across processes (covered in-process) |
| SAVE-5 | Existing saves load; save format decision documented | DONE | Save format stays 12 (no new fields); test_save_manager, test_voyage_persistence pass |  |

## LGT — Lighting [§16–§21]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| LGT-1 | Day/night cycle (dawn, day, dusk, night) on the game clock with local solar time by longitude; smooth | DONE | src/world/daylight.gd; test_lighting [sun]: local solar time by longitude, latitude and season (midnight sun), night→dawn→day→dusk→night, smooth (≤0.06 per 5 min) | Approximation, documented; no moon |
| LGT-2 | Correct under Long Passage, sleep, load, harbour | DONE | test_lighting [fast]/[load]: Long Passage pace eased (no strobe), load jumps to the hour; harbour night/dusk; sleep eases over ~1 s |  |
| LGT-3 | Warm cabin lighting from fixtures, all four boats, personalization-safe | DONE | test_lighting [cabin]: lamps at each boat's own fixtures (by fixture name, personalization-safe), night dim not black, day lamps off with hatch daylight; screenshots 17_cabin_night_* |  |
| LGT-4 | Deck and cockpit night lighting, restrained; helm and highlights visible | DONE | test_lighting [deck]: cool dim night, helm instrument glow, companionway spill, red/green/white navigation lights; highlights compensated |  |
| LGT-5 | Harbour lighting via reusable pattern | DONE | test_lighting [harbour]: quay lamps and pontoon lights from the shared HarbourDressing (every harbour), lit at night moored only |  |
| LGT-6 | Soft shadows and depth; before/after comparison | DONE | Fixture soft shadows and contact shadows (test_lighting); docs/screenshots/iteration17/31_lighting_before_after.png | Soft overlays, not true occlusion |

## AUD — Audio and storm atmosphere [§22–§25, §39]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| AUD-1 | Wind sound by actual wind; water ambience; rain | DONE | test_atmosphere [loops]: breeze and water loops by wind and speed, rain by the systems that bring it, strong-wind loop above 20 kn; src/audio/weather_audio.gd | No rain field in the weather model: rain is derived (documented) |
| AUD-2 | Lightning and thunder in thunderstorms, distant/near, cabin light response, no harsh strobe | DONE | test_atmosphere [lightning]/[thunder]: flash pattern through the lighting, brief, cabin lights a little, thunder delayed by distance, near/far variants |  |
| AUD-3 | Cabin vs deck acoustics (muffling), buses ready for I019 alarms | DONE | test_atmosphere [muffle]/[buses]: Outside bus low-pass closes below deck, SFX bus unfiltered for I019 alarms |  |
| AUD-4 | Boat-local visual wind cues agree with actual wind | DONE | test_atmosphere [cues]: wind streaks boat-relative to the actual wind, rain on deck in a gale; screenshot 17_deck_rain_and_wind |  |
| AUD-5 | Assets local, licensed and recorded | DONE | assets/audio/weather/README.md; tools/generate_weather_audio.py (original, generated, deterministic) | Synthetic sounds, not recordings |
| AUD-6 | Accessibility: ambient/effects volume, flash intensity, UI flashing | DONE | Settings: Ambience/SFX volumes (existing), Reduce flashing, Lightning flash 0–100 %; test_atmosphere [access] |  |

## HUD — Cockpit and action wheel [§29–§31]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| HUD-1 | Right-side sailing panel: speed, heading, wind dir/speed, next-leg forecast wind, time to next course change; optional fields; actual vs planned vs forecast distinguished; collapsible | DONE | test_cockpit_ui [panel]: speed, heading, wind now, next leg (forecast, estimate), next turn or "No more turns", distance/ETA (estimate), collapsible, no overlap; screenshot 17_sailing_panel |  |
| HUD-2 | Course-change notification (>~5°, restrained, accessible) | DONE | test_cockpit_ui [pulse]: a >5° autopilot course change highlights, ends by itself, none while steady; Reduce flashing = one gentle pulse |  |
| HUD-3 | Context-aware action wheel (helm, cabin, anchor), keyboard, no click-through | DONE | test_cockpit_ui [wheel]: helm/cabin actions, D/E keys, mouse, Esc closes, nothing under it reacts, captain does not move |  |
| HUD-4 | Action-wheel shortcut in the bottom help panel | DONE | test_cockpit_ui [help]: "Q actions" in the help strip |  |

## PORT — Harbours and arrival [§35–§37]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| PORT-1 | Harbour facilities in destination preview from authoritative data; extensible | DONE | HarbourFacilities.describe_services (tier, groceries, boatyard, haul-out, go ashore) on the working chart and Dreamer's Map; test_presentation [preview] checks all 223 harbours against their data | No fuel (not in the game) |
| PORT-2 | Visited harbours grouped by country, collapsible, All/Visited/Not visited | DONE | Captain's Log harbours by country, collapsible, counts, All/Visited/Not visited; test_captains_log [log ui] |  |
| PORT-3 | Short docking arrival presentation, skippable, no duplication | DONE | test_presentation [docking]: deck, captain at the helm, harbour glides in, engine on, skippable, one arrival, nothing consumed; skipped when asleep (wakes in the cabin as before) |  |

## QA — Testing and delivery [§38, §40–§53]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| QA-1 | Long Passage preserved and integrated (lighting, audio, preview, panel) | DONE | test_long_passage passes; test_lighting [fast] (eased light at Long Passage pace); sailing panel and Long Passage panel do not overlap (test_cockpit_ui) |  |
| QA-2 | Performance profiling and before/after report (headless vs rendered stated) | TODO | | |
| QA-3 | Full regression | TODO | | |
| QA-4 | 30 rendered screenshots reviewed | TODO | | |
| QA-5 | Shipyard Efficiency section with measured timings | DONE | ITERATION_17_REPORT.md §37 (138 logged runs, measured vs estimate separated) |  |
| QA-6 | CAPTAINS_ORDERS.md updated | DONE | Iteration 17 decisions and log entry; existing decisions preserved; no Phase Two wording invented |  |
| QA-7 | ITERATION_17_REPORT.md (40 items), WINDOWS_ACCEPTANCE_17.md | DONE | Both written; Windows status: not yet tested |  |
| QA-8 | Version per policy; push and remote HEAD verified | TODO | | |
| QA-9 | No I018–I021 scope started | DONE | No Fishing 2.0, alarms, shops, personalization or difficulty modes |  |
