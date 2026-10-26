# Revision 0.102b: Life at Anchor

*A small cozy revision after Iteration 14: a safe evening at anchor feels
special, and the galley can make coffee.* Not a numbered iteration;
Iteration 15 stays reserved for the performance and stability pass.

Nothing here has been accepted on Windows; that is the Captain's check with
`WINDOWS_SMOKE_0_102B.md`.

## 1. Repository verification and starting HEAD

| Check | Result |
|---|---|
| Working directory | `/home/user/LittleCaptainsHat` |
| `git remote -v` | `origin https://github.com/crosenlund79/LittleCaptainsHat` (fetch and push) |
| Branch | `claude/friendly-fermat-dey23f` |
| Starting HEAD | `10823c9` (Iteration 14 Checkpoints G and H), equal to the remote branch |
| Working tree | clean |
| Latest report, version | `docs/iterations/i014/ITERATION_14_REPORT.md`; 0.102a |
| Save format | 12 |
| `CAPTAINS_ORDERS.md` | present |
| Existing systems | anchoring (`AnchorState`, `AnchorSite`, `GameSession` anchor checks, windlass), sleeping (`Simulation.sleep`, `App.sleep_for`), the galley (`CookingMenu`, `GalleyStove`, `Recipes`), companions (`CompanionState` spots on the game clock, `ShipCompanion` poses resting / sleeping / stretching / alert), highlights (`HighlightProvider`), the session log. There was **no day/night or lighting system** (game time is UTC; scenes are lit uniformly). |

No other repository was touched; no force push, reset or artwork change.

## 2. Final version

**0.102b** (`GameVersion.MACHINE` 0.102.2; `project.godot` the same).

## 3. Save format

**Unchanged: 12.** The only new persistent data is the anchor stay's list of
quiet moments already shown (`AnchorState.moments`, at most 16 short keys),
written as an optional key: a 0.102a save without it loads with an empty
list (tested), and 0.102a ignores the key. The coffee's Log moment uses the
existing objective ledger.

## 4. Life at Anchor implementation

- **Settled at anchor** (`GameSession.is_settled_at_anchor()`): at anchor,
  holding well or fair, no alarm, and under 18 kn of wind where the boat lies.
  Worked out on every simulation step while anchored and on every anchor
  change; `anchor_life_changed` reports transitions only.
- **Time of day** without a new simulation: the local solar hour at the boat
  (UTC + longitude / 15°) gives morning (05–09), day, evening (18–22:30) and
  night (`src/aboard/anchor_life.gd`).
- **Evening atmosphere** (`src/aboard/anchor_ambience.gd`, one node in every
  boat scene): while settled, a `CanvasModulate` eases the scene to a warm
  evening, a soft blue night or a pale morning (day: unchanged); below deck a
  soft additive lamp glow over the saloon and the galley stove in the evening
  and at night. Not settled: exactly the old look. The HUD badge adds
  "a quiet evening", "a calm night" or "a still morning".
- **Wake-up**: `App.sleep_for` brackets the sleep (`begin_sleep` /
  `end_sleep`); after at least three hours asleep while settled, waking in the
  morning or day brings one line (once per local day), shown after the usual
  "You slept…" notice, with the morning tint.

## 5. Companion settling behaviour

Built on the existing `ShipCompanion` poses (no new AI, no wandering): when
the boat settles, the cat or dog stretches and curls up; while settled, rest
always turns into a nap, naps last 2.5× longer, and only a stretch comes
between them; entering the cabin at a quiet anchorage it is already asleep.
When the boat stops being settled (anchor up, dragging, a fresh breeze) it
wakes (alert, then its usual idling). The resting spot keeps following its
saved schedule, so saves and spot logic are untouched. Petting it on a
settled evening or night gives one soft line per stay.

## 6. Anchored ambience and message logic

| Moment | When | Repeats |
|---|---|---|
| settled | 20 game minutes after the anchor holds, while settled | once per stay |
| evening | first time a settled stay is in the evening (after "settled") | once per local evening |
| pet | petting the companion on a settled evening or night | once per stay |
| wake | waking settled after ≥ 3 h of sleep, morning or day | once per local day |

No moment appears while the captain sleeps; at most one is due at a time;
keys are kept in `AnchorState.moments` (saved), so reloading never repeats one;
dropping anchor anew starts a fresh stay. Lines are short observations
("The anchor holds. The sea is quiet.", "A quiet evening aboard.", "A new day
aboard. The anchor held all night."), shown as an ordinary toast for 5.5 s.

## 7. Morning Coffee implementation

- The galley prompt is now "Cook a meal or make coffee"; the panel has a
  **Make coffee** button beside the dishes (the same illustrated stove and
  highlight, no circle).
- Pressing it puts a pot on the stove (a small drawn pot with flame and
  steam, 1.4 s), then `GameSession.make_coffee()`: ten game minutes pass below
  deck and a line fits the moment (morning at a settled anchorage, at anchor,
  underway, in harbour); a mug appears beside the pot.
- The **first morning coffee while settled at anchor** is a Captain's Log
  moment, "Morning coffee at anchor" (+2 renown, once, via the existing
  ledger). Every other cup is flavour only.
- Refusals are gentle and change nothing: the stove's existing rule (always
  in harbour and at a holding anchor; underway in moderate conditions) and
  "no fresh water left aboard". No stat, inventory, ingredients or economy.

