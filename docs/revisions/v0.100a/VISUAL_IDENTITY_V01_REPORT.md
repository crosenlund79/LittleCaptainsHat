# Visual Identity V01: A Little Personality (Report)

**Game:** Little Captain's Hat (provisional name; developed as Next Harbor until Iteration 006).
**Version:** 0.100a. **Engine:** Godot 4.7.2 stable, GDScript, Compatibility renderer.
**Tested on:** Linux only: headless runs, plus Xvfb with Mesa llvmpipe software OpenGL for rendered runs.
**Not tested on Windows.** The owner's checks are in [WINDOWS_ACCEPTANCE_VISUAL_V01.md](WINDOWS_ACCEPTANCE_VISUAL_V01.md).
**The art direction is a prototype and has not been approved.** It waits for the owner's review.

## 1. Repository and starting commit

- Repository: `https://github.com/crosenlund79/LittleCaptainsHat`. The original Next Harbor repository was not connected to this session and was not touched.
- Starting commit: `ea002ec` (I006, *verified final test and Git results in the report*), clean working tree.
- I006 baseline check: full headless run with Godot 4.7.2, **2,162 passed, 0 failed, exit code 0**. That matches the I006 report.

## 2. Protected baseline tag

- `i006-pre-visual-identity` is an annotated tag on `ea002ec`, created locally.
- **The tag could not be pushed.** The session's Git proxy refused the tag push ("remote end hung up", three tries); branch pushes work.
- The baseline is recoverable without the tag: `ea002ec` is in the branch history and also the head of `claude/determined-brahmagupta-3v95mx` on GitHub.
- To publish the tag from a normal checkout: `git push origin i006-pre-visual-identity`.

## 3. Final development branch

`claude/friendly-fermat-dey23f`. Every checkpoint was committed and pushed on its own:

| Checkpoint | Commit | Content |
|---|---|---|
| A | `02241c8` | The captain's hat |
| B | `dded561` | Secret hat achievements |
| C | `62ab2c8` | Typography, branding, save safety, versioning |
| D | `aca1ec9` | Illustrated Starling and Copenhagen harbour prototype |
| E | see §25 | Diagnostic log, restart check, docs, verification, version |

## 4. Hat ownership architecture

- **One hat, owned by the player.** `HatState` (`src/core/hat_state.gd`) lives in `SessionState.hat` and is saved as the `hat` section. GameSession is its only writer.
- **States:** `stored` (on its hook in the cabin), `worn`, `carried` and `lost`. *Carried* means taken off and tucked under the arm; it is safe from the wind. It lets **H** take the hat off on deck without walking to the cabin.
- **Switching boats, rescue and loading** never copy, reset or restore the hat. A stored hat shows on the new cabin's hook. A worn or carried one stays with the player. A lost one stays lost.
- **Interaction**, with no inventory system:
  - each cabin has a `hat` station (E): *Put on captain's hat*, *Hang up captain's hat* or *Look at the empty hat hook*;
  - the `captains_hat` action (**H**) toggles worn and carried. It is handled by App like L, never in menus, and is not F9.
- **Hooks aboard:**

  | Boat | Hook | Station |
  |---|---|---|
  | Starling 33 | above the forward port locker | (200, −52) |
  | Halcyon 40 | above the owner's sofa | (230, −244) |
  | Petrel 36 | on the port side, forward of the settee | (168, −70) |

  - The multihull cabin generator was updated too.
  - The Halcyon hook was moved from (190, −244) after the companion test found that it could take focus from the cat at the nav station.
- **Art, kept separate from state and collision:**
  - `HatHook` at `Layout/HatSpot`;
  - `PlayerHat`, a child of the player (the collision circle is unchanged);
  - `HatBlowAway`, the short effect on deck.
- **Three replaceable slots** (stored, worn, blowing), resolved by `HatArt` (`data/hat/hat_art.tres`) in this order: an assigned texture, then `assets/hat/hat_<slot>.png`, then the procedural `HatDrawing` (white crown, navy band, black peak, brass badge, uneven ink outline).
- **Save format version 10.** `_migrate_9_to_10` gives every I006 save the original hat on its hook, with hat checks starting at the saved time.

