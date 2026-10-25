# Boat care: wear, boatyards, haul-outs, equipment and Passage Readiness

Iteration 14. How the boat wears, what the boatyard does and charges, how to
change or add equipment, and how Passage Readiness decides what to say.

## 1. The care areas

Boat care extends the boat's existing condition (the hull percentage that
weather damages and that the rescue resets); it does not replace it. Each boat
has its own care record (`src/core/boat_care_state.gd`, saved per boat):

| Area | What wears it | Levels (cosmetic / recommended / needs attention) | Effect |
|---|---|---|---|
| Hull and bottom | the hull: weather damage (the existing condition); the bottom: weed, 1 point a day in the water since the last haul-out | bottom 25 / 50 / 100 days; hull by condition band | from 30 days of growth, up to 6 % less speed (sail and engine) over the next 90 days |
| Rigging and sails | 0.05 wear per nautical mile under sail, ×2 from 20 kn of wind, ×3 from 28 kn; plus 0.6 per % of weather damage | 15 / 35 / 65 wear | from 40 wear, up to 5 % less sailing speed; from 50 wear, up to 30 % more weather damage |
| Engine | its hours under power | 50 / 80 / 160 hours | from 120 hours, up to 10 % less engine speed |
| Equipment | nothing: it is what is fitted | — | see section 3 |

So a typical week of coastal sailing adds a few points of rig wear and a few
engine hours: wear is slow and predictable (the same passage wears the same).
The numbers are constants at the top of `src/boat_care/boat_care.gd`.

The overview (`src/ui/boat_care_view.gd`) shows each area's level in words and
colour with a one-line description and what to do about it. It appears in the
Captain's Log (Boat tab, with the boatyard history) and in the Boat care panel.
When an area reaches "service recommended" underway, a single notice says so.

## 2. Boatyards and the haul-out

Boat care is opened from the boatyard panel (**Boat care…**), only in a
harbour with a boatyard (see [HARBOURS.md](HARBOURS.md) for which harbours have
one). It shows only what that yard does; a service that is not needed or not
affordable says why instead of being sold. Prices are for a 30 ft boat and
scale with length (`size factor = length / 30 ft`):

| Service | Where | Price | Time |
|---|---|---|---|
| Repair hull and structure | any boatyard | €3 per missing % × size | 1 h + 3 min per missing % |
| Rigging and sail service | any boatyard | (€70 + €1.50 per wear point) × size | 2 h |
| Engine service | any boatyard | €90 × size | 3 h |
| Haul out | yards that can haul out | €10 per foot | a day |
| Fitting equipment | any boatyard (the coating: a haul-out yard) | its price | 4 h |

The time passes ashore (the hat is safe; food and water are used as usual).
Each job is one transaction (`GameSession.perform_service`,
`GameSession.haul_out`, `GameSession.install_upgrade`): it is paid, done and
written to the boat's care history together, or refused as a whole.

**The haul-out** (`src/ui/haul_out_panel.gd`, drawn by
`src/ui/haul_out_scene.gd`): the boat is lifted in the travel lift's slings, the
weed comes off, a day passes. It cleans the bottom and repairs the hull. While
she is out the yard can also service the engine and the rig and apply the hard
antifouling coating; these add their price, not time. The first haul-out is a
Captain's Log moment (+2 renown).

## 3. Equipment

The catalogue is `data/boat/equipment.json`: an id, a name, a price per foot of
boat length, the yard it needs (`boatyard` or `haul_out`) and the text shown.
Each upgrade has one real effect, read where it applies:

| Upgrade | Effect | Read in |
|---|---|---|
| Heavier anchor and chain | +5 kn of holding | `GameSession.get_anchor_holding_bonus_kn()` → `AnchorSite.holding()` |
| Weather receiver | route weather warnings 10 h ahead instead of 6 | `GameSession.get_warning_horizon_hours()` → `Simulation._route_warning()` |
| Gimballed stove | cooking underway in up to 26 kn instead of 18 | `GameSession.get_calm_cooking_wind_kn()` |
| Large cool box | room for 10 fish instead of 6 | `GameSession.get_cool_box_capacity()` |
| New stainless rigging | rig wear ×0.5, weather damage ×0.9 | `BoatCare.rig_wear_for()`, `BoatCare.effects()` |
| Hard antifouling coating | weed grows at 0.4× | `BoatCare.fouling()` |

No upgrade makes a boat faster than new: wear can only take speed away, and
care gives it back. There is no tech tree; each item is bought once per boat.

**To change a price or text**, edit the JSON. **To add an upgrade**, add an
entry, then read its effect where it belongs through a small getter like the
ones above (`GameSession.has_upgrade("<id>")`). Keep the catalogue between four
and eight items; `tests/suites/test_boat_care.gd` checks the count.

## 4. Passage Readiness

`src/boat_care/passage_readiness.gd` looks at a planned course before setting
out. It is advice only: it never disables Set sail. It is shown in the chart's
Course tab (for a course in harbour) and in the "Set sail?" question.

| Finding | OK | Note | Worth a second thought |
|---|---|---|---|
| Hull | sound | worn, short passage | worn and overnight; damaged |
| Care areas | — | bottom, rig or engine due a service | — |
| Food and water | 2+ days to spare | less than 2 days to spare | less than 1 day to spare |
| Weather on the route | nothing rough foreseen | caution level (fresh to strong) | dangerous or severe |
| Length | — | overnight (14 h+), several days (48 h+) | — |
| The boat | — | 28 ft or less, with rough weather or several days ahead | — |

The passage time is the same estimate as the chart's ETA, and the weather is
the same forecast as the route warnings (up to 24 hours ahead). The wording is
in the script; keep it friendly and never forbidding.

## 5. Saves

Save format 12 adds `boat_care` (per boat). A format 11 save (Iteration 13)
is migrated on load: its boat gets a care record with the hull last cleaned 20
days earlier and rig wear and engine hours from the miles in the Captain's Log
(0.02 wear and 0.03 hours per mile, at most 30 and 60), with no equipment
(`SaveManager._migrate_11_to_12`). Other boats get a fresh record when first
boarded.
