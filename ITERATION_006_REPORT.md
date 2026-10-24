# Iteration 006: Making Waves (Report)

**Engine:** Godot 4.7.2, GDScript, Compatibility renderer.

**Tested on:** Linux only: headless runs, plus Xvfb with Mesa llvmpipe software OpenGL for rendered runs.

**Not tested on Windows.** The owner's checks are in [WINDOWS_ACCEPTANCE_I006.md](WINDOWS_ACCEPTANCE_I006.md).

The loop is now: Explore → Sail → Arrive → Record → Renown → Publish → Money → Prepare. Every checkpoint (A–F) was committed and pushed separately.

## 1. Starting branch and commit

- **Branch:** `claude/determined-brahmagupta-3v95mx`.
- **Baseline:** I005b `d2f7e1d`. The I006 baseline check found the I005c money and provisions functionality missing, so I stopped and reported it.
- **I005c:** at the owner's instruction, I implemented it first as its own checkpoint, `9ff3360`. See [ITERATION_005C_REPORT.md](ITERATION_005C_REPORT.md).
- **I006 checkpoints:**

| Checkpoint | Commit | Content |
|---|---|---|
| A | `718304f` | Captain's Log |
| B | `80eba01` | Objectives and renown |
| C | `d8786a5` | Social-media income; the core loop is playable from here |
| D + E | `c343dc2` | Harbour architecture and 163 harbours |
| F | see §20 | Final verification, restart check, docs |

## 2. Captain's Log architecture

- **Data:** `CaptainsLog` (`src/core/captains_log.gd`) is plain data in `SessionState.captains_log`. GameSession is its only writer.
- **What it holds:**
  - `total_nm`, `voyages_completed`, `arrivals`;
  - `longest`: the record of the longest passage;
  - `visited`: port id → first visit and arrivals;
  - the latest **50** voyage records.
- **Rescues** are not repeated in the log: it shows the existing `rescue_count`.
- **No second voyage system.** The log is written in only two places, inside GameSession's own transactions:
  - `complete_voyage()` writes an *arrived* record;
  - `rescue()` writes a *rescued* record.
