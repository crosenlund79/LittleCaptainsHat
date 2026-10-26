# LITTLE CAPTAIN'S HAT
# ITERATION 18 — THE JOY OF THE JOURNEY
## Fishing 2.0, Living Fish, Meaningful Sailing, Peaceful Anchorages and a Companion at Your Side

**FULL AND AUTHORITATIVE COMMISSIONING ASSIGNMENT**

**Repository:** https://github.com/crosenlund79/LittleCaptainsHat

**Expected development branch:** `claude/friendly-fermat-dey23f`

**Starting baseline:** I017 — Let There Be Light, version **0.104a**, save format **12**

**New version:** Follow the project's existing version policy.

**Captain's governing principle:** **COZY FIRST.**

**Tagline:** *Small boat. Wide world. Hold onto your hat.*

---

# 0. IMPORTANT — THIS IS THE COMPLETE HANDOVER

Monsieur Claude,

This document is the complete, consolidated assignment for Iteration 18.

**There is no missing base prompt.**

It supersedes any earlier I018 ideas or partial assignments wherever they conflict.

You are authorized to proceed with implementation after verifying the repository and baseline. You do not need to ask the Captain for permission to implement requirements explicitly described here.

I018 has four major purposes:

1. Make fishing visual, delightful, skillful and rewarding.
2. Make the journey itself more interesting through sail trim, improved Long Passage pacing and purposeful anchorages.
3. Make the boat feel lived in, especially through anchoring details and pet companionship.
4. Resolve the specific I017 Windows findings intentionally carried into this iteration.

Do not confuse these goals with building a difficult survival simulator.

The Captain wants a cozy liveaboard sailing experience: a small boat, a large world, thoughtful choices, occasional surprises, charming details and a comfortable sense of home.

**There is no need to retrieve earlier ChatGPT conversations. All approved I018 requirements are contained here.**

Before changing gameplay code, preserve this entire assignment in the repository as:

`ITERATION_18_ASSIGNMENT.md`

Create a requirement tracker with stable IDs and update it as implementation progresses.

This file must remain the source of truth after session interruption or context compaction.

Do not invent requirements that are not present.

Do not mark features complete merely because a class or UI element exists.

---

# 1. CURRENT PROJECT STATE

I017 was delivered as:

- **Game version:** 0.104a.
- **Save format:** 12.
- **Branch:** `claude/friendly-fermat-dey23f`.
- **Automated developer verification:** 3,838 checks passed in its full reported regression.
- **Windows acceptance:** Priority sea trial completed, but comprehensive acceptance was not performed.

The Captain personally tested I017 on Windows.

## I017 Windows results

**PASS:**

- Existing save loaded successfully.
- Cabin world map and voyage daydreaming worked.
- Night sailing was smooth.
- Boat visibly changed heading while the Captain stood outside.
- Quicksave, full restart and reload while underway worked.

**PARTIAL — Carry into I018:**

### Finding I17-S3: Route disappears when panning the global chart

With Papeete selected as a destination from Middelfart, the planned route appeared correctly on the chart.

After panning a little to the left, its dashed line disappeared.

After continuing to pan left, the route reappeared, stretching from the Denmark/European area toward Papeete.

The destination, route distance and estimated passage time remained displayed.

The Captain confirmed that **planning remained active**. This was a graphical route-visibility problem, not an observed loss of route data.

Two Windows screenshots were supplied to Atlas; they may not be attached to this Claude session.

Do not stop because screenshots are unavailable. The defect and expected behaviour are described here.

### Finding I17-S4: Wind preview time increments are too small

The current 30-minute forecast steps show very little meaningful change.

The Captain would prefer larger intervals and a more useful planning horizon.

Inspect the actual weather time scale before finalizing new increments.

### Finding I17-S5: Lighting refinements

The Captain wants:

- More visible contrast between illuminated cabin areas and darker corners.
- Warm pools of light that feel attached to real fixtures.
- Exterior navigation lights clearly visible against the darkness while underway, outside the cabin.

These are refinements to an otherwise promising I017 lighting system, not authorization to rebuild its renderer.

## Carry-forward acceptance policy

The Captain is deliberately carrying these findings into I018.

Do not call the underlying I017 problems fixed before verifying the new implementation.

Do not claim that all I017 Windows acceptance was completed.

---

# 2. REPOSITORY AND WORKTREE SAFETY

Before implementing anything, verify:

1. Working directory.
2. Git remote.
3. Current branch.
4. HEAD commit.
5. Working tree.
6. Current game version.
7. Save format.
8. `CAPTAINS_ORDERS.md`.
9. `ITERATION_17_REPORT.md`.
10. `ITERATION_17_REQUIREMENTS.md`.
11. `ITERATION_17_ASSIGNMENT.md`.
12. Existing fishing architecture.
13. Fish species and rarity data.
14. Catch persistence and trophy data.
15. Inventory and food systems.
16. Sailing and wind physics.
17. Long Passage simulation.
18. Current anchoring mechanics.
19. Existing route waypoint editing.
20. Current character and pet scene logic.
21. Existing lighting and chart rendering.
22. Test suites, screenshot tools and benchmarks.

Work only in the authorized repository.

Do not touch the archived Next Harbor project.

Do not reset or discard valid changes.

Preserve original Captain-owned art assets.

Do not force-push, rewrite history or silently modify existing save files.

Use normal recoverable checkpoint commits.

---

# 3. NON-NEGOTIABLE DESIGN PRINCIPLES

## 3.1 Cozy, not punishing

A failed fishing minigame should feel like a missed opportunity, not a personal disaster.

A poor sail-trim choice should reduce efficiency modestly, not suddenly strand the boat.

Reaching an anchorage should create a pleasant moment of decision, not automatically cause a collision.

The pet should behave like a companion, not another resource that requires micromanagement.

## 3.2 Real systems, shared truth

Use existing authoritative data for:

- Fish species.
- Fish rarity.
- Fish weight.
- Specimen records.
- Inventories.
- Fishing equipment.
- Wind and weather.
- Navigation.
- Anchor state.
- Route waypoints.
- Pet location.
- Save/load.

Do not invent parallel systems to support a new interface.

## 3.3 Respect the four vessels

Ensure correct behaviour on:

- Arctic Wanderer 26.
- Wing 33.
- Frogleap 36.
- Clam 40.

Different deck and cabin layouts must not cause characters or pets to appear outside the boat.

## 3.4 Illustrated personality

The game should look and feel like Little Captain's Hat.

Avoid generic developer widgets, debug panels and numeric-only rewards as the final player experience.

## 3.5 Bounded performance

No feature should introduce expensive work every frame when it could be event-driven, cached or updated at a modest interval.

## 3.6 Preserve worldwide sailing

Do not restrict global routing, destinations or Long Passage functionality.

---

# 4. IMPLEMENTATION PRIORITIES

## P0 — Correctness

- Fix world-route overlay disappearance during horizontal panning.
- Preserve route data and waypoint state.
- Preserve existing fishing, inventory and save data.
- Ensure anchorage waypoints cannot steer the vessel onto land.
- Preserve existing safe anchor checks.
- Keep pets aboard.
- Preserve sailing and Long Passage simulation correctness.

## P1 — Core I018 identity

