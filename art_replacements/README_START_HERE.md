# Sprite Workshop: start here

This folder is where you put hand-drawn pictures that replace the game's own artwork. You never need to change any code or scene to do it.

## The five steps

1. **Choose a folder.** Each one covers one kind of art (`02_pets/snovs_cat/` for Snøvs, `03_boats/arctic_wanderer_26/` for that boat, and so on). Read its `README.md`.
2. **Find the row in `manifest.csv`.** It names the file, its size and how it must be drawn. You can open it in a spreadsheet program or a text editor. Only rows marked **READY** are picked up by the game today.
3. **Draw it at the "2x source" size** (`source_width_2x` x `source_height_2x` pixels). Keep that exact shape. Use a transparent background.
4. **Save it as a PNG** with exactly the `filename` from the row, in that same folder.
5. **Open the project in Godot and run the game.** Godot imports the new file by itself when the editor opens or regains focus. The game reads replacements when it starts, so if it is already running, restart it.

It works with the normal routine: download the branch as a ZIP, extract it, open `project.godot` in Godot, and Run. You do not need a special build or export.

## If something is wrong

- **Missing PNG:** the game keeps its own art, silently.
- **Wrong shape, or a file Godot cannot read:** the replacement is ignored, the original art stays, and Godot's Output panel shows a line starting `Sprite Workshop:` that explains why.
- **To get the original back:** delete or rename your PNG and restart the game.

## What the statuses mean

- **READY:** drop in the PNG and it is used.
- **ADAPTER_REQUIRED:** the game draws this in code with movement or changing states (flames, a nodding rod tip, walking arms). It still needs a small adapter before a PNG can replace it. Drawing it now is still worthwhile.
- **REFERENCE_ONLY:** listed for planning. It is either part of a bigger picture (for example, the winches are drawn inside a boat's `deck_details` layer) or an effect such as a light glow.

## Where to look next

- [`INDEX.md`](INDEX.md) has the counts, the first 25 subjects worth drawing, quick wins, and the three inventory counts. It is generated from the manifests by `tools/art/build_index.py`, so run that script after editing a manifest.
- `SPRITE_WORKSHOP_REPORT.md` at the project root explains the reasoning behind the priorities, sizes and counts.

Pictures never change the game itself. Walkable deck, collisions, interaction spots, Snøvs's safe places, routes, anchorages, fish data and saves all come from the game's own data.
