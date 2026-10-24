# Iteration 005b: The Price of the Passage (Report)

**Engine:** Godot 4.7.2 stable, GDScript, Compatibility renderer.

**Test environment:** Linux container, Godot headless, plus Xvfb with Mesa
llvmpipe for rendered runs.

**Not tested on Windows.** Nothing here has been run on Windows by the developer.
The owner's checklist is [WINDOWS_ACCEPTANCE_I005.md](WINDOWS_ACCEPTANCE_I005.md).

The report distinguishes:
- **Implemented:** in the game.
- **Automatically verified:** an automated check covers it; the suite is named.
- **Visually reviewed:** a rendered screenshot was looked at.
- **Owner verification:** still needed on Windows.

## 1. Baseline branch and commit

| | |
|---|---|
| Branch | `claude/determined-brahmagupta-3v95mx`, the only branch on GitHub, with no pull requests |
| Baseline | `4cecf06` (Iteration 005a: weather), which sits on I004b `c57af32` |
| Working tree | clean at the start |
| Save format at the start | version 6 |
| I005b work elsewhere | none (checked on GitHub: one branch only) |

I005a (the weather model, its tests and documents) and I004b (the cat artwork,
the guides, the developer viewer) were present and passing.

## 2. Initial repository findings

- **Not built yet:** money, provisions, vessel condition, damage, repair,
  restocking and rescue did not exist in the code at all. That explains the
  October 24 findings "provisions not visible" and "no damage observed": the
  Windows build was Iteration 005a.
- **Interaction:** `InteractionSensor` focused the interactable whose centre was
  nearest, with no notion of priority. A resting cat beside a station is often
  nearer than the station's centre, so it took the focus (root cause of the cat
  finding, §15).
- **Boatyard:** the panel sat in a `CenterContainer` with no fixed size. Its
  width and height followed the description and specs text, so it changed size
  with each boat (§16).
- **Halcyon 40 cabin:**
  - The hull passages were 100 units wide but 925 long. With the player 40
    units across (~0.5 m), that is ~1.25 m wide.
  - Counters, settees and desks were 26 units deep (~0.33 m), and the berths
    145×92.
  - The previous refinement had improved the layout, but not these
    proportions (§14).
- **Starling 33 and Petrel 36:** found while testing. Their berth resting spot
  for the companion was out of the player's reach (82 and ~92 units from the
  nearest standing place), so a cat there could never be petted. Fixed (§15).

## 3. Implemented condition system

- Each boat has one general seaworthiness value, 0–100 %, in
  `SessionState.vessel_conditions` keyed by the stable vessel id. A boat not
  listed is at 100 %. A new game starts with every boat at 100 %.
- It is owned by `SessionState` and changed only through `GameSession`:
  - `apply_weather_damage()`, called by the Simulation;
  - `repair_vessel()`;
  - `rescue()`;
  - `set_condition_for_testing()`, for the developer tools only.
- Bands (`VesselCondition`): **Sound** 76–100, **Worn** 41–75, **Damaged**
  16–40, **Critical** 1–15; 0 means a rescue. The shown value is rounded up, so
  "0 %" appears only when the boat is lost.
- Shown in the HUD (`Hull 87 % · Sound`), in the boatyard for every boat, and in
  the developer panel.
- Switching boats keeps each boat's own condition. Money and stores are not
  touched.
- No separate hull, engine, sail, rigging, electrical or plumbing damage.

*Verified:* `test_upkeep` "[start]", "[boats]", "[condition]", "[repair]";
`test_upkeep_ui` "[hud]", "[boatyard]".

## 4. Damage model and balancing

Rate in % per hour, from the weather at the boat, times the boat's
`VesselProfile.weather_damage_factor`: Starling 33 1.0, Halcyon 40 0.85 (a
stable catamaran), Petrel 36 1.15 (a light trimaran).

```
sustained  0.06 × (wind − 28 kn)^1.6      only above 28 kn
gusts      0.2  × (gust − 45 kn)          only above 45 kn
```

