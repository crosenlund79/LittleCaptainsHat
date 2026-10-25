# Iteration 13: The Catch & The Cove

*Fishing, cooking, safe anchorage, companion art and the eight-direction
sailing view.* Version **0.101a**.

Nothing in this report has been accepted on Windows. That is the Captain's
trial, with `WINDOWS_ACCEPTANCE_13.md`.

## 1. Repository and starting commit

- **Working directory:** `/home/user/LittleCaptainsHat`.
- **Remote:** `https://github.com/crosenlund79/LittleCaptainsHat` (fetch and
  push). This is not KindleSpark, NomadicSailor, GardenOfOddlings or the
  archived Next Harbor repository; none of them was touched.
- **Branch:** `claude/friendly-fermat-dey23f`. The working tree was clean.
- **Starting commit:** `35c11ec` (Iteration 12 Checkpoint G, 0.100c), equal to
  the remote branch. Iteration 12 was completely delivered. The only other
  remote branch, `claude/determined-brahmagupta-3v95mx`, is the older I006
  baseline.
- **Baseline:** version 0.100c, save format 10, 34 test suites, the
  Iteration 12 report and `CAPTAINS_ORDERS.md` (which already recorded that
  the Phase Two wording is missing).

**Checkpoints** (all pushed):

| Checkpoint | Commit | Content |
|---|---|---|
| A | `0ea409d` | state design, save format 11 and its migration, the core rules |
| B | `ac64f7d` | fishing: rod, lures, fish, bites, the fight, trolling, trophies |
| C and D | `91231e2` | the galley and the anchor (committed together: they share the time and alarm wiring) |
| E, F and G | `b38e504` | the new cat and dog, their highlight, the eight-direction view |
| H | see §23 | verification, screenshots, documentation, version |

## 2. Version and save format

- **Version 0.101a** (`GameVersion.DISPLAY`; `MACHINE` 0.101.1;
  `project.godot` matches). The tags on the branch end at the local
  `v0.100c`, and 0.100c was the last revision of the 0.100 milestone, so this
  feature milestone is 0.101a. It is not derived from the iteration number.
- **Save format 11.** Fishing, cooking and anchoring add real persistent
  state (§16).

## 3. Fishing design and catch tables

The loop: let the line out at the rod, time passes (sailing, waiting at the
rod, sleeping), a fish bites, the captain comes to the rod, a short fight,
and the fish goes into the cool box (or back).

- **Bites** are checked every 5 game minutes with the line out, on a fixed
  grid, with a random generator seeded from the game's wind seed and the
  check's time. The same moment always gives the same bite, at 1× or 20×,
  in one long sleep or in many small steps (tested).
- **Chance per check** = 0.11 × how well the lure and the way of fishing suit
  the fish here (about 0.4–1.3), × 0.6 in winds over 22 kn; none when
  trolling faster than 7 kn.
- **Which fish**: the candidates of the sea area, weighted by rarity × lure ×
  way of fishing. The sea area is the region of the nearest harbour; fish
  marked coastal bite only within 3 nm of land. Sizes lean small.
- **A waiting bite** gives the captain 45 seconds of play (paused while a
  menu is open) to reach the rod; otherwise the fish slips off and the line
  stays out.

The catch table (`data/fishing/fishing.json`; multipliers per lure and per
way of fishing, 1 = average). A simplified gameplay table, not science:

