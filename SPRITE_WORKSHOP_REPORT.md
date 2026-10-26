# Sprite Workshop: Phase 1 report (Revision 0.105b)

This report is for development. The artist's entry point is `art_replacements/README_START_HERE.md`; it can be read without this report. All counts below come from the manifests: `art_replacements/INDEX.md` is generated from them by `tools/art/build_index.py`. Nothing here was tested on Windows yet.

## 1. Current artwork audit

The audit read every drawing path in the game: textures, scene shapes, and the procedural `_draw` code. The game uses five kinds of renderer:

| Renderer | What uses it | Replaceable today? |
|---|---|---|
| **Layered PNG, full canvas** (`VesselVisual` slots) | The four boats' deck and cabin layers: hull, deck, coachroof, deck details, shadow, rigging, mast, cabin shell, furniture, cabin details. Existing illustrated PNGs are 2× the scene canvas (for example 1760 x 640 for the Arctic Wanderer 26's 880 x 320 units). | **Yes** (40 entries) |
| **Pose PNG set** (`CompanionVisualSet`) | The cat (Snøvs) and the dog: 4 poses each, 256 x 256 sources drawn 100 / 116 units across. | **Yes** (8) |
| **Layered fish PNG** (`FishArt`) | 16 fish and sharks × body / tail / eyelid on a 512 x 256 canvas with tail pivot and eye from `data/fishing/fish_art.json`; 3 junk pictures; 19 thumbnails. | **Yes** (70) |
| **Procedural with a PNG hook** | The Captain's hat (worn, stored, blowing; the old `assets/hat/` hook has no PNGs), provisions (per-boat hook), the harbour landmark (`HarbourArt`, Copenhagen's Nyhavn only). | Hat **yes** (3); the other two keep their own existing hooks |
| **Procedural `_draw`** | The Captain (`SailorDrawing`: walking arms, carrying pose), windlass and chain, anchor ball / rode / buoy, Magic Anchor gear, solar panels, rod and line, galley stove, trophy board, cabin map frame, hat hook, gangplank, the whole harbour set (pontoon, quay, bollards, lamps, cleats, signs and icons), drifting leaves / seaweed / foam / paper, waves, rain, and the UI pictures (Go Ashore icons, haul-out scene, cooking). | Buoy, ball, solar panel **yes** (3, through new hooks); the rest are catalogued |
| **Scene polygons** (`ProceduralShape` in each boat scene) | Placeholder furniture and deck fittings under the boat layers. | Drawn as part of the boat layers (REFERENCE_ONLY entries) |

Notes:

- The owner's original cat drawings in `Visuals/Cat/` are Captain-owned art. The workshop never reads or writes them.
- The existing `assets/` art is never overwritten either: replacements live only in `art_replacements/`.
- `anchor_ambience.gd` draws nothing since I017, so it is not catalogued.
- Fenders exist only painted into each boat's `deck_base` layer.

## 2. Folder hierarchy

The tree has 10 categories and 34 working folders, each holding a `manifest.csv` and a `README.md`. Root files: `README_START_HERE.md`, `INDEX.md`.

```
art_replacements/
  01_characters/captain/
  02_pets/snovs_cat/   02_pets/dog/
  03_boats/arctic_wanderer_26/ starling_33/ petrel_36/ halcyon_40/
  03_boats/shared_deck_equipment/   03_boats/shared_cabin_furniture/
  04_cabins_and_interiors/shared_props/
  05_sailing_equipment/anchor/   05_sailing_equipment/lights_and_gangplank/
  06_fishing_equipment/
  07_fish_and_sea_creatures/<16 species>/   07_fish_and_sea_creatures/junk/
  08_harbours_and_towns/shared_harbour/   08_harbours_and_towns/landmarks/
  09_nature_and_environment/
  10_shared_props/ui_illustrations/
```

- One folder per production task: one boat, one fish species, one pet.
- Internal boat ids are kept as they are, with the display names in the rows: `starling_33` = Wing 33, `petrel_36` = Frogleap 36, `halcyon_40` = Clam 40.
- Snøvs is the ship's cat (companion kind `cat`). Her ids are `pet.snovs.*`.

## 3. Manifest schema

The 20 required columns are, in order:

