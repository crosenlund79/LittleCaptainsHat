# Revision 0.105b — Safe Harbours, Deep Waters & the Sprite Workshop

Assignment: `REVISION_0_105B_ASSIGNMENT.md` (verbatim). Tracker:
`REVISION_0_105B_REQUIREMENTS.md`. Windows checklist:
`WINDOWS_ACCEPTANCE_0_105B.md`. Sprite Workshop: `docs/artwork/SPRITE_WORKSHOP_REPORT.md`
and `art_replacements/README_START_HERE.md`.

**Windows acceptance is pending.** Everything here was verified on Linux
only. Numbers are measured unless marked *estimate*.

## 1. Baseline

- Branch `claude/friendly-fermat-dey23f`, HEAD `2f1ed06` ("I018: record the
  Checkpoint I push in the report"), equal to the remote; clean working tree.
- Version 0.105a (`GameVersion.DISPLAY`, `project.godot`), save format 12
  (`SaveManager.SAVE_VERSION`).
- I018 documents present (`ITERATION_18_*`, `docs/iterations/i018/WINDOWS_ACCEPTANCE_18.md`,
  `CAPTAINS_ORDERS.md`). The I018 report's figures (4,184 checks, 17 restart
  checks) are its own records of runs on `f8d68ed`; they are re-verified by
  this revision's own full regression rather than re-run at the start.

## 2. Final version and save format

- Version **0.105b** (`GameVersion.DISPLAY`, `project.godot`).
- **Save format 12, unchanged.** Every new piece of state is an optional field or an existing mechanism:
  - `AnchorState` gains `kind` (normal / magic), `depth_m`, `depth_source` and `bonus_kn`; all optional with defaults, so 0.105a saves load as normal anchors.
  - Magic Anchor ownership is a progress mark (`equipment:magic_anchor`), so no new field is needed.
  - The anchorage type of a waypoint is **recomputed** from its saved position (depth is deterministic), so it is not stored.
  - Depth tables, the overlay and images are never saved.
  - An old save at anchor with the engine running is corrected on load.

## 3. Checkpoint commits

| Checkpoint | Commit | Content |
|---|---|---|
| A | `a52f8aa` | Assignment, tracker, root cause |
| B | `bd16387` | Fine coastal raster, depth service, anchoring rule, router links |
| C | `6313113` | Anchorage overlay and waypoint selection |
| D | `574aae5` | Magic Anchor, shared timing check, engine-off anchoring, solar panels |
| E/F | `2803394` | Sprite Workshop catalogue, resolver hooks, working replacements, restart tests |
| G | `aa8fe0b` | Evidence scenes, benchmarks with provenance, version 0.105b |
| H | final commit (see §27) | Final regression, report, tracker, checklist, orders |

## 4. Why anchoring stopped at the Danish chart's edge (root cause)

Established from the code (I018 state):

1. **Where suitability is calculated**: `AnchorSite.evaluate()`
   (`src/anchor/anchor_site.gd`) for anchoring at the boat, and
   `GameSession.anchorage_spot()` for anchorage waypoints. Both apply the same
   rule: the point must be a **navigable routing cell**, and land must be
   within `MAX_LAND_NM` = 2.5 nm.
2. **Which coastline**: the routing raster (`NavGrid`), not the drawn
   coastline. The world raster has 12 cells per Mercator degree (about 5 nm
   cells, `data/navigation/world/world.json`); Europe 60 (about 1 nm);
   Denmark a further 6× finer.
3. **How distance to shore is computed**: `HatStory.open_water_nm()` scans
   neighbouring raster cells and returns the distance between **cell
   centres** minus half a cell. On the world raster the nearest non-water
   cell centre is at least one cell (≈5 nm) away, so the result is ≥ about
   2.5 nm — never below the 2.5 nm limit, by construction.
4. **Water depth**: **not represented at all.** "Near land" stood in for
   "the anchor reaches the bottom"; there is no bathymetry in the game.
5. **Different resolution from routing?** No — the same raster, which is the
   problem: a raster cell is "navigable" only if **no part of it** touches
   land (`build_world.py`: land if any 4×4 subsample is land). Near a coast
   the world raster keeps only water that is a whole cell (≈5 nm) clear of
   land, so every navigable world cell is at least ~2.5 nm (half a cell) from
   the coast, and its measured distance is larger still.
