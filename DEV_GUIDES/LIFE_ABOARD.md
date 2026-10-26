# Life aboard: fishing, the galley and the anchor

Iteration 13, "The Catch & The Cove". How to tune the fish, the lures, the
dishes and the anchorage rules, and where each piece lives. Everything here
is a simplified gameplay model, not a claim of scientific or nautical
accuracy.

## 1. The stations

No per-boat setup is needed. `BoatArea` (`src/boat/boat_area.gd`, section
"Aboard gear") places four drawn objects from each boat's own layout:

| Object | Where | Drawing | Panel |
|---|---|---|---|
| Fishing rod | deck, port rail near the stern, clear of the helm | `src/aboard/rod_holder.gd` | `src/ui/fishing_menu.gd` |
| Windlass | deck, centreline of the foredeck | `src/aboard/windlass.gd` | `src/ui/anchor_menu.gd` |
| Galley stove | cabin, beside the provisions station, clear of the companion's resting spots | `src/aboard/galley_stove.gd` | `src/ui/cooking_menu.gd` |
| Trophy board | cabin, on the hat hook's wall, 140 units or more from it, clear of the other stations and the companion's resting spots | `src/aboard/trophy_board.gd` | `src/ui/trophy_menu.gd` |

Each object carries a `HighlightProvider`, so the object itself glows when
its station has the focus (no circles). The placement rules are constants in
`BoatArea` (`ROD_STATION_OFFSET`, `ROD_HELM_CLEARANCE`, `STOVE_OFFSETS`,
`TROPHY_OFFSETS` and their clearances): the stove and the trophy board take
the first offset that keeps clear of the companion's resting spots and the
other stations. The trophy board, like the companion, has focus priority −1,
so it never takes the E key from a nearby station. The
tests walk to every station on every boat.

## 2. Fish and lures

All in `data/fishing/fishing.json`:

- `bite_chance_per_check` and `check_interval_s`: one bite check every five
  game minutes with the line out, on a fixed grid (the same moment always
  gives the same bite, whatever the time speed);
- `coastal_nm`: fish marked `"coastal": true` bite only this close to land;
- `max_trolling_kn`: trolling faster than this gets no bites (a warning says
  so once);
- `lures`: id, name, price (grocery store) and a line of text;
- `rarities`: the weight of each rarity in the draw and its rank (trophy
  score);
- `species`: id, name, rarity, `regions` (the chart's region names, see
  `data/navigation/ports/`), `kg` range, `price_per_kg`, `strength` (the
  fight), and multipliers per lure (`lures`) and per way of fishing
  (`modes`: `stationary`, `trolling`).

A position's sea area is the region of the nearest harbour
(`FishingCatalog.region_at`). To add a species, add an entry; to make a lure
better for a fish, raise its multiplier (keep them between about 0.5 and
1.5, so lures differ modestly).

Landing a catch (Iteration 18; the I013 tension bar is gone) is the reel
dial, `src/fishing/reel_timing.gd`: `SPEED_DEG` (the needle's one constant
speed), `LINE_CONTROL` (misses allowed), `PERFECT_SHARE` (the Perfect zone in
the arc), `DEBOUNCE` and `IDLE_SECONDS`. The checks and arc width per rarity
are `FishingCatalog.REEL` (and `JUNK_REEL`); the Perfect weight nudge is
`PERFECT_NUDGE`; the grades are `GRADE_FROM` (share of the species' weight
range). `test_fishing2` simulates a careful and a sloppy captain over many
catches and checks the landing rates stay fair: re-run it after tuning.

## 3. Trophies and milestones

The trophy board keeps the five highest scores:
`score = 25 × rarity rank + 50 × size within the species` (0 for the
smallest, 1 for the biggest), plus 10 for a new species or a personal best
at the time (`FishingCatalog.score`, `GameSession.finish_fight`).

Milestones pay renown once each, through the existing ObjectiveProgress
ledger, and appear among the Captain's Log notable moments
(`GameSession.get_aboard_moments`):

| Milestone | Renown |
|---|---|
| First fish | 3 |
| First of each species | 2 |
| An exceptional fish (top fifth of its size range), per species | 4 |
| First meal cooked | 2 |
| First supper from your own catch | 3 |
| Caught, anchored and cooked: "A quiet evening at anchor. Fresh fish for supper." | 5 |
| First anchorage (holding fair or better) | 3 |
| A night at anchor (8 h without dragging) | 3 |
| Stopping the anchor dragging | 4 |

Personal bests are noted in the ledger without renown.

## 4. Dishes

`src/galley/recipes.gd` lists the dishes: fish taken from the cool box (the
oldest first), groceries in days of food, food gained per kg of fish (at most
`MAX_FISH_DAYS` per dish), cooking minutes and hours of "well fed". Well fed
makes the food stores last longer (`GameSession.WELL_FED_FOOD_FACTOR`, 0.75
of the usual use); there is no hunger.

