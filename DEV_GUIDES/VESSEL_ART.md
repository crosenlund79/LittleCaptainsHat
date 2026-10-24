# Vessel art: decks, cabins and sails

How to replace a boat's placeholder art with drawn sprites, and how the pieces
fit together. The general rules (formats, transparency, import, common mistakes)
are in [SPRITES.md](SPRITES.md). No code changes are needed: you drop correctly
named PNGs into the vessel's art folder, or assign them in the inspector.

## How the pieces fit together

```
data/vessels/<vessel_id>.tres            VesselDefinition: id, name, scenes, performance,
   │                                     visual profile
   ├─ deck_scene / cabin_scene           gameplay scenes  (src/vessels/<vessel_id>/deck.tscn, cabin.tscn)
   │     ├─ Visual        ◄── instance of the art-only scene (deck_visual.tscn / cabin_visual.tscn)
   │     │                    named VisualSlot nodes, each with placeholder drawing
   │     ├─ Layout        ◄── gameplay: Collision, Stations, SpawnPoints,
   │     │                    SailMarkers (deck), CompanionSpots (cabin)
   │     └─ SailRig (deck) / Companion (cabin), Player, Camera2D
   └─ visual_profile                     VesselVisualProfile (data/vessels/<vessel_id>_visuals.tres):
                                         which sprite each slot uses
```

- **The gameplay layout** (`Layout`) decides where you can walk, where E works,
  where you appear, where the sails attach and where the cat rests. It is made of
  invisible shapes and markers.
- **The visual scene** (`Visual`) is only artwork, split into **slots**.
- **The visual profile** says, for each slot, whether to show a sprite or the
  slot's placeholder drawing (**the fallback**).
- Because art and layout are separate, replacing art can never move a wall or a
  station. Changing the layout never needs new art, though it may need the art
  updated to match.
- **The templates** show the layout drawn on the canvas, so the art can match it.
- **The sails** are drawn live by the `SailRig` from the wind and trim. Their
  sprites are stretched over the moving sail shape (see §5).

## 1. Art direction

- **Hand-drawn, top-down, warm.** The look is inspired by FlipTober-style
  illustration: confident ink lines that wobble a little, flat colour washes with
  some unevenness, and light hatching for shade. No photo textures and no hard
  3D rendering.
- **Palette.** Stay close to the game's colours:
  - cream hulls (`#EFE5CC`);
  - sand-coloured non-skid deck (`#D4CCB4`);
  - teak (`#8A6A4A`);
  - sea-glass windows (`#3F7880`);
  - warm, dark ink (`#342C26`);
  - honey cabin sole (`#9A7A57`).

  The water and night backgrounds are teal and very dark blue, so keep hull edges
  clearly readable against them.
- **Light** comes from the upper left. Shadows fall down and to the right, about
  8–12 scene units.
- **Readability before detail.** Doors, helm, berth and chart table must be
  recognisable at 1× zoom. The game draws a brass focus ring around stations, so
  you do not need to draw highlights.
- **No text** in sprites. Labels are separate nodes in the placeholder art and stay
  optional.

## 2. Coordinate conventions (every vessel, deck and cabin)

- **Top-down view.**
  - **+x** is forward (towards the bow); **−x** is aft.
  - **−y** is port; **+y** is starboard.
  - The origin is the middle of the boat.
- **Units.** The player token is 40 units across. The Starling 33's hull is about
  1000 units long.
- **Canvas.** Each art scene's `VesselVisual.canvas` is the rectangle the sprites
  cover, in scene units:

  | Vessel | Deck and cabin canvas | Sprite size at 2× |
  |---|---|---|
  | Starling 33 (monohull) | `Rect2(-560, -200, 1120, 400)` | 2240 × 800 px |
  | Halcyon 40 (catamaran) | `Rect2(-560, -330, 1120, 660)` | 2240 × 1320 px |
  | Petrel 36 (trimaran) | `Rect2(-600, -320, 1200, 640)` | 2400 × 1280 px |

- **Sprite size.** Every slot sprite is a **full-canvas PNG**, transparent wherever
  the slot has nothing. Draw it at **2 px per unit** (the table above).
  - The game puts the image's top-left corner on the canvas's top-left and scales
    it uniformly to the canvas width. Any resolution with the same aspect ratio
    works (for example 1× or 3×).
  - A different aspect ratio still shows, scaled to the width, but logs a warning.
  - Because every layer covers the same rectangle, the layers line up without any
    offsets.