## 5. Wind-loss mechanics and balancing

- **Wind source:** the one authoritative `WeatherModel` sample at the boat. No second wind system was added.
- **Checks:** `Simulation._check_hat()` runs after every step of `advance()`, on an absolute 60-game-second grid.
  - A check samples the weather only while the hat is worn on deck. Sleeping and remote work count as below deck.
  - Underway, the position at each check is interpolated along the course inside the step. This is exact because the speed is constant between evaluation points.
  - There are no frame-based dice rolls.
- **Strain** (`data/hat/hat_config.json`, `HatConfig`):
  - effective wind = max(sustained, gust − 10 kn);
  - 25 kn: 0.25 per minute; 35 kn: 1.0; 45 kn: 2.0;
  - gusts from 45 kn add 0.5; gusts from 55 kn add 4.0 (a squall can snatch a hat);
  - the harbour halves the strain;
  - strain recovers by 2 per minute when the hat is not at risk.
- **Threshold:** each hat blows away at its own threshold, between 20 and 40, fixed from the game's seed and the hat's serial number.

| Wind on deck at sea (sustained / gusts) | The hat lasts |
|---|---|
| below 25 kn | for ever |
| 30 / 37 kn | 80–160 game minutes |
| 40 / 50 kn | 13–27 game minutes |
| any wind with gusts of 55 kn or more | 3.5–7 game minutes |

- **Fair warning:**
  - The first check with any risk only warns ("Better hold onto your hat! The wind is … kn. Go below, or press H to take it off.") and drops time to 1×, like a weather warning.
  - Another warning comes only after the hat has fully recovered and 30 game minutes have passed.
- **Loss:** the hat is removed from the player, a short tumble-downwind effect plays with a soft sour note, and the state persists. A humorous notification shows (four lines in turn, the first "Your captain's hat has decided to explore the ocean without you.").
  - A *Notable moments* line names the real place and wind (`HatStory`): the harbour the boat lies in, or the distance to the nearest harbour in the catalogue.
  - No damage, no money.
- **Balancing change during Checkpoint B:** the first numbers were thresholds of 30–50 and +1.5 for 55 kn gusts.
  - With those numbers, European weather (gales peak at about 42 kn sustained) could never take a new hat within five minutes, so *The Last Straw* was unreachable.
  - The 55-kn gust band was raised to +4 and the thresholds lowered to 20–40. A hat lost within minutes stays rare (it needs squall gusts), and gales still allow 13+ minutes.
- **Tested:**
  - the same moment of loss at 1 s, 20 s, 137.3 s and 5,400 s steps (moored), and at 3 s, 77.7 s and one-hour steps (underway, the same logged place);
  - across a save and load mid-exposure;
  - nothing in 24 h at 24 kn;
  - safe while sleeping 8 h or working 4 h in a gale;
  - identical boat condition, position and funds with or without the hat.

## 6. Replacement purchase implementation

- **Where:** a hat row in the existing harbour grocery store (pontoon, provisions panel, boatyard). There is no clothing shop.
- **Rules:** `GameSession.buy_hat()` checks that the boat is moored in harbour, that the hat is lost (no second hat) and that funds are at least the price (€15, `price_eur`).
- **Effect:**
  - exactly one payment;
  - a new hat (serial + 1) handed over *carried*, so H puts it on;
  - records the purchase time, the count and the euros spent;
  - persists.
- **Without enough money**, the button is disabled with an explanation and nothing changes.
- **The provisions figures** in the same dialog are unchanged (tested: same price and missing days before and after a hat purchase).

## 7. Secret achievements implemented

All seven are implemented in the existing objectives data and system (`"secret": true`), with six new objective types.

