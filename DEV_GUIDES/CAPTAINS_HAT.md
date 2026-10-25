# The captain's hat

The captain's hat (Visual Identity V01) is one small personal object: the
player owns exactly one hat at a time. It hangs on a hook in the cabin, is worn,
is carried under the arm, or has blown away. This guide covers its artwork, its
balancing and where it is placed aboard.

## Artwork: three replaceable slots

| Slot | When it is drawn | File |
|---|---|---|
| stored | on the cabin's hook while the hat hangs there | `hat_stored.png` |
| worn | on the player token, turned the way the player faces | `hat_worn.png` |
| blowing | the short effect on deck when the wind takes it | `hat_blowing.png` |

Each slot is resolved in this order (see `src/hat/hat_art.gd`):

1. the texture assigned in `data/hat/hat_art.tres` (`stored_texture`,
   `worn_texture`, `blowing_texture`);
2. a file named as in the table in `assets/hat/`;
3. the procedural drawing in `src/hat/hat_drawing.gd`.

So dropping a PNG with the right name into `assets/hat/` replaces the drawing,
and removing it brings the drawing back. Nothing else changes: the art never
affects the hat's state, the player's collision or any interaction.

How to draw them:

- Draw the hat **from above** (the game's top-down view). For *worn* and
  *blowing*, point the **peak to the right** (+x); the game rotates it.
- Use a transparent background (PNG with alpha). See [SPRITES.md](SPRITES.md)
  for import settings.
- The image is scaled so its larger side is the slot's size in
  `data/hat/hat_art.tres`: `stored_size` 46, `worn_size` 36 (the player token is
  42 across), `blowing_size` 40. Change the sizes there, not in code.
- `procedural_only = true` in the resource forces the drawings, to compare.

## Where it hangs aboard

Every cabin has two nodes for the hat:

- `Layout/HatSpot` (a `Marker2D`): where the hook and the stored hat are drawn.
  `BoatArea` creates the `HatHook` art node there.
- `Layout/Stations/Hat` (an `Interactable`, id `hat`, circle radius 24): the
  interaction. Its prompt follows the hat: *Put on captain's hat*, *Hang up
  captain's hat*, *Look at the empty hat hook*.

| Boat | Hook | Station |
|---|---|---|
| Starling 33 | above the port storage locker, forward (200, −100) | (200, −52) |
| Halcyon 40 | above the owner's sofa (230, −292) | (230, −244) |
| Petrel 36 | on the port side, forward of the settee (168, −96) | (168, −70) |

The Halcyon and Petrel cabins come from
`tools/vessels/build_multihull_scenes.py`; the hat nodes are in its cabin
functions too, so a regenerated cabin keeps them. The tests check that every
companion resting spot is at least 110 px from the hat, that petting the cat is
not affected anywhere, and that the station can be walked to.

## Controls

- **E** at the hook: put the hat on, or hang it up.
- **H** anywhere aboard: take a worn hat off (carried under the arm, safe from
  the wind) or put a carried hat back on. H never uses F9 or any other key
  already taken.

## Wind and balancing

All numbers are in `data/hat/hat_config.json` (read by `src/hat/hat_config.gd`).

- The wind is the one weather model's sample at the boat (`WeatherModel`):
  no other wind is calculated.
- The hat is checked once per `check_interval_s` (60 game seconds) on an
  absolute grid of the game clock, and only while it is **worn on deck**.
  Sleeping and remote work count as below deck.
- The *effective* wind is the sustained wind, or the gusts less
  `gust_allowance_kn` (10) if that is more.
- `bands` give the strain per game minute: from 25 kn 0.25, from 35 kn 1.0,
  from 45 kn 2.0. `gust_bands` add 0.5 for gusts from 45 kn and 4.0 from 55 kn (a
  squall gust can snatch a hat).
  Below 25 kn there is no risk at all.
- In harbour the strain is multiplied by `harbour_factor` (0.5).
- The first minute with any risk only **warns** ("Better hold onto your
  hat!") and drops time to 1×. The warning is not repeated until the hat has
  fully recovered and `warning_repeat_min` (30) game minutes have passed.
- Strain recovers by `recovery_per_min` (2) per minute when the hat is not at
  risk.
- Each hat blows away when its strain reaches its own threshold, between
  `threshold_min` (20) and `threshold_max` (40), fixed per hat from the game's
  seed. There is no frame-based dice roll: the outcome is the same at 1×, 5×,
  20×, while sleeping, and across save and load.

What that means at sea on deck with the hat on:

| Wind (sustained / gusts) | Strain per minute | The hat lasts about |
|---|---|---|
| 24 / 30 kn | 0 | for ever |
| 30 / 37 kn | 0.25 | 80–160 minutes |
| 40 / 50 kn (gale) | 1.5 | 13–27 minutes |
| any wind with gusts of 55 kn or more (squalls, storm) | 2.0 + 4.0 = 6.0 | 3.5–7 minutes |

Add the warning minute to each. One game minute is one real second at 1×,
and the warning drops time to 1×. European gales rarely bring gusts of 55 kn
or more, so a hat that blows away within minutes is a rare event (and the
secret achievement *The Last Straw* depends on it).

In harbour it lasts twice as long. Losing a hat costs nothing else: no damage,
no money.

## Replacement hats

The harbour **grocery store** sells a replacement for `price_eur` (15) in its
own row, only while moored and only when the hat is lost
(`GameSession.buy_hat()`). The new hat is handed over carried: press H to put
it on. The provisions price and figures are not touched.

## Secret achievements

Seven hidden achievements are ordinary objectives in
`data/progression/objectives.json` with `"secret": true` (and a `"tone"`:
`proud` or `comic`). They pay modest renown through the existing
`ObjectiveProgress`, exactly once, and the Captain's Log shows nothing about
them (title, condition or reward) until they are found; then it shows the
title, description, date and renown. Finding one shows a notification and
plays `assets/audio/placeholder/achievement_chime.wav`.

| Achievement | Type | Condition | Renown |
|---|---|---|---|
| Captain No-Hat | `hat_lost_count` 1 | the first hat lost | 10 |
| Hat Trick | `hat_lost_count` 3 | three hats lost | 15 |
| Hold Onto Your Hat | `hat_weather_voyage` hazard 2 | arrive after a voyage on which the hat was worn on deck in dangerous weather, without losing it | 30 |
| The Hat Tax | `hat_spent` 100 | €100 spent on replacement hats | 10 |
| The Last Straw | `hat_lost_soon` 5 | a replacement lost within 5 game minutes of buying it | 15 |
| A Captain of Distinction | `original_hat_voyages` 10 | ten voyages completed and the original hat never lost | 40 |
| The Sea Wears a Hat Now | `hat_lost_offshore` 20 | a hat lost at sea with no land within 20 nm | 15 |

- Hat events are evaluated in `GameSession` when the hat is lost or bought
  (`ObjectiveCatalog.evaluate_hat_event()`); the voyage ones when a voyage is
  logged, with the hat passed to `ObjectiveCatalog.evaluate()`.
- "No land within 20 nm" is measured on the chart's own navigability raster
  (`HatStory.open_water_nm()`): the distance to the nearest cell that touches
  land, small islands included; cells off the chart count as land.
- Losing hats never pays: all the comic ones together give 65 renown (€130 when
  published), less than the hats they need.
- To add one: an entry with a hat type, `"secret": true`, a positive
  `reward`; secret objectives cannot be `repeatable`.

## State and saving

`HatState` (`src/core/hat_state.gd`) is the saved `hat` section (save version
10): status, strain, the warning, the last checked time, the hat's serial
number, counts, money spent, the purchase time, the current voyage's worst
weather met while wearing it, and a short history for the Captain's Log. It
belongs to the player: switching boats, rescue and loading never copy, reset
or restore it.
