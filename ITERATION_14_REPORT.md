# Iteration 14: A Bigger World, a Better Boat

*Detailed Danish waters as the first regional chart, and boat care:
wear, boatyards, the haul-out, equipment and Passage Readiness.* Version
**0.102a**, save format **12**.

Nothing in this report has been accepted on Windows. That is the Captain's
trial, with `WINDOWS_ACCEPTANCE_14.md`.

## 1. Repository verification and starting HEAD

- **Working directory:** `/home/user/LittleCaptainsHat`.
- **Remote:** `https://github.com/crosenlund79/LittleCaptainsHat` (fetch and
  push), the only authorized repository. KindleSpark, NomadicSailor,
  GardenOfOddlings and the archived Next Harbor repository were not touched.
- **Branch:** `claude/friendly-fermat-dey23f`; the working tree was clean.
- **Starting HEAD:** `799af34` (Iteration 13 Checkpoint H part 2, 0.101a,
  save format 11), equal to the remote branch.
- No force pushes, resets or overwrites; the Captain's artwork
  (`Visuals/`) is untouched.

## 2. Final version and save format

- **Version 0.102a** (the next feature milestone after 0.101a, following
  0.<milestone><letter>); `GameVersion.MACHINE` 0.102.1; `project.godot`
  carries the same.
- **Save format 12** (`SaveManager.SAVE_VERSION`): the new `boat_care`
  section. Format 11 saves migrate on load (section 15).

## 3. Datasets, sources and licences

| Data | Source, version, date | Licence | Used for |
|---|---|---|---|
| Danish land polygons | OpenStreetMap land polygons as packaged by geo-maps *earth-lands-100m* **0.6.0** (npm `@geo-maps/earth-lands-100m`, `package/map.geo.json`, package SHA-1 `bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41`), about 100 m accuracy; retrieved 2026-10-25 | Map data © OpenStreetMap contributors, **ODbL 1.0**; package code MIT. The derived region files are ODbL too. | the region's raster, route graph and drawn coast |
| Town positions | GeoNames cities via lutangar/cities.json | **CC BY 4.0** | Danish harbour positions (placed off the coast), chart label positions |
| Base chart | Natural Earth 1:10m land (unchanged) | public domain | Europe outside the region |

**Coordinate system:** WGS 84 longitude/latitude (EPSG:4326) throughout;
navigation rasters in Mercator rows, as the base chart. The region uses the
base chart's cells per Mercator degree × 6 with its edges on base cells, so
positions, saves and projections did not change.

**Not used:** no online map tile service at runtime (all data is in the
repository); the first-choice OSM downloads (osmdata.openstreetmap.de,
Geofabrik) and GeoNames' own server were blocked by this environment's
network policy, so the npm-packaged OSM land polygons and the GitHub-hosted
GeoNames list were used instead. Attribution is in `README.md` (Credits),
`data/navigation/regions/denmark/region.json` and
`DEV_GUIDES/CHART_REGIONS.md`.

**Not invented:** no depth soundings, buoys, shoals, rocks, shipping lanes,
tide tables or marina layouts. Coastlines come only from the data above.

## 4. Processing scripts

- `tools/navigation/build_region.py` (new): clips the OSM polygons to the
  region with a 0.1° margin, fills holes (lakes and the source's tile-seam
  artefacts become land), rasterizes with the base chart's conservative rule
  (any land in a cell makes it land at 1/4-cell precision; approach water by
  majority), builds the region graph (a lattice that refines towards the coast,
  192 → 12 fine cells, plus the skeleton of narrow water so sounds get nodes),
  links it to the base graph (seam edges) and lists the base edges that cross
  the region but are not clear. Display: detail simplified 0.0003°, overview
  0.0035° (as the base), 0.5° tiles; labels from GeoNames towns. Deterministic
  (a rebuild gave identical files); about 12 s.
- `tools/navigation/add_danish_harbours.py` (new): 23 harbours from town
  positions, placed 0.15 nm off the nearest OSM coastline; writes their CSV
  rows (with the source recorded) and facility files by tier. Then
  `tools/navigation/build_harbours.py` (existing) writes the port resources.
- `tools/navigation/danish_labels.json` (new): label texts and the towns that
  place them.

How to rebuild: `DEV_GUIDES/CHART_REGIONS.md` §3.

## 5. Regional architecture

- `data/navigation/regions.json` lists regions; each folder holds
  `region.json` (bounds, factor, sources, licence, CRS, processing),
  `navmask.png`, `land.json` and `graph.json`.
