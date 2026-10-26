# 09_nature_and_environment

Small things drifting on the water, and weather effects.

## What belongs here

- `leaf.png` - Drifting leaf (ADAPTER_REQUIRED; 38 x 16 px; replaces: procedural: src/water/water_life.gd / src/boat/weather_visuals.gd)
- `seaweed.png` - Seaweed strand (ADAPTER_REQUIRED; 84 x 20 px; replaces: procedural: src/water/water_life.gd / src/boat/weather_visuals.gd)
- `foam.png` - Foam clump (ADAPTER_REQUIRED; 38 x 38 px; replaces: procedural: src/water/water_life.gd / src/boat/weather_visuals.gd)
- `paper.png` - Paper scrap (ADAPTER_REQUIRED; 24 x 20 px; replaces: procedural: src/water/water_life.gd / src/boat/weather_visuals.gd)
- `waves.png` - Waves and whitecaps (REFERENCE_ONLY; 100 x 24 px; replaces: procedural: src/water/water_life.gd / src/boat/weather_visuals.gd)
- `rain.png` - Rain and wind streaks (REFERENCE_ONLY; 56 x 4 px; replaces: procedural: src/water/water_life.gd / src/boat/weather_visuals.gd)

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

Centred, small.

The picture never changes the game itself: walkable deck, collisions, interaction spots, the pet's safe places, routes, anchorages,
fish data and saves come from the game's own data, not from the art.

## Status of the entries

- **READY**: drop in the PNG and it is used.
- **ADAPTER_REQUIRED**: catalogued, but this kind of art is drawn in code with movement or states; the game needs a small adapter before a PNG can replace it. Drawing it now is still useful.
- **REFERENCE_ONLY**: for planning (part of a larger picture, or a light/effect); not loaded on its own.

Still needing adapters here: `leaf.png`, `seaweed.png`, `foam.png`, `paper.png`.

## Testing a replacement

- Run the game and look at the thing. If it does not change: check the file name and that `integration_status` is READY.
- A wrong shape or an unreadable file is ignored: the original art stays, and Godot's Output panel says
  `Sprite Workshop: ...` with the reason.
- Missing PNG: the game keeps its own art. Remove (or rename) your PNG to get the original back.
- Changes are picked up when the game starts; restart the game after adding or changing a PNG.
