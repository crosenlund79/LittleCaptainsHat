# Windows Acceptance — Iteration 18, The Joy of the Journey (0.105a)

**Status: NOT YET TESTED ON WINDOWS.** Everything in this iteration was
verified on Linux only (automated tests, rendered screenshots under a software
renderer, benchmarks, a two-process restart test). Nothing here is claimed as
accepted until the Captain's and the Skipper's results come back.

How to report: for each check write **PASS**, **FAIL**, **PARTIAL** or
**NOT TESTED** in the Result column, and anything worth saying under
Observations (what you saw, a screenshot name, the game time). Checks are
independent: skip any you cannot reach.

Setup: GitHub → branch `claude/friendly-fermat-dey23f` → Code → Download ZIP →
extract → open `project.godot` in Godot 4.7 → Run (F5 in the editor).

Keys used below: **E** interact (also the reel press, with Space/Enter or a
click on the dial) · **Q** action wheel · **R** rod (reel in when a fish is
on) · **T** Sail Trim · **M** mark/unmark the selected chart
waypoint as an anchorage · **F5** quicksave · **F9** quickload · **F10**
developer test panel (editor runs only).

## 1. Launch and save migration

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 1A | Start the game and look at the main menu. | It shows **Version 0.105a**. | | |
| 1B | **Continue** your newest 0.104a save. | It loads as you left it (boat, harbour or voyage); no error, no request to re-plot the course. | | |
| 1C | Open the rod (R) and the trophy board in that old save. | Your old catches and trophies are there; catch preferences start at "keep everything". | | |
| 1D | Load Game. | Slots 1–3 listed as before; manual saves untouched. | | |
| 1E | Settings. | A **Reduce motion** option is there; Apply keeps it after a restart. | | |

## 2. World-route panning

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 2A | Plan a long route (e.g. Copenhagen → Papeete or → Sydney) and apply it. | The route is drawn. | | |
| 2B | Pan the chart slowly west for several full turns of the globe, then east. | The route **never disappears** and is never shifted; it is drawn in every copy of the world that is on screen. | | |
| 2C | After panning, click on the route line to add a waypoint. | The click lands on the route where you clicked. | | |

## 3. Fishing reel-in

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 3A | Cast a line (rod, R or the action wheel) and wait for a bite. | The badge says **"Fish on! Reel in"** with an R key. | | |
| 3B | Press **R** (from deck or cabin). | The reel opens: a **circular dial** with a moving needle and a highlighted arc; the fish's portrait is shown. | | |
| 3C | Press **E**, **Space/Enter** or click the dial when the needle is inside the arc. | A success; common fish need 1, uncommon 2, rare 3, very rare 4 successes. A press in the middle of the arc counts as **perfect**. | | |
| 3D | Press well outside the arc three times. | The line breaks (or the fish gets away) with a clear message; nothing is landed. | | |
| 3E | Let a fish go with **Let go**. | The catch swims off; nothing landed. | | |
| 3F | Hold the key down, or mash it. | Held keys and very fast repeats do not count as extra presses. | | |

## 4. Fish art and animation

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 4A | Catch (or view on the trophy board) several different fish: cod, mackerel, garfish, a flatfish. | Each species is drawn as its own illustrated fish, recognisable by shape and colour. | | |
| 4B | Watch a fish on the reel and on the result screen for ~10 s. | It **blinks** now and then and **flicks its tail**; gentle, not frantic. | | |
| 4C | Turn on Settings → Reduce motion, then look again. | The tail and body stay still (no flick, no bob); the fish still blinks now and then. | | |
| 4D | Catch junk (old boot, tangled rope, rusty tin; rare). | Its own drawing, a gentle joke, not a fish. | | |

## 5. Catch preferences

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 5A | Open the rod and set **Keep** to e.g. "Uncommon or better" and grade "Silver or better". | The choices are saved and shown in words. | | |
| 5B | Land a fish below the preference. | It is released with a friendly line saying why; it is not in the hold and not a trophy. | | |
| 5C | Land a fish above it. | Its weight and **grade** (Bronze/Silver/Gold where it applies) are shown; it goes to the cool box and the trophy board. | | |
| 5D | Release a kept fish by hand from the result screen. | It is gone from the hold and from the trophies. | | |

## 6. Sharks and junk

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 6A | Fish off the Atlantic islands, Iberia/Biscay (blue shark) or the Caribbean/Pacific coasts (blacktip). | Occasionally a shark: drawn as a shark, landed with the dial, **always released**, counted on the trophy board. | | |
| 6B | Fish for a while anywhere. | Now and then junk instead of a fish (about 6%), never kept as a trophy. | | |

## 7. Sail Trim

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 7A | Underway under sail, press **T**. | The Sail Trim panel opens: a slider from **Eased** to **Sheeted in**, a sketch with a faint mark where the sail draws best, a word for how it is ("Too loose", "Well trimmed", …) and **Leave it to the crew**. | | |
| 7B | Move the slider (A/D or arrows) to the best mark, then far from it. | Speed rises a little at best (a few percent), falls when badly trimmed; the panel shows "speed +N %" / "−N %". | | |
| 7C | Choose **Leave it to the crew** (or Space). | Speed returns to normal; nothing else changes. | | |
| 7D | Under engine, open the panel. | "Under engine: the sails are not drawing." Trim has no effect. | | |

