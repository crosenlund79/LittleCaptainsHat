# Iteration 004b: Cabin Refinement, Companion Animation & Developer Workflow (Report)

**Baseline:** Iteration 004, commit `4403477`, plus the owner's two uploads on
the same branch: `8ffc290` and `ff4a7b5`, which add `Visuals/Cat/` and
`Visuals/Visuals in PNG.txt`.

**Engine:** Godot 4.7.2 stable, GDScript, Compatibility renderer.

**Test environment:** Linux container, Godot headless, plus Xvfb with Mesa llvmpipe
for rendered runs.

**Not tested on Windows.** The following have not been verified on Windows:
graphics, timing, input and the developer viewer. Everything below was verified
with automated checks and with screenshots from automated runs. §14 is the
owner's checklist.

## 1. Overview

- **Halcyon 40 cabin.**
  - A visible saloon door to the deck at the existing companionway interaction.
    The working transition and its prompt "Go on deck" are unchanged.
  - A coherent layout:
    - saloon with L-galley, U-settee and table, and nav desk;
    - owner's hull with a full-width double berth aft, wardrobe, desk, sofa and
      ensuite forward;
    - guest hull with a double berth aft, a locker, heads and shower, and a bunk
      forward;
    - steps down into both hulls.
  - Collision, stations, the wake-up spot, companion spots and the art templates
    were updated with it.
- **The owner's cat artwork.**
  - The four images in `Visuals/Cat/` are used from their original location and
    under their original names, as four poses (resting, sleeping, alert,
    stretching).
  - Their behaviour is simple and data-driven: idle changes, a look-up on
    approach, and a reaction when petted, with the purr and hearts kept.
  - The dog is unchanged.
- **Self-service art.** Pose images, placement and timing live in
  `data/companions/cat_visuals.tres`.
  - Replacing an image under the same file name was demonstrated, with no code or
    data change (§5).
  - Missing images fall back gracefully, with warnings that name the file.
- **Developer documentation.**
  - `DEV_GUIDES/` with six guides: the index, sprites, companion animation, vessel
    art, audio and future modding.
  - `docs/artwork/ART_PIPELINE.md` is reduced to a pointer, so there is one source of truth.
  - README and ARCHITECTURE link to the guides and state the maintenance rule.
- **In-game viewer.** A **Developer guides** button in the main menu, shown in
  development builds only. It reads the Markdown files directly.
- **Modding.** Documented principles only; nothing was implemented (§8).
- **No save format change** (still version 5).

## 2. Halcyon 40 cabin changes

**Before (I004):**
- a saloon with a small galley block, a short settee and table, and the nav table
  by the starboard wall;
- the door to the deck was only a label ("SALOON DOOR") over a plain wall;
- the berths were boxes at the ends of two long, empty hull corridors: the owner's
  berth squeezed into the port bow taper, plus two identical guest berths aft and
  one heads block.

**After (I004b), the same hulls and saloon outline:**

| Area | Layout |
|---|---|
| Door to deck | A gap in the middle of the aft saloon wall, with the cockpit floor beyond, a half-open sliding glass door, door posts, a step and three chevrons pointing out, labelled **TO DECK**. The step is drawn exactly at the companionway interaction (tested). The interaction, its prompt **Go on deck** and the transition are unchanged. |
| Saloon | L-shaped galley in the aft port corner (stove, sink, fridge); U-settee with cushions and table to starboard; nav desk forward to port with a stool, chart and instruments; windows along the forward wall. |
| Into the hulls | Openings in the saloon walls with three-tread steps down: port at x −60…20, starboard at x 50…115. |
| Owner's hull (port) | A double berth across the full hull width aft (145 × 92 units: pillows at the transom end, blanket folded back), then wardrobe, desk, a sofa, and the **ensuite** (shower and heads) in the bow. The sleeping station and wake-up spot are at the foot of this berth. |
| Guest hull (starboard) | Guest double berth aft (130 × 92), a locker, **heads** (toilet and basin) and shower amidships, a single **bunk** in the bow. |

**On the berth sizes.** Their area is similar to before; the difference is the
arrangement:
- The owner's berth is now a rectangular double that spans the hull's width,
  instead of a pointed shape in the bow.
- It is drawn as a bed (pillows, folded blanket).
- The long empty corridors are now furnished rooms, so the beds no longer look
  lost.

