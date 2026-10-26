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
| FISH-1 | Circular timing replaces the tension bar; constant angular speed; action key and mouse | DONE | ReelTiming + ReelDial; test_fishing2 [reel]; E/Space/click; screenshots 01–04 |  | PENDING |
| FISH-2 | Successful checks by rarity (existing rarity names), narrower windows at higher rarity | DONE | FishingCatalog.REEL 1/2/3/4 checks, 72/60/50/42°; test_fishing2 [reel] |  | PENDING |
| FISH-3 | Forgiving, documented miss allowance | DONE | LINE_CONTROL 3 grips; no cost for not pressing; test_fishing2 [fairness] |  | PENDING |
| FISH-4 | Smaller Perfect zone; modest specimen influence; never species/rarity | DONE | Perfect zone 30 % of the arc (≥10°); PERFECT_NUDGE 0.07 within the range; test_fishing2 [perfect] |  | PENDING |
| FISH-5 | Encounter from existing species/location logic; species and rarity preserved through the game | DONE | existing species/region/lure logic; species and rarity carried in the bite; test_fishing2 |  | PENDING |
| FISH-6 | Integrity: one result per catch, no duplicate insertion, no repeat after save/load, not while paused elsewhere | DONE | test_fishing2 [integrity]; test_joy_journey (no repeat after reload); restart_18 A |  | PENDING |
| FISH-7 | Bite handling: clear alert, reel-in immediately reachable, no silent loss | DONE | "Fish on! Reel in" badge with R; R from anywhere aboard; action wheel; test_fishing2 [bite] |  | PENDING |
| FISH-8 | Fishing while anchored (and moored where sensible): stationary rod fishing distinct from trolling | DONE | stationary at anchor/moored/waiting, trolling underway; test_fishing2, test_anchorage |  | PENDING |

## FART — Fish artwork and animation [§7]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| FART-1 | Every species in the data has recognizable illustrated art | DONE | 16 species + 3 junk painted (tools/fishing/paint_fish.py); test_fishing2 [art] (distinct silhouettes); fish_art_sheet_all_species.png | script-painted, simple style | PENDING |
| FART-2 | Blink (irregular, quick) and tail flick (brief) on prominent fish; optional gentle bob | DONE | FishPortrait blink/flick/bob; test_fishing2 [alive]; fish_animation_frames_mackerel.png (24 real frames), 11–14 |  | PENDING |
| FART-3 | Animation stops on close, bounded timers, no growth, pause and reduced motion respected; thumbnails static | DONE | processes only while visible; no timers; Reduce motion stills tail/bob; thumbnails static; the reel holds still under another window; test_fishing2 | blink kept under Reduce motion (by design) | PENDING |
| FART-4 | Reveal shows art, name, rarity (not by colour alone); same identity through the encounter | DONE | reel face: portrait, name, rarity badge in words |  | PENDING |
| FART-5 | Catch result panel: art, species, rarity, weight, grade, kept or released, actions | DONE | result card: art, name, rarity, kg, grade, kept/released line, Release/Back; 15–17 |  | PENDING |
| FART-6 | Same art in cool box, details, trophies; one presentation API ready for a future fishmonger | DONE | FishArt.thumbnail in cool box, trophy menu, trophy board; FishPortrait for large views |  | PENDING |
| FART-7 | Junk has its own non-living art | DONE | old boot, tangled rope, rusty tin; no blink; 10_junk_catch_artwork.png |  | PENDING |
| FART-8 | Asset provenance documented | DONE | assets/fishing/README.md; report §12 |  | PENDING |

## SPEC — Specimen grades [§8]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| SPEC-1 | Species, rarity, weight and grade kept distinct | DONE | separate fields; grade by weight only; test_fishing2 [grade] |  | PENDING |
| SPEC-2 | Bronze/Silver/Gold by weight within the species range; documented | DONE | Bronze ≥0.35, Silver ≥0.6, Gold ≥0.8 of the species range; report §15 |  | PENDING |
| SPEC-3 | Perfect hits nudge weight modestly within the species range only | DONE | landed_kg never above the species max; test_fishing2 [perfect] |  | PENDING |

## KEEP — Catch preferences [§9]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| KEEP-1 | Minimum rarity and minimum grade to keep; plain explanation of the rule | DONE | KeepRarity/KeepGrade on the rod; describe_keep; 20_fishing_preferences.png |  | PENDING |
| KEEP-2 | Automatic release: shown, not in cool box, trophies or sale | DONE | test_fishing2 [keep]; test_joy_journey [7]; 16_automatic_release_by_preferences.png |  | PENDING |
| KEEP-3 | Manual release: same exclusions; released fish never on the trophy board | DONE | release_fish removes the trophy and gives the species best back; test_fishing2 [release]; 17_manual_release.png |  | PENDING |
| KEEP-4 | Kept fish stored once through existing systems | DONE | test_fishing2 "stored exactly once" |  | PENDING |
| KEEP-5 | Preferences persist (existing schema where practical) | DONE | optional fields in format 12; restart_18 A; test_fishing2 [save] |  | PENDING |

