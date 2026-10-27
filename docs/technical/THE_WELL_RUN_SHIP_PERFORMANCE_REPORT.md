# Injection 2: The Well-Run Ship

Performance, memory, sleep, time transitions and Long Passage.

## Starting state

| | |
|---|---|
| Branch | `claude/friendly-fermat-dey23f` |
| Start commit (remote HEAD, verified clean) | `8cf8c19` (Injection 1, Cozy 4) |
| Checkpoints | `7862607` + `4ced918` (theme fix, time passages, voyage map, probe, tests) |
| Final commit | the commit that adds this report; the hash is given in the delivery message |
| Version / save format | 0.105b / 12, unchanged. No save changes: nothing new is saved |
| Engine | Godot 4.7.2 (Linux) |
| Renderer for frame times | OpenGL 3 (Compatibility) on **llvmpipe** (Mesa software rendering, LLVM 20) under xvfb, 1600×900, vsync off, no frame cap |
| Windows acceptance | **pending**. Software rendering puts the GPU's work on the CPU, so absolute frame times here are much slower than on a real machine, and night scenes (2D lights) are especially slow. The numbers are for before/after comparison on the same setup only |

The probe is `tests/benchmark_wrs.gd`:
- It ran **3 times on the untouched start commit** (in a separate worktree) and **3 times on the final code** (with `--no-time-passage`, so the same work is measured).
- One more run (`--presented`) measured the new presentations as the Captain sees them.
- Results: `docs/benchmarks/well_run_ship_*_rendered.json`.

---

## Diagnosis

### What reproduced

| The Captain reported | Reproduced? | Measured (3 baseline runs, worst frame) |
|---|---|---|
| Sleeping makes the game exceptionally sluggish | **Yes**: right after waking, not during sleep | Frames of **0.81–0.89 s** after every sleep. The sleep call itself took about 1 ms in harbour |
| Night → day causes a major stall | **Yes** | **1.2–1.4 s** frames, repeatedly, through every dawn and dusk |
| Day/night while walking in a harbour stalls | **Yes** | **0.94 s** worst frame while walking at 20× through a sunset |
| The navigation station makes it worse | **Yes, much worse** | **2.3–2.5 s** frames through a sunrise with the chart open |
| Transitions get slower after several game days | **No** | Six successive dawns and dusks: the same 1.2–1.4 s each time, no trend |
| Movement gets janky after longer sessions | **Not reproduced** | Walking on deck after 20 rounds of deck, cabin, chart and sleep: median 37–39 ms, the same as at the start. The jank was the twilight stalls |
| The game gradually accumulates work | **Not reproduced** | Over 20 rounds: nodes 313 → 313, autoload signal connections 83 → 83, orphan nodes 0, audio players, timers and tweens flat, static memory 228.7 → 228.7 MB |
| Long Passage may be inefficient | **Partly** | The simulation was already efficient (about 9 ms per frame at 12 h/s). Each frame still rendered the whole deck, and Long Passage hit the twilight stall every second or two (1.2 s frames) |

### The root cause: one colour change at a time, each refreshing every control

`UiTheme` (the Vintage Chartroom / Harbor Dusk theme) recolours the **project theme** as the light changes:
- about 80 style boxes and about 200 theme colours, set one by one;
- every 0.25 s during dawn and dusk (`MIN_STEP` 0.02).

Every `Theme.set_color()` and every style-box colour change emits the theme's `changed` signal. For the project theme, each emission sends a theme refresh through the whole scene tree: every control re-reads its theme items and is laid out again. So one blend step meant **about 280 whole-tree refreshes**.

Measured with `tests/scratch/probe_daynight.gd`:

| One `set_blend()` call | Before | After |
|---|---|---|
| Deck shown (about 570 nodes) | **650–770 ms** | **3.5–5 ms** |
| Chart open (about 7,560 nodes) | **2,190–2,420 ms** | **9.5–12 ms** |

