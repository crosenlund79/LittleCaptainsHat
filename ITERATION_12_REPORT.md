# Iteration 12: A Little Harbour Life

*Revision build: interaction polish, shore access, hat feedback and harbour
atmosphere.* Version **0.100c**.

Nothing in this report has been accepted on Windows. That is the Captain's
trial, with `WINDOWS_ACCEPTANCE_12.md`.

## 1. Repository and starting commit

- **Working directory:** `/home/user/LittleCaptainsHat`.
- **Remote:** `https://github.com/crosenlund79/LittleCaptainsHat`. This is not
  NomadicSailor, KindleSpark or the archived Next Harbor repository.
- **Branch:** `claude/friendly-fermat-dey23f`. The working tree was clean.
- **Starting commit:** `f90fe9c` (0.100b, "A Living Little World"). I checked
  that it is the latest delivery. The only other remote branch,
  `claude/determined-brahmagupta-3v95mx`, is the older I006 baseline and an
  ancestor of it.
- **Latest report** before this one: `VISUAL_POLISH_0100B_REPORT.md`.
  Version 0.100b, save format 10.
- **CAPTAINS_ORDERS.md** did not exist; it is created now (§18).
- **Tests and tools** available: the headless test runner (`tests/test_runner.tscn`,
  33 suites; 34 with this iteration's new one), rendered screenshots under Xvfb, the two-process restart check,
  and the diagnostic session logger (SessionLog).

**Checkpoints** (all pushed):

| Checkpoint | Commit | Content |
|---|---|---|
| A | `a5409d0` | hat feedback and shortcut contrast |
| B–E | `f82b177` | object highlights, gangplank and shore, harbour facilities, Go Ashore (committed together: they share `BoatArea` and the harbour signs) |
| F | `84198ab` | the boat faces its course underway |
| G | see the delivery message | verification, screenshots, documentation, version |

## 2. Version

**0.100c** (`GameVersion.DISPLAY`; `MACHINE` 0.100.3; `project.godot` matches).

Under the convention, 0.100b is "fixes and refinements within a milestone" and
0.101a is "the next feature milestone". This iteration is an authorized
revision of the 0.100 milestone, so it takes the next letter. It is not
derived from the iteration number.

**The save format stays at 10** (§13). The release tag `v0.100c` is created
after verification; see the delivery message for whether the push was
accepted.

## 3. Hat feedback

The hat-loss rules did not change: probability, strain, warnings and
achievements are all as before. What changed is how the hat's fate is shown.

**Before the loss**
- `HatBadge` is new, in the HUD under the area panel.
- While the worn hat is at risk on deck (after the wind warning), a little hat
  flutters and lifts with wind streaks: **"Hold onto your hat! [H]"**.
- The warning message itself stays up 7 s (ordinary notices: 3.5 s).

**At the loss**
- The message reads **"Hat overboard! Your captain's hat has decided to explore
  the ocean without you. A new one is sold at the harbour grocery store."**
- It stays up 9 s, on the toast layer above every panel, so an open panel
  cannot hide it.
- The badge pulses for a few seconds.
- The tumble on deck is larger (×1.45) and longer (2.8 s), with wind streaks and
  two fading echoes.
- One message per loss: the test checks it appears exactly once.

**After the loss**
- A quiet **"Hat missing"** badge stays, on deck and below, until a new hat is
  bought. Then it disappears.

**Muted audio:** none of this needs sound.

**Diagnostics:** `hat_warning_shown` and `hat_lost_shown`, the latter with
whether a panel was open.

## 4. Shortcut contrast

- The bottom-left shortcut line used to be flat grey text. It is now a compact
  strip on a dark translucent backing.
- Each key is a cream key cap: `WASD / ↑↓←→`, `E`, `H`, `L`, `Esc`. Its meaning
  sits beside it in light text.
- It is the same on deck, in the cabin and in harbour, and scales with the
  interface scale.
- Checked over the pontoon, the quay with Copenhagen's houses, the water and
  the cabin. Screenshots: `175_copenhagen_with_boatyard.png`, `170_hat_warning.png`.
- No other panel was redesigned.

## 5. Interaction highlight architecture

- `Interactable` no longer draws the brass ring. The **generous interaction
  areas are unchanged**, and so is the focus priority: nearest wins, the
  companion yields to stations unless faced. Interactions are exactly as easy
  as before.
- While focused, a station draws a soft warm glow with a fine cream outline
  that breathes gently, around **the object it belongs to**.
- `HighlightResolver` finds that object from each boat's own layout, in this
  order:
  1. a provider that names the interaction: the hat hook, each harbour sign;
  2. the nearest furniture fixture named for it: the chart table (`nav_table`),
     the berth (`bed`), the galley (`provisions`), the saloon table or desk
     (`work`), the wheel or tiller (`helm`), the companionway steps;
  3. a small soft outline of the area itself. The Clam 40's saloon doorway
     uses this, since it has no step fixture.
- The prompt panel still says exactly what E will do.
- The companion keeps its own highlight (the animal brightens).
- **Developer view:** F8, with the developer tools, draws every interaction
  area. It never appears in normal play.
- Comparison: `180_interaction_before_after.png` shows the 0.100b ring against
  the 0.100c glowing hook, the same moment aboard the Arctic Wanderer 26.

## 6. Gangplank and shore access

`ShoreAccess` builds the shore on every deck with a pontoon, from that deck's
own layout. There are no per-boat numbers.

- **The gangplank** lands at the boat's existing boarding point
  (`from_boatyard`) and runs straight down to the pontoon. It is 68 units wide
  (the player is 40 across), with boards, cleats and hand ropes.
- **The rail.** In harbour, the closed rail (`Lifeline`) is swapped for the same
  outline with a gap exactly where the plank meets it. The plank's sides and the
  shore strip complete one walkable area: boat, plank and pontoon. There is no
  place between boat and land to get stuck. The test checks this both ways on
  every boat, in addition to walking it with the keys.
- **The shore strip** is the front of the pontoon. The back holds the service
  signs, so the captain walks up to them.
- **The services stand ashore:**
  - the grocery store, the boatyard and the new **Go Ashore** sign, placed in
    slots left and right of the gangplank;
  - each sign is what lights up;
  - the harbour's name is painted on the pontoon beside the plank.
- **The view** glides down when the captain steps ashore, so the pontoon and
  signs show, and back up when they return.
- **Underway** the gangplank comes in and the rail closes. A captain ashore when
  the boat leaves is put back aboard at the boarding point. All shore stations
  are disabled.
- **Safety:**
  - cabin and deck transitions, arrival, departure and mooring are unchanged;
  - after a rescue, a vessel switch or a load, the shore is rebuilt from the
    state;
  - a game saved ashore loads with the captain on the pontoon (tested).

## 7. Behaviour on all four boats

Each boat was tested in the same way: the gangplank is out; you can walk from
the cockpit down the plank to the pontoon, and from the pontoon back to the
companionway; every shore service can be reached; there are three signs; the
keys walk you down and up the plank; the view follows.

| Boat | Boarding point | Screenshot |
|---|---|---|
| Arctic Wanderer 26 | (40, 84) | `172_gangplank_arctic_wanderer_26.png` |
| Wing 33 | (−20, 128) | `172_gangplank_starling_33.png` |
| Clam 40 | starboard hull (−20, 226) | `172_gangplank_halcyon_40.png` |
| Frogleap 36 | starboard float (0, 236) | `172_gangplank_petrel_36.png` |

The Frogleap is narrower on the pontoon, so its third sign moved in slightly:
slots at ±215 and +430.

## 8. Harbour facility metadata

- `HarbourFacilities` defines `grocery`, `boatyard` and `go_ashore`, all on by
  default. A harbour without its own file keeps exactly the services it had,
  plus Go Ashore.
- Per-harbour overrides live in `data/harbours/facilities/<port_id>.tres`, apart
  from the generated harbour catalogue, so the harbour builder never
  overwrites them.
- **One rule decides, everywhere.** `GameSession.has_facility()` and
  `facility_refusal()` guard every entry point:
  - the boatyard: opening it, changing boats, repairs;
  - the grocery store: opening it, buying food and water, buying a hat;
  - Go Ashore;
  - the grocery buttons in the provisions and boatyard panels.

  Nothing unavailable can be used or charged.
- An unavailable station is disabled, hidden and removed from interaction, so
  there are no invisible targets. Its sign and classic label are hidden too.
- How to add one: `DEV_GUIDES/HARBOURS.md`.

## 9. Copenhagen and Lohals

- **Copenhagen:** groceries, boatyard and Go Ashore (explicit file).
  `175_copenhagen_with_boatyard.png`.
- **Lohals:** groceries and Go Ashore; **no boatyard**.
  `176_lohals_without_boatyard.png`. In Lohals:
  - changing boats and repairs are refused ("There is no boatyard in Lohals.")
    and nothing is charged;
  - the boatyard cannot be opened.
- **Lohals was not in the catalogue.** I added it as one harbour, the one the
  Captain named, through the existing tooling (`harbours.csv` →
  `build_harbours.py`):
  - **id** `lohals`, UN/LOCODE DK LOH;
  - **position** 55.1325 N, 10.9014 E, from the MarineLink port entry, which
    matches the town's published position;
  - **classification:** island harbour on Langeland, importance 3.

  The harbour suite validates it: on a coast, an approach from open water, and a
  valid route. The catalogue now has 164 harbours. No other harbour was
  researched or changed.

## 10. Go Ashore

**The event library** (`ShoreEvents`):

| Kind | Events |
|---|---|
| Generic (every harbour) | a harbour café, a quiet bench, a friendly sailor, a small market stall, a view over the harbour, the harbour noticeboard (with a hat joke), gulls with opinions, a well-loved old boat |
| Copenhagen | the colourful waterfront: only what the game already shows, its colourful houses |
| Lohals | a quiet island evening: only what any small harbour has |

Each event has a title, a short text, a drawn icon, one or two choices and
Return to the boat.

**Consequences** reuse what exists:
- a small cost (€0–8);
- 10–60 minutes of harbour time (`Simulation.spend_time_ashore`, with the hat
  sheltered);
- renown 1–4, **only the first time** an event is enjoyed in a harbour;
- a **notable moment** in the Captain's Log.

**No farming**
- Events not yet enjoyed in a harbour are offered first, in an order fixed for
  the game, so reopening never re-rolls.
- After an outing the harbour "rests" for 6 game hours: a pleasant stroll, with
  nothing to gain.
- A choice for an event that is not on offer is refused.
- Outings are recorded in the existing, already-saved objective records
  (`shore:<port>:<event>`), so no reward can be paid twice, even across saves.

**Out of scope, as instructed:** no NPC pathfinding, dialogue trees, quests,
inventories, currencies, factions, walkable villages, generated stories or
chains.

**Diagnostics:** `facility`, `shore_event` and `shore_choice`, with cost,
renown, minutes and any refusal.

Screenshots: `177_go_ashore_event.png` and `178_go_ashore_outcome.png`.

## 11. Course-facing boat: outcome

**Prototype first.** The deck scenes are drawn in boat coordinates (bow = +x)
with a fixed camera, and the HUD is on its own canvas layer. Turning the deck
camera therefore turns the boat, the water and the sails together. The HUD,
the collision, the hit-testing and the sailing simulation are untouched,
because they all live in boat coordinates. Turning proved robust, so it is
**integrated**, behind a setting.

**How it works**
- **Setting:** Settings → *Sailing view* → **Boat faces its course** (on by
  default).
- **Rotation:** underway, the camera turns to `90° − heading`. The bow points
  along the voyage leg's course on screen, with north up. The model has one
  course per leg; no separate visual "truth" was invented.
- **Transitions:** rotation, zoom and centre tween together over 1.8 s at
  departure, at each new leg and on arrival. Nothing moves frame by frame, so
  there is no jitter. Moored, the deck is upright as before.
- **Zoom** fits the turned boat (with room for a flying spinnaker) inside the
  screen less the HUD, but **never below 0.78**. This is the compromise: at due
  north or south, the deck is drawn smaller than when sailing east or west.
  Measured at 1600×900:

  | Heading | Arctic Wanderer 26 zoom |
  |---|---|
  | east, west | 1.29 |
  | north, south | 0.78 |

  At 0.78 the 26 fits completely. The longer boats (about 1000 units) can reach
  the top and bottom of the screen at due north or south; the floor keeps the
  deck readable rather than tiny.
- **Controls:** WASD and the arrows stay screen-relative (W walks up the screen,
  towards the bow when it points north). Interaction is unchanged.
- **World coherence:** the waves keep their world direction (tested). The water
  is enlarged to fill a turned view.
- **Not done:** the hull's drop shadow turns with the boat, so the "sun" moves.
  This is minor and noted under limitations.
- **Diagnostics:** `course_view`, with heading, zoom and whether the floor was
  reached.

Screenshots: `179_course_north`, `_east`, `_south`, `_west`. These four use a
presentation-only heading override (`BoatArea.view_heading_override`), so the
sails show the real course of that test voyage, not the forced heading.

## 12. Existing systems protected

Unchanged:
- the four-boat fleet;
- sailing and weather physics, routing and the chart;
- the 0.100b camera improvements (the 0.86× underway framing when the course
  view is off);
- the wind-aware water, marine decking and player animation;
- provisions, groceries and their prices;
- boat condition and rescue;
- companion behaviour;
- the hat's state and achievements;
- the Captain's Log, renown and social publishing;
- save migration and diagnostics.

No financial balance was changed. The Captain's artwork is untouched: the
owner's cat drawings are MD5-checked by the tests.

## 13. Save compatibility

- **No save format change; the format stays at version 10.** The Go Ashore
  records reuse `ObjectiveProgress.completed`, which is already saved and
  validated. A new `mark()` records without paying renown.
- **Loading this version's saves in older versions:** older versions also load
  them; they simply ignore the `shore:` records.
- **Lohals** is a new port id. Older saves never name it.
- **Course view** is a preference in `settings.cfg`, not saved game state.
- **Tested:**
  - saving ashore and loading (on the pontoon);
  - saving after an outing and loading (rewards kept, not repeatable);
  - the restart check (two processes);
  - the existing migration tests.

## 14. Diagnostic updates

New SessionLog events, each one line written at the moment it happens, never
per frame:

| Event | Contents |
|---|---|
| `hat_warning_shown` | area, seconds |
| `hat_lost_shown` | area, seconds, whether a panel was open |
| `gangplank` | to shore or boat, vessel, port |
| `facility` | grocery, boatyard or go_ashore; opened or unavailable |
| `shore_event` | event, resting, seen |
| `shore_choice` | event, choice, error, cost, minutes, renown |
| `course_view` | heading, zoom, whether the zoom floor was reached (once per deck) |

## 15. Tests actually run

Godot 4.7.2, headless unless stated.

**New suite `test_harbour_life`** (96 checks):
- facility data: Copenhagen, Lohals, defaults, only Lohals lacks a boatyard;
- shore access on all four boats: reachable both ways, every service ashore,
  three signs, walking down and up with the keys, the view following;
- highlights: cabin stations on all four boats; shore signs; focus and prompts
  at the grocery and boatyard signs;
- Lohals: no station, sign or label for the boatyard; refusals; no charge;
- Go Ashore:
  - opening it by walking up and pressing E;
  - cost, renown, time and the notable moment;
  - outcome text, the rest period, refusing a repeat, a new event later;
  - one record only, and save/load after an event;
- departure takes the gangplank in and puts the captain aboard;
- save/load ashore;
- course view: moored upright, the rotation at the real heading, the HUD
  upright, the waves, N/E/S/W with the zoom floor, the input remap, upright
  on arrival, the setting off.

**Extended suites:**
- `test_hat` (203): the fluttering badge after the warning; one "Hat overboard!"
  message, longer-lived; the persistent badge on deck and below; the badge
  cleared by a purchase.
- `test_visual_prototype`: the harbour shows exactly the harbour's facilities.
- `test_living_world`: the 0.100b framing, checked with the course view off.
- `test_dev_guides`: the new HARBOURS guide.
- `test_branding` and `test_diagnostics`: 0.100c.

**Full suite:** see §15a.

**Restart check:** see §15a.

### 15a. Final verification

Recorded at the end of Checkpoint G:

- **Full headless suite (every suite in the runner):** **2858 checks passed, 0 failed** (34 suites, exit code 0, no script errors).
- **Restart check:** `--phase=write` then `--phase=read`: **PASS** (settings, saves, the active boat, conditions, the hat, money and stores restored).
- **Rendered runs (Xvfb, OpenGL 3):** `test_hat` and `test_harbour_life`, for
  the screenshots below. Earlier in the iteration also `test_life_aboard`.

Not run:
- a rendered run of every suite (not needed for these changes);
- any test on Windows (the Captain's trial).

## 16. Screenshot review

Everything is in `docs/screenshots/iteration12/`. I reviewed each one by eye.

| # | Requested | File |
|---|---|---|
| 1 | Hat warning | `170_hat_warning.png` |
| 2 | Hat lost, persistent indicator | `171_hat_lost_badge.png`, `123_hat_blowing_away.png` |
| 3 | Readable shortcut help over the harbour | `175_copenhagen_with_boatyard.png` (strip over the quay houses) |
| 4–7 | Gangplank on Arctic Wanderer, Wing, Clam, Frogleap | `172_gangplank_<id>.png` |
| 8 | Highlighted grocery target | `173_highlight_grocery.png` |
| 9 | Highlighted boatyard target | `174_highlight_boatyard.png` |
| 10 | Copenhagen with boatyard | `175_copenhagen_with_boatyard.png` |
| 11 | Lohals without boatyard | `176_lohals_without_boatyard.png` |
| 12 | Go Ashore panel | `177_go_ashore_event.png`, `178_go_ashore_outcome.png` |
| 13 | Sailing N, E, S, W | `179_course_north/east/south/west.png` |
| 14 | Revised interaction design against the old circles | `180_interaction_before_after.png` |

## 17. Known limitations

- **Course view:**
  - at due north or south the deck is drawn at 0.78 zoom; the longer boats can
    reach the screen's top and bottom there;
  - the hull's drop shadow turns with the boat;
  - the four heading screenshots force the view's heading, while the sails
    follow the test voyage's real course.
- **Shore and camera:**
  - the gangplank is always on the pontoon side at the boarding point; there is
    no choice of side;
  - when the captain is ashore on the Clam 40, the camera pans down far enough
    that the far side of the boat leaves the top of the screen.
- **Go Ashore:**
  - the library is small (8 generic events and 2 harbour variants);
  - once everything in a harbour has been enjoyed, events repeat without
    rewards.
- **Lohals** is the only harbour without a boatyard. Other harbours keep every
  service until the Captain decides otherwise.
- **Drawn rather than painted:** the Go Ashore icons and the gangplank, in the
  same ink-and-warm-colour style.
- **Windows** has not been tested; the rendered runs use software OpenGL under
  Xvfb.

## 18. Captain's Orders updates

`CAPTAINS_ORDERS.md` is created. It records the Iteration 12 decisions as
given:
- Iteration 12 is a revision build, and revisions are the preferred rhythm;
- cozy first;
- real object highlights instead of circles;
- the gangplank and shore access are approved;
- harbour facilities are data-driven and optional;
- Copenhagen has a boatyard; Lohals does not;
- Go Ashore is deliberately lightweight;
- hat loss must be clear without audio;
- course-aligned rendering is attempted conservatively;
- stability and save compatibility come first.

It also keeps the earlier Captain decisions found in the assignments: the name
and tagline, the fleet names and ids, the visual direction, the conventions for
iterations and versions, the working and delivery rules, and the assignments
not yet started.

**Phase Two.** The locked Phase Two distinction is not written anywhere in the
repository. The file says so and asks for its wording; I did not guess it. The
roadmap was not rewritten; only this iteration is recorded.

## 19. Git

- Branch: `claude/friendly-fermat-dey23f` on `crosenlund79/LittleCaptainsHat`.
- Checkpoints A, B–E and F were pushed as listed in §1.
- The final commit, the push result and the tag result are in the delivery
  message.

## 20. Windows acceptance items

See `WINDOWS_ACCEPTANCE_12.md`. In short:
1. hat feedback with sound off;
2. readable shortcuts;
3. walking ashore on all four boats;
4. glowing objects instead of rings;
5. Copenhagen with a boatyard and Lohals without;
6. Go Ashore, its single rewards and save/load;
7. the course view at several headings, readability at north/south, and the
   setting off;
8. a report back.