`asset_id, filename, display_name, description, category, current_source, display_width, display_height, source_width_2x, source_height_2x, complexity, hand_draw_priority, priority_rank, view_direction, view_count, transparent_background, pivot_or_origin, replacement_mode, integration_status, notes`

Six columns are added for this architecture:

| Column | Meaning |
|---|---|
| `renderer` | How the game draws the asset today |
| `used_in` | Where it appears |
| `design_subject` | The reusable design it belongs to (used for unique-design counts) |
| `set_a`, `set_b`, `set_c` | Whether the drawing is needed in each inventory scenario |

Rules:

- **Ids** are stable and dotted, in families: `boat.<vessel>.<deck|cabin|sails>.<layer>`, `pet.snovs.<pose>`, `fish.<species>.<layer>`, `character.captain.hat_<slot>`, `equipment.anchor.*`, `harbour.shared.*`, `nature.*`, `ui.*`.
- **Validation** (`build_index.py --check`, and at run time `ArtworkResolver`):
  - required columns present;
  - no duplicate id;
  - no duplicate output file;
  - known status and complexity;
  - `.png` file names only;
  - whole-number sizes.

## 4. Asset counts

| | Entries |
|---|---|
| Catalogued | **202** |
| **READY** (pathway implemented and verified per entry) | **124** |
| ADAPTER_REQUIRED | **42** |
| REFERENCE_ONLY | **36** |

| Category | READY | Adapter | Reference |
|---|---|---|---|
| 01 Characters | 3 | 1 | 0 |
| 02 Pets | 8 | 0 | 0 |
| 03 Boats | 41 | 16 | 17 |
| 04 Cabins and interiors | 0 | 7 | 1 |
| 05 Sailing equipment | 2 | 4 | 1 |
| 06 Fishing equipment | 0 | 1 | 1 |
| 07 Fish and sea creatures | 70 | 0 | 0 |
| 08 Harbours and towns | 0 | 9 | 2 |
| 09 Nature and environment | 0 | 4 | 2 |
| 10 Shared props (UI pictures) | 0 | 0 | 12 |

The 124 READY entries are not just listed. Each one is checked by `test_sprite_workshop` `[ready]`: a fixture PNG is installed under its file name, the real consumer is asked (boat scene slot, companion set, `FishArt`, `HatArt`, anchor signals, solar panels), and the test confirms the consumer shows the fixture. The fixture is then removed.

## 5. Complexity

| Complexity | Points | READY | Adapter | Reference | All |
|---|---|---|---|---|---|
| C1, simple | 1 | 50 | 12 | 9 | 71 |
| C2, moderate | 3 | 22 | 28 | 25 | 75 |
| C3, detailed | 8 | 36 | 2 | 1 | 39 |
| C4, complex composition | 20 | 16 | 0 | 1 | 17 |

Complexity follows the artistic work, not the pixel count:

- Fish eyelids and thumbnails are C1.
- Tails and junk are C2.
- Fish bodies, pets, the Captain and coachroofs are C3.
- Hulls, decks, cabin shells and furniture layers are C4.

## 6. Resolution

**Display size** is the on-screen size at the 1600 x 900 reference: scene units × the largest camera zoom the object is seen at × 0.833 (the 1920 x 1080 viewport shown in a 1600 x 900 window). **Source size** is 2× the display size.

| Class (longest source side) | READY | Adapter | Reference |
|---|---|---|---|
| S, up to 128 px | 23 | 16 | 10 |
| M, up to 512 px | 10 | 8 | 24 |
| L, up to 1024 px | 51 | 18 | 0 |
| XL, over 1024 px | 40 | 0 | 2 |

Examples:

| Asset | Display (px) | Source (px) |
|---|---|---|
| Anchor buoy | 30 x 30 | 60 x 60 |
| Snøvs | 142 x 142 | 284 x 284 |
| Fish | 420 x 210 | 840 x 420 |
| Arctic Wanderer 26 deck layer | 1100 x 400 | 2200 x 800 |
| Wing 33 cabin layer | 1447 x 517 | 2894 x 1034 |

Natural aspect ratios are kept: the rod is 176 x 100 and the solar panel 100 x 250.

The resolver accepts any size from **0.5× to 4×** the 2× size with the manifest's shape (±2 %). This means the existing art, for example the 1760 x 640 boat layers or the 256 px cat, still fits the same rules.

## 7. Unique designs versus directional drawings