That explains everything that reproduced:
- **Dawn and dusk:** about 20 such steps per twilight, each one frozen frame.
- **The chart:** it has the most controls, so it was worst.
- **Waking after sleep:** the clock had jumped hours, and the interface then eased to the new light over about 4 s of frozen steps.
- **Long Passage at 12 h/s:** it crosses a twilight every couple of seconds.
- **Starts and loads at night:** they paid it too.

**Fix (one line of intent):** `set_blend()` now blocks the theme's signals while it recolours, then emits `changed` once. One whole-tree refresh per step instead of about 280. Nothing visual changed: the same colours and the same easing.

### Suspected, checked, not confirmed

- **Nodes not freed, orphans, scene ownership.** Node, object and orphan counts are flat across long sessions and repeated chart, cabin and deck changes (probe `growth` rows; the `[growth]` test).
- **Duplicate signal subscriptions.** Autoload connections are flat (83 on the start code, 86 on the final code: three new one-off connections for the watch and the voyage map, constant).
- **Unbounded caches.**
  - The weather caches clear at `MAX_CACHE`.
  - The router's leg cache is limited (`LEG_CACHE_LIMIT`).
  - The approach cache is per port.
  - The chart's spot cache holds 64 entries; the daydream cache 64.
  - Map land caches are static, built once.
  - The probe tracked the weather and router caches: bounded.
- **Audio players or textures re-created.** The audio-player count is flat (13 → 15 → 17, then constant: the music and weather players are made once). Music tracks are loaded once at start.
- **Per-frame allocations, timers.** No timer nodes are created during play. The tween count stays at 2–5.
- **Injection 1's floating debris.** It is a fixed pool of 16, with no allocation per frame. Sailing at 1× measured 34 → 33 ms median, unchanged. Not a cause.
- **Night-time rendering.** Night frames on deck are about 120 ms against about 55 ms by day. This is the 2D lights drawn in *software* (hiding the lighting saves about 38 ms). It is the same with time stopped or running, so it is not script work. Not changed, to keep the lighting; it should not show on a real GPU (Windows acceptance will tell).
- **The sleep simulation itself.** It is one `Simulation.advance()`, not frame by frame (already event-driven since I003): about 0 ms in harbour, **130–175 ms** for 8 hours underway. It was not the cause of the sluggishness and is now under the black card.

### The Captain's question: is the session kept in memory or written to disk?

**In memory.** Everything that happens in a session (the game state, the voyage, weather, caches, the interface) lives in memory. Nothing is written to disk on its own while you play: **there is no autosave.**

**Written to disk, and when:**

| File (Windows: `%APPDATA%\Little Captains Hat\…`) | What | When | Grows? |
|---|---|---|---|
| `saves/slot_N.json` (plus `.bak`, through a temporary file) | The game | Only when you save (Save menu, or F5 quicksave) | One file per slot, replaced each time |
| `settings.cfg` | Preferences: volumes, window, interface light, art style, the remembered sleep duration | When you press Save in Settings, or when the sleep duration you chose changes | No |
| `diagnostics/*.jsonl` | The diagnostic session log: meaningful events only (screen changes, sleep, voyages, saves, errors), never per frame. About 9 lines per round of deck, cabin, chart and sleep | One line per event, written and flushed at once (so a crash keeps it) | Bounded: at most 5,000 lines / 1 MB per file, newest 10 files kept |
| `logs/godot.log` | Godot's own log (engine messages; the game prints nothing in normal play) | As the engine writes | Godot keeps 5 files |

**Memory-only caches** (cleared when the game closes):
- weather samples;
- route legs and approaches;
- map land triangles, the cabin map, sprite and companion art, fender and facility data;
- the chart's anchorage spots and the daydream routes.

**Kept across launches:** only the saves, `settings.cfg` and the logs above. Godot's shader cache is the engine's own.

**Responsiveness.** One small flushed line per meaningful event is negligible, and nothing is written per frame. No essential persistence was removed and no saves were touched.

