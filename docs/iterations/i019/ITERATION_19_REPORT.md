# I019 — The Captain's Watch (0.106a)

Part of *Operation Three Watches* (Turbocharge → I019 → I020). Starting
point: the Turbocharge build, `5b6474a` (checkpoint A,
`backup/post-turbocharge-pre-i019`). The final I019 commit is the one that
adds this report (see the git log; checkpoint B, `backup/post-i019-pre-i020`,
points at it).

**Windows acceptance is pending.** Everything below was verified on Linux
(Godot 4.7.2: headless suites, rendered runs under Xvfb with software
OpenGL). Numbers are measured unless marked otherwise.

## What the Captain gets

### 1. Traffic at sea and collision awareness

- Other vessels (cargo ships, tankers, ferries, fishing boats, sailing
  yachts) sail plausible straight tracks through navigable water: busier
  near harbours, few on the open ocean, never over land. They are made up
  where and when they are looked for (`TrafficModel`), never simulated for
  the whole world and never saved: the same ships appear after a load,
  while asleep and in Long Passage.
- **Closest point of approach** from relative motion. Three levels:
  *nearby* (within 6 nm), *caution* (passes within 1 nm in the next 45 min),
  *collision risk* (within 0.3 nm in the next 30 min). Only a moving boat can
  be on a collision course: at anchor or moored, ships are only nearby.
