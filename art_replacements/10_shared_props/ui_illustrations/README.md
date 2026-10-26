# 10_shared_props/ui_illustrations

Pictures inside windows (Go Ashore, cooking, haul-out).

## What belongs here

- `go_ashore_cup.png` - Go Ashore picture: cup (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_bench.png` - Go Ashore picture: bench (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_sailor.png` - Go Ashore picture: sailor (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_basket.png` - Go Ashore picture: basket (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_view.png` - Go Ashore picture: view (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_board.png` - Go Ashore picture: board (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_gull.png` - Go Ashore picture: gull (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_boat.png` - Go Ashore picture: boat (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `go_ashore_houses.png` - Go Ashore picture: houses (REFERENCE_ONLY; 192 x 192 px; replaces: procedural: src/ui/go_ashore_menu.gd)
- `haul_out_scene.png` - Haul-out scene (REFERENCE_ONLY; 1240 x 480 px; replaces: procedural: src/ui/haul_out_scene.gd / cooking_menu.gd)
- `frying_pan.png` - Frying pan on the hob (REFERENCE_ONLY; 360 x 120 px; replaces: procedural: src/ui/haul_out_scene.gd / cooking_menu.gd)
- `coffee_pot.png` - Coffee pot and mug (REFERENCE_ONLY; 160 x 120 px; replaces: procedural: src/ui/haul_out_scene.gd / cooking_menu.gd)

## How to draw a replacement

1. Pick a row in `manifest.csv` (open it in any spreadsheet program or text editor).
2. Draw the picture at the **2x source size** (`source_width_2x` x `source_height_2x` pixels). The game shows it at about half that size
   (`display_width` x `display_height` on the 1600 x 900 screen), so 2x keeps lines crisp. Keep the shape (aspect ratio) exactly;
   any size from half to four times the 2x size is accepted, but other shapes are refused.
3. Save it as a **PNG with a transparent background** under exactly the `filename` in the row, in **this folder**.
4. Open the project in Godot (it imports the new file by itself) and run the game. The picture is used wherever that thing appears.

## Style

Warm, hand-illustrated, soft outlines, gentle colours like the rest of Little Captain's Hat; seen from the front or side.

## Orientation, pivot and what must not change

UI-only: outside the in-world counts.

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