| Conditions (sustained / gusts) | Starling 33 per hour | 6 hours in it |
|---|---|---|
| 25 / 34 kn (fresh breeze) | 0 % | 0 % |
| 30 / 40 kn (strong winds, caution) | 0.2 % | ~1 % |
| 34 / 46 kn (gale threshold, dangerous) | 1.3 % | ~8 % |
| 40 / 54 kn (gale) | 5.0 % | ~30 % |
| 48 / 65 kn (storm, severe) | 11.2 % | ~67 % |
| 60 / 78 kn (violent storm) | 22 % | lost after ~4.5 h |
| 22 kn with squall bursts to 55 kn | ~2 % while bursts last | — |

- Ordinary sailing does nothing.
- Caution is survivable.
- A gale costs a noticeable amount over hours.
- A storm is a real threat if the boat stays in it, but no single gale is
  instantly fatal.

*Verified:* `test_upkeep` "[damage]":
- an ordinary-weather passage leaves ≥ 90 %;
- 6 h of strong winds cost < 3 %;
- a 42 kn gale costs 3–25 % in 2 h, and damage grows with time;
- squall gusts alone do damage;
- the three boats rank by resilience.

## 5. Weather integration and gust handling

- Damage uses only the one `WeatherModel` (no second weather source). It is
  applied in `Simulation._assess_weather()` at every evaluation point while
  underway (the absolute 300 s grid, plus departure), before the warnings.
- **Gusts:** the damage for the stretch since it was last applied is the sum
  over **fixed 60 s sample times** (k × 60 s of game time) at the boat. I005a's
  gust bursts last 8–20 minutes, so none is missed between 300 s evaluation
  points.
- **No double counting:** `damage_applied_until` (saved) records how far damage
  has been applied, so the same interval is never processed twice, including
  across saves.
- **Time-step independence:** the sample times are fixed on the clock, so 1×,
  5×, 20×, one 6 h `advance()`, sleeping and a save/load midway give **exactly**
  the same condition, position, stores and exposure (compared to 1e-6).
- Found and fixed on the way: `Simulation.advance()` could run one extra
  iteration on floating-point residue. An evaluation point exactly at the end
  of a call was then handled in that call after one big step, but in the next
  call after many small steps. Residue below 1 µs now ends the loop.
- No damage while moored or arrived. No harbour storms, collisions, grounding
  or wave physics.
- The last partial interval before an arrival (at most 5 minutes) is not
  charged.

*Verified:* `test_upkeep` "[time]" (six modes, two moving events starting
during the voyage), "[saves] loading mid-storm continues the damage exactly";
`test_weather`, `test_simulation` and `test_sailing` still pass unchanged.

## 6. Damage visual presentation