| Fish | Rarity | Sea areas | Coastal | kg | €/kg | Fight | Spinner | Spoon | Soft | Jig | Still | Trolling |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Herring | common | Baltic, North Sea, Scandinavia, North Atlantic, British Isles | no | 0.1–0.45 | 4 | 0.25 | 1.0 | 0.7 | 1.2 | 0.9 | 1.1 | 0.8 |
| Mackerel | common | North Sea to the Aegean (11 areas) | no | 0.3–1.2 | 5 | 0.45 | 1.3 | 1.2 | 0.7 | 0.9 | 0.8 | 1.3 |
| Flounder | common | Baltic, North Sea, Channel, Scandinavia, British Isles | yes | 0.3–2.5 | 6 | 0.35 | 0.4 | 0.5 | 1.2 | 1.1 | 1.3 | 0.3 |
| Cod | uncommon | Baltic, North Sea, Scandinavia, North Atlantic, British Isles, Channel | no | 1–12 | 8 | 0.7 | 0.6 | 0.9 | 1.1 | 1.4 | 1.3 | 0.7 |
| Perch | uncommon | Baltic only | yes | 0.2–1.5 | 7 | 0.4 | 1.4 | 0.8 | 1.1 | 1.0 | 1.2 | 0.8 |
| Garfish | uncommon | Baltic to the Ionian (9 areas) | no | 0.3–1.2 | 5 | 0.5 | 1.1 | 1.3 | 0.6 | 0.6 | 0.8 | 1.2 |
| Gilt-head bream | uncommon | Mediterranean, Adriatic, Aegean, Ionian, Levant, Iberian Atlantic | yes | 0.3–2.5 | 10 | 0.55 | 0.6 | 0.6 | 1.4 | 1.1 | 1.3 | 0.6 |
| Sea trout | rare | Baltic, Scandinavia, British Isles, North Sea | yes | 1–6 | 12 | 0.75 | 1.2 | 1.4 | 0.8 | 0.6 | 0.9 | 1.2 |
| Sea bass | rare | Channel to the Levant (9 areas) | yes | 0.5–6 | 14 | 0.75 | 1.1 | 1.0 | 1.3 | 0.9 | 1.0 | 1.1 |
| Atlantic bonito | very rare | Mediterranean, Aegean, Iberian Atlantic, Biscay, Adriatic, Ionian, Levant | no | 1–5 | 11 | 0.85 | 1.0 | 1.3 | 0.5 | 0.8 | 0.4 | 1.5 |

Rarity weights: common 10, uncommon 4, rare 1.5, very rare 0.5.

**The fight** (`FishFight`, real time, so 20× never rushes it). Hold E (or
the Reel button) to reel in; reeling and the fish's runs raise the line's
tension, letting go eases it. The bar turns red with **"Ease off! The line is
close to breaking."** at 80 %; the line parts only after 1.6 s at the very
top. Strong wind (over 15 kn) and boat speed add a little tension. A
sensible captain (reel, ease off at red) lands every species from smallest
to biggest within 40 s; reeling flat out against the strongest fish breaks
the line, but only 1.5 s or more after the red warning; never reeling, the
fish slips the hook after 60 s and the line never breaks (all tested).

**Outcomes.** A landed fish goes into the cool box (6 fish); with the box
full it goes back. In the cool box: release it, cook it, or sell it at a
harbour grocery store (by weight). A broken line costs the lure. Every fish
has a unique id, so nothing can be landed, cooked, sold or released twice.

## 4. Equipment and lures

One basic rod (every game has it) and four lure families, sold at the
grocery store's counter beside the hat (new **Fishing lures** row):

| Lure | Price | Good for |
|---|---|---|
| Small spinner | €4 | most small predators: perch, mackerel, sea trout |
| Spoon lure | €5 | trolling: sea trout, garfish, bonito |
| Soft bait | €3 | fish near the bottom: flounder, bream, sea bass |
| Weighted jig | €5 | cod and bream lower down |

A new game, and every older save, starts with two spinners. The differences
are modest. The lures' overall fit (1 = average) in three sea areas:

| Sea area, way of fishing | Spinner | Spoon | Soft bait | Jig |
|---|---|---|---|---|
| Baltic, still | 0.93 | 0.86 | 1.28 | 1.16 |
| Baltic, trolling | 0.68 | 0.63 | 0.72 | 0.64 |
| North Sea, still | 0.88 | 0.87 | 1.09 | 1.05 |
| North Sea, trolling | 0.89 | 0.86 | 0.75 | 0.76 |
| Mediterranean, still | 0.94 | 0.93 | 0.84 | 0.82 |
| Mediterranean, trolling | 1.31 | 1.30 | 0.89 | 0.97 |

