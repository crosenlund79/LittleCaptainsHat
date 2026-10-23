# Iteration 003b: Stabilization, Sail Polish & Life Aboard (Report)

**Engine:** Godot **4.7.2 stable** (official Linux build), GDScript, Compatibility renderer.

**Test environment:** a Linux container, running Godot headless, plus Xvfb with Mesa
llvmpipe (software OpenGL) for rendered runs. There is no sound device.

**No Windows machine was available**, nothing was played by a human, and no audio
was heard. "Verified" below means an automated check or a reviewed screenshot of an
automated run. Statements without such evidence are marked as assumptions.

## 1. Implemented changes

| # | Work package | Result |
|---|---|---|
| 1 | Chart UI stability | The side panel keeps a fixed size. Changing labels reserve fixed lines (full text in a tooltip), sections never appear or disappear, and buttons stay put. A **Sleep** button was added. |
| 2 | Spinnaker positioning | The spinnaker flies further ahead of the bow (leading edge at x≈686, bow at 500), from a pole at the mast, with halyard, sheet and guy. It is slightly larger than before, not smaller. |
| 3 | Sail animation | Mainsail, jib and spinnaker "breathe" gently (fullness, a fraction of a degree, a small leech ripple). Furled sails are still. The motion is cosmetic only. |
| 4 | Course-change reassessment | Verified, then improved: clearly good or poor conditions on the new heading now decide at once, within the minimum times. |
| 5 | Helm check | Underway, the helm prompt is **Check sail configuration**. It requests a fresh assessment through the controller and reports the result. It cannot force a mode or reset timers. |
| 6 | Sleeping | A 1–12 h duration selector with arrows, reachable from the berth and the chart. The player always wakes in the cabin beside the V-berth. |
| 7 | Ship's companion | Cat or dog, chosen on New Game (cat preselected). It rests in the cabin, changes spot every 2–5 game hours, and responds to petting with a sound and a small reaction. It is saved. |

## 2. Architectural modifications

- **`PropulsionController.evaluate(…, reset_history, reassess)`** replaces the single
  `force_reset` flag, separating the two concerns:
  - `reset_history`: restart the average after a turn;
  - `reassess`: let the current conditions decide at once.
- **`Simulation`:**
  - `evaluate_propulsion(reset_history, reassess)`;
  - new `reassess_propulsion()` for the helm;
  - a change of course uses both flags.
- **`GameSession`:**
  - `start_new_session(companion_kind)`;
  - `get_companion()`;
  - the `companion_moved` signal;
  - `apply_simulation_step()` advances the companion's schedule on the same game
    clock.
- **New data class `CompanionState`** (`src/companion/`), held by `SessionState`. It
  is plain data with a deterministic schedule; `GameSession` remains its only writer.
- **New presentation node `ShipCompanion`** in the cabin scene. It only reads
  state, has no collision, and petting goes through the existing `Interactable`
  framework (id `pet`). No new autoload or manager was added.
- **`BoatArea`:**
  - `place_player_at_spawn()`;
  - the helm prompt depends on the voyage;
  - routing for `pet`.
- **`App`:**
  - `open_new_game_menu()`, `start_new_game(kind)`;
  - `open_sleep_menu()` works from the chart too;
  - `_wake_in_berth()`;
  - `describe_reassessment()`.
- **`WorldMap`:** `LINE_BUDGET` and `_reserve_text_space()` handle layout
  stability; `sleep_requested` is a new signal.
- **`SailRig`:**
  - geometry is computed in `get_shape(time)`, which drawing and tests share;
  - real-time animation (`animation_time`);
  - a deck-view shift while the spinnaker flies.
- **Save format version 4** adds the companion.

## 3. Files created and modified

**New:**
- `src/companion/companion_state.gd`, `src/companion/ship_companion.gd`
- `src/ui/new_game_menu.gd`, `src/ui/new_game_menu.tscn`
- `assets/audio/placeholder/companion_purr.wav`, `companion_dog_pant.wav` (+ `.import`)
- `tests/suites/test_reassessment.gd`, `tests/suites/test_life_aboard.gd`
- `ITERATION_003B_REPORT.md`, screenshots `docs/screenshots/25_…` to `32_…`

**Modified:**
- App and scenes:
  - `src/app/app.gd`, `app.tscn` (new-game menu, sleep flow, helm messages);
  - `src/boat/boat_area.gd`, `interior.tscn` (`v_berth` marker, Companion node),
    `sail_rig.gd`.
