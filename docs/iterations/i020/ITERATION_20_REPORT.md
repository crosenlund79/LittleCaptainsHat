# I020 — A Boat of Your Own (0.107a)

Third watch of *Operation Three Watches*. Starting point: the I019 build,
`ba0cacf` (checkpoint B, `backup/post-i019-pre-i020`). The final I020
commit is the one that adds this report (see the git log).

**Windows acceptance is pending.** Verified on Linux (Godot 4.7.2,
headless suites, rendered runs under Xvfb with software OpenGL).

COZY FIRST, LESS IS MORE: three small trades and six small things for the
cabin, all on the systems the game already has.

## What the Captain gets

### Harbour trades, where the harbour's data says

Which harbours have which trade follows each harbour's existing facility
data, so every harbour (Danish and international) is predictable:

| Trade | Where | Reached from |
|---|---|---|
| **Fishmonger** | wherever there is a grocery store (all 223 harbours today) | the grocery store: "To the fishmonger (€…)…" |
| **Chandlery** | wherever there is a boatyard (202 harbours) | the boatyard: "Chandlery…" |
| **Sailmaker** | wherever there is a boatyard | the boatyard: "Sailmaker…" |

They are listed in the chart's and the Dreamer's Map harbour previews
("… · Chandlery (gear and cabin things) · Sailmaker (sail care, new
sailcloth) · Fishmonger (sells your catch)"). Selling the catch is never far
away; nothing essential moved further away.

### The fishmonger