---

## Performance

### Before → after

Medians over 3 runs each. Frame times are in milliseconds, under software rendering. "Worst" is the single longest frame in the scenario.

| Scenario | Median frame | p99 | Worst frame |
|---|---|---|---|
| Day/night at the **chart**, 20× | 50 → 48 | **2,322 → 69** | **2,485 → 81** |
| Day/night **walking in harbour**, 20× | 61 → 58 | **897 → 151** | **940 → 264** |
| Day/night **sailing**, 20× | 60 → 60 | **1,135 → 80** | **1,216 → 88** |
| 6 successive dawns/dusks in harbour (each) | 54–124 → 54–122 | **1,175–1,239 → 137–155** | **1,236–1,374 → 154–190** |
| After **sleeping 8 h across midnight** | 84 → 82 | **841 → 112** | **891 → 116** |
| After **sleeping 4 h across sunrise** | 66 → 65 | **812 → 108** | **845 → 116** |
| After **sleeping 4 h across sunset** | 83 → 82 | **809 → 107** | **878 → 119** |
| **Long Passage**, 12 h/s, on deck | 77 → 76 | **1,176 → 108** | **1,245 → 115** |
| Chart open, idle | 49 → 45 | 65 → 61 | 67 → 65 |
| Walking on deck in harbour (day) | 54 → 64 * | 72 → 80 | 190 → 106 |
| Walking in the cabin (day) | 65 → 63 | 84 → 82 | 89 → 88 |
| Sailing at 1× | 34 → 33 | 44 → 44 | 48 → 47 |
| Walking on deck after a 20-round session | 39 → 37 | 50 → 50 | 55 → 59 |
| Opening the chart (12 times) | 66 → 65 per open | | |
| Startup, probe start to loading done | 1,131–1,511 → 924–945 ms | | |

\* **Walking on deck (day):** the median is bimodal from run to run on this renderer (before 58 / 54 / 54, after 64 / 54 / 64), so this is not a regression.

\*\* **Startup:** measured shorter. `set_blend` also runs at start and on a new game, so the theme fix is the likely cause. This is **not proven**.

**The new presentations** (`--presented`, one run):

| Presentation | Frames | Median | Worst | Duration |
|---|---|---|---|---|
| 8-hour sleep (fade, clock, fade back) | 71 | 88 ms | 118 ms | about 6 s in all; any key skips |
| Dawn card | 61 | 62 ms | 167 ms | |
| Long Passage on the **voyage map**, 12 h/s | 360 | **42 ms** | 85 ms | against 76 ms median on deck: the deck and HUD are hidden and not processed while the map shows |

### Memory, node and resource trends

Before, and identical after: no growth anywhere.

| Measure | 20 rounds of deck, cabin, chart and sleep | Six day/night cycles |
|---|---|---|
| Nodes | 313 at every check | |
| Objects | 2,948–2,954 | |
| Orphan nodes | 0 | |
| Autoload connections | 83 before, 86 after, constant | constant |
| Static memory | 228.7 MB before, 229.2 MB after, flat | |

### The three biggest improvements actually achieved (measured)

1. **Twilight at the chart:** worst frame **2.5 s → 0.08 s**. `set_blend` at the chart is 2.3 s → 0.01 s.
2. **Every dawn and dusk** (harbour, sailing, Long Passage, and after every sleep): worst frames **0.8–1.4 s → 0.09–0.26 s**. `set_blend` on deck is 0.7 s → 0.004 s.
3. **Long Passage:** median frame **76 ms on deck → 42 ms on the voyage map**, and its 1.2 s stalls are gone.

Expected but not measured here: these remaining worst frames are mostly software rendering. On a GPU they should be far smaller.

---

## Remaining opportunities

