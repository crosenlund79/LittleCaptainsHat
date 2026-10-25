# Chart regions: detailed coastlines (geographic data preparation)

Iteration 14. How the chart gets a detailed region (Denmark is the first),
where the data comes from, how to rebuild it, and how to add another region.

## 1. How it fits together

The game has one chart of Europe, in geographic coordinates (longitude,
latitude, WGS 84) with a Mercator raster for navigation:

| Layer | Files | Detail |
|---|---|---|
| Base chart | `data/navigation/europe_navmask.png`, `data/navigation/europe_navmask.json`, `data/navigation/europe_route_graph.json`, `data/navigation/europe_land.json` | 60 cells per Mercator degree (about 1 nautical mile); Natural Earth 10m coastlines |
| Regions | `data/navigation/regions.json` lists them; each has a folder such as `data/navigation/regions/denmark/` | finer (Denmark: 6 times, about 175 m cells); OpenStreetMap coastlines |

A region is a rectangle of the base chart, its edges on base raster cells, with
its own raster, route graph and drawing, in the **same coordinates**. Nothing
about positions, saves or projections changes, and the base files stay exactly
as they were: outside the regions the game is unchanged.

- **Navigation** (`src/navigation/nav_grid.gd`): `NavGrid.grid_at()` answers
  with the finest chart covering a position. Point and line checks
  (`cell_class_at_geo`, `is_geo_line_clear`) cut a line where it crosses a
  region's edge and check each part on its own chart.
- **Routes** (`src/navigation/sea_router.gd`): the region's graph replaces the
  base graph nodes inside it; seam edges join the two; base edges that cross
  the region but are not clear on the detailed chart are dropped. Harbour
  approaches are searched in the finest chart.
- **Drawing** (`src/navigation/map_view.gd`): the base land is clipped away
  inside each region; the region draws a light **overview** outline when zoomed
  out and its **detailed** coastline once the chart is zoomed in past
  `detail_from_px_per_degree` (in `region.json`). Region labels appear at their
  own zoom.
- **Anchoring, fishing, the hat's open water** read the same composite chart
  (`src/anchor/anchor_site.gd`, `src/fishing/fishing_catalog.gd`,
  `src/hat/hat_story.gd`), so they see the detailed coast too.
- **Saves**: a position saved under an older, coarser chart that the detailed
  chart places on land is moved to the nearest open water when the game is
  loaded, and the course is re-planned from there (`GameSession._recover_location`).
  The vessel is never stranded or erased; a notice tells the player.

## 2. The Danish data

| | |
|---|---|
| Land | OpenStreetMap land polygons as packaged by geo-maps *earth-lands-100m* 0.6.0 (npm `@geo-maps/earth-lands-100m`, GeoJSON, about 100 m accuracy), file `package/map.geo.json`, SHA-1 of the package `bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41`. Retrieved 2026-10-25. |
| Licence | Map data © OpenStreetMap contributors, **ODbL 1.0** (openstreetmap.org/copyright). The region's raster, land and graph are derived databases and are ODbL too. The package's own code is MIT. |
| Labels | Town positions from GeoNames (lutangar/cities.json, **CC BY 4.0**), only to place the chart's island and water names; texts in `tools/navigation/danish_labels.json`. |
| Coordinates | WGS 84 longitude/latitude (EPSG:4326); raster rows in Mercator like the base chart. |
| Region | 8.0–15.4° E, 53.8–58.0° N, snapped outwards to base cells: Denmark, the Øresund, the Kattegat to Gothenburg, the German Baltic coast to Rügen's west, Bornholm. |

Processing (`tools/navigation/build_region.py`): the polygons are clipped to the
region with a 0.1° margin; holes are filled (lakes and the source's tile-seam
artefacts count as land, as in the base chart); the raster uses the base
chart's conservative rule (any land in a cell makes it land, at 1/4-cell
precision; approach-only water needs a water majority). The route graph is a
lattice that gets finer near the coast plus the centre lines of narrow water,
so narrow sounds get nodes. The drawn coastline is simplified (detail 0.0003°,
overview 0.0035°); tiny islets are dropped from the drawing only, never from
the raster.

**What it is not**: there are no depths, buoys, shoals, rocks, shipping lanes,
tides or harbour layouts. Harbours are gameplay positions near their towns.
The chart is for a cozy game, not for navigation.

## 3. Rebuilding the region

You need python3 with numpy, scipy, shapely 2, pillow and scikit-image, and the
two source files (they are not kept in the repository):

1. `map.geo.json` from
   `https://registry.npmjs.org/@geo-maps/earth-lands-100m/-/earth-lands-100m-0.6.0.tgz`
   (unpack; check the SHA-1 above).
2. `cities.json` from the lutangar/cities.json project (GeoNames cities).

```
python3 tools/navigation/build_region.py path/to/map.geo.json path/to/cities.json denmark
```

It writes `region.json`, `navmask.png`, `land.json` and `graph.json` into the
region's folder in about 12 seconds, and prints the graph and seam figures.
The build is deterministic: the same inputs give the same files. Then run the
tests (`tests/suites/test_routing.gd`, `tests/suites/test_regions.gd`,
`tests/suites/test_harbours.gd`); they check that every graph edge is clear,
that routes stay off the drawn land, and that every harbour has an approach.

## 4. Adding another region

1. Add an entry to `REGIONS` in `tools/navigation/build_region.py`: a name, the
   bounds, the detail factor (6 for Denmark; keep the fine raster below about
   3,000 × 3,000 cells), the simplification and a labels file like
   `tools/navigation/danish_labels.json`.
2. Build it as above, with land data that covers it and whose licence you
   record in the region's `region.json` (the script writes the source and
   licence fields; change them if your source differs).
3. Add the folder to `data/navigation/regions.json`.
4. Regions must not overlap. A region outside the base chart's extent needs
   the base chart extended first (a separate, larger job).
5. Run the tests. Add harbours for the region as described in
   [HARBOURS.md](HARBOURS.md).

## 5. Performance

Measured by `tests/suites/test_regions.gd` (headless; see the Iteration 14
report for the figures): navigation with the region loads in well under a
second, a route through Danish waters plans in a few milliseconds, and the
chart switches between the overview and the detailed layer in a fraction of a
millisecond. The detailed coastline is drawn in 0.5° tiles so that only the
visible ones cost anything.