The boats are drawn **top-down** and the game turns the **camera** for the eight headings. **One top-down drawing serves all eight directions**: this is the real architecture, not a rotated stand-in. So every entry has `view_count` 1.

The I018 deck is not an eight-sprite system, and the counts do not inflate it into one. Pet poses are separate drawings of one design (Snøvs = 1 design, 4 drawings). Fish layers are separate drawings of one design (cod = 1 design, 4 drawings including the thumbnail).

| Scenario | Unique designs | Static drawings | C1 / C2 / C3 / C4 | Res. S / M / L / XL | Workload points |
|---|---|---|---|---|---|
| **A**, absolute reusable minimum | 38 | 50 | 3 / 8 / 23 / 16 | 5 / 4 / 21 / 20 | **531** |
| **B**, practical illustrated set | 52 | 93 | 11 / 31 / 35 / 16 | 16 / 12 / 37 / 28 | **704** |
| **C**, full distinct-object set | 81 | 187 | 69 / 64 / 38 / 16 | 47 / 31 / 69 / 40 | **885** |

What each scenario contains:

- **A** has one drawing per design for:
  - each boat's hull, deck, cabin shell and furniture (16 C4: boats cannot share these);
  - the Captain and the worn hat;
  - Snøvs resting;
  - each fish body and junk picture (eyelid, tail and thumbnail are derived);
  - the shared harbour set;
  - the buoy, solar panel, rod and stove.
- **B** adds:
  - the coachroofs and detail layers;
  - all four Snøvs poses and the dog's resting pose;
  - fish tails;
  - the hat variants, windlass, Magic Anchor gear, ball and gangplank;
  - signs and icons;
  - leaves and seaweed.
- **C** is every meaningfully distinct in-world object:
  - all pet poses, fish layers and thumbnails;
  - sails, mast and rigging;
  - the individual deck fittings and furniture drawn inside the layers.

What the counts exclude:

- The 12 UI pictures.
- Weather and water effects.
- The bespoke Copenhagen landmark.

Points are relative (C1 = 1, C2 = 3, C3 = 8, C4 = 20), not hours or costs. The C4 boat layers dominate every scenario: 320 of A's 531 points.

## 8. The first 25 hand-drawing priorities

Ranking evidence: time on screen (deck and cabin are where play happens), emotional weight (Snøvs, the Captain, the hat), uniqueness to the game, reuse (the solar panel serves all four boats), and benefit from hand illustration. Complexity is weighed as cost.

| # | Subject | Why | Complexity | Display → source | READY |
|---|---|---|---|---|---|
| 1 | Snøvs resting | On screen almost always; the heart of the boat | C3 | 142² → 284² | yes |
| 2 | The Captain | Always on screen | C3 | 57² → 114² | adapter (walking arms) |
| 3 | Hat (worn) | The game's title object, always visible | C2 | 38² → 76² | yes |
| 4–7 | Arctic Wanderer 26: deck, hull, cabin furniture, cabin shell | The starter boat; fills the screen | C4 | 1100x400 → 2200x800; cabin 1247x453 → 2494x906 | yes |
| 8–10 | Snøvs sleeping, alert, stretching | Idle and petting moments | C3 | 284² | yes |
| 11 | AW26 coachroof | Centre of the deck view | C3 | 2200x800 | yes |
| 12–14 | Cod, mackerel, herring bodies | The commonest catches in Danish water | C3 | 420x210 → 840x420 | yes |
| 15 | Hat (stored) | On the cabin hook; carried | C2 | 130² | yes |
| 16 | Anchor windlass | Used at every anchorage | C2 | 70x100 | adapter |
| 17 | Rod in holder | Fishing is a core loop | C2 | 176x100 | adapter |
| 18 | Galley stove | Cooking and coffee moments | C2 | 96x68 | adapter |
| 19–20 | Pontoon, quay | Every harbour arrival | C2/C3 | 1000x110, 1000x324 | adapter (tiling) |
| 21–22 | Wing 33 deck and cabin furniture | The next boat most Captains sail | C4 | 2650x946, 2894x1034 | yes |
| 23 | Magic Anchor gear | New and whimsical | C2 | 42² | adapter (rotates) |
| 24 | Solar panel | Reused on all four boats, tiny cost | C1 | 100x250 | yes |
| 25 | Anchor buoy | Every anchorage; a 10-minute drawing | C1 | 60² | yes |

