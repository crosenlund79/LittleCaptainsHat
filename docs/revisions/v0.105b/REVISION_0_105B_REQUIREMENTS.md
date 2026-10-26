# Revision 0.105b — Requirement tracker

The source of truth is `REVISION_0_105B_ASSIGNMENT.md`; section numbers are in brackets.

Statuses:
- **DONE**: implemented *and* verified by the named tests or evidence.
- **PARTIAL**: part done; the limitation is stated.
- **TODO**: not done.

Windows acceptance is **PENDING** for every row until the Captain's own trial. It is never filled in by the developer.

Screenshots are in `docs/screenshots/revision_0_105b/`. Suites are in `tests/suites/`. Harnesses are in `tests/`.

## GEO — Geography and root cause [§3, §6]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| GEO-1 | Root cause of the international restriction found from the code and documented | DONE | Report §4 | Code reading: shore distance on 5 nm cells could never be below 2.5 nm; "near land" stood in for depth | — | — | PENDING |
| GEO-2 | Finer coastal land/water than the routing grid, near the candidate point | DONE | `src/navigation/coastal_geography.gd`, `data/navigation/coast/` (1/120°, OSM), `tools/navigation/build_coast.py` | test_coastal_depth `[raster]` (35 checks) | rb_02, rb_04 | OSM polygons at about 100 m accuracy; Danish regional chart authoritative where finer | PENDING |
| GEO-3 | Never on land; safe margin from the shore | DONE | `AnchorSite.MIN_SHORE_NM` 0.2 nm; drag never moves onto land (`SeaRouter.is_afloat`) | test_coastal_depth `[rule]`; test_anchorage_overlay `[waypoint]`; test_magic_anchor (drag stays afloat); test_galley_and_anchor `[drag]` | rb_04, rb_08 | — | PENDING |
| GEO-4 | Reachable: conservative connection from the route to the anchorage; no invented passages | DONE | `CoastalGeography.approach()` (BFS over clear cells, up to `approach_max_nm`); `SeaRouter` coastal link (line clear) | test_coastal_depth `[reach]` (synthetic 1-cell gap refused, 3-cell allowed; Antigua; Falmouth route) | rb_07 | Approach limited to about 11 nm on the world grid | PENDING |
| GEO-5 | Navigable water, coast proximity, depth and shelter kept distinct | DONE | `AnchorSite.evaluate` keys `water`, `reachable`, `land_nm`, `depth_m`, `shelter` | test_coastal_depth `[shelter]`, `[rule]` | rb_05 | — | PENDING |

## DEPTH — Bathymetry and game estimates [§4, §5]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| DEPTH-1 | Real sources investigated and recorded (name, edition, licence, access) | DONE | Report §5 | GEBCO, EMODnet, NOAA ETOPO and Natural Earth all refused (HTTP 403); npm/PyPI searched | — | **No real bathymetry acquired** | PENDING |
| DEPTH-2 | One authoritative depth service with tiers and provenance | DONE | `DepthService` (regional / global / estimate), `DepthData` reader, `tools/navigation/build_depth.py` | test_coastal_depth `[data]` (synthetic data file read, labelled, coarse near-shore falls back) | — | Tiers A and B have no data installed | PENDING |
| DEPTH-3 | Deterministic game estimate: smooth, varied, same after restart | DONE | `DepthService.estimate` (fixed-seed value noise, shelf seas) | test_coastal_depth `[depth]`; restart_105b A (same depth after restart) | — | Plausible, not real | PENDING |
| DEPTH-4 | Estimates labelled GAME ESTIMATE; no fake surveyed precision | DONE | `describe_depth` ("about 9 m", 5 m and 50 m steps); labels in the windlass, chart and legend | test_anchorage_overlay `[tooltip]`; test_magic_anchor (panel text) | rb_05, rb_06, rb_23 | — | PENDING |
| DEPTH-5 | Bounded data, no full-resolution global grid in memory, offline | DONE | coast.bin 1.17 MB, tiles decoded on demand (512-tile cache) | test_coastal_depth; benchmark | — | — | PENDING |

