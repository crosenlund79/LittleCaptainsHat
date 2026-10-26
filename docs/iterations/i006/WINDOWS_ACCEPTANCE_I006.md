# Windows acceptance: Iteration 006 (Making Waves)

A short practical checklist for the new systems. Run the game from the Godot 4.7.2 editor (**F5**). Mark each step **Pass / Fail** and take the screenshots asked for (Win+Shift+S).

The I005 checks (weather, damage, rescue, money, provisions, work, grocery store) stay in [WINDOWS_ACCEPTANCE_I005.md](../i005/WINDOWS_ACCEPTANCE_I005.md).

Nothing here has been run on Windows by the developer. It was tested on Linux only (automated and rendered runs).

## K. Captain's Log

| Step | Do | Expected | Pass if |
|---|---|---|---|
| K1 | New game. Press **L** | The **Captain's Log** opens: Distance sailed 0.0 nm, Voyages 0, Harbours visited **1 of 163**, Arrivals 0, Rescues 0, Renown 0 (0 unpublished). The game is paused behind it. | Values as stated |
| K2 | **Harbours** tab | Copenhagen, Denmark, "start harbour". All other harbours under *Not yet visited*. | — |
| K3 | Press **L** again; then Esc → pause menu → **Captain's Log (L)** | L closes it; the pause-menu button opens it | Both ways work |
| K4 | Plot a course to Kiel and sail there (20× or sleep) | On arrival, short messages: "New harbour in the Captain's Log: Kiel (2 of 163 visited)" and "+100 renown: …" | Both shown once |
| K5 | Open the log | Distance about 154 nm, Voyages 1, Harbours 2 of 163, Arrivals 1. Longest passage: Copenhagen → Kiel. One line under *Recent passages*. | Values match |
| K6 | Sail back to Copenhagen | Arrivals 2, still 2 harbours; no "new harbour" message; no renown | No reward for returning |
| K7 | Save, quit to the main menu, load (also after restarting the game) | The log, renown and objectives are exactly as before; no messages on loading | Nothing repeats |

📸 Screenshots of K1 and K5.

## L. Objectives and renown

| Step | Do | Expected | Pass if |
|---|---|---|---|
| L1 | Log → **Objectives** tab | The renown line at the top; open objectives with their requirement, progress (e.g. "Progress: 2 of 5.") and reward; "Completed" at the bottom with Cast off, Across the Western Baltic, The first hundred miles, New horizons and Not a scratch | Readable; the panel keeps its size between tabs |
| L2 | Sail somewhere new (e.g. Gothenburg) | "+10 renown: New horizons." (plus any objective reached) | Renown for the new harbour |
| L3 | During a passage, F9 → **Rescue test** (see the I005 checklist, D) | After the rescue: no voyage or harbour renown; only distance objectives can count the miles | Renown never decreases |

📸 Screenshot of L1.

## M. Publish travel update

| Step | Do | Expected | Pass if |
|---|---|---|---|
| M1 | In harbour with renown: Log → **Publish travel update (€…)…** | Confirmation: unpublished renown, "N renown × €2 = €…", "Funds €A → €B", buttons *Cancel* and *Publish for €…* | Numbers add up |
| M2 | **Cancel** | Back to the log; nothing changed | — |
| M3 | Publish | Message "Travel update published: N renown earned you €…"; HUD funds increase by that amount | Exact amount |
| M4 | Open the log | Renown "N (0 unpublished)"; the publish button is disabled with a reason | Lifetime renown unchanged |
| M5 | At the cabin's work station (Work remotely) | The dialog also has **Publish travel update…** (disabled when nothing is unpublished). Remote work still pays €25 an hour. | Both work |
| M6 | At sea: open the log | The publish button is disabled: "moor in a harbour first" | No publishing at sea |
| M7 | The grocery store (deck, pontoon) | Still sells food and water at €10 per missing day | Unchanged |

📸 Screenshot of M1.

## N. Chart with 163 harbours

| Step | Do | Expected | Pass if |
|---|---|---|---|
| N1 | Open the chart, **All Europe** | About 40 major harbours (e.g. Tromsø, Tallinn, Venice, Split, İzmir, Limassol), names not overlapping | **Your judgement:** readable, not cluttered |
| N2 | Zoom in step by step on the Baltic, the Adriatic and the Aegean | More harbours and names appear as you zoom; names never overlap; at the closest zoom every harbour in view has a marker | Smooth, no stutter |
| N3 | Pan around quickly at several zoom levels | The chart stays responsive | **Your judgement:** no slow-down |
| N4 | Course tab → **Find a harbour…**: type "kor" | "Korčula, Croatia" appears; click it | The chart zooms to Korčula, selected |
| N5 | While the search field has focus, press W A S D | Letters are typed; the chart does not move | — |
| N6 | **Plot course to Korčula**, Apply, Set sail | A valid route; the voyage starts | — |
| N7 | Try a few far harbours (e.g. Honningsvåg, Tórshavn, Larnaca) | Each gets a route that stays on water | — |
| N8 | Settings → Interface scale 130 %, open the chart | The sidebar and search still fit | — |

📸 Screenshots of N1, a close zoom (N2), and N4.

## O. Older saves

| Step | Do | Expected | Pass if |
|---|---|---|---|
| O1 | Load a save made with Iteration 005c or earlier | It loads. The log shows Copenhagen (and the harbour the boat was in) as visited, "before the log was kept", with no invented voyages, distance or renown. | Loads, nothing invented |
| O2 | Complete a voyage from that save | The log records it; objectives check the log as it now stands | — |
