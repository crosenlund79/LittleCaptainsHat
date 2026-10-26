# LITTLE CAPTAIN'S HAT — ITERATION 17 — LET THERE BE LIGHT

The Dreamer's Map, Cozy Lighting, Living Weather and a Better Sailing Experience

FULL AND FINAL CONSOLIDATED ASSIGNMENT (saved verbatim from the Captain's commissioning message)

Authorized repository: https://github.com/crosenlund79/LittleCaptainsHat
Expected development branch: `claude/friendly-fermat-dey23f`
Starting baseline: Iteration 16 — The World Awaits; game version 0.103a; save format 12
New version: Determine according to the project's existing version policy.
Core design principle: COZY FIRST.
Tagline: Small boat. Wide world. Hold onto your hat.

## 0. CRITICAL HANDOVER INSTRUCTIONS

This is the complete, authoritative commissioning prompt for Iteration 17.
It replaces all earlier I017 assignments, partial prompts, addenda and revisions.
There is no missing base assignment.
There are no further instructions from the Captain that you need to retrieve before beginning.
The Captain confirms:

* I016 has been delivered.
* I017 implementation has not started.
* This document contains the full revised scope.
* You are authorized to implement I017 directly from this document.
* You should not wait for another base prompt.
* You should not select an amendment-only interpretation.
* You should not assume the two earlier chart screenshots are attached.

The chart defects and visual references are described in this assignment. If the screenshots are available in your environment, use them as supporting evidence, but do not stop because they are missing.
Do not ask the Captain to choose among competing versions of I017.
This document is the scope decision.
Before implementation, save its complete contents in the repository as: `ITERATION_17_ASSIGNMENT.md`
Create a requirement-tracking checklist linked to the sections of this document.
Read the assignment from the repository when resuming after a session interruption or context compaction.
Do not assume details from earlier ChatGPT conversations are available to you.

## 1. CAPTAIN'S INTENT

The Captain has spent considerable time testing and designing Little Captain's Hat.
I016 gave the game a worldwide sailing environment.
The next step is to make that world feel beautiful, comfortable and genuinely pleasant to inhabit.
The Captain also identified two significant I016 Windows issues:

1. Severe world-chart graphics discontinuities when panning around Australia and across the Pacific.
2. Very poor performance associated with wind visualization on broad chart views.

These must be corrected.
However, the Captain subsequently proposed a more coherent navigation architecture:
The world map is where the Captain dreams.
The navigation station is where the Captain plans.
The cockpit chartplotter is where the Captain sails.
That concept is now approved for I017.
In addition, the Captain considers meaningful lighting absolutely essential to the game's cozy identity.
The boat currently feels too visually static.
I017 must therefore combine:

* Essential chart and sailing correctness.
* Efficient weather and wind handling.
* Three distinct navigation experiences over shared data.
* Time-of-day lighting and visual depth.
* Warm cabin lighting.
* Storm visuals and environmental audio.
* Better cockpit information and controls.
* Save/load reliability.
* Harbour and presentation improvements.

This is a major iteration.
Build the complete experience without sacrificing coherence, reliability or performance.

## 2. REPOSITORY SAFETY AND BASELINE VERIFICATION

Work only in: https://github.com/crosenlund79/LittleCaptainsHat
Expected branch: `claude/friendly-fermat-dey23f`
Before editing any gameplay code, verify and report:

1. Absolute working directory.
2. `git remote -v`.
3. Current branch.
4. HEAD commit.
5. Working-tree status.
6. Actual game version.
7. Save format.
8. Presence of `ITERATION_16_REPORT.md`.
9. Presence of `CAPTAINS_ORDERS.md`.
10. Existing navigation architecture.
11. Existing wind/weather architecture.
12. Existing chart rendering code.
13. Existing boat orientation implementation.
14. Existing cabin, deck and harbour scenes.
15. Existing audio, lighting and save/load infrastructure.
16. Existing regression, screenshot and benchmark tools.

I016 reportedly delivered:

* Version 0.103a.
* Save format 12.
* Worldwide chart and routing.
* 36 new international harbours.
* Three geographic detail levels: world, Europe and Denmark.
* International wind and weather.
* Long Passage mode.
* Extended passage provisions.
* Existing save compatibility.

Verify those claims from the repository.
The reported final I016 delivery commit was `01f01cc`, but use the actual verified current branch state rather than assuming that hash remains HEAD.
I015 was skipped with the Captain's authorization. Do not claim it was completed or renumber I017.
Do not:

* Work in the archived Next Harbor repository.
* Change unrelated repositories.
* Discard Captain-owned artwork.
* Force-push.
* Destructively reset.
* Rewrite history.
* Delete valid existing saves.
* Open a pull request unless requested.

Use normal recoverable checkpoint commits.

## 3. IMPLEMENTATION STRATEGY

Prioritize correctness, visual atmosphere and performance.

Priority 0 — Existing defects and data integrity

* Fix the Australia/Pacific world-chart rendering discontinuities.
* Investigate and resolve the wind visualization performance problem.
* Verify that sailing weather is evaluated locally or on demand where appropriate.
* Fix the vessel failing to visually turn while the Captain stands on deck.
* Ensure saving and loading underway keeps the Captain safely aboard.
* Preserve coherent deterministic weather through save/load.
* Add safe quicksave and quickload.

Priority 1 — The defining I017 experience

* Implement the three navigation interfaces.
* Implement proper day/night lighting.
* Add warm, atmospheric cabin illumination.
* Add practical deck and cockpit lighting.
* Add soft shading and visual depth.
* Add harbour lighting.
* Add wind, waves, rain, lightning and thunder.
* Make weather sound different inside and outside.

Priority 2 — Navigation and usability

* Add the larger right-side sailing information panel.
* Add the simplified cockpit chartplotter.
* Add the context-aware action wheel.
* Display its shortcut in the bottom help panel.
* Show visual course-change notifications.
* Add the optimized wind snapshot/time-preview controls.

Priority 3 — Supporting polish

* Fix player rendering relative to sails and rigging.
* Investigate the white objects/fenders on the boat.
* Show harbour facilities on chart selection.
* Organize visited harbours by country.
* Add a short docking arrival presentation.

These priorities govern the order of implementation.
They do not grant permission to silently omit lower-priority requirements.
If a technical conflict arises, preserve working gameplay and report the issue accurately.

## 4. THE NEW NAVIGATION ARCHITECTURE

Implement three navigation experiences:

1. Cabin World Map — Dreaming
2. Navigation Station — Planning
3. Cockpit Chartplotter — Sailing

All three must reuse:

* One authoritative geographic data system.
* One worldwide route planner.
* One harbour catalogue.
* One vessel position.
* One voyage state.
* One wind/weather model.
* One save/load system.

Do not create independent navigation simulations.
Separate the presentation and interaction layers, not the underlying truth.

Important architectural rule: Restrict what a chart renders, not how far the Captain can sail.
The Captain must still be able to plan and sail from Copenhagen to Papeete, across the Atlantic and Pacific, and through the existing abstract Panama passage.
The new interface architecture must not undo I016.

## 5. CABIN WORLD MAP — THE DREAMER'S MAP

Introduce a framed world map hanging inside the boat's cabin.
It should feel like an actual object in the Captain's home.
The player approaches and interacts with the map using the established contextual interaction system.
Do not add a giant visible interaction circle.
The world map opens an exploratory map interface.

### 5A. Visual design

Make it:

* Attractive.
* Illustrated.
* Nautical.
* Readable.
* Consistent with the game's existing art.
* Calm and uncluttered.

It should resemble a chart or world map that belongs aboard a cruising sailboat.
Do not make it look like a technical debug map or a modern satellite-navigation application.

### 5B. Required functionality

* View the entire world.
* Pan east and west.
* Zoom into continents and regions.
* Display major geographic names.
* Reveal harbours at suitable zoom levels.
* Search for harbours if the existing interface supports it.
* Select a harbour.
* Read its name, country and description.
* See whether it has been visited.
* Inspect useful destination information.
* Return to the cabin.

### 5C. Performance restriction

The cabin world map must not run the expensive operational wind overlay.
It must have:

* No live wind arrows.
* No animated weather fields.
* No storm-particle overlays.
* No continually updating forecast.
* No expensive per-frame global weather sampling.

The base map should be static or effectively cached between meaningful user changes.
Dynamic information such as visited-harbour markers may update when necessary.
Use the existing I016 geographic assets and rendering logic wherever possible.
Do not build a completely separate world renderer unnecessarily.

### 5D. Worldwide exploration must remain correct

The world map must support repeated panning across the Date Line.
No missing continents.
No rectangular rendering blocks.
No incorrectly repeated land.
No seams that become visible after panning west or east.
The Australia/Pacific defect described later in this assignment must be fixed here.

## 6. THE CAPTAIN'S VOYAGE DAYDREAMS

This is a small but important cozy feature.
When selecting a distant harbour on the cabin world map, allow the Captain to imagine the journey.
Use a button or interaction such as: Imagine this voyage
The game should calculate an actual route behind the scenes using I016's existing worldwide router.
Then present a short internal monologue.

Example: "Panama City... quite a distance from here. I could make my way toward the Canary Islands, then stop somewhere in the Caribbean. Perhaps one day..."
This is a narrative example, not an instruction to hardcode those stops for every voyage.

Actual information required. The reflection should use:

* Current vessel position.
* Selected harbour.
* Approximate route distance.
* Two or three geographically meaningful intermediate locations when available.
* Appropriate route context.

Mention actual existing harbours or locations associated with the route.
Do not invent harbour names.
Do not use an unrelated destination simply because it appears in a template.

Vary the tone modestly. A small selection of authored templates is sufficient.
The Captain may sound: Curious. Hopeful. A little cautious. Excited. Thoughtful.
Do not create a large procedural storytelling engine.
No online generative AI dependency.

Equipment and knowledge. The Captain likes reflections such as: "Perhaps one day, when I've got the experience and equipment."
But do not assert specific missing qualifications or equipment unless they correspond to actual game mechanics.
Passage Readiness may inform a gentle comment.
It must remain advisory.
Do not lock distant destinations behind imaginary experience requirements.

Route computation. Calculate the route when requested.
Reuse existing routing.
Cache the result where appropriate.
Do not recompute an entire worldwide route every frame while the map is open.

Fewer or no useful stops. Handle these cases naturally.
Do not invent locations to force exactly three names.

Existing voyage safety. Imagining a voyage must not:

* Change the active route.
* Move the vessel.
* Spend money.
* Consume provisions.
* Advance time.
* Trigger encounters.

If offering a future-destination bookmark is straightforward, it may be implemented, but do not build an extensive wishlist or quest system.

## 7. NAVIGATION STATION — THE WORKING CHART

Separate the operational navigation station from the exploratory world map.
The working chart should focus on the region relevant to active sailing.

### 7A. Coverage

Evaluate a practical initial display window on the order of 300–500 nautical miles across.
This is an initial design target, not a fixed gameplay limitation.
Choose a sensible final display behaviour after inspecting:

* Typical Danish voyages.
* Regional coastal sailing.
* Offshore passages.
* Existing waypoint spacing.
* Rendering performance.
* Map readability.

Account for geographic projection and latitude.
Avoid using a naïve fixed longitude rectangle that behaves badly at different latitudes.

### 7B. Required information

The navigation station should show:

* Current boat position.
* Relevant coastline.
* Nearby harbours.
* Active route segment.
* Route waypoints.
* Next waypoint.
* Current heading.
* Useful distance and course information.
* Relevant regional weather.
* Wind visualization where useful and performant.

### 7C. Route planning

Continue to permit global destinations.
Selecting a destination beyond the current chart window must still work through the global route planner.
The regional chart may inspect:

* The current leg.
* Subsequent legs.
* Selected route sections.

It should not require the full route to be drawn across the entire planet simultaneously.

### 7D. Access to distant voyages

The Captain can discover destinations through the cabin world map and use the operational chart to plan or follow the practical route.
Provide a clear connection between those experiences without losing existing route functionality.

### 7E. Correct navigation state

There must be no conflict between:

* The route shown at the navigation station.
* The route followed by the vessel.
* The route shown on the cockpit chartplotter.
* The route described by Passage Readiness.

All are views of the same route.

## 8. COCKPIT CHARTPLOTTER — THE SAILING CHART

Implement the simplified chartplotter planned for I017.
It should be accessible while the Captain is outside at the helm.
Integrate it with the right-side sailing panel.
Required:

* Boat position.
* Boat heading.
* Nearby coastline.
* Active route.
* Next waypoint.
* Distance to next waypoint.
* Planned course.
* Relevant local wind information.

It must be lightweight.
Do not initialize or render the entire world chart merely to display a local cockpit view.
Use bounded geographic data and caches.
Toggle: The Captain should be able to open and close it from the context-aware action wheel.
Retain sensible keyboard access where appropriate.
Do not require the player to rely solely on the `M` key.

## 9. I016 WINDOWS REGRESSION — BROKEN WORLD RENDERING

This is a confirmed player-reported visual problem.
The Captain panned the worldwide map left/west toward Australia and the Pacific.
The rendered chart developed large rectangular discontinuities.

Screenshot description. The supplied Windows screenshot showed:

* A whole-world Mercator-style map.
* Large vertical bands in which land geometry appeared shifted or clipped.
* Australia, Asia and surrounding Pacific land presented inconsistently.
* Rectangular boundaries inconsistent with natural coastlines.
* An ordinary interactive chart and destination panel still visible.

The rendering failure appeared after substantial horizontal panning.
This was observed in I016, version 0.103a.
The screenshot is supporting visual evidence, not proof of a specific root cause.

Required investigation. Inspect:

* Longitude normalization.
* Date Line wrapping.
* Map tile coordinate origins.
* Cached geometry transforms.
* Repeated-world copies.
* Tile visibility logic.
* Viewport clipping.
* Mercator/world-to-screen conversions.
* Land-layer offsets.
* Zoom-dependent coordinate changes.
* Cache invalidation on pan and zoom.
* Differences between world, Europe and Denmark map layers.

The bug may be in rendering rather than geographic data.
Do not rebuild geographic data without evidence it is necessary.

Required fix. World land must remain coherent while:

1. Panning toward Australia from either direction.
2. Crossing the Pacific and Date Line.
3. Panning beyond one full world width if supported.
4. Panning back.
5. Zooming around Australia and New Zealand.
6. Switching between world and regional map scales.
7. Reopening the map.
8. Selecting destinations after extensive panning.

No rectangular missing-land regions or incorrectly shifted continents.
The world map may normalize camera position to keep coordinates bounded, provided the interaction remains seamless.

Verification. Capture rendered evidence around the affected regions.
Run actual visual panning scenarios.
Do not conclude the rendering bug is fixed merely because routing tests pass.
Preserve worldwide routing and Date Line correctness.

## 10. I016 WINDOWS REGRESSION — WIND PERFORMANCE

The Captain reports that wind visualization at broad world-chart zoom levels severely degrades performance.
A second Windows screenshot shows the chart covering Denmark, southern Norway, southern Sweden and parts of northern Europe.
The Captain considers this approximately the kind of geographic scale at which wind information begins to become useful.
However: Do not treat that screenshot as a mandatory hardcoded zoom cutoff.
The Captain wants the wind implementation profiled and optimized before deciding the final visibility thresholds.

Required sequence:

1. Measure.
2. Identify where time is spent.
3. Separate simulation work from visualization work.
4. Optimize unnecessary calculations.
5. Establish adaptive wind detail.
6. Measure again.
7. Choose useful zoom limits.
8. Implement wind time-preview controls.

Do not simply hide the problem without investigating it.

## 11. SEPARATE WIND SIMULATION FROM WIND DISPLAY

Create or verify a clean separation between:

A. Authoritative sailing weather — The actual wind and weather affecting the vessel.
B. Forecast and route sampling — Weather information requested for an upcoming route section.
C. Chart visualization — Samples needed to draw wind information in a specific chart viewport.

These systems may reuse common functions and data.
They must not all perform the same expensive work independently.
Critical rule: Closing the chart must stop chart-specific wind processing, not the actual sailing-weather simulation.
The vessel must continue experiencing correct wind anywhere in the world.
Do not disable weather outside the active map.

## 12. LOCAL AND ON-DEMAND WEATHER CALCULATION

The Captain asks: "Why calculate the entire world's wind while sailing near Denmark?"
That is the right question.
I016's report describes deterministic global wind based on location, game time and seed, and weather optimizations using spatial bounding boxes.
Audit the current code carefully.

If simulation sampling is already local: Preserve it. Document how it works. Do not claim to have optimized a system that was already efficient.

If unnecessary global work exists: Remove or reduce it. Use:

* Local sampling.
* Relevant nearby event queries.
* Spatial indexing.
* Bounded area selection.
* Lazy evaluation.
* Caching where appropriate.

Preserve:

* Weather determinism.
* Sailing physics.
* Wind continuity.
* Region transitions.
* Date Line continuity.
* Storm likelihood and timing.
* Save/load integrity.
* Long Passage equivalence.

Weather elsewhere in the world must remain reproducible when the Captain eventually reaches it.
Avoid a design where distant weather only comes into existence when the player approaches it.

Long passages: During accelerated sailing, evaluate conditions along the actual travelled path.
Do not sample only the departure region for an entire ocean crossing.
Use bounded simulation steps or another accurate method consistent with I016.

## 13. EFFICIENT CHART WIND OVERLAY

Treat wind visualization as a deliberately sampled, cached visual layer.

When to calculate. Recalculate or refresh when:

* The user enables wind display.
* The visible geographic area changes materially.
* The selected forecast time changes.
* The zoom requires a different sampling resolution.
* A Now snapshot becomes meaningfully stale.

When not to calculate:
Do not rebuild the overlay every rendered frame.
Do not regenerate all visible samples for tiny camera movements if cached samples remain valid.
Do not update a world-sized invisible wind layer when the user is viewing a limited region.
Do not keep chart-specific wind rendering active after the chart closes.

Cache strategy. Implement appropriate:

* Spatial caching.
* Time-bucket caching.
* Zoom/sampling-level caching.
* Bounded memory usage.
* Invalidation rules.
* Reuse across modest pan movements.

The exact architecture should follow existing code patterns.
Avoid overengineering a general-purpose global weather database.

Drawing performance. Inspect:

* Draw calls.
* Arrow and line counts.
* Sample density.
* Canvas item counts.
* Geometry rebuilds.
* Clip visibility.
* Work performed while stationary.

Use lightweight drawing and bounded sample counts.

## 14. ADAPTIVE WIND DETAIL BY ZOOM

The Captain does not require detailed wind arrows on a full-world chart.
They become more useful at regional scale.
After optimization, choose appropriate behaviour.

At broad world zoom: Prefer no detailed wind overlay. If a very sparse, cached regional visualization is genuinely useful and inexpensive, evaluate it. Do not force the world map to draw dense wind fields. Remember that the cabin world map never displays wind.

At continental zoom: Use highly restricted density or hide detailed wind entirely if performance or readability suffers.

At regional zoom: Display understandable wind direction and strength. The Denmark/southern-Norway screenshot is a useful visual reference for this scale.

At coastal zoom: A denser local display may be useful, but must remain bounded.

Thresholds: Choose thresholds based on actual profiling and visible usefulness. Use hysteresis if appropriate.
If the player zooms out beyond useful wind detail, show a subtle notice: "Zoom in to see wind details."
Do not let the wind checkbox mislead the player into thinking actual wind has disappeared.

## 15. WIND SNAPSHOTS AND SHORT-TERM FORECAST PREVIEW

The Captain approves a read-only wind time navigator.
This replaces continuous live visualization with an inspectable snapshot approach where appropriate.

Initial controls:

* Previous.
* Next.
* Now.
* Selected time.
* Forecast indicator.

Use 30-minute steps initially.
Allow approximately:

* Two hours backward.
* Current time.
* Two hours forward.

Evaluate whether these increments make sense with the existing weather time resolution.
Do not add arbitrary 10-minute steps unless measurements or gameplay show a real benefit.

Labels. For current time: NOW. For earlier time: PAST MODEL SNAPSHOT. For future time: FORECAST.

Forecast uncertainty. Show a brief warning such as: "Estimated conditions. Actual wind may differ."
I016's weather is deterministic, but a read-only preview should still be framed as a game forecast rather than promising exact future conditions.
Do not artificially introduce random inaccuracy merely to make the warning true.

No simulation side effects. Forecast preview must never:

* Move the boat.
* Advance game time.
* Consume provisions.
* Spend money.
* Cause boat wear.
* Trigger events.
* Modify weather.
* Change random seeds.
* Grant rewards.

It should only inspect modelled conditions.

Performance. Cache snapshot samples.
Avoid evaluating intermediate timestamps while moving between steps.
During accelerated game time, do not rebuild hundreds of intermediate snapshots.
Clearly update the Now label if the authoritative clock changes.
A sensible default is to return to Now when reopening the chart.
No save-format change should be needed solely for this UI state.

## 16. LIGHTING IS A MAJOR FEATURE, NOT AN EXTRA

The Captain has explicitly elevated lighting to a defining requirement.
The current boat appears flat and static.
I017 must make it feel warmer, deeper and more alive.
Do not reduce the lighting work to a single full-screen dark tint.
Choose a maintainable Godot 2D lighting strategy suited to the existing renderer and art.
This may combine:

* CanvasModulate.
* Light2D.
* PointLight2D.
* DirectionalLight2D.
* Appropriate occluders.
* Baked or authored shading.
* Custom lightweight shader treatment.
* Layered illumination and shadows.

Those are possible techniques, not mandatory implementation choices.
Evaluate the current renderer and project settings first.
Use the least complex approach that produces convincing results.
Do not rewrite the rendering engine.

## 17. PROPER DAY/NIGHT CYCLE

Tie all lighting transitions to the authoritative game clock.
Implement recognizable:

1. Dawn.
2. Daylight.
3. Dusk.
4. Night.

Requirements:

* Smooth transitions.
* Meaningful ambient colour changes.
* Gradual changes in brightness.
* No abrupt dark/light jumps.
* Appropriate boat and water presentation.
* Correct behaviour during Long Passage acceleration.
* Correct behaviour after sleeping.
* Correct behaviour after loading.
* Correct behaviour in harbours.

Worldwide time. I016 is a worldwide game.
Account sensibly for the boat's geographic longitude and the game's time basis.
A simple, documented local-solar-time approximation is acceptable.
Do not implement a full astronomical, moon-phase or worldwide timezone system unless already available and inexpensive.
The sun should not behave obviously inconsistently when sailing across the Pacific.

## 18. WARM CABIN LIGHTING

The cabin must feel welcoming, especially during evening and bad weather.

Lighting sources. Use appropriate light associated with existing fixtures:

* Saloon lighting.
* Galley light.
* Chart-table illumination.
* Relevant warm cabin lamps.

Visual goals:

* Warm light pools.
* Gentle falloff.
* Slightly darker corners.
* Depth and contrast.
* Readable character and companions.
* Inviting berth and table areas.
* Subtle daylight from windows or hatches.

Do not cover the entire cabin in uniform yellow.
Do not create very dark areas that make ordinary interactions frustrating.

All four boats. Support:

* Arctic Wanderer 26.
* Wing 33.
* Clam 40.
* Frogleap 36.

Adapt to their actual cabin layouts.

Future compatibility. I020 will introduce cabin personalization.
Design lighting fixtures and overlays so changing upholstery, furniture finishes or equipment does not require rewriting the lighting system.
Do not implement full customization in I017.

## 19. DECK AND COCKPIT LIGHTING

At night:

* Outdoor light should be weaker and cooler than interior cabin light.
* The boat should remain navigable.
* The helm should be discoverable.
* Existing interaction highlights must be visible.
* Instruments should be readable.
* Cabin illumination may spill softly toward nearby deck areas.

Use restraint.
Avoid lighting the entire sea like a football stadium.
The cockpit chartplotter should remain comfortable to read in darkness.
Consider day/night UI contrast without introducing a complicated global theme system.

## 20. HARBOUR LIGHTING

Harbours should feel inhabited after dark.
Add restrained effects such as:

* Dock lights.
* Warm windows.
* Light pools.
* Soft illuminated walkways.
* Subtle reflections if affordable.

Use reusable patterns.
Do not author custom lighting scenes for all 223 harbours individually.
The shared international harbour scenes should still benefit.
Maintain performance and path readability.

## 21. SOFT SHADOWS AND VISUAL DEPTH

The Captain wants the boat to stop feeling completely flat.
Introduce subtle depth treatment around relevant elements.
Possible areas:

* Cabin fixtures.
* Furniture.
* Settees.
* Deck hardware.
* Helm.
* Railings.
* Character contact with deck.
* Sail and rigging overlap.

Do not implement expensive physically accurate shadows everywhere.
Focus on believable illustrated depth.
Acceptance: A before-and-after rendered comparison should show a meaningful improvement at normal gameplay scale.
The treatment must not destroy the existing artwork's character.

## 22. WIND, WAVES AND RAIN AUDIO

Implement weather-responsive environmental sound.
Wind: Wind sound should respond to actual conditions. Light wind is gentle. Strong wind is more forceful. Avoid a single loud looping sound that becomes unpleasant on long passages.
Water: Use appropriate hull/wave/water ambience. Change it modestly with sea conditions and movement.
Rain: Rain must be perceptible during rainy weather. Use appropriate variation and mixing.
Asset policy: Use legitimate redistributable sound sources or original/generated assets. Record licensing and provenance. All runtime sounds must be local project assets. Do not require network audio services.

## 23. LIGHTNING AND THUNDER

When the boat sails into a thunderstorm:

* Show lightning.
* Play thunder.
* Make the effects clearly related to the weather.
* Allow distant and closer thunder variations.
* Make the world briefly brighten from lightning.
* Show a suitable light response inside the cabin.

The cabin should feel protected, not disconnected from the storm.
Lightning quality: Avoid aggressive full-screen white strobes. Use a short, believable flash pattern. Provide a reduced-flash or equivalent accessibility option if appropriate.
Thunder timing: Prefer a reasonable relationship between visual lightning and audible thunder. It does not need to be scientifically sophisticated.
Performance: Do not create dozens of expensive overlapping lights merely to simulate one thunderstorm. Reuse effects where possible.

## 24. CABIN VERSUS DECK ACOUSTICS

Environmental audio should respond to player location.
Outside: Clear wind. Direct rainfall. Stronger wave ambience. Unmuffled thunder.
Inside: Muffled wind. Muted rain striking deck and hull. Low-frequency thunder. Softer water ambience. Comfortable interior soundscape.
Use smooth transitions where practical.
Future safety-alarm compatibility: I019 will introduce the Captain's Watch audio alarms and spoken warnings.
Design the audio buses and mixing so these later sounds can remain clear inside and outside.
Do not implement collision encounters or the full alarm system now.

## 25. VISUAL WIND WHILE SAILING

Provide subtle visual cues for wind while the Captain is aboard.
Examples:

* Wind streaks.
* Sail movement.
* Streamer or small indicator.
* Water ripples.
* Light atmospheric particles.

The cues must agree with actual wind direction and strength.
This visual effect is separate from the chart wind overlay.
Do not compute an entire visible world wind grid to animate a handful of boat-local effects.
Keep effects tasteful and performant.

## 26. FIX VISUAL BOAT ORIENTATION

The Captain explicitly verified a defect:
When the boat changes course, the boat may not visually change direction while the player is outside.
Fix it.
The boat should visually follow its actual heading.
Preserve the established eight-direction visual system.
Preserve full-precision underlying sailing calculations.

Required scenarios:

* Manual course change.
* Autopilot turn.
* Course change while standing on deck.
* Course change near the bow.
* Course change near the stern.
* Cabin/deck transitions.
* Save/load.
* Multiple turns in succession.

Ensure:

* Player remains aboard.
* Fixtures remain correctly positioned.
* Deck movement remains intuitive.
* Camera stays coherent.
* Pets and objects do not detach.
* Interface does not rotate incorrectly.

Do not merely update a heading label while leaving the boat image unchanged.

## 27. FIX PLAYER / SAIL DEPTH ORDER

The Captain observed that the player sometimes appears on top of the sail and rigging when passing beneath them.
Correct the relevant rendering layers.
Use appropriate ordering or occlusion.
Test:

* Different boat headings.
* Bow and stern movement.
* Walking beneath sail artwork.
* Interactions near the rigging.
* Different boats.

The player should remain visible where physically appropriate.
Do not place the entire boat artwork above the player as a crude workaround.

## 28. INVESTIGATE WHITE SIDE OBJECTS / FENDERS

The Captain noticed two white objects along the boat's side while underway.
Identify them.
If they are fenders:

* Display them while moored.
* Stow them while underway.
* Restore the appropriate state on docking.
* Preserve correct display after save/load.

If they are something else, identify them and explain their purpose in the report.
Do not delete unknown artwork blindly.

## 29. RIGHT-SIDE SAILING INFORMATION PANEL

The Captain notes significant unused space while sailing.
Use it for a larger, useful navigation panel.

Mandatory information. Show:

1. Current boat speed.
2. Current heading.
3. Wind direction.
4. Wind speed.
5. Expected wind on the next route leg, within available forecast limits.
6. Estimated time until the next course change.

Useful optional information:

* Distance to waypoint.
* Distance remaining.
* ETA.
* Engine status.
* Current planned course.

Data integrity. Distinguish:

* Actual heading.
* Planned course.
* Actual local wind.
* Forecast wind.
* Estimated arrival.

Do not present forecast wind as guaranteed.
If no next course change exists, show an appropriate clear state rather than a fictitious time.

Visual requirements:

* Readable at 1600×900.
* Clear contrast.
* Suitable for day and night.
* No giant overlapping panels.
* Compatible with Long Passage UI.
* Collapsible or toggleable.
* Does not obscure the Captain or helm unnecessarily.

Consider adapting the I016 Long Passage panel instead of stacking another large competing panel.

## 30. COURSE-CHANGE NOTIFICATION

When the intended course changes by more than approximately five degrees:

* Briefly highlight the new course.
* Use a restrained colour pulse or blink.
* Make the updated number readable.
* Avoid continuous flashing.

Do not trigger repeatedly for ordinary minor heading fluctuations.
Use the route/autopilot command change rather than raw tiny moment-to-moment variations.
Respect accessibility preferences.

## 31. CONTEXT-AWARE ACTION WHEEL

Add an action wheel to expose useful actions.
At helm — Examples: Show/hide cockpit chartplotter. Open relevant navigation view. Existing helm actions.
In cabin — Examples: Sleep. Cabin map. Existing relevant stations.
At anchor — Examples: Existing anchor controls.
Other relevant contexts: Present useful existing actions without building a new universal command system for everything.

Interaction requirements:

* Keyboard accessible.
* Quick to open and dismiss.
* Clear selected action.
* Does not trigger controls beneath it.
* Preserves movement when closed.
* No giant visible interaction circles.

Mandatory help: The action-wheel shortcut must be displayed in the existing lower instruction/help panel.
Do not introduce a feature the player has to discover through undocumented keys.

## 32. SAVE/LOAD WHILE UNDERWAY

This is a critical correctness requirement.
The Captain worries that saving at sea might restore the character in the water or disconnected from the vessel.
Audit and verify thoroughly.

Test saving while:

* At helm.
* Standing on deck.
* Near bow.
* Near stern.
* Inside cabin.
* Under autopilot.
* In an ocean passage.
* During poor weather.
* At night.
* At anchor.
* During a route change.

After loading, verify:

* Character remains in a valid onboard position.
* Correct deck or cabin context.
* Vessel geographic position.
* Heading and visual orientation.
* Active route.
* Next waypoint.
* Relevant weather.
* Game time.
* Boat condition.
* Money and inventory.
* Provisions.
* Pets.
* Existing progression.

Relative positions: Player-on-deck coordinates must restore relative to the vessel's scene/layout, not as stale absolute world positions.
Use a safe fallback if a saved position becomes invalid.
Avoid teleporting to water.

## 33. WEATHER PERSISTENCE / SAVE-SCUMMING

The Captain asks whether reloading a save can avoid an approaching storm by rerolling weather.
Investigate the existing implementation.
I016 reports deterministic wind derived from geographic position, game time and seed.
Verify how all relevant weather systems behave after reload.
Desired result: Reloading the same save should reproduce coherent immediate weather and near-term conditions.
Do not arbitrarily reroll storms.
Do not freeze weather permanently after loading.
Persist or reconstruct the necessary weather and random-generation state.
Document actual behaviour.
Do not introduce a save-format change unless required.

## 34. QUICKSAVE AND QUICKLOAD

Add:
F5 — Quicksave
F9 — Quickload
Important: Godot's editor may use F5 to run the game. This does not prevent using F5 as an in-game shortcut once the game window has focus.

Requirements:

* Clear confirmation.
* No accidental double-activation.
* Valid save state.
* Reliable reload.
* No item or reward duplication.
* Suitable behaviour during underway sailing.
* Defined behaviour during transient scenes.
* No silent corruption of manual saves.

If the existing architecture supports separate quicksave slots, use them.
Otherwise clearly document the implemented policy.
Test in a fresh game and existing save.

## 35. HARBOUR FACILITIES IN DESTINATION PREVIEW

When selecting a harbour in the world map or operational chart, show which facilities exist there.
Examples:

* Groceries.
* Fuel only if fuel facilities actually exist in the current game.
* Boatyard.
* Haul-out.
* Go Ashore.
* Other operational services represented in harbour metadata.

Do not invent facilities.
I016 notes that international harbour tiers differ.
Use the authoritative per-harbour data.
The Captain needs this to plan provisions and maintenance.
Future shop compatibility: I020 will add a clearer separation between boatyard, chandlery, sailmaker and fishmonger.
Do not prematurely display those future services as functioning shops.
Keep the facility-display architecture extensible.

## 36. VISITED HARBOURS BY COUNTRY

Rework the visited-harbour list.
Required: Group by country. Make country groups collapsible. Add filter controls: All. Visited. Not visited.
Requirements:

* Correct visit state.
* Consistent country assignment.
* Useful counts if straightforward.
* Responsive with all current 223 harbours.
* No lost historical visits.
* Save compatibility.
* Correct handling of international harbours.
* Good empty states.

Do not turn this into a new exploration achievement system.

## 37. SHORT DOCKING ARRIVAL ANIMATION

The Captain requests a small arrival presentation.
Current harbour arrivals are automatic.
Do not build a difficult manual docking system.
Desired experience:

1. Vessel reaches a valid harbour arrival.
2. Short fade or smooth transition.
3. Show the harbour scene.
4. Briefly depict the boat settling into the berth.
5. Captain appears at the helm.
6. Engine is running where appropriate.
7. Boat becomes moored.
8. Normal harbour gameplay resumes.

Keep it short and visually satisfying.
Skippable if practical.
Reliability:

* No double arrival.
* No duplicated rewards.
* No extra provision consumption.
* No impossible player position.
* No route-state corruption.
* No save/load regression.
* Correct behaviour for all four boats.

## 38. PRESERVE LONG PASSAGE MODE

I016 introduced Long Passage time acceleration.
It must continue functioning.
The game reportedly supports 1, 4 and 12 game hours per real second.
Preserve:

* Identical voyage simulation regardless of time speed.
* Weather changes.
* Sailing distance.
* Provisions.
* Wear.
* Existing interruptions.
* Correct arrival.
* Save/load.
* UI access.

I017 integration: Day/night lighting must respond correctly.
Environmental sound should not become chaotic during rapid time changes.
Wind preview should not regenerate every intermediate frame.
Navigation panel updates must be bounded.
Do not introduce the full I018 long-passage gameplay overhaul in this iteration.

## 39. AUDIO AND GRAPHICS ACCESSIBILITY

Provide reasonable control over:

* Ambient sound.
* Environmental effects.
* Thunder volume or overall effects volume.
* Lightning flash intensity.
* UI course-change flashing.

Preserve existing settings where available.
Do not add a large new accessibility menu if the existing configuration is adequate.
Critical information should remain readable without sound.
Visual lighting must never make cabin interactions inaccessible.

## 40. PERFORMANCE ENGINEERING

Do not repeat expensive work needlessly.
I016's report measured approximately:

* First chart open: 2.3 seconds after I016 versus 1.2 seconds before.
* World-router initialization: approximately 0.7 seconds.
* Memory: about 66 MB more than before I016.
* No meaningful memory growth during its ten-day benchmark.
* Slower whole-world software-rendered frames.
* Stable underlying simulation performance after weather optimizations.

These are historical Linux measurements, not guaranteed Windows values.
Establish fresh I017 baselines.

Required profiling. Measure:

* Game startup.
* World-map first open.
* World-map reopen.
* World-map panning.
* Regional chart opening.
* Regional chart panning.
* Wind on/off.
* Wind sampling cost.
* Wind drawing cost.
* Cabin rendering.
* Deck rendering.
* Night rendering.
* Thunderstorm rendering.
* Harbour rendering.
* Cockpit chartplotter.
* Long Passage simulation.
* Save/load.
* Memory behaviour.

Separate costs where possible. Distinguish:

* CPU scripting time.
* Data generation.
* Geometry preparation.
* GPU/render work.
* Initial cache loading.
* Subsequent reuse.

Headless CPU measurements and software-renderer measurements mean different things.
Report that clearly.
Important: If a system is already efficient, preserve it.
Do not perform an architectural rewrite merely to create the appearance of optimization.

## 41. TESTING PHILOSOPHY

The Captain has not completed comprehensive Windows testing over the previous several iterations.
Accordingly, I017 needs strong developer-side verification.
But automated tests are not a substitute for actually looking at the game.
Use:

1. Focused unit tests.
2. Integration tests.
3. Rendered visual tests.
4. Two-process restart tests.
5. Performance benchmarks.
6. A clear Windows acceptance checklist.

Do not inflate test counts with meaningless assertions.
Do not weaken old tests to obtain a clean run.
Clearly identify unsupported test environments.

## 42. MANDATORY TEST MATRIX

A. Worldwide chart: Whole-world overview opens. Australia rendering remains correct. Pacific rendering remains correct. Date Line crossing displays correctly. Multiple east/west pans. Zoom in/out. No missing or duplicated continents. World map remains responsive. World routing remains functional.

B. Three navigation interfaces: Cabin map interaction. World map exploration. Destination selection. Voyage monologue. Plausible intermediate stop selection. Regional operational chart. Worldwide route preserved. Cockpit chartplotter. Same route data across all views.

C. Wind and weather: Sailing with chart closed. Local wind sampling. Regional wind overlay. Wind hidden or reduced at broad zoom. Wind cache reuse. Wind time controls. Forecast label. No game-state mutation during preview. Date Line weather continuity. Fast-time weather equivalence.

D. Lighting: Dawn. Daylight. Sunset. Night. Cabin light. Deck light. Harbour light. Indoor/outdoor contrast. Save/load at night. Time acceleration through a full day.

E. Audio and storms: Calm weather. Strong wind. Rain. Lightning. Thunder. Interior muffling. Exterior audio restoration. No sound leaks between contexts. Reasonable audio mixing.

F. Boat and graphics: Boat turns while Captain stands on deck. Eight-direction artwork behaves correctly. Player stays positioned onboard. Player/sail layering. Fender state. Pets and fixtures remain positioned correctly.

G. Cockpit: Navigation panel opens. Fields contain correct values. Course-change notification. Mini chartplotter. Action wheel. Shortcut hint.

H. Save/load: Save underway. Load underway. Save at night. Load at night. Repeated storm reload. F5/F9. Existing saves. Two-process restart.

I. Harbours: Facility information. Visited lists. Country grouping. Filters. Docking arrival. International harbour. Detailed Danish harbour.

J. General regression: Fishing. Cooking. Anchoring. Boat maintenance. Renown. Captain's Log. Companions. Morning Coffee. Go Ashore. Global sailing. Passage stores. Long Passage mode.

## 43. RENDERED VISUAL REVIEW

Use the existing screenshot system where possible.
Capture and inspect:

1. Cabin world map on the cabin wall.
2. World overview opened.
3. Australia and Pacific after panning.
4. Date Line crossing.
5. Selected distant destination.
6. Voyage reflection.
7. Regional navigation station.
8. Cockpit chartplotter.
9. Right-side navigation panel.
10. Action wheel.
11. Bottom shortcut help.
12. Cabin at noon.
13. Cabin at dusk.
14. Cabin at night.
15. Deck at noon.
16. Deck at sunset.
17. Deck at night.
18. Harbour at night.
19. Wind/rain outside.
20. Rain from cabin.
21. Lightning outside.
22. Lightning seen from cabin.
23. Boat before and after heading change.
24. Character near sail overlap.
25. Moored fenders.
26. Fenders while underway.
27. Harbour facility preview.
28. Country-grouped visited list.
29. Docking arrival.
30. Wind snapshot controls.

Review image quality, not just screenshot generation success.
A lighting effect that technically renders but looks ugly is not accepted.
A chart that routes correctly but visually shows shifted continents is not accepted.
Use the game's normal play resolution, including 1600×900 where practical.

## 44. TWO-PROCESS SAVE/LOAD VERIFICATION

Run a real cross-process test.
In process A: Create or load a voyage. Put the Captain aboard underway. Set a valid route. Advance weather and time. Save. Exit.
In process B: Start the game fresh. Load the save. Verify the full restored state. Continue sailing. Verify no duplication or invalid positioning.
Repeat where needed for storm weather and cabin/deck state.
Do not treat resetting a scene in the same process as equivalent evidence.

## 45. SHIPYARD EFFICIENCY REPORT

The Captain requested development-efficiency analysis during I016.
That report was not clearly present in the delivered implementation report.
For I017, include a section titled: Shipyard Efficiency — Where the Time Went
Track measurable information throughout this build rather than trying to reconstruct it at the end.
Include:

1. Major implementation phases.
2. Measured command durations where available.
3. Expensive tests.
4. Expensive rendering or screenshot steps.
5. Repeated geography/data generation.
6. Caching opportunities.
7. Unnecessary repeated work.
8. Up to five recommended efficiency improvements.

Separate measured numbers from estimates.
Do not invent times.
Do not skip critical regression tests merely to improve the efficiency report.
Do not let reporting overhead consume a disproportionate share of development time.

## 46. CHECKPOINT STRUCTURE

Use recoverable checkpoint commits. Suggested structure:

Checkpoint A — Baseline and world-chart repair: Verify repository. Save assignment. Establish benchmarks. Reproduce Australia/Pacific defect. Fix root cause. Render and verify map.

Checkpoint B — Weather architecture and performance: Profile weather and overlay. Confirm local/on-demand simulation behaviour. Optimize wind calculations. Implement snapshot caching. Choose adaptive zoom behaviour. Benchmark.

Checkpoint C — Navigation architecture: Cabin world map. Harbour exploration. Voyage daydreaming. Regional working chart. Shared worldwide routing preserved.

Checkpoint D — Core sailing correctness: Boat orientation. Save/load underway. Weather persistence. Quicksave/quickload. Regression checks.

Checkpoint E — Lighting: Time-of-day transitions. Cabin lighting. Deck lighting. Harbour lighting. Soft shadows and depth. Rendered review.

Checkpoint F — Atmospheric weather: Wind and water audio. Rain. Lightning. Thunder. Cabin muffling. Visual wind near boat.

Checkpoint G — Cockpit and usability: Right-side sailing panel. Compact chartplotter. Course-change indication. Action wheel. Bottom shortcut hint. Wind time controls.

Checkpoint H — Presentation: Player/sail layering. Fenders. Harbour-facility preview. Visited-harbour list. Docking animation.

Checkpoint I — Final verification and delivery: Complete regression. Two-process restart. Rendered screenshots. Performance comparison. Documentation. Push verification.

The order may be adjusted for technical dependencies.
Do not commit broken intermediate states unnecessarily.
Do not run the entire expensive regression suite after every small cosmetic edit.
Run focused tests during development and the complete relevant suite at final checkpoints.

## 47. REQUIREMENT TRACKER

Create a comprehensive tracker covering the actual scope.
Use stable IDs. Suggested sections:

* NAV — Navigation architecture.
* MAP — World rendering.
* WND — Wind and weather performance.
* LGT — Lighting.
* AUD — Audio and storm atmosphere.
* BOAT — Vessel graphics and movement.
* HUD — Cockpit and action wheel.
* SAVE — Persistence.
* PORT — Harbours and arrival.
* QA — Testing and delivery.

Every requirement should have: Identifier. Description. Implementation status. Verification evidence. Relevant test or screenshot. Remaining limitation.
Do not mark something complete just because a script exists.
Do not omit lower-priority items from the final report.

## 48. CAPTAINS_ORDERS.md

Update the authoritative Captain decisions with I017. Record:

* I017 is Let There Be Light.
* Cozy lighting is a defining requirement.
* Three navigation experiences are approved.
* Cabin world map is for exploration and dreaming.
* Navigation station is for practical regional planning.
* Cockpit chartplotter is for immediate sailing.
* All use the existing authoritative worldwide navigation system.
* Worldwide route distance must never be artificially restricted by chart display size.
* World map has no live wind/weather overlay.
* Wind visualization must be optimized through profiling, caching and appropriate sampling.
* Actual sailing weather remains deterministic and coherent worldwide.
* Wind forecasts are read-only model previews.
* Save/load underway must keep the Captain aboard.
* Boat visuals must reflect heading while outside.
* The action-wheel shortcut must appear in the bottom help panel.
* Lighting, weather audio and storm presentation are prioritized.
* No giant visible activation circles.
* I018–I021 remain separately scoped.
* Difficulty levels remain deferred.
* Windows acceptance must not be claimed without the Captain's test.

Preserve all existing authorized decisions.
Do not invent missing Phase Two wording.

## 49. SCOPE BOUNDARIES — DO NOT START THE LATER ITERATIONS

We have already scoped the following future builds.

I018 — The Joy of the Journey. Will include: Fishing 2.0. Fixed-speed circular skill checks. Rarity reveal. Three to five checks for valuable fish. Catch filtering by rarity and size. Automatic release. Bronze/silver/gold fish quality. Released catches excluded from trophies. Shark encounters. Junk catches. Fishing while docked evaluation. Sail Trim minigame. Long-passage activity and pacing.
Do not implement those features in I017.

I019 — The Captain's Watch. Will include: Shared spoken safety alarms. Collision warnings. Wake-up and walk to helm. Radar-based avoidance. Anchor-drag alarm integration. VHF distress calls. Optional rescue missions. Significant renown and scenario-appropriate rewards. Event cooldowns and fairness.
Do not implement these in I017. I017 should provide compatible audio and navigation foundations.

I020 — A Boat of Your Own. Will include: Cabin personalization. Table finishes. Settee colours. V-berth bedding. Decorations. Entertainment screen. Laptop. Visible equipment upgrades. Boatyard for boats and repair. Chandlery / bådudstyrforretning for equipment. Sailmaker for sails and repairs. Fishmonger for retained fish. One shared commerce backend. Boat pricing. Engine condition visuals and upgrades.
Do not build these shops or customization systems in I017.
The cabin wall map is specifically authorized now as a navigation/exploration feature and does not authorize the rest of I020.

I021 — The Well-Trimmed Ship. Will include: Dedicated optimization and stability. Automated gameplay/playthrough evaluation. Economy and reward balancing. Difficulty analysis. Potential later difficulty settings.
Do not implement selectable difficulty modes in I017.
Continue ordinary performance checks now.

## 50. DOCUMENTATION AND DELIVERY

Create: `ITERATION_17_ASSIGNMENT.md`, `ITERATION_17_REQUIREMENTS.md`, `ITERATION_17_REPORT.md`, `WINDOWS_ACCEPTANCE_17.md`
Update: `CAPTAINS_ORDERS.md`
Relevant architecture and developer guides should also be updated where needed.

Implementation report. Include:

1. Starting repository state.
2. Final game version.
3. Save format.
4. Commit/checkpoint list.
5. World-chart rendering defect root cause.
6. Before/after chart screenshots.
7. Weather architecture findings.
8. Local and on-demand computation.
9. Wind performance before/after.
10. Snapshot caching design.
11. Adaptive wind thresholds.
12. Wind time-preview controls.
13. Cabin world map.
14. Voyage daydreaming.
15. Regional navigation station.
16. Cockpit chartplotter.
17. Worldwide routing regression.
18. Lighting implementation.
19. Time-of-day model.
20. Interior/exterior lighting.
21. Harbour lighting.
22. Weather visuals and audio.
23. Cabin acoustics.
24. Visual boat-turning fix.
25. Player/sail layering.
26. Fender findings.
27. Right-side HUD.
28. Action wheel.
29. Save/load and weather persistence.
30. F5/F9.
31. Harbour facilities and visited list.
32. Docking animation.
33. Automated test results.
34. Rendered review.
35. Two-process restart.
36. Performance and memory.
37. Shipyard Efficiency.
38. Known limitations.
39. Pending Windows acceptance.
40. Final commit and push verification.

## 51. WINDOWS ACCEPTANCE 17

Produce a detailed acceptance guide.
The Captain and Skipper use numbered sections and lettered tests.
Each check must have an identifier such as: `1A`, `1B`, `2A`, `2B`.
Organize by subject. Suggested groups:

1. Installation and previous saves.
2. World map and geographic rendering.
3. Cabin map and voyage daydreaming.
4. Navigation station and worldwide routes.
5. Wind overlay and time previews.
6. Day/night and lighting.
7. Weather sound and thunderstorms.
8. Boat orientation and deck graphics.
9. Cockpit panel and chartplotter.
10. Action wheel.
11. Save/load and F5/F9.
12. Harbours and docking.
13. Long Passage and regression.
14. Performance and stability.
15. Final verdict.

Keep checks independent.
Make failures easy to report.
Use the Captain's preferred feedback categories: PASS. FAIL. PARTIAL. NOT TESTED.
Provide space for comments.
Do not claim acceptance is complete until actual Windows results are received.

## 52. DEFINITION OF DONE

I017 is ready for Windows acceptance when all mandatory requirements are implemented and genuinely verified, including:

Navigation: Cabin world map exists and is accessible. World map pans and zooms. Australia and Pacific rendering is corrected. Harbours can be explored. Voyage daydreaming uses real route information. Operational chart focuses on practical regional navigation. Global routes remain possible. Cockpit chartplotter works. All three interfaces use shared navigation data.

Wind and weather performance: Actual weather remains coherent worldwide. Sailing does not unnecessarily calculate a full-world wind display. Chart wind is sampled and cached efficiently. World zoom does not suffer the original severe wind slowdown. Zoom-specific wind density is measured and appropriate. Wind snapshot/time-preview controls work. Forecasts are labelled and read-only.

Lighting and atmosphere: Smooth day/night progression. Warm cabin light. Practical deck lighting. Harbour light. Soft visual shadows and depth. Wind, rain and water ambience. Lightning and thunder in storms. Muffled sound in cabin. Visually coherent local wind cues.

Gameplay correctness: Vessel visually turns while player is on deck. Character/sail layering is corrected. Fenders are correctly understood and handled. Save/load underway keeps Captain aboard. Weather state survives save/load coherently. F5/F9 work reliably. Long Passage continues functioning. Existing gameplay remains intact.

Usability and polish: Right-side sailing HUD. Course-change notification. Context-aware action wheel. Shortcut hint in bottom panel. Harbour facilities visible. Harbour visit list grouped and filtered. Short docking arrival sequence.

Engineering: No obvious major performance regression. Complete relevant regression testing. Rendered visual inspection. Two-process restart tests. Honest implementation report. Shipyard Efficiency reporting. Updated Captain's Orders. Clean committed and pushed branch.

If any material requirement cannot be completed, explain: What remains incomplete. Why. What was tested. What risks remain.
Do not claim full completion for a partial implementation.

## 53. FINAL GITHUB HANDOVER

Push only to: https://github.com/crosenlund79/LittleCaptainsHat
Use the verified development branch.
The Captain's deployment workflow remains: GitHub → Branch → Code → Download ZIP → Extract → Open `project.godot` in Godot → Run.
Do not create a Windows executable unless requested.
Before final delivery:

1. Verify repository.
2. Confirm commits.
3. Run final tests.
4. Review screenshots.
5. Complete documentation.
6. Push.
7. Verify remote HEAD.
8. State exact version and save format.
9. State final commit.
10. State Windows acceptance status accurately.

The final line of your final delivery message must be the clickable direct GitHub URL to the branch containing the completed work.
Expected URL, if unchanged: https://github.com/crosenlund79/LittleCaptainsHat/tree/claude/friendly-fermat-dey23f
Do not substitute the generic repository homepage.

## FINAL CAPTAIN'S ORDERS

We have given the Captain the world.
Now make it somewhere worth inhabiting.
The cabin world map should invite the Captain to dream of faraway places.
The navigation station should turn those dreams into a voyage.
The cockpit chartplotter should make sailing that voyage easy to understand.
The world chart must render correctly, even when crossing the Pacific.
Wind visualization must be useful without becoming an unnecessary performance burden.
The actual wind must still move the boat.
Let daylight fade naturally.
Let warm lamps illuminate the saloon.
Let the harbour lights welcome us home.
Let rain drum softly on the cabin roof.
Let thunder rumble outside while the Captain feels sheltered below.
Let the boat visibly turn when we change course.
Let every save restore the Captain safely aboard.
Preserve the world, preserve the voyage, and preserve the cozy atmosphere.
Do not begin the separately scoped work of I018, I019, I020 or I021.
COZY FIRST.
Small boat. Wide world. Hold onto your hat.
Proceed with Iteration 17 from the verified I016 baseline.
REMEMBER: End your final delivery with the exact direct GitHub development-branch URL.