The stove rule is one line in `GameSession.cooking_refusal`: in harbour and
at a holding anchor always; underway only below `CALM_COOKING_WIND_KN` (18
kn) and without a weather hazard. A refusal changes nothing.

## 5. The anchorage model

`src/anchor/anchor_site.gd`. The chart has no depth soundings or seabed
data, so the game never invents them. It uses the chart's own land/water grid
(about one arc-minute per cell):

- anchoring is offered only in open water with land within `MAX_LAND_NM`
  (2.5 nm), and not in more than `MAX_ANCHORING_WIND_KN` (34 kn);
- shelter is the **fetch**: the open water upwind of the boat, walked in
  0.25 nm steps up to 8 nm. Up to 1.5 nm is sheltered, up to 4 nm partly
  sheltered, more is exposed. A wind shift changes it;
- the bottom is assumed to be ordinary mixed ground everywhere.

Holding compares what the anchor can hold with the wind it feels:

```
power = 16 + chain bonus (3×: 0, 5×: 6, 7×: 10) + 8 × set quality + shelter bonus (8 / 4 / 0)
wind  = max(sustained, gusts × 0.8) × exposure (0.55 / 0.8 / 1.0)
margin = power − wind:  ≥ 8 holding well · ≥ 3 fair · ≥ 0 poor · below 0 dragging
```

The anchor is checked on the same five-minute grid as the weather. Holding
that falls from well or fair to poor raises the alarm; dragging raises it
again, moves the boat `DRAG_NM_PER_CHECK` (0.04 nm) downwind per check, and
scrapes the hull a little only within 0.6 nm of land. Both wake a sleeping
captain and drop the time speed to 1×. All tunables are constants in
`AnchorSite` and `GameSession`.

## 6. Sounds

The small cues are synthesized placeholders, made by
`tools/generate_placeholder_audio.py` into `assets/audio/placeholder/`
(`fishing_cast.wav`, `fishing_bite.wav`, `fishing_reel.wav`,
`fishing_splash.wav`, `fishing_snap.wav`, `galley_sizzle.wav`,
`anchor_chain.wav`, `warning_beep.wav`) and loaded through
`src/fishing/fishing_sounds.gd`. Replace a file under the same name to
change a sound (see [AUDIO.md](AUDIO.md)). Every cue has a visible
counterpart: a notice, the HUD's aboard badges (`src/ui/aboard_badge.gd`)
or the panel itself.

## 7. Saving

`SessionState` keeps `fishing` (rod, lures, the cool box, records, trophies),
`galley` and `anchor` (save format 11; format 10 saves gain empty ones when
loaded). A bite waiting for the captain is not saved: after loading the line
is simply out. A save with the anchor down in harbour, or with a fish twice in
the cool box, is rejected as invalid.

## 8. Life at anchor and morning coffee (revision 0.102b)

**Settled at anchor.** The boat counts as settled while the anchor holds well
or fair, no alarm is sounding and the wind where she lies is under 18 kn
(`AnchorLife.SETTLED_WIND_KN`). `GameSession.is_settled_at_anchor()` says so;
`anchor_life_changed` reports the change.

**Time of day.** There is no day/night simulation: the mood uses the local
solar hour at the boat (game time is UTC; 15° of longitude make an hour):
morning 05–09, day 09–18, evening 18–22:30, night otherwise
(`src/aboard/anchor_life.gd`).

**What changes aboard while settled** (`src/aboard/anchor_ambience.gd`, added
to every boat scene):

| Phase | Tint (`AnchorLife.TINTS`) | Cabin lamp (`AnchorLife.LAMP`) |
|---|---|---|
| Morning | pale warm | off |
| Day | none (white) | off |
| Evening | warm | soft glow |
| Night | soft blue | brighter glow |

The lamp glows over the saloon and the galley stove (below deck only). The
HUD badge adds "a quiet evening", "a calm night" or "a still morning". Not
settled: the scene looks exactly as before.

**The companion** (`src/companion/ship_companion.gd`): when the boat settles it
stretches and curls up; while settled, rest turns into naps that last 2.5 times
longer, with only a stretch between them. Its resting spot still follows its
normal schedule. When the boat stops being settled it wakes.

**Quiet lines** (texts in `AnchorLife`): one when the boat has settled (20
minutes after the anchor holds), one each evening, one when petting the
companion on a settled evening or night, and one on waking at anchor after at
least three hours of sleep in the morning or day. Each is kept in the anchor
state's `moments` list, so it never repeats on the same stay or day, even after
loading; none appears while the captain sleeps. To change a line, edit the
lists in `src/aboard/anchor_life.gd`.

**Morning coffee** (`GameSession.make_coffee()`, the galley's **Make coffee**
button): ten minutes pass and a line fits the moment (at anchor in the
morning, at anchor, underway, in harbour). The stove's rule applies (always in
harbour and at a holding anchor; underway in moderate conditions), and there
must be some water aboard. The first morning coffee while settled at anchor is
a Captain's Log moment (+2 renown, once). There is no coffee stat or
inventory.