## 3. Slots

Each art scene (`src/vessels/<vessel_id>/deck_visual.tscn`, `cabin_visual.tscn`)
has named `VisualSlot` nodes. A slot shows its sprite **or** its placeholder
children, never both. The slots are listed bottom to top.

**Deck (exterior):**

| Slot | File name | Contents |
|---|---|---|
| ShadowVisual | `shadow.png` | the boat's shadow on the water |
| HullBase | `hull_base.png` | hull(s), toe rail, bridgedeck or akas |
| DeckBase | `deck_base.png` | deck surface, cockpit, benches, nets, steps |
| Coachroof | `coachroof.png` | coachroof or saloon roof, windows, hatches |
| DeckDetails | `deck_details.png` | wheel, winches, cleats, lockers, lifelines, pulpits |
| RiggingVisual | `rigging.png` | shrouds, forestay, bridle |
| MastVisual | `mast.png` | the mast seen from above |
| BoomVisual | `boom.png` | boom (drawn by the SailRig, see §5) |
| MainSailVisual | `main_sail.png` | mainsail cloth (SailRig) |
| HeadSailVisual | `head_sail.png` | jib cloth (SailRig) |
| SpinnakerVisual | `spinnaker.png` | spinnaker cloth (SailRig) |

**Cabin (interior):**

| Slot | File name | Contents |
|---|---|---|
| CabinBase | `cabin_base.png` | hull interior, cabin sole, cabin sides, windows |
| FurnitureVisual | `furniture.png` | galley, settees, tables, berths, steps, doors, nav station |
| CabinDetails | `cabin_details.png` | small details on top (cushions, books, lamps) |

The ship's cat or dog is **not** vessel art: one set of companion images is used
on every boat. See [COMPANION_ANIMATION.md](COMPANION_ANIMATION.md).

The deck's water and pontoon (`Surroundings`) and the cabin's darkness
(`Backdrop`) belong to the gameplay scene, not to the vessel art.

## 4. Where files go, and the fallback order

```
assets/vessels/<vessel_id>/
  deck/       hull_base.png, deck_base.png, coachroof.png, ... (deck slots)
  cabin/      cabin_base.png, furniture.png, cabin_details.png
  templates/  generated guides (not imported by Godot)
```

Create the `deck/` or `cabin/` folder when you add the first sprite. For each slot,
the vessel's `VesselVisualProfile` (`data/vessels/<vessel_id>_visuals.tres`) picks
the art in this order:

1. a texture assigned to the slot in the profile (inspector);
2. the PNG at the conventional path `<art_folder>/<deck|cabin>/<file>.png`;
3. the placeholder drawing already in the scene.

A missing, misnamed or unreadable file therefore never breaks the boat: that slot
keeps its placeholder. `procedural_only` in the profile switches every sprite off,
which is useful for comparing.

## 5. Sails

The sails stay dynamic. Their trim, set, hoist and breathing are computed by the
`SailRig` (`src/boat/sail_rig.gd`) from the propulsion state. A sail sprite is
**stretched over the live sail shape** as a strip of triangles:

- the image's **left edge** is the luff (mast, or the tack for the jib);
- the **right edge** is the clew;
- the **top edge** follows the curved leech (for the spinnaker, its leading edge);
- the **bottom edge** is the foot.

Draw the sail as a flat, roughly rectangular panel, about 512 × 256 px. Seams,
panels, battens and a little shading read well. The stretch is modest: the sail
fills and eases by a few percent and swings with the trim. Avoid strong
perspective and outlines that must stay perfectly straight. `boom.png` is drawn
along the boom from gooseneck (left) to boom end (right).

The attachment points come from the deck scene's markers
(`Layout/SailMarkers/Mast`, `Tack`, `BoomEnd`, `Traveller`, `JibSheetLead`,
`SpinnakerSheetLead`). Each vessel therefore rigs its own sails, and moving a
marker re-rigs the boat.

**Limits.** There is no cloth simulation and no sprite-sheet animation. Furled
sails use the placeholder sail cover and the rolled jib. The mast is a static
top-down sprite.

## 6. Cabins

