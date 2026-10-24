# Iteration 005c: A Sailor's Living (Report)

**Baseline:** I005b, commit `d2f7e1d`, branch `claude/determined-brahmagupta-3v95mx`.

**Engine:** Godot 4.7.2, GDScript, Compatibility renderer.

**Test environment:** Linux (headless, plus Xvfb with Mesa llvmpipe for
rendered runs).

**Not tested on Windows.** The owner's checks are in section **J** of
[WINDOWS_ACCEPTANCE_I005.md](WINDOWS_ACCEPTANCE_I005.md).

A small iteration: two ways money moves, and nothing else. There is no jobs
system, no physical shops, no trading and no regional prices.

## 1. Remote work

- **Where:** a **work station** in every cabin, with the prompt "Work
  remotely":
  - Starling 33: the saloon table;
  - Halcyon 40: the desk in the owner's hull;
  - Petrel 36: the saloon table.
- **Dialog:** `WorkMenu` lets you choose **1–8 hours** (arrows or Left/Right;
  4 is suggested). It shows the pay, the finish time, funds before and after,
  and the food and water that will be used.
- **When:** only while moored in harbour (`GameSession.can_work_remotely()`).
  At sea the station explains that work needs a harbour, and nothing happens.
- **How:** `Simulation.work(hours)` advances the existing simulation exactly as
  sleeping does. Food and water are used as usual. It works while paused and
  leaves the pause as it was. Then `GameSession.pay_remote_work()` pays
  **€25 per completed hour**.
- **Owners:** Simulation owns time, and GameSession owns funds.
- **Verified** (`test_living`):
  - 4 h earn €100 and take 4 h;
  - the stores drop by 4/24 day each;
  - limits are 1 and 8 h;
  - paused stays paused;
  - the stores used equal those of the same time simply passing;
  - refused at sea (no money, no time);
  - the station exists and opens the dialog on all three boats;
  - working 8 h through the dialog pays €200 and reports it.

## 2. Grocery store

- **Where:** at **every harbour**: a **GROCERY STORE** sign and station on the
  pontoon of every boat's deck. Like the boatyard, it is enabled only in
  harbour and disappears at sea. It is also reachable from the provisions panel
  and the boatyard, which now show **Grocery store (€…)…**.
- **Price:** **€10 per missing day of food or water, counted together**,
  filling both to 14 days. It is rounded up to whole euros, so a fraction of a
  day is never free, and it is the same in every harbour.
  - Examples: empty stores €280; 9.5 + 9.5 days missing €190; 10 days of food
    plus 1.5 days of water €115.
- **One transaction:** `GameSession.buy_provisions()` checks the harbour, that
  the stores are not full, and that funds ≥ the price. It then takes the price
  and fills both stores together. If anything fails, nothing changes and the
  reason is returned.
- **Insufficient funds:** Buy is greyed out, and the store says how much is
  needed and points to remote work.
- **Verified** (`test_living`):
  - prices: 0, 75, 76, 1 (rounded up), 280, 115 and 140 in three harbours;
  - €279 for €280 is refused with nothing changed; exactly €280 works and
    leaves €0;
  - refused at sea and when full;
  - the station and sign on all three boats, the menu opens, Buy pays €190;
  - the not-enough-money state explains itself;
  - the store is gone underway.

## 3. Free restocking removed

- `GameSession.restock_provisions()` was **removed** (the test checks that the
  method no longer exists). The free "Restock provisions" buttons in the
  provisions panel and the boatyard now lead to the grocery store.
- Messages that said "restock" now say "buy provisions at the grocery store".
- **Repairs stay free** (verified).
- The developer panel's "Full (test)" stores button remains. It is
  development-only, as before.

## 4. Persistence

- No new data: funds and provisions were already saved. Save format stays
  **version 7**, with no migration needed.
- *Verified:* money and stores after working and shopping survive save/load
  (`test_living`). The two-process restart check is reported in §6.

## 5. Changes to existing tests (because behaviour changed)

- `test_upkeep`:
  - the restock checks became purchase checks (€280 for empty stores, €9,720
    left);
  - the "nothing costs money" check now covers voyages, repairs and changing
    boats.
- `test_upkeep_ui`:
  - the provisions panel's button opens the grocery store (Buy €10 for one
    missing day in all);
  - the boatyard's grocery button opens the store, with repair free and
    provisions €180;
  - rescue fee checks are relative to the funds before the rescue (earlier
    purchases changed the starting balance).

No test was removed. The boatyard's fixed-size checks (100 %/130 %, all three
boats) still pass with the renamed **GroceryButton**.

## 6. Test results

- **Full headless run:** **1770 checks passed, 0 failed**, exit code 0. This
  includes the I005b weather, rescue, vessel, companion, interaction and
  boatyard-size suites unchanged.
- **`test_living` alone, rendered (Xvfb, OpenGL 3):** 52 passed, 0 failed.
  Screenshots 105–107 were produced by this run.
- **Two-process restart check** (`restart_check.tscn`, write then read):
  **PASS**, including money, food and water and each boat's condition.
- Save format unchanged (version 7); older saves load as before.

## 7. Screenshots (reviewed)

- `105_remote_work`: the work dialog at 8 h, "Work 8 h for €200", the finish
  time, funds before and after, and stores used.
- `106_grocery_store`: the store at Copenhagen, 4.5 days aboard, 19 days
  missing, "Price €190 · Funds €10,000 → €9,810".
- `107_grocery_not_enough_money`: €30 for €240; Buy greyed out with a note
  pointing to remote work. Re-rendered after the price line was changed to show
  only the current funds when the purchase is unaffordable.
- `89`, `90`, `93`, `94`: the provisions panel and boatyard with the grocery
  buttons.

## 8. Files

- **Added:**
  - `src/ui/simple_panel.gd`, `work_menu.gd`, `grocery_menu.gd`;
  - `tests/suites/test_living.gd`;
  - this report;
  - screenshots 105–107.
- **Modified:**
  - `src/core/game_session.gd` (prices, purchase, pay, constants);
    `src/core/simulation.gd` (`work`);
  - `src/app/app.gd`, `src/boat/boat_area.gd`;
  - `src/ui/provisions_menu.gd/.tscn` and `boatyard_menu.gd/.tscn`
    (GroceryButton);
  - the Starling cabin and deck scenes (hand-edited); the Halcyon and Petrel
    cabins and decks (regenerated from `tools/vessels/build_multihull_scenes.py`);
  - tests (`test_upkeep`, `test_upkeep_ui`, `test_dev_guides`, `test_runner`);
  - `README.md`, `ARCHITECTURE.md`, `WINDOWS_ACCEPTANCE_I005.md`.

## 9. Limitations

- Remote work has one fixed rate, with no fatigue, schedule or jobs. Work is
  paid per *completed* hour (always whole hours here).
- One grocery price everywhere, and only "fill both to 14 days" (no partial
  purchase).
- Not run on Windows.

## 10. Git

- Branch `claude/determined-brahmagupta-3v95mx`, on top of I005b `d2f7e1d`.
- One commit, "Iteration 005c: A Sailor's Living" (see `git log`).
