# Companion artwork and poses

How the ship's cat is drawn in the game, and how you change, add or prepare
companion artwork. The general sprite rules are in [SPRITES.md](SPRITES.md).

## What the game does with the cat

The cat uses four images, each one **pose**:

| Pose | File | When it shows |
|---|---|---|
| `resting` | `Visuals/Cat/Cat_resting.png` (lying down, eyes open) | most of the time |
| `sleeping` | `Visuals/Cat/Cat_SleepingBack.png` (asleep on its back) | now and then, for 1–2.5 minutes |
| `alert` | `Visuals/Cat/Cat_alert.png` (sitting up, looking) | when petted (with hearts and a purr), and briefly when you walk up to it while it rests |
| `stretching` | `Visuals/Cat/Cat_stretching.png` (big stretch) | a few seconds, before or after a nap |

**Behaviour.**
- The cat rests for 25–60 s (real time). Then it usually naps (60%) or stretches.
- After a nap it often stretches before resting again.
- Each change is a 0.25 s cross-fade with a very small breathing movement. The cat
  is never rotated or distorted.
- Petting (E) works in any pose: it shows `alert` for 2 s with hearts and the purr,
  then the cat goes back to resting. One press is enough.
- Approaching while it **sleeps** does not wake it. Petting does.

**Where it rests** does not change: the cat still moves between its resting spots
(settee, nav station, berth) every few game hours, on every boat. Poses are
presentation only and are never saved. The dog keeps its drawn (procedural) look
until it gets its own images.

## 1. Where to draw and export

- Put your exported images in **`Visuals/Cat/`**. That is the folder the game
  reads; nothing needs to be copied anywhere else.
- Keep working files (`.kra`, `.psd`, layers) outside the project folder, or at
  least outside `Visuals/`.
- Export PNG. Transparent background is best. A plain white (or any single flat
  colour) background also works, as long as it reaches all four edges and the
  cat's outline is closed.

## 2. File and folder rules

- Use exactly these names, including capitals: `Cat_resting.png`,
  `Cat_SleepingBack.png`, `Cat_alert.png`, `Cat_stretching.png`. Linux and
  exported games treat `cat_resting.png` as a different file.
- **Same canvas for every pose.** All four current images are 1254 × 1254 px with
  the cat roughly in the middle. Keep the same canvas size and keep the cat's body
  in the same place, so changing pose does not make it jump.
- **Size.** Draw the cat to fill about 60–70% of the canvas width, like now. The
  game scales the whole canvas down (see §4), so the cat keeps its on-screen size.
- **Smaller exports load faster.** The images are scaled to 320 px when loaded. A
  512 × 512 export looks the same in the game and loads quicker than 1254 × 1254.

## 3. How poses are mapped

The mapping is a data file: **`data/companions/cat_visuals.tres`**. Open it in
Godot (double-click it in the FileSystem dock) and look in the Inspector:

- **Kind**: `cat`.
- **Poses**: a list. Each entry (a `CompanionPoseArt`) has:
  - **Pose**: the name the behaviour uses (`resting`, `sleeping`, `alert`,
    `stretching`);
  - **Image Path**: the PNG, for example `res://Visuals/Cat/Cat_alert.png`;
  - **Offset**, **Scale**, **Flip H**: per-pose placement fixes (see §4).
- **Behaviour** group: rest time (min, max), sleep time (min, max), chance of a
  nap, stretch, alert and cross-fade durations, and how often walking up to it
  makes it look up (`Approach Alert Cooldown`, 0 = never).

The script that runs the behaviour is `src/companion/ship_companion.gd`; the data
types are `src/companion/companion_visual_set.gd` and
`src/companion/companion_pose_art.gd`. **You do not need to edit any of them to
change art or timing.**

## 4. How alignment works

The `Placement` group of `data/companions/cat_visuals.tres` controls it:

- **Display Size** (72): the canvas's longer side is drawn this many scene units
  long. The player token is 40 units across. Raise it to make the cat bigger.
- **Pivot** (0.5, 0.5): the point of the canvas, as a fraction of its width and
  height, placed on the resting spot. (0.5, 0.5) is the centre; (0.5, 0.8) would
  put a point near the bottom on the spot.
- Per pose: **Offset** shifts that pose in scene units (+x right, +y down);
  **Scale** enlarges or shrinks only that pose; **Flip H** mirrors it.

All four images share one canvas, so the current offsets are zero. Use an offset
only when a new drawing sits somewhere else on its canvas.

