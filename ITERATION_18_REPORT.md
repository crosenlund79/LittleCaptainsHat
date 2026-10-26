# Iteration 18 — The Joy of the Journey (0.105a)

Assignment: `ITERATION_18_ASSIGNMENT.md` (verbatim). Requirement tracker:
`ITERATION_18_REQUIREMENTS.md`. Windows checklist: `WINDOWS_ACCEPTANCE_18.md`.

**Windows acceptance is pending.** Everything below was verified on Linux
(Godot 4.7.2: headless test suites, rendered runs under Xvfb with software
OpenGL, benchmarks, a two-process restart test). Nothing here claims that
I018 passed the Captain's and Skipper's Windows trial.

Numbers are **measured** unless marked *estimate*.

## Starting point

### 1. Verified starting state

- Branch `claude/friendly-fermat-dey23f` at `3c5690a` (I017 final, "record
  the Checkpoint I push"), pushed, clean working tree; version 0.104a, save
  format 12. Recorded at the start of the timing log (Shipyard Efficiency).
- A full baseline regression was **not** re-run at the start (I017's own
  final regression of 3838 checks on that code is in `ITERATION_17_REPORT.md`);
  instead the I017 suites touching the defect area were run on the baseline
  before changing it (`test_world_chart_render`, `test_navigation_views`,
  `test_wind_overlay`, `test_cockpit_ui`: all passed), and the reported route
  defect was reproduced with a new test that fails on the 0.104a code (5).
- No Captain-owned art was modified. No force-push, reset or history rewrite;
  every checkpoint is a normal commit. The archived Next Harbor project was
  not touched.

### 2. Final version

**0.105a** (`GameVersion.DISPLAY`, `MACHINE` 0.105.1, `project.godot`
`application/config/version`): a feature milestone after 0.104a, per the
version policy.

### 3. Save format and migration

**Format 12, unchanged.** Everything new is an *optional* field with a safe
default, so 0.104a saves load as they are and nothing is rewritten:

| Where | New optional fields | Default when absent |
|---|---|---|
| fishing | `keep_min_rarity`, `keep_min_grade`, `passage_posture`, `sharks_released`, `junk_caught`; per kept fish `prev_best_kg` | keep everything; stop for every bite; 0 |
| vessel | `sail_trim` {auto, value} | left to the crew |
| planned route | `anchorages` (one flag per waypoint) | none |
| voyage | `holding_at`, `anchorages_done` | not waiting; none done |
| companion | `area` (cabin/deck), `deck_spot` | cabin |

Tested: `test_fishing2` ("a 0.104a save loads with keep-everything
defaults"), `test_sail_trim`, `test_anchorage` ("a 0.104a voyage loads with
no anchorages"), `test_companion_deck` (save/load on deck), the existing save
suites, and the two-process restart test (29).

### 4. Checkpoint commits

| Commit | Checkpoint |
|---|---|
| `799398f` | A: assignment, tracker, route stays visible while panning |
| `39ca3bc` | B/C: Fishing 2.0 reel-in dial, illustrated living fish, grades, keep preferences, sharks and junk |
| `4b453f9` | D/E: fishing at anchor, fast-time fishing choice, Sail Trim, fewer Long Passage stops |
| `beb0124` | F: anchorage waypoints |
| `d592d7b` | G: anchor ball, light, rode and buoy; companion follows on deck |
| `c10cb8d` | H: cabin light and shadow, navigation lights on the rail, wind preview in 1 h steps |
| `f8d68ed` | I (in progress): 0.105a, combined-journey and restart tests, screenshots, report draft, checklist, orders |
| (next) | I: final report with the regression results; then a last commit recording the push check (33) |

## The I017 carry-forward

### 5. World-route display defect: diagnosis and fix

**Symptom (I017 Windows test):** a long route disappeared or jumped when the
world chart was panned east or west.

**Cause (from the code):** the chart draws the world several times side by
side (wrapping), but a route was moved *as a whole* into the world copy
nearest the camera, chosen by the route's **first point** only
(`MapView._path_to_map`). Once the view was panned so that the start of the
route was nearer another copy than the part on screen, the whole route was
drawn one world-width away — off screen. The overlay was also not redrawn
for every camera move, so a stale position could stay after a wrap.

**Fix:** `MapView._path_copies(path)` returns the route in **every** world
copy that reaches into the view, and the route, its legs and the click
targets (`pick_route_leg`) use it; `_overlay_view_key` redraws the overlay
whenever the camera moves. Only drawing changed: the route data, waypoints,
distances and the saved voyage are untouched (checked by fingerprint).

### 6. Rendered route-wrap evidence

`test_route_wrap` (103 checks rendered, 87 headless): pans west and east in
15° steps, 2.2 turns of the globe each way, at whole-world and regional
zooms, with Middelfart → Papeete (the Captain's case, ~160° of longitude),
the same with several waypoints, Papeete → Auckland across the Date Line with
a waypoint on it, the committed course underway, and the daydream route on
the Dreamer's Map. At every step it works out by brute force where the route
falls on screen and checks that the map draws it there, (rendered) that the
route's colour really is on screen along it, that no segment jumps across
the map, and that nothing in the route or the saved state changed. Run against the 0.104a `map_view.gd` it fails 29
checks; with the fix it passes. Image:
`docs/screenshots/iteration18/33_route_before_after_pan_fix.png` (same pan,
0.104a left with no route, 0.105a right).

## Fishing 2.0

### 7. Design

The I013 tension bar is replaced by **ReelTiming** (`src/fishing/reel_timing.gd`)
and its dial (`src/ui/reel_dial.gd`):

- a needle sweeps the dial at one **constant speed** (200°/s, one turn in
  1.8 s; it never changes, in fast time either: real time);
- press **E**, **Space/Enter** or click the dial while the needle is inside
  the **green arc**; each good press is a check, and the arc then jumps to a
  new place well ahead of the needle;
- a gold **Perfect** zone in the middle of the arc (30 % of the arc, at
  least 10°);
- **forgiving misses**: three "grips"; a press outside the arc costs one and
  the fish escapes only when all three are gone; not pressing costs nothing;
- a press is counted at most every 0.15 s (held or bouncing keys are one
  press); after 60 s without a press the fish slips the hook; **Let it go /
  Esc** releases it.

A bite shows a "Fish on! Reel in" badge with an **R** key; R opens the reel
from anywhere aboard (and the action wheel offers it). The rod face
(`FishingMenu`) has three faces: rod (lure, line, preferences, cool box),
reel (portrait, dial, feedback) and result.

### 8. Rarity and timing balance

| Rarity (data's own names) | Checks | Arc |
|---|---|---|
| common | 1 | 72° |
| uncommon | 2 | 60° |
| rare | 3 | 50° |
| very rare | 4 | 42° |
| junk | 1 | 84° |

Fairness, simulated in `test_fishing2` over many catches, a careful captain
(presses within 0.6 of half the arc from its middle) and a sloppy one (1.5):

| Landed | common | uncommon | rare | very rare |
|---|---|---|---|---|
| careful | 100 % | 100 % | 100 % | 100 % |
| sloppy | 98 % | 89.5 % | 79 % | 64.5 % |

A careful captain lands a very rare fish (four checks) in 4.7 s; each check
needs at most one turn of the dial (1.8 s).

### 9. Perfect-hit behaviour

A Perfect counts as a check and **nudges the landed weight** a little toward
the top of the species' range: each Perfect moves it 7 % of the remaining
way (`FishingCatalog.PERFECT_NUDGE`), so four Perfects add at most ~25 % of
the remaining range and never pass the species' maximum. Species and rarity
never change. The result card says "N Perfect hits: a little heavier for
your care."

### 10. Fish artwork coverage by species

All **16 species** in `data/fishing/fishing.json` and the **3 junk items**
have their own illustration: herring, mackerel, flatfish, cod, perch,
garfish, gilthead bream, sea trout, sea bass, bonito, mahi-mahi, skipjack,
snapper, yellowfin, blue shark, blacktip reef shark; old boot, tangled rope,
rusty tin. Each fish has a body, a tail (separate, for the flick), an eyelid
and a thumbnail. `test_fishing2` checks every species has its layers and
that silhouettes differ (the closest pair, bonito and skipjack, measured at
90 % overlap; the snapper was redrawn after it was too close to the perch).
Sheet: `docs/screenshots/iteration18/fish_art_sheet_all_species.png`; single
fish 05–10.

### 11. Fish animation method

`FishPortrait` (`src/fishing/fish_portrait.gd`): three textures on one canvas
(body, tail, lid). It **blinks** (0.13 s, at irregular intervals of 2.4–6 s,
each portrait with its own random timing) and **flicks its tail** (a damped
13° wiggle of 0.42 s every 3–7.5 s), with a 2.5 px bob. No timers or tweens:
one `_process` that runs **only while the portrait is visible** and stops
when hidden or closed. **Reduce motion** (Settings) stills the tail and the
bob (the blink stays). Lists and the trophy board use static thumbnails
(`FishArt.thumbnail`). The same art is used on the reel, the result card,
the cool box, the trophy menu and the trophy board on the cabin wall.
Evidence (not a still): `fish_animation_frames_mackerel.png` — 48 frames,
0.15 s apart, of the running animation cut from the screen (the eye closed in
one, the tail turned in two); and the posed
frames 11–14. `test_fishing2` checks the blink and flick happen over time,
end, and stop with Reduce motion and when hidden.

### 12. Asset provenance

All fish and junk art is **original**, painted by a script in this
repository (`tools/fishing/paint_fish.py`, drawing with Pillow from shapes
and colours written in the script; no external images, no generated-image
service). Output: `assets/fishing/<id>/{body,tail,lid,thumb}.png` (junk:
`art.png`) and `data/fishing/fish_art.json`. Provenance and the regeneration
command: `assets/fishing/README.md`. The anchor ball, rode, buoy, lamp dots
and corner shade are drawn in code (`_draw`). No Captain-owned asset was
changed.

### 13. Catch preferences

On the rod: **Keep** — minimum rarity (any / uncommon / rare / very rare) and
minimum size (any / Bronze / Silver / Gold); a fish is kept when it meets
**both**, described in words ("Keep: Uncommon or better, Silver or better").
A fish below them is landed, shown, and released with the reason ("Not one to
keep by your preferences: back it goes."). Also on the rod: what fast time
does with bites (19). Saved (optional fields).

### 14. Trophy exclusion and persistence

Only **kept** fish reach the cool box, the trophy board, personal bests and
"exceptional" notes. Automatic releases (preferences, a full cool box), sharks
and junk never do. A kept fish released by hand (from the result card, or the
cool box) leaves the cool box **and** the trophy board, and if it held the
species' best weight, the best goes back to what it was before (or the
heaviest of that species still kept; new optional `prev_best_kg`). Tested in
`test_fishing2`, `test_joy_journey` and the restart test (scenario A).

### 15. Specimen grade calculations

Grade is by **weight only**, as a share of the species' own weight range
(`relative = (kg − min) / (max − min)`): **Bronze ≥ 0.35, Silver ≥ 0.6,
Gold ≥ 0.8**, below that "Ordinary". Rarity plays no part (a common herring
can be Gold; a rare trout can be Ordinary). Shown as a badge with the
rarity, and in words (never by colour alone).

### 16. Sharks and junk

- **Sharks**: blue shark (Atlantic islands, Iberian Atlantic, Biscay) and
  blacktip reef shark (Caribbean, Central America, Pacific; coastal); both
  rare; never in Danish or Baltic waters. Reeled in with the dial, then
  **always released** ("That's quite a catch. Better let this one swim
  free."): not food, not for sale, not a trophy; counted on the trophy board
  as sharks released.
- **Junk**: 6 % of bites (`junk_chance`): an old boot, a tangled rope, a
  rusty tin, each with its own drawing and a line of humour; worth nothing,
  discarded, counted.

### 17. Moored and anchored fishing

At anchor, moored, or waiting at an anchorage the rod fishes from a **still
boat** (the stationary mode); underway it **trolls**, and a line is refused
above the trolling speed. Tested in `test_fishing2` and `test_anchorage` ("waiting
there, one fishes from a still boat").

## Sailing

### 18. Sail Trim

**T** (or the action wheel) opens the Sail Trim panel: a slider from
**Eased** to **Sheeted in**, a sketch with a faint mark where the sail draws
best, a word ("Too loose", "Well trimmed", "Too tight") and the effect in
percent; **Leave it to the crew** (the default) sails exactly as before.
The best trim follows the true wind angle (and a little the wind strength):
`best = clamp((95° − |angle|) / 60°) × 0.9 (+ a strong-wind bonus)`. The
effect is a factor on the sailing speed only: **+6 % at best, down to −10 %
far off**; never on the engine, never on the speed the boat could reach
(the "potential"), so it cannot make an unsuitable point of sail fast or
stack. Measured over a test passage: +4.3 % well trimmed, −7.3 % badly
(part of that passage was under engine, where trim does nothing). The trim
is kept through course changes, saves and loads; its effect is recomputed
from the wind at each sail evaluation, not per frame. No gradual drift back
to neutral was added: leaving it to the crew is the relaxed default.

### 19. Long Passage refinements

- **"In fast time"** (on the rod): *stop for every bite* or *stop only for
  fish worth keeping*: with the second, bites from fish you would not keep
  swim off quietly (nothing is caught without you) and are counted ("(N fish
  nibbled and swam off on the way.)").
- In fast time (Long Passage or 20×) a bite is followed by a **3-hour rest**
  before the next.
- Measured (`tests/pacing_18.tscn`, Copenhagen → Las Palmas, 12 game days at
  12 h/s, real wind): **432** bite stops before, **75** after the rest, **8**
  with "only fish worth keeping" (Rare or better).
- Fast time stays the same simulation (distance, stores, wear and weather
  are computed exactly as at 1×; the existing Long Passage tests pass).
- Engine fuel cost is recorded as a future consideration only (not built).

## Anchorages

### 20. Anchorage waypoint design

At the chart table, any waypoint of the course can be marked as an
**anchorage** (the Anchorage button, or **M** for the selected waypoint); it
is drawn with an anchor. It must pass the game's own anchoring rule (water,
depth, within 2.5 nm of land): far offshore or on land is **refused with the
reason**, and the **nearest suitable spot** on the course side is offered
(one click moves it there). It can be dragged like any waypoint (the course
is recomputed; the flag moves with it), unmarked, or removed. A one-off hint
explains it the first time a waypoint is added. The flags are saved with the
route and the voyage.

### 21. Arrival and resume

- Arriving stops the leg at the spot and **stops Long Passage** (reason
  "anchorage"); the boat **waits** there: speed 0, sails furled, "waiting at
  the anchorage" on the HUD and sailing panel. Long Passage cannot start
  while waiting.
- On deck the captain is asked **once**: "We've arrived at our anchorage.
  Ready to drop anchor?" — **Drop anchor** (opens the usual anchoring panel:
  scope, the usual checks of wind, depth and holding; the anchor is never set
  by itself),
  **Not yet** (the boat keeps waiting; the action wheel offers the anchor and
  "Sail on"), **Sail on** (continues the course).
- After weighing anchor the rest of the course continues; that anchorage is
  done and never stops the boat again. A new course resets it.
- Loading a save made while waiting, or at anchor there, never asks again.

### 22. Anchor ball, anchor light, rode and buoy

`AnchorSignals` (`src/boat/anchor_signals.gd`), at anchor only (not moored,
underway or merely waiting at an anchorage):

- the **black ball** hoisted in the forward rigging, between the mast and the
  bow;
- the **rode** from the bow fitting into the water (slack in good holding,
  straighter when dragging) to a small orange **marker buoy** that bobs gently
  (still with Reduce motion);
- at night the **white all-round anchor light** at the masthead
  (`BoatLighting`, category "anchor"), and no red or green.

All in the boat's own coordinates, so they turn with the deck view.

### 23. Pet following and safety

- **Safe places** per boat are computed from its own layout
  (`DeckCompanionSpots`): three resting places (aft, amidships, forward) where
  the animal's whole body (a 16 px disc) is inside the **lifeline**, clear of
  every solid fitting (with a margin), away from the helm and the stations.
  The test of "inside" is a true distance test to every edge of the lifeline
  (an earlier eight-point ring test let a walk graze the rail for a frame on
  a concave edge; it was replaced).
- **Walks** between the companionway and a place follow a straight line when
  it is clear, otherwise a path found on a safe grid (8 px cells, no corner
  cutting) and pulled tight into a few straight legs; planned 3 px further
  inside than the safety test, so no frame touches the rail. Every frame of
  every walk is checked in `test_companion_deck` on all four boats.
- **When**: moored, or at anchor with wind under 20 kn and no rain or
  thunder, the companion follows the captain up after 2.5–5 s and down after
  4–8 s, and now and then moves between its places. **Casting off, weighing
  anchor or the weather turning** sends it below by itself (it walks to the
  companionway first); underway it stays below.
- **Saved**: its area and place (optional fields); loading on deck shows it at
  its place without walking up again. Petting works on deck as below.

## Lighting and wind

### 24. Lighting refinements

- **Cabin at night** (all four boats): the lamps at the saloon table, galley,
  chart table and berths use a tighter, stronger falloff (their own light
  texture), the night ambient is a little dimmer (luminance ~0.36, was 0.40;
  still within the "dim but not black" test), and a soft **corner shade**
  (a gradient along the floor's edges, deepest where two walls meet, clipped
  to the hull outline, faded in with the dark) lets the corners fall away.
  Measured on rendered frames (`tests/cabin_light_18.tscn`): lamp pool ÷
  floor corner brightness **2.5–6.6× before → 4.0–8.6× after**; the
  captain's brightness unchanged (±0.02). Side by side:
  `docs/screenshots/iteration18/cabin_lighting/` and
  `31_cabin_lighting_before_after_starling.png`.
- **Navigation lights**: red and green now sit **on the hull's rail** at the
  bow (computed from the lifeline at that point; before, they could float over
  the water where the bow narrows), with the white stern light; each has a
  small bright lamp dot and a small glow (no halos). Checked on screen in **all
  eight orientations** (red to port, green to starboard, both ahead of the
  stern light).
- **States**: underway — red, green, white stern; at anchor — the white
  anchor light only; moored — none (the harbour lights the quay); by day —
  none. Tested in `test_companion_deck` and `test_lighting`.

### 25. Wind forecast refinements

Measured first (`tools/weather/measure_wind_variation.gd`: 5 sailing areas,
25 points each, 40 start times, the authoritative weather model):

| Step | Speed change (mean / p90) | Direction (mean / p90) | Arrows changing colour band |
|---|---|---|---|
| 30 min | 0.2 / 0.6 kn | 0.8 / 1.7° | 3 % |
| 1 h | 0.4 / 1.1 kn | 1.7 / 3.4° | 7 % |
| 2 h | 0.8 / 2.3 kn | 3.3 / 6.8° | 14 % |
| 3 h | 1.2 / 3.4 kn | 5.0 / 10.1° | 21 % |
| 6 h | 2.3 / 6.2 kn | 9.9 / 20.0° | 34 % |

Half-hour steps were nearly invisible (3 % of arrows change). Chosen: **1-hour
steps, up to 6 h ahead and 6 h back** (◀ 1 h / Now / 1 h ▶): each step
visibly moves some arrows, and six steps reach changes worth planning around
(a third of the arrows change band, ~10° on average). Two-hour steps would
give the same reach with only three positions each way. Now still follows
the clock every half hour. Kept: NOW, PAST MODEL SNAPSHOT, FORECAST with
"Estimated conditions. Actual wind may differ.", read-only previews, the
snapshot cache (now 14 snapshots so all 13 navigator times stay cached), zoom
limits and the frame budget. The weather model was not changed.

### 26. Performance before and after

`tests/benchmark_18.tscn` (rendered, Xvfb + **software** OpenGL, so absolute
times are far above a real GPU; only before/after comparison is meaningful),
run twice on the I017 baseline (`3c5690a`) and twice on I018, mean frame
time (ms):

| Scene (Starling 33, night) | I017 runs | I018 runs |
|---|---|---|
| cabin | 92.7 / 91.9 | 97.5 / 93.2 |
| deck, moored | 163.7 / 167.5 | 149.7 / 145.5 |
| rod with a fish on, deck | 164.3 / 175.8 | 152.7 / 146.7 |
| deck, underway | 90.2 / 94.6 | 64.0 / 67.1 |
| deck, at anchor (I018: ball, buoy, companion on deck) | 91.8 / 85.9 | 55.6 / 57.5 |
| chart with wind | 60.0 / 64.3 | 57.5 / 62.0 |

- The cabin is within ~5 % (inside the spread of runs); the other scenes are
  equal or faster. Why underway and at anchor got faster was **not
  investigated**; it is reported as measured, not claimed as an improvement.
- Wind navigator: each new snapshot fills in ~0.55–0.65 s on this software
  renderer, as before (I017: 9 times in 4.7–5.6 s; I018: 13 times in
  7.2–8.5 s); a second sweep is instant (all cached).
- Files: `docs/benchmarks/iteration18_{before,after}_rendered_run{1,2}.json`.

## Verification

### 27. Automated test results

**Final full regression** (headless, every suite including the worldwide
all-pairs routing test), on the final code (`f8d68ed`): **4184 checks
passed, 0 failed**, exit code 0, 1046 s, 58 suites. Skipped by design: the
window-mode checks need a real display (reported as skipped by the runner).
(An earlier full run on the code before the last changes: 4155 passed, 1
failed — a developer guide still naming the removed `fish_fight.gd`; fixed,
and the guide suite re-run: 82/82.)

New suites: `test_route_wrap` (103 rendered / 87 headless), `test_fishing2`
(88), `test_sail_trim` (28), `test_anchorage` (54), `test_companion_deck` (52),
`test_joy_journey` (26: the section 23 scenario played in order — anchorage
waypoint, sailing, trim, trolling, bite, dial, release, arrival, Long
Passage stop, anchor, ball, coffee, deck, the companion joins, save, load,
anchor up, resume — with no duplicate prompt, result, walk or log entry
after the reload). Separate harnesses: `restart_18` (17 checks, section 29),
`screenshots_18`, `benchmark_18`, `cabin_light_18`, `pacing_18` and
`tools/weather/measure_wind_variation.gd`.

Existing tests changed, without weakening them: the I013 fishing tests now
land fish with the dial instead of the tension bar (same expectations:
landed, stored once, trophies); the version checks say 0.105a; the wind
navigator test expects 1-hour steps and ±6 h (and checks more: one step is one
hour, the button labels, all 13 times cached); `test_life_aboard` counts the
companions **shown** (the deck now always has a hidden companion node, so
"no companion on deck while it is below" is checked by visibility); the
lighting test adds the corner shade and lamp pools. Rendered runs per
checkpoint (`test_route_wrap`, `test_companion_deck`, `test_lighting`,
`test_wind_overlay`, `test_anchorage`, `test_sail_trim`) passed.

### 28. Rendered visual review

All in `docs/screenshots/iteration18/` (1600×900, software renderer),
reviewed by eye:

| # | Scene | File |
|---|---|---|
| 1 | Reel — common fish | `01_reel_common_fish.png` |
| 2 | Reel — rare fish | `02_reel_rare_fish.png` |
| 3 | Perfect timing | `03_reel_perfect_timing.png` |
| 4 | Missed timing | `04_reel_missed_timing.png` |
| 5–8 | Cod, mackerel, garfish, flatfish | `05_…`–`08_…` |
| 9 | Shark (art; and landed and released: `09b_…`) | `09_illustrated_shark.png` |
| 10 | Junk | `10_junk_catch_artwork.png` |
| 11–14 | Eyes open / closed, tail neutral / flick | `11_…`–`14_…`; real frames: `fish_animation_frames_mackerel.png` |
| — | Every species and junk item | `fish_art_sheet_all_species.png` |
| 15 | Result with weight and grade | `15_catch_result_weight_grade.png` |
| 16 | Automatic release | `16_automatic_release_by_preferences.png` |
| 17 | Manual release | `17_manual_release.png` |
| 18 | Kept catch (cool box) | `18_kept_catch_inventory.png` |
| 19 | Trophies | `19_trophy_presentation.png` |
| 20 | Fishing preferences | `20_fishing_preferences.png` |
| 21–22 | Sail Trim, well / badly trimmed | `21_sail_trim_control_well_trimmed.png`, `22_sail_trim_too_loose.png` |
| 23 | Anchorage waypoint icon | `23_anchorage_waypoint_icon.png` |
| 24 | Dragging an anchorage waypoint (and onto land: refused, `24b_…`) | `24_dragging_anchorage_waypoint.png` |
| 25 | Arrival prompt | `25_anchorage_arrival_prompt.png` |
| 26, 27, 30 | At anchor by day: ball, rode, buoy, companion on deck | `26_27_30_anchored_day_ball_buoy_pet.png` |
| 28 | At anchor at night: anchor light | `28_anchored_night_light.png` |
| 29 | Companion on deck, moored | `29_pet_on_deck_moored.png` |
| 31 | Cabin after the lighting refinement (+ before/after) | `31_…` |
| 32 | Navigation lights underway | `32_underway_navigation_lights.png` |
| 33 | Route before/after the pan fix | `33_route_before_after_pan_fix.png` |
| 34 | Wind preview controls (1 h) | `34_wind_preview_controls_1h_steps.png` |

Found and fixed by reviewing renders: the rode and buoy ran off screen under
the clock and the ball was too small (shorter rode at an angle, bigger ball);
the side lights floated over the water at the narrowing bow (moved onto the
rail); a corner-shade rectangle showed over the water (clipped to the hull);
leftover toasts in a screenshot; the wind buttons still said "30 min"; the
first animation strip (2.4 s) was too short to catch a tail flick (now 7.2 s).
Fishing scenes and the anchorage drag come from `tests/screenshots_18.tscn`;
the others from their suites (see its header).

### 29. Two-process restart tests

`tests/restart_18.tscn`, run as **two separate processes** (write, quit; then
read in a new process). A fixed fair wind is set in both processes so the
scenarios do not depend on the season; the weather model's own events still
run and are compared. **PASS, 17 of 17 checks** (write 9 s, read 5 s):

- **A — Fishing**: preferences Uncommon+ / Silver+; a cod (9.4 kg, Silver)
  landed through the dial and kept, a herring landed and let go by the
  preferences, a sea trout kept then released by hand; after the restart the
  hold (the cod only), trophies, records, preferences and counts are exactly
  as saved, no trophy for a released fish.
- **B — Anchorage**: course Copenhagen → Gothenburg with an anchorage at
  55°58.6′N 12°38.0′E marked on the chart; sailed there, anchored, the
  companion up on deck; after the restart: same position and time, at anchor
  as saved, the anchorage done (no question again), course and remaining way
  as saved, the companion on deck at its place and shown; anchor up and the
  voyage reaches Gothenburg at the same game time as in the first process.
- **C — Sailing**: trimmed by hand (factor 0.90 at that wind: a poor trim,
  kept as the captain set it), six hours toward Las Palmas; after the
  restart: trim, factor, speed (4.82 kn), weather, position, course,
  progress and stores (13.75 / 13.75 days) as saved; six more hours end
  where the first process got, in the same weather, with the same stores.

### 30. Shipyard Efficiency — Where the Time Went

Every Godot run went through one wrapper that logs wall time and exit code
(`i18_timing.log`, outside the repository). **Measured**, from the start of
I018 (08:21 UTC) to the start of the final regression (10:40 UTC):
**137 logged Godot runs, 77.3 minutes of Godot time** (I017: 138 runs,
47.1 min).

| Checkpoint | Runs | Godot time | Share | Note |
|---|---|---|---|---|
| A: route fix | 11 | 634 s | 14 % | rendered route sweeps ~90 s each (7 runs) |
| B/C: fishing core, art | 18 | 242 s | 5 % | focused suite ~10 s |
| D/E: anchored fishing, trim, pacing | 18 | 258 s | 6 % | |
| F: anchorages | 17 | 187 s | 4 % | |
| G: anchor signals, companion | 44 | 1982 s | 43 % | ~20 repeat runs chasing an intermittent one-frame graze |
| H: lighting, wind, benchmarks | 29 | 1333 s | 29 % | 4 rendered benchmarks ~200 s each |

**Expensive steps**: the four rendered benchmark runs (796 s, 17 %), rendered
route-wrap runs (7 × ~90 s), and the companion suite (40–75 s per run).
The worldwide all-pairs routing regression was kept for the final run only
(about 9 minutes of it).

**Avoidable work, honestly**:

- **G (≈20 min)**: the deck-walk test failed intermittently (one frame
  off-deck in 1 of 3 runs, depending on the randomly chosen resting place).
  Each fix was validated by repeating the suite 4–6 times. Root-causing it
  first (it was the eight-point body test not being monotonic on a concave
  lifeline) would have saved most of those runs; a seeded resting place in the
  test would have made it deterministic from the start.
- 25 runs ended with a non-zero exit (1004 s): mostly a test run right after
  writing it (typing errors, wrong API names, test fixtures). A single
  `--check-only` parse pass before the first real run would catch the
  parse errors in ~3 s (the wrapper already aborts on a parse error).
- No run hung this time: the wrapper's timeouts and the parse-error abort
  held (I017 lost 300 s to one hang).

**What helped** (from the I017 recommendations): focused `--only=` suites
while implementing; the expensive routing regression only at the end;
reusing the import cache; rendered runs only for visual checks; one
baseline worktree for before/after benchmarks instead of re-checking out.

**Recommendations**: seed every random choice a test depends on; repeat a
suspicious suite at most twice, then debug; run the parse check first; keep
rendered benchmarks to one pair (before/after) unless the spread matters.

**Checkpoint I** (after the table above; measured): 9 more runs, 2209 s —
two full regressions (1062 s and 1046 s), the restart test (9 s + 5 s), the
screenshot harness (25 s, twice) and focused suites. **Whole iteration:
146 logged runs, 114 minutes of Godot time.**

### 31. Known limitations

- **Anchorages and anchoring abroad**: the world chart outside the detailed
  Denmark region has ~5 nm cells, so a navigable cell next to land measures at
  least ~2.5 nm from it — beyond the anchoring rule (2.5 nm). Anchorage
  waypoints (and anchoring) therefore work in the detailed region only. This
  predates I018 (I016's coarse world chart) and is stated in the checklist.
- Sail Trim has no gradual drift back to neutral (the crew default covers the
  relaxed case).
- The companion's deck places are computed, not hand-placed; they are safe by
  construction and test, but their *look* (where it likes to sit) is generic.
- Fish art is script-painted, consistent but simple; sharks and the largest
  fish are drawn at the same portrait size as small fish.
- Benchmarks are from a software renderer; Windows frame times are
  unmeasured.
- Performance cause of the faster underway/anchor frames not investigated.

### 32. Windows acceptance status

**PENDING.** The checklist is `WINDOWS_ACCEPTANCE_18.md` (sections 1–16,
tests 1A–16C, each with what to do, what to expect, PASS / FAIL / PARTIAL /
NOT TESTED and space for observations). Nothing is marked accepted.

### 33. Git commit and push verification

Pushed with `git push -u origin claude/friendly-fermat-dey23f` after each
checkpoint (normal pushes; no force). The final verification (remote branch
head equal to the local head) is recorded in the commit that follows this
report, and in the delivery message.