6. **Boat position vs land**: the voyage path is validated against the
   raster (`SeaRouter.validate_route`, `is_point_navigable`); on load,
   `GameSession._recover_voyage` moves a boat whose position is not on a
   navigable cell to the nearest one.
7. **Anchorage waypoints**: validated by `anchorage_spot()` (above) and by
   the router, which requires every waypoint to be on a navigable cell.
8. **Scope, holding, dragging**: `AnchorSite.holding()` /
   `holding_margin()` (power from scope, set quality, shelter, equipment
   against the wind and gusts), checked on the simulation's grid by
   `GameSession.apply_anchor_check()`, which also moves a dragging anchor
   downwind.
9. **Saved state**: `AnchorState` (active, position, scope, set quality,
   holding, dragged distance, alarm, times, moments) in save format 12.
10. **Accuracy**: the drawn land and the raster come from OpenStreetMap land
    polygons (about 100 m accuracy, `world.json`); the *coastline* is good
    enough for a game, the *5 nm raster* is not good enough to say how close
    to the shore water is, and there is *no depth* at all.

**So the restriction had two causes, not one**: (a) a measurement artefact —
distance to shore measured on 5 nm cells can never be below ~2.5 nm; and
(b) the rule used "near land" as its only proxy for depth. Relaxing the
2.5 nm constant would have hidden (a) and kept (b). This revision instead
measures the coast on a fine coastal raster from the same OSM polygons,
models depth separately, assesses shelter separately, and connects a
near-shore anchorage to the routing network by a short, checked approach
(sections 5–7).

## 5. Real-world depth sources: what was tried

| Source | Edition | Result in this environment |
|---|---|---|
| GEBCO gridded bathymetry (gebco.net, betadownload.gebco.net, download.gebco.net) | GEBCO 2026 (15 arc-second) | **Not reachable**: the session's egress proxy refused the connection (HTTP 403 on CONNECT) |
| EMODnet Bathymetry (emodnet.ec.europa.eu) | DTM | **Not reachable** (403) |
| NOAA ETOPO via ERDDAP / THREDDS (coastwatch.pfeg.noaa.gov, ngdc.noaa.gov) | ETOPO 2022 | **Not reachable** (403) |
| Natural Earth bathymetry polygons (naciscdn.org) | 1:10m | **Not reachable** (403) |
| Package registries (npm, PyPI) — the only reachable hosts | searched "bathymetry", "gebco", "etopo", "ocean depth" | **No depth grid packaged.** The closest, PyPI `basemap-data` 2.0.0, contains `etopo1.jpg`, a *coloured shaded-relief picture*, not depth values: using it as depth would be dishonest, so it was not used |

**No real bathymetry was acquired.** All depths in 0.105b are **game
estimates**, labelled as such everywhere they are shown. The depth service
is built with a slot for real data (section 6) and a documented
preprocessing script, so a GEBCO subset can be added later without code
changes; that script was tested only on synthetic input.

What *was* acquired: the same OpenStreetMap land polygons the world chart is
built from (npm `@geo-maps/earth-lands-100m` 0.6.0, SHA-1
`bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41`, ODbL 1.0, © OpenStreetMap
contributors), used at full resolution for the new fine coastal raster.

## 6. Where estimates replace source data: the depth service

`DepthService` (`src/navigation/depth_service.gd`) is the one place the game asks for depth. It has three tiers:

| Tier | Source | Status in this build |
|---|---|---|
| A | Regional data file | None installed |
| B | Global model subset (`data/navigation/depth/depth.bin`, made by `tools/navigation/build_depth.py` from a GEBCO-style ASCII grid) | None installed |
| C | Deterministic **GAME ESTIMATE** | Everywhere |

So **every region uses the game estimate.** How the estimate works:

- **Formula:** depth = 3 m + 17 m × slope × shore_nm^0.9, with the shore distance capped at 6 nm.
- **Slope:** a fixed-seed value-noise field on a 0.75° lattice, contrast-stretched to 0.55–3.2, which gives gentle shelves and steep island flanks.
- **Shallow shelf seas:** a gentler slope range in the Danish straits and Kattegat, the Baltic and the southern North Sea.
- **Enclosed bays:** shallower.