- `NavGrid` (`src/navigation/nav_grid.gd`) loads them over the unchanged base:
  `grid_at()`, `region_id_at()`, and composite `cell_class_at_geo()` /
  `is_geo_line_clear()` which clip a line at a region edge (Liang–Barsky) and
  check each part on its own chart.
- `SeaRouter` merges each region's graph: base nodes inside are disabled,
  region nodes appended, seam edges added, crossing base edges dropped.
  Harbour approaches are searched in the finest grid.
- `MapView`: base land and coast are clipped outside the regions; each region
  has an overview layer (zoomed out) and a detail layer (from
  `detail_from_px_per_degree`, 140 px per degree), and labels with their own
  minimum zoom. A base label that a region also places is shown once.
- A Python/GDScript consistency detail: Godot's `Vector2` is 32-bit, so the
  seam nudge (0.01 cell) and edge clamp (0.001 cell) are float32-safe and
  mirrored in the build script; every region graph edge passes the runtime
  check.
- Adding Sweden, New Zealand or French Polynesia later is an entry in the
  build script and `regions.json` (regions outside the base chart's extent
  need the base extended first). None was built.

## 6. Denmark detail coverage

- Region 8.0–15.4° E, 53.80–58.00° N: all of Denmark (Jutland, Funen, Zealand,
  Lolland, Falster, Møn, Langeland, Ærø, Als, Samsø, Læsø, Bornholm and the
  small islands), the Øresund with the Swedish shore to Gothenburg and Ystad,
  the Kattegat, the Belts, the South Funen Archipelago, Smålandsfarvandet and
  the German coast from Kiel to west of Rügen.
- Raster 2664 × 2706 cells, 360 per Mercator degree (about 175 m north–south);
  graph 8,695 nodes and 37,194 edges; 227 seam links; 1,114 base nodes
  replaced; 446 crossing base edges blocked.
- Drawn coast: detail 512 polygons / 13,872 points; overview 125 / 6,737.
- 19 labels (Jutland, Zealand, Funen, Lolland, Falster, Møn, Langeland, Ærø,
  Als, Bornholm, Samsø, Læsø, Kattegat, Øresund, Great Belt, Little Belt,
  Fehmarn Belt, Smålandsfarvandet, South Funen Archipelago).

## 7. Coarse or unsupported areas

- Everywhere outside the region the chart is the Natural Earth outline (about
  one nautical mile), unchanged; Sweden north of Gothenburg, Norway and the
  rest of the Baltic are not detailed.
- Inside the region, water narrower than about two cells (~350 m) can close:
  the raster is conservative (land wins). Small harbour basins, canals and
  narrow fjord mouths may read as land; harbours are placed just off the
  coast so they stay reachable.
- Lakes and enclosed lagoons count as land. Man-made features that OSM maps
  as land (moles, causeways) appear as land; there are no bridges to sail
  under.
- The 100 m source accuracy and the display simplification (about 30 m)
  smooth the smallest coves.

## 8. Route and harbour improvements

- Routes in Danish waters follow the detailed coast: through the Øresund, the
  Great and Little Belts, Smålandsfarvandet and the South Funen Archipelago,
  never across Zealand or Funen (tested, section 17). Outside the region the
  routes are unchanged (the existing routing suite passes as before).
- **23 new Danish harbours** (187 in the catalogue): Helsingør, Gilleleje,
  Dragør, Rødvig, Stege, Vordingborg, Nysted, Korsør, Kalundborg, Nyborg,
  Kerteminde, Svendborg, Faaborg, Ærøskøbing, Marstal, Rudkøbing, Middelfart,
  Juelsminde, Ebeltoft, Grenaa, Skagen, Rønne, Sønderborg. Every Danish
  harbour has an approach to open water.
- **Tiers** (`HarbourFacilities.get_tier()`, optional `haul_out` switch):
  - small (no boatyard): Lohals (unchanged), Gilleleje, Dragør, Rødvig,
    Stege, Nysted, Kerteminde, Ærøskøbing, Juelsminde, Ebeltoft;
  - larger (boatyard): Helsingør, Vordingborg, Korsør, Kalundborg, Nyborg,
    Faaborg, Marstal, Rudkøbing, Middelfart, Grenaa, Rønne, Sønderborg;
  - major (haul-out): Copenhagen (keeps its boatyard, now with haul-out),
    Svendborg, Skagen, and harbours without a file of their own that are the
    catalogue's major ports (importance 1).
  These are gameplay tiers, not claims about real yards.
