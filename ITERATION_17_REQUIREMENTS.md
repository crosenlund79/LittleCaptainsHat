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
| MAP-6 | Rendered before/after evidence | TODO | | |
| MAP-7 | Worldwide routing and Date Line correctness preserved | TODO | | |

## WND — Wind and weather performance [§10–§15]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| WND-1 | Profile before restricting: simulation, events, chart sampling, geometry, draw, caches, stationary, pan/zoom, fast time | DONE | tests/benchmark_17.gd; docs/benchmarks/iteration17_before_*.json; sample cost breakdown in report | Rendered numbers on software GL (llvmpipe) |
| WND-2 | Separation: authoritative sailing weather / forecast-route sampling / chart visualization | DONE | WeatherModel.sample (sailing), Simulation forecasts with known_at (route), WeatherModel.sample_wind + WindLayer snapshot cache (chart) |  |
| WND-3 | Audit: sailing weather local/on-demand; documented honestly | DONE | Audit: samples are point queries; event list per 15-min bucket ~10 events worldwide, 0.5 ms cold / 2 µs warm; reach boxes skip far events (0.38 events checked per sample near Denmark) | Was already local; no optimisation claimed |
| WND-4 | Closing the chart stops chart wind work; sailing weather continues | DONE | test_wind_overlay [close]; WindLayer processes only while shown and in the open chart |  |
| WND-5 | Long passages sample along the travelled path; Long Passage equivalence kept | TODO | | |
| WND-6 | Chart wind as a cached snapshot (spatial, time, resolution; bounded; reuse on small pans; no per-frame rebuild) | DONE | test_wind_overlay [overlay]: no chunks while stationary, small pans reuse, cached snapshot reuse, bounded caches |  |
| WND-7 | Adaptive density by zoom; thresholds measured; hysteresis; "Zoom in to see wind details." | DONE | test_wind_overlay [zoom]: hidden below 9 px/° (shown again above 11), notice, bounded lattice points |  |
| WND-8 | Wind snapshot controls: Previous/Next/Now, 30-min steps, ±2 h, NOW / PAST MODEL SNAPSHOT / FORECAST labels, uncertainty note | DONE | test_wind_overlay [navigator]; screenshot 17_wind_forecast |  |
| WND-9 | Forecast preview is read-only (no time, movement, stores, wear, events, weather, seeds, rewards) | DONE | test_wind_overlay: time, position, seed and whole saved state unchanged after previewing |  |
| WND-10 | Passage Readiness / cockpit forecasts limited to relevant samples | TODO | | |
| WND-11 | Before/after wind performance measured | DONE | docs/benchmarks/iteration17_checkpointB_*.json: forced full re-sample 1051 → 36 ms (Denmark region, headless); in play spread over frames at ≤ 3 ms |  |

## NAV — Navigation architecture [§4–§8]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| NAV-1 | Three interfaces share one geography, router, catalogue, vessel, voyage, weather, save | TODO | | |
| NAV-2 | Framed world map object in every cabin; contextual interaction; no circle | TODO | | |
| NAV-3 | Cabin world map: whole world, pan, zoom, names, harbours by zoom, search, select, name/country/description, visited, return | TODO | | |
| NAV-4 | Cabin map has no wind/weather overlay; static/cached | TODO | | |
| NAV-5 | Voyage daydreams: real route, distance, 2–3 real intermediate places, modest template variety, no invented names, read-only, cached | TODO | | |
| NAV-6 | Navigation station: regional working chart (~300–500 nm, latitude-aware), boat, coast, harbours, route segment, waypoints, next waypoint, heading, distance/course, weather, wind | TODO | | |
| NAV-7 | Global destinations still plannable from the station | TODO | | |
| NAV-8 | Cockpit chartplotter: lightweight, bounded, boat, heading, coast, route, next waypoint and distance, planned course, local wind; toggle from action wheel and a key | TODO | | |
| NAV-9 | Same route in station, vessel, chartplotter and readiness | TODO | | |

## BOAT — Vessel graphics and movement [§26–§28]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| BOAT-1 | Boat visually turns with heading while the Captain is on deck (all listed scenarios) | DONE | test_sailing_correctness [orientation]: autopilot turns at waypoints with the captain amidships/bow/stern, successive turns, cabin round trip, after load; fails without the fix | Root cause: the deck camera re-turned only on route edits/voyage start |
| BOAT-2 | Player/sail and rigging depth order correct | TODO | | |
| BOAT-3 | White side objects identified; fenders shown moored, stowed underway, correct after save/load | TODO | | |