- **Fields added to `Voyage`:** `departure_port_id` and its position (kept through changes of course), `sailed_nm` (advanced from the simulation's own progress in `apply_simulation_step`), `worst_hazard` and `damage_percent`.
- **UI:** `CaptainsLogMenu`, opened with **L** (aboard or on the chart) or from the pause menu.
  - Tabs: **Log** (statistics, renown, publish button, recent passages), **Harbours** (visited and not yet visited) and **Objectives**.
  - Fixed size; lists scroll.
- **Order fix:** in `Simulation._assess_weather` the weather at the boat is now recorded before the damage step. A voyage lost in a storm therefore keeps that storm in its record. The weather and rescue suites are unchanged and pass.

## 3. Voyage and visit tracking

- **A harbour becomes visited** only by arriving and mooring there. A new game records its start harbour (with 0 arrivals).
- **These change nothing in the log:** plotting a course, an abandoned destination after a change of course, waiting, sleeping, working, loading, and the rescue tow home.
- **A rescued voyage** counts its miles. It is not a completed voyage, an arrival, a visit or a "longest passage".
- **The distance sailed is the same** in one large step or 540 small ones (tested).
- **Size:** a full log (50 records) is under 20,000 characters of JSON (tested).

## 4. Objectives

Data file: `data/progression/objectives.json`, evaluated by `ObjectiveCatalog` (`src/core/objective_catalog.gd`). There are **16 objectives**:

| Kind | Objectives | Renown |
|---|---|---|
| Introduction | Cast off (1st voyage) | 20 |
| | Across the Western Baltic (Kiel) | 15 |
| | The first hundred miles | 25 |
| Exploration | New horizons (every new harbour, repeatable) | 10 |
| | Harbour hopper (5 harbours) | 30 |
| | Well travelled (10 harbours) | 50 |
| | 3 generated *Far horizons* | 30–50 |
| Sailing | Regular passages (5 voyages) | 30 |
| | A thousand miles | 50 |
| Challenge | Offshore passage (≥ 200 nm) | 30 |
| | Long haul (≥ 500 nm) | 50 |
| | Blue-water passage (≥ 300 nm, repeatable) | 15 |
| | Not a scratch (≥ 150 nm without damage) | 30 |
| Weather | Heavy weather (arrive after dangerous weather) | 40 |

- **Types:** voyage count, total distance, visit a harbour, visit N harbours, passage length, passage without damage, arrival after hazardous weather, and new harbour.
- **Generated objectives** come from the harbour catalogue: distant harbours (≥ 600 nm from Copenhagen), evenly spread by distance, with the reward scaled by distance. They can only name harbours that exist. With 163 harbours they are Dublin, Barcelona and Gibraltar.
- **Validation:** invalid definitions (unknown harbour or type, zero target or reward) are left out with an error.
- **Tracked automatically.** The Objectives tab shows each objective's requirement, progress, reward, and how often a repeatable one has been completed.
- **Weather and no-damage objectives need a fully recorded voyage.** A voyage migrated from an older save cannot qualify on weather it may not have met.

## 5. Renown system

- **`ObjectiveProgress`** (the `progress` save section) holds lifetime renown (which only increases), unpublished renown, the completions (`count`, `first`, `last_event`) and the latest 20 rewards.
- **When rewards are paid:** objectives are evaluated only in `GameSession._award_objectives()`, inside `complete_voyage()` and `rescue()`, in the same transaction as the log record.
- **Paying once:**
  - A one-time objective pays once.
  - A repeatable one pays only for a voyage that ended later than the last one it paid for.
  - Re-evaluating the same voyage, loading, saving, returning to known harbours and rescues therefore never pay twice (all tested).
- **Notifications:** one short "+N renown: …" message per voyage.

## 6. Social-media conversion

- **The transaction:** `GameSession.publish_travel_update()`, in harbour only.
  - All unpublished renown × €2 (`euros_per_renown` in the data file) is paid in one step.
  - Unpublished renown drops to 0; lifetime renown is unchanged; `lifetime = published + unpublished` holds (tested).
- **Refusals:** with nothing to publish, or at sea, it changes nothing.
- **Confirmation** (`PublishMenu`): shows unpublished renown, rate, earnings and funds before → after, with *Publish for €X* or *Cancel*. It is reached from the Captain's Log and from the work station dialog, so there is no new interactable on board.
- **Unchanged:** remote work and the grocery store (tested together).
- **Not built (excluded by the spec):** followers, platforms, sponsors, algorithms and photos.

## 7. Harbour catalogue changes

- **Audit findings (before the change):**
  - `get_port()` was a linear scan.
  - The chart drew every port and label at every zoom.
  - Ports had no notion of importance.
  - Routing was already independent of ports: harbours join the sea graph at runtime through `find_port_approach`, so no navigation data had to be rebuilt.
  - Saves store only ids.
- **Changes:**
  - **Records:** `PortData` gained `importance` (1–3), `region`, `island` and `source`.
  - **Lookups:** `PortCatalog` gained an id dictionary, a 2° spatial grid (`ports_in_rect`) and `search()`.
  - **Data pipeline:** `tools/navigation/harbours.csv` is the source of truth. `build_harbours.py` writes the resources.
  - **Rejected candidates** are listed with reasons in `harbours_rejected.csv`.
- **Original harbours:** all 15 ids, coordinates and descriptions are unchanged.

## 8. Final destination count

- **163 harbours:** the 15 originals plus 148 added. This is the "preferred ~150" target.
- **Candidates:** 180 were checked. 17 were rejected (§10). 47 more were never added because UN/LOCODE has no coordinates for them (for example Esbjerg, Dover, Southampton, Valencia, Riga, Gdańsk and Rhodes), and I added nothing without a verified coordinate.

## 9. Geographic coverage

| Area | Harbours |
|---|---|
| Mediterranean (W/central, incl. Corsica, Sardinia, Sicily, Malta, Balearics) | 32 |
| Baltic | 21 |
| Aegean (incl. Crete, Cyclades, Turkish coast) | 19 |
| Norway / Skagerrak | 18 |
| Adriatic | 16 |
| North Sea | 12 |
| English Channel and Channel Islands | 10 |
| British Isles (Irish Sea, Scotland, Orkney, Shetland) | 9 |
| Bay of Biscay | 8 |
| Atlantic Iberia | 8 |
| Ionian | 5 |
| Eastern Mediterranean (Cyprus, Marmaris) | 3 |
| North Atlantic (Iceland, Faroes) | 2 |

- **Spread:** no area has more than 20 % of the harbours, and 44 are island harbours.
- **By country (added harbours):** France 21, Italy 21, Greece 18, Norway 15, United Kingdom 12, Sweden 9, Croatia 9, and 18 more countries.
- **Coordinates:** UN/LOCODE (UNECE), via the `datasets/un-locode` code list. Each row's `source` names the entry and its published coordinate (arc-minute precision, about 1.8 km).
- **No harbour was invented or moved by hand.**

## 10. Routing validation

`test_harbours` checks every harbour. All 163 pass:

- it lies within the chart;
- it has a harbour approach that reaches open sea (not inland, not in a closed basin);
- it lies on a coast (chart land within 3 nm);
- it has a valid sea route to its nearest original harbour.

Measured: 148 routes in about 0.3 s.

Representative trips (all pass, distances along the course):

| Kind | Trips |
|---|---|
| Short coastal | Aarhus → Copenhagen 111 nm; Nice → Cannes 27 nm |
| Island hopping | Mykonos → Paros 26 nm; Palma → Ibiza 74 nm; Hvar → Korčula 57 nm |
| Offshore | Brest → A Coruña 355 nm; Bergen → Tórshavn 370 nm; Lisbon → Cagliari 1,054 nm |
| Difficult coasts | Tromsø → Honningsvåg 197 nm; Arendal → Kiel 289 nm; Lerwick → Kirkwall 96 nm |
| Narrow passages | Messina → Catania 55 nm; Bonifacio → Olbia 51 nm; Málaga → Lagos (Gibraltar) 242 nm; Malmö → Copenhagen (Øresund) 18 nm |
| Long | Mariehamn → Heraklion 3,827 nm; Reykjavík → Limassol 3,835 nm |

**Rejected (17):**

- **No approach from open water at the UN/LOCODE point** (often the town centre, or up a river or archipelago the chart cannot represent): Stockholm, Oslo, Rotterdam, Valletta, Plymouth, Rostock, Turku, Umeå, Ostend, Newcastle, Bayonne, Bilbao, Mahón, Kotor and Kos.
- **Molde:** its fjord is not connected to open water in the chart.
- **Helgoland:** the island is below the chart's minimum islet size, so the harbour would sit in open sea.

## 11. Viewport and label performance

**How the chart works:**

- Only harbours in view (plus a margin) are considered.
- Markers depend on zoom and importance: importance 1 always, 2 from 45 px per degree, 3 from 110 px per degree. Selected, destination and current harbours always get a marker.
- Labels are placed in priority order on the first free side (right, left, above, below). Names never overlap; this is tested at three zoom levels.
- The layout is recomputed only when the view changes.
- Hidden harbours cannot be clicked, but the search finds all of them.

**Measured (headless, this Linux container; benchmark in `test_harbour_chart`; average of 20 layouts):**

| Catalogue | Layout ms, whole / regional / close | Markers shown, whole / regional / close | `ports_in_rect` µs | `get_port` µs |
|---|---|---|---|---|
| 15 real | 0.49 / 0.09 / 0.03 | 15 / 4 / 1 | 5.3 | 0.78 |
| 50 real | 0.50 / 0.26 / 0.02 | 19 / 15 / 1 | 7.6 | 0.82 |
| 100 real | 0.88 / 0.23 / 0.02 | 27 / 15 / 1 | 6.4 | 1.05 |
| 163 real | 1.34 / 0.24 / 0.31 | 41 / 15 / 21 | 18.2 | 0.83 |
| 1,000 synthetic | 2.13 / 0.37 / 0.47 | 50 / 22 / 27 | 18.5 | 0.90 |

- **Lookup comparison:** the old list-scan lookup on 1,000 harbours took 46.8 µs.
- **What is not measured:** frame-rate figures on real GPUs. The numbers above are CPU-side layout and lookup costs only. Software-rendered frame times under Xvfb are not representative of a Windows PC, so none are claimed.
- **Clustering and chunk loading** were not needed at this size and were not built.

## 12. Save migration

| Version | Adds | Migration from the previous version |
|---|---|---|
| **8** | `log`, and the voyage's log fields | Invents nothing: no voyages, distance or arrivals. Only harbours with evidence are listed as visited: Copenhagen (every older game started there) and the harbour the boat lies in, with "first visit unknown". A voyage under way gets its course's origin, distance = progress, and is marked not fully recorded. |
| **9** | `progress` (renown and objectives) | Starts empty: no renown for the past. Objectives are checked against the log at the next voyage's end. |

- **Tested:** v7 → 9 (in port and under way), v8 → 9, and all older migrations (existing suites).
- **Preserved:** funds, provisions, conditions, rescue history, weather seed, vessel, companion, clock, voyage and route (tested).

## 13. Automated test results

- **Full headless run** after Checkpoints D/E: **2,159 checks, 0 failed**. The first run gave 2,157 passed and 2 failed: two old checks that required "10–15 ports". They were updated to the new target, re-run and passed.
- **New suites:**

| Suite | Checks |
|---|---|
| `test_captains_log` | 71 |
| `test_objectives` | 78 |
| `test_publishing` | 42 |
| `test_harbours` | 34 |
| `test_harbour_chart` | 17 |

- **Final full headless run** after the documentation commit: **2,162 checks passed, 0 failed**, exit code 0. This includes the new documents linked from `test_dev_guides`.

## 14. Rendered test results

- **Full rendered run** (Xvfb, OpenGL 3, Mesa llvmpipe, `--screenshots`): **2,168 checks passed, 0 failed**, exit code 0. It produced 121 screenshots.
- **Screenshots in `docs/screenshots`:**
  - the 10 new ones (108–117) were added;
  - the 104 existing ones were refreshed from this run. The chart shots now show the larger harbour set.
- The rendered run has 6 more checks than the headless one: checks that only run with a real display.

## 15. Restart results

The two-process check (`restart_check.tscn`, write then read in separate processes) was extended. It now writes a game that has:

- sailed Copenhagen → Gothenburg;
- earned renown and published a travel update;
- changed to the Petrel;
- been under way to Kiel for 3 hours.

**Result: PASS.** Every item was restored: settings, area and position, voyage, propulsion, companion, clock, Captain's Log, renown (lifetime 95, 1 publication), the voyage's distance from Gothenburg, vessel, weather, exposure, money, stores and each boat's condition.

## 16. Screenshot review

All of these were looked at:

- `108_captains_log`: statistics in two columns, longest passage on one line, recent passages newest first.
- `109_captains_log_harbours`: visited harbours with first-visit dates; the not-yet-visited list.
- `110_objectives`, `111_objectives_completed`: renown summary, open objectives with progress and reward, completed list with dates.
- `112_publish_travel_update`: 100 renown × €2 = €200, funds €10,000 → €10,200.
- `113_log_after_publishing`: renown "100 (0 unpublished)", button disabled with its reason.
- `114_chart_wide_zoom`: whole Europe with about 40 major harbours, no overlapping names.
- `115_chart_close_zoom`: the Aegean with every harbour named (Paros's label moved left of its marker to avoid Naxos).
- `116_chart_search`, `117_chart_search_result`: search results; Korčula selected and zoomed in, the sidebar unchanged.
- The chart's sea and country labels can still sit near harbour names at wide zoom. This is pre-existing and judged acceptable.

## 17. Known limitations

- Several large ports are missing. Some have no UN/LOCODE coordinate (Esbjerg, Dover, Valencia, Riga, Gdańsk and others). Others fail on the chart at their UN/LOCODE point (Stockholm, Oslo, Rotterdam, Valletta and others).
- Descriptions of added harbours are short and generic ("an island harbour on the Aegean Sea").
- Arrivals always equal completed voyages in this version: every completed voyage ends with exactly one arrival.
- Generated objectives depend on the catalogue. If harbours are added later, the set can change. Objectives already completed keep their renown.
- Renown has no other use yet; the publishing rate is fixed (configurable in data).
- Not run on Windows. No GPU frame-rate measurements.

## 18. Scope reductions and their reasons

- **Harbours: 163, so the target was not reduced.** The reasons some named or major ports are absent are in §8, §10 and §17.
- **Not built:** marker clustering and chunk loading. They are not needed at this size (§11).
- **Strict exclusions respected:** none of the excluded features (§16 of the spec) were built.

## 19. Remaining owner acceptance tests

See [WINDOWS_ACCEPTANCE_I006.md](WINDOWS_ACCEPTANCE_I006.md):

- **K:** Captain's Log;
- **L:** objectives and renown;
- **M:** publishing;
- **N:** the chart with 163 harbours (readability and responsiveness are the owner's judgement);
- **O:** older saves.

The I005 checklist still applies. Owner acceptance is not claimed from automated results.

## 20. Final Git commit and push status

- **Branch:** `claude/determined-brahmagupta-3v95mx`, pushed.
- **Commits:** I005c `9ff3360`; I006 A `718304f`, B `80eba01`, C `d8786a5`, D+E `c343dc2`, F `4eaf122` (restart check and documents) plus a final commit with these results and the refreshed screenshots (the branch head; see `git log`).
- **No pull request** was created, and nothing of I007 was implemented.