- Core and persistence:
  - `src/core/game_session.gd`, `session_state.gd`, `simulation.gd`;
  - `src/persistence/save_manager.gd` (v4).
- Sailing and chart:
  - `src/sailing/propulsion_controller.gd`;
  - `src/navigation/world_map.gd`, `world_map.tscn` (panel stability, Sleep button,
    toolbar width).
- UI: `src/ui/sleep_menu.gd`, `sleep_menu.tscn`.
- Tests:
  - `tests/test_runner.gd`;
  - `tests/suites/test_gameplay_flow.gd` (New Game dialog, sleep selector);
  - `tests/restart_check.gd` (companion).
- Tools and docs:
  - `tools/generate_placeholder_audio.py`;
  - `README.md`, `ARCHITECTURE.md`, `assets/audio/placeholder/README.md`;
  - refreshed screenshots.

## 4. Chart UI stabilization approach

**Cause.**
- The panel content sits in a `ScrollContainer` with horizontal scrolling
  disabled, so the content's minimum width became the panel's width.
- Wrapped labels changed their line count as values changed, which moved
  everything below them.
- The voyage box and the **Set sail** button were shown or hidden.

**Fix**, using containers and constraints rather than coordinates:
- **Reserved lines.** Each changing label reserves a fixed number of lines
  (`LINE_BUDGET`: status 2, position 1, voyage 2, port title 1 + details 4, course
  2 + status 3, weather 4). Labels use smart word wrap, `max_lines_visible`, an
  ellipsis and a minimum height of the reserved lines. The full text is the label's
  tooltip, so nothing becomes inaccessible.
