# Revision 0.105b — Safe Harbours, Deep Waters & the Sprite Workshop

Assignment: `REVISION_0_105B_ASSIGNMENT.md` (verbatim). Tracker:
`REVISION_0_105B_REQUIREMENTS.md`. Windows checklist:
`WINDOWS_ACCEPTANCE_0_105B.md`. Sprite Workshop: `SPRITE_WORKSHOP_REPORT.md`
and `art_replacements/README_START_HERE.md`.

**Windows acceptance is pending.** Everything here was verified on Linux
only. Numbers are measured unless marked *estimate*.

*(Draft: sections are filled in as the checkpoints land.)*

## 1. Baseline

- Branch `claude/friendly-fermat-dey23f`, HEAD `2f1ed06` ("I018: record the
  Checkpoint I push in the report"), equal to the remote; clean working tree.
- Version 0.105a (`GameVersion.DISPLAY`, `project.godot`), save format 12
  (`SaveManager.SAVE_VERSION`).
- I018 documents present (`ITERATION_18_*`, `WINDOWS_ACCEPTANCE_18.md`,
  `CAPTAINS_ORDERS.md`). The I018 report's figures (4,184 checks, 17 restart
  checks) are its own records of runs on `f8d68ed`; they are re-verified by
  this revision's own full regression rather than re-run at the start.

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