- **Save location recovery** (`GameSession._recover_location`, on every
  load): a voyage position, anchor or course that the detailed chart puts on
  land or across an island is moved to the nearest open water (searched in
  the finest grid, preferring water connected to the sea, up to 15 nm, then
  60 nm) and the course re-planned to the same destination; a planned course
  in harbour is re-planned. The vessel is never erased; a notice explains it
  and the session log records `location_recovered`.

## 9. Maintenance design

Boat care extends the existing condition (the hull % that weather damages);
it adds a per-boat `BoatCareState` (`src/core/boat_care_state.gd`):
`hull_cleaned_at`, `rig_wear`, `engine_hours`, `upgrades`, `history`.

| Area | Wear | Levels cosmetic / recommended / needs attention | Effect |
|---|---|---|---|
| Hull and bottom | condition (existing); weed 1/day in the water | 25 / 50 / 100 days (and the hull's band) | from 30 days, up to −6 % speed over 90 days |
| Rigging and sails | 0.05/nm, ×2 at 20 kn, ×3 at 28 kn; +0.6 per % damage | 15 / 35 / 65 | from 40, up to −5 % sail speed; from 50, up to +30 % weather damage |
| Engine | hours under power | 50 / 80 / 160 h | from 120 h, up to −10 % engine speed |
| Equipment | — | — | the upgrades |

The overview (`BoatCareView`) reads each area in words and colour with what
to do; it is in the Captain's Log (new **Boat** tab, with the boatyard
history) and the Boat care panel. One notice when an area reaches
"recommended" underway. The effects are applied through
`GameSession.get_vessel_profile()` (cached), so sailing, ETA and
propulsion all see them.

## 10. Wear and repair balance

- A 30 ft boat sailing 50 nm a week in moderate wind gains about 2.5 rig wear
  a week: the rig reaches "recommended" after roughly three months of
  ordinary sailing, sooner in strong winds. The bottom needs a haul-out after
  about 50 days (about 125 with the coating). Engine service every 80 hours.
- Prices (size factor = length / 30 ft): repair €3 per missing % (a 40 %
  damaged Arctic Wanderer: about €100; a Clam 40: about €160), rig service
  €70 + €1.50 per wear point, engine service €90, haul-out €10 per foot
  (€260 for the Arctic Wanderer, €400 for the Clam 40). Against €10,000 at
  the start and €25 an hour of remote work, care is noticeable but never
  punishing.
- Repairs, which were free until 0.101a, now cost their quote; rescue,
  changing boats and voyages stay free.

## 11. Boatyards and haul-outs

- The boatyard panel's service button is now **Boat care…** (it names the
  worst level when something needs attention). Boat care shows only the work
  this yard does: repairs and services at any boatyard; the haul-out and the
  coating only where the yard hauls out. A harbour without a boatyard has no
  boatyard sign, and every way in is refused with a short message and no
  charge (tested at Lohals, Stege and Korsør).
- Each service shows price and time; not needed or not affordable says why.
  The time passes ashore (`Simulation.spend_time_ashore`).
- **The haul-out** (`HaulOutPanel`, `HaulOutScene`): options (engine and rig
  service when due, the hard coating if not fitted) with the total and a day
  ashore; then the travel lift raises the boat (drawn in code), the weed fades
  off, a day passes, and the result is written to the care history; the first
  haul-out is a Captain's Log moment (+2 renown, once). One transaction
  (`GameSession.haul_out`), refused as a whole if anything is not possible.

## 12. Upgrades and effects

`data/boat/equipment.json`, six items, priced per foot (Arctic Wanderer /
Clam 40):

| Upgrade | Price | Effect |
|---|---|---|
| Heavier anchor and chain | €420 / €640 | +5 kn holding |
| Weather receiver | €310 / €480 | route weather warnings 10 h ahead instead of 6 |
| Gimballed stove | €230 / €360 | cooking underway up to 26 kn instead of 18 |
| Large cool box | €160 / €240 | 10 fish instead of 6 |
| New stainless rigging | €780 / €1,200 | rig wear ×0.5, weather damage ×0.9 |
| Hard antifouling coating (haul-out yards) | €520 / €800 | weed grows at 0.4× |

Bought once per boat; none makes a boat faster than new (tested). No tech
tree; the Arctic Wanderer stays a small boat.

## 13. Passage Readiness

