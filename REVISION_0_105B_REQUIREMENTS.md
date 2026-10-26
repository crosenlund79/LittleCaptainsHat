# Revision 0.105b — Requirement tracker

Source of truth: `REVISION_0_105B_ASSIGNMENT.md` (section numbers in brackets).
Status: **TODO**, **PARTIAL** (part done; limitation stated), **DONE**
(implemented *and* verified by the named tests or evidence). Windows
acceptance is **PENDING** for every row until the Captain's own trial; it is
never filled in by the developer.

## GEO — Geography and root cause [§3, §6]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| GEO-1 | Root cause of the international restriction found from the code and documented | TODO | | | | | PENDING |
| GEO-2 | Finer coastal land/water than the routing grid, near the candidate point | TODO | | | | | PENDING |
| GEO-3 | Never on land; safe margin from the shore | TODO | | | | | PENDING |
| GEO-4 | Reachable: conservative connection from the route to the anchorage; no invented passages | TODO | | | | | PENDING |
| GEO-5 | Navigable water, coast proximity, depth and shelter kept distinct | TODO | | | | | PENDING |

## DEPTH — Bathymetry and game estimates [§4, §5]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| DEPTH-1 | Real sources investigated and recorded (name, edition, licence, access) | TODO | | | | | PENDING |
| DEPTH-2 | One authoritative depth service with tiers and provenance | TODO | | | | | PENDING |
| DEPTH-3 | Deterministic game estimate, smooth, varied, same after restart | TODO | | | | | PENDING |
| DEPTH-4 | Estimates labelled GAME ESTIMATE; no fake surveyed precision | TODO | | | | | PENDING |
| DEPTH-5 | Bounded data, no full-resolution global grid in memory, offline | TODO | | | | | PENDING |

## SHELTER — Coastal exposure [§7]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| SHELTER-1 | Shelter from wind and nearby land, independent of depth | TODO | | | | | PENDING |
| SHELTER-2 | Exposed in a storm even if fine in fair weather; advisory wording | TODO | | | | | PENDING |

## ZONE — Anchorage overlay [§8, §30]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ZONE-1 | Optional toggle on the working chart; only at close zoom | TODO | | | | | PENDING |
| ZONE-2 | Visible area only, cached tiles, bounded eviction, frame budget | TODO | | | | | PENDING |
| ZONE-3 | Normal (teal) vs Magic (amber) distinguished, with legend | TODO | | | | | PENDING |
| ZONE-4 | Friendly inspection text with depth and its source | TODO | | | | | PENDING |
| ZONE-5 | Correct after panning and world wrapping | TODO | | | | | PENDING |

## WAYPOINT — Anchorage route integration [§9]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| WAYPOINT-1 | Mark only inside eligible regions; reason and nearby suggestion otherwise | TODO | | | | | PENDING |
| WAYPOINT-2 | Normal vs Magic requirement shown and saved | TODO | | | | | PENDING |
| WAYPOINT-3 | Zoom does not remove or alter planned anchorages | TODO | | | | | PENDING |
| WAYPOINT-4 | Arrive, stop, prompt, anchor, resume (I018 flow) worldwide | TODO | | | | | PENDING |

## NANCH — Normal anchoring worldwide [§10, §15]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| NANCH-1 | Normal anchor works on suitable international coasts | TODO | | | | | PENDING |
| NANCH-2 | Existing scope, holding, drag, visuals, persistence reused | TODO | | | | | PENDING |
| NANCH-3 | Acceptance areas: Denmark, Iberia/Med, Canaries/Madeira, Caribbean, Polynesia, New Zealand | TODO | | | | | PENDING |

## MAGIC — Magic Anchor [§11, §13, §14]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| MAGIC-1 | Fictional equipment with flavour text; obtainable by a documented prototype route; all boats | TODO | | | | | PENDING |
| MAGIC-2 | Deep / uncertain depth eligible; land and unreachable water still refused | TODO | | | | | PENDING |
| MAGIC-3 | Offshore emergency deployment in open water, documented limits | TODO | | | | | PENDING |
| MAGIC-4 | Existing holding/drag model; real depth stored separately from the effective holding | TODO | | | | | PENDING |
| MAGIC-5 | No shelter or weather immunity; offshore says so | TODO | | | | | PENDING |
| MAGIC-6 | Modest distinct presentation (chart icon, brass flourish) | TODO | | | | | PENDING |
| MAGIC-7 | State transitions and one authoritative anchored state | TODO | | | | | PENDING |
| MAGIC-8 | Engine stops when anchoring succeeds; cannot restart while anchored; friendly message; old saves normalised | TODO | | | | | PENDING |
| MAGIC-9 | Decorative solar panels on all four boats; no power simulation; attached through turns; not obstructing | TODO | | | | | PENDING |

