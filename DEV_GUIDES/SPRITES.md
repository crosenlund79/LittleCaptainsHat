# Replacing sprites

The general rules for putting a drawn image into the game. The specific guides
build on this one:
- [COMPANION_ANIMATION.md](COMPANION_ANIMATION.md) covers the cat and dog;
- [VESSEL_ART.md](VESSEL_ART.md) covers decks, cabins and sails.

**You never need to edit a script to replace art.**

## Shortest procedure

1. Export the new image as PNG with **the same file name** as the image it
   replaces, for example `Visuals/Cat/Cat_resting.png`.
2. Overwrite the old file in the project folder.
3. Switch to the Godot editor: it notices the change and re-imports the image.
   Without the editor, run `godot --headless --path . --import` once.
4. Run the game. The new image is shown.

New images that are not replacements need their name (or path) added to a data
file. Each guide says which one.

## Formats

- **PNG** (8-bit, RGBA or RGB). Other formats Godot imports (WebP, JPG) also work
  wherever a texture is assigned in the inspector, but the conventional file names
  in the guides all end in `.png`.
- sRGB colours.
- Keep source files (`.kra`, `.psd`, `.clip`, ...) outside `assets/` and `Visuals/`,
  or Godot may try to import them.

## Transparency

- **Preferred:** export with a transparent background (PNG with alpha), using
  straight (not premultiplied) alpha.
- **Companion images may also be opaque** (drawn on white). The game removes the
  plain background colour connected to the image border when it loads them,
  and keeps enclosed white areas such as a white chest. Details are in
  [COMPANION_ANIMATION.md](COMPANION_ANIMATION.md). The original file is never
  changed.
- **Vessel layers must be transparent** wherever the layer has nothing. An opaque
  vessel layer would cover the layers below it.

## Import settings

The defaults are right: Godot's 2D texture import, **Lossless** compression,
mipmaps **off**, filter from the project (linear). You can see them per file in
the Import dock, or in the `.import` file next to the image (for example
`Visuals/Cat/Cat_resting.png.import`). Commit the `.import` files together
with the images.

There is no need to change the import settings. If an image looks blurry when
small, draw it larger rather than enabling mipmaps.

## Sizes, scale and alignment

- **Vessel art.**
  - Every layer is a **full-canvas** image covering the vessel's art canvas, a
    rectangle in scene units listed in [VESSEL_ART.md](VESSEL_ART.md).
  - Draw at **2 px per scene unit**: the Starling 33 deck is 2240 × 800 px.
  - The game puts the image's top-left corner on the canvas's top-left and scales
    it uniformly to the canvas width.
  - Every layer covers the same rectangle, so layers line up without offsets.
- **Companion poses.**
  - Every pose of one animal is drawn on the **same square canvas** (the cat uses
    1254 × 1254 px), with the animal in the same place.
  - The game draws the canvas's longer side `display_size` scene units long (72
    for the cat). The point `pivot` of the canvas (centre by default) sits on the
    resting spot.
  - Per-pose fixes (`offset`, `scale`, `flip_h`) live in the data file, never in
    code.
- One scene unit is about the width of a hand; the player token is 40 units
  across.

## Named slots and fallback

- **Vessel art** is split into named slots (HullBase, DeckBase, Coachroof,
  FurnitureVisual, ...). Each slot shows **either** your sprite **or** the built-in
  procedural (placeholder) drawing. A slot without a sprite simply keeps the
  placeholder, so you can replace art one layer at a time. The list of slots and
  their file names is in [VESSEL_ART.md](VESSEL_ART.md).
- **Companions:**
  - a missing pose image falls back to the resting pose;
  - a missing resting image falls back to the procedural animal.

Missing or unreadable files never stop the game. They print a warning in the
Godot output panel that names the file.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| The old image still shows | Godot has not re-imported the file | Focus the editor window, or run `godot --headless --path . --import`; restart the game |
| The placeholder still shows | Wrong file name or folder (names are case-sensitive on Linux and in exported games) | Compare with the table in the guide, letter by letter |
| A white box around the animal | The background is not plain (a gradient, texture or shadow touching the border), so it cannot be removed | Export with transparency, or keep the background one flat colour all the way to the border |
| Parts of the animal disappeared | The outline has a gap, so the background removal leaks inside | Close the outline, or export with transparency |
| A vessel layer is shifted or squashed | The image is not the canvas's aspect ratio (a warning is printed) | Use the template size from `assets/vessels/<vessel_id>/templates/` |
| A vessel layer hides the layers below | It was exported without transparency | Export with alpha; leave empty areas transparent |
| The player walks through drawn furniture | Collision never comes from art | Move or resize the matching shape in the scene's `Layout/Collision` (see [VESSEL_ART.md](VESSEL_ART.md)) |
| The poses jump when they change | The animal sits in different places on the canvases | Draw all poses on one canvas, or set a per-pose `offset` in the data file |
