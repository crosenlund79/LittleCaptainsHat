# 04_cabins_and_interiors/shared_props

Cabin props shared by the boats.

## What belongs here

- `galley_stove.png` - Galley stove (ADAPTER_REQUIRED; 96 x 68 px; replaces: procedural: src/aboard/galley_stove.gd)
- `trophy_board.png` - Trophy board (ADAPTER_REQUIRED; 374 x 130 px; replaces: procedural: src/aboard/trophy_board.gd)
- `world_map_frame.png` - Framed world map (REFERENCE_ONLY; 424 x 238 px; replaces: procedural: src/boat/cabin_world_map.gd)
- `hat_hook.png` - Hat hook (ADAPTER_REQUIRED; 52 x 22 px; replaces: procedural: src/hat/hat_hook.gd)
- `provisions_full.png` - Provisions (full) (ADAPTER_REQUIRED; 226 x 124 px; replaces: procedural: src/boat/provision_display.gd (PNG hook <art_folder>/cabin/provisions_full.png))
- `provisions_moderate.png` - Provisions (moderate) (ADAPTER_REQUIRED; 226 x 124 px; replaces: as above)
- `provisions_low.png` - Provisions (low) (ADAPTER_REQUIRED; 226 x 124 px; replaces: as above)
- `provisions_empty.png` - Provisions (empty) (ADAPTER_REQUIRED; 226 x 124 px; replaces: as above)

## How to draw a replacement

1. Pick a row in `manifest.csv` (open it in any spreadsheet program or text editor).
2. Draw the picture at the **2x source size** (`source_width_2x` x `source_height_2x` pixels). The game shows it at about half that size
   (`display_width` x `display_height` on the 1600 x 900 screen), so 2x keeps lines crisp. Keep the shape (aspect ratio) exactly;
   any size from half to four times the 2x size is accepted, but other shapes are refused.
3. Save it as a **PNG with a transparent background** under exactly the `filename` in the row, in **this folder**.
4. Open the project in Godot (it imports the new file by itself) and run the game. The picture is used wherever that thing appears.

## Style

Warm, hand-illustrated, soft outlines, gentle colours like the rest of Little Captain's Hat; seen from above.

## Orientation, pivot and what must not change

Top-down, centred.

The picture never changes the game itself: walkable deck, collisions, interaction spots, the pet's safe places, routes, anchorages,
fish data and saves come from the game's own data, not from the art.

## Status of the entries

- **READY**: drop in the PNG and it is used.
- **ADAPTER_REQUIRED**: catalogued, but this kind of art is drawn in code with movement or states; the game needs a small adapter before a PNG can replace it. Drawing it now is still useful.
- **REFERENCE_ONLY**: for planning (part of a larger picture, or a light/effect); not loaded on its own.

Still needing adapters here: `galley_stove.png`, `trophy_board.png`, `hat_hook.png`, `provisions_full.png`, `provisions_moderate.png`, `provisions_low.png`, `provisions_empty.png`.

## Testing a replacement

- Run the game and look at the thing. If it does not change: check the file name and that `integration_status` is READY.
- A wrong shape or an unreadable file is ignored: the original art stays, and Godot's Output panel says
  `Sprite Workshop: ...` with the reason.
- Missing PNG: the game keeps its own art. Remove (or rename) your PNG to get the original back.
- Changes are picked up when the game starts; restart the game after adding or changing a PNG.