It never depends on the game seed, the time or the boat: the same place gives the same depth in every game and after every restart (`[depth]` tests, `restart_105b` A).

**How it is shown:** "about 9 m", in 5 m steps above 10 m and 50 m steps above 100 m, always with "GAME ESTIMATE". **Not for navigation.**

## 7. International anchorage coverage

**The fine coastal raster.** `CoastalGeography` covers 1/120° (about 0.5 nm north–south) from 72° S to 80° N:

- 6,315 mixed 1° tiles, bit-packed, decoded on demand (512-tile cache);
- built from the same OSM land polygons as the world chart;
- the Danish regional chart stays authoritative where it is at least twice as fine.

**A spot is anchorable when it is:**
- water, with water on all four sides;
- at least 0.2 nm from the shore (planning);
- **reachable**: a short approach over clear water to a routing-navigable cell, at most `approach_max_nm` (about 11 nm on the world grid). A one-cell gap is refused and a three-cell channel allowed (synthetic test).

**Then:**
- the **normal anchor** needs 2.5–25 m and wind up to 34 kn;
- the **Magic Anchor** works at any depth and in wind up to 55 kn;
- **shelter** is judged separately, from the open water upwind.

Verified in the six acceptance areas (`test_coastal_depth [areas]`), each with a normal anchorage near its harbour:

- Nyborg (the Belts);
- A Coruña (Iberia);
- Las Palmas (Canaries);
- Falmouth Harbour, Antigua (Caribbean);
- Papeete (French Polynesia);
- Whangārei (New Zealand).

Also verified: Madeira's steep coast takes the Magic Anchor (rb_23), and the open Atlantic takes the offshore Magic Anchor (rb_12).

## 8. Overlay design and cache

`AnchorageLayer` (`src/navigation/anchorage_layer.gd`) is drawn only when the **Anchorages** switch is on **and** the chart is zoomed in past 700 px per degree. At world zoom the legend just says to zoom in.

**How it fills:**
- It works per 1° tile at 1/60° cells, visible tiles only.
- Each tile is a job in stages: land, clear water and reach, per-cell classification, texture.
- Work is limited to a 3 ms frame budget; measured p95 is 3.2 ms of work per busy frame, maximum 5.0 ms, over 271 frames.
- Up to 48 tiles are cached and the least recently used are evicted. Panning back reuses them, and wrapped longitudes share keys (Date Line test).

**Exactness:** the per-cell classification is an exact replica of the waypoint rule, and agrees with it on 375 of 375 sampled cells.

**What the player sees:**
- **teal**: normal anchor;
- **amber**: Magic Anchor;
- nothing elsewhere;
- pointing at the water shows a short note with anchor type, depth (GAME ESTIMATE) and land distance.

Anchorage waypoints use the same rule (`anchorage_spot`). An amber spot shows an amber ring and "(Magic Anchor)" on the chart.

## 9. Magic Anchor mechanics

- **Access:** Boat care → Equipment → **Magic Anchor (Multi-purpose Deep Anchor)**, "Fit it (free prototype)".
  - Fitted free at any boatyard until the chandlery of I020 sets a price.
  - Kept by the Captain, so it works on all four boats.
  - The game stays fully playable with the normal anchor alone.
- **Eligibility:** navigable, reachable water (never land or a closed-off gap), any depth, wind up to 55 kn. Beyond 3 nm from land it counts as **offshore**: it holds the boat's position and the game says it is **no shelter** from wind or waves.
- **Depth:** the true estimated depth is stored and shown (for example "about 250 m, GAME ESTIMATE"), not falsified. The holding model has no depth term, so the effective holding is that of an ordinary well-set anchor, documented as fictional.
- **Presentation (modest):**
  - a brass glow round the dial when it bites;
  - on deck, a small turning brass gear at the bow fitting;
  - a short brass-tinted line (never a rope across the sea);
  - a brass band on the buoy;
  - an amber ring on the chart.
  - The usual ball and anchor light stay.

## 10. Skill check and balance