- **`DamageOverlay`** (`src/boat/visuals/damage_overlay.gd`) is a child of each
  `VesselVisual`, on deck and in the cabin.
  - Marks are placed deterministically per boat and area, inside the boat's own
    outline (its base slots' shapes).
  - Worn shows 14 scuffs and rust spots. Damaged shows 34 marks, adding cracks
    and damaged planking. Critical shows 60, with water on the cabin sole.
  - It draws over the art and under `Layout`, so station rings and markers stay
    on top. It never touches the owner's PNGs, has no collision, and follows
    `condition_changed`.
- **Replaceable:** per band, `damage_<worn|damaged|critical>.png` in
  `<art>/<deck|cabin>/`, or a texture in the profile's Damage group, replaces
  the procedural marks.
- The boatyard preview shows each boat's own damage.

*Verified:* `test_upkeep_ui` "[damage]" on all three boats: 0 marks at 100 %,
then more at 75 %, 40 % and 15 %; the cabin too; a repair clears them; the HUD
says Critical.

*Visually reviewed:* `80`–`88_damage_*` (each boat at 100 %, 40 %, 15 %). Damage
is plainly visible at 40 % and heavy at 15 %. Whether it looks good is the
owner's call.

## 7. Repair interaction

- **Repair vessel (free)** is in the boatyard's new services row, enabled only
  when moored in harbour and below 100 %.
- `GameSession.repair_vessel()` re-checks the harbour when called, so it is
  refused at sea. It restores 100 % and updates the HUD, the overlays and the
  boatyard at once.
- No costs, parts, labour or time.

*Verified:* `test_upkeep` "[repair]", `test_upkeep_ui` "[boatyard]".
*Visually reviewed:* `93`, `94`.

## 8. Rescue transaction

- `GameSession.rescue()` is called when damage brings the condition to 0. One
  transaction applies everything to the state at once, so no save can hold half
  of it:
  - the fee is `min(1000, funds)`;
  - the voyage and the planned route are cleared;
  - the boat is moored in **Copenhagen** at its position, with the propulsion
    and exposure reset;
  - the condition goes back to 100 %;
  - the player is put in the cabin at spawn `start`, time runs at 1× (a player
    pause stays), and the rescue is recorded.
- Then it emits `rescued`.
- **Exactly once:** `rescue()` does nothing unless underway, and the voyage is
  gone after it. `Simulation.advance()` stops immediately with `STOP_RESCUE`,
  whatever was asked, so no 20× frame, long advance or sleep continues the
  abandoned voyage.
- **Dialog** "Rescued at Sea": what happened, return destination Copenhagen, the
  fee and the remaining funds.
  - The game stays paused under it, also during the screen change
    (`App._rescue_open`).
  - Continue resumes at 1×.
  - A sleep that ends in a rescue shows only this dialog.
- Kept: the boat, the companion, the funds after the fee, the provisions (minus
  the elapsed time), other boats' condition, settings.

*Verified:* `test_upkeep` "[rescue]":
- normal time, sleep, 20×, a 48 h advance;
- shortly before arrival, exactly one of arrival or rescue happens;
- the same boat (Halcyon or Petrel) and the same companion (dog) are kept;
- 100 %, cabin, 1×, one record;
- a rescue in harbour is impossible;
- a second rescue brings €8,000;
- "[saves] after loading a rescued game: no second rescue or fee".

`test_upkeep_ui` "[rescue]" checks the dialog text, that the game is paused, that
no time passes, Continue, the HUD in Copenhagen, and the sleep case.

*Visually reviewed:* `97_rescue_dialog`, `98_copenhagen_after_rescue`.

## 9. Funds and rescue fee

- `SessionState.funds`: €10,000 at the start, shown in the HUD and the boatyard.
- Each rescue costs €1,000. With less than that, the rescue still happens and
  takes what is there, so funds never go negative.
- No other transaction exists: voyages, repairs, restocking and changing boats
  are free.

*Verified:* `test_upkeep` "[money]":
- with €600, the fee is €600 and €0 is left;
- with €0, the rescue is free and funds stay €0;
- €10,000 is unchanged after a voyage, a repair, restocking and a boat change.

## 10. Provisions

- `Provisions`: food and water in fractional days, 14 each at the start
  (capacity 14).
- **Consumption** is in `GameSession.apply_simulation_step()`: elapsed / 86,400
  days of each for every advance of game time, moored, underway or sleeping.
  - Pausing stops it, because no time passes.
  - Sleeping while paused uses the hours slept.
  - Stores are clamped at 0, and the shown values are rounded down (never a
    free tenth).
- **Warnings**, once each until the stores change:
  - low at ≤ 3 days;
  - critical at ≤ 1 day;
  - empty at 0.
- **Empty stores** never hurt the player or the boat and never trigger a
  rescue. A voyage underway continues, but `depart()` refuses until restocked.
- No hunger, thirst, health or pet food.

*Verified:* `test_upkeep` "[provisions]":
- one game day uses exactly 1.0;
- 6 h use 0.25;
- paused frames use nothing;
- 12 h of sleep while paused use 0.5;
- underway works the same;
- 1×, 20× and one step agree;
- each warning comes once;
- never below 0;
- the boat is not damaged;
- no departure when empty;
- the voyage continues when empty at sea.

## 11. Provision inspection and cabin visuals

- **Station:** every cabin (Starling, Halcyon, Petrel) has a provisions station
  at the galley. Its prompt is "Check provisions".
- **Panel:** **Provisions** shows `Food 13.5 days`, `Water 13.5 days`,
  `Endurance 13.5 days`, each level (Full / Moderate / Low / Empty), a harbour
  note, and Restock.
- **HUD:** `Food 13.5 d · Water 13.5 d` at all times.
- **Cabin graphics:** `ProvisionDisplay` draws four food crates and four water
  cans on the galley counter, each standing for 3.5 days.
  - They empty to outlines as stores are used, and turn amber when low and red
    when empty.
  - They follow the real quantities, including continuous use.
  - Replaceable by `cabin/provisions_<level>.png`.

*Verified:* `test_upkeep_ui` "[provisions]" (inspect, sleep 12 h, inspect,
−0.5 day), "[supplies]" (full 4/4, moderate 2/2, low 1/1, empty 0/0; a crate
empties as time passes; a restock refills it), "[cabins]" (on all three boats
the station is reachable, the display is beside it, and the panel opens).

*Visually reviewed:* `89`, `90` (before and after sleep), `91`, `92` (full and
low).

## 12. Restocking

- **Restock provisions (free)** is offered in the provisions panel and in the
  boatyard, only when moored in harbour.
- It is re-checked when used, and refused underway or when already full.
- It returns food and water to 14 days, clears the warnings, and updates the
  numbers and graphics at once. The result is saved.

*Verified:* `test_upkeep` "[restock]", `test_upkeep_ui` "[restock]",
"[boatyard]", "[supplies]".

## 13. Severe-weather test tools

- **Opening it:** run the project from the Godot editor (F5) and press **F9**
  (or pause menu → **Developer tests**). The panel is titled "DEVELOPER TEST
  TOOLS" and states that it is not part of the game.
- **Weather:**
  - Normal weather (removes test weather);
  - Strong winds (a gale around the boat);
  - Severe storm at the boat;
  - Thunderstorm / severe squall at the boat;
  - Storm 20 nm ahead on the course.
- **Condition:** 100 / 75 / 40 / 15 / 1 %.
- **Rescue test:** at sea, 1 % plus a storm. The real damage reaches 0 at the
  next evaluation point (≤ 5 game minutes) and the real rescue runs.
- **Provisions:** 3 days, 0.5 day, empty, full. **Time:** advance 1, 6 or 24 h
  through the normal simulation.
- **Live status:** the active test weather, the wind, gusts, label and hazard
  at the boat, the condition, funds, rescues, stores and time.
- **Real game:** scenarios are `WeatherFixtures` events (moved from
  `tests/helpers` to `src/dev`) in the one `WeatherModel`, at full strength at
  once. The boat sails in them, the chart and Weather tab show them, and
  warnings and damage follow. They are repeatable: the same state gives the
  same weather.
- **Isolation:**
  - `DevTools.is_enabled()` requires a debug build of the editor binary
    (`OS.has_feature("editor")`), and `-- --no-dev-tools` turns it off.
  - Exported games have no panel and no pause-menu button, and the actions
    refuse.
  - Test weather is not session state: it is never saved, and it is removed by
    Normal weather, New Game, Load and Main menu.

*Verified:* `test_upkeep_ui` "[dev]":
- all buttons are present and the panel shows its state;
- the storm on the course needs a course;
- the route forecast and chart see it;
- the squall gives a real warning and a squall classification;
- test weather has no event data in the save;
- Normal weather and Load remove it;
- activating a scenario twice gives the same weather;
- in a player's build F9 does nothing, there is no button, and nothing can be
  activated.

*Visually reviewed:* `95_test_storm_chart`, `96_test_squall_chart`.

## 14. Halcyon proportion corrections

| | Before (I004b) | After (I005b) |
|---|---|---|
| Hull cabin width | 100 units (~1.25 m) | 152 units (~1.9 m) |
| Owner's berth | 145 × 92 | 160 × 132 (~2.0 × 1.65 m) |
| Guest berth | 130 × 92 | 146 × 124 |
| Galley, settee, nav desk, wardrobe, desk, sofa depth | 26 units | 44 units (~0.55 m) |
| Saloon table | 110 × 40 | 120 × 56 |
| Heads / shower | 90 × 30 / 50 × 44 | 100 × 44 / 50 × 60 |
| Exit | sliding door, chevrons, "TO DECK" over the floor | lit doorway frame, the cockpit beyond, bigger chevrons, "TO DECK" beside the door (not under the player) |
| Camera zoom | 1.3 | 1.2 (the wider cabin fits between HUD and prompt) |

- The saloon, the two-hull layout and every station, spawn and companion spot
  were kept. Both berths fill their hull's width at the aft end.
- The galley gained a pantry (the provisions station).
- Collision and art come from the same generator data, so they still match
  (tested). The art templates were re-rendered.
- The exterior and performance are unchanged.

*Verified:* `test_catamaran_cabin` (56 checks):
- the door and its prompt;
- art matches collision;
- the new checks: hulls ≥ 140 wide, berth ≈ 2 m × 1.6 m, furniture ≥ 40 deep;
- walking into both hulls and back with real input;
- every fixture reachable;
- nav station, sleep and wake;
- companion spots.

*Visually reviewed:* `51_catamaran_cabin`, `99_halcyon_cabin`,
`100_halcyon_cabin_exit` and the template. **Whether the proportions now look
right is for the owner to judge on Windows.**

## 15. Companion interaction corrections

- **Root cause:** nearest-centre focus with no priority (§2), plus two
  unreachable berth spots.
- **Fix (one general rule, no per-station exceptions):**
  - `Interactable.focus_priority` is 0 for all stations and doors, and −1 for
    the companion.
  - `InteractionSensor.choose()` adds 60 px of distance per priority step, so a
    station the player stands at keeps the focus.
  - When the player **faces** the companion (within ~45° of the facing arrow),
    the margin is dropped and it competes on plain distance: step up to the
    cat, face it, pet it.
  - Prompt and action always come from the same choice.
- Station-to-station behaviour is unchanged, since they all share priority 0.
- The berth spots on the Starling and Petrel (and the Halcyon's, with the new
  layout) were moved to the walkway end of the berth, within reach.
- The companion's art, poses, petting, purr, hearts and the dog are unchanged.

*Verified:*
- `test_upkeep_ui` "[companion]": on all three boats, for every resting spot
  and every station, each station stays usable, and the cat can be petted at
  every spot (geometry analysis over all reachable standing places).
- In play: the cat by the Starling's galley, the prompt "Check provisions" and E
  opens provisions; a step over, facing the cat, "Pet cat" and E pets.
- `test_life_aboard`: cat vs. chart table, berth, wake-up spot and
  companionway, for cat and dog.
- `test_gameplay_flow`: station-to-station choice unchanged.

*Visually reviewed:* `101_cat_near_provisions`.

## 16. Boatyard sizing correction

- The panel has a fixed `PANEL_SIZE` of 1180 × 860. It is made smaller only to
  fit a smaller window (`_fit_panel`).
- **Fixed parts:** title, intro, the boat list, the comparison table, the
  services row (status, Repair, Restock) and the buttons.
- **Variable part:** the boat details (name, hull type, condition, description,
  specs) sit beside the preview in a scroll area. It never widens the panel:
  horizontal scrolling is "never shown" and the spec values wrap.
- **Verified:** `test_upkeep_ui` "[boatyard]":
  - identical panel position and size for all three boats, at 100 % and 130 %;
  - all buttons inside the panel and on screen;
  - each boat's own condition shown;
  - repair and restock work and update at once;
  - Close.
- `test_vessels` (browsing, choosing, refused underway) still passes.
- *Visually reviewed:* `102`–`104_boatyard_*`. The first rendered pass showed
  the details pushed below the preview (needing a scroll); they were moved
  beside it.

## 17. Chart stability regression

- The chart was not modified.
- Existing checks pass (`test_chart_and_pause`):
  - the same sidebar, header, tabs and footer on every tab;
  - 20× with changing wind, speed, ETA and sail/engine;
  - destinations and drafts;
  - 80 % and 130 % interface scale;
  - 1366 × 768.
- **New:** with test weather listed (a storm ahead and a squall at the boat),
  the sidebar and its footer keep their size on every tab
  (`test_upkeep_ui` "[chart]").

## 18. Save migration

- **Version 7:**
  - `economy.funds`;
  - `provisions` (food, water, warning level);
  - `rescue` (count, last);
  - in `vessel`: `conditions` (by id) and `damage_applied_until`.
- All are required on load.
- **`_migrate_6_to_7`** (chain 1 → … → 7) gives older games what a new game
  has: €10,000, 14 days, every boat at 100 %, no rescues, damage counted from
  the saved time. Voyages underway, the boat, companion, harbour, time, seed,
  warnings and pause are kept.
- Test weather is never part of the state.
- *Verified:* `test_upkeep` "[saves]" (saved in a storm, loads, continues
  exactly; after a rescue nothing repeats), "[migration]" (a v6 save underway on
  the Petrel). `test_weather` (v5 → 7 chain), `test_voyage_persistence` and
  `test_save_manager` pass. The restart check covers two processes (§22).

## 19. Determinism verification

See §5 and §10.
- Damage, position, stores and exposure are identical across 1×, 5×, 20×, a
  large advance, sleep and save/load midway.
- Rescues happen at the same evaluation point whatever the step size.
- The developer weather scenarios are repeatable.

## 20. Headless test results

<<HEADLESS>>

## 21. Full rendered test results

<<RENDERED>>

## 22. Restart test results

<<RESTART>>

## 23. Screenshot review

<<SHOTS>>

## 24. Windows acceptance instructions

[WINDOWS_ACCEPTANCE_I005.md](WINDOWS_ACCEPTANCE_I005.md): sections A (starting
state) to I (persistence). Each has steps, the expected result, what to
screenshot and the pass criterion. They use only the game and the F9 panel; no
script editing.

## October 24 Windows Playtest Findings — Resolution

| Finding | Observation | Root cause | Correction | Automated verification | Visual evidence | Owner to verify |
|---|---|---|---|---|---|---|
| Provisions not verifiable | Food, water and endurance could not be seen | Not implemented (the build was I005a) | Provisions system, the cabin station and panel, the HUD line, supply graphics, restocking | `test_upkeep` "[provisions]"/"[restock]", `test_upkeep_ui` "[provisions]"/"[supplies]"/"[cabins]" | 89–92 | Checklist B |
| Damage and rescue not verifiable | No damage seen; no easy way to make dangerous weather | Not implemented; rare weather | Condition, weather damage, overlays, repair, rescue and fee; F9 test tools (storms, squalls, condition, rescue test) | `test_upkeep` "[damage]"/"[time]"/"[rescue]"/"[money]", `test_upkeep_ui` "[damage]"/"[rescue]"/"[dev]" | 80–88, 95–98 | Checklists C, D |
| Halcyon interior disproportionate | It still looked wrong after I004b | Hull passages 100 wide (1.25 m), furniture 26 deep, small berths | Hulls 152, furniture 44 deep, berths 160×132 and 146×124, a clearer exit | `test_catamaran_cabin` (proportion checks added) | 51, 99, 100 | Checklist E (aesthetic judgement) |
| Cat blocks interactions | Stations unusable with the cat nearby | Nearest-centre focus without priority; two unreachable berth spots | `focus_priority` and facing rule; spots moved | `test_upkeep_ui` "[companion]", `test_life_aboard` | 101 | Checklist F |
| Boatyard resizes | The panel changed size between boats | No fixed size; content dictated the width and height | A fixed 1180×860 panel, details in a non-widening scroll area, a services row | `test_upkeep_ui` "[boatyard]" (100 % and 130 %) | 102–104 | Checklist G |
| Persistence | Worked | — | Extended to v7; restart check extended | `test_upkeep` "[saves]"/"[migration]", restart check | — | Checklist I |

## 25. Known limitations

- **Balancing:** the damage rates are a first balance and were not playtested
  over long passages. The table in §4 is the reference for tuning
  (`src/sailing/weather_damage.gd`).
- **Damage model:**
  - damage is sampled at the boat's position at each evaluation point (it moves
    up to ~1 nm in 5 minutes);
  - the last partial interval before an arrival (≤ 5 minutes) is not charged;
  - condition is one general value; there is no hull, engine or sail damage,
    no maintenance or repair cost, and no income.
