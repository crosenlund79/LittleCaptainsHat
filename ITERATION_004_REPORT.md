# Iteration 004: The Boatyard & Sprite-Ready Vessel Architecture (Report)

**Baseline:** the I003b final UI hotfix, commit `68cf245` (chart sidebar tabs and
simulation pause). **That hotfix has not been explicitly accepted by the owner.**
Iteration 004 builds on it as it was pushed. If the owner's review of the hotfix
asks for changes, they apply on top of this iteration without conflicts: I004 does
not change the chart sidebar or the pause logic.

**Engine:** Godot 4.7.2 stable, GDScript, Compatibility renderer.

**Test environment:** Linux container, Godot headless, plus Xvfb with Mesa llvmpipe
(software OpenGL) for rendered runs.

**Not tested on Windows.** The following have not been verified on Windows:
graphics, performance, input and the feel of the new boats. Everything below was
verified with automated checks and with screenshots from automated runs. See §10
for the owner's Windows checklist.

## 1. Summary

- **Three vessels**, each with its own deck and cabin, collision, stations, spawn
  points, companion spots, sail attachment points, sailing performance and engine:

  | Id | Name | Hull | Layout highlights |
  |---|---|---|---|
  | `starling_33` | Starling 33 | monohull | the existing starter boat, preserved |
  | `halcyon_40` | Halcyon 40 | catamaran | two hulls, bridgedeck saloon, trampoline, wheel at the saloon bulkhead; owner's berth in the port hull, guest hull with heads |
  | `petrel_36` | Petrel 36 | trimaran | central hull with cockpit, coachroof and V-berth; nets and two floats you can walk on; cabin in the main hull only |

- **Boatyard**: a station by the pontoon on every deck, active only while moored in
  harbour. It offers:
  - a list of the boats;
  - an art-only preview;
  - name, hull type, description and specs;
  - a performance comparison computed from the profiles;
  - **Move aboard**, which is free and keeps the time, harbour, companion and
    progress, and puts you on deck by the boatyard.

  Underway the station disappears, and the boatyard and `switch_vessel` refuse.
- **Sprite-ready architecture** (the primary deliverable):
  - gameplay layout (collision, stations, spawns, markers) is separated from art;
  - the art sits in named visual slots that take full-canvas PNGs by file name or
    inspector, with procedural fallback;
  - sail sprites are stretched over the live sails;
  - there are per-vessel templates showing the landmarks;
  - a real sprite swap on the monohull (demo coachroof) leaves collision and
    interactions unchanged, which is tested;
  - [ART_PIPELINE.md](ART_PIPELINE.md) has the art direction and conventions.
- **Persistence**: save version 5 stores `vessel.id`.
  - v4 saves load aboard the monohull.
  - An unknown id falls back to the monohull and the player is told.
- **Tests**:
  - headless: 1164 checks pass (842 before; +322 in the new `test_vessels` suite);
  - rendered run: 1172 checks pass;
  - restart check: 16/16.

## 2. Vessel data

- `VesselDefinition` (`src/vessels/vessel_definition.gd`) has these fields:
  - `id` (stable, saved), `display_name`, `hull_type`, `description`, `specs`;
  - `performance` (`VesselProfile`);
  - `deck_scene`, `cabin_scene`, `deck_visual_scene`;
  - `visual_profile`.
- There is one `.tres` per boat in `data/vessels/`; `vessel_catalog.tres` lists them
  in order, starter first.
- `GameSession` is still the only writer of state:
  - `get_vessel_definition()` and `get_vessel_profile()` replace the single default
    profile everywhere (Simulation, controller, ETA, helm check);
  - `can_change_vessel()` and `switch_vessel(id)` decide and perform the change.

  On a switch, the propulsion state is reset, so no stale rolling averages or timers
  from another hull carry over. The deck is entered at `from_boatyard`, and
  `vessel_changed` makes the Simulation drop cached ETAs.
- `App` takes boat area scenes from the active definition. The old
  `boat_area_scenes` dictionary and `src/boat/exterior.tscn` / `interior.tscn` are
  gone. A switch is an ordinary scene change through the `SceneRouter`, so there is
  never a duplicate area, player or companion (tested).

### Performance (computed from the profiles; the boatyard shows the same numbers)