## SKILL — Special deployment challenge [§12]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| SKILL-1 | Reusable constant-speed timing component shared with fishing, no catch state | TODO | | | | | PENDING |
| SKILL-2 | 1 / 2 / 3 successes by conditions; Perfect bounded holding bonus | TODO | | | | | PENDING |
| SKILL-3 | Miss costs time, retry, cancel; no random failure; player informed | TODO | | | | | PENDING |

## SAVE — Persistence [§29, §34]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| SAVE-1 | Format decision documented; optional fields; 0.105a saves load | TODO | | | | | PENDING |
| SAVE-2 | Two-process restarts: international normal anchor, Magic Anchor, artwork fallback | TODO | | | | | PENDING |

## ARTINV — Artwork inventory [§20–§23]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTINV-1 | Audit of real artwork and renderer types | TODO | | | | | PENDING |
| ARTINV-2 | Display and 2× source sizes from how each is shown | TODO | | | | | PENDING |
| ARTINV-3 | Complexity C1–C4, priorities, first 25, quick wins | TODO | | | | | PENDING |
| ARTINV-4 | Three inventory counts with views, classes and workload points | TODO | | | | | PENDING |

## ARTMAN — Manifests [§17–§19]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTMAN-1 | Folder hierarchy with manifest.csv and README.md per folder; START_HERE and index | TODO | | | | | PENDING |
| ARTMAN-2 | Schema with all required fields; stable unique IDs; honest status | TODO | | | | | PENDING |
| ARTMAN-3 | Duplicates and invalid paths validated | TODO | | | | | PENDING |

## ARTRES — Resolver [§24, §25]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTRES-1 | get_artwork(id, fallback): index once, cache, fallback, warnings | TODO | | | | | PENDING |
| ARTRES-2 | Works in the ZIP → editor workflow (imported or not yet imported PNG) | TODO | | | | | PENDING |
| ARTRES-3 | Never alters gameplay geometry, collisions, safe zones, IDs | TODO | | | | | PENDING |

## ARTTEST — Demonstrated replacements [§26]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| ARTTEST-1 | Small prop replacement, full test sequence | TODO | | | | | PENDING |
| ARTTEST-2 | Pet replacement, full test sequence | TODO | | | | | PENDING |
| ARTTEST-3 | Composed/layered replacement, full test sequence | TODO | | | | | PENDING |
| ARTTEST-4 | Fixtures kept apart; nothing left installed | TODO | | | | | PENDING |

## PERF — Performance [§30]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| PERF-1 | Overlay bounded and measured | TODO | | | | | PENDING |
| PERF-2 | Resolver: no per-frame scans, cached loads | TODO | | | | | PENDING |
| PERF-3 | Before/after benchmarks; I018 benchmark version metadata explained and fixed | TODO | | | | | PENDING |

## QA — Testing [§32, §33]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| QA-1 | Focused suites for each area | TODO | | | | | PENDING |
| QA-2 | Full regression | TODO | | | | | PENDING |
| QA-3 | Rendered evidence (24 scenes + solar panels) reviewed | TODO | | | | | PENDING |
| QA-4 | No I019–I021 scope | TODO | | | | | PENDING |

## DOC — Delivery [§35, §36, §39, §40, §42]

| ID | Requirement | Status | Implementation | Test evidence | Screenshot | Limitation | Windows |
|---|---|---|---|---|---|---|---|
| DOC-1 | REVISION_0_105B_REPORT.md (27 items, Shipyard Efficiency) | TODO | | | | | |
| DOC-2 | WINDOWS_ACCEPTANCE_0_105B.md | TODO | | | | | |
| DOC-3 | SPRITE_WORKSHOP_REPORT.md and art_replacements/README_START_HERE.md | TODO | | | | | |
| DOC-4 | CAPTAINS_ORDERS.md: 31 decisions; attribution docs; scripts | TODO | | | | | |
| DOC-5 | Version 0.105b; push verified | TODO | | | | | |
