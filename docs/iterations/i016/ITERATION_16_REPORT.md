# Iteration 16: The World Awaits

Global chart, international cruising and long-distance passages. Version
**0.103a**, save format **12** (unchanged).

## 1. Repository verification

- Remote `origin`: `https://github.com/crosenlund79/LittleCaptainsHat` (fetch and
  push), the only authorized repository. No other repository was touched.
- Branch: `claude/friendly-fermat-dey23f`.
- The baseline was revision 0.102b ("Life at Anchor", commit `6613fa2`).
  **Iteration 15 had not been delivered**: there was no Iteration 15 report,
  version or commit in the repository. The Captain was asked and chose
  **"Authorize 16 now"**: Iteration 16 starts on the 0.102b baseline,
  performance is measured first, and this report records that Iteration 15
  was skipped. Iteration 15 is not renumbered or reused.
- Captain-owned artwork was not modified. No force-push, reset or history
  rewrite was used; every checkpoint is a normal commit.

## 2. Starting and final commits

| | Commit |
|---|---|
| Starting point (0.102b) | `6613fa2` |
| Checkpoint A: benchmark harness, baseline measurements | `f5fa557` |
| Checkpoint B: worldwide chart, Date Line wrapping, global wind and weather | `62c00e6` |
| Checkpoint C: worldwide hierarchical routing | `0402f3b` |
| Checkpoint D: international harbours | `8bee5f0` |
| Checkpoint E: Long Passage, passage stores, ocean readiness | `50a3285` |
| Checkpoint F: log firsts, diagnostics, 0.103a, Copenhagen-to-Paradise test | `3fdc2d5` |
| Checkpoint G: performance, Date Line save fixes, Long Passage tests | `185ff03` |
| Checkpoint H: screenshots, documentation, delivery (final) | see section 23 |

## 3. Final version

**0.103a** (`GameVersion.DISPLAY`; `MACHINE` 0.103.1; `project.godot`
`application/config/version`). The next feature milestone after 0.102b.

## 4. Save format

**Format 12, unchanged.** Nothing new is saved:

- passage stores are the same two numbers (food and water days); only their
  validation limit was raised (`Provisions.MAX_STORE_DAYS` = 60);
- Long Passage time is not saved (loading always returns to normal time);
- the Captain's Log firsts use the existing objective records;
- route paths were already geographic points; validation now accepts
  longitudes to ±540° in paths (continuous paths across the Date Line),
  ±180° for waypoints.

Older saves (format 12 from 0.102a/0.102b, and older formats through the
existing migrations) load unchanged. See section 15.

## 5. Geographic data sources and licences

| Data | Source | Version / date | Licence | Notes |
|---|---|---|---|---|
| World land (raster, graph, drawn land) | OpenStreetMap land polygons via geo-maps *earth-lands-100m* (npm `@geo-maps/earth-lands-100m`), file `package/map.geo.json` | 0.6.0; package SHA-1 `bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41`; retrieved 2026-10-25 | Map data © OpenStreetMap contributors, **ODbL 1.0**; the derived world raster, graph and land are ODbL too; package code MIT | the same source as the Danish region (Iteration 14) |
| International harbour positions | UN/LOCODE code list (UNECE), CSV packaged by datasets/un-locode (`data/code-list.csv`) | retrieved 2026-10-25; file SHA-1 `e8fd5de2af057d193bcb97cd2039c684ab097f2e` | UNECE's freely published code list | positions to the arc-minute, used **unchanged**; each harbour's `source` column records its code and coordinates |
| Europe (unchanged) | Natural Earth 1:10m land | as in Iteration 006 | public domain | |
| Denmark (unchanged) | OpenStreetMap via the same package | as in Iteration 14 | ODbL 1.0 | |
| Ocean, continent and island-group label positions | hand-placed label anchors (`tools/navigation/world_labels.json`) | Iteration 16 | project | label positions only, no geometry |

- **Coordinate reference system**: WGS 84 longitude/latitude (EPSG:4326);
  the navigation rasters use Mercator rows. One coordinate system for the
  world, Europe and Denmark.
- **Scripts**: `tools/navigation/build_world.py` (raster, graph, seams, drawn
  land), `tools/navigation/world_land_to_res.gd` (binary `land.res`),
  `tools/navigation/add_world_harbours.py` (harbours from UN/LOCODE),
  `tools/navigation/build_harbours.py` (port resources).