(The Baltic's coastal flounder and perch favour fishing from a still boat;
the Mediterranean's mackerel, garfish and bonito favour trolling.) The test
checks the spread stays within 0.5–1.4. There is no tackle shop catalogue.

## 5. Trolling

Underway the rod's panel says **"Trolling behind the boat at 5.9 kn"**. The
line goes out and the boat sails on; the existing automatic sail/engine
controller and the course keep doing their work, so the helm is never
abandoned. Bite checks run along the course where the boat is at each check.
Faster than 7 kn the lure skips: no bites, a single notice says so, and the
HUD shows **"Line out · too fast to troll"** in amber. A bite while sailing
rings the bell, shows **"Fish on! Go to the rod [E]"** and drops 20× to 1×.

## 6. Trophy display

A small wooden board with five brass hooks hangs on the cabin wall of every
boat, beside the hat hook (140 units away, further along the wall where that
spot is a companion's resting place; it never takes the E key from a station
or the cat). Each of the five best catches is a little
painted fish in its species' colour (the best has a brass medal); empty
places are faint outlines. **E** at the board lists them:
"1. Atlantic bonito, 4.2 kg · very rare · 1 May, Copenhagen" and the record
(caught, species, released, sold, best weight per species).

**Ranking:** score = 25 × rarity rank (common 1 … very rare 4) + 50 × size
within the species (0 smallest, 1 biggest) + 10 if it was a new species or a
personal best when caught. Highest first; ties keep the earlier catch. The
board lives in the game state, not the boat, so it is the same after loading
and after changing boats.

## 7. Cooking recipes and effects

The stove (a little two-burner hob beside the provisions, on every boat)
opens the galley: choose a dish, see what it needs and gives, **Cook**. The
pan sizzles (flames, steam, a soft sizzle) for 1.6 s, then the dish is served
in one transaction and the cooking time passes below deck. The stove keeps
steaming for a while.

| Dish | Fish | Groceries | Food to the stores | Time | Well fed |
|---|---|---|---|---|---|
| Warm porridge | – | 0.25 d | – | 15 min | 10 h |
| Bread and soup | – | 0.5 d | – | 35 min | 16 h |
| Pan-fried fish | 1 | – | 0.6 d per kg | 25 min | 12 h |
| Fish stew | 1 | 0.3 d | 0.9 d per kg + 0.3 d | 50 min | 16 h |
| A sailor's supper | 2 | 0.5 d | 1.0 d per kg + 0.5 d | 60 min | 20 h |

Fish dishes add at most 3 days of food each. **Well fed** makes the food
stores last longer (0.75 of the usual use) while it lasts; nothing else. No
hunger, nutrition or mood system. Fish are taken from the cool box oldest
first.

**The stove rule:** in harbour and at a holding anchor, always; underway only
below 18 kn and without a weather hazard ("Too lively for the stove … anchor
somewhere sheltered"). A refused dish changes nothing; there are no
accidents.

## 8. Anchorage model

The chart has **no depth soundings or seabed data**, and the game invents
none. `AnchorSite` uses only the chart's own land/water grid (about one
arc-minute per cell):

- Anchoring is offered only during a voyage, in open water, with land within
  **2.5 nm** (assumed shallow enough), and not in more than **34 kn**.
- **Shelter is the fetch**: how far the wind blows over open water before it
  reaches the boat, walked upwind in 0.25 nm steps up to 8 nm. Up to 1.5 nm:
  sheltered (a good anchorage); up to 4 nm: partly sheltered (fair); more:
  exposed (poor). A wind shift changes it.
- The bottom is assumed to be ordinary mixed ground everywhere.

The windlass panel says which it is and why, and states these limits in a
line of its own. On land, far offshore, in harbour and in a gale the anchor
is refused with the reason.

## 9. Holding and dragging calculations

```
power  = 16 + chain (3×: 0, 5×: 6, 7×: 10) + 8 × set quality + shelter (8 / 4 / 0)
wind   = max(sustained, gusts × 0.8) × exposure (sheltered 0.55, partly 0.8, exposed 1.0)
margin = power − wind:  ≥ 8 Holding well · ≥ 3 Fair holding · ≥ 0 Poor holding · < 0 Anchor dragging
```

**Setting** is one short interaction: a marker swings across a bar; "Set it
now" (or E) as it crosses the green middle. Caught in the middle the set is
1.0, at the edge 0. More chain, a good set and shelter each hold better; as
the wind rises the holding always steps well → fair → poor → dragging, and
poor holding spans several knots before dragging (tested).

The anchor is checked on the weather's 5-minute grid. **Poor holding** (from
well or fair) raises the alarm. **Dragging** raises it again and moves the
boat 0.04 nm downwind per check (no jumps); within 0.6 nm of land each check
also scrapes the hull 1.5 %. At a holding anchor, weather damage is reduced
by the shelter's exposure. Letting out chain or setting the anchor again
works the holding out afresh (10 minutes); "Raise anchor" ends the stay.

## 10. Sleep and alarm behaviour

- Sleeping at anchor in steady conditions sleeps through (tested over 9 h);
  8 hours without dragging is "a night at anchor".
