# Iteration 18 — Requirement tracker

Source of truth: `ITERATION_18_ASSIGNMENT.md` (section numbers in brackets).
Status: **TODO**, **IN PROGRESS**, **DONE** (implemented *and* verified by the
named tests or evidence), **PARTIAL** (part done; limitation stated).
Manual (Windows) acceptance is **PENDING** for every row until the Captain's
own trial; it is never filled in here by the developer.

| Column | Meaning |
|---|---|
| Evidence | tests (suite and tag), screenshots, measurements |
| Limitation | what is not covered or differs from the assignment |

## MAP — Route overlay correction [§1 I17-S3, §5]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| MAP-1 | Root cause found from the code, not assumed | DONE | `_path_to_map` shifted the whole route to the world copy nearest the camera by its *first point*; report §5 |  | PENDING |
| MAP-2 | Route visible wherever it is in view, while panning east and west (several turns) | DONE | test_route_wrap: every copy reaching into the view is drawn (`MapView._path_copies`), checked by brute force and, rendered, by pixels; fails 29 checks on the 0.104a map code |  | PENDING |
| MAP-3 | Date Line routes wrap without a line across the map | DONE | test_route_wrap: Papeete → Auckland, waypoint on 180°, no segment jumps |  | PENDING |
| MAP-4 | Several waypoints; first and last segments in different copies; partly off screen | DONE | test_route_wrap: Middelfart → Papeete with three waypoints; regional zooms |  | PENDING |
| MAP-5 | Panning never changes waypoints, route, destination, distance, vessel, saved voyage | DONE | test_route_wrap fingerprint before/after every sweep |  | PENDING |
| MAP-6 | Working chart and Dreamer's Map; committed course line underway | DONE | test_route_wrap: draft, applied course underway, daydream route |  | PENDING |
| MAP-7 | Rendered before/after evidence | DONE | docs/screenshots/iteration18/33_route_before_after_pan_fix.png |  | PENDING |

## FISH — Fishing mechanics [§6, §12, §13]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| FISH-1 | Circular timing replaces the tension bar; constant angular speed; action key and mouse | TODO | | | PENDING |
| FISH-2 | Successful checks by rarity (existing rarity names), narrower windows at higher rarity | TODO | | | PENDING |
| FISH-3 | Forgiving, documented miss allowance | TODO | | | PENDING |
| FISH-4 | Smaller Perfect zone; modest specimen influence; never species/rarity | TODO | | | PENDING |
| FISH-5 | Encounter from existing species/location logic; species and rarity preserved through the game | TODO | | | PENDING |
| FISH-6 | Integrity: one result per catch, no duplicate insertion, no repeat after save/load, not while paused elsewhere | TODO | | | PENDING |
| FISH-7 | Bite handling: clear alert, reel-in immediately reachable, no silent loss | TODO | | | PENDING |
| FISH-8 | Fishing while anchored (and moored where sensible): stationary rod fishing distinct from trolling | TODO | | | PENDING |

## FART — Fish artwork and animation [§7]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| FART-1 | Every species in the data has recognizable illustrated art | TODO | | | PENDING |
| FART-2 | Blink (irregular, quick) and tail flick (brief) on prominent fish; optional gentle bob | TODO | | | PENDING |
| FART-3 | Animation stops on close, bounded timers, no growth, pause and reduced motion respected; thumbnails static | TODO | | | PENDING |
| FART-4 | Reveal shows art, name, rarity (not by colour alone); same identity through the encounter | TODO | | | PENDING |
| FART-5 | Catch result panel: art, species, rarity, weight, grade, kept or released, actions | TODO | | | PENDING |
| FART-6 | Same art in cool box, details, trophies; one presentation API ready for a future fishmonger | TODO | | | PENDING |
| FART-7 | Junk has its own non-living art | TODO | | | PENDING |
| FART-8 | Asset provenance documented | TODO | | | PENDING |

## SPEC — Specimen grades [§8]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| SPEC-1 | Species, rarity, weight and grade kept distinct | TODO | | | PENDING |
| SPEC-2 | Bronze/Silver/Gold by weight within the species range; documented | TODO | | | PENDING |
| SPEC-3 | Perfect hits nudge weight modestly within the species range only | TODO | | | PENDING |

## KEEP — Catch preferences [§9]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| KEEP-1 | Minimum rarity and minimum grade to keep; plain explanation of the rule | TODO | | | PENDING |
| KEEP-2 | Automatic release: shown, not in cool box, trophies or sale | TODO | | | PENDING |
| KEEP-3 | Manual release: same exclusions; released fish never on the trophy board | TODO | | | PENDING |
| KEEP-4 | Kept fish stored once through existing systems | TODO | | | PENDING |
| KEEP-5 | Preferences persist (existing schema where practical) | TODO | | | PENDING |

## SHRK — Sharks and junk [§10, §11]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| SHRK-1 | Sharks by believable region (not Danish waters); distinct art | TODO | | | PENDING |
| SHRK-2 | Sharks always released: not food, not for sale, not trophies; friendly line | TODO | | | PENDING |
| SHRK-3 | Occasional junk with its own art and a little humour; no value, no trophy, discarded | TODO | | | PENDING |