## SHELTER — Coastal exposure [§7]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| SHELTER-1 | Shelter from wind and nearby land, independent of depth | DONE | `AnchorSite.shelter_at` / fine `fetch_nm` | test_coastal_depth `[shelter]` (same depth, different shelter) | — | Fetch only; no swell refraction | PENDING |
| SHELTER-2 | Exposed in a storm even if fine in fair weather; advisory wording | DONE | Shelter judged at arrival; offshore Magic says "no shelter" | test_magic_anchor (50 kn drag); test_galley_and_anchor `[drag]` | rb_12 | — | PENDING |

## ZONE — Anchorage overlay [§8, §30]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ZONE-1 | Optional toggle on the working chart; only at close zoom | DONE | `AnchorageLayer`, "Anchorages" switch, `SHOW_PX_PER_DEG` | test_anchorage_overlay `[zone]` | rb_01, rb_02 | — | PENDING |
| ZONE-2 | Visible area only, cached tiles, bounded eviction, frame budget | DONE | Tile jobs in stages, `MAX_TILES` 48, `FRAME_BUDGET_USEC` 3 ms | test_anchorage_overlay (p95 3.2 ms of work per busy frame, max 5.0 ms; tiles reused after panning) | — | Fill takes some seconds under software rendering | PENDING |
| ZONE-3 | Normal (teal) vs Magic (amber) distinguished, with legend | DONE | `map_view`, `world_map` legend | test_anchorage_overlay; agrees with the waypoint rule 375/375 | rb_02, rb_03 | — | PENDING |
| ZONE-4 | Friendly inspection text with depth and its source | DONE | `WorldMap.inspect_anchorage` | test_anchorage_overlay `[tooltip]` | rb_05, rb_06 | — | PENDING |
| ZONE-5 | Correct after panning and world wrapping | DONE | Wrapped tile keys | test_anchorage_overlay (Date Line) | — | — | PENDING |

## WAYPOINT — Anchorage route integration [§9]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| WAYPOINT-1 | Mark only inside eligible regions; reason and nearby suggestion otherwise | DONE | `GameSession.anchorage_spot`, `nearest_anchorage_spot` | test_anchorage `[mark]`; test_anchorage_overlay `[waypoint]` | rb_07, rb_08 | — | PENDING |
| WAYPOINT-2 | Normal vs Magic requirement shown and saved | DONE | Amber ring and "(Magic Anchor)" label; the type is recomputed from the saved position (depth is deterministic) | test_anchorage_overlay | rb_03 | The type is not stored per waypoint (no save field needed) | PENDING |
| WAYPOINT-3 | Zoom does not remove or alter planned anchorages | DONE | Waypoints independent of the overlay | test_anchorage_overlay | — | — | PENDING |
| WAYPOINT-4 | Arrive, stop, prompt, anchor, resume (I018 flow) worldwide | DONE | Unchanged I018 flow; `[abroad]` check off New Zealand | test_anchorage (74 with overlay) | rb_22 | — | PENDING |

## NANCH — Normal anchoring worldwide [§10, §15]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| NANCH-1 | Normal anchor works on suitable international coasts | DONE | `AnchorSite.evaluate` | test_coastal_depth `[areas]`; restart_105b A (Antigua) | rb_22 | — | PENDING |
| NANCH-2 | Existing scope, holding, drag, visuals, persistence reused | DONE | Holding model unchanged; `AnchorState` optional fields | test_galley_and_anchor (91); test_anchor_life (44) | rb_15, rb_24 | — | PENDING |
| NANCH-3 | Acceptance areas: Denmark, Iberia/Med, Canaries/Madeira, Caribbean, Polynesia, New Zealand | DONE | — | test_coastal_depth `[areas]`: Nyborg, A Coruña, Las Palmas, Falmouth (Antigua), Papeete, Whangārei | — | Depths are estimates | PENDING |