- **Buttons** clip their text (Plot course to …, Apply/Change course, Set sail).
- **No disappearing sections.** The voyage box is always shown ("No voyage in
  progress." in port), and **Set sail** stays visible but is disabled at sea.
- **Clock.** It drops " UTC" to fit beside the time controls (full text in the
  tooltip).
- **Toolbar.** Its cursor readout was narrowed (300 px, clipped) so the toolbar no
  longer runs under the panel at 130 % scale. That overlap was a leftover from
  Iteration 003, visible in the 130 % screenshot.

**Verified by test.** The test records the rectangles of the panel, nine buttons
and the weather label, and compares them across:
- 12 steps at 20× with the wind changing strength and direction;
- forced sail and engine states;
- five destinations;
- a new draft course with its weather, and discarding it;
- 80 % and 130 % interface scale (the panel also fits on screen).

Nothing moved by more than 0.5 px.

## 5. Spinnaker geometry adjustments

| | Iteration 003 | Iteration 003b |
|---|---|---|
| Tack | free point beside the foredeck | end of a **270-unit pole** from the mast, 22° (reach) to 58° (run) to windward |
| Clew | (300–340, leeward 185–225) | (470–400, leeward 215–205): further forward |
| Leading-edge depth | 520 | **560** |
| Leading edge at 150° | x≈620 | **x≈686** (bow at 500) |
| Size at 150° | ≈ 352 wide × 520 deep | **397 wide × 578 deep** (incl. breathing) |
| Rigging drawn | pole, sheet, guy | pole, **halyard (mast → head)**, sheet, guy, corner fittings |

- Deployment rules, wind-relative orientation, port/starboard placement, speed and
  the ×1.12 bonus are unchanged.
- While the spinnaker is set, the deck camera eases 110 units forward so the whole
  sail is on screen; the stern and helm stay visible.

## 6. Sail animation implementation

- **Time source.** `SailRig.animation_time` advances with real (frame) time.
- **Geometry.** `get_shape(t)` builds every sail from the eased pose plus small
  sinusoids at different, slow frequencies:

  | Sail | Angle | Fullness | Other |
  |---|---|---|---|
  | Mainsail | ±0.8° at 0.13 Hz | ±6 % at 0.21 Hz | leech ripple ≈ 1 px |
  | Jib | ±1.2° | ±8 % | leech ripple 2 px |
  | Spinnaker | swing ±2.5° | depth ±7 % | clew ±6 px |

- **Scaling.** Amplitudes are multiplied by how far the sail is set, so furled sails
  are still and motion fades in when sails are set.
- **Measured over 10 s:**
  - mainsail clew up to 5.6 px;
  - jib clew up to 3.8 px;
  - spinnaker head up to 39 px;
  - largest per-frame step 0.79 px (no jitter).

  The sails stay on the leeward side throughout.
- **No effect on the simulation.** The rig writes nothing; 30 animated frames leave
  `PropulsionState` identical (tested). Animation phases are not saved.

## 7. Propulsion reevaluation behavior

**Verified first:**
- Iteration 003 already re-evaluated on a change of course at the moment it was
  applied, from the unchanged vessel position, with the new heading and the local
  wind.
- It also restarted the rolling average from the new heading.

That was kept.

**What was missing**, and how it was handled:
- **Turning from a beat into a good breeze while motoring.** The engine still
  needed the 20-minute "favourable" confirmation, because a course change reset
  that timer. Now a reassessment stops the engine at once when the current
  potential is above 6.0 kn and the engine has run at least 30 minutes.
- **Turning into poor wind under sail.** This already started the engine at once
  when the average restarted below 3.5 kn and the boat had sailed for 15 minutes.
  This is now explicit: the current potential below 3.5 kn decides. Head to wind
  gives reason "becalmed or head to wind".
- **Stall timer.** A turn no longer resets it while the new heading is still
  becalmed, so a near-stall cannot be dodged by turning.
- **Anti-cycling** is preserved by the unchanged minimum times: 900 s under sail and
  1800 s motoring.

**Test, Copenhagen → Kiel in a fresh southerly (motoring):**
- The change of course to Gothenburg set the sails immediately at the same
  position and time.
- The new heading is used and the average restarts.
- The reported speed follows, and the boat did not switch back within the next
  hour.

**Regressions.** All earlier suites still pass, including step independence at
1×/5×/20×/sleep, weather warnings, ETA, rerouting and save/load.

## 8. Helm interaction behavior

- **Prompt.** In port it is **Take the helm** (departure, as before). Underway it is
  **Check sail configuration**.
- **Action.** `Simulation.reassess_propulsion()` evaluates the current heading and
  local wind through `PropulsionController` with `reassess = true`, and never with
  `reset_history`. It therefore resets no timer, and the minimum times apply.
- **Messages:**
  - "Sailing conditions favourable (8.2 kn possible under sail in 15 kn of wind).
    Sails set with the spinnaker, engine stopped."
  - "Insufficient sailing performance (…). Sails furled, engine started." /
    "…Continuing under engine."
  - "Becalmed or head to wind (…)."
  - "Sails are drawing well (…). No change needed."
  - "Light wind (…). The sails stay up a little longer; the engine starts if it does
    not improve."
  - "The wind is filling in (…). The engine runs a little longer before the sails go
    up."
- **Tested safeguards:**
  - five checks in good wind never start the engine;
  - five checks in light air never stop it, and timers keep running;
  - ten checks within the minimum sailing time cause **0** switches;
  - position and course never change;
  - in port it does nothing.
- **Presentation follows**, tested through the real deck scene: HUD ("Under sail"),
  sails set, engine sound stopped.

## 9. Sleep menu and V-berth wake-up implementation

**Dialog** (`SleepMenu`):
- **<** / **>** buttons (also Left/Right) change the duration from 1 to 12 hours,
  default 6. The buttons disable at the limits.
- It shows the duration, the wake-up time ("Wake at about …, in the V-berth"), and
  **Sleep N hours** / **Cancel**.

**Entry points:**
- the berth in the cabin, as before;
- the new **Sleep** button on the chart. It is refused, with a message, while
  course edits are unapplied, so drafts are never silently lost.

**Same simulation everywhere.**
- `App.sleep_for()` calls `Simulation.sleep(hours)`, as before.
- Tested: a 2 h sleep from the chart and a direct `Simulation.sleep(2)` from the
  same state give identical progress (30.978 nm) and time.

**Wake-up.**
- Afterwards, `_wake_in_berth()` enters the cabin at the new `v_berth` marker
  (282, 0).
- If the player is already in the cabin, they are moved without reloading.
  Otherwise the cabin is shown, which closes the chart or leaves the deck.
- Tested after:
  - sleeping in port (from the cabin);
  - from the chart underway;
  - a weather-warning interruption (sleep started on deck: woken after 6 h 43 min
    of 12 h, warning and reason shown, progress exactly matching the time slept);
  - an arrival interruption.

  Each time, the spot is free of furniture collision and the player can walk from
  it into the cabin.

## 10. Companion implementation

- **Choice.** New Game opens a dialog with a short question, **Cat**/**Dog** toggle
  buttons (cat preselected), a drawn preview, a one-line description, and
  **Start**/**Cancel**.
- **State.** `CompanionState` holds:
  - `kind`: `cat` or `dog`, kept generic so a future crew member can be another
    kind;
  - `spot`;
  - `next_move_time`;
  - `moves`.

  The spots are fixed per kind:

  | Kind | Spots |
  |---|---|
  | Cat | settee, nook beside the chart table, V-berth blanket |
  | Dog | cabin floor by the locker, foot of the steps, beside the starboard settee |

- **Schedule.**
  - Every 2–5 game hours (whole minutes) the companion moves instantly to another
    spot.
  - The spot and interval are chosen deterministically from the kind and a move
    counter.
  - Moves are driven by the game clock in `apply_simulation_step`, so 1×, 20× and
    sleep behave the same. Tested: one 48 h step equals 2,880 one-minute steps;
    17 moves in 48 h, never sooner than 2 h apart; all spots used.
- **Presentation.**
  - `ShipCompanion` draws a flat top-down animal in the fixture style:
    - the cat: grey, curled up, striped, ears, wrapped tail;
    - the dog: brown, stretched out, floppy ears, tail.
  - It breathes slowly and has no collision, so it never blocks movement.
  - For every spot, the chart table, berth, wake-up spot and companionway remain the
    focused interaction from where the player stands (tested for all six spots).
- **Petting.**
  - **E** near it shows "Pet cat" / "Pet dog".
  - The cat purrs: a soft, low pulsing noise of 1.6 s, with a small settle and two
    hearts.
  - The dog pants softly and sighs, and wags its tail.
  - Sounds go through `AudioManager.play_sfx` on the SFX bus. Tested: the sound is
    playing on SFX, and 0 % SFX mutes the bus. The sounds are synthetic
    placeholders and were not listened to.
- **No duplicates.** It is part of the cabin scene: one in the cabin, none on deck,
  and still one after the deck, the chart, sleeping and loading (tested).

## 11. Save migration details

- **Version 4** adds `session.companion = {kind, spot, next_move_time, moves}`.
  - Validation rejects unknown kinds, unknown spots and an invalid schedule.
  - The schedule is stored in whole minutes, so JSON round trips are exact.
- **`_migrate_3_to_4`** gives older saves the documented default: a **cat** resting
  in its first spot (the settee), with its schedule starting at the saved game time.
  - Migration chains 1 → 2 → 3 → 4.
  - Iteration 001 and 002 migration tests still pass, and an Iteration 003 (v3)
    save was tested.
- **No new propulsion fields** were needed. The reassessment rules use the existing
  controller state. Sail animation phases are not saved.
- **Restart check.** The two-process restart check now writes a game with a **dog**
  and verifies that the companion is restored, along with voyage, propulsion,
  clock, area, player and settings.

## 12. Tests executed

| # | What | Command |
|---|---|---|
| T1 | Import / compile | `godot --headless --path . --import` |
| T2 | Headless suite | `godot --headless --path . res://tests/test_runner.tscn` |
| T3 | Rendered suite + screenshots | `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tests/test_runner.tscn -- --screenshots=DIR` |
| T4 | Restart persistence (2 processes) | `godot --headless --path . res://tests/restart_check.tscn -- --phase=write`, then `--phase=read` |

New suites:
- **`test_reassessment`** (34 checks): controller reassessment rules, hysteresis,
  minimum times, stall timer on turns, course change at sea, helm check, helm
  safeguards and messages.
- **`test_life_aboard`** (112 checks, real `App`): New Game choice, companion spots,
  focus, schedule and petting (cat and dog, SFX bus, mute), sleep dialog limits,
  sleep from the cabin and the chart, interruptions, V-berth wake-up and
  walkability, chart panel geometry stability (20×, wind, propulsion, destinations,
  drafts, 80 %/130 % scale), helm prompt and result on deck, sail motion and
  spinnaker geometry, companion persistence, scene transitions and v3 migration.

Updated:
- `test_gameplay_flow`: New Game now goes through the companion dialog; the berth
  sleep uses the arrows (4 h).
- `restart_check`: covers the companion.

## 13. Actual test results

- **T1:** no errors.
- **T2: 761 checks passed, 0 failed**, exit code 0, no leaks at exit. Checks per
  suite:

  | Suite | Checks |
  |---|---|
  | data model | 29 |
  | routing | 99 |
  | simulation | 82 |
  | wind | 41 |
  | sailing | 55 |
  | reassessment | 34 |
  | save manager | 28 |
  | voyage persistence | 36 |
  | settings/audio | 37 |
  | sailing presentation | 34 |
  | life aboard | 112 |
  | gameplay flow | 174 |

- **T3: 765 checks passed, 0 failed**, exit code 0.
- **T4:** both phases passed (15 checks, including the companion), exit code 0.

During development the new tests found and I fixed:
- the companion schedule's float precision in JSON;
- clicking the sleep dialog before its first layout (a test issue);
- the chart toolbar overlapping the panel at 130 %;
- a truncated chart clock;
- "V-berth" breaking at its hyphen in the sleep dialog.

## 14. Visual verification

I reviewed the screenshots from the final rendered run:
- `25_new_game_companion`: the dialog with the dog preview;
- `26_pet_cat`: the cat on the settee with hearts and the "Pet cat" prompt;
- `26_pet_dog`, `32_cabin_dog`: the dog on the cabin floor;
- `27_sleep_dialog`: arrows, duration and wake time;
- `28_chart_panel_underway`, `28b_chart_panel_scale_130`: the stable panel with
  Sleep beside Set sail, and the toolbar no longer under the panel at 130 %;
- `29_woke_at_v_berth`: the player beside the V-berth after arrival;
- `30_deck_sailing_motion`, `31_deck_spinnaker_refined`: the spinnaker ahead of
  the bow on pole and halyard, the whole sail in view, and the helm prompt.

**Assumption:** the motion can only be judged from screenshots and measured
geometry here. How it *feels* in motion still needs the owner's playtest.

## 15. Known limitations

- **Untested conditions:** not run on Windows, no human play, and no audio heard.
  The purr and panting sounds are synthetic placeholders and may sound artificial.
- **Abbreviated text.** On the chart, text beyond a label's reserved lines ends in
  "…" with the full text in a tooltip. Tooltips need hovering; there is no other
  way to read the rest. Typical texts fit, and the port descriptions take at most
  3 of their 4 lines.
- **Panel needs scrolling.** At 1080p the bottom of the chart panel (weather list,
  help, Back) is reached by scrolling. That was already the case and is unchanged.
- **Spinnaker and HUD.** On deep downwind angles the spinnaker's upper part can
  pass under the top-right HUD panel. The eased mainsail can reach the top edge of
  the deck view.
- **Wait after a recent switch.** A course change shortly after a mode switch still
  waits for the minimum time (by design, against cycling), so the boat may sail
  slowly or motor for up to 15/30 minutes after such a change.
- **Companion.** It only rests and never walks. Spots change instantly, possibly in
  view. It does not react to sailing or weather.
- **Sleeping from the chart** is refused while course edits are unapplied (a
  message explains this) rather than asking to discard them.

## 16. Explicitly excluded features

These were not implemented, as agreed:
- **Boats and boatyards:** boat purchases, boatyards, multihulls, decorations.
- **Economy and supplies:** economy, jobs, provisions.
- **Pet care:** feeding, health, happiness and following, companion pathfinding or
  AI.
- **Crew:** human crew and crew tasks.
- **Manual sailing:** manual sail trimming or propulsion selection, tacking.
- **Wear and damage:** fuel, engine damage, boat damage, storm consequences.
- **Systems:** new navigation mechanics and new weather systems.

## 17. Future architectural concerns

- **Companions.** `CompanionState` is deliberately small. A human crew member with
  tasks would need its own state and probably a scheduler service, not more fields
  on this class. `ShipCompanion` would stay a presentation node.
- **Long text on the chart.** If later panels hold much more text (tasks,
  provisions), the chart side panel should become tabs or sections. Reserved
  lines plus tooltips suit short, frequently changing values, not documents.
- **Reassessment conditions.** If manual sail control arrives, add it to
  `PropulsionController` as one more input (an override honoured within the same
  minimum times), so HUD, rig and audio keep following only `PropulsionState`.
- **Deck view.** The camera shift for the spinnaker lives in `SailRig`. If the deck
  gets a real camera controller (zoom or follow), move the framing request there.