- **Rescue:** always to Copenhagen, with no towing time. The player is placed
  in the cabin.
- **Provisions:** food and water always fall together (the same rate) and are
  only restocked in full.
- **Damage art:** the overlays are procedural placeholders; the marks fall
  anywhere on deck, including the trampolines.
- **Companion:** petting a cat beside a station needs a step and a turn to face
  it. This is deliberate, but new to players.
- **Developer tools:** the panel needs the Godot editor binary. Production
  isolation was tested with the tools forced off (`DevTools.force_enabled`),
  not with an exported Windows build.
- **Cabins:** the Halcyon's proportions are improved by measurement. The
  owner's aesthetic acceptance is pending. The Starling and Petrel layouts are
  unchanged apart from the pantry station.
- **Platform:** not run on Windows.

## 26. Files modified

Compared with `4cecf06` (I005a).

**Added**
- `src/core/provisions.gd`, `src/core/vessel_condition.gd`
- `src/sailing/weather_damage.gd`
- `src/boat/provision_display.gd`, `src/boat/visuals/damage_overlay.gd`
- `src/ui/provisions_menu.gd/.tscn`, `src/ui/rescue_dialog.gd/.tscn`
- `src/dev/dev_tools.gd`, `src/dev/dev_test_panel.gd`
- `src/dev/weather_fixtures.gd`, moved from `tests/helpers/`
- `tests/suites/test_upkeep.gd`, `tests/suites/test_upkeep_ui.gd`
- `WINDOWS_ACCEPTANCE_I005.md`, `ITERATION_005B_REPORT.md`
- screenshots `docs/screenshots/80`–`104_*`
- `.uid` files for the new scripts