- Fishing 2.0 circular timing interaction.
- Illustrated fish by species.
- Blink and tail-flick animation.
- Catch rarity and specimen-size systems.
- Fish keep/release preferences.
- Trophy correctness.
- Sharks and occasional junk catches.
- Meaningful Sail Trim.
- Anchorage waypoint interaction.
- Anchorage arrival prompt.
- Pet follows between cabin and deck while anchored or moored.
- Better Long Passage event flow.

## P2 — Polish

- Anchor ball and anchor light.
- Visible anchor buoy and/or anchor rode.
- Improved cabin light contrast.
- Improved exterior navigation lights.
- Better wind preview intervals.
- Additional fishing presentation polish.

Everything in this scope must be tracked.

Do not silently drop a feature because it appears lower in the list.

---

# 5. FIX THE I017 WORLD-ROUTE OVERLAY DEFECT FIRST

This fix is particularly important because I018 will extend waypoint behaviour.

## 5.1 Reproduction

On a Windows-style interactive chart:

1. Start in the Middelfart/Denmark region.
2. Select Papeete as a distant destination.
3. Plot or preview a valid worldwide route.
4. Display the dashed route.
5. Pan the chart west.
6. Observe whether the route disappears although the destination and distance remain.
7. Continue panning west.
8. Observe whether the route reappears in a different horizontal world copy.
9. Pan east and repeat.

The Captain observed precisely this pattern in 0.104a.

## 5.2 Root-cause investigation

I017's world-chart land-rendering repair made west/main/east geographic copies complete.

Investigate whether the route overlay:

- Uses only one world copy.
- Clips segments incorrectly.
- Normalizes longitudes inconsistently.
- Uses stale camera offsets.
- Mixes wrapped and unwrapped coordinates.
- Incorrectly joins segments across the Date Line.
- Culls the complete polyline because one portion is off-screen.
- Loses display geometry while retaining the route model.

Do not assume the root cause without examining the code.

## 5.3 Expected fix

A route should remain visible wherever relevant portions of its geography appear in the viewport.

A route crossing the Date Line must wrap correctly without drawing a wildly incorrect line across the map.

Repeated east/west panning must not hide valid route segments.

Keep route planning and route drawing separate.

Camera panning must never alter:

- Route waypoint positions.
- Active route.
- Planned destination.
- Calculated route distance.
- Vessel navigation state.
- Saved voyage.

## 5.4 Regression testing

Add a rendered test that specifically draws long route polylines and checks their visibility across multiple horizontal offsets.

Cover:

- Copenhagen/Middelfart to Papeete.
- Pacific and Date Line routes.
- Routes with several waypoints.
- Routes with a waypoint near the Date Line.
- A route partly off-screen.
- A route with the first and last segments in different world copies.

Test both the cabin world map and the working navigation chart where relevant.

Do not rely only on the land-layer regression test.

---

# 6. FISHING 2.0 — THE CIRCULAR TIMING GAME

Replace the existing fishing tension-bar interaction with a simple, clear, satisfying timing challenge.

The Captain specifically wants a **constant-speed rotating indicator on a circle**.

## 6.1 Core interaction

When a fish bites:

1. The game alerts the Captain.
2. The reel-in interaction opens automatically or becomes immediately prominent, according to the existing fishing flow.
3. The fish species and rarity are revealed.
4. A circular timing interface appears.
5. An indicator moves around the circle at a constant, readable angular speed.
6. A target success arc is shown.
7. The Captain presses the action key as the indicator passes through the arc.
8. Each successful check advances the catch.
9. After all required successful checks, the fish is landed.

Use a consistent input, with appropriate keyboard and mouse support.

Do not suddenly vary the indicator's speed merely to trick the player.

The challenge should primarily come from the size of the target window and the number of checks.

## 6.2 Rarity and difficulty

Initial intended progression:

| Rarity | Successful checks required |
|---|---:|
| Common | 1 |
| Uncommon | 2 |
| Rare | 3 |
| Epic | 4 |
| Legendary | 5 |

Target windows should generally become narrower at higher rarities.

Keep all rarities fairly playable.

Inspect the actual rarity names and mappings already used in the repository before implementation.

Do not create duplicate rarity categories if the project uses different labels.

## 6.3 Failed timing checks

A missed timing press should matter but should not immediately destroy every catch.

Implement a forgiving, readable miss allowance.

For example, misses may reduce line control and after a fair number of misses the fish escapes.

The exact rule should be documented and tested.

Avoid an experience in which one slightly mistimed keypress destroys a legendary encounter.

## 6.4 Perfect hits

Include a visibly smaller **Perfect** zone inside the successful timing arc.

A Perfect hit should modestly improve the likelihood of a better specimen size or quality within that fish's already-determined possibilities.

**Perfect hits must not magically change a common fish into a legendary species or rarity.**

Keep rarity, species and specimen size conceptually distinct.

## 6.5 Consistent simulation

The catch encounter should use existing species and fishing location logic.

Do not replace fishing populations with a completely random visual minigame.

The UI must reflect an actual encounter.

Protect against:

- Multiple results from one catch.
- Duplicate inventory insertion.
- Repeated rewards after save/load.
- Accidentally landing a fish twice.
- Catching fish while the game is paused in an unrelated UI.

---

# 7. THE FISH MUST BE A CREATURE, NOT A NUMBER

This is a specific Captain-requested addition to I018.

**Every actual fish species in the current game should have a recognizable visual representation.**

The Captain does not want to catch only a name, weight and numerical rarity.

A landed fish should feel like a little creature we have encountered.

## 7.1 Art direction

Create attractive, cozy, illustrated 2D fish artwork matching the game's established visual language.

The look should be:

- Recognizable by species.
- Charming rather than clinical.
- Simple enough to animate.
- Legible at modest UI sizes.
- Consistent across the species collection.
- Believable enough to distinguish different kinds of fish.

Avoid:

- Plain text placeholders.
- Generic identical fish silhouettes recoloured for every species.
- Photographic or hyperrealistic fish pasted into an illustrated game.
- Unrelated clip-art styles.
- Overly elaborate 3D animation.
- Decorative graphics that obscure information.

Inspect the existing species list and region assignments.

Produce visuals for the actual supported species, including existing international or special catches.

Do not arbitrarily limit the system to seven handpicked fish if the game supports more.

A reasonable shared template or body-shape family may be used to control asset production effort, but each species should have recognizable identifying features.

If some species require a temporary shared base shape, identify that honestly in the deliverables and do not call the species art complete.

## 7.2 Species examples

Examples of fish that may require distinct forms depending on actual game content:

- Cod.
- Mackerel.
- Garfish.
- Sea trout.
- Halibut.
- Other existing fish species.
- Region-appropriate sharks.

These are examples, not an exhaustive species catalogue.

The repository is the authority for actual game species.

## 7.3 Fish behaviour — a tiny charming gimmick

When displayed prominently in the reel-in, catch-result or inspection interface, the fish should exhibit occasional subtle movement.

**Blinking:**

- The eye occasionally closes and opens.
- Small and quick.
- Irregular timing, approximately every few seconds.
- Not mechanically synchronized across all species.

**Tail flick:**

- A small tail wiggle or flick every so often.
- Modest movement.
- Brief and playful.
- Not frantic continuous flapping.