- An anchor alarm (poor or dragging) stops the sleep at once
  (`STOP_ANCHOR`): "You were woken after 1 h 05 min by the anchor alarm: poor
  holding. Go up to the windlass." A bite does the same (`STOP_BITE`), and so
  do weather warnings, as before. Accelerated time drops to 1×.
- Every alarm has a visible counterpart: a notice, the HUD badge
  ("At anchor · Poor holding" in amber, **"Anchor dragging! Go to the
  windlass"** in red, pulsing) and a soft double beep. "Alarm seen" in the
  panel answers it; it sounds again if things get worse.

## 11. New cat and dog graphics

The old in-game look (the owner's side-view cat drawings and the dog's
procedural shape) is replaced by **new illustrations in the game's style**,
painted by a script so they can be repainted and tuned:
`tools/companions/paint_companions.py` → `assets/companions/cat/` and
`assets/companions/dog/`. Seen from above (like the boats and the sailor),
warm ink outlines over soft colour washes with a little grain, a soft shadow;
a grey tabby with a white chest and pink ears, and a brown and cream dog with
floppy ears and a red collar.

| Pose | When | Cat | Dog |
|---|---|---|---|
| resting | idle, most of the time | lying, head up on its paws, eyes half open | lying, head up, eyes open |
| sleeping | now and then | curled up, eyes closed | lying on its side, eyes closed |
| alert | walking up to it; **petted** (hearts, purr or panting) | sitting up, looking at you | sitting up, tongue out |
| stretching | before or after a nap | a long stretch | a long stretch |

Scale: the cat is drawn 100 units across, the dog 116 (the captain is about
40 across the shoulders, seen from above). The sets are data
(`data/companions/cat_visuals.tres`, new `data/companions/dog_visuals.tres`).

**The owner's original drawings stay** in `Visuals/Cat/`, byte for byte
(their checksums are tested), and can be switched back in through data. No
runtime path depends on them any more.

## 12. Companion interaction changes

The companion logic is unchanged (resting spots, schedule, petting, sounds,
persistence). What changed is how it is drawn and highlighted:

- The animal is a highlight provider: when the captain can pet it, it **glows
  around its own silhouette** (the outline of the pose shown, updated when the
  pose changes). No tint, no circle.
- The focus rules are unchanged: the companion's priority stays −1, so the
  galley, berth, hat hook, chart table, companionway and other stations keep
  the E key unless the captain stands clearly closer to the animal; the
  prompt says "Pet cat" / "Pet dog".
- The dog now uses pose images like the cat, so it is drawn upright (the
  procedural shapes remain only as a fallback).

## 13. Eight-directional display implementation

- `BoatArea.get_view_octant()` maps the course to the nearest of N, NE, E, SE,
  S, SW, W, NW (0°, 45°, … 315°). **Hysteresis:** a new octant is taken only
  8° past the halfway line, so a course drifting to 30° keeps the north view
  and comes back from north-east only below 14.5°. A course wavering ±5°
  around a boundary does not flip the view (tested).
- The camera turns to the octant with the existing 1.8 s smooth tween.
- **Only the picture is quantized.** The simulation's heading, routes, wind
  angles, speeds, distances and ETAs keep their full precision (tested: a
  heading that is not a multiple of 45° is kept exactly by the simulation
  while the deck is drawn in its octant).
- Moored, the deck is upright as before; Settings → *Sailing view* still
  switches the course view off (the fixed, bow-right view).

## 14. Camera and movement controls

- **Controls:** movement is screen-relative (W up the screen, S down, A left,
  D right) because the player's input is turned by the camera's rotation.
  With eight directions the rotation is always a multiple of 45°, so the keys
  never drift at odd angles (tested at 45° and 225°: W walks up the screen).
- **Framing:** the Iteration 12 zoom floor (0.78) keeps the deck readable;
  instead of shrinking the boats further, the course-view camera now
  **follows the captain** along the turned boat, clamped so it never shows
  more water past the boat's ends than needed. On the large Frogleap 36
  sailing north the captain stays in view at the bow and at the stern
  (tested and screenshotted); small boats that fit stay centred.
- The HUD stays upright; waves keep their world direction.

## 15. New interaction highlights

All four new stations use the Iteration 12 highlight architecture (an
`Interactable` with no tint target, a `HighlightProvider` on the drawn
object): the rod holder on the stern rail, the windlass on the foredeck, the
galley stove and the trophy board. Each is placed from the boat's own
outline and fixtures (no per-boat offsets) and reachable on foot on all four
boats (tested with the walkability flood fill, on a finer grid for the Wing
33's narrow side decks). No circle is drawn anywhere.

## 16. Save migration and compatibility

- **Format 11** adds `fishing` (rod, lures, chosen lure, line out and mode,
  check grid, the cool box with ids, next id, records, trophies, counts),
  `galley` (well fed until, meals, last meal) and `anchor` (active, position,
  chain, set quality, holding, alarm, dragged distance, anchored since, check
  grid).
- **Migration 10 → 11** adds an empty cool box with the basic rod and two
  spinners, a clean galley and no anchor down. Nothing else changes; every
  older format still migrates through it.
- **Validation** rejects a fish twice in the cool box, more fish than it
  holds, ids beyond the next id, and an anchor down outside a voyage.
- **Not saved:** a bite waiting for the captain and a fight in progress.
  After loading the line is simply out; nothing is landed twice.
- Loading at anchor restores the boat where the anchor holds it, with the
  same holding (tested), and the whole day (catch, anchorage, meal, night)
  saves and loads exactly (journey test).

## 17. Captain's Log and progression integration

Through the existing ObjectiveProgress ledger and renown (no new currency),
each paid once only:

| Moment (Captain's Log) | Renown |
|---|---|
| Caught my first fish | 3 |
| First <species> caught | 2 each |
| An exceptional <species> (top fifth of its sizes) | 4 each |
| First meal cooked in the galley | 2 |
| Supper from my own catch | 3 |
| A quiet evening at anchor. Fresh fish for supper. | 5 |
| First anchorage of my own (holding fair or better) | 3 |
| A night at anchor | 3 |
| Stopped the anchor dragging | 4 |

Personal bests are recorded without renown. Ordinary fish, meals and
anchorages earn nothing more.

## 18. Diagnostics

New bounded SessionLog events (one line per action, never per frame):
`fishing_open`, `fishing_line`, `fishing_wait`, `fishing_bite`,
`fishing_fight`, `fishing_result` (landed, broke, escaped, escaped
unattended), `fish_landed`, `fishing_fish` (released, sold),
`fishing_sold`; `galley_open`, `cooking_started`, `cooking` (including
refusals), `meal`; `anchor_open` (with suitability), `anchor` (drop with
scope, set and class; scope; reset; acknowledge; raise), `anchor_state`
(holding changes), `anchor_alarm`; `sleep` (with what stopped it);
`companion_pet`; `view_octant` (octant changes). Diagnostics never affect
the game.

## 19. Tests run and results

New suites: `test_fishing` (96 checks), `test_galley_and_anchor` (87),
`test_eight_directions` (38), `test_catch_and_cove_journey` (31). Updated:
`test_companion_art` (new art, dog set, highlight; 90), `test_harbour_life`
(octant course view; 96), `test_branding` and `test_diagnostics` (0.101a,
format 11), `test_dev_guides` (the new guide).

FULL_RUN_RESULTS

## 20. Rendered screenshot review

Rendered under Xvfb (software OpenGL, 1600 × 900), inspected one by one;
copied to `docs/screenshots/iteration13/`:

| # | Required | File | Seen |
|---|---|---|---|
| 1 | redesigned cat | `13_companion_cat.png` | the new tabby resting on the settee, at a size that sits right next to the captain |
| 2 | redesigned dog | `13_companion_dog.png` | the new dog resting on the cabin floor |
| 3 | cat highlight | `13_companion_cat_highlighted.png` | the glow hugs the sitting cat; "Pet cat" |
| 4 | dog highlight | `13_companion_dog_highlighted.png` | the glow hugs the sitting dog |
| 5 | fishing station | `13_fishing_rod_highlight.png` | the rod on the port quarter glows; "Fishing rod" |
| 6 | fishing panel | `13_fishing_panel.png` | how and where (moored, Baltic, near the coast), lure, line, wait, cool box |
| 7 | bite / tension | `13_fishing_bite_tension.png` | red tension bar, "Ease off!", progress bar, the HUD's "Fish on!" |
| 8 | catch result | `13_fishing_catch_result.png` | "Perch, 0.8 kg · A new species", the fish in the cool box with Release / Sell |
| 9 | trophy display | `13_trophy_display.png`, `13_trophy_board_highlight.png` | the ranked list; the board on the cabin wall with five painted fish |
| 10 | cooking panel | `13_cooking_panel.png` | the dishes, the stew's needs and effects, the pan |
| 11 | completed meal | `13_cooking_meal_done.png` | "Fish stew is ready … Well fed until …", steam, the HUD's "Well fed" |
| 12 | suitability | `13_anchor_suitability.png` | "An exposed anchorage …", the chain choice and the model's limits |
| 13 | anchor deployed | `13_anchor_deployed.png` | chain over the bow, sails furled, "At anchor · Holding well" |
| 14 | holding | `13_anchor_holding.png` | the panel at anchor with the holding and the wind |
| 15 | dragging warning | `13_anchor_dragging_warning.png` | red "Anchor dragging! Go to the windlass", the poor-holding notice before it |
| 16 | eight directions | `13_view_0_north.png` … `13_view_315_north_west.png` | the bow points N, NE, … NW; HUD upright |
| 17 | Arctic Wanderer 26 | `13_view_ne_arctic_wanderer_26.png` | whole boat, centred |
| 18 | Wing 33 | `13_view_ne_wing_33.png` | whole boat |
| 19 | Clam 40 | `13_view_ne_clam_40.png` | whole catamaran |
| 20 | Frogleap 36 | `13_view_ne_frogleap_36.png`, `13_view_north_frogleap_at_the_bow.png`, `…_at_the_stern.png` | the trimaran with its spinnaker; sailing north the camera follows the captain to the bow and the stern |

Also: `13_galley_highlight.png`, `13_cooking_in_progress.png`,
`13_trophy_board_highlight.png`, `13_new_game_dog_art.png`.

Findings from the review, fixed before delivery: the companions were first
drawn too small beside the captain (enlarged); at anchor the HUD still said
"Under sail" and the sails stayed set (now "At anchor · voyage paused",
furled); the trophy list wrapped badly (shortened); award titles
lower-cased "Atlantic bonito" (fixed); notices covered panels in
screenshots (cleared for the shots). No mismatch remains between the
automated results and what the screenshots show.

## 21. Known limitations and compromises

- **Anchorages are coarse.** The model knows only land, water and the wind:
  no depths, no seabed, no rocks or shoals, no tidal streams. The chart grid
  is about one arc-minute, so a narrow cove may not be found, and "land
  within 2.5 nm" stands in for "shallow enough". The panel says so.
- **Dropping the anchor stops the boat at once** (the 15 minutes include
  rounding up and letting go); there is no slowing-down manoeuvre.
  **Raising it** continues the voyage from its course position, so after a
  drag the chart position returns to the route (small; the drag is at most a
  few tenths of a mile before the captain is woken).
- Fish areas follow the nearest harbour's region; there are no seasons,
  times of day or depths for fish.
- The companions still do not walk or face different directions; they move
  between resting spots as before (the existing behaviour, kept on
  purpose).
- All new sounds are synthetic placeholders.
- The course view still rotates the deck art (now only by multiples of 45°);
  the illustrated art is not redrawn per direction.
- Stations are placed by rule from each boat's outline and fixtures, not
  hand-placed: on the Arctic Wanderer 26 the rod sits beside the cockpit bench
  and the trophy board hangs on the port wall (the hat's wall has no free
  stretch clear of the cat's resting spots); on the Wing 33 the windlass is
  reached along narrow side decks. The full regression run caught the first
  placement of the board and the stove competing with the cat's and dog's
  resting spots for the E key; they now keep clear of those spots, and the
  board has the companion's low focus priority.
- Tested on Linux only (headless and Xvfb). Windows is the Captain's trial.

## 22. Captain's Orders updates

`CAPTAINS_ORDERS.md`:
- a new **Iteration 13** section with every decision the Captain approved
  (fishing, cooking and anchoring as one experience; manageable equipment
  and regional fish; the five-catch trophy display; lightweight cooking;
  coastal anchoring with scope, holding, dragging and alarms; progression
  through renown and the Log; the cat and dog replacement; companions in the
  highlight system; no circles; eight-directional display with accurate
  physics; intuitive controls; strict preservation; revision iterations as
  the preferred follow-up);
- fishing and anchoring removed from **Not now** (with a note that they were
  commissioned as Iteration 13);
- **Phase One and Phase Two**: the distinction is preserved. The precise
  Phase Two wording is still absent from the repository; it is not invented.
  Recorded only what the current authorization establishes: Iteration 13 is
  within the current scope and does not reopen or expand Phase Two;
- the iteration log gains Iteration 13.

## 23. Final version, commit, tag and push status

FINAL_STATUS