- A ship newly at collision risk is announced **once**: a short alarm, a
  warning ("Collision risk: the ferry Kristina will pass 0.2 nm off in about
  26 min, from the NE. Keep a sharp lookout and give way if needed."), and
  it wakes the Captain, drops accelerated time and stops Long Passage at the
  exact simulated time and position. The voyage's warned conditions keep the
  ship's key, so a load or another sleep never announces it twice.
- **Fair by design:** no ship appears out of nowhere beside the boat (a track
  starting within 12 nm stays unseen for its first hour), alerts come well
  ahead (measured 26–27 min before the closest point on 204 h of busy and
  long routes, 4 alerts), and there are **no collisions and no penalties**:
  this is awareness, not a hazard that can strike while asleep.

### 2. The radar

A compact north-up scope on deck (bottom left, beside the chartplotter) in
the HUD's own panel style, day and night: the boat in the centre, range
rings (3/6/12 nm, + and −), ships as small marks pointing where they go,
coloured nearby / caution / risk, and up to three lines ("Fishing boat
5.7 nm E, passes 3.7 nm off in 39 min") with what to do. Turned on from the
action wheel (Q → Radar); it shows by itself while a ship is a caution or a
risk underway. It asks for traffic five times a second, never every frame.
Not a certified instrument.

### 3. Anchor-drag awareness

On the existing anchor model (no second simulation; Magic Anchor
unchanged): an alarm sounds only when the concern **rises** (holding poorly,
then dragging). Holding that wavers with the gusts never wakes the Captain
twice; "The anchor is holding well again." is said once; after an hour of
good holding the next trouble is news again. Sleep is still interrupted by
the alarm (unchanged); the HUD's location line now reads "At anchor, holding
well · bound for …".

### 4. VHF calls and assistance

Now and then underway (at most one call per 6 hours of a voyage, a pure
function of the voyage, so a load never brings a different one):

- **"PAN-PAN"**: a sailing yacht a few miles off has an engine that will not
  start, a rope around the propeller or a broken rudder line, no one hurt,
  and asks a vessel to stand by until the coastguard's boat arrives (8 % of
  slots, 16 % in hazardous weather). The dialog says what is asked: heaving
  to nearby for about 2 hours (3 in bad weather), the voyage waits, the
  weather does not. **Declining is fine**: another vessel answers. Answering
  stands the boat by; when the coastguard arrives the voyage goes on by
  itself. Thanks: 4 renown and €120 (6 and €200 in hazardous weather).
- **A forecast request** from a fishing boat (12 % of slots): a quick reply,
  1 renown.
- A call not answered within an hour is taken by another vessel. A call for
  assistance wakes the Captain and stops Long Passage; a forecast request
  does not.
- **No exploits:** each call's thanks are an award with the call's id
  (`vhf:<departure>:<slot>`) in the objective progress record, paid once
  whatever is saved and loaded (tested both ways).

### 5. English and Dansk

The whole game speaks English or Dansk: menus, settings, HUD, chart and
navigation, warnings, sleep and the calendar, time controls, deck and cabin,
fishing, the galley, boat care, provisions, the Captain's Log, the Dream
World, objectives, harbour services, notifications, the radar and the VHF.

- **First launch** asks once, before anything else: "Language · Sprog",
  English / Dansk, each explained in both languages. The choice is a
  preference (`user://settings.cfg`), never part of a save.
- **Settings → Language** switches at once (no restart).
- **Values in each language's form:** 5.5 / 5,5 · 10,000 / 10.000 ·
  €1,200 / 1.200 € · "Fri 1 May 2026, 08:05 UTC" / "fre. 1. maj 2026, 08:05
  UTC" · NE / NØ · "4 h 50 min" / "4 t 50 min" · nm / sm · port / bagbord;
  plurals ("1 time", "3 timer").
- **Catalogue:** `locale/da.po`, 2,290 messages, all translated, every
  placeholder kept (checked by `tools/i18n/check.py` and the suite).
  Harbour names use Danish exonyms where Danes use them (København,
  Göteborg, Lissabon, Venedig…); ids, coordinates and saves are unchanged.
- **How it is built and maintained**, the tools and the glossary:
  `docs/technical/LOCALIZATION.md`. Built text asks for its sentence in the
  current language before values go in (`Loc.t`, `Loc.n`, `Loc.format`);
  English sentence fragments were reworked into whole sentences or plurals
  where the Danish needed it.

## Save format

Still **12**. New optional fields only, absent in older saves and read with
defaults: `anchor.alarm_level`, `anchor.good_since` (older saves take the
level from the alarm), `voyage.standby_until`. Traffic and VHF dedupe reuse
the voyage's existing warned conditions and the existing award record. A
game saved in Danish loads in English unchanged (tested).

## Tests

- New `tests/suites/test_captains_watch.gd` (43 checks): deterministic and
  bounded traffic on water, CPA geometry and the three thresholds, alerts
  once per ship and in good time on busy and long routes, sleep woken and
  Long Passage stopped by a collision risk, no repeat after a load, radar
  text and colours, anchor alarm levels and their save compatibility, VHF
  determinism and frequency, declining, answering, standing by and moving
  on, no double reward across save and load, lapsed calls, the forecast
  call.
- New `tests/suites/test_localization.gd` (28 checks): catalogue complete,
  placeholders kept, plurals, number/date/money/compass/duration formats in
  both languages, the first launch in English and in Dansk (asked once, Esc
  cannot skip it, kept, not asked again), the Settings switch, the main
  menu, settings, HUD and pause menu fitting the screen in Danish, and saves
  independent of the language.
- The test runner sets English before every suite, and treats traffic and
  VHF encounters as a fixture (`Simulation.sea_encounters`, off except in
  the two suites above), like its calm wind: older voyage-timing suites stay
  exact.
- Full regression (headless, all suites): **4,620 checks passed, 0 failed**. Canals (Kiel, Suez, Panama)
  are in the routing and world-voyage suites.

## Performance

Rendered `--turbo` probe against the Turbocharge build
(`docs/benchmarks/turbocharge_after1_rendered.json` →
`docs/benchmarks/i019_after1_rendered.json`): every frame-time scenario is
equal or a little lower (e.g. sailing 35.7 → 32.8 ms median, chart idle
46.3 → 42.4 ms, Long Passage 61.1 → 60.6 ms; differences of this size are
within run-to-run noise). The one cost is **sleep underway**: 56–58 ms →
48–106 ms in that run, the traffic checks on the evaluation grid. Tuned
afterwards (a flat pre-check per track, fewer water checks per new track):
headless, a cold query 18 → 8 ms, a warm one 0.31 → 0.19 ms, an 8-hour sleep
underway about +25–30 % over traffic off instead of +45 %. Recorded with a
further small step as entry 9 of `docs/technical/PERFORMANCE_OPPORTUNITIES.md`.

## Screenshots

`i019_01_first_launch_language.png`, `i019_02_main_menu_dansk.png`,
`i019_03_radar_dansk.png`, `i019_04_radar_english.png`,
`i019_05_vhf_call_english.png`, `i019_06_vhf_call_dansk.png`,
`i019_07_settings_dansk.png` (Linux, software rendering).

## Known limitations

- **Text written before a language switch keeps its language** until it is
  written again: notifications already shown, an open weather warning, the
  forecast line until its next refresh, and entries already in the
  Captain's Log.
- The Danish is careful but machine-made: a native read-through, especially
  of fish and place names and nautical terms, is recommended.
- The Danish overflow check covers the main menu, settings, HUD and pause
  menu automatically; other screens were looked at in screenshots only.
- Pre-existing, not I019: an open weather warning on the HUD can sit under
  the sailing panel, hiding its buttons (seen in English and Danish).
- Traffic does not manoeuvre, there is no AIS detail, and there are no
  collisions: awareness only, by design. The radar is on deck only.
- Assistance is "stand by" (one pattern) plus the forecast request; no
  towing or rescue missions.
- Coordinates (56°29.9′ N) keep a decimal point in Danish.
- Windows not verified: fonts, the first-launch picker and the radar should
  be looked at there.