**Optional subtle motion:**

- Very gentle bobbing.
- A slight body wiggle.
- Small orientation or shadow changes if they improve the effect.

The fish should feel alive without turning the interface into a cartoon circus.

Use lightweight sprite frames, separated body parts or another straightforward Godot-compatible animation technique.

Prefer reusable animation logic with species-specific proportions or assets.

## 7.4 Animation correctness

Animations must:

- Stop when the fish UI is closed.
- Not create unbounded timers.
- Not cause memory growth.
- Not continue off-screen for hundreds of inventory fish.
- Respect pause behaviour.
- Respect reduced-motion preferences if available.
- Avoid flickering eyes at excessively high frequency.

The prominent fish illustration should animate.

Small collection thumbnails can remain static for performance.

## 7.5 Fish reveal

When the fish encounter is revealed:

- Show its illustrated species.
- Show the species name.
- Clearly identify the rarity.
- Use the same image identity throughout the encounter.
- Preserve clarity for colour-blind or low-contrast viewing.

The fish should not abruptly change species between reel-in and result.

## 7.6 Catch result

After landing the catch, display a satisfying result panel containing:

- Fish illustration.
- Species.
- Rarity.
- Weight.
- Bronze/Silver/Gold specimen grade where applicable.
- Whether it will be kept or released.
- Appropriate actions.

A subtle animation or small entrance flourish is welcome.

Do not require lengthy repetitive celebrations for common fish.

## 7.7 Inventory and trophies

Reuse the species artwork in:

- Kept-fish inventory.
- Fish inspection/details.
- Catch history if present.
- Trophy display or plaque system.
- Future fishmonger presentation.

Do not create multiple incompatible presentation pipelines.

## 7.8 Future compatibility

I020 will introduce the fishmonger as a dedicated commercial shop.

Make fish art, rarity, specimen grade and price-relevant data accessible to that future interface through reusable APIs.

Do not build the fishmonger shop in I018.

## 7.9 Junk visuals

Junk catches need their own small illustrated presentation.

For example, an old boot or similarly harmless discarded object can be amusing.

Do not present junk as a living fish that blinks.

## 7.10 Asset provenance

Document how images were produced, their licenses where appropriate, and where source/project files reside.

Do not use unlicensed copied art.

Do not modify or overwrite Captain-owned art without authorization.

---

# 8. RARITY, WEIGHT AND SPECIMEN GRADES

Preserve a clear distinction between:

1. Species.
2. Rarity.
3. Weight.
4. Specimen grade.

## 8.1 Rarity

Rarity determines how unusual the fish encounter is and affects minigame challenge.

## 8.2 Weight

Weight is an attribute of the individual specimen.

It should fall within plausible existing species ranges.

## 8.3 Bronze / Silver / Gold

These grades must be **weight-based**, using species-relevant thresholds.

A rare species is not automatically Gold.

A common species can be a Gold specimen if it is particularly large for that species.

A legendary rarity does not guarantee exceptional weight.

Document the grade calculation.

Keep the scale consistent with existing fish data, inventory and trophies.

## 8.4 Perfect timing

Perfect timing can influence the final weight or quality probability modestly, within reasonable limits.

It cannot invent implausible specimen sizes.

It must not reroll or silently replace the actual species.

---

# 9. KEEP OR RELEASE PREFERENCES

The Captain wants to specify which catches are worth keeping.

Add preferences based on **both rarity and specimen size**.

## 9.1 Required controls

Allow the player to select:

- Minimum rarity to keep.
- Minimum specimen size or grade to keep.

Use a comprehensible interface.

If there are species-specific limitations, explain them.

Do not require cumbersome per-species configuration unless genuinely useful.

## 9.2 Combined rule

The Captain's chosen filters should work together.

For example:

- Keep Rare or better.
- Keep Silver or Gold specimens.

Then a fish below either threshold should be released automatically, unless another explicit protected-species rule governs it.

Show clearly what the current settings mean.

## 9.3 Automatic release

When a landed fish does not meet the preferences:

- Show its species and weight.
- Explain that it is being released according to preferences.
- Do not add it to inventory.
- Do not add it to trophy records.
- Do not award sale value.
- Do not allow item duplication through UI timing.

Keep the interaction concise.

## 9.4 Manual release

If the Captain manually releases a fish, the same exclusion rules apply.

**A released fish must not appear on the trophy board.**

This is a specific Captain requirement.

## 9.5 Kept fish

A kept catch may enter inventory and relevant existing records.

Use the current game systems.

Do not replace the inventory backend.

## 9.6 Persistence

Save preferences correctly using the existing schema where practical.

If the save format must change, document and test migration from format 12.

Do not alter the save format just to store a transient UI selection if existing settings persistence is sufficient.

---

# 10. SHARK ENCOUNTERS

Introduce or enhance appropriate shark fishing encounters according to existing fishing regions.

Sharks should not simply appear in every Danish fishing location.

Use believable geographic species distribution.

## Requirements

- Clearly identifiable shark artwork.
- Appropriate rarity and encounter rates.
- Distinct visual impression from ordinary fish.
- Automatically released after a successful encounter.
- Not available for sale.
- Not edible inventory.
- Not retained as trophy fish.
- Clear player-facing explanation.

A brief reaction such as:

“That's quite a catch. Better let this one swim free.”

is appropriate.

Avoid graphic injury, gore or cruelty.

This is a cozy sailing game.

---

# 11. OCCASIONAL JUNK CATCHES

Add occasional worthless objects to the fishing encounter pool.

Examples:

- Old boot.
- Tangled rope.
- Rusty tin.
- Similar harmless marine debris.

Keep encounters infrequent.

## Requirements

- Distinct visuals.
- A little humour.
- No fake fish rarity.
- No meaningful sale value.
- No trophy entry.
- No unrealistic accumulation of useless inventory.

Use a simple discard outcome.

Avoid turning fishing into a repetitive trash-collection chore.

Do not launch a new environmental cleanup quest system.

---

# 12. FISHING WHILE MOORED OR ANCHORED

Inspect the current fishing controls and boat-state restrictions.

The Captain is interested in being able to fish peacefully while stopped.

## Preferred design

Allow an appropriate fishing interaction when:

- Safely anchored in suitable water.
- Possibly moored, if the existing harbour design supports a sensible location and interaction.

Differentiate:

- Trolling while underway.
- Stationary rod fishing while anchored or moored.

Do not pretend the boat is trolling when stationary.

Reuse the shared encounter and fish presentation systems.

If enabling dockside fishing requires new harbour geometry or a full separate minigame, keep it modest and explain the limitations.

A future "Go Ashore" shore-fishing activity can remain deferred if necessary.

---

# 13. FISH BITES AND LONG PASSAGE FLOW

I016's Long Passage mode sometimes interrupts frequently, particularly when fish bite.

I018 should make this more pleasant.

## 13.1 Bite handling

When a fish bites during normal play:

- Clearly inform the Captain.
- Make the reel-in interface immediately accessible.
- Avoid a situation where a bite happens silently and disappears.
- Avoid forcing the Captain through unnecessary unrelated menus.

## 13.2 Long Passage

The player should be able to choose a sensible fishing posture during time acceleration.

Potential options:

- Fishing actively: catches may interrupt.
- Fishing passively with a simplified preference: only certain catches require attention.
- No fishing during accelerated passage.

Choose the least complicated option that respects actual gameplay.

Do not grant unearned fish while skipping the skill check.

If passive fishing is implemented, outcomes must be documented and should not bypass the rules unfairly.

## 13.3 Catch preferences and interruptions

The rarity/size preferences should reduce unnecessary inventory clutter.

They can also help reduce notifications that don't require the Captain's attention.

However, since specimen size may only be known after a successful catch, do not magically pre-filter using information the player has not earned unless that is a deliberate, clearly explained game rule.

## 13.4 Fair pacing

Fishing should be enjoyable, not an interruption every few seconds.

Use appropriate cooldowns and encounter rates.

Retain meaningful geographic fishing differences.

---

# 14. SAIL TRIM — A SMALL OPTIONAL SAILING SKILL

Add a Sail Trim interaction that makes attentive sailing feel rewarding.

The Captain originally envisioned a slider.

## 14.1 Main interaction

Provide a simple slider or equivalent control representing sail trim.

The best trim should depend on:

- Relative wind direction.
- Boat heading.
- Current sailing conditions.
- Existing sail and boat characteristics.

## 14.2 Feedback

Show readable, immediate feedback.

Examples:

- Too loose.
- Well trimmed.
- Too tight.

A small efficiency indicator is acceptable.

Do not turn this into a technical aerodynamics panel.

## 14.3 Reward

Good trim should provide a **modest improvement** to sailing efficiency or speed.

Poor trim may produce a modest reduction.

Do not allow a minigame to override the real sailing model or make an unsuitable point of sail impossibly fast.

Respect eight-direction visuals and continuous physics.

## 14.4 Coziness and accessibility

Sail Trim must be optional in the sense that the player can still sail successfully without actively managing it every minute.

Consider sensible autopilot/default trimming or a gradual return to neutral.

Do not demand adjustment after every tiny gust.

## 14.5 Persistence

Define whether trim state persists across course changes, saves and loads.

A sensible approach is to preserve user intent while recalculating actual effectiveness from current wind.

No speed duplication or stacking exploits.

## 14.6 Performance

Calculate meaningful trim changes at suitable simulation intervals.

Avoid expensive continuous searches for an optimal trim value every rendered frame.

---

# 15. IMPROVE LONG PASSAGE PACING

Keep I016's essential Long Passage model.

The Captain values being able to cross oceans without manually watching every individual nautical mile.

## Preserve

- 1, 4 and 12 game hours per real second where already supported.
- Actual route movement.
- Weather.
- Stores and provisions.
- Hull and rig wear.
- Anchor and mooring states.
- Existing event handling.
- Global voyage completion.

## Improve

- Avoid excessive trivial interruptions.
- Make significant events clearly distinguishable from minor activity.
- Avoid repetitive fishing interruptions.
- Keep sleeping aboard meaningful.
- Ensure day/night lighting changes gracefully.
- Preserve readable navigation information.
- Avoid event storms during 20× or Long Passage acceleration.

## Critical rule

Fast time must not become free travel.

Provisions, wear, distance and weather must still follow the authoritative simulation.

Do not implement I019's collision radar, VHF rescues or voice-alarm architecture here.

## Engine economy note

The Captain has observed that engine use currently carries no fuel cost.

Do not invent a full fuel economy in I018 unless an existing mechanic already requires correction.

Record this as a future balancing/economy consideration rather than silently introducing a new survival requirement.

---

# 16. ANCHORAGE WAYPOINTS — A DESTINATION FOR THE NIGHT

This is a newly approved I018 feature.

The Captain wants to be able to choose a spot near the coastline, add a waypoint there and mark it as an anchorage.

On arrival, the boat should stop its planned navigation leg and ask the Captain to deploy the anchor.

## 16.1 Waypoint creation and editing

Preserve current route-waypoint behaviour.

Allow the player to:

1. Add a waypoint along a planned route.
2. Drag it to a new suitable position.
3. Mark the waypoint as an **Anchorage**.
4. Recognize the anchorage visually on the chart.
5. Edit or remove the designation.
6. Save and restore it.

An anchorage waypoint must be a type or property of the existing waypoint system, not a completely separate navigation engine.

## 16.2 Discoverability

When the player first uses relevant chart controls, provide a brief useful hint:

“Found a sheltered bay? Place a waypoint near the coast and mark it as an anchorage. I'll stop there so you can drop the anchor.”

Use unobtrusive help.

Do not require the Captain to discover a hidden right-click gesture without guidance.

Support an accessible alternative to mouse-only interaction if practical.

## 16.3 Safe positioning

The waypoint must be in navigable water.

Check:

- Land geometry.
- Coast proximity.
- Reachability.
- Existing chart routing constraints.
- Appropriate depth and anchor rules where available.
- Existing hazards.

Do not invent precision bathymetry the game does not possess.

If depth data is insufficient, use the game's current anchoring suitability model and acknowledge its limitations.

Do not allow the Captain to drag a waypoint onto dry land and then have the autopilot crash into it.

If a nearby point is unsuitable, explain why and offer a safe correction or let the player choose another spot.

## 16.4 Anchorage arrival

When the vessel reaches a marked anchorage:

1. Stop the active route leg at an appropriate distance.
2. Reduce or halt movement safely under the existing vessel controls.
3. Pause Long Passage acceleration.
4. Notify the Captain.
5. Prompt: **“We've arrived at our anchorage. Ready to drop anchor?”**
6. Allow the Captain to perform the normal anchor action.
7. Apply normal anchoring checks.

**Do not automatically claim the anchor is set simply because the vessel reached the waypoint.**

Reaching the anchorage and successfully anchoring are different events.

## 16.5 Declining or postponing

If the Captain chooses not to anchor:

- Do not force anchoring.
- Keep navigation state coherent.
- Allow a safe decision to resume, modify or cancel the route.
- Avoid repeatedly presenting the same prompt every second.

## 16.6 Continuing the voyage

If the anchorage waypoint lies within a longer route, define the remaining route properly.

After raising anchor, the Captain should be able to resume the remaining passage without reconstructing every subsequent waypoint.

Do not allow autopilot to resume unexpectedly while the anchor is deployed.

## 16.7 Save/load

Test saving:

- On approach.
- At the anchorage prompt.
- Successfully anchored.
- After declining.
- After weighing anchor and resuming.

Avoid prompt duplication, waypoint loss and auto-departure.

---

# 17. ANCHOR BALL — A REAL NAUTICAL DETAIL

The Captain specifically requested a traditional **black anchor ball**.

This is the black spherical day shape displayed prominently in the forward rigging when a vessel is at anchor.

Implement it as a visible part of the boat presentation.

## Requirements

- Black ball visible when anchored during daylight.
- Clearly associated with the vessel.
- Positioned sensibly in the forward rigging.
- Rendered correctly for the existing eight boat orientations.
- Not floating arbitrarily beside the boat.
- Not present while merely moored to a dock.
- Not present while underway.
- Disappears when the anchor is raised.

Use a simple illustrated sprite or vector-like artwork matching the game.

Keep it legible at ordinary game scale.

## Night-time behaviour

At night, the appropriate **white anchor light** must be visible while anchored.