## TRIM — Sail Trim [§14]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| TRIM-1 | Slider; best trim from the apparent wind angle and conditions | TODO | | | PENDING |
| TRIM-2 | Readable feedback (too loose / well trimmed / too tight) | TODO | | | PENDING |
| TRIM-3 | Modest effect on speed; never beyond the sailing model; no stacking | TODO | | | PENDING |
| TRIM-4 | Optional: sensible default (auto trim) and gentle drift, no constant adjustment | TODO | | | PENDING |
| TRIM-5 | Persistence defined and tested; effect recomputed from the wind | TODO | | | PENDING |
| TRIM-6 | Computed on the simulation step, not searched per frame | TODO | | | PENDING |

## PASS — Long Passage [§13, §15]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| PASS-1 | Fewer trivial interruptions; a fishing posture during fast time | TODO | | | PENDING |
| PASS-2 | Fast time stays faithful (distance, stores, wear, weather) | TODO | | | PENDING |
| PASS-3 | No event storms at 20× or Long Passage | TODO | | | PENDING |
| PASS-4 | Engine fuel cost recorded as a future consideration (not built) | TODO | | | PENDING |

## ANCH — Anchorage waypoints and signals [§16–§18]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| ANCH-1 | Mark a waypoint (of the existing waypoint system) as an anchorage; edit, remove; shown on the chart | TODO | | | PENDING |
| ANCH-2 | First-use hint; keyboard/accessible way to mark | TODO | | | PENDING |
| ANCH-3 | Safe positioning: water, reachable, existing anchoring rules; unsafe spot explained | TODO | | | PENDING |
| ANCH-4 | Arrival: leg stops, boat stops safely, Long Passage paused, notice and prompt | TODO | | | PENDING |
| ANCH-5 | Anchor not set automatically; normal anchoring checks | TODO | | | PENDING |
| ANCH-6 | Declining: no force, no prompt spam, resume/modify/cancel | TODO | | | PENDING |
| ANCH-7 | Resume the rest of the route after weighing anchor; no auto-departure while anchored | TODO | | | PENDING |
| ANCH-8 | Save/load on approach, at the prompt, anchored, after declining, after resuming | TODO | | | PENDING |
| ANCH-9 | Black anchor ball by day at anchor only, forward rigging, eight views | TODO | | | PENDING |
| ANCH-10 | White anchor light at night at anchor (not the red/green) | TODO | | | PENDING |
| ANCH-11 | Anchor buoy and rode; coherent with swinging and dragging; state transitions | TODO | | | PENDING |

## PET — Companion [§19]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| PET-1 | Follows to deck and back (moored or anchored) after a natural delay | TODO | | | PENDING |
| PET-2 | Safe resting spots on deck for every boat; never over water, outside the hull, on the helm | TODO | | | PENDING |
| PET-3 | Underway and heavy weather: stays inside; departure brings it in naturally | TODO | | | PENDING |
| PET-4 | Save/load keeps the pet's area coherently | TODO | | | PENDING |

## LIGHT — Lighting refinements [§20, §21]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| LIGHT-1 | Cabin: warmer pools at the fixtures, darker corners; readable; all four boats | TODO | | | PENDING |
| LIGHT-2 | Exterior navigation lights: correct positions, visible over dark water, no halos, eight views | TODO | | | PENDING |
| LIGHT-3 | Underway / anchored / moored lights distinguished | TODO | | | PENDING |
| LIGHT-4 | Night performance measured | TODO | | | PENDING |

## WIND — Forecast refinement [§1 I17-S4, §22]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| WIND-1 | Steps chosen from measured model variation; useful horizon and history | TODO | | | PENDING |
| WIND-2 | Labels, read-only behaviour, uncertainty wording, cache and zoom limits kept | TODO | | | PENDING |

## SAVE — Persistence [§25, §29]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| SAVE-1 | Audit of what needs saving; format decision documented | TODO | | | PENDING |
| SAVE-2 | 0.104a saves load (migration if needed) | TODO | | | PENDING |
| SAVE-3 | Two-process restarts: fishing, anchorage, sailing | TODO | | | PENDING |
| SAVE-4 | Combined scenario (§23) with no duplication after reload | TODO | | | PENDING |

## QA — Testing [§26–§28, §31]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| QA-1 | Focused suites per area | TODO | | | PENDING |
| QA-2 | Full regression | TODO | | | PENDING |
| QA-3 | Rendered screenshots (34 scenes) reviewed; animation evidence over several frames | TODO | | | PENDING |
| QA-4 | Performance profiled before and after | TODO | | | PENDING |
| QA-5 | Shipyard Efficiency measured | TODO | | | PENDING |
| QA-6 | No I019–I021 scope; no difficulty mode | TODO | | | PENDING |

## DOC — Delivery [§30, §34, §36, §38]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| DOC-1 | ITERATION_18_REPORT.md (33 items) | TODO | | | |
| DOC-2 | WINDOWS_ACCEPTANCE_18.md (numbered sections, lettered tests) | TODO | | | |
| DOC-3 | CAPTAINS_ORDERS.md: the 25 I018 decisions; existing ones preserved | TODO | | | |
| DOC-4 | Developer/architecture guides and asset provenance updated | TODO | | | |
| DOC-5 | Version per policy; push and remote HEAD verified | TODO | | | |