`TimingCheck` (`src/skills/timing_check.gd`) is the I018 reel dial extracted: the fishing `ReelTiming` now extends it unchanged (test_fishing2 88/0, fishing 180/0). `MagicAnchorDeployment` adds the anchoring rules:

| Wind | Good turns | Arc |
|---|---|---|
| Under 17 kn | 1 | 70° |
| 17–27 kn | 2 | 58° |
| 28 kn and up | 3 | 48° |

- The needle turns at one constant 200°/s, with no random failures.
- A **miss** costs 5 game minutes. After **3 misses** it has not bitten: the boat stays unanchored and drifting, and the Captain is told and can **Try again** (a fresh dial) or **Cancel** (nothing let go).
- Each **Perfect** adds 1 kn to holding, at most 3 kn.
- Success anchors through the same `GameSession` path as the normal anchor.

Balance is a first proposal for the Captain's feel test (Windows §7).

## 11. Holding and drag integration

There is one `AnchorState` and one `AnchorSite.holding()` model for both anchors; the Magic Anchor only adds its bounded Perfect bonus. The same alarm and the same drag apply.

Drag now never moves the boat onto land: the next downwind step must be afloat by the router's rule. On a lee shore the boat stays and scrapes, with the existing grounding wear.

**Engine (§14A):**
- Anchoring (normal or Magic) sets the one propulsion state to sail with speed 0.
- `is_motoring()` is false at anchor.
- The simulation never runs propulsion while anchored.
- `engine_start_refusal()` answers "Let's raise the anchor before starting the engine."
- Raising the anchor starts nothing.
- Old saves with the engine running at anchor are corrected on load.

The game has no manual engine switch (the crew runs it), so the friendly message is the API answer that any future engine control will use.

**Solar panels (§14A B):**
- 1 small panel on the Arctic Wanderer's stern rail;
- 2 on a stern arch on the Wing 33 and the Frogleap 36;
- 3 across the Clam 40's davit arch.

They are part of each deck scene, so they turn with the boat. They sit aft of the walkable deck (no walkable cell, station or pet spot under them). They are visual only: no processing, nothing saved, no equipment entry. A Sprite Workshop replacement (`boat.shared.solar_panel`) is READY.

## 12. Save compatibility

Covered in §2. Old 0.105a anchored saves load as normal anchors (test_anchor_life `[save]`, the old-style engine-on save in test_magic_anchor and restart_105b A).

## 13–19. Sprite Workshop

Details are in `docs/artwork/SPRITE_WORKSHOP_REPORT.md`; the artist's start is `art_replacements/README_START_HERE.md`.

- **Hierarchy and schema:** 10 categories, 34 folders, each with `manifest.csv` (20 required columns plus 6 for counting) and `README.md`. `INDEX.md` is generated by `tools/art/build_index.py`.
- **Catalogued:** **202** entries.
- **READY:** **124**: 40 boat layers, 70 fish and junk layers, 8 pet poses, 3 hat drawings, buoy, ball, solar panel. Each is verified through its real consumer.
- **Needing adapters:** **42** (the walking Captain, sails, windlass, rod, stove, gangplank, harbour set, drifting debris). **36** are reference only.
- **Complexity:** C1 71, C2 75, C3 39, C4 17.
- **Resolution classes (READY):** S 23, M 10, L 51, XL 40.
- **Inventory:**

  | Scenario | Designs | Drawings | Points |
  |---|---|---|---|
  | A minimum | 38 | 50 | 531 |
  | B practical | 52 | 93 | 704 |
  | C full | 81 | 187 | 885 |

- **First 25:** led by Snøvs resting, the Captain, the worn hat and the Arctic Wanderer 26's layers (full table in `INDEX.md` and the workshop report §8).
- **Demonstrations** (test_sprite_workshop, all passed), each through: original → valid → shown at the right size and pivot → removed → original → invalid → warning and fallback:
  - anchor buoy (rb_16/17);
  - Snøvs resting (rb_18/19);
  - AW26 coachroof layer (rb_20/21).

  Fallback and validation screenshots: rb_25 and rb_26.

## 20. Performance measurements

**Harness.** `tests/benchmark_105b.tscn` uses the I018 scenes (Starling 33, night) plus the chart's anchorage overlay. It is rendered under Xvfb with **software** OpenGL, so absolute times are far above a real GPU and only the comparison means anything. There was one run each:

- **before**: the I018 build `2f1ed06` (0.105a), in a separate worktree;
- **after**: the 0.105b tree, which is `2803394` plus the version bump and a one-line text change, with no other code changes.

Mean frame time and p95, in ms:

| Scene | I018 (before) | 0.105b (after) |
|---|---|---|
| Cabin, night | 108.0 / 126.5 | 98.2 / 115.0 |
| Deck moored, night | 149.6 / 168.5 | 150.2 / 170.7 |
| Rod with a fish on | 154.0 / 178.0 | 157.1 / 183.8 |
| Deck underway, night | 65.0 / 79.1 | 72.7 / 82.4 |
| Deck at anchor, night | 59.0 / 69.7 | 61.8 / 71.4 |
| Chart with wind | 65.1 / 78.2 | 69.3 / 87.7 |
| Chart with the **anchorage overlay** (new) | — | 39.1 / 48.6 |

How to read these:

- **Within the run-to-run spread, apart from one scene.** I018's own two runs per build differed by up to 6 %. The cabin is faster here and the moored deck equal.
- **Deck underway is 12 % slower** (65.0 → 72.7 ms). Nothing in the underway deck changed except the solar panels, which are a few dozen procedural draw calls drawn once, not every frame. This is **reported as measured and not investigated further**: a single run per build cannot separate it from noise. A second pair of runs is the next step if it matters.
- **Wind navigator:** the first sweep took 7.7 s before and 8.4 s after; the second sweep is cached in both.
- **Anchorage overlay:** 6 tiles filled in 445 frames (19.9 s wall time on this software renderer). Its own work was at most 5.0 ms in any frame, and the chart stayed at about 39 ms per frame while filling.
- **Files:** `docs/benchmarks/revision0105b_{before,after}_rendered.json`.

**The I018 "0.104a" benchmark files: diagnosis.** It is a **stale metadata string caused by run order**, not a harness defect and not a baseline inconsistency.

- The I018 harness wrote `application/config/version` at run time.
- I018's "after" runs (log: 10:26 and 10:33 UTC) were made on the Checkpoint H tree, committed at 10:40 as `c10cb8d`.
- The version was raised to 0.105a only at 11:01, in `f8d68ed`.

So the files truthfully say which version string that tree carried. Their measurements are of the I018 Checkpoint H code: all I018 features except Checkpoint I's tests, documents and version bump. They are **left as they were**.

The 0.105b harness now records, in every result file:

- `version`;
- `commit` (read from `.git`; in a git worktree it is passed by the runner and marked `commit_source: runner`, as for the "before" file here);
- `label` (before / after);
- `measured_at`.

## 21. Automated regression results

**Final full regression** (headless, every suite including the worldwide all-pairs routing test, on `aa8fe0b`): **4374 checks passed, 0 failed**, 63 suites, 1165 s. I018's own final run was 4184 checks; the 190 new checks come from five new suites:

| Suite | Checks | Covers |
|---|---|---|
| coastal_depth | 35 | Raster, reach, depth determinism and smoothness, tiers, shelter vs depth, the rule, six acceptance areas |
| anchorage_overlay | 20 | Zoom gating, visible-only and cached tiles, frame budget, Date Line, colours vs waypoint rule, tooltips, waypoint placement |
| magic_anchor | 61 | Shared timing check, fitting, deployment success, miss, fail, retry, cancel, depth not falsified, bounded bonus, offshore no-shelter, engine stop and refusal, old engine-on save, save/load, drag, one alarm |
| solar_panels | 39 | Four boats, counts and sizes, aft of walkable deck, clear of stations and pet spots, no collision, two headings, moored, preview, at anchor, no power or save data |
| sprite_workshop | 35 | Manifests, resolver, cache, every READY entry, three examples through the full sequence |

Adjusted existing checks (each for a real reason, none weakened to pass):

- `test_galley_and_anchor`:
  - the model-limits text now says GAME ESTIMATES;
  - the "on land" fixture moved inland, because Copenhagen + 0.3° E is Øresund water on the finer coast;
  - the drag check now accepts "scrapes at a lee-shore edge" because dragging may no longer move onto land.