Do not rely on the black ball as a night-time indicator.

The day shape may remain physically present, but night visibility should depend on the light.

Do not confuse the white anchor light with the vessel's red/green underway navigation lights.

Follow sensible small-vessel nautical conventions within the limits of the game's visual style.

---

# 18. ANCHOR BUOY AND VISIBLE ANCHOR CONNECTION

The Captain also wants a visible indicator that the boat is anchored.

## 18.1 Anchor buoy

Add a modest illustrated anchor marker buoy near the expected anchor position where appropriate.

Recognize that real vessels do not always deploy an anchor buoy.

Within the game, its purpose is visual clarity and charm.

It may be treated as a game presentation choice or optional equipment, but do not build a complicated equipment purchasing system now.

The marker must not appear as a navigation hazard or harbour buoy unrelated to the vessel.

## 18.2 Anchor rode

Where visually affordable, show a subtle rope or chain from the bow toward the water.

It need not simulate complex rope physics.

The direction should be plausible relative to the anchor and vessel orientation.

## 18.3 Anchored movement

If the existing anchoring model includes limited swinging or dragging, visuals should remain coherent.

The buoy and rope should not visibly teleport in a way that implies the anchor moves with the boat at all times.

Use the most appropriate implementation supported by existing anchoring state.

## 18.4 State transitions

Verify:

- Anchor deployed.
- Anchor holding.
- Anchor slipping or dragging.
- Anchor raised.
- Returning to harbour.
- Save/load.

Do not create a new anchor-drag risk model merely for the visual effects.

I019 will revisit anchor-drag alarms.

---

# 19. SNØVS — COMPANIONSHIP BETWEEN CABIN AND DECK

The Captain wants the onboard pet to feel more present and responsive.

**When the Captain goes outside while moored or anchored, the pet should be able to follow outside.**

When the Captain returns inside, the pet should eventually follow into the cabin.

This is an important cozy feature.

## 19.1 Supported states

Implement area-follow behaviour when the vessel is:

- Moored in harbour.
- Safely anchored.

Preserve current safer behaviour while actively underway unless existing systems already support an appropriate outdoor pet state.

Do not force the pet onto deck in heavy-weather sailing.

## 19.2 Natural behaviour

The pet should not march permanently on the Captain's heels.

Preferred behaviour:

1. Captain changes area.
2. After a small natural delay, the pet decides to follow.
3. The pet appears through or near an appropriate cabin/deck access point.
4. It wanders to one of a few safe places.
5. It may sit, rest, look around or move occasionally.
6. When the Captain returns inside, the pet eventually follows.

Use the existing pet identity and animation system.

Do not replace the pet with a generic follower marker.

## 19.3 Safe locations

For each vessel, define or derive valid areas:

- Inside cabin.
- On deck.
- Near appropriate access points.
- Safe resting spots.

The pet must never:

- Walk over water.
- Appear outside the hull.
- Stand beyond the rail.
- Clip through a major fixture.
- Block the helm.
- Prevent docking or anchoring.
- Fall off during a heading change.

## 19.4 Other characters

If existing pet and companion architecture supports several characters, reuse shared movement infrastructure where appropriate.

But this requirement is primarily about the pet.

Do not implement a giant new NPC schedule system.

## 19.5 Transitions and persistence

Test:

- Cabin to deck while moored.
- Deck to cabin while moored.
- Cabin to deck while anchored.
- Deck to cabin while anchored.
- Raising anchor after the pet has come outside.
- Departure from harbour.
- Save/load while pet is on deck.
- Save/load while pet is in cabin.
- Switching boat heading.
- Different boat layouts.

If a departure requires the pet to return safely inside, handle it automatically and naturally.

Do not strand the pet outside when the boat leaves.

---

# 20. REFINE I017 CABIN LIGHTING

The I017 Windows priority test reported that the cabin looked promising but could use a stronger distinction between light and shadow.

This is a refinement, not a complete lighting redesign.

## Desired visual effect

At night:

- Warm pools near actual lamps.
- Clearly darker unlit corners.
- More local light around the saloon table and galley.
- Gentle contrast near furniture.
- Readable character and pet.
- Soft and welcoming shadows.
- No featureless uniform yellow wash.

Use the existing `BoatLighting` architecture if appropriate.

Preserve performance.

Test all four boats.

## Guardrails

Do not make the cabin oppressively dark.

Do not make interaction targets disappear.

Do not create hard-edged black shadows everywhere.

Do not cause visible light leakage through incorrect canvas layers.

Do not introduce an expensive full dynamic occlusion system merely to adjust light-pool contrast.

Review actual rendered images side by side before accepting the change.

---

# 21. EXTERIOR NIGHT NAVIGATION LIGHTS

The Captain wants to see small, convincing navigation lights glowing against the surrounding dark water while underway.

The previous I017 lighting already introduced navigation lights; refine their visibility and placement.

## Requirements

- Attach lights to the correct vessel positions.
- Correct orientation as the boat turns.
- Appropriate red/green side-light distinction.
- Appropriate white stern/navigation light presentation where relevant.
- Visible exterior glow over the dark sea.
- No false appearance that these are indoor cabin lamps.
- No oversized glowing halos.
- No expensive full-screen lighting effects.
- Correct behaviour for all eight boat orientations.

## Boat state

Distinguish:

- Underway navigation lights.
- Anchored white anchor light.
- Moored harbour lighting.

Use sensible day/night activation.

Check interactions with the new anchor ball and buoy.

## Performance

The Captain reported that night sailing was smooth on Windows.

**Preserve that result.**

Measure the impact of any new light treatment.

---

# 22. WIND FORECAST TIME CONTROLS — MAKE THEM USEFUL

The Captain found 30-minute steps too small.

The underlying forecast changes little over each short interval.

Inspect:

- Weather model temporal variation.
- Snapshot time resolution.
- Existing forecast horizon.
- Cache design.
- Route forecast semantics.
- Actual gameplay use cases.

## Preferred starting proposal

Try:

- **1-hour snapshot increments**.
- **Up to 6 hours ahead**.
- An appropriate limited past-history window, potentially 3–6 hours.

If model variation makes 2-hour steps more informative, evaluate that as an alternative.

Choose based on meaningful observed differences and usability.

## Requirements

- Preserve Now.
- Preserve Past Model Snapshot.
- Preserve FORECAST label.
- Preserve read-only behaviour.
- Preserve uncertainty wording.
- Preserve snapshot caching.
- Preserve appropriate zoom limits.
- No unnecessary global wind work.

Do not artificially exaggerate wind differences.

Do not change the authoritative sailing-weather model merely to make the forecast UI more dramatic.

## Performance

The I017 wind overlay was substantially optimized.

Do not throw away those improvements while changing the selector.

---

# 23. FISHING, ANCHORING AND SAILING INTERACTIONS MUST COEXIST

Consider combined real-world gameplay rather than testing each feature only alone.

## Example scenario

The Captain:

1. Selects a coastal anchorage waypoint.
2. Sails toward it.
3. Adjusts sail trim.
4. Trolls for fish.
5. Receives a bite.
6. Completes the circular timing challenge.
7. Releases a fish below the keep threshold.
8. Arrives at the anchorage.
9. Stops Long Passage.
10. Lowers anchor.
11. Sees the anchor marker and black ball.
12. Goes inside to make coffee.
13. Returns to deck.
14. The pet joins the Captain.
15. Saves the game.
16. Loads the game.
17. Raises anchor.
18. Resumes the route.

