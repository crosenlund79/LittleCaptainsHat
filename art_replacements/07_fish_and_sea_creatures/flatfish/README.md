# 07_fish_and_sea_creatures/flatfish

Fish, sharks and junk you can catch.

## What belongs here

- `flatfish_body.png` - Flatfish: body (READY; 840 x 420 px; replaces: PNG: assets/fishing/flatfish/body.png)
- `flatfish_tail.png` - Flatfish: tail (READY; 840 x 420 px; replaces: PNG: assets/fishing/flatfish/tail.png)
- `flatfish_lid.png` - Flatfish: eyelid (READY; 840 x 420 px; replaces: PNG: assets/fishing/flatfish/lid.png)
- `flatfish_thumb.png` - Flatfish: thumbnail (READY; 128 x 64 px; replaces: PNG: assets/fishing/flatfish/thumb.png)

## How to draw a replacement

1. Pick a row in `manifest.csv` (open it in any spreadsheet program or text editor).
2. Draw the picture at the **2x source size** (`source_width_2x` x `source_height_2x` pixels). The game shows it at about half that size
   (`display_width` x `display_height` on the 1600 x 900 screen), so 2x keeps lines crisp. Keep the shape (aspect ratio) exactly;
   any size from half to four times the 2x size is accepted, but other shapes are refused.
3. Save it as a **PNG with a transparent background** under exactly the `filename` in the row, in **this folder**.
4. Open the project in Godot (it imports the new file by itself) and run the game. The picture is used wherever that thing appears.

## Style

Warm, hand-illustrated, soft outlines, gentle colours like the rest of Little Captain's Hat; seen from the side, head to the left.

## Orientation, pivot and what must not change

Each fish is layers on one **2:1 canvas** (body, tail, closed eyelid) with the fish in the same place on every layer; the tail turns about the tail pivot and the eye blinks at the eye position in `data/fishing/fish_art.json`. Junk is one picture. Thumbnails are small static copies.

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
