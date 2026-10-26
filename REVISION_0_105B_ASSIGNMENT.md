LITTLE CAPTAIN'S HAT
REVISION 0.105b — SAFE HARBOURS, DEEP WATERS & THE SPRITE WORKSHOP
FULL, STANDALONE COMMISSIONING ASSIGNMENT
Repository: https://github.com/crosenlund79/LittleCaptainsHat
Expected development branch: `claude/friendly-fermat-dey23f`
Starting baseline: Iteration 18 — The Joy of the Journey
Starting game version: 0.105a
Starting save format: 12
Target version: 0.105b, subject to the repository's documented version policy.
Revision type: A focused post-I018 revision, not Iteration 19.
Captain's governing principle: COZY FIRST.
Tagline: Small boat. Wide world. Hold onto your hat.
0. THIS IS THE COMPLETE ASSIGNMENT
Monsieur Claude,
This document is the full and authoritative commissioning prompt for Revision 0.105b.
There is no missing base assignment.
You are authorized to implement the work specified here after verifying the repository and starting baseline.
Do not ask for a separate original prompt, additional commissioning instructions or a previous ChatGPT conversation.
Before implementation, save this complete assignment verbatim in the repository as:
`REVISION_0_105B_ASSIGNMENT.md`
This file must remain the source of truth after context compaction or interruption.
If your session is interrupted:

1. Reopen this assignment.
2. Read the requirement tracker.
3. Check the current branch, Git status and most recent checkpoint.
4. Resume from the last verified implementation state.
5. Do not restart the entire revision or request the Captain to resend instructions.

Two principal deliverables
A. Worldwide Coastal Anchoring
Make normal and special anchoring genuinely usable across the worldwide sailing map, without treating coarse global geographic data as a reason to forbid anchoring everywhere outside Denmark.
B. Sprite Workshop — Phase 1
Create a documented, manifest-driven artwork replacement framework that allows the Captain to place replacement images in clearly defined folders and have Godot use those images automatically, with safe fallback to existing artwork.
These deliverables must integrate with the existing game rather than becoming parallel demonstrations disconnected from normal play.
Scope protection
This revision does not start:

* I019 collision radar, voice warnings or VHF rescues.
* I020 boat personalization, shops or the commerce backend.
* I021 dedicated performance and economy balancing.
* A general visual redesign.
* A complete rebuild of the navigation engine.

Preserve all existing I018 gameplay.
The Captain will conduct full Windows acceptance after this revision, not before it.
Do not claim that I018 has already passed comprehensive Windows acceptance.
1. VERIFIED STARTING POINT AND REPOSITORY SAFETY
Before writing implementation code, verify:

* Working directory and repository remote.
* Development branch and HEAD commit.
* Working-tree cleanliness and existing uncommitted work.
* Current game version 0.105a.
* Save format 12.
* `CAPTAINS_ORDERS.md`.
* `ITERATION_18_ASSIGNMENT.md`.
* `ITERATION_18_REQUIREMENTS.md`.
* `ITERATION_18_REPORT.md`.
* `WINDOWS_ACCEPTANCE_18.md`.
* Existing anchoring implementation.
* Anchorage waypoint editing and voyage stopping.
* World and regional chart architecture.
* Coastline, depth and land-collision data.
* World wrapping and the I018 route-overlay fix.
* Existing equipment architecture.
* Existing sprite/resource architecture.
* Procedural drawing systems.
* Boat, deck, cabin, pet, fishing and harbour visual definitions.
* Existing art ownership and provenance records.
* Existing test and screenshot infrastructure.

I018 reportedly delivered 0.105a with unchanged save format 12, 4,184 passed Linux regression checks, 17 passed separate-process restart checks, and a pushed development branch.
Treat those as reported starting facts and verify them against the repository.
Do not work in the archived Next Harbor repository.
Do not modify unrelated projects.
Do not overwrite Captain-owned artwork.
Do not reset, clean away, force-push or discard valid work.
Use ordinary recoverable checkpoint commits.
2. WHY THIS REVISION EXISTS
The Captain has made a clear design decision.
I018 introduced anchorage waypoints, but its report states that the game's coarse worldwide chart prevents ordinary anchoring outside the detailed Denmark region.
That is not the intended final gameplay.
The game already allows worldwide sailing. The Captain must therefore be able to seek shelter and anchor at appropriate coastal locations around the world.
It is not necessary to build a professional hydrographic simulator.
It is necessary to create a believable, deterministic, understandable game system that uses real-world data where useful and honest game approximations where required.
Additionally, the Captain intends to hand-draw replacement artwork over time.
Rather than producing an enormous, disconnected sprite inventory, build an actual artwork replacement framework and generate the artwork inventory as part of that work.
The Captain should be able to draw one object, place the image in the documented location, run the game and see it.
No GDScript editing should be necessary.
PART A — WORLDWIDE COASTAL ANCHORING
3. INVESTIGATE THE REAL CAUSE OF THE INTERNATIONAL RESTRICTION
I018 reports:

* A coarse global coastline/grid outside detailed Denmark.
* Approximately 5-nautical-mile global chart cells.
* An ordinary anchoring rule requiring proximity to land within 2.5 nautical miles.
* The interaction of those constraints effectively excluding worldwide anchorages.

Do not assume that missing bathymetry is the only cause.
Inspect the real code and establish precisely:

1. Where anchoring suitability is calculated.
2. Which coastline representation it uses.
3. How distance to shore is computed.
4. How water depth is currently represented.
5. Whether anchor suitability uses a different geographic resolution than voyage routing.
6. How the boat's position is validated against land.
7. How anchorage waypoints are validated and moved.
8. What controls anchor scope, holding and dragging.
9. How actual anchoring state is saved.
10. Which data are sufficiently accurate for gameplay and which are not.

Document the specific root cause.
Do not merely relax a 2.5 nm constant until everything passes.
The new implementation must distinguish navigable water, coast proximity, depth and shelter.
4. WORLDWIDE DEPTH INFORMATION
Investigate practical sources of game-useful bathymetry.
Preferred candidates
GEBCO 2026
Official source:
https://www.gebco.net/data-products-gridded-bathymetry-data/gebco2026-grid
Download service:
https://betadownload.gebco.net/
A worldwide terrain/elevation dataset with approximately 15 arc-second grid spacing, available in downloadable regions.
EMODnet Bathymetry
Official source:
https://emodnet.ec.europa.eu/en/bathymetry
Detailed regional bathymetric models, particularly useful in European waters.
These are starting research candidates, not mandatory dependencies if direct acquisition proves impractical.
Required investigation
For each chosen source, record:

* Official dataset name and edition/date.
* Provider and download URL.
* Geographic coverage.
* Grid resolution.
* Coordinate reference system.
* Vertical reference and what negative/positive elevations mean.
* Metadata distinguishing measured and interpolated values where available.
* Data licence, redistribution conditions and required attribution.
* Processing scripts and regeneration procedure.
* Source file size.
* Resulting game-data file size.
* Known gaps and caveats.

Do not describe an interpolated depth as a surveyed sounding.
Do not imply that the game is suitable for real navigation.
Never download enormous multi-gigabyte datasets blindly.
Prefer bounded geographic subsets, reproducible preprocessing and compact derived game data.
The worldwide ocean grid must not be loaded into memory at full native resolution during ordinary gameplay.
No online connection should be required when the game is played.
Data availability problems
If an official source cannot be downloaded from the development environment:

* Document the obstacle.
* Try a legally and technically appropriate smaller source or geographic subset.
* Implement the local deterministic approximation described below.
* Never claim data were acquired when they were not.
* Do not block the entire revision waiting for an inaccessible download.

The final system must still support international anchoring, even when real depth coverage is incomplete.
5. A THREE-TIER GAME DEPTH MODEL
Create one authoritative depth-information service or adapter, reusing existing geography systems where possible.
Tier A — Regional detail
Use sufficiently detailed regional game data or suitable licensed bathymetric data.
Tier B — Global approximation
Use available global bathymetric values where their resolution is adequate for broad game decisions.
These may be interpolated values; they are not guaranteed soundings.
Tier C — Deterministic game estimates
Where depth data are missing or the available raster is too coarse near shore, calculate a consistent game-estimated depth from appropriate inputs.
Possible inputs:

* Distance from the coastline.
* Coastal geometry.
* Nearby valid bathymetric values.
* Broad underwater slope where evidence exists.
* Whether the area is a bay, island shelf or exposed open coast.
* Local geographic scale.

Do not randomly generate a new depth whenever the player moves the waypoint.
The same location must produce the same game depth after restarting.
The depth field should change smoothly enough that neighbouring points behave plausibly.
Never create a discontinuous sequence of arbitrary 8 m / 800 m / 12 m values along the same short stretch of coast.
Do not make every coastline identical.
Do not assume that proximity to land automatically means the bottom is shallow.
If estimates are not geophysically trustworthy, label them GAME ESTIMATE rather than implying realistic bathymetric accuracy.
Important distinction
Internally retain provenance or confidence information such as:

* Regional data.
* Global data.
* Game estimate.

Do not confuse confidence in the dataset with depth suitability.
A location can be:

* Shallow but exposed.
* Deep but sheltered.
* Shallow but obstructed.
* Deep, accessible and usable with special anchoring equipment.

Keep these concepts separate.
6. FINER COASTAL SUITABILITY WITHOUT REBUILDING THE WORLD
The existing global routing grid is intentionally coarse.
Do not rebuild the entire worldwide route planner at Denmark-level detail.
Instead, implement a localized anchorage-suitability assessment that can use appropriate finer coastal information near the candidate point.
It must:

* Respect real land and water boundaries where the available source supports them.
* Never recommend an anchorage on land.
* Avoid placing the boat in an inaccessible enclosed feature.
* Respect a reasonable safe margin from the shoreline and obstacles.
* Reject impossible approaches.
* Preserve the actual voyage navigation and collision model.
* Avoid inventing precision where the data do not support it.

If the world routing grid cannot resolve a narrow cove or lagoon entrance, do not pretend the boat can safely sail through it.
Offer nearby reachable open-water positions instead.
At the same time, do not reject the whole island merely because its coarse global cell cannot express nearby shallow water.
Use a conservative and coherent connection between the actual world route and the final anchorage approach.
Test this distinction explicitly.
7. ANCHORAGE SUITABILITY — DEPTH IS NOT SHELTER
Evaluate anchoring suitability using at least three distinct questions.
A. Can the vessel reach this position safely?
Land and route geometry must allow arrival.
B. Is the water appropriate for the selected anchoring equipment?
Use depth, scope and equipment limitations.
C. Is this a sensible location in the present or forecast conditions?
Use a lightweight shelter/exposure assessment.
Possible shelter inputs include:

* The direction of the current wind.
* Nearby coastline and land in the direction from which wind or waves arrive.
* Broad orientation of a bay.
* Distance to nearby land.
* Existing weather severity.

Do not implement a full wave, tide or current simulator.
Do not pretend that absence of a wind-facing shoreline proves perfect shelter.
Treat forecast information as advisory and uncertain.
A location may remain usable in fair weather but be marked as exposed in a storm.
A magical depth solution must not magically remove wind, waves, land hazards or anchor-drag risk.
8. THE ANCHORAGE SUITABILITY OVERLAY
Create a clear, attractive chart overlay showing candidate anchorage areas.
The Captain likes the visual language of weather fronts or weather-system highlights: soft translucent regions rather than a forest of individual icons.
Behaviour

* Available on the operational navigation chart.
* Optional and easy to toggle.
* Shown only when zoomed in sufficiently.
* Limited to currently visible geographic areas plus a modest margin.
* Not evaluated globally whenever the chart opens.
* Updated when map movement, zoom, equipment state or relevant weather state requires it.
* Cached using geographic tiles/chunks or another bounded method.
* Old cache entries evicted to avoid uncontrolled growth.
* No expensive worldwide scans per rendered frame.

Suggested presentation
Normal anchoring area
Soft teal/green highlighted water.
Special-equipment anchoring area
Soft amber highlight where a Magic Anchor is eligible and ordinary anchoring is not.
Unsuitable area
Not necessarily a full red overlay. A clear rejection explanation on hover/selection may be preferable to painting every stretch of coast red.
Do not hide useful chart geography beneath solid colour.
Use legible small symbols or a legend as well as colour.
Avoid making the interface look like a highly technical nautical chart.
Labels
When inspecting an area, show friendly information such as:

* Suitable for ordinary anchoring.
* Estimated depth approximately 9 m.
* Sheltered from current wind.
* Deep water: Magic Anchor required.
* Coast exposed to the current wind.
* No safe approach.
* Land or unsuitable water.

Distinguish measured/modelled bathymetry from game-estimated depth.
All depths are gameplay guidance only.
9. HOW ANCHORAGE WAYPOINTS MUST WORK
Preserve the I018 waypoint architecture.
The Captain should:

1. Open the working chart.
2. Zoom in on a coast.
3. Enable or see anchorage-suitability regions.
4. Plot a course.
5. Add or select a waypoint.
6. Drag the waypoint into an eligible anchorage area.
7. Mark it as an anchorage.
8. See whether it requires a normal or Magic Anchor.
9. Apply the course.
10. Arrive, stop and receive the existing manual anchor prompt.
11. Deploy the appropriate anchor manually.
12. Resume the remaining route after weighing anchor.

Selection rule
For normal anchoring, the waypoint must fall inside an eligible ordinary anchorage region.
For Magic Anchor use, additional eligible special-equipment regions may be selected.
A waypoint positioned outside a valid region must not silently become an anchorage.
The game should explain the reason and, if possible, suggest a nearby eligible location.
Zoom behaviour
The zoom requirement applies to the discovery and editing overlay, not to the saved anchorage's existence.
After an anchorage is planned, zooming out must not remove its waypoint or alter its navigation state.
The marker may simplify visually at broad zoom.
Save/load
Persist the anchorage designation, intended anchor mode where required, and route progress.
Do not let panning or changing zoom corrupt a planned route.
Preserve the I018 fix for wrapped world-route overlays.
10. NORMAL ANCHOR
The normal anchor remains a standard, useful and desirable part of the game.
It uses:

* Existing scope controls.
* Existing holding logic.
* Existing drag logic.
* Existing visuals.
* Existing manual deployment interaction.
* Existing boat state and persistence.