All states must remain consistent.

There must be no event that causes the anchorage prompt, fishing result or pet transition to duplicate after reload.

---

# 24. UI AND INPUT CONSISTENCY

Reuse established visual design:

- Warm illustrated surfaces.
- Clear typography.
- Sensible button sizes.
- Existing help panel.
- Keyboard-first interaction with mouse support.
- Context-aware action wheel.
- No giant visible activation circles.

## New controls

Whenever new interactions are introduced, show the relevant shortcut in the appropriate help or contextual UI.

Examples:

- Fishing minigame action key.
- Open fishing preferences.
- Sail Trim.
- Mark waypoint as anchorage.
- Anchor deployment prompt.

Do not rely on undocumented keys.

Do not introduce controls that conflict with:

- Helm controls.
- Q action wheel.
- Existing navigation shortcuts.
- F5 quicksave.
- F9 quickload.
- Existing menu navigation.

---

# 25. SAVE FORMAT AND MIGRATION

Starting save format is 12.

Prefer using existing extensible save structures.

However, I018 introduces potentially persistent state:

- Fishing keep preferences.
- Sail trim.
- Anchorage waypoint type.
- Anchorage progress.
- Pet current area and safe location.
- Catch grade if not already stored.

Audit what actually needs persistence.

## Rules

- Do not force a schema change for purely visual transient animation.
- If format 12 can safely represent new fields, retain it and document defaults.
- If a schema change is genuinely necessary, increment according to project policy.
- Migrate old saves without losing voyages, inventory, trophies or pets.
- Test loading version 0.104a saves.
- Test saving and loading the new version.
- Test cross-process persistence.

Do not simply stamp a new save version without a migration plan.

---

# 26. PERFORMANCE AND RESOURCE BUDGET

I017 reported:

- World wind overlay substantially faster after caching.
- Night-deck lighting expensive in Linux software-rendered tests.
- Windows priority night-sailing test passed.
- World chart first-open cost still significant.
- Worldwide routing and chart data reused from I016.

Protect those improvements.

## Profile

- Fishing minigame idle/open/close.
- Fish sprite rendering.
- Fish blink/tail animation.
- Catch-result panel.
- Inventory with many fish.
- Trophy display with several species.
- Anchorage waypoint editing.
- Route panning with many waypoints.
- Pet movement on deck.
- Sail Trim update cost.
- Long Passage interruptions.
- Night sailing with new exterior lights.

## Specific limits

- Do not animate every fish inventory thumbnail continuously.
- Do not spawn a new timer every time a fish blinks without cleaning it up.
- Do not recalculate worldwide routes during every waypoint drag pixel.
- Do not run pet pathfinding every rendered frame unless necessary.
- Do not repeatedly recalculate anchor suitability when nothing has changed.
- Do not lose the I017 wind cache.

Measure before and after where practical.

---

# 27. VISUAL EVIDENCE IS MANDATORY

Create rendered screenshots and review them.

Important scenes include:

1. Fishing minigame — common fish.
2. Fishing minigame — rare fish.
3. Perfect timing.
4. Missed timing.
5. Illustrated cod.
6. Illustrated mackerel.
7. Illustrated garfish.
8. Illustrated flatfish.
9. Illustrated shark.
10. Junk catch artwork.
11. Fish with eyes open.
12. Fish with eyes closed.
13. Tail in neutral pose.
14. Tail-flick pose.
15. Catch result with weight and grade.
16. Automatic release.
17. Manual release.
18. Kept catch inventory.
19. Trophy presentation.
20. Fishing preferences.
21. Sail Trim control.
22. Optimal versus poor trim feedback.
23. Anchorage waypoint icon.
24. Dragging anchorage waypoint.
25. Anchorage arrival prompt.
26. Boat anchored in daylight, black ball visible.
27. Anchor buoy or rode.
28. Boat anchored at night, white anchor light visible.
29. Pet resting on deck while moored.
30. Pet on deck at anchor.
31. Cabin after lighting refinement.
32. Underway exterior navigation lights.
33. Worldwide route before/after pan fix.
34. Wind preview controls after interval adjustment.

For animation, provide evidence from multiple frames or a short capture method where available.

**A screenshot showing a fish exists does not prove it blinks or flicks its tail.**

Test the animation behaviour explicitly and provide appropriate evidence.

Screenshots should be taken at the game's intended display scale, including 1600×900 where practical.

Review them for artistic coherence.

---

# 28. AUTOMATED TEST REQUIREMENTS

Add focused tests rather than relying solely on a huge final regression.

## FISH tests

- Existing species catalogue loads.
- Every fish species has valid presentation data.
- Sprite lookup resolves correctly.
- Blink and tail states work.
- Animation stops when UI closes.
- Correct rarity.
- Correct number of successful timing checks.
- Constant rotation speed.
- Perfect timing.
- Miss allowance.
- Species and rarity preserved through the minigame.
- Plausible weight ranges.
- Bronze/Silver/Gold by weight.
- No rarity-to-grade confusion.
- Preference filtering.
- Automatic release.
- Manual release.
- Released fish not in trophies.
- Kept fish stored once.
- Shark automatically released.
- Junk excluded from fish trophies.
- No duplicate rewards.
- Fish preferences persist.

## SAIL tests

- Trim input.
- Wind-relative optimal trim.
- Moderate efficiency effect.
- No physics bypass.
- No speed stacking.
- Save/load trim behaviour.
- Long Passage equivalence.
- Correct provisions and wear.
- Fishing encounter pacing.

## ANCH tests

- Anchorage waypoint creation.
- Valid drag.
- Invalid land placement rejected.
- Proper waypoint display.
- Date Line compatibility.
- Arrival detection.
- Acceleration stopped on arrival.
- Anchor prompt.
- Successful anchoring.
- Failed anchoring.
- Declined anchoring.
- Resume after weighing anchor.
- Save/load.
- No route corruption.
- No prompt spam.
- Day anchor ball.
- Night anchor light.
- Buoy/rode state.

## PET tests

- Cabin to deck while moored.
- Deck to cabin while moored.
- Cabin to deck while anchored.
- Safe resting spots.
- No walking over water.
- No clipping outside hull.
- Pet returns to safety on departure.
- Save/load.
- All four boats.

## I017 REGRESSION tests

- World route remains visible during panning.
- Geography wrapping remains correct.
- Weather model unchanged.
- Wind preview selection read-only.
- Lighting contrast.
- Exterior lights.
- Existing quicksave.
- Existing sailing HUD.
- Existing cockpit chartplotter.
- Boat orientation.
- Harbours and docking.

---

# 29. TWO-PROCESS RESTART TESTING

Perform a genuine separate-process save/load test.

## Scenario A — Fishing

- Configure catch preferences.
- Land and keep a fish.
- Release another fish.
- Save.
- Exit game process.
- Launch a new process.
- Load.
- Verify inventory, preferences and trophy correctness.

## Scenario B — Anchorage

- Plot a route with an anchorage waypoint.
- Reach the waypoint.
- Anchor.
- Have the pet outside.
- Save.
- Exit.
- Launch a new process.
- Load.
- Verify vessel position, anchor state, waypoint, pet and route continuation.

