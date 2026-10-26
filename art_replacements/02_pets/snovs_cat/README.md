# 02_pets/snovs_cat

The ship's companions. Snøvs is the ship's cat (companion kind `cat`); the dog is the other companion.

## What belongs here

- `resting.png` - Snøvs: resting (READY; 284 x 284 px; replaces: PNG: assets/companions/cat/resting.png)
- `sleeping.png` - Snøvs: sleeping (READY; 284 x 284 px; replaces: PNG: assets/companions/cat/sleeping.png)
- `alert.png` - Snøvs: alert (READY; 284 x 284 px; replaces: PNG: assets/companions/cat/alert.png)
- `stretching.png` - Snøvs: stretching (READY; 284 x 284 px; replaces: PNG: assets/companions/cat/stretching.png)

## How to draw a replacement

1. Pick a row in `manifest.csv` (open it in any spreadsheet program or text editor).
2. Draw the picture at the **2x source size** (`source_width_2x` x `source_height_2x` pixels). The game shows it at about half that size
   (`display_width` x `display_height` on the 1600 x 900 screen), so 2x keeps lines crisp. Keep the shape (aspect ratio) exactly;
   any size from half to four times the 2x size is accepted, but other shapes are refused.
3. Save it as a **PNG with a transparent background** under exactly the `filename` in the row, in **this folder**.
4. Open the project in Godot (it imports the new file by itself) and run the game. The picture is used wherever that thing appears.

## Style

Warm, hand-illustrated, soft outlines, gentle colours like the rest of Little Captain's Hat; seen from above, upright on screen.

## Orientation, pivot and what must not change

Square canvas, the animal in the middle; draw **every pose on the same canvas with the animal in the same place** so the poses line up. The centre of the image sits on the pet's resting spot. A plain light background is removed automatically, but transparency is best. The owner's original cat drawings in `Visuals/Cat/` are never touched.

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
