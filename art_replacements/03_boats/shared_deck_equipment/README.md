# 03_boats/shared_deck_equipment

The four boats, drawn as layers of one top-down picture (like transparent sheets stacked).

## What belongs here

- `solar_panel.png` - Solar panel (decorative) (READY; 100 x 250 px; replaces: procedural: src/boat/visuals/solar_panels.gd)
- `winch.png` - Winch (REFERENCE_ONLY; 50 x 50 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `cleat.png` - Cleat (REFERENCE_ONLY; 60 x 20 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `wheel.png` - Wheel and pedestal (REFERENCE_ONLY; 150 x 36 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `tiller.png` - Tiller (REFERENCE_ONLY; 176 x 24 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `bow_roller.png` - Bow roller (REFERENCE_ONLY; 76 x 40 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `hatch.png` - Hatch (REFERENCE_ONLY; 100 x 100 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `swim_ladder.png` - Swim ladder (REFERENCE_ONLY; 76 x 60 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `fender.png` - Fender (REFERENCE_ONLY; 30 x 76 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))
- `rails.png` - Pulpit, pushpit and lifelines (REFERENCE_ONLY; 250 x 24 px; replaces: painted into each boat's deck_details/deck_base layer (or ProceduralShape))

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
