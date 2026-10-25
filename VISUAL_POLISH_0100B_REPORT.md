# Little Captain's Hat 0.100b: A Living Little World

A visual polish release with one new starter boat. Every change here is
presentation, except the new boat and the official boat names, which were
integrated with the smallest possible changes to data and tests.

None of the new artwork has been reviewed by the owner yet. Everything below
is offered for review, not presented as approved.

## 1. Repository and starting point

- Repository: `crosenlund79/LittleCaptainsHat`. This is the new development
  repository; the archived Next Harbor repository was not touched.
- Branch: `claude/friendly-fermat-dey23f`.
- Verified starting commit: `8e640d7` ("V01 Checkpoint E: diagnostic session
  log, verification, 0.100a"). Before any edit I checked:
  - the remote (`crosenlund79/LittleCaptainsHat`, not NomadicSailor and not the
    archived repository);
  - the branch;
  - the version, 0.100a.
- Checkpoint commits on the branch:

  | Checkpoint | Commit | Content |
  |---|---|---|
  | A | `e61b7de` | illustrated sailor with walking arms |
  | B | `0cdd73d` | marine teak decking and living water |
  | C | `826afdf` | illustrated profiles for the Halcyon 40 (Clam 40) and Petrel 36 (Frogleap 36) |
  | D | `277282e` | Arctic Wanderer 26 starter and official boat names |
  | E | `57d9781` | wider underway framing, wind-driven waves checked |
  | F | see the delivery message | tests, docs, version and release |

## 2. Version decision

- **0.100b**, set in `src/app/game_version.gd`:
  - `DISPLAY` is "0.100b" and `MACHINE` is "0.100.2";
  - `project.godot` `config/version` matches, and a test keeps the two equal.
- **The save format stays at version 10.** Nothing new needed to be saved:
  - the new boat is just another vessel id;
  - only the starter boat of *new* games changed.

  The only persistence change is in the v4→v5 migration. It used to write
  "the current starter" into very old saves; it now writes `starling_33`
  literally, the starter boat of that era. So the same old save still loads
  aboard the same boat as before.
- The release tag `v0.100b` is created only after the final push (see the
  delivery message for whether the proxy accepted it).

## 3. The sailor (Task A)

- `src/player/sailor_drawing.gd` is new: a static, procedural top-down sailor.
  - It has an inked head with hair, a cream jumper with navy stripes, shoulders,
    and two arms with hands.
  - The arms swing gently and oppositely while walking.
- The swing is driven by the distance actually walked (`Player._walk_phase`,
  one stride is 46 units), so it stops against a wall. It eases back to rest
  when the player stops. No animation framework is used.
- `Player.get_carry_point()` returns the left hand, which is where a carried
  hat is now held (`PlayerHat`, at 0.46 scale).
- The worn hat was re-sized to the new head (`worn_size` 27 in
  `data/hat/hat_art.tres`). It looks coherent worn, carried, stored on the
  hook and blowing away; see the screenshots in §11.
- Unchanged: collision (radius 20), movement, interaction reach, petting and
  every hat animation and state. The hat-loss rules were not touched.

## 4. Marine teak (Task B, C)

**No reference photographs.** The reference photographs mentioned in the
assignment were **not accessible** from this conversation. The teak follows
general knowledge of yacht decks, not the owner's photos.

The teak is built in `tools/vessels/illustrate.py` and shared by every boat.
`teak_deck()` paints a deck like this:

- **Strips:** long, narrow strips (about 8 px) running fore and aft, with dark
  caulking, an occasional pale holly line and slight colour variation from
  strip to strip.
- **Margin boards:** they follow the deck edge and run around every hole (the
  coachroof, the cockpit and the hatches), so the strips meet them cleanly.
- **Sprung strips:** three strips are bent along the curve of the hull near the
  sheer, and taper towards the bow.
- **King plank:** an optional king plank runs down the monohull foredecks.

`teak_sole()` paints the cockpit sole: a finer teak-and-holly grid, so it reads
differently from the side decks. Cockpit benches are teak with their own
margin.

The aim was a deck that reads as yacht teak, not indoor flooring. The Wing 33's
deck was repainted with it, and the other boats got it through the new
painter (§6).

## 5. Living water and harbour ambience (Task B)

The water is drawn by `src/water/water_life.gd`. `BoatArea` adds it to every
deck, above the water and under the boat. It only appears with the Illustrated
art; Classic art keeps the old static ripples.

**In harbour:**

- slow ripple rings, wavelets and warm glints;
- water lapping along each hull's waterline and along the pontoon edge;
- at most six drifting things, chosen by the harbour's broad character:

  | Atmosphere | Drifting things | Used for |
  |---|---|---|
  | `marina` | the odd leaf | everywhere else |
  | `coastal` | seaweed and foam | island harbours |
  | `urban` | leaves and occasionally a scrap of paper | major ports, and Copenhagen (set explicitly in its harbour art) |

  These are moods, not claims about any real harbour: no harbour is shown as
  dirty, and nothing factual is invented.
- Everything moves slowly, wraps around the visible area and never
  accumulates. The counts are fixed: 70 crests, 6 drifters, 8 rings and 34
  wavelets at most.
- It runs on real time with a fixed seed. It keeps moving gently while the
  game clock is paused, and stops when a menu pauses the scene, like the
  sails.
- It is cosmetic only: no collision and no gameplay effect.

**Underway:** see §9.

## 6. Clam 40 and Frogleap 36 artwork (Task D)

The new `tools/vessels/paint_illustrated_vessel.py` paints a boat's illustrated
layers from its own `deck_visual.tscn` and `cabin_visual.tscn`. It maps every
shape's colour to a material:

- teak deck, cockpit sole, cushions, berths with blankets and pillows;
- glass, metal, tiles and rope nets.

Because the art comes from the same shapes as the collision, it stays aligned
with it.

- **Clam 40** (`halcyon_40`, catamaran):
  - teak hull decks and bridgedeck, a rope-mesh trampoline;
  - the saloon roof with windows and an herb box;
  - the cabin: two hulls with berths, an ensuite, a heads and a bunk, a saloon
    with galley, settee, rug, books and a plant.
- **Frogleap 36** (`petrel_36`, trimaran):
  - a teak main hull with king plank, teak amas, rope safety nets;
  - the cabin: a compact saloon, galley, chart table and V-berth.
- Both share the family style: ink outlines, warm muted colours and the same
  teak. They are distinct boats, not scaled copies of the Wing 33.
- Preserved:
  - geometry, stations, spawns and collision (the existing layout tests
    compare them);
  - provisioning visuals and damage overlays (drawn over the art);
  - companion spots and the hat hooks;
  - the classic profiles, one setting away.
- Data: `data/vessels/halcyon_40_visuals_illustrated.tres`, the same file for
  `petrel_36`, and PNGs under `assets/vessels/<id>/illustrated/`.

## 7. The Arctic Wanderer 26 and the official names (Task E, amendment)

- **New boat:** id `arctic_wanderer_26`, display name **Arctic Wanderer 26**.
  It is first in the catalog and is `VesselCatalog.STARTER_ID`, so every
  **new game starts aboard it**.
- **Size:** 770 scene units long against the Wing 33's 980, with a
  proportionally narrower beam. It is convincingly smaller because the
  proportions changed, not because the Wing was shrunk:
  - a short cockpit with coamings and a **tiller** (helm prompt "Take the
    tiller");
  - a modest coachroof with portlights, a sliding hatch and a forehatch;
  - a short foredeck with an anchor locker and a pulpit.
- **One-level cabin:** companionway steps over the engine box, a small galley
  with the provisions display, a chart table, two settees with a drop-leaf
  table, a compression post, a bulkhead, and a V-berth forward. There are six
  companion spots and a hat hook (starboard, above the forward end of the
  settee).
- **Scenes** are generated once by `tools/vessels/build_arctic_wanderer_26.py`,
  which reuses the multihull builder's helpers. The illustrated art comes from
  the generic painter.
- **Performance:** `data/vessel/arctic_wanderer_26.tres`. The values are
  conservative:

  | Setting | Value |
  |---|---|
  | Top speed under sail | 8 kn |
  | Wind speed scale | 9.5 kn |
  | Light air from / full at | 1.0 kn / 3.4 kn |
  | Spinnaker bonus | ×1.08 |
  | Engine | the usual 5 kn |
  | Weather damage factor | 1.1 |

- **Price:** an informational "Guide price: ~€28,000 used (for reference)"
  row in the boatyard specs. There is no purchase economy. Starting funds are
  unchanged and the other three boats stay free to switch to.
- **Official names**, display only (ids, saves, handling, prices and sizes are
  unchanged):

  | Old name | Official name | Internal id (unchanged) |
  |---|---|---|
  | Starling 33 | **Wing 33** | `starling_33` |
  | Halcyon 40 | **Clam 40** | `halcyon_40` |
  | Petrel 36 | **Frogleap 36** | `petrel_36` |

  The new names appear in the boatyard, the welcome toasts and the Captain's
  Log (which reads names from the catalog). The Wing 33's description no
  longer calls it the boat you started with; the Settings tooltip and the
  docs are updated too. Historical reports keep the old names.

## 8. Save compatibility

- Saves store the vessel id, and every save keeps the boat it names. This is
  tested by round trips aboard every boat, including the 26.
- 0.100a saves aboard the Wing 33 (`starling_33`) load aboard the Wing 33.
- Iteration 003b saves (v4, no vessel) still load aboard `starling_33`.
- A save naming an unknown boat falls back to the starter (now the 26), and
  the player is told, as before.
- No save data is converted, and no existing save is ever moved to the new
  boat.

## 9. Sailing camera and wind-driven waves (Task F)

**Camera**

- On departure the deck camera eases out to 0.86× the scene's harbour zoom,
  and eases back on arrival or rescue.
  - The transition is a 1.8 s sine tween (`BoatArea.UNDERWAY_ZOOM_FACTOR`,
    `ZOOM_TRANSITION_S`).
  - The camera does not move, so there is no jitter.
  - `SailRig` keeps its spinnaker offset.

**Waves**

- Underway, the crests lie across the WeatherModel wind at the boat, seen
  relative to the course (deck coordinates), and drift downwind.
- Stronger wind gives more and livelier crests: 18 + 1.6 per knot, capped at
  70, with white flecks from 20 kn.
- The boat's own speed streams the crests aft.
- Calm water stays calm. The waves are cosmetic only: no effect on sailing,
  routing or weather.

## 10. Files and visual assets

**Code**
- `src/player/sailor_drawing.gd` (new), `src/player/player.gd`
- `src/hat/player_hat.gd`, `src/hat/hat_art.gd`
- `src/water/water_life.gd` (new), `src/boat/boat_area.gd` (water and camera)
- `src/harbour/harbour_art.gd` (atmosphere)
- `src/vessels/vessel_catalog.gd` (starter), `src/vessels/vessel_definition.gd` (comment)
- `src/core/session_state.gd` (default vessel = starter)
- `src/persistence/save_manager.gd` (literal id in the v4→v5 migration)
- `src/app/game_version.gd`, `src/ui/settings_menu.gd`, `src/settings/settings_manager.gd`

**Scenes**
- `src/vessels/arctic_wanderer_26/{deck,cabin,deck_visual,cabin_visual}.tscn` (new)

**Data**
- `data/vessel/arctic_wanderer_26.tres`
- `data/vessels/arctic_wanderer_26*.tres`
- `data/vessels/{halcyon_40,petrel_36}_visuals_illustrated.tres`
- `data/vessels/{starling_33,halcyon_40,petrel_36}.tres` (names, illustrated profiles)
- `data/vessels/vessel_catalog.tres`
- `data/harbours/copenhagen.tres`, `data/hat/hat_art.tres`

**Art**
- `assets/vessels/{arctic_wanderer_26,halcyon_40,petrel_36}/illustrated/{deck,cabin}/*.png` (new)
- `assets/vessels/starling_33/illustrated/deck/deck_base.png` (repainted with marine teak)
- The Wing 33's V01 cabin layers and the owner's cat drawings are untouched
  (a test checks the owner's files by MD5).

**Tools**
- `tools/vessels/illustrate.py` (new shared toolkit)
- `tools/vessels/paint_illustrated_vessel.py` (new)
- `tools/vessels/build_arctic_wanderer_26.py` (new)
- `tools/vessels/paint_illustrated_starling.py` (now uses the toolkit)

**Tests**
- `tests/suites/test_living_world.gd` (new)
- `tests/test_runner.gd` (`board()` fixture)
- Updated suites: vessels, hat, living, life aboard, gameplay flow, sailing,
  reassessment, upkeep, Captain's Log, visual prototype, branding, diagnostics

**Docs**
- this report, README, ARCHITECTURE
- DEV_GUIDES: VESSEL_ART (illustrated profiles for every boat, the painters,
  marine teak, living water), CAPTAINS_HAT (hooks on four boats), SPRITES
- screenshots in `docs/screenshots/0100b/`

## 11. Before and after

The "before" images are the existing V01 screenshots in `docs/screenshots/`;
the "after" images are in `docs/screenshots/0100b/`.

| Subject | Before (0.100a) | After (0.100b) |
|---|---|---|
| Wing 33 deck: plain planks → marine teak | `141_starling_deck_illustrated.png` | `0100b/162_deck_starling_33.png` |
| Copenhagen harbour water | `145_copenhagen_harbour_illustrated.png` | `0100b/161_moored_water_copenhagen.png` |
| Clam 40 (classic art) → illustrated | `149_harbour_halcyon_40.png` | `0100b/162_deck_halcyon_40.png`, `0100b/163_cabin_halcyon_40.png` |
| Frogleap 36 (classic art) → illustrated | `149_harbour_petrel_36.png` | `0100b/162_deck_petrel_36.png`, `0100b/163_cabin_petrel_36.png` |
| Sailor with hat | `121_hat_worn_starling_33.png` | `0100b/121_hat_worn_starling_33.png` |
| Boatyard | `102_boatyard_starling_33.png` | `0100b/40_boatyard_arctic_wanderer_26.png` |

More 0.100b captures:

- **Sailor:** walking without the hat `160_sailor_walking.png`; the hat worn
  aboard the 26 `121_hat_worn_arctic_wanderer_26.png`; carried on deck
  `122_hat_carried_deck.png`; on the 26's hook
  `120_hat_on_hook_arctic_wanderer_26.png`.
- **Arctic Wanderer 26:** deck `162_deck_arctic_wanderer_26.png`, cabin
  `163_cabin_arctic_wanderer_26.png`, Wing 33 cabin
  `163_cabin_starling_33.png`.
- **Water and waves:** generic marina harbour (Kiel)
  `148_kiel_generic_harbour.png`; light wind (7 kn)
  `164_sailing_light_wind.png`; strong wind (26 kn)
  `165_sailing_strong_wind.png`, where the crests lie across the westerly
  wind and are denser and brighter; underway framing
  `166_underway_framing.png`.
- **Harbour services stay legible:** `149_harbour_halcyon_40.png`,
  `149_harbour_petrel_36.png` (the 0100b versions) and
  `93_boatyard_after_repair_restock.png`.
- **Damage overlay over illustrated art:** `85_damage_halcyon_40_15.png`.
- **Classic art still available:** `140_starling_deck_classic.png`.

## 12. Tests actually run

All suites ran headless with Godot 4.7.2. Screenshots came from rendered runs
under Xvfb (OpenGL 3, software rendering).

**Targeted checks**

New suite `test_living_world` (47 checks):
- the sailor's collision is unchanged, the arms rest when still and swing
  while walking, then come back to rest;
- the water atmospheres (Copenhagen urban, an island coastal, a small mainland
  harbour marina);
- moored water: drifters within their limit, hull laps, art only, drawn above
  the water and under the boat, still moving with the clock paused, hidden in
  Classic;
- all four boats have an illustrated teak deck, an illustrated cabin, a hat
  hook and hull laps;
- underway: crests aligned with the WeatherModel wind relative to the
  heading; more crests at 26 kn than at 7 kn, capped at 70;
- the camera eases out on departure (no jump), settles at 0.86× and returns
  on arrival.

`test_vessels` (432 checks):
- four vessels with the starter first; a new game starts aboard the 26; the
  official names; the 26 is smaller and slower than the Wing 33 with a 5 kn
  engine;
- per boat, reachability of every station and spawn (the 26 included);
- the boatyard with four boats, including the Clam 40 welcome toast;
- save/load round trips aboard the 26 (cabin and deck) and the other boats;
- the v4 save loads aboard `starling_33`; an unknown id falls back to the 26.

Other targeted suites:

| Suite | Checks | What it covers |
|---|---|---|
| `test_hat` | 197 | hat hooks and petting compatibility on all four boats, the hat surviving boat switches in every state |
| `test_living` | 56 | life aboard every boat, the 26 included |
| `test_upkeep` | 226 | storm damage on every boat; new: a rescue aboard the 26 keeps the boat and leaves the hat untouched |
| `test_upkeep_ui` | 94 | provisions, the grocery store bought from a new game (aboard the 26), the boatyard |
| `test_visual_prototype` | 74 | the Clam 40 and Frogleap 36 now have illustrated profiles with replaceable PNG slots; the classic art is still procedural and one setting away |
| `test_companion_art` | 77 | companions stay reachable and pettable |

Smoke-test coverage across the required list:

- **Sailing and routing:** new game → chart → plotted route → departure →
  arrival, in `test_gameplay_flow`, `test_sailing`, `test_routing` and
  `test_reassessment`.
- **Cabin/deck transitions and stations:** `test_gameplay_flow`,
  `test_life_aboard` and `test_vessels`.

**Restart check:** both processes (`--phase=write`, then `--phase=read`)
passed. Settings, saves, the active vessel, conditions, the hat and the
Captain's Log all survived the restart.

**How suites written for the old starter were handled.** Several older suites
have walks or timings scripted for the Wing 33's layout and speeds: gameplay
flow, life aboard, sailing, reassessment and visual prototype. Each one now:

1. checks that the new game starts aboard the Arctic Wanderer 26;
2. boards the Wing 33 explicitly with `t.board(&"starling_33", app)`.

Nothing was skipped or weakened. The 26 itself is covered by the all-boats
suites.

## 13. Broader regression

Central persistence and scene logic were touched (starter id, session
default, migration, BoatArea), so **the full headless suite was run**: every
suite in `tests/test_runner.gd`. **Final run (with every 0.100b change):
2747 checks passed, 0 failed**, exit code 0. A full run earlier in Checkpoint F had 2743 checks passing and one
failure, a version string hard-coded to 0.100a in `test_diagnostics`. That
check was fixed and re-run.

A complete rendered screenshot campaign of every suite was **not** run, as
the lean testing policy allows. Rendered runs were made for: living world,
hat, visual prototype, vessels and upkeep UI.

## 14. Performance

Measured with a temporary script (not committed). It compared the deck with
the water on and off over 300 frames, after a warm-up.

**Headless (script cost only)**

| Situation | Extra cost of the water |
|---|---|
| Moored in Copenhagen | about 0.5–0.9 ms per frame |
| Underway at 34 kn with the full 70 crests | about 0.6–0.8 ms per frame |

**Rendered (Xvfb software OpenGL, so absolute numbers are pessimistic)**

- At first, each crest and ripple was its own antialiased polyline. That cost
  about 440 extra draw calls underway (533 against 89 with the water off).
- In Checkpoint F the strokes were batched into one `draw_multiline_colors`
  call per line width. Underway this now costs about 25 extra draw calls (114
  against 89), with the same look.

**Other notes**

- Nothing accumulates: the element counts are fixed and created once.
- There are no particle systems and no per-frame node creation.
- The wind is read twice a second, not every frame.
- The illustrated layers are static textures (one sprite per slot, as before),
  so their cost is texture memory: about 7 slot PNGs per boat at 2 px per
  unit.
- The first measuring window after a scene loads shows a large one-off spike
  whether the water is on or off. It is scene start-up, not the water.

## 15. Known visual compromises

- **Arctic Wanderer 26:**
  - the zoom is 1.5 against the Wing 33's 1.42, so on screen it looks only
    somewhat smaller than the Wing; side by side in the boatyard the
    difference is clear;
  - the sails use the shared sail rig, so in strong wind a spinnaker can show
    on this small boat. That is existing sailing logic, unchanged.
- **Wing 33:** its cabin layers are still V01's (only the deck was repainted).
- **Clam 40 and Frogleap 36:** their art comes from the scenes' placeholder
  shapes, so some furniture looks geometric (simple rectangles for lockers and
  desks). Hand-drawn layers can replace any slot without code changes.
- **Water:**
  - it is drawn, not painted; strokes are small curved lines, not textures;
  - at the wider underway zoom, the same 70 crests spread over a larger area.
- **Boatyard:** the details panel scrolls (it has a fixed size since 005b).
  The 26's guide price is the third spec row; Engine and Accommodation may
  need a scroll.
- **Sailor:** drawn procedurally, not a sprite.

## 16. Remaining Windows acceptance checks

- The look at real resolution on Windows (Compatibility renderer, GPU):
  - teak strip width;
  - ink line weight;
  - how readable the water is at 100 % and 130 % interface scale.
- The smoothness of the camera ease and of the water at 60 fps on the owner's
  machine.
- Taste checks, which only the owner can judge:
  - the sailor's proportions with and without the hat;
  - the 26's proportions;
  - the Clam and Frogleap interiors.
- Loading an existing 0.100a save on Windows: it must come back aboard the same
  boat (Wing 33 = the old Starling 33).

## 17. Windows visual-testing guide (about 15 minutes)

1. **Get the project.** On GitHub, open the branch
   `claude/friendly-fermat-dey23f` and choose **Code → Download ZIP**. Extract
   it, open `project.godot` in Godot 4.7, and press **Run** (F5).
2. **New game.** Choose New Game. You should start in the small cabin of the
   **Arctic Wanderer 26**. The HUD and boatyard name it.
3. **Sailor.** Walk around with WASD:
   - the arms swing gently and stop when you stop;
   - press **E** at the hat hook (starboard, forward) to wear the hat, and walk
     again;
   - press **H** to take it off, and check the carried hat sits in the hand.
4. **Deck and water.** Go on deck (companionway):
   - look at the teak (long planks, margins, the king plank forward, a
     distinct cockpit sole);
   - watch the water lap along the hull and the pontoon, with a few leaves or
     a scrap of paper in Copenhagen;
   - pause the game clock with the ⏸ button at the top: the water keeps
     moving gently.
5. **Boatyard.** Use the Boatyard sign on the pontoon:
   - the list shows Arctic Wanderer 26, Wing 33, Clam 40 and Frogleap 36;
   - move aboard each, visit deck and cabin, check the hat hook, and pet the
     cat or dog;
   - in Settings → Artwork, switch to *Classic* and back: the old art returns
     at once.
6. **Sailing.** Plot a route at the chart table (for example to Kiel) and set
   sail at the helm:
   - the view eases out a little;
   - the wave crests lie across the wind shown in the HUD;
   - if a windy day comes, they get busier.
   On arrival the view eases back in.
7. **Old save.** Load a 0.100a save: it should come back aboard its old boat,
   shown as **Wing 33** if it was the Starling 33.
8. **Report.** Any drawing you would like changed, ideally with a screenshot
   (Windows + Shift + S).