## SHRK — Sharks and junk [§10, §11]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| SHRK-1 | Sharks by believable region (not Danish waters); distinct art | DONE | blue shark (Atlantic islands, Iberia, Biscay), blacktip (Caribbean, Central America, Pacific; coastal); 09_illustrated_shark.png |  | PENDING |
| SHRK-2 | Sharks always released: not food, not for sale, not trophies; friendly line | DONE | always released with a friendly line; counted; test_fishing2 [shark]; 09b_shark_landed_and_released.png |  | PENDING |
| SHRK-3 | Occasional junk with its own art and a little humour; no value, no trophy, discarded | DONE | junk_chance 0.06; discarded, worth nothing; test_fishing2 [junk] |  | PENDING |

## TRIM — Sail Trim [§14]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| TRIM-1 | Slider; best trim from the apparent wind angle and conditions | DONE | SailTrim.best from the true wind angle (+ strong wind); slider; test_sail_trim |  | PENDING |
| TRIM-2 | Readable feedback (too loose / well trimmed / too tight) | DONE | "Too loose / Well trimmed / Too tight" + percent; 21/22 screenshots |  | PENDING |
| TRIM-3 | Modest effect on speed; never beyond the sailing model; no stacking | DONE | factor 1.06…0.90 on speed only (not potential, not engine); test_sail_trim; measured +4.3 % / −7.3 % |  | PENDING |
| TRIM-4 | Optional: sensible default (auto trim) and gentle drift, no constant adjustment | DONE | "Leave it to the crew" is the default and sails as before | no gradual drift back to neutral (the default covers it) | PENDING |
| TRIM-5 | Persistence defined and tested; effect recomputed from the wind | DONE | trim kept through course changes/saves (optional field); effect recomputed from the wind; restart_18 C |  | PENDING |
| TRIM-6 | Computed on the simulation step, not searched per frame | DONE | computed in the sail evaluation (simulation step) |  | PENDING |

## PASS — Long Passage [§13, §15]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| PASS-1 | Fewer trivial interruptions; a fishing posture during fast time | DONE | "stop only for fish worth keeping"; 3 h rest between bites in fast time; pacing_18: 432 → 75 → 8 stops |  | PENDING |
| PASS-2 | Fast time stays faithful (distance, stores, wear, weather) | DONE | same simulation at any rate; existing Long Passage tests pass |  | PENDING |
| PASS-3 | No event storms at 20× or Long Passage | DONE | bite cooldown; quiet nibbles counted, reported once |  | PENDING |
| PASS-4 | Engine fuel cost recorded as a future consideration (not built) | DONE | recorded as a future consideration (report §19); not built |  | PENDING |

## ANCH — Anchorage waypoints and signals [§16–§18]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| ANCH-1 | Mark a waypoint (of the existing waypoint system) as an anchorage; edit, remove; shown on the chart | DONE | Anchorage button / M; anchor icon; test_anchorage [mark][chart]; 23, 24 |  | PENDING |
| ANCH-2 | First-use hint; keyboard/accessible way to mark | DONE | one-off hint; M key; test_anchorage [hint] |  | PENDING |
| ANCH-3 | Safe positioning: water, reachable, existing anchoring rules; unsafe spot explained | DONE | anchoring rule; land/offshore refused with reason; nearest spot offered; test_anchorage | not possible abroad (coarse world chart, pre-existing) | PENDING |
| ANCH-4 | Arrival: leg stops, boat stops safely, Long Passage paused, notice and prompt | DONE | STOP_ANCHORAGE; Long Passage stops; holding at the spot; prompt; test_anchorage [arrive][prompt]; 25 |  | PENDING |
| ANCH-5 | Anchor not set automatically; normal anchoring checks | DONE | Drop anchor opens the normal anchoring panel; checks apply; test_anchorage [anchor] |  | PENDING |
| ANCH-6 | Declining: no force, no prompt spam, resume/modify/cancel | DONE | Not yet keeps waiting, asked once; wheel offers anchor / Sail on; test_anchorage [wait] |  | PENDING |
| ANCH-7 | Resume the rest of the route after weighing anchor; no auto-departure while anchored | DONE | weighing anchor resumes; never stops there again; test_anchorage [resume], test_joy_journey [18], restart_18 B |  | PENDING |
| ANCH-8 | Save/load on approach, at the prompt, anchored, after declining, after resuming | DONE | saved while waiting, at anchor (test_anchorage), anchored with the companion on deck (restart_18 B, test_joy_journey) | save on the approach and after resuming are ordinary underway saves (covered by existing voyage persistence tests), not separately tested | PENDING |
| ANCH-9 | Black anchor ball by day at anchor only, forward rigging, eight views | DONE | AnchorSignals ball in the forward rigging, at anchor only; boat coordinates (turns with the view); test_companion_deck [ball]; 26 |  | PENDING |
| ANCH-10 | White anchor light at night at anchor (not the red/green) | DONE | "anchor" light at the masthead at night; no red/green; test_companion_deck [lights]; 28 |  | PENDING |
| ANCH-11 | Anchor buoy and rode; coherent with swinging and dragging; state transitions | DONE | rode slack/straighter when dragging, buoy bobbing; test_companion_deck [buoy]; 27 |  | PENDING |

