# Windows sea trial: Iteration 14, A Bigger World, a Better Boat (0.102a)

A practical walkthrough for the Captain, about 45 minutes: bring an Iteration
13 save into the detailed Danish waters, look after the boat in Copenhagen and
sail on. Tick what works and note what does not, ideally with a screenshot
(Windows + Shift + S).

Nothing here has been tried on Windows yet. This trial is the acceptance.

**Get the project:** open the GitHub branch `claude/friendly-fermat-dey23f`,
choose **Code → Download ZIP**, extract it, open `project.godot` in Godot 4.7
and press **Run** (F5). Keep a copy of your saves folder before you start
(main menu → Load → the folder button shows where it is).

## 1. Load an Iteration 13 save

- [ ] **Load** a game saved with 0.101a. It opens normally; the main menu shows
  **Version 0.102a**.
- [ ] If the save was at sea in Danish waters, the boat is still at sea on its
  way. If the new coastline put it on land, a notice says it was moved a short
  way to open water and the course re-planned; it is never lost.
- [ ] Your money, boats, fish, renown and the Captain's Log are unchanged.

## 2. The detailed chart

- [ ] Open the chart at the chart table in the cabin. Zoomed out over Europe,
  Denmark has a light outline that matches the rest of the chart.
- [ ] Zoom in on Denmark: the detailed coastline appears, with Zealand, Funen,
  Jutland, Langeland, Lolland, Falster, Møn, Bornholm and the small islands;
  the Øresund, the Great Belt and the Little Belt are open water.
- [ ] Island and water names appear as you zoom in (Zealand, Funen, Kattegat,
  Øresund, Great Belt, …). They never cover each other badly.
- [ ] Panning and zooming stay smooth over Denmark.
- [ ] Find the new harbours: Helsingør, Svendborg, Skagen, Rønne, Korsør,
  Ærøskøbing and others (search box works for them).

## 3. Plan a journey

- [ ] In Copenhagen, plot a course to **Svendborg**: it goes round Zealand by
  sea, never across land, and enters Svendborg by water.
- [ ] Plot **Lohals → Copenhagen** and **Middelfart → Sønderborg** (Little
  Belt): sensible routes that follow the water.
- [ ] Drag the course line to add a waypoint in the Great Belt; the course and
  distance update. A waypoint dropped on an island is refused clearly.
- [ ] Below the course, **Passage readiness** gives a short, friendly line
  (for a sound boat with full stores in calm weather: "Ready to sail.").

## 4. Copenhagen boatyard

- [ ] Walk ashore in Copenhagen to the boatyard. The panel has a **Boat
  care…** button (it names the worst level when something needs attention).
- [ ] **Boat care** shows the four areas (hull and bottom, rigging and sails,
  engine, equipment) in words and colour. After your Iteration 13 travels the
  bottom has some weed (20 days in the water) and the rig and engine a little
  wear. Nothing reads alarming for a fresh boat.
- [ ] Each service shows its **price and time**. Services not needed say so
  and cannot be bought.
- [ ] Have the **rig serviced**: the money goes down by the price shown, the
  clock moves on by the time shown, the rig reads **Good**.

## 5. The haul-out

- [ ] **Haul out…** opens the haul-out: the boat in the travel lift, weed on
  her bottom. Tick **Engine service**: the total goes up, the time stays a
  day.
- [ ] **Haul out**: she rises in the slings, the weed comes off. A day passes;
  you pay the total shown.
- [ ] **Back in the water** returns to Boat care: the bottom reads **Good**.
- [ ] The Captain's Log (**L**) has a **Boat** tab listing the haul-out and the
  service, and the Log tab lists "First haul-out" among the moments (+2
  renown, once).

## 6. Equipment

- [ ] In Boat care, scroll to **Equipment**: six items, each with what it does
  and a price for your boat. Fit the **Large cool box**: "Fitted".
- [ ] Fit one more you like (for example the **Weather receiver**). Each is
  paid once; the boat does not become faster than new.

## 7. Passage Readiness and departure

- [ ] Use the developer tests (F9) to set the condition low (for example 40 %)
  and the stores to 0.5 day, then plan a longer passage. Passage readiness says it is worth a
  second thought, in plain words (repair, stores).
- [ ] **Set sail** is still available, and the "Set sail?" question repeats the
  advice. You can go anyway.
- [ ] Put things right again (repair, groceries) and depart Copenhagen
  normally.

## 8. Lohals has no boatyard

- [ ] Sail to **Lohals** (or a small harbour such as Stege or Gilleleje). No
  boatyard sign on the quay; using the boatyard is refused with a short
  message and **costs nothing**.
- [ ] Groceries and Go Ashore work as before.

## 9. Fishing and anchoring in Danish waters

- [ ] Underway between the islands, fish from the stern: the coast counts as
  near (coastal fish).
- [ ] Anchor near the coast (for example in the lee of an island): the
  anchorage is judged from the detailed coastline, sheltered or exposed by the
  wind's direction.
- [ ] With the **Large cool box**, the cool box holds up to 10 fish.

## 10. Save and reload

- [ ] Save at sea in Danish waters, quit to the menu, load: same position,
  same course, same boat care and equipment.
- [ ] Save in harbour after the haul-out, load: the care history is still
  there.

## 11. The eight-direction view and controls

- [ ] On deck while sailing through the Belts, the boat is shown in its eight
  directions as in Iteration 13; walking with **WASD / arrows** still moves
  the captain the way you expect at every heading.
- [ ] Interactions still highlight the objects themselves; no circles.

## 12. Nothing else broke

- [ ] Elsewhere in Europe the chart and routes are as before (try Lisbon →
  Barcelona, Portsmouth → Kiel).
- [ ] The hat, weather warnings, the galley, the grocery store, changing boats
  and Go Ashore work as in Iteration 13.

**Result:** ☐ Accepted  ☐ Accepted with notes  ☐ Needs a revision

Notes:
