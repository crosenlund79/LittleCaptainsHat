# Windows Acceptance — Iteration 17, Let There Be Light (0.104a)

**Status: NOT YET TESTED ON WINDOWS.** Everything below was verified on Linux
(automated tests, rendered screenshots under a software renderer, benchmarks).
Acceptance is the Captain's own trial; nothing here is claimed as accepted
until the Captain's results come back.

How to report: for each check write **PASS**, **FAIL**, **PARTIAL** or
**NOT TESTED** in the Result column, and anything worth saying in Comments
(what you saw, a screenshot name, the time of day in the game). Checks are
independent: skip any you cannot reach.

Setup: GitHub → branch `claude/friendly-fermat-dey23f` → Code → Download ZIP →
extract → open `project.godot` in Godot 4.7 → Run (F5 in the editor).
In the game: **F5 quicksaves and F9 quickloads**; the developer test panel
moved to **F10** (editor runs only).

## 1. Installation and previous saves

| ID | Check | Result | Comments |
|---|---|---|---|
| 1A | The main menu shows **Version 0.104a**. | | |
| 1B | Continue loads your newest save from 0.103a (or earlier); the boat, harbour or voyage is as you left it. | | |
| 1C | Load Game lists slots 1–3 as before; manual saves are untouched. | | |
| 1D | Settings → the new **Flashing: Reduce flashing** and **Lightning flash** controls are there; Apply keeps them after a restart. | | |

## 2. World map and geographic rendering

| ID | Check | Result | Comments |
|---|---|---|---|
| 2A | At the chart table, **Whole world**: all continents are drawn; no rectangular gaps. | | |
| 2B | Pan slowly west for several full turns of the globe, then east: Australia, New Zealand, Asia and the Americas never disappear, shift or show blocks of empty sea. | | |
| 2C | Centre on Australia / the Pacific and zoom in and out across the regional detail switch: land stays correct. | | |
| 2D | After long panning, click a harbour (e.g. Papeete): it is selected and its details show. | | |
| 2E | Plan Copenhagen → Papeete: a sea route via the Panama passage is found and drawn across the Date Line. | | |

## 3. Cabin map and voyage daydreaming

| ID | Check | Result | Comments |
|---|---|---|---|
| 3A | Each boat's cabin has a **framed world map** on the wall (try all four boats if you can). No circle; the frame itself is highlighted when near. | | |
| 3B | **E** at the frame opens the **Dreamer's Map**: no wind arrows, no weather areas, no wind switch. | | |
| 3C | Find a harbour by name; select it: name, country, story, **Visited / Not visited yet** and its services show. | | |
| 3D | **Imagine this voyage** to a distant harbour: a short reflection names the distance and up to three **real** harbours along the way; the route is drawn dashed. | | |
| 3E | Imagining changes nothing: same time, money, stores; no course planned. | | |
| 3F | **Plan it at the chart table** opens the working chart with that harbour selected. | | |
| 3G | **Back to the cabin (Esc)** returns to the cabin. | | |

## 4. Navigation station and worldwide routes

| ID | Check | Result | Comments |
|---|---|---|---|
| 4A | The chart table opens on the region around the boat (about 400 nm across), not the whole world. | | |
| 4B | Zooming out and choosing a harbour on another continent still plots a full route. | | |
| 4C | Underway: the next turn is marked with a ring on the course; the Course tab shows "Steering 000° · next turn to 000° in N nm". | | |
| 4D | Selecting a harbour shows its tier and services (groceries, boatyard, haul-out, go ashore) — no invented ones (no fuel). | | |

## 5. Wind overlay and time previews

| ID | Check | Result | Comments |
|---|---|---|---|
| 5A | Whole-world view with Wind on: no arrows, the legend says **"Zoom in to see wind details."**; the chart stays smooth. | | |
| 5B | Zoom to Denmark/southern Norway: arrows and tint appear within a moment; panning and zooming stay smooth (no hitches). | | |
| 5C | Arrows are only on water. | | |
| 5D | **◀ 30 min / Now / 30 min ▶**: steps of 30 minutes up to two hours back or ahead; labels **NOW**, **PAST MODEL SNAPSHOT**, **FORECAST**; forecasts add "Estimated conditions. Actual wind may differ." | | |
| 5E | Previewing does not move the boat or the clock; reopening the chart starts on NOW. | | |
| 5F | With the clock at 20× the chart stays smooth while the NOW snapshot follows. | | |

## 6. Day/night and lighting

| ID | Check | Result | Comments |
|---|---|---|---|
| 6A | Over a game day (20× or sleep): dawn, day, dusk and night change gradually, no jumps. | | |
| 6B | Cabin at night: warm pools of light at the saloon table, galley, chart table and berth; corners darker; everything still usable. Try all four boats. | | |
| 6C | Cabin by day: bright, lamps off, light from the hatches. | | |
| 6D | Deck at night: cool and dim, the helm glows softly, red/green/white navigation lights, the highlight on the helm still clear. | | |
| 6E | Harbour at night: quay lamps and pontoon lights; the harbour feels inhabited, not floodlit. | | |
| 6F | Long Passage at 12 h/s: the light swells gently between day and night, no strobing. | | |
| 6G | Save at night, load: it is night at once. | | |
| 6H | Soft shadows beside the furniture and under the captain and companion; the art still looks like itself. | | |

## 7. Weather sound and thunderstorms

| ID | Check | Result | Comments |
|---|---|---|---|
| 7A | Light wind: a soft breeze and water along the hull; never a harsh drone on a long passage. | | |
| 7B | Strong wind / gale: louder wind, the strong-wind loop, rain. | | |
| 7C | Thunderstorm (F10 developer tools can create one): lightning brightens the scene briefly, thunder follows — sooner and sharper when near, later and lower when far. | | |
| 7D | Below deck the outside sounds muffled (wind, rain, thunder); back on deck they are clear again. | | |
| 7E | The cabin brightens a little with lightning; it feels sheltered. | | |
| 7F | Reduce flashing on: one soft glow per strike. Lightning flash 0 %: no flash, thunder still heard. | | |
| 7G | On deck, wind streaks drift with the wind; rain falls on deck in rain. | | |

## 8. Boat orientation and deck graphics

| ID | Check | Result | Comments |
|---|---|---|---|
| 8A | Underway, standing on deck, the autopilot reaches a waypoint: the boat turns to its new heading (eight directions). | | |
| 8B | Same with the captain at the bow and at the stern; after going below and coming back up. | | |
| 8C | Walking under the boom/sail: the sail is above the captain and turns see-through while you are under it. | | |
| 8D | In harbour the white fenders hang over the starboard side; underway they are gone (stowed); arriving, they are back. | | |

## 9. Cockpit panel and chartplotter

| ID | Check | Result | Comments |
|---|---|---|---|
| 9A | Underway, the **Sailing** panel on the right: speed, heading, wind now, next leg (forecast, estimate), next turn (time, distance, new course), distance and ETA. | | |
| 9B | The values agree with the route panel and the chart. | | |
| 9C | On the last leg it says "No more turns: <harbour> ahead". | | |
| 9D | The – / + button collapses and expands it. It does not cover the Long Passage panel or the weather warning. | | |
| 9E | When the autopilot changes course by more than 5°, the heading briefly highlights (gently with Reduce flashing). | | |
| 9F | **P** on deck shows the **chartplotter** (bottom left): coast, the course, the next-turn ring, the boat and wind; + / – change range; not shown in the cabin. | | |

## 10. Action wheel

| ID | Check | Result | Comments |
|---|---|---|---|
| 10A | The help strip at the bottom shows **Q actions**. | | |
| 10B | **Q** at the helm: chartplotter, sailing details, anchor, chart, go below, Captain's Log. | | |
| 10C | **Q** in the cabin: sleep, world map, chart table, provisions, go on deck, Captain's Log. | | |
| 10D | A/D or arrows choose, E/Enter uses, Q/Esc closes; the mouse works; nothing under the wheel reacts. | | |

## 11. Save/load and F5/F9

| ID | Check | Result | Comments |
|---|---|---|---|
| 11A | Save underway on deck near the bow, load: you are aboard where you stood. | | |
| 11B | Save in the cabin underway, load: in the cabin. | | |
| 11C | Save in rough weather, load several times: the same weather each time (no reroll). | | |
| 11D | **F5** aboard: "Quicksaved"; manual slots unchanged. Pressing twice quickly saves once. | | |
| 11E | Play on, **F9**: it asks, then restores the quicksave exactly. | | |
| 11F | F5 with a menu open: refused with a short message. | | |
| 11G | Quit the game completely, start again, load an underway save: aboard, same place, sails on normally. | | |

## 12. Harbours and docking

| ID | Check | Result | Comments |
|---|---|---|---|
| 12A | Captain's Log → Harbours: grouped by country, each with "N of M visited"; countries open and close. | | |
| 12B | All / Visited / Not visited filters work; your earlier visits are all there. | | |
| 12C | Arriving in a harbour (awake): the deck shows, the captain at the helm, the harbour glides alongside with the engine; any key skips it; then you can walk. | | |
| 12D | Sleeping through an arrival: you wake in the cabin as before. | | |
| 12E | An international harbour (e.g. Papeete) and a Danish one both work as before. | | |

## 13. Long Passage and regression

| ID | Check | Result | Comments |
|---|---|---|---|
| 13A | Long Passage 1, 4 and 12 h/s work and stop by themselves as before. | | |
| 13B | Fishing, cooking, anchoring, boat care, renown, the log, companions, morning coffee and Go Ashore still work. | | |

## 14. Performance and stability

| ID | Check | Result | Comments |
|---|---|---|---|
| 14A | Chart with Wind on at regional zoom: smooth on your machine (note the frame rate if you can). | | |
| 14B | Opening the chart: about how long? | | |
| 14C | No crash or freeze in an hour of play. | | |

## 15. Final verdict

| ID | Check | Result | Comments |
|---|---|---|---|
| 15A | Overall: accept Iteration 17? | | |