- **Processing and simplification**: 4 × 4 subsamples per cell; a cell is land
  if any subsample is land, approach-only if land covers at most half of it;
  holes (lakes) filled; latitudes 72° S–80° N. Drawn land simplified 0.08°
  (overview, below 9 px per degree) and 0.02° (regional), adaptive for small
  islands with a floor; tiny islands drawn as islet dots. Slivers removed.
- **Limitations**: the world raster has 5 nm cells (12 per Mercator degree).
  Channels, lagoons and harbour entrances narrower than about a cell are not
  charted; atolls and small islands may be approach-only cells. **No depth
  data** of any kind; no reefs, shoals, currents, ice or shipping lanes. The
  **Panama Canal** is a gameplay abstraction (a straight two-cell channel
  between the UN/LOCODE positions of Colón and Panama City), not its geometry.
  Not for navigation.
- **No runtime tile servers**: everything is built ahead of time and shipped
  in `data/navigation/world/`. `land.json` (12 MB, the build's text output)
  is not kept in the repository; `land.res` (4.5 MB, binary) is.

## 6. Global chart architecture

- **Three nested charts, one coordinate system** (`NavGrid.load_world`): the
  world raster (4,320 × 2,943 cells, columns wrapping) holds Europe as a
  region (one world cell = 5 × 5 European cells), which holds Denmark (one
  European cell = 6 × 6 Danish cells). Europe's and Denmark's files are
  unchanged. `grid_at` returns the finest chart for a position.
- **Levels of detail on the chart** (`MapView`):
  - world scale (below 9 px per degree): the world overview land in 10° tiles;
    ocean, continent and island-group names; only the larger harbours, with
    markers that would overlap a more important one left out;
  - regional scale (from 9 px per degree): Europe's own chart plus the
    regional world land (built on first use), island dots, Europe's names
    from 16 px per degree;
  - coastal scale: Denmark's detailed coast from its own zoom, as before.
- **Drawing cost bounded**: each world tile is one indexed triangle array and
  one line batch, shown only when in view; land, Europe and region shapes are
  prepared once and kept in static caches across chart openings; weather
  shapes are culled to the view; islet dots redraw only on visible zoom
  changes. No geometry grows with play time.
- **No debug geometry** in normal play; the graticule, harbours, routes,
  weather and wind are the only overlays.

## 7. Coordinate and Date Line handling

- Positions are stored with longitudes in −180..180. `GeoMath.normalize`,
  `wrap_delta` (the short way round), `same_position` and `unwrap_path` are
  the helpers; every distance, bearing and rhumb interpolation uses
  `wrap_delta`, so a segment from 179° E to 179° W is 2° long, never 358°.
- `Voyage.position_at` returns normalized positions (Iteration 16 fix: a boat
  just past the Date Line was stored at 180.007° and the save did not load
  until the load check became wrap-aware; both fixed and tested).
- The raster wraps: line checks across the Date Line continue on the other
  side. The router plans on a sphere (A* on 3-D unit vectors), so there is no
  seam and no antipode problem (an earlier Europe-centred projection broke
  in the South Pacific and was replaced).
- The chart wraps east–west: the camera stays in the main copy; land within
  40° of ±180° is drawn again one world-width away; harbours, labels, courses,
  weather and wind use the copy nearest the view, so the Pacific is continuous.
- **Polar limit**: the world chart covers 72° S to 80° N (documented in
  `world.json`); beyond it the raster is land, so routes cannot go there.

## 8. Routing design

- **Hierarchical graph** (`SeaRouter.load_world`, `_merge`): a world lattice
  (96/48/24/12-cell spacing, finer near the coast) plus channel centre lines,
  built against the world raster (and the European raster inside Europe);
  Europe's graph and Denmark's replace the world nodes inside them, joined by
  seam edges. 53,641 nodes in all.
- **Validation**: every graph edge is checked at build time and by the test
  suite with the same line check the game uses (229,870 edges, 0 failing).
  Every planned route is validated before it can be used.
- **Harbour approaches** scale with the chart: 10 nm in Europe, six world
  cells (30 nm) abroad (`approach_radius_nm`); berths 2 nm or 1.5 cells.
- **Failure**: no route → a clear message (`plan_route` error), never a straight
  line over land. A waypoint on land is refused with its number.
- **Responsiveness** (headless, cold): Copenhagen → Papeete (10,258 nm) 60 ms,
  Copenhagen → Las Palmas 51 ms, Las Palmas → Castries 4 ms, Papeete →
  Auckland 6 ms; the world router loads in about 0.7 s.

## 9. Regional integration

- Denmark stays the detailed foundation: its raster, graph, drawing, labels
  and harbours are unchanged and nested exactly as before (now inside Europe
  inside the world). Danish routes and distances are unchanged (Copenhagen →
  Kiel 152 nm, → Svendborg 145 nm, → Lisbon 1,620 nm).
- The world's own land is clipped out inside Europe, and Europe's inside
  Denmark, so each area is drawn once at its best detail.
- Region transitions (Denmark ↔ Europe ↔ world) are logged underway.
- Adding regions (Sweden, New Zealand, French Polynesia, …) is documented in
  `DEV_GUIDES/CHART_REGIONS.md` §6 and in section 21; none is built now.

## 10. Harbour additions

36 international harbours, at their UN/LOCODE positions (unchanged), each
with a stable id, name, country, region, importance, description and source,
and a facility tier (small: grocery and Go Ashore; larger: + boatyard; major:
+ haul-out). Every one has a grocery store.

| Region | Harbours |
|---|---|
| `atlantic_islands` | Funchal, Ponta Delgada, Horta, Las Palmas (major), Arrecife, Mindelo, St. George's (Bermuda) |
| `caribbean` | Castries, Le Marin (major), Fort-de-France, Port Elizabeth (Bequia), Falmouth Harbour, Port of Spain, Willemstad, San Juan, Nassau |
| `central_america` | Colón, Panama City (major) |
| `pacific` | Puerto Ayora, Taiohae, Atuona, Fakarava, Papeete (major), Uturoa, Bora Bora, Avarua, Pago Pago, Nuku'alofa, Suva, Lautoka, Nouméa, Whangarei, Auckland (major), Wellington, Nelson, Honolulu (major) |

223 harbours in all (187 before). Opua (New Zealand) was left out: its
UN/LOCODE position lies deeper in the Bay of Islands than the approach limit
of the coarse chart. Every harbour has an approach (tested); every
international harbour is reachable from Copenhagen (tested).
Regional Go Ashore flavour: one gentle moment each for the Atlantic islands,
the Caribbean, Panama and the Pacific, generic colour only. Four warm-water
fish (mahi-mahi, skipjack, red snapper, yellowfin) for the new regions.

## 11. International passage mechanics

- **No teleporting**: every mile is sailed by the existing simulation
  (`Simulation.advance`): wind, propulsion, weather, wear, stores, fishing,
  the hat and the companions all run as at home.
- **Long Passage time** (`Simulation.start_passage`): 1, 4 or 12 game hours
  per real second, the same timeline in chunks of one frame each that stop
  at the first event, as sleeping does; so the voyage is identical to normal
  time (tested: Copenhagen → Gothenburg arrives at the same minute with the
  same miles, weather and condition at 12 h/s and in 20-minute steps). It
  stops by itself and returns to normal time for: arrival, a weather warning,
  a bite, the hat in strong wind, low stores, a boat-care notice, rescue, the
  anchor. Pausing holds it; Chart and Save stop it first.
- **The panel** (`PassagePanel`, on deck underway on voyages of 60 nm or
  more): destination, position and day at sea, distance and ETA with a
  progress bar, speed and wind, the outlook (hazards in the forecast, and
  "further on, not yet known"), stores against the days left, the hull and
  any care notes, the speeds, Chart and Save. There is no fuel system, so no
  fuel line (documented).

## 12. Passage Readiness integration

Still advisory; it never blocks a departure (tested). New for ocean passages:

- beyond the 24-hour forecast it says the weather further along is **not yet
  known** instead of promising fair weather;
- stores are weighed against what the boat can stow: it suggests stocking up
  when that would be enough, and suggests breaking up a passage longer than
  the boat can stow food and water for;
- passages over a week are named ocean passages, with a pointer to Long
  Passage time; the small-boat note remains a friendly note.

## 13. Weather and provisions behaviour

- **Wind** is valid everywhere: Europe's anchors are unchanged inside their
  lattice; elsewhere a synthetic northern-summer climatology from latitude
  belts (polar easterlies, westerlies, horse latitudes, trades, doldrums) and
  16 regional anchors (Canary and Caribbean trades, Pacific trades, New
  Zealand westerlies, monsoons…), blended in over 4° outside Europe, on a
  2.5° lattice that wraps. The weather waves cross-fade over the last 30°
  before the Date Line, so there is no seam. Deterministic: a pure function of
  position, time and seed.
- **Weather events**: 7 ocean gale zones (westerlies of both hemispheres,
  Southern-hemisphere seasons reversed) and 7 convective zones (Caribbean,
  doldrums, eastern Pacific, warm pool, South Pacific convergence, Bay of
  Bengal); cyclone basins were already global. European zones and their
  events are unchanged (same ids, same seeds).
- **Simplifications**: one season's climatology for the wind all year; zones
  are rectangles; no currents, swell or ice. Not real weather, not a forecast.
- **Provisions**: everyday stores stay at 14 days; each boat can stow
  **passage stores** — Arctic Wanderer 26: 32 days, Wing 33: 36, Frogleap 36:
  34, Clam 40: 45 — bought at the grocery store ("Stock up") at the same price
  per day. Cooking can top food up to the boat's passage stores. Running out
  still only warns (and blocks the next departure), as before.

## 14. Captain's Log achievements

Each paid once (`_award_once`), modest renown:

| First | Id | Renown |
|---|---|---|
| Beyond Danish waters (arriving outside the detailed Danish chart) | `world:beyond_denmark` | 3 |
| First international destination (a harbour abroad) | `world:first_international` | 4 |
| First offshore crossing (a voyage of 500 nm or more) | `world:offshore_crossing` | 4 |
| Across the Atlantic (east of 30° W to west of 50° W, or back) | `world:atlantic_crossing` | 6 |
| Into the Pacific (first Pacific harbour) | `world:pacific_arrival` | 5 |
| French Polynesia | `world:french_polynesia` | 5 |
| New Zealand | `world:new_zealand` | 5 |

"Beyond Danish waters" is defined by the detailed Danish chart (which also
covers Kiel and Gothenburg), so the existing Danish objectives and their
renown sums are unchanged. Tested: earned when due, never twice, never early.

## 15. Save migration

No migration was needed (format 12). Compatibility changes:

- path longitudes up to ±540° accepted; waypoints within ±180°;
- the load check of the boat's position against its voyage is wrap-aware;
- stores above 14 days load (up to 60);
- location recovery (Iteration 14) applies as before; its approach check now
  uses the chart's approach radius, so a boat near a harbour abroad is not
  "recovered" needlessly.

Tested: a save in mid-Atlantic and a save just past the Date Line both load
to the same position and progress, with no recovery, no duplicated progress
and no renown gained or lost; the voyages then finish normally.

## 16. Performance before and after

Measured by `tests/benchmark.gd` on this Linux machine (headless = CPU only;
rendered = Xvfb with software OpenGL/llvmpipe, which exaggerates fill cost).
Before = 0.102b (worktree at `6613fa2` with the same benchmark), after =
0.103a. Files in `docs/benchmarks/` (`iteration16_before_*_v2.json`,
`iteration16_after_*.json`; the first baseline of Checkpoint A is kept too).

| Measurement | Before (headless) | After (headless) | Before (rendered) | After (rendered) |
|---|---|---|---|---|
| App startup | 113 ms | 114 ms | 174 ms | 170 ms |
| Navigation load (Europe router) | 449 ms | 459 ms | 472 ms | 469 ms |
| World router load | — | 755 ms | — | 693 ms |
| Chart first open (until shown) | 1,238 ms | 2,278 ms | 1,347 ms | 2,513 ms |
| Chart reopen | 519 ms | 496 ms | 555 ms | 534 ms |
| Chart frame, whole view | 6.9 ms | 6.9 ms | 68 ms | 93 ms |
| Chart frame, Europe | 6.9 ms | 7.0 ms | 66 ms | 79 ms |
| Chart frame, Denmark | 7.2 ms | 9.5 ms | 66 ms | 76 ms |
| Chart frame, panning | 7.0 ms | 12.3 ms | 55 ms | 99 ms |
| Deck frame | 6.9 ms | 7.2 ms | 29 ms | 31 ms |
| Simulation per game day | 486 ms | 487 ms | 456 ms | 450 ms |
| Memory at the end | 135 MB | 201 MB | 125 MB | 191 MB |
| Memory growth, days 2–10 of a session | −8.4 MB | −12.1 MB | 0.8 MB | 1.7 MB |
| Save / load parse / load apply | 1.8 / 1.2 / 3.3 ms | 1.1 / 0.8 / 2.4 ms | 2.3 / 2.0 / 3.4 ms | 1.3 / 0.9 / 2.4 ms |

Reading it honestly:

- **Simulation, saves, startup and reopening the chart** are as fast as
  before or faster. During the work the simulation got 50 % slower (the ocean
  weather zones); per-bucket reach boxes brought it back.
- **First chart open** is about 1 s slower: the world router and the world
  land load once (later openings are not slower).
- **Memory** is about 66 MB higher (the world router and the world land),
  loaded once; a 10-day session shows **no growth** after the first day.
- **Whole-view frames** on software GL are 37 % slower (the whole world's land
  instead of Europe's); headless (CPU) they are equal.
- **Panning** is not a like-for-like comparison: the old chart stopped at
  Europe's east edge after about 11 of the 120 frames, while the world chart
  keeps moving round the globe and computes the wind for each new column. With
  the wind layer off, panning costs 7.1 ms headless, the same as before.
- Fixed regressions found by measuring: a harbour lookup that visited ~15,000
  buckets per frame at world zoom (14 ms → 1.5 ms), weather outlines drawn off
  screen (79,000 → 16,000 canvas items at Denmark zoom), 7,700 draw calls for
  the world land (→ 1,400), per-opening re-triangulation of Europe and
  Denmark (reopen 1.9 s → 0.5 s).

All build assets are deterministic (graph and raster MD5s identical across
rebuilds).

## 17. Automated tests

New suites:

- `tests/suites/test_long_passage.gd` (39 checks): same voyage at any speed,
  interruptions (stores, bite, arrival), pausing, loading resets, passage
  stores, readiness wording, Date Line save and load, the log firsts, the panel.
- `tests/suites/test_world_voyage.gd` (57 checks): the Copenhagen-to-Paradise
  voyage (section 19).

Extended: `test_routing` (world passages: Copenhagen → Britain and Iberia,
Iberia → Canaries and Madeira, Canaries → Caribbean and Cape Verde,
Caribbean → Pacific through Panama, Panama → Galápagos → Marquesas → Tahiti,
French Polynesia → New Zealand, Hawaii → Tahiti, Azores → Bermuda, detailed
Denmark → the world chart; three Date Line routes; land crossings checked
against the drawn world land; every international harbour from Copenhagen;
failures: the Caspian, a waypoint in the Sahara, a straight line across
Central America); `test_regions` (nested charts); `test_harbours` (world
regions and extent, coast check on the finest chart); `test_harbour_life`,
`test_weather` (ocean zones), `test_upkeep_ui` (stock-up), `test_branding`,
`test_diagnostics` (0.103a).

**Final full run** (Linux, Godot 4.7.2, headless, all 44 suites including the
two new ones; about 16 minutes): **3,589 checks passed, 0 failed.** These are
Linux results; they are not a Windows acceptance. Geographic checks
covered: continents and hemispheres (routes in every ocean), oceans
traversable, Denmark detail, the Date Line, the polar limit (beyond it the
raster is land), harbours on coasts. Regression: all existing suites.
Long session: the benchmark's 10-day session and the 97-day voyage.

## 18. Rendered screenshot review

`docs/screenshots/iteration16/` (rendered by `tests/screenshots_16.gd`,
1600 × 900, software GL), each reviewed:

| # | File | Review |
|---|---|---|
| 1 | `01_global_chart.png` | whole world, continents and oceans named, larger harbours only, no overlapping markers |
| 2 | `02_europe_on_world_chart.png` | Europe on the world overview at 8 px/°, readable |
| 3 | `03_denmark_regional.png` | Denmark at regional scale, Danish names, harbours |
| 4 | `04_danish_coast_detail.png` | the detailed Danish coast, unchanged |
| 5 | `05_north_atlantic.png` | the Atlantic islands named (Azores, Madeira, Canaries, Cape Verde), gale area |
| 6 | `06_caribbean.png` | the Antilles, trades from the east |
| 7 | `07_south_pacific.png` | South Pacific, islands as dots, westerlies in the south |
| 8 | `08_french_polynesia_papeete.png` | Papeete selected, Society Islands, Tuamotu |
| 9 | `09_new_zealand_auckland.png` | Auckland selected, a gale over Northland |
| 10 | `10_route_around_a_landmass.png` | Castries → Nassau around the Greater Antilles |
| 11 | `11_dateline_route.png` | Suva → Avarua across the Date Line, no seam |
| 12 | `12_route_europe_to_atlantic.png` | Copenhagen → Las Palmas round Britain and Iberia |
| 13 | `13_long_passage_ui.png` | Long Passage panel at 4 h/s, under spinnaker mid-Atlantic |
| 14 | `14_readiness_long_voyage.png` | Galápagos → Marquesas: "worth a second thought", stock up, forecast limit |
| 15 | `15_underway_ocean_passage.png` | the Arctic Wanderer underway, day 10 at sea |
| 16 | `16_route_with_intermediate_harbour.png` | Las Palmas → Castries by way of Mindelo |
| 17 | `17_arrival_papeete.png` | moored in Papeete, gangplank out, the Pacific and French Polynesia firsts |
| 18 | `18_go_ashore_papeete.png` | Go Ashore in Papeete |
| 19 | `19_zoom_world_to_regional.png` | world → Europe → Denmark in three steps |
| 20 | `20_save_during_long_passage.png` | saving mid-ocean from the panel |

Found and fixed during the review: the EUROPE label on top of markers (moved),
Europe's country names crowding the small-scale chart (now from 16 px/°),
island-group names hard to read over water (now in the sea's text colour),
and three screenshot-script mistakes.

## 19. Copenhagen-to-Paradise test result

Automated, seeded (`tests/suites/test_world_voyage.gd`, wind seed 16, real
generated wind and weather), aboard the **Arctic Wanderer 26**, the smallest
boat, all in Long Passage time at 12 hours a second:

| Leg | Distance | Days at sea | Stores left on arrival |
|---|---|---|---|
| Copenhagen → Las Palmas (through Danish waters, round Britain and Iberia) | 2,285 nm | 18.6 | 13.4 days |
| Las Palmas → Castries (Atlantic crossing; save and reload at 20°49′ N 38°29′ W) | 2,773 nm | 23.1 | 8.9 days |
| Castries → Colón | 1,183 nm | 11.0 | 21.0 days |
| Colón → Panama City (the Panama passage) | 30 nm | 0.3 | 31.6 days |
| Panama City → Puerto Ayora (Galápagos) | 989 nm | 9.3 | 22.6 days |
| Puerto Ayora → Taiohae (Marquesas; Pacific crossing) | 3,090 nm | 28.4 | 3.5 days |
| Taiohae → Papeete (Tahiti) | 770 nm | 6.2 | 25.8 days |

Result: **arrived in Papeete**, no rescue, hull 100 % (97 days of voyage
simulated in 56 seconds; the final full test run reproduced every figure
exactly). On the way: passage
stores bought before each leg; readiness consulted (advice only; honest about
the forecast); the detailed Danish chart, Europe and the world chart all
crossed; Las Palmas as the intermediate harbour: moored, gangplank out on
deck, Go Ashore taken; fishing once a day and the catch cooked (98 fish, 97
meals); a save and reload in mid-Atlantic (same position, same progress, no
renown change); Papeete: moored, gangplank out, Go Ashore taken. Long Passage
time stopped by itself 63 times (51 bites, 5 weather warnings, 7 arrivals).

Honest notes:
- With the first planned stores (24 days) the Galápagos → Marquesas leg ran
  out (28.4 days at sea): the test found it, and the Arctic Wanderer's passage
  stores became 32 days (the other boats 34–45).
- The test drives the game through its own state API (stocking, fishing,
  cooking, Go Ashore choices) rather than walking the captain to each station;
  the gangplank is checked on the real deck scene. Mooring is the game's
  automatic arrival (there is no manual docking).
- In light or deep-downwind trade winds the Arctic Wanderer's propulsion
  controller sometimes chooses the engine (its existing polar and threshold);
  there is no fuel, so this costs nothing — see limitations.

## 20. Known limitations

- The world chart is a coarse ocean chart (5 nm cells): narrow channels,
  lagoons and harbour entrances abroad are not charted; harbours abroad are
  reached through approaches of up to 30 nm; atolls may be approach-only cells.
  The Panama passage is an abstraction. The chart stops at 72° S and 80° N.
- Only Denmark has a detailed region; other regions are future work.
- Harbours abroad use the shared harbour scene (pontoon, signs); no
  harbour-specific scenery. Go Ashore abroad is generic plus one regional
  moment per region.
- The global wind is one season's synthetic climatology all year; weather
  zones are rectangles; no currents or swell. Not real weather.
- No fuel system; motoring is free. The Arctic Wanderer can motor long
  stretches in light trade winds.
- With the line out, Long Passage time stops at every bite (by design, but
  frequent if the line stays out all passage).
- First chart opening is about 1 s slower and memory about 66 MB higher than
  in 0.102b (one-time loads). On software rendering, whole-world frames are
  slower than the old Europe-wide view.
- Island-group and ocean labels are hand-placed anchors.
- Opua is not included (see section 10).
- Not tested on Windows: `WINDOWS_ACCEPTANCE_16.md` is the Captain's trial.
- The precise historic Phase Two wording is still not in the repository; it
  was not invented.

## 21. Future regional expansion instructions

Summary (full steps in `DEV_GUIDES/CHART_REGIONS.md` §4–6 and
`DEV_GUIDES/HARBOURS.md`):

1. Choose the region's rectangle on its parent chart's cells (Europe for
   Sweden; the world for New Zealand or French Polynesia) and a factor (e.g.
   12 for one-mile cells under the world chart).
2. Build its raster, graph and drawn land with `build_region.py` (taught to
   align to world cells for a world-level region), from licensed land data
   whose source and licence are recorded in `region.json`.
3. Add it to its parent's regions list (`regions.json` for Europe; a world
   regions list in `NavGrid.load_world` for world-level regions — the code
   nests charts recursively, but today only Europe is attached to the world).
4. Re-check harbour positions there (`add_world_harbours.py` or a regional
   script) and run `test_routing`, `test_regions`, `test_harbours`.
5. Measure with `tests/benchmark.gd` before and after.

## 22. Captain's Orders updates

`CAPTAINS_ORDERS.md` now records: Iteration 16 is **The World Awaits**;
global sailing and international passages are authorized; Iteration 15 was
not delivered and is recorded as skipped (the Captain's decision to proceed);
Denmark remains the detailed foundation and other detailed regions are future
work; the global chart is intentionally lower resolution; the existing
simulation is used, not teleportation; Passage Readiness remains advisory;
small boats remain valid; cozy activities remain central; performance and save
compatibility are mandatory; no visible activation circles; the
eight-direction view and precise physics are preserved; iteration numbers are
plain integers; the branch link is mandatory in a delivery; Phase Two is not
reopened and its wording was not invented.

## 23. Push and tag status

- Every checkpoint was pushed to `origin/claude/friendly-fermat-dey23f` with
  a normal push (no force). Checkpoint H, `3cb379a`, was pushed and verified:
  `git ls-remote` showed the remote branch at
  `3cb379a7cd7290eca7dd481bb69e348c9bf6a83d`, the same as the local HEAD.
- This section was then filled in and committed on top of `3cb379a` (the
  branch head after it; the delivery message gives its hash, verified the
  same way).
- **Tag `v0.103a`: not pushed.** It was created locally on `3cb379a`, but
  `git push origin v0.103a` failed ("unexpected disconnect while reading
  sideband packet"); three retries reported "Everything up-to-date" while
  `git ls-remote --tags origin` still showed no such tag. As in Iteration 14,
  the tag is not on GitHub; it can be added from the GitHub web interface on
  `3cb379a` (or on the final commit) if wanted.
- No pull request was opened.