## 9. Iteration 18: keeping, sharks and junk, anchorages, the companion on deck

- **Keeping**: `FishingState.keep_min_rarity` / `keep_min_grade` and
  `wants()`; the release lines are in `FishingMenu._show_result`. Only kept
  fish become trophies, personal bests or exceptional notes
  (`GameSession.finish_fight`); `release_fish` takes a fish off the board and
  gives the species' best back (`prev_best_kg`).
- **Fast time**: `passage_posture` (stop for every bite / only for keepers)
  and `GameSession.FAST_BITE_COOLDOWN_S` (the rest after a bite in Long
  Passage or at 20×). `tests/pacing_18.tscn` counts the stops on an ocean
  passage.
- **Sharks and junk**: sharks are species with `"kind": "shark"` in
  `fishing.json` (always released); junk items are the `junk` list with
  `junk_chance`. Art: `assets/fishing/README.md`.
- **Fish art and animation**: `FishPortrait` (`BLINK_*`, `FLICK_*`, `BOB_*`);
  lists use `FishArt.thumbnail()`.
- **Sail Trim**: `src/sailing/sail_trim.gd` (best trim, factor, words);
  applied to the sailing speed only in `PropulsionController`.
- **Anchorage waypoints**: `PlannedRoute.anchorages`, `Voyage.holding_at` /
  `anchorages_done`, `Simulation.STOP_ANCHORAGE`; the rule is
  `GameSession.anchorage_spot()` (the anchoring rule: water, depth, within
  `AnchorSite.MAX_LAND_NM` of land); the question is `AnchoragePrompt`.
- **Anchor signals**: `src/boat/anchor_signals.gd` (ball, rode, buoy);
  the anchor light is the "anchor" light in `BoatLighting`.
- **The companion on deck**: `DeckCompanionSpots` computes each boat's safe
  places and walks from its lifeline and fittings (no hand-placed markers);
  when it follows is `App._update_companion_follow` (`FOLLOW_UP_SECONDS`,
  `FOLLOW_DOWN_SECONDS`, `WANDER_SECONDS`) and `GameSession.companion_may_be_on_deck()`
  (moored, or anchored under `COMPANION_DECK_MAX_WIND_KN` without rain).
  `test_companion_deck` checks every frame of every walk on all four boats.

## 10. Revision 0.105b: anchoring worldwide, the Magic Anchor, engine off

- **Where you can anchor.** `AnchorSite.evaluate()` (`src/anchor/anchor_site.gd`) works on the fine coastal raster (`CoastalGeography`, 1/120°, `data/navigation/coast/`), not on the 5 nm routing cells. A spot must be:
  - water;
  - (when planning) at least `MIN_SHORE_NM` from the shore;
  - reachable from routing water by a short checked approach.

  Depth comes from `DepthService` (`src/navigation/depth_service.gd`). In this build every depth is a deterministic **GAME ESTIMATE** (no real bathymetry is installed), shown as "about 9 m". Shelter is judged separately, from the open water upwind.
- **Normal anchor:** depth `MIN_DEPTH_M`–`NORMAL_MAX_DEPTH_M` (2.5–25 m), wind up to 34 kn. **Magic Anchor:** any depth and wind up to 55 kn. It counts as "offshore" (no shelter) beyond `COASTAL_NM` (3 nm) from land. Holding and drag use the same `AnchorSite.holding()` model for both. The Magic Anchor's Perfects add at most `AnchorState.MAGIC_BONUS_MAX_KN` (3 kn).
- **Obtaining it:** Boat care → Equipment → Magic Anchor (free prototype until the chandlery). It is stored as the progress mark `equipment:magic_anchor`.
- **The dial:** `MagicAnchorDeployment` (`src/anchor/`) wraps the shared `TimingCheck` (`src/skills/timing_check.gd`; the reel is the same component). Checks and arcs:

  | Wind | Checks | Arc |
  |---|---|---|
  | Under 17 kn | 1 | 70° |
  | 17–27 kn | 2 | 58° |
  | 28 kn and up | 3 | 48° |

  Each miss costs `MISS_MINUTES` (5). Three misses and it has not bitten: Try again or Cancel.
- **Engine:** anchoring sets the one propulsion state to sail and stops the boat. `GameSession.is_motoring()` is false at anchor, and `engine_start_refusal()` gives "Let's raise the anchor before starting the engine." An older save at anchor with the engine on is corrected on loading.
- **Overlay:** `AnchorageLayer` (`src/navigation/anchorage_layer.gd`) fills only visible tiles at close zoom. It is cached, works within a frame budget, and its colours match the waypoint rule exactly.
- **Solar panels:** decoration only. Each deck scene lists its panel rectangles (`VesselVisual.solar_panels`, drawn by `SolarPanels`).