`PassageReadiness.assess(path)`: OK / note / worth a second thought, from the
hull, the care areas, food and water against the estimated passage time
(+1 day margin, +2 comfortable), the forecast on the route (the same as the
warnings, up to 24 h), the length (overnight from 14 h, several days from
48 h) and small boats (28 ft or less) facing rough weather or long passages.
Shown in the chart's Course tab for a course in harbour and in the "Set sail?"
question. It never disables Set sail (tested: a damaged boat with no stores
can still depart). Wording example: "Worth a second thought before setting
out. • The hull is worn (45 %). Fine for a short hop; a boatyard repair
would be wise before a long passage."

## 14. Existing system integration

- **Fishing** (coastal water) and **anchoring** (land distance, fetch,
  shelter) use the composite chart, so in Danish waters they see the detailed
  coast (tested off five Danish harbours). The cool box size, the stove's
  wind limit and the anchor's holding read the equipment.
- **Weather**: the receiver extends the route warning horizon; rig wear adds
  weather damage.
- **Provisions**: Passage Readiness compares them with the passage; time at
  the yard uses them as usual.
- **Captain's Log**: Boat tab; first haul-out moment; renown via the existing
  ledger.
- **Interactions** keep the illustrated highlights; no circles were added.
- **Eight-direction view** unchanged (its suite passes).

## 15. Save migration

- Format 12 adds `boat_care` {vessel id → record}, validated on load (finite
  numbers, known and unique upgrades).
- `SaveManager._migrate_11_to_12`: the active boat gets a record with the hull
  last cleaned 20 days earlier, rig wear 0.02 and engine hours 0.03 per mile
  in the Captain's Log (at most 30 and 60), no equipment. Other boats get a
  fresh record when boarded. Logged as `save_migrated`.
- Location recovery runs after every load (section 8).
- Tested: a format 11 save with 500 nm loads with rig wear 10, engine 15 h,
  20 days since cleaning, nothing else changed.

## 16. Performance results

Measured by `tests/suites/test_regions.gd` (headless, this container):

| Measurement | Result |
|---|---|
| Navigation load (base + Denmark region) | 410 ms |
| Navigation memory (static, approx.) | 46 MB |
| Graph nodes (base + region) | 32,755 |
| Cold route Copenhagen → Svendborg (new router, no caches) | 14 ms |
| Routes in Danish waters (8 voyages) | 1–15 ms each |
| Chart open (including the fade) | 347 ms |
| Zoom change (overview ↔ detail) | 0.11 ms |
| Frame with the detailed chart (headless) | 6.9 ms |

The rendered (Xvfb, software OpenGL) runs of the chart views were smooth;
these are not Windows measurements.

## 17. Automated tests

New suites:

- `test_regions` (41 checks): region loaded and documented; inland towns are
  land, straits open; every Danish harbour has an approach; eight voyages
  valid and sensible; anchoring and fishing off Danish harbours; recovery of
  a voyage, an anchor and a course on land, and a valid voyage untouched;
  performance; the chart's overview/detail switch.
- `test_boat_care` (80 checks): the catalogue; wear (bottom, rig with wind,
  engine hours, predictability, speed effects); services (no yard, no
  haul-out, costs by damage and size, unneeded services); haul-out (cost,
  day, history, first award once); upgrades (effects, paid once, coating needs
  a haul-out yard, no faster than new); Passage Readiness (ready, worth a
  second thought, never gating, long passages, small boats); migration from
  format 11; the panels (overview, rig service and repair with time passing,
  fitting, the haul-out with options, Stege and Korsør, the Log's Boat tab,
  readiness in the chart).
- `test_denmark_views` (17 checks): chart views at every scale with the
  right layer, a course round Zealand, sailing and anchoring in Danish waters,
  Svendborg's boatyard highlight and fleet.

Updated for intended changes (not weakened): paid repairs (`test_upkeep`,
`test_upkeep_ui`, `test_living`); the facility tiers (`test_harbour_life`);
version and format (`test_branding`, `test_diagnostics`); the dev guides list.
Made independent of geometry that the detailed chart changed:
`test_gameplay_flow` (drag the longest course leg on screen instead of leg
number 3), `test_galley_and_anchor` (the gale turns to the anchorage's most
open side; the detailed Øresund coast now shelters the first site from the
east), `test_life_aboard` (a heading may differ by one unit in the last place
after JSON).

RESULTS_PLACEHOLDER

## 18. Rendered screenshots

Rendered under Xvfb (software OpenGL, 1600 × 900), inspected one by one;
in `docs/screenshots/iteration14/`:

