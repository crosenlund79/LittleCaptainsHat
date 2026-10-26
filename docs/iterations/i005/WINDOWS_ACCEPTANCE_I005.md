# Windows acceptance: Iteration 005 (005a weather, 005b condition, rescue, money, provisions, 005c work and grocery store)

A step-by-step checklist for testing on Windows. You never need to edit a script.

Record for each test: **Pass / Fail**, plus a screenshot where asked (Win+Shift+S).

## How to run the game for testing

1. Open the project folder in **Godot 4.7.2** (the editor) and press **F5** (Run Project).
2. **F9** opens the **Developer test tools** panel, on board or on the chart. Press F9 again or Esc to close it.
   - The **pause menu** also has a **Developer tests (F9)** button.
   - The panel is only available when the game runs from the Godot editor. A player's (exported) game has no such panel or button.
   - To see the game exactly as a player does, set the run arguments to `--no-dev-tools`: Project → Project Settings → Editor → Run → Main Run Args. The panel and the button are then gone.
3. The game is paused while the panel is open. The panel's **Advance** buttons move time on through the normal simulation.
4. Test weather made in the panel is never saved. It disappears with **Normal weather**, New Game, Load or Main menu.

Default controls: WASD or the arrow keys to walk, **E** to use what the prompt names, Esc for the menu.

---

## A. Starting state

| Step | Do | Expected | Pass if |
|---|---|---|---|
| A1 | Main menu → New Game → Cat → Start | You are in the Starling 33's cabin in Copenhagen | — |
| A2 | Look at the top-left HUD panel | Third line: `Hull 100 % · Sound   €10,000   Food 14.0 d · Water 14.0 d` | All four values are as shown |

📸 Screenshot of the HUD.

## B. Provisions

| Step | Do | Expected | Pass if |
|---|---|---|---|
| B1 | Walk to the galley (top left in the cabin). The food crates and water cans are drawn on the counter. Stand below it; the prompt says **Check provisions**. Press E. | The **Provisions** panel shows Food, Water and Endurance as `14.0 days`, level **Full** | The numbers are readable |
| B2 | Note the values. Close the panel. Walk to the berth, press E, choose **12 hours**, Sleep. | You wake 12 h later | — |
| B3 | Open Provisions again | Food and Water both `13.5 days` (12 h = 0.5 day) | Reduced by exactly 0.5 |
| B4 | Press F9 → Provisions: **3 days (low)**. Close the panel. | A message says provisions are running low. On the counter one crate and one can are left, in amber. HUD: `Food 3.0 d`. | The graphics changed |
| B5 | F9 → **Empty** | Message: you have run out. The crates and cans are outlines, red. | — |
| B6 | Chart table → plot a course to Kiel → helm (on deck) → Set sail | Refused: "You are out of food or water. Buy provisions at the grocery store…" | You cannot depart |
| B7 | Open Provisions → **Grocery store (€280)…** → **Buy for €280** (I005c) | `14.0 days` at once; the crates and cans are full again | Full, and €280 paid |
| B8 | At sea: set sail, then open Provisions | The grocery button is greyed out: "Underway: buy food and water at the grocery store in the next harbour" | No buying at sea |

📸 Screenshots of B1, B3 and B5.

## C. Severe weather and damage

