# 03_boats/shared_cabin_furniture

The four boats, drawn as layers of one top-down picture (like transparent sheets stacked).

## What belongs here

- `settee.png` - Settee (REFERENCE_ONLY; 340 x 114 px; replaces: painted into each boat's furniture layer)
- `saloon_table.png` - Saloon table (REFERENCE_ONLY; 198 x 142 px; replaces: painted into each boat's furniture layer)
- `nav_table.png` - Navigation table (REFERENCE_ONLY; 170 x 114 px; replaces: painted into each boat's furniture layer)
- `galley_counter.png` - Galley counter (REFERENCE_ONLY; 256 x 102 px; replaces: painted into each boat's furniture layer)
- `berth.png` - Berth (REFERENCE_ONLY; 396 x 198 px; replaces: painted into each boat's furniture layer)
- `engine_box.png` - Engine box / steps (REFERENCE_ONLY; 142 x 114 px; replaces: painted into each boat's furniture layer)
- `heads.png` - Heads and shower (REFERENCE_ONLY; 170 x 170 px; replaces: painted into each boat's furniture layer)
- `wardrobe.png` - Wardrobe (REFERENCE_ONLY; 114 x 84 px; replaces: painted into each boat's furniture layer)

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

Nothing in this folder needs an adapter.

## Testing a replacement

- Run the game and look at the thing. If it does not change: check the file name and that `integration_status` is READY.
- A wrong shape or an unreadable file is ignored: the original art stays, and Godot's Output panel says
  `Sprite Workshop: ...` with the reason.
- Missing PNG: the game keeps its own art. Remove (or rename) your PNG to get the original back.
- Changes are picked up when the game starts; restart the game after adding or changing a PNG.