| # | Required | File | Seen |
|---|---|---|---|
| 1 | Denmark at regional scale | `14_01_denmark_regional.png` | all of Denmark in detail, the new harbours, island and water names |
| 2 | Zealand | `14_02_zealand.png` | Zealand with Isefjord, Roskilde Fjord, Køge Bay; Copenhagen, Dragør, Rødvig |
| 3 | Funen | `14_03_funen.png` | Funen, the Little and Great Belts, the archipelago south of it |
| 4 | Jutland waters | `14_04_jutland_waters.png` | Jutland's east coast fjords, Juelsminde, the Little Belt |
| 5 | Langeland and Lohals | `14_05_langeland_lohals.png` | the long island with Lohals at its north end, Rudkøbing on its west shore |
| 6 | Island passages | `14_06_island_passages.png` | Ærø, Marstal, Ærøskøbing and the sounds between the islands |
| 7 | Copenhagen approach | `14_07_copenhagen_approach.png` | the harbour, Amager, Saltholm, the Øresund |
| 8 | Route around land | `14_08_route_around_land.png` | Copenhagen → Svendborg south through the Øresund, past Møn, Smålandsfarvandet, round Langeland's north end |
| 9 | Close coastal view | `14_09_close_coastal_view.png` | Svendborg Sound at close zoom |
| 10 | Zoomed-out view | `14_10_zoomed_out.png` | Europe; Denmark's light outline matches the rest |
| 11 | Maintenance overview | `14_11_maintenance_overview.png`, `14_11b_log_boat_tab.png` | the four areas in words and colour; the Log's Boat tab |
| 12 | Boatyard repairs | `14_12_boatyard_repairs.png` | services with price and time, done ones no longer offered |
| 13 | Haul-out | `14_13a_haul_out_options.png`, `14_13b_haul_out_lifting.png`, `14_13_haul_out.png` | the options and total; the boat in the slings; the result |
| 14 | Upgrades | `14_14_upgrades.png` | six items with effects and prices, the cool box fitted |
| 15 | Passage Readiness | `14_15_passage_readiness.png` | the Course tab: worth a second thought, hull and stores |
| 16 | Small harbour without a yard | `14_16_small_harbour_without_yard.png` | Stege: groceries and Go Ashore only |
| 17 | Sailing in Danish waters | `14_17_sailing_danish_waters.png`, `14_17b_chart_underway_danish_waters.png` | on deck underway to Svendborg; the chart around the boat |
| 18 | Anchorage near the coast | `14_18_anchorage_near_coast.png`, `14_18b_anchorage_on_deck.png` | anchored off the coast; at anchor on deck |
| 19 | Fleet in harbour interactions | `14_19_fleet_in_harbour.png`, `14_19b_boatyard_fleet.png` | Svendborg's boatyard sign lit up; the boatyard with the fleet |

Findings from the review, fixed before delivery: base-chart water names
(Øresund, Great Belt, Kattegat) were drawn twice next to the region's (now
once, by the region, visible as early as before); the haul-out mast poked
above its picture (clipped); the chart header said "0.0 kn under sail" at
anchor (now "At anchor on the way to …"); readiness text was long in the
side panel (three findings at most); test notices covered some panels
(cleared for the shots).

## 19. Known limitations

- Only Denmark is detailed; no other region was built.
- No depths, buoys, shoals, rocks, lanes, tides or marina layouts anywhere;
  anchoring remains the conservative land/wind model.
- The region raster is about 175 m: very narrow water closes; small harbour
  basins are not drawn; there are no bridges to sail under.
- Harbour positions are near their towns, not real berths.
- Danish harbours' tiers are gameplay choices, not real facilities.
- Boat care has no breakdowns or failures at sea; wear only slows the boat
  a little and makes weather a little harder.
- Passage Readiness uses the same estimate and forecast as the chart; the
  forecast only sees weather that already exists.
- The haul-out illustration is a simple drawing, not the illustrated art
  style of the boats.
- Windows acceptance has not happened; performance figures are from this
  container.

## 20. Captain's Orders updates

`CAPTAINS_ORDERS.md`: a new section records the Iteration 14 authorization
(both scopes and their rules); the "Not now" list keeps a worldwide chart
and adds further regions, noting that maintenance and equipment were
commissioned now; the Phase One/Phase Two section records that the Phase Two
wording is still not in the repository (not guessed) and that the scope freeze
holds; the iteration log has the new entry. All earlier decisions are kept
unchanged.

## 21. Commits, tag and push status

COMMITS_PLACEHOLDER