| # | Problem | Evidence | Expected gain | Confidence | Effort | Risk | Priority |
|---|---|---|---|---|---|---|---|
| 1 | Long Passage and underway sleep: the weather assessment scans the route ahead (`route_hazards`, 6 h at 2 nm steps) at every 5-minute grid point | 8 h asleep underway costs 130–175 ms. Long Passage simulation is about 9 ms per frame at 12 h/s | About 3–5× less simulation time. Cache the hazards along the route per half hour of forecast time | Medium | Medium | **Medium**: warnings must stay identical however time is chopped (existing tests guard this) | **Next**, if Windows shows Long Passage cost |
| 2 | The chart is about 7,560 nodes (labels and markers as controls) | Opening costs 65 ms. It also made the old theme stall 4× worse | Faster opening, cheaper theme refreshes, fewer nodes to lay out | Medium | Medium–high (draw labels instead of nodes) | Medium (hover, tooltips, tests) | Later |
| 3 | Night 2D lights under software rendering | About 38 ms per frame on llvmpipe | Probably none on a real GPU | Low | — | — | **Measure on Windows first** |
| 4 | The interface still eases the twilight in steps when no card is shown (polar summer, Long Passage) | Each step is now about 4–12 ms | Small | High | Low (fewer steps) | Low | Low |
| 5 | The HUD's panels refresh their text every frame (`PassagePanel.refresh`, `SailingPanel`) | A few ms per frame at most (noisy) | Small | Low | Low | Low | Low |

Quick, high-confidence item: the theme batching, **done**. Medium: #1 and #2. Architectural: none needed. The simulation was already event-driven.

---

## Gameplay

### Day/night transition: IMPLEMENTED

`DayNightWatch` (src/world) watches the sun at the boat each frame. When, in ordinary play, the morning twilight starts (the sun rises through −6°) or the evening one does (it sinks through +4°), `App.play_new_light()` runs this sequence:

1. Gameplay pauses and the screen fades to Harbor Dusk ink (0.7 s).
2. The date, "9 May 2026", fades in, with the weekday phrase beneath it: "a Saturday", or "a Friday evening" at dusk. The weekday comes from the game's own calendar.
3. Under the black, the rest of the twilight passes with the normal `Simulation.advance(…, true)`. Stores, weather, wear, the hat and events apply as always; an event stops it early and reports itself, and the clock drops to 1× as in fast time.
4. The interface and the boat's light take the new hour at once, then the game fades back (1.0 s). In all it takes about 4 s; any key skips ahead.

Rules:
- **No redundant fades.** One card per twilight. It never shows over a menu, during Long Passage, while sleeping, during a screen change or over another card.
- **No card after a jump in time.** Load, sleep, work and outings ashore never trigger one (a gap of more than 30 game minutes between two looks is a jump).
- **High latitudes.** Where the twilight lasts more than two hours (summer far north), no card is shown and the light changes slowly, as before.
- **State is preserved.** Nothing is rebuilt: the screen, the chart's zoom and course, open panels and the player's position stay as they are. Music follows its own gentle day/night change.

### Sleep transition: IMPLEMENTED

1. Choose the hours. The remembered duration from Injection 1 is kept.
2. The screen fades to black, showing the date, the weekday and the start time.
3. The simulation runs **once** under the black (`Simulation.sleep`: one event-driven advance; stores, weather, the anchor, wear and events as before).
4. The ship's clock then counts the hours slept, one every 0.42 s. Midnight turns the date and the weekday.
5. An early waking is named on the card ("Woken by a weather warning").
6. The game fades back in the new light, in the berth, with the usual wake-up message.
7. Any key or click skips to the fade back. A second sleep cannot start while one is on screen.

### Long Passage: IMPLEMENTED (the presentation), simulation kept