Following the brief, nothing was enlarged just to fill space. Measured against
the player token (40 units across):
- the owner's berth is 3.6 tokens long and 2.3 wide, about 1.8 m × 1.15 m at
  token scale;
- tests require at least 3.5 × 2.2 for the owner's berth and 3.0 × 2.2 for the
  guest berth.

**Gameplay alignment.**
- **Single source.** Collision and art come from one furniture list in
  `tools/vessels/build_multihull_scenes.py` (`cat_furniture()`), and the tests
  check that every fixture's drawing has the same position and shape.
- **Updated points and spots.**
  - The sleeping station is at (−306, −218) and the `v_berth` wake-up spawn at
    (−288, −218), both in the owner's hull.
  - The chart station is at the nav desk.
  - `start` moved to the saloon centre.
  - The companion spots moved: settee, nav station (on the desk), the foot of the
    owner's berth, and three floor spots.
- **Unchanged.** The deck, the Starling 33 and the Petrel 36 were not changed (the
  generator was run for `halcyon_40` only, and the deck scene files are
  byte-identical).
- **Templates.** `assets/vessels/halcyon_40/templates/cabin_*.png` were re-rendered.

## 3. Companion sprite integration

- **Files.** The four files in `Visuals/Cat/` (exact names, untouched; MD5
  checked by the tests) are 1254 × 1254 px RGB.
  - They have **no alpha channel**: a white paper background.
  - All four share one canvas with the cat roughly centred.
  - Their content matches their names: resting = lying with eyes open;
    SleepingBack = asleep on its back; alert = sitting up; stretching = a big
    stretch.
- **Background removal.** Because the owner's files must not be modified, the game
  removes the background when it loads them:
  - a flood fill from the image border makes pixels close to the corner colour
    transparent (tolerance 0.12);
  - the anti-aliased rim is faded;
  - white fur enclosed by the outline (chest, belly, paws) stays.

  Images that already have transparency are used unchanged. Exporting with
  transparency is documented as the preferred format.
- **Loading cost.** Images are scaled to 320 px when loaded, which takes about
  0.13–0.15 s per pose here, once per run (cached).
- **Data.** `data/companions/cat_visuals.tres` (`CompanionVisualSet`) maps
  pose → image path, with per-pose offset, scale and flip, and sets the shared
  placement (`display_size` 72 units, `pivot` at the centre), the loading options
  and the behaviour timings.
  - The images are referenced by path, so a missing file never stops the set from
    loading.
  - A kind is linked to its set by the convention
    `data/companions/<kind>_visuals.tres` (`CompanionVisualSet.PATH_PATTERN`).
- **Alignment.** All poses go through one rule: the canvas's longer side is drawn
  72 units long, with the pivot on the resting spot. The four poses therefore
  occupy the identical rectangle (tested), and per-pose corrections are data.
  There are no compensating offsets in code.
- **Vessels.** The cat rests on the same semantic spot markers on all three boats,
  and exactly one instance exists (tested on each). The New Game dialog previews
  the drawn cat.
- **Dog.** No set exists for the dog, so it keeps the procedural drawing,
  rotation per spot and panting (tested). Adding `dog_visuals.tres` later is all
  it takes (documented step by step).

## 4. Pose-animation behaviour