- Cabin art covers the cabin canvas like the deck art.
- **Collision is never derived from the art (or its alpha).** Furniture blocks the
  player because of the `BoatFixture` shapes in `Layout/Collision`, so a drawn sofa
  that is wider than its fixture is only visual. When you draw furniture larger or
  smaller than the template, ask for the fixture to be changed to match. That
  change is in the cabin scene, not in a script.
- **Doors and access points:**
  - the way to the deck (the companionway) is a station in `Layout/Stations`; the
    art should make it obvious;
  - on the Halcyon 40 it is the sliding saloon door in the middle of the aft wall,
    drawn with the cockpit beyond and chevrons pointing out. Its prompt is
    "Go on deck".
- The companion's resting places are the markers in `Layout/CompanionSpots`
  (`settee`, `nav_station`, `v_berth`, `cabin_floor`, `companionway`, `seating`).
  Leave a little room in the art where they are.

## 7. Templates

`assets/vessels/<vessel_id>/templates/` holds, per vessel and area:

- `deck_reference.png` / `cabin_reference.png`: the current art with the landmarks
  drawn over it;
- `deck_guide.png` / `cabin_guide.png`: the landmarks alone on transparency, to use
  as a layer in a painting program.

Both are full-canvas images at 2×. Landmark colours:

| Colour | Meaning |
|---|---|
| **red** | solid collision; keep the art's walls and furniture over these |
| **green** | walkable fixture (for example a seat the player can stand by) |
| **teal** | interaction station (helm, companionway, chart table, berth, boatyard) |
| **blue** | player spawn points, with the player's body radius |
| **orange** | companion resting spots |
| **magenta** | sail attachment markers |
| **grey** | 50-unit grid; the darker lines are the x and y axes |

To regenerate the templates after layout changes, run this with a display:

```
godot --path . --rendering-driver opengl3 res://tools/vessels/render_art_templates.tscn
```

## 8. Workflow and checklist

1. Open the vessel's `*_guide.png` as the bottom layer, at the template size.
2. Paint each slot on its own layer, and export each one as a full-canvas PNG
   (transparent elsewhere) with the file name from §3.
3. Copy the PNGs to `assets/vessels/<vessel_id>/deck/` or `cabin/`.
4. Start the game, or import. The slot shows the sprite; everything else is
   unchanged.

Checklist:

- [ ] Same aspect ratio as the canvas, sRGB, straight (non-premultiplied) alpha.
- [ ] Walls and furniture cover the red collision shapes, and walkways stay open
  where the template has none.
- [ ] Stations are recognisable where the teal shapes are.
- [ ] Nothing important is under the sails' area on deck (sails are drawn above
  the deck art).
- [ ] No text baked into the art.

## 9. Demonstration

The Starling 33 has a demo coachroof sprite drawn by
`tools/vessels/make_demo_coachroof.py`. It sits at
`assets/vessels/starling_33/demo/deck/coachroof.png`, with the profile
`data/vessels/starling_33_visuals_demo.tres` (`art_folder` = the demo folder).

- To see it in the game, set the Starling 33 definition's `visual_profile` to the
  demo profile, or copy the PNG into a new folder *assets/vessels/starling_33/deck/*.
- The tests apply it and check that the coachroof shows the sprite, that the
  other slots stay placeholders, and that every collision shape, station, spawn
  and marker stays exactly in place.

Screenshots: `docs/screenshots/45_monohull_procedural.png` and
`docs/screenshots/46_monohull_demo_coachroof_sprite.png`.

## 10. For developers

- **Generator.** `tools/vessels/build_multihull_scenes.py` generates the catamaran
  and trimaran scenes. The Halcyon 40 cabin was regenerated in Iteration 004b.
  - Furniture, collision and the placeholder drawing come from one list
    (`cat_furniture()`), so they always match.
  - Use the script with `--force` only for scenes nobody has edited by hand;
    otherwise edit the scenes in Godot.
- **Scene structure** (fixed):
  - **`Visual`**: the instanced art-only scene;
  - **`Layout`**: `Collision`, `Stations`, `SpawnPoints`, and `SailMarkers` (deck)
    or `CompanionSpots` (cabin);
  - **`SailRig`** (deck) or **`Companion`** (cabin), plus **`Player`** and
    **`Camera2D`**.
- `BoatFixture` is collision only (it draws an outline in the editor only), and
  `ProceduralShape` is drawing only.
- The automated test `tests/suites/test_vessels.gd` walks every area with the real
  player shape, and checks that every spawn and station can be reached.