## MAGIC — Magic Anchor [§11, §13, §14, §14A]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| MAGIC-1 | Fictional equipment with flavour text; documented prototype route; all boats | DONE | Boat care row "Fit it (free prototype)"; progress mark | test_magic_anchor `[magic]` (fitting, free, kept across boats) | rb_09 | Price deferred to I020 | PENDING |
| MAGIC-2 | Deep or uncertain depth eligible; land and unreachable water still refused | DONE | `magic_ok` after the water and reach checks | test_coastal_depth `[rule]`; test_magic_anchor | rb_03, rb_23 | — | PENDING |
| MAGIC-3 | Offshore emergency deployment in open water, documented limits | DONE | Offshore beyond 3 nm; wind up to 55 kn; holds position only | test_magic_anchor; restart_105b B | rb_12 | — | PENDING |
| MAGIC-4 | Existing holding/drag model; real depth stored separately from the effective holding | DONE | `AnchorState.depth_m`, `depth_source` kept; the holding model has no depth term | test_magic_anchor ("not falsified") | — | — | PENDING |
| MAGIC-5 | No shelter or weather immunity; offshore says so | DONE | Toast and windlass text | test_magic_anchor (50 kn drag; "no shelter") | rb_12 | — | PENDING |
| MAGIC-6 | Modest distinct presentation (chart icon, brass flourish) | DONE | Amber chart ring; brass glow on the dial; brass gear and short line on deck | test_magic_anchor | rb_10, rb_12, rb_23 | No new sound; the chain sound is reused | PENDING |
| MAGIC-7 | State transitions and one authoritative anchored state | DONE | One `AnchorState`; cancel, fail, success, drag, raise, save/load, boat change | test_magic_anchor (61); restart_105b B | rb_11 | — | PENDING |
| MAGIC-8 | Engine stops when anchoring succeeds; cannot restart while anchored; friendly message; old saves normalised | DONE | `_let_go`, `is_motoring`, `engine_start_refusal`, `_recover_location` | test_magic_anchor `[engine]`; restart_105b A | — | The game has no manual engine switch (the crew runs it), so the message is an API answer rather than a button | PENDING |
| MAGIC-9 | Decorative solar panels on all four boats; no power simulation; attached through turns; not obstructing | DONE | `SolarPanels`, `VesselVisual.solar_panels` | test_solar_panels (39) | rb_13 (×6), rb_14, rb_15 | — | PENDING |

## SKILL — Special deployment challenge [§12]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| SKILL-1 | Reusable constant-speed timing component shared with fishing, no catch state | DONE | `TimingCheck` (`ReelTiming` extends it) | test_magic_anchor `[skill]`; test_fishing2 (88) unchanged | rb_10 | — | PENDING |
| SKILL-2 | 1 / 2 / 3 successes by conditions; Perfect gives a bounded holding bonus | DONE | Under 17 / 17–27 / 28+ kn; arcs 70° / 58° / 48°; at most +3 kn | test_magic_anchor | rb_10 | Balance needs the Captain's feel test | PENDING |
| SKILL-3 | Miss costs time, retry, cancel; no random failure; player informed | DONE | 5 min per miss, 3 misses allowed, Try again, Cancel | test_magic_anchor | rb_11 | — | PENDING |

## SAVE — Persistence [§29, §34]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| SAVE-1 | Format decision documented; optional fields; 0.105a saves load | DONE | Format 12 kept; optional `kind`, `depth_m`, `depth_source`, `bonus_kn`; ownership as a progress mark | test_anchor_life `[save]`; test_magic_anchor (old engine-on save) | — | — | PENDING |
| SAVE-2 | Two-process restarts: international normal anchor, Magic Anchor, artwork fallback | DONE | `tests/restart_105b.gd` | A 5/5, B 4/4, C 5/5 (report §23) | — | — | PENDING |

## ARTINV — Artwork inventory [§20–§23]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTINV-1 | Audit of real artwork and renderer types | DONE | SPRITE_WORKSHOP_REPORT §1 | — | — | — | PENDING |
| ARTINV-2 | Display and 2× source sizes from how each is shown | DONE | Units × largest zoom × 0.833 | manifests | — | — | PENDING |
| ARTINV-3 | Complexity C1–C4, priorities, first 25, quick wins | DONE | `INDEX.md`, report §5, §8 | build_index | — | Priorities are a judgement, explained | PENDING |
| ARTINV-4 | Three inventory counts with views, classes and workload points | DONE | A 38/50/531, B 52/93/704, C 81/187/885 | build_index | — | — | PENDING |

