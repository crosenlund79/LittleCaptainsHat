# The Ship's Engine Room & a Little Companion Love: report

Documentation, personalized petting and test reliability. Version stays
**0.107a**, save format stays **12**. Iteration 21 is not started.
**Windows testing was not done**; everything below was run on Linux
(Godot 4.7.2, headless).

## 1. Commits

| | Commit |
|---|---|
| Starting point | `fc7d0b0` (end of I020) |
| Part A: the GDScript guides and their checker | `30556d9` |
| Part B: companion dialogue | `4b72258` |
| Parts C and D: test reliability and the small localization fixes | `1b1eb54` |
| Part E/F: integration and this report | the commit that adds this file (the branch head) |

The backup branches `backup/post-turbocharge-pre-i019` and
`backup/post-i019-pre-i020` were not touched. No history was rewritten.

## 2. Scripts inventoried

**276** GDScript files when the guides were written (Part A). **278** at the
end: Part B added `src/companion/companion_remarks.gd` and
`tests/suites/test_companion_remarks.gd`. Of the 278: 180 game scripts under
`src/`, 73 test suites under `tests/suites/`, and 25 test runners, probes,
helpers and tools (`tests/`, `tools/`).

## 3. The guides

- [GDSCRIPT_GUIDE_EN.md](GDSCRIPT_GUIDE_EN.md): for the Captain, in English.
  A tour of the ship first, then one entry per script: purpose, what it
  does, what it works with, what it keeps, when it runs, what changing it
  would affect.
- [GDSCRIPT_GUIDE_DA.md](GDSCRIPT_GUIDE_DA.md): the same, in Danish.
- [GDSCRIPT_ARCHITECTURE.md](GDSCRIPT_ARCHITECTURE.md): the developer
  reference: the autoloads, who owns which state, signals, the simulation,
  save and migration, localization, performance paths, ten cross-system
  flows, then one entry per script (role, dependencies, signals, state,
  lifecycle, invariants, tests, change risks).

They are linked from the [Ship's Library](../README.md), and the rule for
keeping them current is in [CAPTAINS_ORDERS.md](../../CAPTAINS_ORDERS.md)
("GDScript guides (the Engine Room)").

## 4. The freshness checker

`tools/docs/check_gdscript_guides.py` (Python 3 only, no Godot, no network;
Windows and Linux):

```
python tools/docs/check_gdscript_guides.py            # check; exit 1 if a review is needed
python tools/docs/check_gdscript_guides.py --acknowledge src/x.gd tests/suites/y.gd --note "what was reviewed"
python tools/docs/check_gdscript_guides.py --init --note "..."   # only when no manifest exists
```

It lists the scripts with `git ls-files` (plus new, not ignored files),
compares them with the entries in the three guides and with the manifest
`docs/technical/gdscript_guides_manifest.json` (a fingerprint of each script
as it was when its entries were last reviewed: SHA-256, line endings
normalized, so a Windows checkout gives the same answer). It reports:
scripts without an entry, duplicate entries, entries for scripts that no
longer exist, and scripts changed since their review. Reviewing and
re-fingerprinting are separate steps: `--acknowledge` refuses a script that
does not have exactly one entry in each guide, and records a note and the
date. Changing a script and only re-running `--acknowledge` is possible, but
it is a deliberate act with a note, not a side effect of a check.

## 5. Coverage

Every one of the 278 scripts has exactly one entry in each of the three
guides (278 + 278 + 278), and the checker passes at the end of this work:
"All 278 scripts have exactly one reviewed entry in each guide." The link
checker passes (0 broken links).

## 6. The companion's kind words

Petting the ship's cat or dog now, now and then, brings a short remark in a
notice, as well as the hearts and the purr or bark that were already there.

- **Where.** `src/companion/companion_remarks.gd` (`CompanionRemarks`) holds
  the lines and chooses one; `ShipCompanion.take_remark()` keeps the pace;
  `BoatArea` shows it in the petting branch, right after
  `companion.pet()` (unchanged).
- **Fits the animal.** Cats and dogs have their own lines.
- **Name and gender.** The companion's identity is read from the
  authoritative `CompanionState` through `CompanionRemarks.identity()`;
  nothing keeps a second copy. **Today the game's companion has a kind only:
  there is no name and no gender in `CompanionState` or in the New Game
  menu**, so the lines that use them cannot appear in play yet. They are
  written, translated and tested (with identities given directly to
  `CompanionRemarks`), and they are used automatically if a name and a
  gender are added to `CompanionState` later. No naming screen was invented
  here (the brief allowed no new menus). A name is inserted exactly as
  written: Danish letters, apostrophes and hyphens included.
- **Not constant, not repetitive.** At most one remark every 15 seconds (a
  quick second petting brings the hearts but no second note); the lines
  rotate, so the next remark is never the same line as the last.
- **No name hardcoded.** The old hands-full line "Snøvs gets a friendly look…"
  now says "The cat/The dog gets a friendly look…" (or the companion's name
  when it has one). No game code uses the name Snøvs.
- **Unchanged:** the hearts, sounds and alert pose, the reaction time, the
  walk pause, the hands-full rule (hat and coffee in hand: a look, no
  petting), movement and following, and the save.

## 7. Example remarks

| English | Dansk |
|---|---|
| You're looking especially cozy today. (cat) | Du ser særligt hyggelig ud i dag. |
| What a lovely little purr. (cat) | Sikke en dejlig lille spinden. |
| There's my favourite little sailor. (cat) | Dér er min lille yndlingsmatros. |
| Who's a good dog? (dog) | Hvem er en dygtig hund? |
| There's my faithful first mate! (dog) | Dér er min trofaste styrmand! |
| That tail could power the boat. (dog) | Den hale kunne drive båden frem. |
| Who's a good girl, Freja? (a named female dog) | Hvem er en dygtig pige, Freja? |
| There's my good boy, Bølle! (a named male dog) | Dér er min dygtige dreng, Bølle! |
| There's my handsome little sailor, Mis. (a named tomcat) | Dér er min flotte lille matros, Mis. |
| The dog gets a friendly look: your hands are full (hat and coffee). | Hunden får et venligt blik: dine hænder er fulde (hue og kaffe). |

In all there are 8 unnamed lines, 5 named lines, 6 gendered lines and 3
hands-full lines, 22 in all, each with its Danish translation in
`locale/da.po` (2,304 messages, all translated).

## 8. Old saves

Nothing new is saved: the rotation and the pause live in memory only.
`SaveManager.SAVE_VERSION` is still 12. A companion loaded from any save
(cat or dog) has its remarks; `test_companion_remarks` checks a round trip
through the save dictionary and that no new field appears.

## 9. The two intermittent tests

**Fish blink (`test_fishing2`, "two fish do not blink in step").** Each fish
portrait seeds its own random blink timing (`hash(species|instance id)`), and
the first blink falls anywhere between 0.8 and 6 seconds. The old check
compared only the *first* blink of two fish and failed when they happened to
fall within 0.05 s of each other. Measured with a probe over 2,000 pairs of
fish: the old check failed **44 times (2.2 %)**, by pure chance, with nothing
wrong. The new check simulates 30 seconds (not waited for) and compares the
whole blink schedules. "In step" means every blink of the second fish lands
with one of the first's, so the check fails only if that happens. Over the
same 2,000 pairs it failed **0 times** (at most 2 shared blinks out of about
6). It still catches real lock-step: two fish given the same seed are caught
**50 of 50** times, by the old check and the new one alike. The assertion was
not loosened; it now checks the whole behaviour instead of one moment.

**Companion walk (`test_cozy_patch`, "then she goes below as before").** The
test sends the cat below while the captain stays on deck, then waited real
frames, up to 20 s of wall time, for her to finish walking out. Meanwhile
the game's own follow-the-captain timer (`App._update_companion_follow`, a
random 2.5–5 s) kept running and called her back up on deck. Measured: the
walk out, petted on the way, takes 2.9 s, 6.0 s or 10.4 s depending on the
resting spot she starts from. So whether she reached the companionway before
being recalled depended on two random numbers and the machine's speed. Fix:
the walks are now stepped in game time without waiting for frames
(`_walk_on`: `ShipCompanion._process(1/60)`, at most a minute of walking),
and the App's follow timer is held still (`app.set_process(false)`) during
the walk out, since that part of the test is about the walk, not about
following. The checks are the same checks.