**Modified**
- Core and simulation: `src/core/session_state.gd`, `game_session.gd`,
  `simulation.gd`; `src/persistence/save_manager.gd` (v7);
  `src/navigation/vessel_profile.gd` and `data/vessel/halcyon_40.tres`,
  `petrel_36.tres` (damage factor).
- Interaction and companion: `src/interaction/interactable.gd`,
  `interaction_sensor.gd`; `src/player/player.gd` (facing accessors);
  `src/companion/ship_companion.gd` (priority).
- Visuals: `src/boat/boat_area.gd`; `src/boat/visuals/vessel_visual.gd`,
  `vessel_visual_profile.gd`.
- UI: `src/ui/hud.gd/.tscn`, `boatyard_menu.gd/.tscn`, `pause_menu.gd`;
  `src/app/app.gd`.
- Cabins: `src/vessels/starling_33/cabin.tscn` (pantry station and display,
  berth spot); `halcyon_40/cabin.tscn`, `cabin_visual.tscn` and
  `petrel_36/cabin.tscn`, regenerated by `tools/vessels/build_multihull_scenes.py`
  (updated); `assets/vessels/*/templates/cabin_*.png` (re-rendered).
- Tests: `test_runner.gd` (new suites, `press_key`), `restart_check.gd`,
  `test_gameplay_flow.gd` (the state comparison allows the stores used since
  loading), `test_catamaran_cabin.gd` (proportion checks), `test_dev_guides.gd`
  (new documents).
- Docs: `README.md`, `ARCHITECTURE.md`, `DEV_GUIDES/README.md`, `WEATHER.md`,
  `VESSEL_ART.md`, `COMPANION_ANIMATION.md`.
- Existing screenshots in `docs/screenshots/` refreshed from the rendered run.

The owner's artwork (`Visuals/`) is untouched.

## 27. Git branch, commit and push status

<<GIT>>