## PET — Companion [§19]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| PET-1 | Follows to deck and back (moored or anchored) after a natural delay | DONE | App._update_companion_follow (2.5–5 s up, 4–8 s down); test_companion_deck [pet]; 29, 30 |  | PENDING |
| PET-2 | Safe resting spots on deck for every boat; never over water, outside the hull, on the helm | DONE | DeckCompanionSpots (true disc test vs lifeline, fittings, helm); every walk frame checked on all four boats | places computed, not hand-chosen | PENDING |
| PET-3 | Underway and heavy weather: stays inside; departure brings it in naturally | DONE | departure / anchor up / wind ≥20 kn / rain → below; test_companion_deck [safe], test_joy_journey [17] |  | PENDING |
| PET-4 | Save/load keeps the pet's area coherently | DONE | area and place saved (optional); test_companion_deck [save]; restart_18 B |  | PENDING |

## LIGHT — Lighting refinements [§20, §21]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| LIGHT-1 | Cabin: warmer pools at the fixtures, darker corners; readable; all four boats | DONE | pool texture, dimmer ambient, corner shade clipped to the hull; pool/corner 2.5–6.6× → 4.0–8.6× (cabin_light_18); test_lighting [cabin]; 31 |  | PENDING |
| LIGHT-2 | Exterior navigation lights: correct positions, visible over dark water, no halos, eight views | DONE | side lights on the rail; lamp dots; eight orientations checked on screen (test_companion_deck [lights]); 32 |  | PENDING |
| LIGHT-3 | Underway / anchored / moored lights distinguished | DONE | underway / anchor / moored / day; test_companion_deck, test_lighting |  | PENDING |
| LIGHT-4 | Night performance measured | DONE | benchmark_18 before/after, two runs each (report §26) | software renderer only | PENDING |

## WIND — Forecast refinement [§1 I17-S4, §22]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| WIND-1 | Steps chosen from measured model variation; useful horizon and history | DONE | measure_wind_variation.gd; 1 h steps, ±6 h (report §25); 34 |  | PENDING |
| WIND-2 | Labels, read-only behaviour, uncertainty wording, cache and zoom limits kept | DONE | test_wind_overlay [navigator] (labels, note, read-only, all 13 cached) |  | PENDING |

## SAVE — Persistence [§25, §29]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| SAVE-1 | Audit of what needs saving; format decision documented | DONE | report §3 (format 12, optional fields) |  | PENDING |
| SAVE-2 | 0.104a saves load (migration if needed) | DONE | old-save checks in test_fishing2, test_sail_trim, test_anchorage; existing save suites |  | PENDING |
| SAVE-3 | Two-process restarts: fishing, anchorage, sailing | DONE | tests/restart_18.tscn, two processes, scenarios A, B, C (report §29) |  | PENDING |
| SAVE-4 | Combined scenario (§23) with no duplication after reload | DONE | test_joy_journey: the §23 scenario in order; no duplicate prompt, result, walk or log entry after reload |  | PENDING |

## QA — Testing [§26–§28, §31]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| QA-1 | Focused suites per area | DONE | route_wrap, fishing2, sail_trim, anchorage, companion_deck, joy_journey (+ updated suites) |  | PENDING |
| QA-2 | Full regression | DONE | full regression on the final code (report §27) |  | PENDING |
| QA-3 | Rendered screenshots (34 scenes) reviewed; animation evidence over several frames | DONE | 34 scenes + art sheet + 24-frame animation strip in docs/screenshots/iteration18 (report §28) | software renderer | PENDING |
| QA-4 | Performance profiled before and after | DONE | benchmark_18 (report §26) |  | PENDING |
| QA-5 | Shipyard Efficiency measured | DONE | report §30 |  | PENDING |
| QA-6 | No I019–I021 scope; no difficulty mode | DONE | none started; no difficulty mode |  | PENDING |

## DOC — Delivery [§30, §34, §36, §38]

| ID | Requirement | Status | Evidence | Limitation | Windows |
|---|---|---|---|---|---|
| DOC-1 | ITERATION_18_REPORT.md (33 items) | DONE | ITERATION_18_REPORT.md |  |  |
| DOC-2 | WINDOWS_ACCEPTANCE_18.md (numbered sections, lettered tests) | DONE | WINDOWS_ACCEPTANCE_18.md |  |  |
| DOC-3 | CAPTAINS_ORDERS.md: the 25 I018 decisions; existing ones preserved | DONE | CAPTAINS_ORDERS.md "Iteration 18" (25 decisions); log entry |  |  |
| DOC-4 | Developer/architecture guides and asset provenance updated | DONE | README (version, controls), DEV_GUIDES/LIFE_ABOARD.md §9, assets/fishing/README.md |  |  |
| DOC-5 | Version per policy; push and remote HEAD verified | DONE | 0.105a; push verified (report §33) |  |  |