**Background removal** (`Loading` group):
- `Remove Background` is on.
- `Background Tolerance` (0.12) is how close to the corner colour a pixel must be
  to count as background. Raise it slightly if a light fringe remains; lower it if
  pale parts of the cat disappear.
- Images that already have transparency at their border are used unchanged.

## 5. How petting works

- The cat's interaction (E, prompt "Pet cat") calls `pet()`.
- **Next to a station** (Iteration 005b): a resting cat never takes over a
  station, door or berth the player is standing at. To pet a cat lying right by
  a station, step up to the cat and face it (the arrow on the player token);
  the prompt then says "Pet cat". The rule is in
  `src/interaction/interaction_sensor.gd` (`focus_priority` −1 for the
  companion), so it holds on every boat without per-station exceptions.
- That plays the purr on the SFX bus (`assets/audio/placeholder/companion_purr.wav`,
  see [AUDIO.md](AUDIO.md)), shows the `alert` pose for `Alert Seconds` (at least
  1.6 s) with rising hearts, then returns to `resting`.
- Without an `alert` image, the cat keeps its current image and still purrs and
  shows hearts.

## 6. Change a pose image

Either way, no code changes:

- **Same name:** overwrite `Visuals/Cat/Cat_alert.png` with your new drawing,
  let Godot re-import (focus the editor, or run
  `godot --headless --path . --import`), and run the game.
- **Different name or folder:** put the file in `Visuals/Cat/`, then in
  `data/companions/cat_visuals.tres` select the pose and change **Image Path** to
  the new file. Save.

## 7. Add another pose

The behaviour knows four pose names: `resting`, `sleeping`, `alert`,
`stretching`. With the data file alone you can:

- **give an existing pose a different image** (above);
- **use one image for several poses**: point two entries at the same file;
- **leave a pose out**: delete its entry. The behaviour then skips it, and petting
  keeps the current image.

A **new kind of behaviour** (for example `grooming`) needs one small code change
in `ShipCompanion.advance_behaviour()` (`src/companion/ship_companion.gd`), which
decides when each pose name is used. Add the new entry in the data file first.
The artwork side then works exactly like the four existing poses.

## 8. Check it in Godot

1. Run the project (F5) and start a New Game. The cat appears in the cabin. In
   the New Game dialog the preview also shows its resting image.
2. Walk up to the cat. It looks up briefly (`alert`), unless it is asleep.
3. Press E: purr, hearts and the alert pose, then back to resting.
4. To see the idle poses without waiting, temporarily set `Rest Seconds` to
   (3, 5) in the data file. **Set it back afterwards.**
5. Change boats at the boatyard and go below: the same cat in the same spot.

The automated tests check that all four files load, that the poses line up, the
behaviour and petting, and the fallbacks:

```
godot --headless --path . res://tests/test_runner.tscn -- --only=companion
```

## 9. Diagnose a missing sprite

- **The cat looks like a simple drawn shape (grey, top-down):** the resting
  image could not be loaded. The Godot output panel shows a warning such as
  `Companion art 'cat': pose 'resting' image res://Visuals/Cat/Cat_resting.png is missing or unreadable`.
  Check the name, the capitals and the folder. Make sure the file was imported
  (it has a `.import` file next to it).
- **One pose never appears:** that entry's file is missing (the same warning,
  naming it), and the pose falls back to resting.
- **The old picture still shows after replacing it:** re-import (focus the editor
  or run `--import`) and restart the game. Images are cached while the game runs.
- **White halo or missing parts:** see the background notes in §4 and the table
  in [SPRITES.md](SPRITES.md).

## 10. Prepare dog artwork later

The dog uses the same system. Nothing has to be programmed:

1. Draw the poses on one square canvas: resting, sleeping, alert (petted) and
   stretching. The four names are the same; use what fits a dog.
2. Export them into a new folder next to the cat's: *Visuals/Dog/Dog_resting.png*
   and so on.
3. In Godot, duplicate `data/companions/cat_visuals.tres` as
   *data/companions/dog_visuals.tres* (the name must be `<kind>_visuals.tres`).
4. In the copy, set **Kind** to `dog` and point each pose's **Image Path** at the
   dog files.
5. Run the game with a dog. As soon as `dog_visuals.tres` exists and its
   resting image loads, the dog uses the images instead of the drawn dog.

The dog's sound is `assets/audio/placeholder/companion_dog_pant.wav` (see
[AUDIO.md](AUDIO.md)).