| Step | Do | Expected | Pass if |
|---|---|---|---|
| C1 | In Copenhagen: plot Kiel, set sail, and let it run about 10 minutes at 1×. | Underway | — |
| C2 | F9 → **Severe storm**. Read the panel's status line. | `Test weather: Severe storm at the boat (active…)`. At the boat: wind about 50 kn, gusts about 70, Storm, **Severe** | The status shows the storm |
| C3 | Close F9 and open the chart | A labelled **STORM** area around the boat, with the wind arrows red | Visible on the chart |
| C4 | Back aboard: a weather warning appears ("Severe conditions at the boat…"). Let time run at 20× for 1–2 game hours. | The HUD hull value drops (roughly 10–15 % per hour in this storm) | Condition decreases |
| C5 | Go on deck | Scuffs, rust spots, cracks and dark patches appear as the condition drops. More below 40 % (Damaged), heavy below 15 % (Critical). | Damage is clearly visible |
| C6 | F9 → **Normal weather** | The storm is gone from the chart and the status; the wind is ordinary again | Restored without restarting |
| C7 | F9 → **Thunderstorm / squall**, then chart and HUD | A **SEVERE SQUALLS** cell (lightning symbol) at the boat; a warning; gusts well above the wind | — |
| C8 | F9 → **Condition 100 / 75 / 40 / 15 / 1 %**, on deck | At 100 % no marks; more marks at each lower step. HUD: Sound / Worn / Damaged / Critical. | The look changes at each step |
| C9 | Repeat C8 on the Halcyon 40 and the Petrel 36 (change boats in harbour, test G) | The same on both | — |

📸 Screenshots of C3, and of C5 or C8 at 40 % and at 15 %.

## D. Rescue

| Step | Do | Expected | Pass if |
|---|---|---|---|
| D1 | Note your funds (a new game: €10,000) | — | — |
| D2 | Set sail for Kiel and let it run a few minutes | Underway | — |
| D3 | F9 → **Rescue test: 1 % + storm (at sea)**, then close the panel and let time run at 1× | Within at most 5 game minutes the storm's damage takes the hull to 0 % | — |
| D4 | — | A dialog **Rescued at Sea**: return destination Copenhagen, rescue fee €1,000, remaining funds €9,000. The game is paused behind it. | Text and numbers correct |
| D5 | Press **Continue** | You are aboard in the cabin, **Moored at Copenhagen**, hull `100 % · Sound`, funds `€9,000`; same boat, same companion; time runs at 1× | All as stated |
| D6 | Save (pause menu → Save Game → a slot), then load that slot | Still €9,000, Copenhagen, 100 %; no second rescue or fee | No repeat |
| D7 | Repeat D2–D5 | €8,000 left | Exactly €1,000 less |
| D8 | Variation: at D3, sleep 8 hours at the berth instead of waiting | The rescue dialog appears; no "You slept…" message; no voyage continues | — |

📸 Screenshots of D4 and D5.

## E. Boat layouts