## 8. Integration points used

`GameSession` (anchor state and checks, `cooking_refusal`, `_award_once`,
`get_aboard_moments`, `notice`-style signals), `Simulation.advance` /
`spend_time_aboard` / `sleep`, `App.sleep_for` and `open_cooking`,
`ShipCompanion` poses, `AboardBadge`, `CookingMenu`, the toasts, the session
log. No new autoload or framework.

## 9. Diagnostics added

`anchor_ambience` {active, phase, hour} on each settled/unsettled change;
`anchor_moment` {kind}; `companion_settled` {kind, settled, spot};
`coffee` {context, award} or {error}. All are one line per change or action.

## 10. Tests run

- New suite `test_anchor_life` (44 checks): time-of-day rules; coffee in
  harbour (offered, brewing, ten minutes, no reward); settling (settled, no
  line at once, the companion curls up and keeps dozing); one settled line,
  not repeated; one evening line, not repeated; warm tint and lamp in the
  cabin, tint on deck; the HUD badge; petting gives one line once; nothing
  while asleep and one wake line after; the wake line once a day; morning
  coffee at anchor is a Log moment with +2 renown, a second cup gives nothing,
  the Log keeps it once; save/load at anchor after coffee keeps the moments
  and repeats nothing; a 0.102a save without moments loads; a fresh breeze
  unsettles the boat, the scene and the companion; anchor up ends the stay;
  coffee refused gently underway in a gale.
- Updated: the galley prompt in `test_galley_and_anchor`; version strings
  in `test_branding` and `test_diagnostics`.
- Focused regression (all passed): `test_galley_and_anchor` 91,
  `test_life_aboard` 113, `test_catch_and_cove_journey` 31,
  `test_companion_art` 90, `test_save_manager` 28, `test_voyage_persistence`
  37, `test_branding` 63, `test_diagnostics` 24, `test_fishing` 96,
  `test_gameplay_flow` 176, `test_harbour_life` 100.
- Full regression as a safety net (GameSession's simulation step changed):
  42 suites, **3,366 checks passed, 0 failed**. Restart check (write, then
  read in a new process): **PASS**.
- Rendered run of `test_anchor_life` (Xvfb, software OpenGL, 1600 × 900):
  44 passed, with screenshots.

## 11. Screenshot review

In `docs/screenshots/revision_0102b/`, inspected one by one:

| # | Required | File | Seen |
|---|---|---|---|
| 1 | Anchored evening aboard | `0102b_01_anchored_evening_cabin.png`, `0102b_01b_anchored_evening_deck.png` | the cabin in warm light with a soft lamp glow over the saloon; on deck a gentle warm tint; HUD "At anchor · Holding well · a quiet evening" |
| 2 | Companion settled | `0102b_02_companion_settled.png` | the cat curled up asleep on the V-berth |
| 3 | Cozy anchored message | `0102b_03_cozy_anchored_message.png` | "The anchor holds. The sea is quiet." under the first-anchorage notice; the cat napping on the settee |
| 4 | Wake-up at anchor | `0102b_04_wake_up_at_anchor.png` | "You slept 10 h…" then "You wake to the slap of small waves…"; pale morning tint; HUD "a still morning" |
| 5 | Coffee at the galley | `0102b_05_coffee_at_the_galley.png` | the pot on the flame with steam; "A pot of coffee on the little stove… Takes 10 minutes" |
| 6 | Coffee result | `0102b_06_coffee_result.png` | the mug beside the pot; "Coffee is ready… Written in the Captain's Log: Morning coffee at anchor"; "+2 renown" |

Fixed after the first review: while brewing, the panel still described the
selected dish (now it describes the coffee); the lamp glow showed rings (now
a smoother falloff); the morning tint was too faint to notice (a touch
warmer); the morning line said "in the cockpit" while the captain is below
(now "by the open hatch").

## 12. Known limitations

- The time of day is the local solar hour, not a sky simulation: no sunrise
  colours, no seasonal day length, and the chart is not tinted.
- The ambience is a whole-scene tint plus a lamp glow; there are no light
  sources or shadows (by design, the game has no lighting system).
- The companion settles in its scheduled spot; it does not walk to a cozier
  one.
- Lines are in English and few (three settled, three evening, three wake, one
  per companion when petted); they come from code (`AnchorLife`).
- Windows has not been tried; the rendered screenshots use software OpenGL.

## 13. Captain's Orders updates

`CAPTAINS_ORDERS.md` records the approval of this small revision after
Iteration 14 (0.102b), Life at Anchor as a cozy ambience feature, Morning
Coffee as a lightweight galley ritual, no major new mechanics, no change to
the roadmap's next major iteration, and that Iteration 15 remains reserved for
the performance and stability pass; plus an iteration log line. Earlier
decisions are unchanged; the Phase Two note is untouched.

## 14. Final commit and push status

| Checkpoint | Commit |
|---|---|
| A, baseline verification | no commit (verified `10823c9`, clean, = remote) |
| B and C, Life at Anchor and Morning Coffee | `d42de17` |
| D, review fixes, screenshots, documentation | the final commit on the branch |

Pushed to `origin/claude/friendly-fermat-dey23f`; the delivery message states
the final commit as confirmed on the remote. No pull request was opened.
