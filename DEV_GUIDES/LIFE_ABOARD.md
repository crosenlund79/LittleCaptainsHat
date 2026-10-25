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

The fight (`src/fishing/fish_fight.gd`) is tuned by its constants: the red
warning at `WARN`, the top of the bar at `TOP`, and `BREAK_SECONDS` at the
top before the line parts. The tests check that easing off at the red
warning lands every species, smallest to biggest.

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