## ARTMAN — Manifests [§17–§19]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTMAN-1 | Folder hierarchy with manifest.csv and README.md per folder; START_HERE and index | DONE | `art_replacements/` (34 folders) | test_sprite_workshop `[manifest]` | — | — | PENDING |
| ARTMAN-2 | Schema with all required fields; stable unique ids; honest status | DONE | 20 required + 6 extra columns | test_sprite_workshop `[manifest]`, `[ready]` | — | — | PENDING |
| ARTMAN-3 | Duplicates and invalid paths validated | DONE | `build_index.py --check`; `ArtworkResolver` | test_sprite_workshop | — | — | PENDING |

## ARTRES — Resolver [§24, §25]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTRES-1 | get_artwork(id, fallback): index once, cache, fallback, warnings | DONE | `src/art/artwork_resolver.gd` | test_sprite_workshop `[resolver]` (1 load for 51 requests) | rb_26 | — | PENDING |
| ARTRES-2 | Works in the ZIP → editor workflow (imported or not yet imported PNG) | DONE | ResourceLoader or `Image.load_from_file` | restart_105b C (install, `--import`, new process, remove) | — | Restart to see new art; exported builds not covered | PENDING |
| ARTRES-3 | Never alters gameplay geometry, collisions, safe zones or ids | DONE | Pictures only | test_sprite_workshop (walkable cells, pet spot unchanged) | — | — | PENDING |

## ARTTEST — Demonstrated replacements [§26]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTTEST-1 | Small prop replacement, full test sequence | DONE | Anchor buoy | test_sprite_workshop `[example 1]` | rb_16, rb_17, rb_25, rb_26 | — | PENDING |
| ARTTEST-2 | Pet replacement, full test sequence | DONE | Snøvs resting | `[example 2]` | rb_18, rb_19 | — | PENDING |
| ARTTEST-3 | Composed/layered replacement, full test sequence | DONE | AW26 coachroof layer | `[example 3]` | rb_20, rb_21 | — | PENDING |
| ARTTEST-4 | Fixtures kept apart; nothing left installed | DONE | `tests/helpers/art_fixtures.gd` | "nothing left installed" checks | — | — | PENDING |

## PERF — Performance [§30]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| PERF-1 | Overlay bounded and measured | DONE | Frame budget, tile cache | test_anchorage_overlay; benchmark_105b `anchorage_overlay_fill` | — | Software renderer only | PENDING |
| PERF-2 | Resolver: no per-frame scans, cached loads | DONE | — | test_sprite_workshop `[resolver]` | — | — | PENDING |
| PERF-3 | Before/after benchmarks; I018 benchmark version metadata explained and fixed | DONE | `tests/benchmark_105b.gd` records version, commit, label and time | `docs/benchmarks/revision0105b_*` | — | Software rendering, not Windows GPU | PENDING |

## QA — Testing [§32, §33]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| QA-1 | Focused suites for each area | DONE | coastal_depth, anchorage_overlay, magic_anchor, solar_panels, sprite_workshop | report §21 | — | — | PENDING |
| QA-2 | Full regression | DONE | — | report §21 | — | One test-order interaction (pre-existing, reproduced on I018) noted | PENDING |
| QA-3 | Rendered evidence (24 scenes + solar panels) reviewed | DONE | `docs/screenshots/revision_0_105b/` | report §22 | rb_01–rb_26 | — | PENDING |
| QA-4 | No I019–I021 scope | DONE | No collision radar, VHF, shop or economy | — | — | — | PENDING |

## DOC — Delivery [§35, §36, §39, §40, §42]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| DOC-1 | REVISION_0_105B_REPORT.md (27 items, Shipyard Efficiency) | DONE | — | — | — | — | |
| DOC-2 | WINDOWS_ACCEPTANCE_0_105B.md | DONE | 26 sections | — | — | — | |
| DOC-3 | docs/artwork/SPRITE_WORKSHOP_REPORT.md and art_replacements/README_START_HERE.md | DONE | — | — | — | — | |
| DOC-4 | CAPTAINS_ORDERS.md: 31 decisions; attribution docs; scripts | DONE | Orders, README credits, `coast.json`, build scripts | — | — | — | |
| DOC-5 | Version 0.105b; push verified | DONE | `GameVersion`, `project.godot` | test_branding, test_diagnostics | — | — | |