- `test_anchorage`: the offshore fixture is refused for depth.
- `test_branding` and `test_diagnostics`: 0.105b.

Separate harnesses, all passing:
- `restart_105b` (§23);
- `screenshots_105b` (11 checks);
- `benchmark_105b` (§20).

## 22. Rendered evidence

All are in `docs/screenshots/revision_0_105b/`. Each was inspected visually, and every one is produced by a test that also checks the behaviour.

| § 33 item | Screenshot |
|---|---|
| 1 Global chart, far zoom, no overlay | rb_01 |
| 2 Coastal chart with normal regions | rb_02 |
| 3 Deep coastal Magic zone | rb_03 |
| 4 Invalid land area | rb_04 |
| 5 Depth tooltip with source | rb_05 |
| 6 Game-estimated depth tooltip | rb_06 |
| 7 Anchorage waypoint in a valid region | rb_07 |
| 8 Invalid placement with reason | rb_08 |
| 9 International ordinary anchorage (Antigua) | rb_22 |
| 10 International Magic Anchor anchorage (Madeira, about 30 m, 0.7 nm from land) | rb_23 |
| 11 Offshore emergency deployment | rb_12 |
| 12 Magic Anchor timing dial | rb_10 |
| 13 Perfect deployment ("Perfect! 1 more to go") | rb_10 |
| 14 Failed deployment | rb_11 |
| 15 Successful special holding | rb_12, rb_23 |
| 16 Boat anchored at night | rb_24 |
| 17–18 Small prop original / replacement | rb_16 / rb_17 |
| 19–20 Pet original / replacement | rb_18 / rb_19 |
| 21–22 Composed original / replacement | rb_20 / rb_21 |
| 23 Missing replacement fallback | rb_25 |
| 24 Incorrect replacement validation message | rb_26 (the Output-panel text, shown on an overlay by the harness) |
| Solar panels, four boats, two headings, moored and anchored | rb_13 (×6), rb_14, rb_15 |
| Magic Anchor fitting at the boatyard | rb_09 |

Notes:

- The replacement fixtures are deliberately loud pink-and-yellow checks, so a screenshot shows unambiguously that the replacement is in use.
- The coachroof fixture fills its whole layer canvas, which shows the canvas extent.
- The international screenshots are deck views with the windlass panel open. The deck view shows no coastline; the chart screenshots show the coasts.

## 23. Two-process restart results

`tests/restart_105b.tscn` runs every phase as its own Godot process: write, read, art_install, `--import`, art_read, art_after. **All passed:**

| Scenario | What it showed |
|---|---|
| **A, international normal anchor (Antigua)** | 4 set-up checks and 5 read checks. Same position, time and anchor (kind, depth, source); engine stays off; no prompt; an hour at anchor identical to the first process; anchor up without the engine starting. |
| **B, Magic Anchor offshore (west of the Canaries)** | 4 set-up checks and 4 read checks. Ownership kept; same anchor with depth and bonus; engine off and no prompt; a 50 kn blow drags it exactly as in the first process. |
| **C, artwork** | A replacement PNG for Snøvs, imported by `godot --import`, is used by a fresh process as an imported resource with no warnings. It is removed with its `.import` file, and the next fresh process is back to the original, with nothing left installed. Saves contain no texture paths (artwork is resolved by id, independent of saves). |

The log lines are in `docs/revisions/v0.105b/evidence/revision_0_105b_restart_log.txt` (and the full-regression and screenshot summaries next to it), reproducible with the commands in the harness header.

## 24. Shipyard Efficiency: where the time went

**Measured from the session's run log.** Every Godot run started through the timing wrapper is logged with its wall time:

| Checkpoint | Godot runs | Wall time | Runs that failed or were aborted |
|---|---|---|---|
| A/B: raster, depth, rule | 25 | 376 s | 6 (test failures while tuning) |
| C: overlay | 11 | 434 s | 7 (frame-budget iterations) |
| D: Magic Anchor, solar panels | 23 | 430 s | 6 |
| E/F: Sprite Workshop, restarts | 8 | 91 s | 0 |
| G/H: evidence, benchmarks, final regression | 5 | 1651 s | 0 |
| **Total** | **72** | **2983 s (49.7 min)** | 19 (17 failed, 2 aborted on parse errors) |