The one place a catch is sold (the grocery store's old "Sell the catch"
now leads here; the fishing panel's own Sell button uses the same
transaction). Each fish in the cool box with its price (the fishing
catalogue's price by weight, unchanged), sold one by one or all at once.
Paid at once, exactly once; the fish leaves the cool box. Trophies and the
species records stay in the Captain's Log. A little character: the person
at the counter has a name, the same at each harbour every visit.

### The chandlery

A short list, each with its name, what it does and its price:

- **For the boat**: the weather receiver, the large cool box and the
  gimballed stove: the boat-care catalogue's own upgrades, fitted the same
  way, once per boat. (The yard still fits the heavy anchor, the stainless
  rigging and, with a haul-out, the hard coating.)
- **The Magic Anchor**, once, for every boat: €450. It was a free prototype
  at the boatyard "until the chandlery"; a Magic Anchor already aboard in an
  older save stays aboard.
- **Fishing tackle**: the four lures (also still at the grocery store).
- **For the cabin**: six small things (below).

### The sailmaker

Two things, kept apart and labelled:

- **Care (the boat sails better)**: the rigging and sail service: the
  boat-care service itself, with the same wear, price and time as at the
  yard. No second model of sail wear.
- **Sailcloth (a look only: no change in speed)**: classic cream (the
  boat's own), **tanbark** (the red-brown of the old working boats) or
  **harbour blue**, €10 per foot of boat (€260 for the Arctic Wanderer
  26, €400 for the Clam 40). Each boat keeps its own; a cloth already cut
  for a boat is bent on again for free. The deck shows it at once.

### Make it home

Six things for the cabin, bought once at the chandlery (they are the
Captain's, for any boat): a braided rug (€40), a pot of herbs (€25), a
framed old chart of the Kattegat (€60), a brass oil lamp (€80), a shelf of
sea stories (€45) and signal-flag bunting (€30). In the cabin, the action
wheel's **"Make it home"** shows each or puts it away; the panel stands to
the side without dimming, so the cabin itself is the preview.

- **Each boat its own**: the choice is kept per boat; changing boats never
  touches another boat's cabin.
- **Never in the way**: the things are drawn in the cabin's own manner with
  no collision and no station. Where each goes is found from the cabin: wall
  things along the hull sides, the rug on open floor clear of all
  furniture, all kept clear of every station (galley, chart table, berths,
  coffee spots, the trophy board), the companion's resting spots and the
  fitted gear. Verified on all four boats (6 of 6 placed, none near a
  station).

## Economy and balance

- Nothing is required: the boat sails, fishes and is cared for exactly as
  before without any of it. No upkeep, no running costs.
- Prices sit with the existing ones (provisions, care, upgrades): cabin
  things €25–80, sailcloth €10/ft, the Magic Anchor €450. Fish prices are
  unchanged. No new income.
- Transactions are whole or nothing: each checks the trade and the funds
  first and changes nothing when refused; funds never go below zero, unique
  things are never sold twice (tested with €10 in the purse).
- The only behaviour change to an existing thing: the Magic Anchor now has
  a price, at the chandlery (its prototype note said so).

## Save format

Still **12**. One optional record, `home`: the cabin things owned, and per
boat the things shown, its sailcloth and the cloths cut for it (stable ids,
no scene paths). An older save loads with plain cabins and cream sails;
unknown ids are dropped quietly (tested), never a refused save.

## Localization

Everything new in English and Dansk (skibshandel, sejlmager, fiskehandler,
"Gør det hjemligt", barket sejldug…), glossary updated
(`docs/technical/LOCALIZATION.md`). Catalogue complete: 2,283 messages.
Species names and rarities are now translated where they are shown. The
trade panels fit the screen in Danish (tested).

## Tests

- New `tests/suites/test_boat_of_your_own.gd` (51 checks): availability
  from harbour data (Copenhagen, Ærøskøbing without a yard, all harbours),
  previews, the fishmonger (one and all, paid once, no double sale, trophies
  and records kept, a load from before the sale, nothing at sea), the
  chandlery (the boat-care upgrade itself, no duplicates, refused whole with
  too little money, none without a yard), the sailmaker (cloth paid once,
  free to change back, per boat, the deck shows it, the same rig service),
  the cabins on all four boats (placed, clear of stations, no collision,
  stations intact, per-boat choices), saves (round trip, older save,
  unknown ids) and Danish.
- Changed: `test_boat_care` (the yard's equipment test now fits the heavy
  anchor; the cool box is the chandlery's), `test_magic_anchor` (bought at
  the chandlery, charged once, never twice).
- Full regression (headless, all suites): **4,672 passed, 2 failed**; the two
  are wall-clock-timing checks (a fish's blink offset, a companion's walk
  within 20 s) in suites that run before the new one and pass when re-run
  (108 of 108). Recorded as timing-sensitive, not I020 defects.

## Performance

Rendered `--turbo` probe, I020 (`docs/benchmarks/i020_after1_rendered.json`)
against the I019 build **re-run in the same session** from a clean checkout of
checkpoint B (`docs/benchmarks/i019_rerun_rendered.json`). The re-run was
needed: against I019's earlier run, every scenario (including screens I020
does not touch, such as the chart and the Dream World) looked 3–10 % slower,
and the I019 re-run showed the same shift, so it was the machine, not the
code.

| Scenario (median ms) | I019 (re-run) | I020 |
|---|---|---|
| Sailing 1× | 36.4 | 34.9 |
| Sailing with debris | 41.2 | 41.1 |
| Cabin walk (day) | 64.1 | 70.1 |
| Harbour walk (day) | 65.0 | 56.0 |
| Chart open, idle | 46.6 | 47.9 |
| Dream World map | 102.8 | 99.1 |
| Fishing | 66.2 | 61.4 |
| Long Passage 12 h/s | 64.0 | 61.9 |
| Sleep 8 h across midnight | 83.3 | 81.1 |
| Sleep 8 h underway (3 runs) | 25, 93, 89 | 93, 101, 47 |

Equal within the run-to-run noise of software rendering (the largest
differences, cabin +6 ms and harbour −9 ms, go both ways; a new game's
cabin has no cabin things, and nothing new runs per frame). Long-session
growth stays flat (nodes, objects, connections, tweens, audio players over
20 rounds). The new panels are built on opening and freed on closing; the
cabin things are drawn once and redrawn only when changed.

## Screenshots

`i020_cabin_<boat>.png` (all four boats with every thing shown),
`i020_make_it_home.png`, `i020_chandlery.png`, `i020_sailmaker_dansk.png`,
`i020_fishmonger.png`, `i020_tanbark_sails.png`.

## Known limitations

- The trades have no pontoon stations or signs of their own: they are
  reached through the grocery store and the boatyard.
- The cabin things are placed automatically (no free placement); on the
  Wing 33 the braided rug lies near the cabin's own oval rug.
- Sailcloth tints sail sprites by multiplication: on the illustrated sails
  the darker cloths read a little darker than on the drawn ones.
- The boatyard's vessel choice is unchanged (no new ownership economy).
- Windows not verified.