## Scenario C — Sailing

- Set Sail Trim.
- Begin a passage.
- Advance time.
- Save.
- Exit.
- Reload.
- Verify trim behaviour, weather, route and stores.

Do not treat a same-process scene reload as equivalent to a complete restart.

---

# 30. MANUAL WINDOWS ACCEPTANCE

Create:

`WINDOWS_ACCEPTANCE_18.md`

Use numbered sections and lettered test codes.

For example:

- 1A — Launch and save migration.
- 2A — World-route panning.
- 3A — Fishing reel-in.
- 4A — Fish art and animation.
- 5A — Catch preferences.
- 6A — Sharks and junk.
- 7A — Sail Trim.
- 8A — Long Passage.
- 9A — Anchorage waypoint.
- 10A — Anchor visual signals.
- 11A — Pet follows outside.
- 12A — Cabin and deck lighting.
- 13A — Wind forecast.
- 14A — Persistence.
- 15A — Performance.
- 16A — Final verdict.

Each test needs:

- What to do.
- Expected behaviour.
- PASS.
- FAIL.
- PARTIAL.
- NOT TESTED.
- Space for observations.

Do not mark Windows acceptance complete.

The Captain and Skipper will perform that testing on Windows.

Atlas will turn this checklist into an interactive form with status selectors and comment fields after delivery.

---

# 31. SHIPYARD EFFICIENCY — CONTINUE MEASURING

I017 supplied useful development-efficiency findings.

Its report recorded:

- 138 logged Godot runs before final regression.
- 47.1 minutes of measured Godot execution.
- A 300-second wasted render-test hang.
- Repeated test-writing runs.
- Expensive routing regression.
- Opportunities for shared test fixtures and better suite targeting.

I018 should benefit from these findings.

## Implement practical improvements

Where feasible:

- Guard rendered test scripts against hanging.
- Use reasonable development-time timeouts.
- Run focused suites while implementing.
- Keep the expensive worldwide all-pairs router regression for appropriate final checkpoints.
- Reuse imported data where possible.
- Record meaningful test durations.
- Avoid unnecessary repeated full screenshot generation.

Keep a section in the I018 report:

**Shipyard Efficiency — Where the Time Went**

Include measured execution time, expensive steps, avoidable work and recommendations.

Do not invent timings.

Do not skip necessary verification to achieve nicer efficiency numbers.

---

# 32. RECOMMENDED CHECKPOINTS

Use normal Git commits and recoverable checkpoints.

## Checkpoint A — Baseline, route display and foundation

- Verify I017 baseline.
- Save I018 assignment.
- Catalogue fishing species and data.
- Inspect anchoring and pet systems.
- Reproduce and fix the disappearing route.
- Add rendered wrap regression.

## Checkpoint B — Fishing core

- Circular timing minigame.
- Rarity and successful-check progression.
- Perfect timing.
- Fair misses.
- Encounter integration.
- Catch result integrity.

## Checkpoint C — Living fish artwork

- All-species art coverage.
- Reusable fish presentation.
- Blink and tail animation.
- Catch reveal.
- Result panel.
- Inventory and trophies.
- Junk and shark art.

## Checkpoint D — Catch preferences and special catches

- Weight-based specimen grades.
- Rarity/size keep thresholds.
- Automatic and manual release.
- Trophy exclusion.
- Shark rules.
- Junk handling.
- Fishing while stopped.

## Checkpoint E — Sail Trim and passage pacing

- Trim slider.
- Feedback and modest efficiency.
- Safe persistence.
- Improved fish interruptions.
- Long Passage regression.

## Checkpoint F — Anchorage waypoints

- Add and drag waypoint.
- Mark as anchorage.
- Safe positioning.
- Route arrival.
- Stop and prompt.
- Resume route.
- Save/load.

## Checkpoint G — Anchor and pet presentation

- Anchor ball.
- Anchor light.
- Buoy/rode.
- Companion follows cabin/deck.
- Safe boat boundaries.
- All four boats.

## Checkpoint H — I017 refinements

- Cabin light contrast.
- Exterior navigation-light polish.
- Wind interval and horizon adjustment.
- Performance review.

## Checkpoint I — Final verification

- Full relevant regression.
- Rendered screenshots.
- Two-process restarts.
- Benchmarks.
- Reports.
- Captain's Orders.
- Version.
- Git push and verification.

The order may change for dependencies.

Do not repeatedly run the entire regression after small art edits.

---

# 33. REQUIREMENT TRACKER

Create:

`ITERATION_18_REQUIREMENTS.md`

Use stable IDs such as:

- MAP — Route overlay correction.
- FISH — Fishing mechanics.
- FART — Fish artwork and animation.
- KEEP — Catch preferences.
- SPEC — Specimen grades.
- SHRK — Sharks and junk.
- TRIM — Sail Trim.
- PASS — Long Passage.
- ANCH — Anchorage waypoints and signals.
- PET — Companion behaviour.
- LIGHT — Lighting refinements.
- WIND — Forecast refinement.
- SAVE — Persistence.
- QA — Testing.
- DOC — Delivery.

For every requirement, record:

- ID.
- Requirement.
- Implementation status.
- Test coverage.
- Screenshot or animation evidence where applicable.
- Known limitation.
- Manual acceptance status.

Do not invent PASS results from tests that were not run.

---

# 34. UPDATE CAPTAINS_ORDERS.md

Preserve the existing authoritative decisions.

Add the approved I018 decisions:

1. Fishing 2.0 uses a constant-speed circular timing interaction.
2. Rarity determines challenge, not weight grade.
3. Perfect hits influence specimen quality modestly.
4. Each supported fish species needs recognizable illustrated artwork.
5. Prominent fish visuals occasionally blink and flick their tails.
6. Art and animation must be lightweight and reusable.
7. Keep preferences filter by rarity and specimen size.
8. Released fish are excluded from trophy records.
9. Sharks are released and are not edible/sellable inventory.
10. Junk catches are occasional and worthless.
11. Sail Trim is optional and offers modest efficiency benefits.
12. Long Passage must remain faithful to normal simulation.
13. A waypoint can be marked as an anchorage.
14. Reaching an anchorage stops the route leg and prompts for normal manual anchoring.
15. The Captain must never be routed onto land by an anchorage waypoint.
16. A black anchor ball appears at anchor in daylight.
17. The appropriate white anchor light appears at night.
18. A modest buoy or rode makes anchoring visually evident.
19. The pet can join the Captain outside while safely moored or anchored.
20. Pet behaviour must remain safe on all four vessels.
21. The I017 world-route display defect is a required carry-forward fix.
22. Cabin light contrast and exterior navigation lights receive refinements.
23. Wind forecast intervals should be useful, not arbitrarily short.
24. I019–I021 remain separate.
25. No selectable difficulty mode is introduced.

Do not overwrite other Captain decisions.

---

# 35. STRICT FUTURE-ITERATION BOUNDARIES

## I019 — The Captain's Watch

Reserved for:

- Clear safety alarms.
- Local spoken alerts.
- Collision-risk encounters.
- Radar-relative-motion gameplay.
- Waking the Captain to respond.
- Anchor-drag warning integration.
- VHF distress calls.
- Optional rescue missions.
- Appropriate renown and rewards.
- Fair event pacing.