`ShipCompanion` (`src/companion/ship_companion.gd`) runs a small state machine.
It is presentation only, runs on real time (it stops while a menu is open; the
simulation's Pause does not freeze it), and is never
saved.

| Pose | When | Duration |
|---|---|---|
| resting | default | 25–60 s, then a nap (60%) or a stretch |
| sleeping | idle nap, on its back | 60–150 s, then a stretch (50%) or rest |
| stretching | idle, short | 2.6 s, then rest |
| alert | the player comes close while it rests (at most every 20 s), and on petting | 1.5 s on approach; 2.0 s on petting, then rest |

- **Transitions.** Pose changes cross-fade over 0.25 s. A very small breathing
  swell (1.2% height, slower when asleep) keeps it alive. The animal is never
  rotated or deformed.
- **Petting.** One press of E plays the existing purr on the SFX bus and shows the
  alert pose with the existing rising hearts, then the cat returns to rest by
  itself. It also wakes a sleeping cat; merely walking past does not.
- **Tested over 30 simulated minutes.** All idle poses appear, there are between
  10 and 120 changes, and no pose is shorter than the 2.6 s stretch (no flicker).

## 5. Sprite replacement workflow

**Same file name** (the owner's normal case). This was demonstrated on a scratch
copy of the whole project, so the owner's file was never touched:
1. Only the copy's `Visuals/Cat/Cat_resting.png` was replaced: the same drawing,
   recoloured as an orange tabby.
2. `godot --headless --path . --import` was run.
3. The cabin was rendered.

Result: the orange cat appears in the same place at the same size. All files
under `src/` and `data/` were byte-identical to the real project (checked with
MD5). Before and after: `docs/screenshots/61_cat_art_swap_same_filename.png`. The
owner's `Visuals/Cat/Cat_resting.png` kept its MD5 `0bb77dda…`.

**Through data** (a new file name), tested in the suite:
1. A new drawing is saved outside the owner's folder.
2. A copy of the pose set points `resting` at it.
3. The new image shows, with its white background removed and at the same logical
   size, and the owner's four files are unchanged (MD5).

**Fallbacks** (tested):
- a missing alert image → the resting image is used, and petting still works;
- a missing resting image → the procedural cat, still pettable;
- no set at all → the procedural cat.

Each missing file gives one warning that names it.

## 6. Developer guide architecture

| File | Contents |
|---|---|
| `DEV_GUIDES/README.md` | Purpose, the guide list, which guide for which asset, where artwork belongs, where the implementation docs are, the maintenance rule |
| `DEV_GUIDES/SPRITES.md` | Formats, transparency, import settings, sizes and scale, pivot and alignment, slots and fallback, the shortest procedure, common mistakes |
| `DEV_GUIDES/COMPANION_ANIMATION.md` | The ten steps asked for, with the real cat files: where to export, naming, mapping, alignment, petting, changing and adding poses, checking in Godot, diagnosing, dog artwork |
| `DEV_GUIDES/VESSEL_ART.md` | The former `docs/artwork/ART_PIPELINE.md`, updated, plus how layouts, profiles, slots, templates, fallbacks and sail mapping relate |
| `DEV_GUIDES/AUDIO.md` | Buses, which file is used where, how to replace a sound, loop requirements |
| `DEV_GUIDES/MODDING_FUTURE.md` | Principles, the decisions needed before any mod support, what is deliberately not done |

- **One source of truth.** `docs/artwork/ART_PIPELINE.md` now only points to the guides. The
  obsolete I004 convention (`assets/companions/<kind>.png`, one sprite per kind)
  was removed from code and docs.
- **The maintenance rule** ("an iteration that changes a workflow updates its
  guide in the same iteration") is stated in `DEV_GUIDES/README.md`, `README.md`
  and `docs/technical/ARCHITECTURE.md`.
- **Link checks.** `test_dev_guides` checks every Markdown link in the guides,
  README, ARCHITECTURE, `docs/artwork/ART_PIPELINE.md` and this report, and every repository
  path written in backticks in the guides.

## 7. In-game developer viewer

- **Access.** Main menu, top-right: **Developer guides**. It is shown only when
  `DevGuides.is_available()`: a debug build, with `res://DEV_GUIDES/*.md` present.
  - It is therefore available when running from the editor or with
    `godot --path .`.
  - In an exported game the Markdown files are not included (Godot exports
    resources only), so the button is hidden.
  - Release builds never show it.
  - It is not in the HUD or any gameplay screen.
- **Viewer** (`src/ui/dev_guides_menu.*`, a modal in the game's theme):
  - the guide titles on the left, index first;
  - the selected guide on the right, in a scrolling `RichTextLabel`;
  - Close or Esc.
- **Content.** The `.md` files are read at runtime and converted by `MarkdownLite`
  (`src/ui/markdown_lite.gd`). It handles headings, paragraphs (with wrapped lines
  joined), lists, bold and italic, inline and fenced code, links shown as
  "text (target)", tables as aligned rows, and rules. There is no second copy of
  the text, no plugin and no browser.
- **Missing files.** No guides → no button, and the viewer explains why if opened
  directly. A missing guide file → a message, with no error (tested).
- **Ligatures.** Barlow's ligatures turned `--` into a dash, which garbled commands
  such as `--headless`. The viewer turns font ligatures off.
  - My first fix (a per-span BBCode tag) printed literally. I caught it in the
    rendered screenshot.
  - It is now a font-level setting, and the test checks the displayed text, not
    only the generated BBCode.

## 8. Future modding compatibility

**Reviewed, not implemented.** The I004 architecture already has the important
properties:
- stable ids saved instead of names or paths;
- data-driven vessel definitions and visual profiles;
- art separated from layout;
- versioned saves with an unknown-vessel fallback.

**Small, directly justified changes in this iteration:**
- companion art moved from a hardcoded file pattern to a data resource;
- images are referenced by path, so a missing image degrades gracefully.

**Documented in `DEV_GUIDES/MODDING_FUTURE.md`:**
- the known remaining hardcoded asset references (default sounds, which can be
  overridden in the Inspector);
- the decisions any future mod support would need: resource packs, catalog
  merging, save fallbacks, no scripts, versioning.

No mod folders, loaders, script execution or API were added.

## 9. Save/load impact

- **No format change** (save version 5).
- **Poses are presentation only and not serialized.** The test checks that a save
  contains neither "pose" nor the image names.
- **Kept across loads and boat changes.** Companion kind, spot and schedule
  persist as before; after loading and after changing boats, the same cat is in
  the same spot, exactly once, still pettable (tested).
- **Existing saves load unchanged**, including all migration tests from earlier
  iterations.
- **Restart check:** 16/16 PASS (the trimaran underway, with the dog).

## 10. Test results

| Run | Result |
|---|---|
| Headless suite | **1341 passed, 0 failed** (1164 before + 177 new) |
| Rendered suite (Xvfb, opengl3, with screenshots) | **1349 passed, 0 failed**, 80 screenshots (8 screenshot-only checks more than headless) |
| Restart check (`--phase=write`, then `--phase=read`) | **16/16, PASS** |
| Same-file-name art swap on a project copy | works; no code or data changes (§5) |

**New suites:**

| Suite | Checks | Covers |
|---|---|---|
| `test_catamaran_cabin` | 53 | door drawn at the interaction, "Go on deck" prompt and E to deck; art = collision for every fixture; complete arrangement; berth proportions; both hulls reached with real movement keys and back; walkable to every piece of furniture; nav station → chart; sleep → wake beside the owner's berth, connected to the saloon; companion spots pettable |
| `test_companion_art` | 74 | the four files (exact paths, imported) and the mapping; background removal (real art and a synthetic case; enclosed white kept); identical logical size and position; New Game preview; each pose on screen; 30 min of behaviour; approach alert, settling, sleeping not woken by walking; petting (alert, hearts, purr on SFX, back to rest); fallbacks; replacement through data with the originals untouched; all three vessels; save/load and boat switching; the dog unchanged |
| `test_dev_guides` | 50 | six guides exist and are linked; links and repository paths resolve; Markdown conversion; viewer opens from the main menu, lists six guides, shows formatted content, scrolls, closes with Close and Esc; missing directory and missing file |

**Regression.** All earlier suites ran unchanged and pass:
- routing, simulation, wind and sailing;
- reassessment (helm);
- sailing presentation (sail animation, spinnaker);
- life aboard (companion, sleep, chart sidebar);
- chart tabs and pause;
- vessels and boatyard (322 checks, including walking on all six areas with the
  new cabin);
- save manager and voyage persistence;
- the end-to-end gameplay flow.

## 11. Visual verification

Screenshots in `docs/screenshots/`:
- `51_catamaran_cabin.png`: the whole new cabin;
- `50_catamaran_door_prompt.png`: the player at the door with "E Go on deck";
- `52_catamaran_woke_at_berth.png`;
- `54_cat_pose_resting.png`, `54_cat_pose_sleeping.png`, `54_cat_pose_alert.png`
  and `54_cat_pose_stretching.png`: close-ups in the cabin;
- `55_cat_petted.png`;
- `58_cat_on_starling_33.png`, `58_cat_on_halcyon_40.png`,
  `58_cat_on_petrel_36.png`;
- `53_new_game_cat_art.png`;
- `59_dog_unchanged.png`;
- `57_cat_replaced_resting_pose.png`;
- `61_cat_art_swap_same_filename.png`;
- `60_dev_guides_viewer.png`.

I checked the cat close-ups and the cabin images visually. The background is
removed cleanly, with no white halo; the poses line up; and the door, galley,
settee, nav desk, berths, heads and bunk read as intended.

## 12. Files changed

**New:**
- **Guides:** `DEV_GUIDES/README.md`, `SPRITES.md`, `COMPANION_ANIMATION.md`,
  `VESSEL_ART.md`, `AUDIO.md`, `MODDING_FUTURE.md`.
- **Companion:**
  - `src/companion/companion_visual_set.gd`, `src/companion/companion_pose_art.gd`;
  - `data/companions/cat_visuals.tres`;
  - `Visuals/Cat/*.png.import` (Godot import files for the owner's images; the
    images themselves are unchanged).
- **Viewer:** `src/dev/dev_guides.gd`, `src/ui/markdown_lite.gd`,
  `src/ui/dev_guides_menu.gd` and `.tscn`.
- **Tests:** `tests/helpers/walkability.gd`,
  `tests/suites/test_catamaran_cabin.gd`, `test_companion_art.gd`,
  `test_dev_guides.gd`.
- **Report:** `ITERATION_004B_REPORT.md`, and new screenshots in
  `docs/screenshots/`.

**Changed:**
- **Code and scenes:**
  - `src/companion/ship_companion.gd`: pose behaviour; the old single-PNG lookup
    removed;
  - `src/app/app.gd` / `.tscn` and `src/ui/main_menu.gd` / `.tscn`: viewer access;
  - `src/vessels/halcyon_40/cabin.tscn` and `cabin_visual.tscn`: regenerated;
  - `tools/vessels/build_multihull_scenes.py`: the new cabin;
  - `assets/vessels/halcyon_40/templates/cabin_*.png`: re-rendered;
  - `tests/test_runner.gd`: three suites registered.
- **Docs:** `README.md`, `docs/technical/ARCHITECTURE.md`, `docs/artwork/ART_PIPELINE.md` (now a pointer).

## 13. Known limitations

- **Loading the cat.** It costs about 0.5–0.6 s, once per run, the first time a
  cabin is shown. This comes from decoding and scaling the 1254 px images;
  smaller exports would load faster (documented).
- **Background removal** needs a plain background reaching the border and a closed
  outline. Exports with transparency avoid both conditions.
- **The cat's view.** The owner's cat is drawn in a side or front view while the
  cabins are top-down. It reads well (see the screenshots), but its perspective
  differs from the furniture. This is intended, as it is the owner's art.
- **Behaviour.** The cat does not walk between spots; it changes spot instantly on
  the game-time schedule, as before. Pose timing is in real time.
- **The dog** has no artwork, as specified.
- **Viewer formatting.** The Markdown converter covers what the guides use; it is
  not a full Markdown renderer. Tables are shown as aligned rows, not a grid.
- **Catamaran layout.** It is checked by automated walking and interaction tests
  and by screenshots, not by play-testing.

## 14. Windows acceptance checklist

1. **Halcyon 40 cabin.** Start a New Game, take the Halcyon 40 at the boatyard and
   go below.
   - The saloon door aft (cockpit beyond, chevrons, "TO DECK") is obvious.
   - Walking up to it shows "E Go on deck", and E takes you on deck.
2. **Walking.** Walk from the saloon down the steps into both hulls and back.
   - Port hull: the owner's cabin (big berth aft), wardrobe, desk, sofa, ensuite
     forward.
   - Starboard hull: the guest berth, heads, shower and bunk.
   - Movement never snags in the openings.
3. **Nav desk.** Use it (chart opens), close the chart, and you are back in the
   cabin.
4. **Sleep.** Sleep at the owner's berth: you wake beside it and can walk back to
   the saloon.
5. **The cat:**
   - it looks like the owner's drawings, with no white boxes or halos, at a sensible
     size, on all three boats;
   - walking up makes it look up; E makes it sit up with hearts and a purr, then
     settle;
   - after a minute or two it naps on its back or stretches; it never flickers.
6. **New Game.** The dialog shows the drawn cat. Choose the dog: the dog looks and
   behaves as before.
7. **Save and load.** Save on the trimaran in the cabin, quit, start and load:
   the same cat in the same spot, pettable.
8. **Art swap.** Replace `Visuals/Cat/Cat_alert.png` with any other PNG of the same
   name (keep a backup), focus the editor so it re-imports, run: the new image
   shows when petting. Restore the original.
9. **Developer guides.** Run from the editor:
   - the main menu shows "Developer guides" top-right; it lists six guides;
   - the text is readable and long guides scroll with the wheel;
   - Close and Esc work.
10. **Exported build.** If you make one, confirm the Developer guides button is
    absent.
11. **Load time.** Check the first time the cabin is shown (cat image loading,
    expected well under a second).

## 15. Commit and push

Committed on the branch `claude/determined-brahmagupta-3v95mx`, then pushed. A
report cannot contain the hash of the commit that adds it, so the exact hash and
the verified push status are given in the delivery summary and can be seen with
`git log -1`.