| Achievement | Condition | Renown | Tone |
|---|---|---|---|
| Captain No-Hat | the first hat lost ("The sea has claimed its most important trophy.") | 10 | comic |
| Hat Trick | three hats lost | 15 | comic |
| Hold Onto Your Hat | arrive after a fully recorded voyage on which the hat was worn on deck in dangerous weather (hazard ≥ 2 at a hat check) and not lost | 30 | proud |
| The Hat Tax | €100 spent on replacements | 10 | comic |
| The Last Straw | a replacement lost within 5 game minutes of buying it | 15 | comic |
| A Captain of Distinction | ten voyages completed, original hat never lost | 40 | proud |
| The Sea Wears a Hat Now | a hat lost at sea with no land within 20 nm | 15 | comic |

- *The Sea Wears a Hat Now* needed no new geography. `HatStory.open_water_nm()` measures the distance to the nearest cell of the existing navigability raster (from the chart's coastline data, small islands included) that touches land. Cells off the chart count as land.
- **Hidden:** before a secret is found, the Captain's Log shows only "N secret achievements are still to discover". No title, condition or reward appears anywhere (tested by scanning every label).
- **After:** the name (hand-lettered), the description, the renown and the date found.

## 8. Renown rewards and persistence

- **Paid once:** awards go through the existing `ObjectiveProgress`, the same pay-once rule and the same save section.
- **Hat events** are evaluated inside the hat's own GameSession transactions (`_lose_hat`, `buy_hat`); the two voyage achievements when the voyage is logged.
- **Renown** counts towards lifetime and unpublished renown and is published as a travel update as before.
- **No farming** (tested): twelve hats lost and eleven bought paid only Captain No-Hat, Hat Trick and The Hat Tax, once each (35 renown, €70 when published). The hats cost €165.
- **Reload:** saving and loading never pay again (tested, and in the two-process restart check).
- **Notifications:** a found secret gets its own notification (title, description, renown) and a soft two-note chime (−9 dB, SFX bus). A lost hat plays a short "wah-wah" (−10 dB, SFX bus). Both are placeholder sounds, generated by `tools/generate_placeholder_audio.py`, and follow the SFX and Master volumes.

## 9. Typography choices

- **Barlow** stays the functional font: every number, the HUD, the chart, settings, dialogs and long text.
- **Patrick Hand** is the display font, used only through three theme variations in `tools/build_theme.gd`:
  - `DisplayTagline` (the title screen's tagline);
  - `DisplayHeader` (the Captain's Log title and section headings);
  - `DisplayName` (a found secret achievement's name);
  - plus the harbour signs on the pontoon, through their own `LabelSettings`.
- **Fallback:** Patrick Hand lacks "→", so each display font is a `FontVariation` with Barlow as fallback.
- **Rendered result:** it reads well at 100 % and 130 % interface scale (screenshots 133 and 134). The title screen fitted at 130 % only after the logo was made slightly smaller (screenshot 131). The font works in Godot, so no alternative was needed.
- **Licence:** Patrick Hand Regular 1.003 by Patrick Wagesreiter, SIL Open Font License 1.1. It was downloaded from the official Google Fonts repository (`google/fonts`, `ofl/patrickhand`). The licence is bundled as `assets/fonts/OFL-PatrickHand.txt`, `assets/fonts/README.md` lists both fonts, and the main menu credits name them. The font is unmodified and not renamed.

## 10. Artwork decisions

- **`Fliptober.png` and the mockup screenshots were not in the repository or the conversation.** The prototype follows the written art direction only and makes **no claim to match the owner's drawing**. Please supply the drawing for the next round.
- **How the art was made:**
  - generated by scripts (`tools/vessels/paint_illustrated_starling.py`, `tools/harbours/paint_copenhagen_landmark.py`) from the scenes' own shapes, so it lines up with the unchanged collision;
  - slightly uneven doubled ink lines, warm muted washes with soft variation, plank and grain texture, light hatching (light from the upper left), small lived-in details;
  - no photographic textures and no text in sprites.
- **Owner artwork untouched:** the four cat PNGs in `Visuals/Cat/` have the same MD5 as at I006 (tested).

## 11. Starling prototype

- **Profile:** a second profile, `data/vessels/starling_33_visuals_illustrated.tres`, with painted layers in `assets/vessels/starling_33/illustrated/`.
  - Deck: hull and toe rail, sand non-skid deck with teak side decks, planked cockpit and benches, coachroof with sea-glass portlights, grab rails and a herb box, coiled lines, winches, cleats, wheel, fenders on the harbour side, a bucket and a mug.
  - Cabin: planked sole with lamplight, a rag rug, galley stove, chart table with chart and lamp, settees with cushions, a planked table with teapot, mugs and a postcard, lockers with books, a plant, a V-berth with blanket and pillow.
  - Shadow, mast, rigging and sails stay procedural.
- **Unchanged layout:** vessel geometry, collision, walkable areas, stations, spawn points, sail markers, companion spots, the provisions display and the damage overlay. The layout snapshot is identical in both styles (tested on deck and in the cabin), and the damaged cabin was checked.
- **Settings → Artwork:** *Illustrated (prototype)* (default) or *Classic*, applied live and saved in `settings.cfg`. *Classic* shows the original profile, unchanged.
- **The Halcyon 40 and Petrel 36** were not redesigned; they support the hat only.
- **Comparison screenshots** at the same resolution (1600×900): `docs/screenshots/140_starling_deck_classic.png` / `141_starling_deck_illustrated.png`, and `142_starling_cabin_classic.png` / `143_starling_cabin_illustrated.png`.

## 12. Copenhagen harbour prototype

- **Generic harbour:** `HarbourDressing` draws an illustrated harbour on every deck's existing `Surroundings/Mooring`:
  - a planked pontoon with nails and grain;
  - mooring ropes with a sag;
  - cleats;
  - a cobbled quay with granite edging, bollards and lamps;
  - soft water patches and wave strokes;
  - the harbour name sign in hand lettering.
- **Copenhagen** adds its landmark: a row of Nyhavn-style coloured, gabled harbour houses on the quay (`assets/harbours/copenhagen/nyhavn.png`).
- **Unchanged gameplay:** the top-down view, mooring state, navigation, collision, walkable areas, vessel placement, the companion and the harbour services. The dressing has no collision; the grocery store and the boatyard open by walking up and pressing E (tested).
- **Comparison:** `147_copenhagen_harbour_classic.png` / `145_copenhagen_harbour_illustrated.png`. Generic: `148_kiel_generic_harbour.png`; the other boats: `149_harbour_halcyon_40.png` and `149_harbour_petrel_36.png`.

## 13. Landmark and facilities architecture

- **Landmarks (optional):**
  - `HarbourArt` at `data/harbours/<port_id>.tres` lists `HarbourLandmark`s (image, offset from the middle of the pontoon's landward edge, width).
  - At most three per harbour are drawn (more are ignored with a warning); one without an image is skipped.
  - A harbour without a file shows the generic harbour, so none of the 163 harbours needs art. Nothing about Copenhagen is hard-coded in the scene.
- **Facilities:**
  - signs only for the services that exist and are enabled: **Groceries** (the grocery station) and **Boatyard · Repairs** (the boatyard, with its free repair);
  - no fuel or other future services;
  - the existing sign labels are reused (their text and font change), so the readable menus are unchanged;
  - no harbour-specific availability.

## 14. Branding changes

- **Name and identity:**
  - `project.godot`: `config/name` "Little Captain's Hat" (window title); description noting the Next Harbor history; icon `little_captains_hat_icon.svg`; boot splash `little_captains_hat_logo_480.png`.
  - New logo, symbol and icon: a hand-drawn captain's hat above a wave; the wordmark is Patrick Hand converted to outlines (`tools/make_branding_svgs.py`, PNGs from `tools/export_branding.gd`).
- **Title screen:** the new logo, the tagline *Small boat. Wide world. Hold onto your hat.*, "Version 0.100a" (with the commit in development builds) and font credits.
- **Docs:** README, ARCHITECTURE and the developer guides use the new name and explain the former one. The iteration reports up to I006 are left as historical documents.
- **Kept on purpose:** the old `next_harbor_*` branding files, the theme file name `next_harbor_theme.tres` and the save format id `next_harbor_save` (so old saves stay valid).

## 15. Save compatibility strategy

- **Fixed folder:** `application/config/use_custom_user_dir` with `custom_user_dir_name = "Little Captains Hat"` gives the game its own folder (Windows `%APPDATA%\Little Captains Hat\`).
  - A future rename cannot move the saves.
  - The new project can never write to the old Next Harbor folder (`%APPDATA%\Godot\app_userdata\Next Harbor\`), which also protects the original development installation's saves.
- **Import, copy only** (`LegacySaves`, `SaveManager.import_file`):
  - When the old folder has valid saves, the main menu offers **Import Next Harbor saves…**. It asks first.
  - Each old save goes into the same slot number if it is free, otherwise into the next free slot, otherwise it is skipped and reported.
  - Nothing is ever overwritten, a save already imported (identical bytes) is not copied again, and the old files are only read.
  - Copies are written to a temporary file, verified and then moved into place. Loading one upgrades it in memory (v9 → v10).
- **By hand:** copy `slot_N.json` from the old folder to the new one (documented in the README).
- **Settings** are not imported.
- **Tested** with I006 (v9) fixtures in a scratch "Next Harbor" folder: conflicts, originals byte-identical, exact copies, loading, re-import, all slots full, and the main-menu flow. The owner's real Windows folder was not assumed to exist.

## 16. Game-version decision and justification

- **Previous version:** `0.1.0` (`project.godot`, I006), not in the owner's convention.
- **This release: 0.100a**, the planned first version of the convention. All Visual Identity V01 deliverables were implemented and verified (see §18–§20), so the full release is reported as delivered.
- **One place:** `GameVersion` (`src/app/game_version.gd`) holds `DISPLAY` "0.100a" and the numbers-only `MACHINE` "0.100.1" (letter a = 1, for tools such as a Windows file version). A test keeps `project.godot`'s `config/version` equal to it.
- **Separate:** the save format version stays independent (9 → 10 only because the hat added a section).
- **Commit id:** read from `build_info.json` (written by `tools/write_build_info.py` before an export; ignored by Git) or from the checkout's `.git` files. No git process runs at runtime. To show it in an exported build, add `build_info.json` to the export's non-resource include filter.
- **Version tag:** `v0.100a`, created on the final commit (status in §25).

## 17. Diagnostic logging status

**Implemented:** the `SessionLog` autoload (`src/diagnostics/session_log.gd`).

- **Files:** one JSON Lines file per run in `user://diagnostics/` (Windows `%APPDATA%\Little Captains Hat\diagnostics\`).
- **Finding it:** Settings → *Diagnostic logs…* opens the folder.
- **Every line:** UTC time, event, and game time during a game.
- **Events:**
  - `session_start` (version, commit, save format, engine, OS, renderer) and `session_end`;
  - `screen`;
  - `game_started` / `game_loaded` / `game_ended`;
  - `save`, `load` (with result) and `import_save`;
  - `hat`, `hat_warning`, `hat_lost`, `hat_bought`;
  - `achievement_unlocked`, `renown_awarded`, `travel_update`;
  - `voyage_started`, `voyage_logged`, `rescued`, `vessel_changed`, `funds`;
  - `error`: engine and script errors, through Godot 4.7's `Logger`.
- **Bounds and safety:**
  - at most 5,000 lines or 1 MB per file, then a `log_truncated` line;
  - only the newest 10 files are kept;
  - every line is flushed at once (the two-process restart check reads the first process's log);
  - no personal data;
  - `-- --no-session-log` turns it off;
  - it only reads the game (tested: the same hat scenario gives the same result with and without it).

## 18. Headless test results

Final full headless run on the final commit's content: **2,552 checks, 2,552 passed, 0 failed, exit code 0**. The I006 baseline was 2,162. The run before was 2,550; the two extra checks are the link checks of this report and the Windows checklist. After this run only the numbers in this report were edited.

New suites:

| Suite | Checks |
|---|---|
| `test_hat` | 182 |
| `test_secret_achievements` | 56 |
| `test_branding` | 63 |
| `test_visual_prototype` | 56 |
| `test_diagnostics` | 24 |

Existing suites that gained checks:

- `test_vessels` (334): automatic reachability of the three new hat stations.
- `test_dev_guides`: the new guide and links.

Every existing suite passes: sailing, routing, weather, damage, rescue, provisions, grocery, remote work, companions, Captain's Log, objectives, renown, publishing, harbours, save manager and migration, voyage persistence, and the gameplay flow.

Test changes, none of which removes a valid assertion:

- `test_objectives`: the "about 10–15 objectives" count now counts the regular (non-secret) objectives. The secret ones have their own suite.
- `test_vessels`: the I004 sprite-swap check starts from the Starling's classic profile explicitly, because the illustrated prototype is now the default.
- `test_gameplay_flow`: the "loading restores the session" comparison treats the hat's last check time as time-derived, like food and water.
- `test_dev_guides`: lists the new guide.

## 19. Rendered test results

Full rendered run (Xvfb 1920×1080, OpenGL 3, Mesa llvmpipe, `--screenshots`): **2,558 checks, 2,558 passed, 0 failed, exit code 0**, 150 screenshots. It has more checks than the headless run because some checks run only with a display.

## 20. Restart-test results

Two separate processes (`restart_check.tscn`, `--phase=write` then `--phase=read`): **write exit 0; read 27 checks, 27 passed, exit 0 (PASS)**.

New in the restart check:

- the Artwork setting;
- the captain's hat after a loss, a purchase and putting it on (hat number 2, worn, €15 spent);
- the secret Captain No-Hat paid once;
- the first process's diagnostic log flushed to disk (start, hat loss, save).

## 21. Screenshot review

All screenshots are in `docs/screenshots/`, at 1600×900, with numbers 120–150. I looked at each new one:

- **The hat:**
  - on the hook in all three cabins (120_*);
  - worn (121_*);
  - carried on deck (122);
  - blowing away with the warning, loss and achievement notifications (123);
  - the grocery hat row (124).
- **The Captain's Log:**
  - secrets hidden (125);
  - after the first secret (126; the found entry is further down the list, below the screenshot);
  - Notable moments (127).
- **Branding and typography:**
  - title screen (130, before: 01);
  - title screen at 130 % (131);
  - import dialog (132);
  - the log's display headings at 100 % and 130 % (133, 134; before: 108).
- **Starling:** before and after on deck and in the cabin (140–143); the damaged illustrated cabin (144).
- **Harbour:**
  - Copenhagen illustrated and classic (145, 147);
  - the boatyard preview with the illustrated Starling (146);
  - Kiel (148);
  - the Halcyon and Petrel harbours (149);
  - the Artwork setting (150).
- **Observations:**
  - the bottom-left controls line overlaps the Nyhavn houses (legible, but busier);
  - the procedural worn hat is small on the token: readable, but the owner's drawing will help;
  - the illustrated deck's large sand areas are still plain;
  - notifications stack over the top of the Captain's Log, as before.

## 22. Known limitations

- **Not checked:** Windows behaviour, real GPUs and frame rates.
- **Hat art:** procedural stand-ins until the owner's drawings arrive.
- **Starling art:** generated, not drawn by hand, and not compared with *Fliptober.png* (unavailable).
- **Timing:** at 1× a game minute is one real second. After the warning in squall gusts there are only a few seconds to react (the warning drops time to 1×).
- **Harbour:** the dressing is drawn the same way on every boat. The quay and landmark are only partly visible at the deck camera's current framing (the camera was not changed).
- **Where the hat counts as on deck:** the chart opened from a weather warning on deck still counts as on deck (the session's area); opening it from the chart table counts as below.
- **Not imported:** old Next Harbor settings.
- **Tags:** neither tag could be pushed from this session (§2, §25).

## 23. Deferred sea-trial findings

Not addressed in V01, as instructed; they are for the stabilization build:

- the F9 freeze (H was chosen for the hat; F9 handling is unchanged);
- cat petting at some berth positions (the hat was tested not to change any petting focus in any cabin, so it is not worse);
- Halcyon cabin proportions (no geometry changed);
- grocery price/days rounding (no economy change; the hat row has its own price and leaves the provisions figures as they were);
- grocery access differences between vessels;
- the upper-left HUD panel changing width;
- pause presentation moving nearby UI.

The chart sidebar, boatyard panel, provisions graphics, Captain's Log, publishing and routing are unchanged (their suites pass).

## 24. Files changed

140 files since `ea002ec` (6,273 insertions, 237 deletions, before the Checkpoint E commit), plus the Checkpoint E files. The main ones:

- **Hat:**
  - code: `src/core/hat_state.gd`, `src/hat/*`, `data/hat/*`, `assets/hat/README.md`;
  - changes in `game_session.gd`, `simulation.gd`, `session_state.gd`, `save_manager.gd`, `boat_area.gd`, `player.gd`, `app.gd`, `grocery_menu.gd`, `hud.tscn`, `project.godot`;
  - the three cabin scenes and `tools/vessels/build_multihull_scenes.py`.
- **Achievements:** `objective_catalog.gd`, `objectives.json`, `captains_log_menu.gd`, two placeholder WAVs, `tools/generate_placeholder_audio.py`.
- **Branding and saves:**
  - `src/app/game_version.gd`, `src/persistence/legacy_saves.gd`, `main_menu.*`;
  - `tools/make_branding_svgs.py`, `tools/export_branding.gd`, `tools/build_theme.gd`, `tools/write_build_info.py`;
  - fonts, branding SVG/PNGs, theme.
- **Visual prototype:**
  - `src/harbour/*`, `data/harbours/copenhagen.tres`, `assets/harbours/copenhagen/nyhavn.png`;
  - `assets/vessels/starling_33/illustrated/*`, `data/vessels/starling_33*.tres`;
  - `vessel_definition.gd`, `settings_manager.gd`, `settings_menu.gd`, `boatyard_menu.gd`, `provision_display.gd`;
  - two painter scripts.
- **Diagnostics:** `src/diagnostics/session_log.gd`.
- **Tests:**
  - five new suites, `test_runner.gd`, `restart_check.gd`;
  - small updates to `test_objectives`, `test_vessels`, `test_gameplay_flow`, `test_dev_guides`.
- **Docs:**
  - this report, the Windows checklist, `README.md`, `docs/technical/ARCHITECTURE.md`;
  - `DEV_GUIDES/CAPTAINS_HAT.md` (new), `AUDIO.md`, `VESSEL_ART.md`, `README.md`, `WEATHER.md`, `MODDING_FUTURE.md`, `docs/artwork/ART_PIPELINE.md`;
  - `assets/fonts/README.md`, screenshots 120–150.

## 25. Final Git commit and push status

- **Branch:** `claude/friendly-fermat-dey23f`.
- **Pushed:** checkpoints A–D (§3).
- **Checkpoint E** is the final commit, the branch head. A commit cannot contain its own hash; it is given in the delivery message and `git log`.
- **Final re-run:** the headless run in §18 (2,552 passed, 0 failed) was made on this commit's content.
- **Tags:** `i006-pre-visual-identity` (on `ea002ec`) and `v0.100a` (on the final commit) exist locally. The session's Git proxy refused tag pushes. Run `git push origin i006-pre-visual-identity v0.100a` from a normal checkout, or create them on GitHub.
- **No pull request** was created, and no anchoring, worldwide chart or other future iteration was started.

## 26. Remaining Windows acceptance items

All 20 sections of [WINDOWS_ACCEPTANCE_VISUAL_V01.md](WINDOWS_ACCEPTANCE_VISUAL_V01.md) are open. Most important for the owner:

- importing the real Next Harbor saves from `%APPDATA%\Godot\app_userdata\Next Harbor\saves\`;
- the hat warning and loss timing at 1× in a gale;
- the readability of Patrick Hand on a Windows display;
- **the verdict on the Starling and Copenhagen art direction**, which decides whether the Halcyon and Petrel follow.
