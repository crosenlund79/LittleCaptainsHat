# 03_boats/petrel_36

The four boats, drawn as layers of one top-down picture (like transparent sheets stacked).

## What belongs here

- `deck_hull_base.png` - Frogleap 36: hull (READY; 2560 x 1366 px; replaces: PNG: assets/vessels/petrel_36/illustrated/deck/hull_base.png)
- `deck_deck_base.png` - Frogleap 36: deck (READY; 2560 x 1366 px; replaces: PNG: assets/vessels/petrel_36/illustrated/deck/deck_base.png)
- `deck_coachroof.png` - Frogleap 36: coachroof (READY; 2560 x 1366 px; replaces: PNG: assets/vessels/petrel_36/illustrated/deck/coachroof.png)
- `deck_deck_details.png` - Frogleap 36: deck details (READY; 2560 x 1366 px; replaces: PNG: assets/vessels/petrel_36/illustrated/deck/deck_details.png)
- `deck_shadow.png` - Frogleap 36: hull shadow (READY; 2560 x 1366 px; replaces: procedural: src/vessels/petrel_36/deck_visual.tscn)
- `deck_rigging.png` - Frogleap 36: standing rigging (READY; 2560 x 1366 px; replaces: procedural: src/vessels/petrel_36/deck_visual.tscn)
- `deck_mast.png` - Frogleap 36: mast (READY; 2560 x 1366 px; replaces: procedural: src/vessels/petrel_36/deck_visual.tscn)
- `cabin_cabin_base.png` - Frogleap 36: cabin shell (READY; 3000 x 1600 px; replaces: PNG: assets/vessels/petrel_36/illustrated/cabin/cabin_base.png)
- `cabin_furniture.png` - Frogleap 36: cabin furniture (READY; 3000 x 1600 px; replaces: PNG: assets/vessels/petrel_36/illustrated/cabin/furniture.png)
- `cabin_cabin_details.png` - Frogleap 36: cabin details (READY; 3000 x 1600 px; replaces: PNG: assets/vessels/petrel_36/illustrated/cabin/cabin_details.png)
- `sails_boom.png` - Frogleap 36: boom (ADAPTER_REQUIRED; 854 x 298 px; replaces: procedural: src/boat/sail_rig.gd (profile PNG slot, stretched over a mesh))
- `sails_main_sail.png` - Frogleap 36: mainsail (ADAPTER_REQUIRED; 854 x 298 px; replaces: procedural: src/boat/sail_rig.gd (profile PNG slot, stretched over a mesh))
- `sails_head_sail.png` - Frogleap 36: headsail (ADAPTER_REQUIRED; 854 x 298 px; replaces: procedural: src/boat/sail_rig.gd (profile PNG slot, stretched over a mesh))
- `sails_spinnaker.png` - Frogleap 36: spinnaker (ADAPTER_REQUIRED; 854 x 298 px; replaces: procedural: src/boat/sail_rig.gd (profile PNG slot, stretched over a mesh))

## How to draw a replacement

1. Pick a row in `manifest.csv` (open it in any spreadsheet program or text editor).
2. Draw the picture at the **2x source size** (`source_width_2x` x `source_height_2x` pixels). The game shows it at about half that size
   (`display_width` x `display_height` on the 1600 x 900 screen), so 2x keeps lines crisp. Keep the shape (aspect ratio) exactly;
   any size from half to four times the 2x size is accepted, but other shapes are refused.
3. Save it as a **PNG with a transparent background** under exactly the `filename` in the row, in **this folder**.
4. Open the project in Godot (it imports the new file by itself) and run the game. The picture is used wherever that thing appears.

## Style

Warm, hand-illustrated, soft outlines, gentle colours like the rest of Little Captain's Hat; seen from above, bow to the right.

## Orientation, pivot and what must not change

Every layer of one boat uses **the same canvas**: the full drawing area of the boat scene, with the boat's centre in the middle of the image and the **bow pointing right**. The game turns the camera for the eight headings, so **one top-down drawing serves all eight directions** - no separate views. Keep hull outline, cockpit, helm and furniture where they are now.

The picture never changes the game itself: walkable deck, collisions, interaction spots, the pet's safe places, routes, anchorages,
fish data and saves come from the game's own data, not from the art.

## Status of the entries

- **READY**: drop in the PNG and it is used.
- **ADAPTER_REQUIRED**: catalogued, but this kind of art is drawn in code with movement or states; the game needs a small adapter before a PNG can replace it. Drawing it now is still useful.
- **REFERENCE_ONLY**: for planning (part of a larger picture, or a light/effect); not loaded on its own.

Still needing adapters here: `sails_boom.png`, `sails_main_sail.png`, `sails_head_sail.png`, `sails_spinnaker.png`.

## Testing a replacement

- Run the game and look at the thing. If it does not change: check the file name and that `integration_status` is READY.
- A wrong shape or an unreadable file is ignored: the original art stays, and Godot's Output panel says
  `Sprite Workshop: ...` with the reason.
- Missing PNG: the game keeps its own art. Remove (or rename) your PNG to get the original back.
- Changes are picked up when the game starts; restart the game after adding or changing a PNG.