The full ranked list of all 202 entries is in `INDEX.md`.

## 9. Recommended production batches

1. **Quick wins** (an evening): anchor buoy, anchor ball, solar panel, hat worn and stored. All READY, C1/C2, seen constantly.
2. **Snøvs**: the four poses on one canvas.
3. **The Arctic Wanderer 26**: deck, hull, coachroof, deck details, then the cabin layers. Start from the existing PNGs as templates.
4. **Danish fish**: cod, herring, mackerel, perch, sea trout, garfish, flatfish (body, tail, eyelid, thumbnail).
5. **The other three boats**, one per batch.
6. **Warm-water fish, sharks and junk.**
7. **Adapter items**, once their adapters exist: the Captain, windlass, rod, stove, harbour set.

## 10. Resolver architecture

`src/art/artwork_resolver.gd`, class `ArtworkResolver`, provides `get_artwork(asset_id, fallback) -> Texture2D`.

1. **Index**:
   - On first use it finds every `manifest.csv` under `res://art_replacements` (34 small files) and reads them once into a dictionary keyed by id.
   - It validates required columns, unknown statuses, duplicate ids and duplicate output files (the first is kept, the second warned).
2. **Resolve** (once per id, then cached as a texture or as "none"). Only **READY** entries resolve.
   - An **imported** PNG (the editor has seen it) loads as a resource.
   - A PNG **not yet imported** (just copied in) is read with `Image.load_from_file`.
   - In both cases it is checked:
     - readable;
     - the manifest's aspect ratio ±2 %;
     - 0.5–4× the 2× size.
   - Then it is mipmapped into an `ImageTexture`.
3. **Fallback**: missing → the caller's own art, silently. Invalid → the caller's own art plus one `push_warning("Sprite Workshop: …")` per problem, also kept in `get_warnings()`.
4. **Consumers**, each a few lines:

| Consumer | Ids it asks for | Behaviour |
|---|---|---|
| `VesselVisual.apply()` | `boat.<vessel>.<deck/cabin>.<layer>`, derived from the scene path and the profile's file names | Skipped when the Artwork setting is procedural |
| `CompanionVisualSet.get_texture()` | `workshop_id` + pose, set in `data/companions/*_visuals.tres` | The replacement goes through the same background removal and resizing as the original |
| `FishArt.layer()` | `fish.<species>.<layer>` | |
| `HatArt.get_texture()` | `character.captain.hat_<slot>` | |
| `AnchorSignals` | buoy and ball | Textures drawn centred at 24 / 26 units |
| `SolarPanels` | the solar panel | Texture drawn into each panel rectangle |

Pictures never change gameplay. The game keeps its own source for all of these:

- walkable polygons;
- collisions;
- station positions;
- pet safe spots;
- routes and anchorages;
- fish data;
- saves.

The Snøvs and coachroof tests check that walkable cells and resting places are unchanged.

## 11. Integrated categories and READY counts

| Category | READY entries |
|---|---|
| Boat layers | 40 |
| Fish and junk | 70 |
| Pets | 8 |
| Hat | 3 |
| Anchor buoy and ball | 2 |
| Solar panel | 1 |
| **Total** | **124** |

## 12. Categories still needing adapters (42)

| Item | Adapter needed |
|---|---|
| The Captain | Body plus arm layers (walk cycle) |
| Sails and boom (16) | `SailRig` mesh mapping for the Workshop path. The old profile slot still works. |
| Windlass and chain | |
| Stowed anchor | |
| Magic Anchor gear | Rotating sprite |
| Gangplank | 3-slice, length varies |
| Rod | Pivoting tip |
| Galley stove | Base plus procedural flames |
| Trophy board | |
| Hat hook | |
| Provisions (4) | The per-boat hook works, but not yet through the Workshop |
| Harbour set | Pontoon and quay need tiling; bollard, lamp, cleat, sign and icons need a `HarbourDressing` sprite adapter |
| Drifting leaf, seaweed, foam, paper | |

## 13. The three demonstration replacements, exactly

All three are in `tests/suites/test_sprite_workshop.gd`, rendered and headless. Fixtures are made in code (`tests/helpers/art_fixtures.gd`) as a bright pink and yellow check, written to the manifest's file name, then removed.

