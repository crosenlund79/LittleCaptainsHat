# Windows Acceptance — Revision 0.105b, Safe Harbours, Deep Waters & the Sprite Workshop

**Status: NOT YET TESTED ON WINDOWS.** This revision was verified on Linux only: automated tests, rendered screenshots under a software renderer, benchmarks, and two-process restart tests. Nothing here counts as accepted until the Captain's and the Skipper's results come back. The I018 checklist (`WINDOWS_ACCEPTANCE_18.md`) is still open as well, and the two can be tested together.

**How to report.** For each check, write **PASS**, **FAIL**, **PARTIAL** or **NOT TESTED** in the Result column. Put anything worth saying under Observations: what you saw, a screenshot name, the game time. The checks are independent, so skip any you cannot reach.

**Setup.** GitHub → branch `claude/friendly-fermat-dey23f` → Code → Download ZIP → extract → open `project.godot` in Godot 4.7 → Run (F5 in the editor).

**Keys used below:**
- **E**: interact (also the press on the Magic Anchor's dial, or click the dial)
- **Q**: action wheel
- **R**: rod
- **T**: Sail Trim
- **M**: mark or unmark the selected chart waypoint as an anchorage
- **F5**: quicksave
- **F9**: quickload

**Depths.** All depths in this build are **GAME ESTIMATES**: no real depth data could be downloaded (see the report, section 5). They are for play, not for navigation.

## 1. Version and old saves

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 1A | Start the game and look at the main menu. | It shows **Version 0.105b**. | | |
| 1B | **Continue** a 0.105a save (I018). | It loads as you left it. No error, and no request to re-plot the course. | | |
| 1C | Load a 0.105a save that was made **at anchor with the engine running** (if you have one). | Still at anchor, and the engine is off. | | |
| 1D | Load Game. | Slots are listed as before, and your saves are untouched. | | |

## 2. Normal anchoring in Denmark

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 2A | Sail from Copenhagen towards Svendborg or Nyborg. Near a sheltered coast, go to the windlass (E). | The panel names the anchorage (good / fair / exposed) and a depth such as "about 9 m, GAME ESTIMATE". | | |
| 2B | Drop anchor (catch the marker in the green middle). | The anchor goes down and the boat stops. The anchor ball, rode and buoy show. | | |
| 2C | If you were motoring, check the HUD after anchoring. | The engine has stopped. | | |
| 2D | Let out more or less chain, then "Set it again". | Holding changes as before. | | |

## 3. Normal anchoring abroad

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 3A | Sail (or Long Passage) to the Caribbean, e.g. Falmouth Harbour, Antigua. Anchor a mile or less off a lee shore. | The normal anchor is offered and holds, just as in Denmark. | | |
| 3B | Try at least one more of: Iberia or the Mediterranean (A Coruña), the Canaries or Madeira, French Polynesia (Papeete), New Zealand (Whangārei). | A suitable cove takes the normal anchor. | | |
| 3C | Try far out at sea with only the normal anchor. | It is refused: "too deep for the normal anchor to reach the bottom". | | |

## 4. Magic Anchor acquisition

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 4A | In a harbour with a boatyard (Copenhagen), open Boat care. | Under Equipment there is a **Magic Anchor (Multi-purpose Deep Anchor)** row, with "Fit it (free prototype)". | | |
| 4B | Fit it. | No money is taken. It shows as "Aboard". | | |
| 4C | Change boats at the boatyard. | The Magic Anchor is still available on the new boat. | | |
| 4D | Read its description. | It is openly fictional ("a suspicious amount of nautical magic"). | | |

## 5. Coastal special anchoring

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 5A | Off a steep island coast (e.g. Madeira), where the windlass says the water is too deep for the normal anchor, press **Magic Anchor**. | The dial opens: "The brass flukes unfold…". | | |
| 5B | Set it down. | The anchor bites and a short brass glow plays. The deck shows a small brass gear at the bow and a short brass-tinted line. | | |
| 5C | Open the windlass again. | "The Magic Anchor holds…" with its depth, marked GAME ESTIMATE. | | |

## 6. Offshore emergency anchoring

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 6A | Far out at sea, deploy the Magic Anchor. | It is allowed. The message says it **holds position but is no shelter** from wind or waves. | | |
| 6B | Try it on a course that runs over land, or near the shore in a tiny gap. | Land and unreachable water are still refused. | | |

## 7. Skill-check feel

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 7A | Deploy in light wind (under 17 kn). | One good turn is needed, with a wide green arc. | | |
| 7B | Deploy in 17–27 kn, then in 28 kn or more. | Two, then three good turns. The arc is a little narrower, and the needle never speeds up. | | |
| 7C | Hit the gold middle. | "Perfect!" counts and gives a small holding bonus. | | |
| 7D | Overall: is it fair and cozy, not punishing? | | | |

## 8. Failure and retry

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 8A | Miss on purpose once. | "Missed - it skips over the bottom (5 min)", the tries left are shown, and the game clock moves 5 minutes. | | |
| 8B | Miss three times. | "…has not bitten. The boat is not anchored and drifts…". A **Try again** button appears. | | |
| 8C | Try again, or press Cancel. | Try again gives a fresh dial. Cancel lets nothing go, and the boat stays as it was. | | |

## 9. Anchorage area overlay

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 9A | On the chart, switch **Anchorages** on (bottom bar) at whole-world zoom. | No colours. The legend says to zoom in on a coast. | | |
| 9B | Zoom in close to a coast. | Within a few seconds, teal (normal anchor) and amber (Magic Anchor) bands appear along the coast. | | |
| 9C | Point at the water. | The legend shows a short note: the anchor type, the depth "about … m, GAME ESTIMATE", and the land distance. | | |

## 10. Zoom and map panning

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 10A | Pan along the coast and back. | Bands fill in for new areas, and areas already seen come back at once. | | |
| 10B | Pan across the Date Line (Fiji or New Zealand). | Bands are correct on both sides. | | |
| 10C | Is the chart smooth while the bands fill in? | | | |

## 11. Safe versus unsafe locations

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 11A | Plot a course and drag a waypoint into a teal band, then press **M**. | It becomes an anchorage. The course text says it suits the normal anchor, with the depth. | | |
| 11B | Drag it into an amber band and press M. | It is marked "(Magic Anchor)" with an amber ring. Without a Magic Anchor aboard, it is refused with the reason and a nearby normal spot is offered. | | |
| 11C | Try to mark a waypoint on land or right against the shore. | It is refused with a reason ("Land…", "Too close to the shore…"). | | |

## 12. Storm and exposure

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 12A | At anchor (normal or Magic), let a gale come (or sit through one with time speed-up). | Poor holding, then dragging, with the existing alarm. The boat drags a little at a time and never onto land. | | |
| 12B | The offshore Magic Anchor in a storm. | It can still drag. It is no weather immunity. | | |

## 13. Long Passage arrival

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 13A | Mark an international anchorage on a long course and use Long Passage. | The boat stops there and asks once: "We've arrived at our anchorage. Ready to drop anchor?" | | |
| 13B | Anchor, then raise the anchor. | The course continues. The engine does not start just because the anchor came up. | | |
| 13C | With the anchor down, try anything that would start the engine. | "Let's raise the anchor before starting the engine." | | |

## 14. Anchoring visuals and solar panels

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 14A | At anchor by day, then at night. | Black ball by day, white anchor light at night, plus the rode and buoy. | | |
| 14B | Look at the stern of each boat (Arctic Wanderer 26, Wing 33, Frogleap 36, Clam 40). | Small decorative solar panels: 1 on the Arctic Wanderer's rail, 2 on the Wing 33 and the Frogleap 36, 3 on the Clam 40's arch. | | |
| 14C | Turn the boat (sail different courses). | The panels stay attached at the stern. | | |
| 14D | Walk around the stern. | The panels never block the Captain, Snøvs or the helm. | | |

## 15. Snøvs aboard while anchored

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 15A | At anchor, go on deck and wait a little. | Snøvs follows and settles somewhere safe (as in I018). | | |

## 16. Sprite Workshop folder readability

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 16A | Open the folder `art_replacements` in Explorer and read `README_START_HERE.md`. | It is clear what to do without reading any other document. | | |
| 16B | Open `art_replacements/INDEX.md`. | The counts, the first 25 subjects and the quick wins are readable. | | |

## 17. CSV instructions and dimensions

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 17A | Open `art_replacements/05_sailing_equipment/anchor/manifest.csv` in Excel or LibreOffice. | One row per picture, with filename, sizes, complexity, priority and status. | | |
| 17B | Check that the README in that folder explains orientation, pivot and transparency. | | | |

## 18. Replacing a simple prop (the anchor buoy)

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 18A | Draw a **60 x 60 px** transparent PNG of a buoy. Save it as `art_replacements/05_sailing_equipment/anchor/anchor_buoy.png`, then restart the game from Godot. | | | |
| 18B | Anchor anywhere. | Your buoy floats at the end of the rode. | | |

## 19. Replacing a character or pet (Snøvs)

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 19A | Draw Snøvs resting, **284 x 284 px**, with the cat in the middle on a transparent background. Save it as `art_replacements/02_pets/snovs_cat/resting.png` and restart. | | | |
| 19B | Go to the cabin (with the cat as companion). | Snøvs rests in your drawing, in the same places as before. The other poses stay as they were until you draw them. | | |

## 20. Replacing a composed object (the Arctic Wanderer 26 coachroof)

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 20A | Draw the coachroof layer at **2200 x 800 px**: the whole boat canvas, transparent except the coachroof, bow to the right. Tip: start from `assets/vessels/arctic_wanderer_26/illustrated/deck/coachroof.png`, scaled up, as a template. Save it as `art_replacements/03_boats/arctic_wanderer_26/deck_coachroof.png` and restart. | | | |
| 20B | Board the Arctic Wanderer 26 and go on deck. | Your coachroof is drawn and the rest of the boat is unchanged. You can walk exactly as before. | | |

## 21. Removing replacements

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 21A | Delete (or rename) the three PNGs and restart. | The original buoy, Snøvs and coachroof return. | | |
| 21B | Save a PNG with the wrong shape (e.g. a 60 x 120 buoy) and restart. | The original stays. Godot's Output panel says "Sprite Workshop: … should have the shape of …". | | |

## 22. I018 fishing gameplay and fish appearance

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 22A | Fish under way and at anchor. Reel in with the dial. | As in I018, with the animated fish portraits, grades and keep preferences. | | |

## 23. Sail Trim

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 23A | Press T under way, trim, and save and load. | As in I018. | | |

## 24. Save and load after restart

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 24A | At an international anchorage with the normal anchor: save, quit Godot's game window, run again and load. | Same place, still anchored, depth unchanged, engine off. No second "arrived" question. | | |
| 24B | The same with the Magic Anchor offshore. | Still the Magic Anchor, still aboard. The holding goes on as before. | | |

## 25. Performance and stability

| ID | What to do | Expected | Result | Observations |
|---|---|---|---|---|
| 25A | Chart with Anchorages on, panning along long coasts. | No stalls you notice. | | |
| 25B | An hour of play mixing everything above. | No crash and no error dialog. | | |

## 26. Final acceptance verdict

| ID | Item | Result | Observations |
|---|---|---|---|
| 26A | Worldwide anchoring (normal and Magic) | | |
| 26B | Sprite Workshop | | |
| 26C | Engine-off anchoring and solar panels | | |
| 26D | Revision 0.105b accepted on Windows | | |