| | Starling 33 | Halcyon 40 | Petrel 36 |
|---|---|---|---|
| Top speed under sail | 10.0 kn | 11.0 kn | 14.0 kn |
| 12 kn wind at 45° | 2.6 kn | 1.1 kn | 5.2 kn |
| 12 kn wind at 90° | 6.8 kn | 7.0 kn | 10.6 kn |
| 12 kn wind at 150° | 6.9 kn | 6.8 kn | 10.2 kn |
| Under engine | 5.0 kn | 6.5 kn (twin diesels) | 5.5 kn (outboard) |
| No sailing below | 40° | 40° | 32° |
| Spinnaker from | 115° | 100° | 120° |

The character of each boat:
- the catamaran is roomy, reaches well and points poorly;
- the trimaran is the quickest boat and good upwind;
- the monohull is the all-rounder.

These are game values, not real polars.

## 3. Scene architecture (all six areas)

```
Exterior / Interior (BoatArea)
  Surroundings (deck: water, Mooring) | Backdrop (cabin)
  Visual        instance of deck_visual.tscn / cabin_visual.tscn (art only)
  Layout
    Collision       BoatFixture (collision only) + hull boundary
    Stations        companionway, helm, boatyard | companionway, nav_table, bed
    SpawnPoints     start, from_cabin, from_boatyard | start, from_deck, v_berth
    SailMarkers     Mast, Tack, BoomEnd, Traveller, JibSheetLead, SpinnakerSheetLead
    CompanionSpots  settee, nav_station, v_berth, cabin_floor, companionway, seating
  SailRig (deck) | Companion (cabin)
  Player, Camera2D
```

- The monohull's scenes were split from the I003b scenes. Collision, stations,
  spawn points and companion spots are the same as before.
  - One deliberate change: the helm sensor radius went from 30 to 40. The walking
    test showed that the helm could only be reached at the very edge of the
    player's reach, from forward of the pedestal.
  - The procedural art was moved into visual slots unchanged.
- The catamaran and trimaran scenes were bootstrapped by
  `tools/vessels/build_multihull_scenes.py`, so art and collision derive from the
  same numbers. They are now ordinary scenes, and the generator refuses to
  overwrite without `--force`.
- `BoatFixture` is collision only (outline drawn in the editor only).
  `ProceduralShape` is drawing only.
- Stations draw a brass focus ring sized from their shape, so feedback no longer
  depends on highlighting a piece of art.
- The companion's resting spots are semantic ids with per-cabin markers, so the
  cat or dog keeps its spot when you change boats.

## 4. Sprite-ready visuals

- **Slots:**
  - deck: ShadowVisual, HullBase, DeckBase, Coachroof, DeckDetails, RiggingVisual,
    MastVisual, plus BoomVisual, MainSailVisual, HeadSailVisual and
    SpinnakerVisual via the SailRig;
  - cabin: CabinBase, FurnitureVisual, CabinDetails, plus CompanionVisual
    (`assets/companions/<kind>.png`).
- **Fallback order** per slot: the texture assigned in the profile, then
  `<art_folder>/<deck|cabin>/<file>.png`, then procedural. A missing file never
  breaks a boat (tested with a non-existent art folder).
- **Placement:** a sprite is a full-canvas PNG with its top-left at
  `canvas.position`, scaled uniformly to the canvas width. An aspect mismatch shows
  anyway and logs a warning (tested).
- **Sails:** the sprite is stretched over the live sail as a UV-mapped triangle
  strip:
  - left edge = luff, right edge = clew, top = leech (spinnaker: leading edge),
    bottom = foot;
  - trim, hoist and breathing apply unchanged, and the sail's shape is identical
    with or without a sprite (tested on all three boats, screenshot
    `43b_deck_sail_sprites_halcyon_40.png`);
  - limits: no cloth simulation and no sprite-sheet animation; furled sails stay
    procedural.