Refine depth and coastal eligibility through the new worldwide service.
Do not replace the entire anchoring system.
A normal anchor should work around suitable international shores, rather than only around Denmark.
If bathymetry is game-estimated, a normal anchorage can still be allowed when the game's conservative estimate and navigability checks support it.
11. THE MAGIC ANCHOR
Introduce a special piece of equipment called:
Magic Anchor
Optional longer equipment description:
Multi-purpose Deep Anchor
The Captain explicitly authorizes a playful, fictional anchoring solution.
Identity and description
Suggested in-game flavour text:
"For waters where the charts grow uncertain. A little engineering, a little seamanship, and a suspicious amount of nautical magic. Somehow it always finds a useful piece of seabed."
The equipment description should openly acknowledge that some depth values are translated from real-world data into game-code magic.
Don't pretend the device exists in real seamanship.
This is a whimsical fictional item, not actual emergency anchoring advice.
Function
The Magic Anchor can make an otherwise depth-ineligible location available, provided the location remains navigable and does not violate the game's fundamental safety rules.
It may handle:

* Greater-than-normal depth.
* Uncertain game-estimated depth.
* Suitable water near steep islands.
* Certain offshore emergency anchoring situations in accessible water.

The crucial offshore distinction
The Captain specifically imagines being able to use the Magic Anchor when a storm approaches even if nearby normal-depth anchoring is unavailable.
Do not require a Magic Anchor always to be within the ordinary coastal-distance limit.
Allow special emergency deep-water deployment in navigable open water, subject to clearly documented gameplay constraints.
This must not mean:

* Anchoring on land.
* Bypassing collision geometry.
* Instantly removing an incoming storm.
* Teleporting to a safe harbour.
* Guaranteed holding under every condition.
* Deploying an anchor during an impossible vessel state.

When deployed offshore, give clear feedback that it is holding position, not providing coastal shelter.
The Captain can still be exposed to the storm.
Effective depth abstraction
After a successful Magic Anchor deployment, the existing anchoring model may use a well-defined effective scope/holding-depth abstraction equivalent to a suitable anchoring depth.
Store actual or estimated local game depth separately.
Do not falsify the depth display just to make the existing anchor code accept it.
For example:

* Displayed game-estimated depth: 85 m.
* Special anchor: deployed.
* Effective holding model: normalized to a documented appropriate anchoring range.

This is explicitly fictional gameplay.
Keep the implementation deterministic and testable.
12. MAGIC ANCHOR SKILL CHECK
The Captain wants successful special deployment to require a meaningful skill check.
Reuse the principles of I018's circular fishing timing system, but do not mix fishing-catch state into anchoring.
Prefer a small reusable timing-control component with separate encounter rules.
Core interaction

* The player selects the Magic Anchor.
* The game shows the fictional deep-anchor deployment process.
* A needle rotates at readable constant speed.
* The player presses within a success arc.
* Successful checks advance deployment.
* Perfect hits provide a modest holding-quality benefit.
* Misses cost time and allow a retry.
* The Captain may cancel if conditions permit.
* After success, actual anchoring state is set through the existing anchor system.

Balance
A practical initial target:

* Calm/ordinary conditions: one success.
* Challenging conditions: two successes.
* Storm deployment: up to three successes.

Tune success windows and retries for fair gameplay.
Do not make the needle arbitrarily accelerate.
No random instant failures.
Missing a single timing window must not destroy the boat.
Repeated failed deployment can leave the boat unanchored and exposed, so the player must remain informed and in control.
Skill should matter without turning a cozy sailing game into a punishing reaction challenge.
Honest risk
Perfect deployment may improve initial holding quality modestly.
It does not guarantee safety against later extreme weather.
The existing drag/holding model remains authoritative.
I019 may later add more elaborate anchor-drag warning integration.
Do not implement I019's entire warning architecture now.
13. HOW THE MAGIC ANCHOR IS OBTAINED
The I020 economy and chandlery do not exist yet.
Do not implement a shop solely to sell this item.
For Revision 0.105b:

* Integrate the item with the existing equipment/ownership architecture where feasible.
* Make it available through a simple, documented prototype-access mechanism suitable for normal gameplay testing.
* Prefer an existing equipment interaction or a simple unlock available to the Captain.
* Ensure every vessel can use it.
* Make acquisition clearly explained.
* Preserve existing saves.
* Avoid money exploits or an invented temporary commerce backend.

The Captain must be able to test the new equipment immediately on Windows.
Document how to enable or select it.
Its permanent purchase price and progression role are deferred to I020.
The game must remain playable using only the standard anchor.
14. VISUAL PRESENTATION AND STATE INTEGRITY
Reuse the I018 anchoring visuals:

* Black daytime anchor ball.
* White night anchor light.
* Rode or chain.
* Anchor buoy.
* Appropriate underway lights when no longer anchored.

The Magic Anchor may have a distinctive but modest presentation, such as:

* A small brass mechanism.
* A brief glowing deployment flourish.
* A different anchor icon on the chart.
* A satisfying short deployment sound.

Do not build a huge effects system.
Do not show an ordinary shallow anchor rope stretching impossibly across the entire water surface to imply hundreds of metres of realistic rope.
Use a concise stylized representation.
Critical state transitions
Test:

* Normal anchor deployed.
* Magic Anchor deploying.
* Skill check failed.
* Skill check cancelled.
* Magic Anchor holding.
* Magic Anchor dragging.
* Anchor raised.
* Equipment changed while anchored.
* Return to moored harbour.
* Day/night changes.
* Long Passage stop.
* Save/load at each meaningful transition.

There must be one authoritative anchored state, regardless of equipment.
No duplicate holding model.
No duplicated alarm triggers.
No duplicate anchor prompt after loading.
14A. ENGINE-OFF ANCHORING AND DECORATIVE SOLAR PANELS
This section is an approved part of Revision 0.105b — Safe Harbours, Deep Waters & the Sprite Workshop.
It applies to all four vessels and both normal and Magic Anchor deployment.
A. Engine behaviour while anchored
The Captain wants a peaceful and believable anchoring experience.
When an anchor is successfully deployed and the vessel enters its anchored state, the engine must automatically stop.
Requirements:

1. Stop the running engine when either the ordinary anchor or Magic Anchor has successfully deployed.
2. Do not stop the engine merely because an anchorage waypoint was reached. Arriving, waiting and anchoring are distinct states.
3. While anchored, prevent ordinary helm, autopilot or Long Passage logic from automatically starting or applying engine propulsion.
4. If the player tries to start the engine while the anchor remains deployed, show a short friendly explanation: "Let's raise the anchor before starting the engine."
5. Once the anchor is raised, return normal engine controls to the Captain. Do not automatically start the engine.
6. Preserve normal departure, course-resumption and anchorage-waypoint behaviour.
7. Use the existing authoritative engine and anchor states. Do not create a second engine-running flag.
8. Ensure old saves containing an anchored vessel with its engine running are normalized safely on loading.
9. Preserve all existing engine-wear, speed and sailing calculations when underway.
10. No engine idling, fuel, exhaust or battery simulation is required.

This is an intentional cozy gameplay simplification, not a claim that real vessels can never run their engines while anchored.
Test the rule for both ordinary and Magic Anchor deployment, cancellation, failure, successful holding, dragging, weighing anchor and save/load.
B. Decorative solar panels
Add attractive, subtle solar panels to all four boats:

* Arctic Wanderer 26.
* Wing 33.
* Frogleap 36.
* Clam 40.

Solar panels are visual only.
Do not implement:

* Solar power generation.
* Batteries.
* Charging.
* Electrical consumption.
* Power budgets.
* Installation or maintenance costs.
* Solar efficiency or weather-dependent output.
* Equipment purchasing.
* Additional save fields solely for solar panels.

Placement and appearance
Inspect each boat's actual geometry and existing equipment.
Choose believable positions appropriate to the vessel, such as on an aft rail, a compact arch, a cabin roof or another sensible mounting location.
The smaller Arctic Wanderer should not receive an oversized installation intended for a forty-foot boat.
The panels should:

1. Match the game's warm, hand-illustrated visual style.
2. Have a recognizable dark blue/black cell pattern and a modest frame.
3. Be visible in the normal deck presentation.
4. Follow the boat's existing eight-direction presentation correctly.
5. Stay visually attached to the boat when it turns.
6. Respect the existing mast, boom, sails, companionway and deck equipment.
7. Avoid blocking the Captain, Snøvs, the helm or interaction highlights.
8. Avoid changing deck walkability, collisions or vessel physics.
9. Remain visible while sailing, moored and anchored.
10. Be lightweight enough not to affect deck rendering performance materially.

Use sensible reusable artwork or shared geometry where practical, with vessel-appropriate sizing and placement.
Sprite Workshop integration
Catalogue the panels in the new Sprite Workshop.
Give them stable IDs, expected replacement filenames, 2× source-art dimensions, complexity categories and hand-drawing priorities.
Where practical, make at least one solar-panel artwork replacement READY through the new resolver.
If panels require a procedural-renderer adapter, catalogue that honestly rather than claiming support that does not exist.
The Captain should eventually be able to draw replacement solar panels without modifying code.
Evidence and testing
Provide rendered screenshots showing solar panels aboard all four boats.
Include at least two different orientations and one anchored scene.
Add checks confirming:

* The engine is stopped whenever anchoring succeeds.
* Engine propulsion cannot resume while the anchor is deployed.
* Weighing anchor restores normal control without automatically starting the engine.
* Old anchored saves load safely.
* Solar panels remain attached to the boat through heading changes.
* Solar panels introduce no new power or equipment simulation.
* The panels do not obstruct the Captain or pet.

Add the corresponding requirements to the revision tracker, Windows acceptance checklist and Captain's Orders.
The deliverable is complete only when these behaviours work in the actual game, not merely in isolated demonstration scenes.
15. WORLDWIDE ANCHORING ACCEPTANCE SCENARIOS
Verify actual gameplay in representative areas:

1. Denmark / the Belts.
2. Mediterranean or Iberian coast.
3. Canary Islands or Madeira.
4. Caribbean.
5. French Polynesia.
6. New Zealand.

Where the source chart makes a particular bay inaccessible, use a nearby valid coast or island approach rather than inventing a navigable passage.
Cover:

* Ordinary shallow anchorage.
* Deep coastal anchorage requiring Magic Anchor.
* Game-estimated depth.
* Open-water emergency Magic Anchor use.
* Exposed water with no claimed shelter.
* Storm approach and deployment.
* Dragging or holding deterioration.
* Impossible land location rejected.
* Too-close coastline rejected.
* Date Line vicinity.
* Saved international anchorage route.
* Resuming the voyage after weighing anchor.

The game must not be limited to handpicked hard-coded demonstration points.
The worldwide system must work generically.
If only certain areas have more accurate depth data, record that honestly.
PART B — SPRITE WORKSHOP PHASE 1
16. MISSION OF THE SPRITE WORKSHOP
The Captain plans to create many replacement illustrations by hand over time.
The framework must make that practical.
The desired experience:

1. Open a clearly named artwork category.
2. Read its instructions.
3. Find the expected filename in its CSV manifest.
4. Draw the illustration at the documented size.
5. Save a transparent PNG under the expected filename.
6. Open the project in Godot.
7. Run the game.
8. See the replacement automatically where that sprite is used.

No editing of GDScript or scene resource paths for each replacement.
If the replacement is absent, the game must continue to use its existing graphics.
The Sprite Workshop is a usable system, not merely an inventory report.
17. FOLDER HIERARCHY
Create a stable artist-friendly root, preferably:
`art_replacements/`
Suggested main categories:

* `01_characters/`
* `02_pets/`
* `03_boats/`
* `04_cabins_and_interiors/`
* `05_sailing_equipment/`
* `06_fishing_equipment/`
* `07_fish_and_sea_creatures/`
* `08_harbours_and_towns/`
* `09_nature_and_environment/`
* `10_shared_props/`

Adjust and expand this structure based on the real code audit.
Examples of useful nested categories:

* Per-vessel folders for the four boats.
* Deck equipment and rigging.
* Cabin furniture and fittings.
* Fishing rods, reels, lines and tackle.
* Individual fish species.
* Shared docks and quays.
* Buildings and shore props.
* Lamps and decorative items.

Do not create thousands of meaningless empty folders.
Prefer folders organized around a coherent art-production task.
Every artwork folder containing replacement entries must include:

* `manifest.csv`
* `README.md`

The root must contain:

* `README_START_HERE.md`
* An overall index or generated catalogue.
* A clear summary of how many replacements are registered, replaceable and pending integration.

18. PER-FOLDER CSV MANIFESTS
Each `manifest.csv` must list the expected replacement filenames, whether or not those PNG files currently exist.
The CSV is both an art-production checklist and part of the replacement framework's authoritative data.
Minimum required fields:

* `asset_id`
* `filename`
* `display_name`
* `description`
* `category`
* `current_source`
* `display_width`
* `display_height`
* `source_width_2x`
* `source_height_2x`
* `complexity`
* `hand_draw_priority`
* `priority_rank`
* `view_direction`
* `view_count`
* `transparent_background`
* `pivot_or_origin`
* `replacement_mode`
* `integration_status`
* `notes`

Add fields if the actual game architecture genuinely requires them.
Stable identifiers
IDs must be unique and stable.
For example:
`equipment.anchor.normal`
`equipment.anchor.magic`
`fishing.rod.basic`
`pet.snovs.cabin`
`boat.arctic_wanderer_26.deck.north`
These examples are illustrative. Follow actual game resource names and existing IDs where appropriate.
Do not silently rename internal boat IDs.
Integration status
Every listed asset must have one of these honest statuses:

* `READY` — the replacement pathway is implemented and verified.
* `ADAPTER_REQUIRED` — catalogued, but a procedural or scene adapter is still required.
* `REFERENCE_ONLY` — included for art planning, not intended for direct PNG replacement in Phase 1.

Do not mark an entry READY merely because its PNG filename appears in a CSV.
Source of truth
Prefer a validated loader or generated central index derived from the per-folder CSV files.
Do not maintain several manually synchronized lists containing contradictory file paths.
Validate duplicate IDs and duplicate output paths.
Keep the manifest format readable and editable in ordinary text editors and spreadsheet software.
19. INSTRUCTIONS INSIDE EACH FOLDER
Every `README.md` should explain:

* What kind of artwork belongs in the folder.
* How to draw it.
* Which existing objects it replaces.
* Expected art style.
* 2× source-resolution convention.
* Required transparency.
* Allowed image formats.
* Orientation conventions.
* Anchor or pivot point.
* Any collision or interaction alignment that must not change.
* How to test a replacement.
* What happens if the PNG is missing.
* Which items still require adapters.

For complex assets, provide additional individual specifications if useful.
For all four boats, document directional-view requirements especially carefully.
Do not assume an eight-directional boat can be replaced by rotating one unsuitable flat illustration.
20. THE 2× ARTWORK STANDARD
The Captain wants source artwork created at approximately twice the intended on-screen resolution.
For example:

* 32 × 32 displayed → 64 × 64 source.
* 64 × 64 displayed → 128 × 128 source.
* 128 × 128 displayed → 256 × 256 source.
* 256 × 256 displayed → 512 × 512 source.

Preserve natural aspect ratios.
A long, thin fishing rod must not be forced into a square canvas.
A large furnished cabin may require a much larger source illustration than a hook or lantern.
Audit:

* Actual scene size.
* Camera zoom.
* UI-independent in-world display scale.
* Sprite transforms.
* Source texture dimensions.
* Existing directional-view arrangement.

Use the intended 1600 × 900 gameplay presentation as a useful reference.
Do not simply double every current PNG dimension without checking how the asset is displayed.
Avoid enormous canvases that waste VRAM without improving visible quality.
Document scaling and import settings so the 2× art is displayed at the expected game size.
21. ARTWORK COMPLEXITY CLASSIFICATION
Classify each unique illustration by production complexity.
C1 — Simple
Small item, simple silhouette, minimal detail.
Examples: hook, rope coil, cup, small buoy.
C2 — Moderate
Recognizable object with meaningful contours, material and detail.
Examples: fishing rod, anchor, lantern, small fish.
C3 — Detailed
Complex silhouette or several material/shape relationships.
Examples: pet, character, mechanical equipment, detailed fish.
C4 — Complex composition
Large cohesive artwork with many visual elements.
Examples: boat exterior, furnished cabin, substantial harbour structure.
Assign complexity based on actual artistic work, not merely image resolution.
22. HAND-DRAWING PRIORITY
Create an ordered, evidence-based hand-drawing priority list.
Rank subjects using:

* Visual prominence.
* Frequency of exposure.
* Emotional importance.
* Uniqueness to Little Captain's Hat.
* Reuse across boats and locations.
* Expected benefit from hand illustration.
* Production complexity.
* Required resolution.

Give every art subject or appropriate asset family a priority.
Additionally produce:
THE FIRST 25 ARTWORK SUBJECTS WORTH HAND-DRAWING
For each item state:

* What to draw.
* Where it appears.
* Why it matters.
* Complexity.
* Display size.
* 2× source size.
* Number of static views.
* Opportunities for reuse.
* Whether the replacement pathway is already READY.

Include a separate shortlist of quick artistic wins.
Do not invent a ranking solely from filenames.
Use actual gameplay and visual prominence as evidence.
23. INVENTORY COUNTS
Produce three counts.
A. Absolute reusable minimum
The smallest sensible number of distinct illustrated designs that covers the current game's in-world objects using legitimate reuse.
B. Practical illustrated set
A coherent, attractive set with distinctive artwork for major subjects, boats, cabins, characters, pets, equipment and fish.
C. Full distinct-object set
A separate illustration for each meaningfully distinct existing in-world object, excluding animation frames and bespoke illustrations for individual harbours.
For each scenario distinguish:

* Unique design subjects.
* Required separate static-view drawings.
* Complexity C1–C4 counts.
* Resolution-class counts.
* Estimated relative artwork workload.

Use a consistent relative workload scale, for example:

* C1 = 1 point.
* C2 = 3 points.
* C3 = 8 points.
* C4 = 20 points.

These are relative comparison points, not hours or costs.
Scope of inventory
Include existing in-world artwork concepts such as:

* All four boats.
* Boat exteriors and decks.
* Cabins and interior layouts.
* Furniture and fittings.
* Sailing equipment and instruments.
* Fishing rods and tackle.
* Fish and sea creatures.
* Captain and companions.
* Harbour infrastructure.
* Shared town/city objects.
* Buildings, shops and shoreline props.
* Environmental objects.
* Food, tools, lamps and other world props.

Exclude from the initial static in-world count:

* UI-only panels and controls.
* Animation frames.
* Fonts.
* Generic HUD decorations.
* Full-screen menus.
* Debug overlays.
* Procedural chart linework.
* Unique commissioned artwork for each individual harbour.

Shared harbour objects still count.
Do not confuse actual image-file count with the number of art concepts that need hand illustration.
24. ACTUAL REPLACEMENT LOADING
Implement the working resolver.
Conceptual API:
`get_artwork(asset_id, fallback)`
The precise architecture may differ if existing systems suggest something more appropriate.
Required behaviour

* Read or generate an indexed view of manifests.
* Resolve a stable ID to an expected replacement path.
* Detect whether an appropriate image exists.
* Load and cache a valid replacement.
* Otherwise return the existing artwork.
* Warn usefully about malformed or unsupported replacements.
* Never crash normal gameplay due to a missing optional PNG.
* Never scan every manifest or reload textures every frame.

Godot-specific considerations
The Captain uses:
GitHub branch → Download ZIP → Extract → Open project.godot in Godot → Run
Design and test for this workflow.
A replacement PNG added to the extracted Godot project should be imported and picked up reliably.
Avoid an implementation that only works after a specialized command-line build or undisclosed export process.
Understand the difference between:

* Godot resource imports.
* Existing `res://` project assets.
* Missing optional files.
* Editor-run behaviour.
* Exported build behaviour, if supported.

For this phase, the editor-run workflow is mandatory; an exported executable is not required.
Document whether a new PNG requires restarting the game or allowing Godot to finish importing it.
Live hot-reloading is not required.
25. SUPPORT DIFFERENT ARTWORK ARCHITECTURES
The game currently includes stored textures, scene objects and procedurally drawn graphics.
Do not promise that one generic PNG lookup can replace every procedural composition without adaptation.
Catalogue the actual renderer type for each asset.
Where a full composed image is required, document its bounds and origin.
Where a boat is composed from multiple meaningful layers, preserve the important interaction and geometry relationships.
Artwork replacement must not alter:

* The boat's actual physics.
* Walkable deck geometry.
* Helm or furniture interaction coordinates.
* Collision areas.
* Character safe zones.
* Snøvs's safe deck movement.
* World route and anchorage coordinates.
* Fishing species data.
* Save identifiers.

A picture may change, but game-state truth remains in the existing systems.
26. MANDATORY WORKING REPLACEMENT EXAMPLES
This is the central acceptance requirement for Sprite Workshop Phase 1.
Claude must implement and test at least three genuinely working replacement pathways, chosen from real game assets:

1. A small in-world object — preferably a lantern, anchor component or equipment prop.
2. A character or pet visual — preferably Snøvs, without breaking existing state or safe movement.
3. A larger or layered asset — preferably a boat/deck element, a cabin element or another meaningful composed object.

The examples must exercise different rendering architectures where practical.
Test sequence for every example