Do not build those systems in I018.

If I018 modifies anchoring, keep its state readable by future I019 alarms.

## I020 — A Boat of Your Own

Reserved for:

- Personalizing furniture finishes.
- Upholstery.
- Bedding.
- Decorations.
- Plants and souvenirs.
- TV/entertainment.
- Remote-work laptop.
- Visible equipment upgrades.
- Boat purchases and sales.
- Boatyard.
- Chandlery.
- Sailmaker.
- Fishmonger.
- Unified commerce backend.
- Boat and engine economy.

I018's fish graphics must be ready for the future fishmonger UI.

Do not build the shop now.

## I021 — The Well-Trimmed Ship

Reserved for:

- Dedicated performance and stability.
- Automated playthroughs.
- Economy evaluation.
- Progression balancing.
- Difficulty analysis.
- Potential future difficulty settings.

Do not add a selectable difficulty system in I018.

Do not defer ordinary performance discipline to I021.

---

# 36. FINAL REPORTING

Create:

- `ITERATION_18_ASSIGNMENT.md`
- `ITERATION_18_REQUIREMENTS.md`
- `ITERATION_18_REPORT.md`
- `WINDOWS_ACCEPTANCE_18.md`

Update:

- `CAPTAINS_ORDERS.md`
- Relevant developer/architecture documentation.
- Asset provenance documentation.
- Screenshot and benchmark evidence.

## I018 report must include

1. Verified starting state.
2. Final version.
3. Save format and migration.
4. Checkpoint commits.
5. I017 route-display defect diagnosis and fix.
6. Rendered route-wrap evidence.
7. Fishing 2.0 design.
8. Rarity and timing balance.
9. Perfect-hit behaviour.
10. Fish artwork coverage by species.
11. Fish animation method.
12. Asset provenance.
13. Catch preferences.
14. Trophy exclusion and persistence.
15. Specimen grade calculations.
16. Sharks and junk.
17. Moored/anchored fishing.
18. Sail Trim.
19. Long Passage refinements.
20. Anchorage waypoint design.
21. Anchorage arrival and resume behaviour.
22. Anchor ball, anchor light and buoy.
23. Pet following and safety.
24. Lighting refinements.
25. Wind forecast refinements.
26. Performance before and after.
27. Automated test results.
28. Rendered visual review.
29. Two-process restart tests.
30. Shipyard Efficiency.
31. Known limitations.
32. Windows acceptance status.
33. Git commit and push verification.

Report partial delivery honestly.

Do not state that I018 passed Windows acceptance before the Captain and Skipper verify it.

---

# 37. DEFINITION OF DONE

I018 is ready for Windows sea trials only when the following are genuinely implemented and verified.

## Fishing

- Circular timing minigame replaces the tension-bar system.
- Constant-speed timing interaction is readable.
- Rarity progression works.
- Perfect hits reward skill without changing rarity.
- Fair misses.
- Every actual fish species has an appropriate visual.
- Fish blink and flick their tails when prominently displayed.
- Same species art reused in catch results, inventory and trophies.
- Weight and rarity are separate.
- Bronze/Silver/Gold are weight-based.
- Catch preferences work by rarity and size.
- Automatic and manual releases never create trophy records.
- Sharks are released.
- Junk catches exist and are clearly distinct.
- No duplicate rewards or catches.

## Sailing

- Sail Trim works with actual wind.
- Efficiency changes modestly.
- Sailing remains playable without constant trim adjustment.
- Long Passage interruptions are improved.
- Fast time does not bypass simulation.

## Anchoring

- Waypoints can be marked as anchorages.
- Anchorage markers are clearly visible.
- Dragging and editing work.
- Unsafe positions are rejected or handled safely.
- Anchorage arrival stops the leg.
- Player receives a prompt to anchor.
- Anchor is not magically deployed.
- Remaining voyage can be resumed.
- Black day anchor ball is visible.
- Night anchor light is visible.
- Buoy or rode provides an understandable visual indicator.

## Companionship

- Pet may follow between cabin and deck while moored or anchored.
- Movement feels natural.
- Pet stays in safe areas.
- Departure behaviour is safe.
- Save/load preserves coherent pet state.
- All four boats work.

## I017 carry-forward

- Worldwide route remains visible after horizontal panning.
- Underlying route data remains unchanged.
- Cabin light contrast is improved.
- Exterior navigation lights are better positioned and visible.
- Wind snapshot increments are useful.
- The I017 wind-performance gains remain intact.

## Engineering and delivery

- Existing gameplay still works.
- Saves migrate correctly if needed.
- No critical performance regression.
- Focused and full relevant tests pass.
- Rendered scenes are inspected.
- Two-process save/load tests pass.
- Documents and source attribution are complete.
- Checkpoints are committed.
- Final branch is pushed and verified.
- Windows acceptance is explicitly pending.

---

# 38. FINAL GITHUB HANDOVER

Push the work only to:

https://github.com/crosenlund79/LittleCaptainsHat

On the verified development branch:

`claude/friendly-fermat-dey23f`

Do not create a Windows executable unless explicitly requested.

The Captain's normal deployment process remains:

**GitHub → Branch → Code → Download ZIP → Extract → Open `project.godot` in Godot → Run.**

At completion:

1. State the exact version.
2. State the save format.
3. List checkpoint commits.
4. Report tests actually run.
5. Report screenshot and benchmark locations.
6. Summarize what changed.
7. Identify any remaining limitations.
8. State that Windows acceptance remains pending.
9. Push and verify the remote HEAD.
10. Provide the exact direct GitHub branch URL.

**The last line of your final delivery message must be the clickable direct URL to the development branch containing the delivered work.**

Expected branch URL, if unchanged:

https://github.com/crosenlund79/LittleCaptainsHat/tree/claude/friendly-fermat-dey23f

Do not substitute the general repository homepage.

---

# FINAL CAPTAIN'S ORDERS

Monsieur Claude,

The Captain has a boat, a home, and an entire world to explore.

Now give that journey a little more personality.

When a fish bites, let us see what we've caught.

Let the reel-in challenge feel like a moment of skill rather than a progress bar.

Let a little mackerel blink at us.

Let a cod flick its tail.

Let a magnificent catch feel special, whether we keep it or gently let it go.

Let us choose a sheltered bay on the chart, mark it as tonight's anchorage and sail there.

When we arrive, pause the voyage and ask us to drop anchor.

Let the black anchor ball rise in the rigging.

Let a little buoy bob beside the boat.

Let the white anchor light glow when darkness falls.

Let the cabin lamps cast warm pools of light, with inviting shadows beyond them.

And when the Captain steps onto the deck to enjoy a peaceful evening, let Snøvs come along and settle somewhere safe.

Fix the disappearing worldwide route.

Keep the weather forecasts useful.

Preserve the sailing physics.

Preserve the world.

And above all, preserve the feeling of being aboard a little boat that we genuinely want to come home to.

**COZY FIRST.**

**Small boat. Wide world. Hold onto your hat.**

Proceed with Iteration 18 from the verified I017 baseline.

**REMEMBER: End the final delivery message with the exact direct GitHub development-branch URL.**