## 10. Repetition results

(Running: the counts are added when the repeated runs finish.)

## 11. Localization audit

The full audit is in [LOCALIZATION.md](LOCALIZATION.md), "Language
switching: what refreshes when". In short:

- **Immediately:** every control whose text is a message (Godot translates
  it again), the Settings menu's own sentences and the main menu's save
  list (both listen to `language_changed`).
- **At the next refresh:** the HUD (refreshed every frame, so at once when
  Settings closes), panels that refresh on game signals, and the companion
  remarks.
- **On reopening:** sentences built in menus left open underneath Settings.
- **Saved as rendered text:** notices already shown, a weather warning
  already on the HUD, award titles (for example "Ashore in Skagen: …"), and
  lines already in the Captain's Log voyages.
- **Keys:** everything in the save (ids for harbours, boats, fish, decor and
  so on), memorable moments (rebuilt from keys each time), and the language
  itself (a setting, never in a save).

**Fixed (small, low risk, each with a test that failed before):**

1. The boat's lighting node was named with `Loc.t("Lighting")`. In Danish it
   was "Belysning", so `BoatArea.get_lighting()` found nothing aboard: no
   contact shadows, lightning did not flash the boat's light, and
   `App.snap_light()` could not snap the light after a sleep or a load. The
   node name is now never translated.
2. The grocery store did not refresh after a sale at the fishmonger opened
   on top of it (it showed the old funds and catch). It now refreshes on
   `funds_changed` and `fishing_changed`.

Also fixed: the probe `tests/pacing_18.gd` had a parse error since I018
(an empty `if line:`); it now puts the line out before departure, as its own
loop already does after each stop.

**Candidates, recorded and not changed:** award titles saved as rendered text
(storing keys would touch the save data); `AnchorSite.describe_for_chart`
tests `begins_with("Too close")` on translated text; a few English-only texts
(the propulsion state "running", the hat story's loss messages, the Passage
Readiness summaries); open menus could refresh their sentences on
`language_changed`; and `test_captains_watch` reads `runner.get("app")`,
which is null, so its HUD radar check is always skipped.

## 12. Other tests

(Running: added when the broad regression finishes.)

## 13. Limitations

- **No name or gender exists yet.** The companion's name and gender lines
  are ready and tested, but the game has no place to give the companion a
  name or a gender. Until `CompanionState` has them, the Captain hears the
  cat and dog lines without a name.
- **Windows was not tested.** The checker is plain Python with line-ending
  normalization and should behave the same on Windows, but it was only run
  on Linux. The game itself was not run on Windows.
- **The fish-blink check is statistical by nature**: two independent random
  schedules can, in principle, coincide. Over 30 seconds the chance of every
  blink coinciding is far below one in a million (0 in 2,000 measured pairs,
  at most 2 of about 6 blinks shared).
- **The guides describe the code as written.** Where the code has a known
  oddity, the guides say so rather than hide it; they are not a promise
  about behaviour that the tests do not check.
- The localization candidates in section 11 remain to be done.