| Step | 1. Anchor buoy (small prop, procedural adapter) | 2. Snøvs resting (pet, pose set) | 3. AW26 coachroof (layered composition) |
|---|---|---|---|
| 1. Original with no PNG | `rb_16_workshop_buoy_original` | `rb_18_workshop_snovs_original` | `rb_20_workshop_coachroof_original` |
| 2–3. Valid PNG shown | 60 x 60 → `rb_17_workshop_buoy_replaced` | 284 x 284 → `rb_19_workshop_snovs_replaced` | 2200 x 800 → `rb_21_workshop_coachroof_replaced` |
| 4. Size and pivot | 24 x 24 units, centred on the buoy | 100 x 100 units, centred on the resting spot; spot and state unchanged; other poses unchanged | Covers exactly the 880 x 320 canvas from its top-left; other layers unchanged; walkable cells unchanged |
| 5–6. Removed | Original back | Original back | Original back |
| 7–8. Invalid | 48 x 96 → refused, warning names the shape; text file named `.png` → "could not be read" | 284 x 142 → refused with warning | 1760 x 1760 → refused with warning |

The coachroof fixture deliberately fills the whole layer canvas, which shows the canvas's exact extent in the screenshot. A real coachroof drawing is transparent except for the roof.

**For the Captain, after downloading the ZIP:**

1. Draw a 60 x 60 PNG and save it as `art_replacements/05_sailing_equipment/anchor/anchor_buoy.png`.
2. Open the project, run, and anchor: your buoy floats there.
3. Delete the file and run again: the original buoy is back.
4. Do the same with `art_replacements/02_pets/snovs_cat/resting.png` (284 x 284) and `art_replacements/03_boats/arctic_wanderer_26/deck_coachroof.png` (2200 x 800, transparent except the roof, bow to the right).

These steps are also in `WINDOWS_ACCEPTANCE_0_105B.md` §18–21.

## 14. How missing and invalid images fall back

| Case | Result |
|---|---|
| Missing | The original art; no message |
| Wrong shape, too small or too large, unreadable, or not a PNG | The original art; one `Sprite Workshop:` warning in Godot's Output panel naming the id, the file and the expected size |
| Duplicate id or file in a manifest | The first row is kept; a warning is printed |

Gameplay never stops for art.

## 15. Import and runtime performance

**Measured.**

- Manifests are read once per run, lazily (see the report's performance section for the time).
- Each id is resolved once: `[resolver]` measured 1 file load for 51 requests.
- Nothing is pre-loaded at start-up, nothing is scanned per frame, and missing files cost one `FileAccess.file_exists` per READY id, once.
- With no replacements installed (the shipped state), the game loads exactly the textures it loaded before. The extra work per id is one dictionary look-up.

**Editor workflow.** A PNG copied in while the editor is open is imported when the editor regains focus. A PNG copied in with the editor closed is imported when the project opens. Either way, the next game run uses it. `restart_105b` C reproduces this:

1. Install the PNG.
2. Run `godot --import`.
3. A new process uses the imported resource.
4. Remove the PNG.
5. The next process is back to the original.

A not-yet-imported PNG also works (it is read directly). A running game needs a restart to see new art; there is no hot reload.

**Memory.** Source sizes are capped by the manifest (largest: the Frogleap 36 cabin layers, 3000 x 1600, about 26 MB each in memory as uncompressed RGBA with mipmaps). Only one boat's layers are in use at a time.

## 16. Current limitations

- 42 entries need adapters (§12). The walking Captain is the most important.
- Provisions and the harbour landmark keep their older, separate PNG hooks.
- Replacements apply when the game starts (no hot reload).
- Exported builds are not covered. The editor-run workflow is the supported one this phase.
- The Snøvs replacement assumes the companion is the cat. The dog has its own ids (`pet.dog.*`).
- Display sizes use the largest camera zoom per area. On smaller boats the art may be shown a little smaller than its display size, which is harmless.

## 17. What the Captain should draw first

Start with the quick wins:

1. The **anchor buoy** (60 x 60).
2. The **solar panel** (100 x 250).
3. The **hat** (76 x 76 worn, 130 x 130 stored).

They take minutes, are seen constantly, and prove the workflow end to end. Then draw **Snøvs resting** (284 x 284) and the other three poses on the same canvas. Then the **Arctic Wanderer 26's deck layers**, starting from the existing PNGs in `assets/vessels/arctic_wanderer_26/illustrated/` as tracing templates.