- **Cabin:** prepared the same way. Collision is never derived from art or alpha.
- **Templates:** `assets/vessels/<id>/templates/{deck,cabin}_{reference,guide}.png`
  at 2 px per unit, rendered by `tools/vessels/render_art_templates.tscn`. They show
  collision, walkable fixtures, stations, spawns (with the player's radius),
  companion spots, sail markers, a 50-unit grid and the axes. The folder has a
  `.gdignore`, so Godot does not import the templates.
- **Demo:** `tools/vessels/make_demo_coachroof.py` draws a hand-drawn-style
  coachroof (wobbly ink outline, uneven wash, hatching) at
  `assets/vessels/starling_33/demo/deck/coachroof.png`. The profile
  `data/vessels/starling_33_visuals_demo.tres` points at it.
  - The tests apply it in the running game and check four things:
    - the coachroof slot shows the sprite and the other slots stay procedural;
    - the sprite covers exactly the canvas;
    - every node in `Layout` is in the identical position;
    - the coachroof still blocks the player, and the helm still works.
  - It is **not enabled by default**, since a single drawn piece among placeholders
    is only a demonstration. Screenshots: `45_monohull_procedural.png` and
    `46_monohull_demo_coachroof_sprite.png`.

## 5. Boatyard

- **Access.** `src/ui/boatyard_menu.tscn` / `.gd` is opened from the deck station,
  by walking to it and pressing E (tested); there is a "BOATYARD" sign on the
  pontoon.
- **Browsing.** Use Up/Down or click.
- **Preview.** The preview instantiates the boat's `deck_visual_scene` in a
  `SubViewport` with its profile, so it shows the real art, sprites included,
  without gameplay nodes (tested).
- **Choosing.** Your current boat is marked and cannot be chosen again.
  **Move aboard** switches, closes the boatyard, shows the new deck at
  `from_boatyard`, and says "Welcome aboard the …".
- **Underway.** The station is hidden and disabled; `App.open_boatyard()` explains
  that the boatyard is only open in harbour, and `GameSession.switch_vessel()`
  refuses (all tested).

## 6. Persistence

- **Save version 5.**
  - `session.vessel.id` holds the stable id.
  - `_migrate_4_to_5` sets `starling_33`; the full migration chain is
    1 → 2 → 3 → 4 → 5.
  - An unknown id loads aboard the Starling 33 at the `start` spawn, and a
    notification names the unknown boat. The rest of the save is kept.
- **Tested in game** (save, back to the main menu, load):
  - in the catamaran's cabin;
  - on the catamaran's deck;
  - underway on the trimaran;
  - after switching boats back to the monohull.

  Each time, the boat, the area, the player position, the voyage and the time come
  back.
- **Restart check** (two processes): the active vessel (`petrel_36`, underway) is
  restored after a restart, along with everything checked before.

## 7. Tests added (`tests/suites/test_vessels.gd`, 322 checks)

- **Catalog and definitions:**
  - three boats, starter first;
  - complete definitions;
  - conventional art folders;
  - unknown ids are not found.
- **Scenes:**
  - every deck and cabin instantiates as the right `BoatArea`;
  - every visual slot exists, and `Visual` holds no physics;
  - all stations, spawns, sail markers and companion spots exist;
  - the deck visuals work alone, for the preview.
- **Walking:** a flood fill with the real player circle against the real collision,
  on all six areas. Every spawn is free and connected, every station can be walked
  to, and the walkable area stays within `walkable_bounds`.
- **Performance:** each boat has its own profile, with the expected order of top
  speed, beam-reach speed, pointing and engine. The boatyard numbers come from the
  profiles.
- **Boatyard:** everything in §5, plus no duplicate areas, kept time, harbour and
  companion, reset propulsion, and refusal of an unknown id.
- **Each boat:**
  - companionway below;
  - the companion on that cabin's markers for each of its spots, and petting;
  - chart from the nav station and back to the same cabin;
  - sleep at the berth, waking beside it 2 hours later;
  - departure, with speed matching that boat's profile;
  - sails rigged on that deck's markers;
  - beam reach with sails to leeward;
  - sail sprites keeping the sail shape;
  - spinnaker on its pole ahead of the bow;
  - motoring with the sails furled and the engine sound.
- **Sprites:**
  - the fallback order;
  - the conventional paths;
  - procedural-only;
  - aspect ratio scaling;
  - hiding and restoring the procedural art;
  - the demo coachroof in game with the layout unchanged.
- **Time:** 20× and pause aboard the trimaran; the chart opens and returns to the
  trimaran.
- **Persistence and migration:** see §6.

Existing tests were updated only for moved node paths:
- `Fittings/SailRig` became `SailRig`;
- `SpawnPoints/...` became `Layout/SpawnPoints/...`;
- spot positions come from the cabin's markers;
- the spinnaker pole length comes from the rig.

The test runner gained `--only=<name>` to run a single suite.

## 8. Defects found and fixed during the iteration

- **Scene generator.** The one-off script that split the monohull scenes gave
  collision fixtures the wrong script (the interactable instead of `BoatFixture`).
  It was caught by checking the generated scenes, and fixed and regenerated before
  any test ran.
- **Catamaran cabin.** The first layout put the settee so close to the opening into
  the owner's hull that the player could not get to the berth, and a wardrobe
  overlapped the wake-up spot. The walking test caught both.
- **Monohull helm.** It was reachable only at the extreme edge of the player's
  reach (an existing tight spot); the sensor was widened (see §3).
- **Boatyard arrow keys.** They were swallowed by GUI focus navigation; the
  boatyard now handles Up/Down before it.

## 9. Verification

| Run | Result |
|---|---|
| Headless suite (`godot --headless --path . res://tests/test_runner.tscn`) | **1164 passed, 0 failed** |
| Rendered suite (Xvfb, opengl3, with screenshots) | **1172 passed, 0 failed** (8 more checks than headless: screenshot-only checks), 64 screenshots |
| Restart check (`--phase=write`, then `--phase=read`) | **16/16, PASS** |
| Art templates rendered for all 3 boats × deck/cabin × reference/guide | 12 images |

New screenshots in `docs/screenshots/`:
- `40_boatyard_*`: the boatyard;
- `41_catamaran_deck_after_switch`;
- `42_cabin_*`: the cabins;
- `43_deck_sailing_petrel_36` and `43b_deck_sail_sprites_halcyon_40`;
- `44_deck_spinnaker_halcyon_40`;
- `45_monohull_procedural` / `46_monohull_demo_coachroof_sprite`.

## 10. Windows test list for the owner

Please check on Windows (each with the "expected" behaviour):

1. **New Game.** You start on the Starling 33 as before. Walk the deck and cabin:
   collision, the companionway, the helm (now a little easier to reach), the
   chart, the berth, and petting the cat or dog.
2. **Boatyard.** On deck in Copenhagen, walk to the pontoon side amidships ("Visit
   the boatyard", brass ring) and press E.
   - The boatyard opens over the deck.
   - Up/Down and clicks browse; the preview shows each boat.
   - The comparison table and text are readable at 100% and 130% interface scale.
3. **Move aboard the Halcyon 40.**
   - The catamaran's deck appears, and you stand by the boatyard station.
   - The time and harbour are unchanged, and the notification is shown.
   - Walk around both hulls, the cockpit, the trampoline and the bows.
   - Go below: the saloon, both hulls through the steps, the owner's berth
     (forward, port), the nav station; the cat or dog is in its spot.
4. **Move aboard the Petrel 36.**
   - Walk the main hull, both nets and both floats.
   - Below: galley, nav station, settees, V-berth.
5. **On each boat:**
   - plot a course and depart from the helm;
   - check that the HUD speed differs between boats in the same wind;
   - watch the sails on deck (beam reach, spinnaker downwind, furled when
     motoring);
   - check that the engine sound plays when motoring.
6. **Underway.** The boatyard station is gone from the deck.
7. **Time.** Pause, 1×, 5× and 20× work on each boat, and the chart opens and
   closes back to the right boat.
8. **Save and load:**
   - save on the catamaran in the cabin, quit the game, start it and load: you are
     back in the same place on the same boat;
   - repeat underway on the trimaran;
   - load an older I003b save: you are on the Starling 33.
9. **Performance.** Check the frame rate on the catamaran's deck while sailing
   with the spinnaker, which has the largest drawn area.
10. **Optional (art pipeline).**
    - Copy `assets/vessels/starling_33/demo/deck/coachroof.png` to
      `assets/vessels/starling_33/deck/` and start the game from the editor: the
      Starling shows the drawn coachroof.
    - Delete the copy: the procedural coachroof returns.

## 11. Limitations and deviations

- **Art.** The boats are still procedural placeholders. The pipeline, templates and
  one demo sprite are delivered; the real art is not.
- **New layouts.** The catamaran and trimaran layouts are first versions. They were
  checked by automated walking and interaction tests and by screenshots, not by
  play-testing on Windows.
- **Companion art.** The companion sprite is shared by all boats (kind-specific,
  not vessel-specific).
- **Sail sprites** stretch over the sail shape; they cannot fold, flog or animate
  frame by frame.
- **Not in this iteration, as specified:** world map, more vessels, currency or
  buying, maintenance, upgrades, decoration, inventory, crew, NPCs, more pet
  systems, weather mechanics.
- **Boatyard preview.** It shows the deck art only (no cabin view and no sails).