## SAVE — Persistence [§32–§34, §44]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| SAVE-1 | Save/load underway keeps the Captain aboard (all listed situations), relative positions, safe fallback | DONE | test_sailing_correctness [save]: helm, bow, stern, cabin, after a course change, at anchor, in a gale at night; invalid position falls back to the spawn point | Two-process check in 17I |
| SAVE-2 | Weather persistence: reload reproduces weather; no rerolling; documented | DONE | test_sailing_correctness [weather]: the same save sailed twice gives identical wind, position and condition for 12 h | Weather is a pure function of (position, time, seed); the seed is saved |
| SAVE-3 | F5 quicksave / F9 quickload with confirmation, no double-activation, defined policy | DONE | test_sailing_correctness [quick]: F5 once per press, own file, manual slots untouched, refused with a window open, F9 asks then restores exactly, repeated F9 ignored | Developer test panel moved from F9 to F10 |
| SAVE-4 | Two-process save/load verification (deck, cabin, storm) | TODO | | |
| SAVE-5 | Existing saves load; save format decision documented | DONE | Save format stays 12 (no new fields); test_save_manager, test_voyage_persistence pass |  |

## LGT — Lighting [§16–§21]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| LGT-1 | Day/night cycle (dawn, day, dusk, night) on the game clock with local solar time by longitude; smooth | TODO | | |
| LGT-2 | Correct under Long Passage, sleep, load, harbour | TODO | | |
| LGT-3 | Warm cabin lighting from fixtures, all four boats, personalization-safe | TODO | | |
| LGT-4 | Deck and cockpit night lighting, restrained; helm and highlights visible | TODO | | |
| LGT-5 | Harbour lighting via reusable pattern | TODO | | |
| LGT-6 | Soft shadows and depth; before/after comparison | TODO | | |

## AUD — Audio and storm atmosphere [§22–§25, §39]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| AUD-1 | Wind sound by actual wind; water ambience; rain | TODO | | |
| AUD-2 | Lightning and thunder in thunderstorms, distant/near, cabin light response, no harsh strobe | TODO | | |
| AUD-3 | Cabin vs deck acoustics (muffling), buses ready for I019 alarms | TODO | | |
| AUD-4 | Boat-local visual wind cues agree with actual wind | TODO | | |
| AUD-5 | Assets local, licensed and recorded | TODO | | |
| AUD-6 | Accessibility: ambient/effects volume, flash intensity, UI flashing | TODO | | |

## HUD — Cockpit and action wheel [§29–§31]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| HUD-1 | Right-side sailing panel: speed, heading, wind dir/speed, next-leg forecast wind, time to next course change; optional fields; actual vs planned vs forecast distinguished; collapsible | TODO | | |
| HUD-2 | Course-change notification (>~5°, restrained, accessible) | TODO | | |
| HUD-3 | Context-aware action wheel (helm, cabin, anchor), keyboard, no click-through | TODO | | |
| HUD-4 | Action-wheel shortcut in the bottom help panel | TODO | | |

## PORT — Harbours and arrival [§35–§37]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| PORT-1 | Harbour facilities in destination preview from authoritative data; extensible | TODO | | |
| PORT-2 | Visited harbours grouped by country, collapsible, All/Visited/Not visited | TODO | | |
| PORT-3 | Short docking arrival presentation, skippable, no duplication | TODO | | |

## QA — Testing and delivery [§38, §40–§53]

| ID | Requirement | Status | Evidence | Limitation |
|---|---|---|---|---|
| QA-1 | Long Passage preserved and integrated (lighting, audio, preview, panel) | TODO | | |
| QA-2 | Performance profiling and before/after report (headless vs rendered stated) | TODO | | |
| QA-3 | Full regression | TODO | | |
| QA-4 | 30 rendered screenshots reviewed | TODO | | |
| QA-5 | Shipyard Efficiency section with measured timings | TODO | | |
| QA-6 | CAPTAINS_ORDERS.md updated | TODO | | |
| QA-7 | ITERATION_17_REPORT.md (40 items), WINDOWS_ACCEPTANCE_17.md | TODO | | |
| QA-8 | Version per policy; push and remote HEAD verified | TODO | | |
| QA-9 | No I018–I021 scope started | TODO | | |