**Audit:**
- **Time:** it already advanced as event-stopping chunks of the one `Simulation.advance()` (`passage_rate` × frame time).
- **Position:** follows the route's own path (vertices, canal reaches, the Date Line).
- **Weather:** a pure function of time.
- **Consequences:** supplies are used per step (`apply_simulation_step`), and wear is applied per step (`_wear`: engine hours or rig wear).
- **Events:** arrival, weather warnings, bite, rescue, the anchor, anchorage waypoints, low stores, boat care and the hat stop it (`passage_interrupted`).
- **Saving:** the passage clock is not saved; loading and arriving return to normal time.
- **Cost:** about 9 ms of simulation per frame at 12 h/s. It does not depend on the frame rate (one 8-hour step and thousands of small ones give the same result: existing tests).

**Decision.** The simulation needed no rewrite: it is already the "small number of correct calculations" the order asks for. What cost time was rendering the whole deck under it and the twilight stalls. So the redesign is the presentation, not the simulation: the **voyage map**.

**The voyage map** (`src/ui/voyage_map.gd`):
- **Opening:** starting Long Passage fades the game away.
- **The atlas:** parchment sea and land by day, deeper colours by night, following the interface.
- **The route:** the voyage's real path, one line across the Date Line, canals included. Sailed water is solid red, the rest dashed.
- **Markers and panel:** a small boat at its real position on it, the start and the destination. Date and time, distance to go, arrival estimate and progress.
- **Speeds:** 1 / 4 / 12 h/s, and *Take the helm*.
- **Interruptions:** the clock stops where the event happened. The atlas says why and circles the boat, with *Back aboard* and, where resuming is possible, *Sail on*. *Sail on* is not offered at arrival, at an anchorage (drop the anchor first) or after a rescue.
- **No repeats:** an unresolved event does not fire again. Weather warnings and stores warnings are remembered in the state; the boat-care notice and the hat are the existing mechanics.
- **Arrival:** shows "Land ho!". *Back aboard* then plays the usual docking arrival.
- **Light:** the deck and HUD are hidden and not processed while it shows. The land is one cached triangle batch (shared with the cabin's wall map) drawn only when the view changes; the route and boat redraw 12 times a second.
- **Closing:** at once on a load, a rescue or any screen change.
- **Not yet built:** there is no new event system and no I019 work. New I019 events can stop the passage through `Simulation`'s existing stop reasons, and the map shows them.

### Save/load behaviour

- No new saved data. The save format stays 12, and the Injection 1 coffee key is untouched.
- Saving during Long Passage: as before, the Save button and quicksave stop the passage first.
- A load during the voyage map closes it and restores the boat scene (tested).
- After an interruption the state is ordinary normal time, and saves and loads as always.
- Old saves are covered by `test_save_manager` (all migrations) and `test_cozy_polish` (with and without the coffee key).

---

## Verification

**Tests run, all passed (Linux, headless):**

| Run | Checks | Failed |
|---|---|---|
| **`test_well_run_ship` (new)** | **41** | 0 |
| Related suites (29, listed below) | 2,551 | 0 |
| Further suites (9, listed below) | 417 | 0 |

`test_well_run_ship` also passed 41/41 in the rendered screenshot run at 1600×900.

What `test_well_run_ship` covers:
- **Theme:** one theme change per day/night step, on deck and at the chart; recolouring with the chart open takes 10 ms.
- **Growth:** six rounds of deck, cabin, chart, sleep and day/night leave nodes, connections, audio players, orphans and tweens as they were.
- **Dates:** the date, weekday and evening phrase, a new year, the clock.
- **Twilight:** when it ends, and no card in the midnight sun.
- **Sleep:** the clock counts 21:00 → 05:00, and midnight turns "7 May 2026, a Thursday" into "8 May 2026, a Friday". It takes 5.7 s, stores are used, the captain wakes in the cabin and is told. A key skips (control back in 1.7 s), and two sleeps never overlap.
- **Dawn and dusk:**
  - dawn brings the card, and the twilight passes with the simulation (stores used);
  - once per twilight;
  - no card after a jump in time, never over a menu;
  - the evening card is followed by Harbor Dusk.
- **Long Passage:**
  - the map opens, and the deck and HUD are hidden and not processed;
  - the boat follows the route (0 px off);
  - date, distance and arrival are shown;
  - an interruption says why and offers *Sail on*, which resumes from the same place;
  - a load closes the map and restores the boat;
  - *Take the helm* returns to normal time;
  - through the Kiel Canal to "Land ho! Cuxhaven" and *Back aboard*;
  - Nouméa → Papeete across the Date Line, one line with the boat on it;
  - a planned anchorage stops it without *Sail on*.

The 29 related suites:

routing (Kiel, Suez, Panama), navigation_views, cockpit_ui, save_manager, voyage_persistence, settings_and_audio, life_aboard, chart_and_pause, vessels, catamaran_cabin, weather, weather_ui, captains_log, hat, branding, living_world, fishing, fishing2, sail_trim, anchorage, anchorage_overlay, cozy_patch, chartroom_ui, soundtrack, cozy_polish (pins, coffee, canals), well_run_ship, galley_and_anchor, long_passage, gameplay_flow.

The 9 further suites:

sprite_workshop, companion_art, world_voyage, world_chart_render, harbour_chart, save_manager, joy_journey, long_passage, life_aboard.

**Changed tests (on purpose):**
- The test runner switches the time presentations off (`TimePassage.enabled = false`), so the existing logic suites keep their synchronous sleep and continuous dawn.
- The new suite switches them on.

**Not run:** the full historical suite (not as ceremony; the shared simulation code itself did not change). No Windows run.

**Evidence** (`docs/screenshots/well_run_ship/`):
- `wrs_sleep_clock_midnight`: the sleep card at 01:00, 8 May, a Friday.
- `wrs_dawn_card`: 9 May 2026, a Saturday.
- `wrs_dusk_after`: Harbor Dusk after the evening card.
- `wrs_voyage_map`: Copenhagen → Reykjavík.
- `wrs_voyage_map_interrupted`: "Weather ahead…", with *Back aboard* and *Sail on*.
- `wrs_voyage_map_date_line`: Nouméa → Papeete across 180°.
- Benchmark JSON files: `docs/benchmarks/well_run_ship_*`.

**Known limitations and remaining risks:**
- **Frame times** are from software rendering. On Windows the remaining worst frames should be far smaller, but that is **expected, not measured**.
- **Underway sleep** still costs one 130–175 ms simulation call, hidden under the black (opportunity #1).
- **Skipped twilight.** At 1× a dawn or dusk is no longer watched in real time: its 50–80 game minutes pass under the card. This is intentional, per the order, and the twilight still passes fully at the poles.
- **Card dates use the ship's clock (UTC)**, like the HUD, not local time. In the far Pacific the card's date can differ from the local day by one.
- **The voyage map's land** is the world overview shape (the cabin map's), not the chart's detailed coast. Very short passages show coarse coastlines.
- **Single runs:** the presented-experience numbers are one run.

**Files changed:**
- `src/ui/theme/ui_theme.gd`: batched recolouring.
- `src/ui/time_passage.gd` (new).
- `src/world/day_night_watch.gd` (new).
- `src/ui/voyage_map.gd` (new).
- `src/app/app.gd`: sleep through `TimePassage`, `play_new_light`, `snap_light`, the voyage map.
- `src/core/simulation.gd`: the `passage_started` signal.
- `src/boat/cabin_world_map.gd`: shared land triangles and the aspect ratio.
- `tests/benchmark_wrs.gd` / `.tscn` (new probe).
- `tests/suites/test_well_run_ship.gd` (new).
- `tests/test_runner.gd`.
- Docs: `docs/technical/ARCHITECTURE.md` (*Time passing on screen*), `docs/technical/CAPTAINS_CHARTROOM_UI_PASS.md`, this report, `docs/README.md`.
- Evidence: `docs/benchmarks/well_run_ship_*`, `docs/screenshots/well_run_ship/`.

There is no GDScript architecture guide in English or Danish in the repository yet, so the technical architecture document carries the update. I019 was not started.