1. Verify the original artwork appears with no replacement PNG.
2. Add a valid replacement PNG under the manifest-specified filename.
3. Run the game and confirm the replacement actually appears.
4. Verify correct displayed dimensions and pivot.
5. Remove or disable the replacement.
6. Confirm the original artwork returns.
7. Try an invalid or incorrectly sized file.
8. Confirm useful validation and safe fallback.
9. Verify other boats, scenes and interactions remain functional.

Include screenshots of original and replacement appearances.
Provide the Captain with exact, simple instructions for reproducing the test after downloading the ZIP.
Do not leave test replacement art installed as permanent overrides unless it is explicitly intended and clearly documented.
Keep any example graphics in a separate test-fixture location or controlled demonstration folder.
27. ARTISTIC GUIDELINES
Preserve the established illustrated style:

* Warm muted colours.
* Hand-drawn feeling.
* Slightly imperfect ink lines.
* Readable top-down silhouettes.
* Marine teak and cozy interior atmosphere.
* Distinctive four-vessel identity.
* Friendly characters and pets.
* Legible fishing species.

The new system should support the Captain's own future artwork.
Do not automatically redraw all the game's existing art.
Do not overwrite existing original assets.
Do not treat generic placeholders as completed replacements.
The Sprite Workshop is a framework for gradual personalization, not a requirement to produce 1,000 new PNGs during this revision.
28. ART WORKSHOP REPORTS
Create:
`SPRITE_WORKSHOP_REPORT.md`
Include:

1. Current repository artwork audit.
2. Folder hierarchy.
3. Manifest schema.
4. Asset counts.
5. Complexity tables.
6. Resolution tables.
7. Unique designs versus directional drawings.
8. Top 25 hand-drawing priorities.
9. Recommended production batches.
10. Architecture of the replacement resolver.
11. Integrated categories and READY asset counts.
12. Categories still requiring adapters.
13. Exact three-example replacement tests.
14. How missing and invalid images fall back.
15. Import and runtime performance.
16. Current limitations.
17. What the Captain should draw first.

Also create a concise:
`art_replacements/README_START_HERE.md`
This should be understandable without reading the development report.
PART C — CROSS-SYSTEM QUALITY AND DELIVERY
29. SAVE COMPATIBILITY
Start from save format 12.
Prefer compatible optional fields.
Potential persistent additions include:

* Magic Anchor ownership or availability.
* Anchor type or deployment mode.
* Additional depth/source information only if persistence genuinely requires it.
* Existing anchor state as extended rather than duplicated.
* Selected anchorage type.
* Saved waypoint and voyage state.

Do not store large generated depth tables inside individual saves.
Do not save the entire suitability overlay.
Do not store custom image binaries inside saves.
Old 0.105a saves must load correctly.
If format 12 cannot safely represent the new state, increment the save schema properly and implement migration.
Test actual separate-process restarts.
30. PERFORMANCE AND MEMORY RULES
Worldwide anchorage overlays and the Sprite Workshop must be designed for bounded performance.
Anchorage

* Compute only visible local areas.
* Require useful close zoom.
* Cache depth and suitability results.
* Avoid full global processing on every pan.
* Do not evaluate storm/shelter geometry every rendered frame.
* Do not recompute expensive routes for every drag pixel.
* Avoid massive unbounded cache growth.

Sprites

* Load replacement textures only when relevant.
* Cache resolved resources.
* Avoid decoding every PNG on every game frame.
* Keep a practical texture-memory budget.
* Do not pre-load every possible 2× illustration at startup.
* Keep missing-file checks efficient.
* Avoid overly large textures for tiny props.

Record before/after measurements where possible.
Use the existing I018 software-rendered benchmarks as reference, without treating them as Windows GPU measurements.
Benchmark metadata discrepancy
The Captain's I018 delivery audit found that the two supplied after-build benchmark JSON files still reported version `0.104a`, although the I018 release was 0.105a.
Investigate this.
Explain whether it is:

* A stale metadata string.
* A benchmark harness initialization issue.
* A test environment/version capture issue.
* Or evidence of a more significant baseline inconsistency.

Correct the metadata generation if necessary.
Do not rewrite past benchmark measurements.
Retain provenance of which commit and version each benchmark actually tested.
31. COZY PLAYER EXPERIENCE
The Captain should not encounter an overwhelming technical interface.
Present:

* Meaningful anchorage highlights.
* Friendly short explanations.
* Clearly differentiated normal versus Magic Anchor areas.
* Understandable depth estimates.
* A charming special-anchor skill interaction.
* A clear arrival prompt.
* Sensible manual control.
* Small, inviting help tips.

Do not add walls of hydrographic terminology.
For artwork replacement, keep the tooling largely in the project folders and documentation, not in a giant in-game administration panel.
The game itself should remain a cozy sailing adventure.
32. AUTOMATED TEST REQUIREMENTS
Create focused tests.
Worldwide depth and suitability

* Real-data lookup where available.
* Deterministic fallback.
* Same location yields same result after restart.
* No discontinuous random depths.
* Correct land/water distinction.
* Nearshore locations accepted appropriately.
* Unsafe land positions rejected.
* Finer coastal handling than the global routing grid where needed.
* Shelter and depth assessed independently.
* Appropriate confidence/provenance labels.
* No fake surveyed precision.

Anchorage overlay

* Appears only at configured zoom.
* Hidden at world zoom.
* No global scan on every chart opening.
* Visible coastal regions only.
* Cache invalidation and reuse.
* Memory bounds.
* Correct after panning and world wrapping.
* Normal/Magic area distinction.
* Correct selection and drag behaviour.

Normal anchor

* Works in suitable international water.
* Existing scope/holding/drag preserved.
* Correct day/night signals.
* Safe save/load.
* Voyage resumes correctly.

Magic Anchor

* Available through documented equipment access.
* Deep-water eligibility.
* Offshore emergency eligibility.
* Land/inaccessible water still rejected.
* Skill-check success, miss, retry and cancel.
* Perfect influence appropriately bounded.
* Existing holding/drag model reused.
* No guaranteed shelter or weather immunity.
* No duplicate deployment rewards or states.
* Save/load while deployed.
* Equipment and anchor-type persistence.

Sprite Workshop

* Manifest CSV parsing.
* Duplicate IDs rejected.
* Invalid paths rejected.
* Missing artwork uses fallback.
* Valid PNG replaces existing art.
* Wrong dimensions warn/fallback appropriately.
* Import and scale correct.
* Cache works.
* No asset scan per frame.
* All three representative replacement paths verified.
* Restoring missing PNG restores original art.
* Existing Captain-owned art remains unchanged.

Existing regression

* Worldwide routes and Date Line wrapping.
* I018 world-route panning fix.
* Fishing 2.0.
* Fish art and animations.
* Catch preferences and trophies.
* Sail Trim.
* Long Passage.
* Pet deck movement.
* Lighting.
* Existing anchoring and harbour systems.
* Save/load and old-save compatibility.

33. RENDERED EVIDENCE
Provide actual screenshots and inspect them visually.
At minimum:

1. Global chart at far zoom: no anchorage overlay.
2. Zoomed coastal chart with normal anchorage regions.
3. Deep coastal zone with Magic Anchor eligibility.
4. Nearby invalid land area.
5. Depth tooltip with data source/confidence.
6. Game-estimated depth tooltip.
7. Anchorage waypoint placed inside a valid region.
8. Attempted invalid placement with reason.
9. International ordinary anchorage.
10. International Magic Anchor anchorage.
11. Offshore emergency deployment.
12. Magic Anchor timing dial.
13. Perfect deployment.
14. Failed deployment.
15. Successful special holding state.
16. Boat anchored at night.
17. Original small prop.
18. Replacement small prop.
19. Original character/pet.
20. Replacement character/pet.
21. Original larger/composed artwork.
22. Replacement larger/composed artwork.
23. Missing replacement fallback.
24. Incorrect replacement validation message.

Use the game's normal rendering scale.
Static screenshots do not establish a working interaction by themselves.
Support the visuals with tests or short sequence evidence.
34. TWO-PROCESS RESTART TESTS
Perform real separate-process save/load verification.
Scenario A — International normal anchor
Plan a course, select a suitable international anchorage, sail there, anchor normally, save, exit, restart and load.
Verify:

* Same position and course.
* Same anchor state.
* Same waypoint.
* Same depth-source semantics.
* No duplicate arrival prompt.
* Raise anchor and continue.

Scenario B — Magic Anchor
Obtain the equipment, select a deep or estimated-water location, deploy successfully, save, exit, restart and load.
Verify:

* Same ownership.
* Same anchor type.
* Same holding/drag state.
* No duplicate skill-check reward.
* Raise anchor correctly.

Scenario C — Artwork fallback
Test valid and missing replacements across fresh game launches.
This need not be a player-save field: the artwork resolver should use the same stable IDs regardless of saved gameplay data.
Verify that gameplay saves do not store or corrupt texture paths unnecessarily.
35. WINDOWS ACCEPTANCE CHECKLIST
Create:
`WINDOWS_ACCEPTANCE_0_105B.md`
Use numbered sections with lettered test codes and spaces for results and observations.
Include:

* Version and old saves.
* Normal anchoring in Denmark.
* Normal anchoring abroad.
* Magic Anchor acquisition.
* Coastal special anchoring.
* Offshore emergency anchoring.
* Skill-check feel.
* Failure/retry behaviour.
* Anchorage area overlays.
* Zoom and map panning.
* Safe versus unsafe locations.
* Storm and exposure behaviour.
* Long Passage arrival.
* Anchoring visuals.
* Snøvs aboard while anchored.
* Sprite Workshop folder readability.
* CSV instructions and dimensions.
* Replacing an actual simple prop.
* Replacing an actual character/pet.
* Replacing an actual composed object.
* Removing replacements and verifying fallback.
* Existing I018 fishing gameplay and fish appearance.
* Sail Trim.
* Save/load after restart.
* Performance and stability.
* Final acceptance verdict.

Each test must support:

* PASS.
* FAIL.
* PARTIAL.
* NOT TESTED.
* Written observations.

Do not mark Windows acceptance completed.
The Captain and Skipper will test this revision and the accumulated I018 features together.
36. SHIPYARD EFFICIENCY
I018 reported:

* 146 logged Godot runs.
* 114 minutes of total measured Godot runtime.
* Significant repeat testing during pet pathfinding development.
* Four costly software-rendered benchmark runs.
* Benefits from targeted tests and timeouts.
* An opportunity to use seeded fixtures and fast parse checks.

Continue the efficiency log.
Use:

* Focused suites during implementation.
* Seeded deterministic tests.
* Parse checks before expensive runs.
* Reasonable timeouts.
* Full costly routing regression at appropriate final checkpoints.
* Before/after benchmarks without needless repetition.
* Shared fixtures when practical.

Create a section:
Shipyard Efficiency — Where the Time Went
Report actual numbers.
Do not invent timings or omit required tests to make the build appear faster.
37. CHECKPOINTS
Use ordinary recoverable Git commits.
Suggested checkpoints:
A — Baseline and root cause

* Verify 0.105a.
* Commit assignment and requirement tracker.
* Investigate coarse-chart anchoring restriction.
* Define bathymetry and fallback architecture.

B — Worldwide depth and suitability

* Acquire/process appropriate data where practical.
* Implement deterministic depth estimates.
* Build safe coastal eligibility service.
* Verify international normal anchor spots.

C — Chart overlay

* Zoom-limited anchorage regions.
* Cached visible-area processing.
* Waypoint selection and validation.
* Wrapped-map tests.

D — Magic Anchor

* Equipment integration.
* Deep-water and emergency eligibility.
* Timing interaction.
* Holding-model integration.
* Persistence.

E — Sprite catalogue

* Audit actual artwork.
* Generate folder hierarchy.
* Create per-folder CSV and README.
* Establish IDs, sizes, complexity and priorities.

F — Replacement engine

* Resolver and caches.
* Simple prop replacement.
* Pet/character replacement.
* Composed-asset replacement.
* Fallback/invalid-file tests.

G — Integrated gameplay

* International voyage and anchorage.
* Storm and Magic Anchor.
* Return to sailing.
* Existing fishing/pet/lighting regression.
* Save/load.

H — Final verification and delivery

* Full regression.
* Rendered evidence.
* Two-process tests.
* Performance and efficiency.
* Documentation.
* Final commit and push.

The implementation order may change for technical dependencies, but neither principal deliverable may silently disappear.
38. REQUIREMENT TRACKER
Create:
`REVISION_0_105B_REQUIREMENTS.md`
Use stable IDs for:

* GEO — Geography/root cause.
* DEPTH — Bathymetry and game estimates.
* SHELTER — Coastal exposure.
* ZONE — Anchorage overlays and caching.
* WAYPOINT — Anchorage route integration.
* NANCH — Normal anchoring worldwide.
* MAGIC — Magic Anchor.
* SKILL — Special deployment challenge.
* SAVE — Persistence.
* ARTINV — Artwork inventory.
* ARTMAN — Per-folder CSV manifests.
* ARTRES — Artwork resolver.
* ARTTEST — Demonstrated replacements.
* PERF — Performance.
* QA — Automated and visual testing.
* DOC — Delivery documents.

For every requirement record:

* ID.
* Description.
* DONE / PARTIAL / TODO.
* Implementation location.
* Test evidence.
* Screenshot evidence where appropriate.
* Known limitation.
* Windows acceptance: PENDING.

Do not mark everything DONE solely because a class exists.
39. REQUIRED DELIVERY FILES
At minimum:

* `REVISION_0_105B_ASSIGNMENT.md`
* `REVISION_0_105B_REQUIREMENTS.md`
* `REVISION_0_105B_REPORT.md`
* `WINDOWS_ACCEPTANCE_0_105B.md`
* `SPRITE_WORKSHOP_REPORT.md`
* `art_replacements/README_START_HERE.md`
* Per-folder `manifest.csv`
* Per-folder `README.md`
* Appropriate source-attribution documentation.
* Reproducible preprocessing scripts, if real geographic data are used.
* Relevant screenshots.
* Before/after benchmarks.
* Updated `CAPTAINS_ORDERS.md`.

The main report must include:

1. Baseline version, save format and commit.
2. Final version and save-format decision.
3. Checkpoint commits.
4. Diagnosis of the international anchoring restriction.
5. Real-world depth sources actually used.
6. Where estimates replace source data.
7. International anchorage coverage.
8. Overlay design and cache architecture.
9. Magic Anchor mechanics.
10. Skill-check balance.
11. Existing holding/drag integration.
12. Save compatibility.
13. Sprite hierarchy and manifest schema.
14. Total catalogued illustrations.
15. Total READY replacements.
16. Total requiring adapters.
17. Complexity/resolution breakdown.
18. First 25 hand-drawing priorities.
19. Replacement demonstration results.
20. Performance measurements.
21. Automated regression results.
22. Rendered evidence.
23. Two-process restart results.
24. Shipyard Efficiency.
25. Known limitations.
26. Windows acceptance status.
27. Git push verification.

The report must clearly distinguish implemented and tested from planned or catalogued only.
40. CAPTAIN'S ORDERS
Update `CAPTAINS_ORDERS.md` with the following newly approved decisions:

1. Worldwide anchoring is a required gameplay capability.
2. The coarse global chart must not prohibit all international anchorages.
3. Real bathymetry is preferred where appropriate.
4. Game-estimated depths are permitted when transparent, deterministic and coherent.
5. The game does not claim navigation-grade depth accuracy.
6. Normal anchoring remains useful worldwide.
7. Anchorage suitability is separate from land avoidance.
8. Shelter/exposure is separate from depth.
9. Zoom-dependent chart highlights show eligible anchoring areas.
10. Overlay computation must be visible-area-only and cached.
11. Anchorage waypoints must use the existing navigation system.
12. The Magic Anchor is approved as fictional equipment.
13. The Magic Anchor can overcome excess or uncertain depth.
14. It can support appropriate deep/offshore emergency deployment.
15. It does not overcome land, impassable geography or weather exposure.
16. Magic Anchor deployment uses a fair skill check.
17. Successful special deployment uses the existing anchor holding model.
18. The Captain's existing anchor ball, light, rode and buoy remain.
19. Sprite Workshop Phase 1 is approved.
20. Every relevant artwork folder contains a CSV list of expected replacement files and written instructions.
21. Artwork targets 2× normal display resolution.
22. Inventory reports unique designs separately from static directional drawings.
23. Artwork is classified by complexity and expected resolution.
24. Assets are ranked by hand-drawing priority.
25. Valid installed replacement PNGs automatically override current artwork.
26. Missing or invalid replacements safely fall back to existing visuals.
27. The original Captain-owned artwork is preserved.
28. Full Windows acceptance will follow this revision.
29. I019–I021 remain independently scoped and are not cancelled.
30. Successfully anchoring automatically stops the engine; the engine remains off until the Captain raises the anchor and chooses to start it.
31. All four boats receive decorative solar panels. No electrical, battery, charging or power-management mechanics are authorized.

Preserve all previous authoritative Captain decisions.
41. DEFINITION OF DONE
This revision is ready for the Captain's Windows acceptance only when:
Worldwide anchoring

* International normal anchoring works in suitable navigable locations.
* World depth handling is documented and consistent.
* Game-estimated depths are labelled as estimates.
* No land-collision shortcut is used.
* The anchorage overlay appears at suitable close zoom.
* Zoomed-out charts avoid expensive overlay work.
* Normal and special anchorage regions are distinguishable.
* Waypoints can be placed only in eligible areas.
* The Captain can reach, stop, anchor and resume a world voyage.
* Magic Anchor equipment is accessible.
* The Magic Anchor skill challenge works.
* Deep-water emergency deployment works within its documented restrictions.
* Anchor holding and drag share the existing system.
* Storms remain meaningful.
* Save/load works.

Sprite Workshop

* Artist-friendly folders exist.
* Each relevant folder has a manifest CSV and instructions.
* IDs are stable and validated.
* 2× dimensions are documented.
* Complexity C1–C4 is documented.
* Hand-drawing priorities are ranked.
* Inventory totals are supplied without obvious double counting.
* The resolver is functional.
* At least three real replacement pathways work.
* No replacement means original artwork.
* Invalid replacements are handled safely.
* The Captain can perform a replacement without code changes.
* Original artwork remains intact.

Engineering

* Existing I018 gameplay is preserved.
* Route wrapping remains correct.
* Existing fish and pet systems remain functional.
* Full relevant regression passes.
* Rendered evidence reviewed.
* Real separate-process restart tests pass.
* No critical performance regression.
* Documentation is complete.
* Work is committed and pushed.
* Windows acceptance remains explicitly pending.
* Successfully anchoring automatically stops the engine, and engine propulsion stays disabled until the anchor is raised.
Decorative solar panels are visible and correctly positioned on all four vessels, without introducing a power system.

If any item cannot be completed, document it as PARTIAL with the technical reason and the remaining work.
Do not disguise partial implementation as completion.
42. FINAL GITHUB HANDOVER
Push only to:
https://github.com/crosenlund79/LittleCaptainsHat
Expected development branch:
`claude/friendly-fermat-dey23f`
Do not create a Windows executable.
The Captain's normal workflow remains:
GitHub → Branch → Code → Download ZIP → Extract → Open `project.godot` in Godot → Run.
Your final delivery message must:

1. State exact version and save format.
2. State final commit and checkpoint commits.
3. Report actual test results.
4. State what geographic depth sources were acquired.
5. Identify regions using game estimates.
6. State whether worldwide normal and Magic Anchor use works.
7. Give the Sprite Workshop location.
8. State how many assets are catalogued and how many are actually READY.
9. Give the exact steps to replace three demonstration sprites.
10. Link report and Windows acceptance documents by repository paths.
11. Describe performance and limitations.
12. State Windows acceptance is pending.
13. Confirm pushed branch HEAD.
14. End with the direct GitHub development-branch URL.

The last line must be the clickable direct branch URL:
https://github.com/crosenlund79/LittleCaptainsHat/tree/claude/friendly-fermat-dey23f
FINAL CAPTAIN'S ORDERS
Monsieur Claude,
The Captain now has an entire world to sail, and the game must allow that world to become a place to rest.
Do not make Denmark the only corner of the ocean where an anchor can touch the bottom.
Find useful depth information where the world has provided it.
Where the information runs out, let the game offer a sensible, clearly labelled estimate.
Show inviting anchorage areas on the chart when the Captain zooms in close enough to explore.
Let an ordinary anchor hold in a suitable cove.
And when the seabed falls away into extraordinary depths, give the Captain a wonderfully improbable Magic Anchor.
Let it descend with a satisfying clunk.
Let the Captain perform a little feat of seamanship to deploy it.
Let it hold the boat without claiming to stop the wind or calm the sea.
At the same time, prepare a workshop for the Captain's future illustrations.
Give every artwork a place.
Give every folder a clear list.
Give every drawing an expected size and purpose.
And when the Captain paints one beautiful little lantern, let that lantern appear aboard without touching a single line of code.
Preserve the four boats.
Preserve the fish.
Preserve Snøvs.
Preserve the world.
Keep the game charming, reliable and welcoming.
COZY FIRST.
Small boat. Wide world. Hold onto your hat.
Proceed with Revision 0.105b from the verified I018 baseline.
REMEMBER: End the final delivery message with the exact GitHub development-branch URL.