## 8. Long Passage

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 8A | Start a long ocean passage (e.g. Copenhagen → Las Palmas) with Long Passage time and a line out, "Stop for every bite". | Time stops for bites, but not constantly (there is a rest of a few hours between bites). | | |
| 8B | Choose "Stop only for fish worth keeping". | Time stops only for fish that match your preferences; the others are noted when time stops ("(N fish nibbled and swam off on the way.)"). | | |
| 8C | Let the passage run for several days. | It flows; stops have clear reasons (weather, stores, bites, anchorage). | | |

## 9. Anchorage waypoint

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 9A | At the chart table plot a course (e.g. Copenhagen → Gothenburg), add a waypoint, select it and press **M** (or the Anchorage button). | Near a coast it is marked with the anchorage icon; far offshore or on land it is refused with a reason, and a **nearby suitable spot** is offered. | | |
| 9B | Drag the anchorage waypoint. | It moves with the course; the course is recomputed. | | |
| 9C | Apply the course, cast off and sail (Long Passage is fine). | Time stops on arrival; the boat waits there (speed 0, sails furled). | | |
| 9D | The prompt. | "We've arrived at our anchorage. Ready to drop anchor?" with **Drop anchor**, **Not yet**, **Sail on**. It is asked once. | | |
| 9E | Choose Not yet, wait, then use the action wheel (Q). | The wheel offers the anchor and "Sail on"; the boat keeps waiting. | | |
| 9F | Drop anchor at the windlass; later raise it. | The usual anchoring checks apply; afterwards the course continues to the harbour and does not stop again at the same anchorage. | | |
| 9G | Abroad (outside Scandinavia). | Known limitation: the coarse chart abroad means anchorages and anchoring are not possible there (as before). | | |

## 10. Anchor visual signals

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 10A | At anchor by day, on deck. | A **black ball** hangs in the forward rigging, between mast and bow. | | |
| 10B | Look ahead of the bow. | The **anchor rode** leads from the bow into the water to a small **marker buoy**, bobbing gently (held still when Reduce motion is on). | | |
| 10C | At anchor at night. | A single **white anchor light** at the masthead; no red or green. | | |
| 10D | Moored in harbour and underway. | No ball, rode or buoy. | | |

## 11. Pet follows outside

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 11A | Moored, go up on deck and wait a few seconds. | Snøvs follows after a short natural delay and walks to a resting place on deck. | | |
| 11B | Watch the walk on each boat you can. | It stays aboard: never over the water, on the pontoon, through the coachroof or at the helm. | | |
| 11C | Go below. | A little later Snøvs follows you down. | | |
| 11D | At anchor in fair weather. | Snøvs comes up too. | | |
| 11E | Cast off, raise the anchor, or let the wind rise above ~20 kn / rain start. | Snøvs goes below by itself and stays below while sailing. | | |
| 11F | Pet Snøvs on deck (E). | Works as in the cabin. | | |

## 12. Cabin and deck lighting

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 12A | At night in the cabin (all four boats if you can). | Warm **pools** of light at the saloon table, galley and chart table; the corners clearly darker; still welcoming, not oppressive. | | |
| 12B | Look for the captain, Snøvs and the interaction highlights at night. | All readable. | | |
| 12C | Underway at night on deck. | Small **red** (port) and **green** (starboard) lights on the bow rail and a **white** stern light, glowing over the dark sea; no big halos. | | |
| 12D | Turn the boat through several headings (the view turns in eight directions). | Red stays to port, green to starboard. | | |
| 12E | Moored at night. | No navigation or anchor lights; the harbour lights the quay. | | |

## 13. Wind forecast

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 13A | Chart → Wind on → the buttons under the legend. | **◀ 1 h / Now / 1 h ▶**; up to **6 h** ahead and 6 h back. | | |
| 13B | Step ahead. | Label **FORECAST** with the time and "(+N h)", and "Estimated conditions. Actual wind may differ." | | |
| 13C | Step back. | **PAST MODEL SNAPSHOT**; Now returns to the present. | | |
| 13D | Step through all and back again. | Each step shows a visible change over the hours; previously seen times appear at once. Previewing changes nothing in the game. | | |

## 14. Persistence

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 14A | Set catch preferences, keep a fish, release another, save, quit the game, start it again, load. | Hold, preferences and trophies as saved. | | |
| 14B | At an anchorage waypoint, anchored, with Snøvs on deck: save, quit, restart, load. | Same position, at anchor, Snøvs on deck, course intact; no second arrival question; raising the anchor continues the voyage. | | |
| 14C | Trim by hand, sail some hours, save, quit, restart, load. | The trim, weather, route and stores as saved. | | |
| 14D | F5 / F9 in each of those situations. | Same results as a slot save/load. | | |

## 15. Performance

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 15A | Night sailing on deck for a few minutes. | As smooth as in 0.104a. | | |
| 15B | Night in the cabin. | Smooth. | | |
| 15C | Reel in a fish on deck at night. | The dial is smooth; no stutter while the fish animates. | | |
| 15D | Chart with wind on: step through the forecast times. | No long freezes; each time fills in within a moment. | | |
| 15E | A long Long Passage (several game days). | No slowdown building up. | | |

## 16. Final verdict

| ID | Question | Answer | Observations |
|---|---|---|---|
| 16A | Is 0.105a accepted on Windows? (YES / YES WITH NOTES / NO) | | |
| 16B | The most important thing to fix next. | | |
| 16C | Anything that felt especially good. | | |