| Step | Do | Expected | Pass if |
|---|---|---|---|
| E1 | Walk around the cabin and deck of all three boats (change boats in harbour, test G) | Every station can be reached | — |
| E2 | Halcyon 40 cabin | Wider hull cabins with real double berths (owner's to port, guest to starboard), deeper galley, settee and desks. The exit is a glowing doorway with chevrons labelled **TO DECK** on the aft wall. | **Your judgement:** the proportions look right |
| E3 | Halcyon: walk into both hulls by the steps and back; use the door to the deck | Smooth walking; "Go on deck" works | — |
| E4 | Each cabin: the provisions station by the galley | Crates and cans drawn; **Check provisions** works | On all three boats |
| E5 | Watch the cat over a few game hours (20×) | It rests on the settee, the berth, by the nav station and so on | Spots look sensible |

📸 Screenshot of the Halcyon cabin.

## F. Cat next to stations

| Step | Do | Expected | Pass if |
|---|---|---|---|
| F1 | Wait until the cat lies by the galley or chart table, or sleep until it moves there | — | — |
| F2 | Stand at the station, facing it | The prompt names the station (e.g. **Check provisions**), and E uses it | The station works |
| F3 | Turn towards the cat (tap the arrow key pointing at it) | The prompt changes to **Pet cat**; E pets it (purr, hearts) | Petting works |
| F4 | Same by the berth and the door | The berth and "Go on deck" are never blocked; the cat stays pettable by facing it | No action becomes unavailable |

The rule: stations win when you stand at them; the cat wins when you face it.

## G. Boatyard

| Step | Do | Expected | Pass if |
|---|---|---|---|
| G1 | In harbour, on deck, use **Visit the boatyard** | Panel with three boats, preview, details, comparison, services | — |
| G2 | Click Starling 33, Halcyon 40, Petrel 36 in turn (or Up/Down) | The outer panel does **not** change size or position; only its content changes. Each boat shows its own condition. | The size stays the same |
| G3 | With a damaged boat (C8) and used stores (B4): **Repair vessel (free)**, then **Grocery store…** → Buy | Hull 100 % for free; stores 14 days for the price shown | — |
| G4 | Move aboard another boat, damage it (C8), move back | Each boat keeps its own condition. Money and stores are not reset by changing boats. | — |
| G5 | Settings → Interface scale 130 %, then G2 again | Still a stable size; all buttons visible | — |

📸 Screenshots of G2 for all three boats.

## H. Chart

| Step | Do | Expected | Pass if |
|---|---|---|---|
| H1 | Open the chart; switch Course / Weather / Details | The sidebar keeps its size; Apply, Set sail, Sleep and Back always visible | — |
| H2 | Plot a course, add a waypoint, change course at sea | The panel does not jump | — |
| H3 | With test weather active (C2 or C7): Weather tab | The hazards listed with their level; the legend; the panel size unchanged | — |
| H4 | Zoom and pan | The weather areas stay in place on the map | — |

## I. Persistence

Save in each state below, then quit to the main menu and load the save (also after restarting the game):

| State | Check after loading |
|---|---|
| Damaged boat (e.g. 40 %) underway | Same condition, position, voyage, time; damage continues in a storm |
| Used stores (e.g. 9.8 days) | Same food and water |
| After a rescue | Funds €9,000, Copenhagen, no repeat rescue |
| On the Halcyon with the dog | Same boat and companion |
| Moored in Kiel | Kiel, moored |
| Test weather active when saving | **The storm is gone** after loading (test weather is never saved); everything else is kept |

Older saves (Iteration 005a and earlier) load with €10,000, 14 days of stores and every boat at 100 %.

## J. A sailor's living (Iteration 005c)

| Step | Do | Expected | Pass if |
|---|---|---|---|
| J1 | New game. In the cabin, find the **work station**: the Starling's and Petrel's saloon table, or the Halcyon's desk in the owner's hull. Prompt **Work remotely**. Press E. | The **Remote work** dialog: 4 hours suggested, "Work 4 h for €100", the finish time, funds now and afterwards | — |
| J2 | Use **<** / **>** (or Left/Right) | 1 to 8 hours; the pay follows (€25 per hour) | Never below 1 or above 8 |
| J3 | Work 8 hours | 8 game hours pass; message "You worked 8 h and earned €200…"; HUD funds +€200; Food and Water each −0.3 days | All three |
| J4 | Set sail, then use the work station at sea | Refused: "Remote work needs a steady connection: moor in a harbour first." | No work at sea |
| J5 | In harbour, on deck: walk to the pontoon sign **GROCERY STORE**; prompt **Visit the grocery store** | The store shows food and water aboard, the missing days, the price at €10 per missing day, and funds before and after | — |
| J6 | After some days in harbour (or F9 → Provisions 3 days), **Buy** | Pays the shown price; food and water 14 days; the crates and cans full | Exact price paid |
| J7 | With little money (spend it, or load a save with less than the price) | **Buy** greyed out; "Not enough money … Remote work … €25 an hour" | No purchase without the money |
| J8 | Provisions panel and boatyard | Both offer **Grocery store (€…)…**, which opens the same store; there is no free restock anywhere | No free restocking |
| J9 | Damage the boat (F9 → 40 %), boatyard → **Repair vessel (free)** | 100 %, money unchanged | Repairs are still free |
| J10 | Save after working and shopping, load | Same money and stores | — |

---

**Not verified by the developer:** none of this has been run on Windows; it was tested on Linux (automated and rendered runs). Aesthetic judgements (E2, the damage look in C5) are yours.