Plus one non-Godot step: the coastal raster build in Python (49 s).

**Expensive steps:**
- The final full regression: 1165 s, 39 % of the total.
- The two rendered benchmarks: 200 s and 238 s.
- The overlay's rendered frame-budget iterations: 7 runs, about 340 s.

**Cheap and decisive steps:**
- Focused suites during implementation (`--only=`): typically 9–30 s.
- The 11-suite targeted regression after Checkpoint D: 280 s in all.
- The headless "every READY entry" check: 124 entries in one 30 s run.

**Not in the log (honestly reported):**
- About 12 `--import` passes (a few seconds each).
- Godot runs in two baseline worktrees: the I018 `--only=art` comparison and its import.
- **One wasted benchmark attempt.** The first "before" run hit a parse error in the new harness (a non-static call on `GameVersion`). The process waited until its timeout before being stopped by hand: roughly 10–15 minutes of wall time with no useful output.

  Lesson: parse-check a new harness with a short headless run before launching a long rendered one. The wrapper's early abort only applies to runs started through it, and this one was started directly.

**Efficiency choices that worked:**
- **Seeded fixtures.** Art fixtures are made in code, not stored. The depth noise and the Magic Anchor dial are deterministic.
- **Before/after benchmarks once each, in a baseline worktree.** Two runs per build, as in I018, would have added about 7 minutes.
- **The full routing regression only at the end.**
- **Delegating the art audit** of 25 drawing scripts to a read-only explorer, which kept the main thread on implementation.

## 25. Known limitations

1. **No real bathymetry.** Every depth is a deterministic GAME ESTIMATE: plausible, not real. Real data can be added through tier B (`build_depth.py`) when a source is reachable.
2. The fine coast comes from OSM polygons at about 100 m accuracy. Harbour basins and very narrow channels may differ from reality, so the Danish regional chart stays authoritative where it is finer.
3. The overlay takes some seconds to fill a new coastal area under software rendering (measured about 20 s for 6 tiles here). It is never more than about 5 ms of work per frame.
4. The game has no manual engine control, so "Let's raise the anchor before starting the engine." is the answer of `engine_start_refusal()`, used by any engine request. There is no button that shows it today.
5. Magic Anchor balance (arcs, checks, miss time, bonus) is a first proposal for the Captain's feel test. It reuses the chain sound; no new sound was added.
6. Sprite Workshop: 42 entries need adapters (most importantly the walking Captain and the sails). New art needs a game restart. Exported builds are not covered.
7. Deck-underway frame time measured 12 % slower in one run per build (§20). The cause was not investigated.
8. Test-order interaction: running only the `art`-matching suites (`--only=art`) fails the chart's wind-toggle click (2 checks). This reproduces identically on the unchanged I018 build `2f1ed06`, so it is pre-existing, not caused by this revision. It passes in the full run order and on its own.
9. The anchorage type of a waypoint is recomputed from its position rather than stored. If a future version changes the depth model, a saved Magic anchorage could become a normal one (or the reverse).

## 26. Windows acceptance

**Pending.** Nothing here was run on Windows. The checklist is `WINDOWS_ACCEPTANCE_0_105B.md` (26 sections). The I018 checklist (`docs/iterations/i018/WINDOWS_ACCEPTANCE_18.md`) is also still open.

## 27. Git push verification

- Branch: `claude/friendly-fermat-dey23f` on `crosenlund79/LittleCaptainsHat`.
- Every checkpoint was pushed as it landed: `a52f8aa`, `bd16387`, `6313113`, `574aae5`, `2803394` and `aa8fe0b`. There was no force-push, reset or history rewrite, and no Captain-owned art was modified.
- Final delivery commit: the commit that adds this completed report; its hash is recorded in the follow-up line below and in the delivery message. Verified by comparing the local HEAD with `git ls-remote origin claude/friendly-fermat-dey23f` after the push.
- Recorded after the push: Checkpoint H is `3ce8b38`, and `git ls-remote` showed the remote branch at `3ce8b38`, equal to the local HEAD. This line is added by the follow-up commit that records it.
