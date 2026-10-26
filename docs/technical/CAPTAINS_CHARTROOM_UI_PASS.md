# The Captain's Chartroom: UI pass

A visual and UX pass over the game's interface: **one shared theme with two moods**, and less on screen by default. The version stays **0.105b** and the save format stays **12**. No gameplay system was changed.

**Reference images.** The two reference images named in the assignment (`LCH_UI_day_night_reference.png` and `little_captain_s_hat_fem_visuelle_retninger.png`) were **not available** in the repository or the session. This pass follows the written design rules in the assignment only. The images were not inspected.

## 1. Start and final commits

| | Commit |
|---|---|
| Start (verified equal to the remote, clean tree) | `d5e0e64` (micro-patch: cat, fish and a greener world) |
| A/B: theme foundation | `ee7bd83` |
| C: HUD and chart | `a130a9d` |
| D/E: remaining screens, adapters and transitions | `b1ebfd6` |
| F: document contrast, easing robustness, report and screenshots | the commit that adds this report (see `git log`) |

Each checkpoint was pushed on its own. Nothing was force-pushed. The Ship's Library and the micro-patch are untouched.

## 2. Screens and components modified

**Theme and settings**
- `src/ui/theme/ui_theme.gd`: new `UiTheme` autoload (section 3).
- `src/settings/settings_manager.gd`: the *Interface light* setting.
- `src/ui/settings_menu.gd`: the *Interface light* option in Settings, under Display.
- `project.godot`: one autoload line.

**HUD** (`src/ui/hud.gd`, `hud.tscn`)
- Compact route panel and slim shortcut bar.
- Warnings in a warning panel; alarms in the theme's warning colour.
- `src/ui/sailing_panel.gd`: hides its duplicate distance row; the course-change highlight uses the theme's highlight colour.
- `src/ui/passage_panel.gd`: hides lines that other panels already show.

**Navigation chart** (`src/navigation/world_map.gd`, `world_map.tscn`)
- Compact destination summary and one readiness note.
- Waypoint buttons whose labels fit; edit help only when a course exists.
- Small map controls.
- `src/harbour/harbour_facilities.gd`: `describe_services(id, brief)`, an optional short form.

**Menus**
- Title (`main_menu.tscn`), pause (`pause_menu.tscn`), new game (`new_game_menu.tscn`) and sleep (`sleep_menu.tscn`) each have one primary button. The others are quiet buttons of the same size.
- On the chart's footer, *Sleep* is now quiet and *Set sail* is the primary.

**Developer guides** (`dev_guides_menu.gd`, `markdown_lite.gd`)
- The guide list is a contents list.
- Code, links and table rules use theme colours that are readable on parchment and on slate.
- The open guide re-renders in the new colours when the mood changes, keeping its scroll position.

**Colour adapters** (fixed warm tints replaced by theme roles)
- Aboard badge, hat badge, anchor holding, galley rule and recipes.
- Boat care levels, the Captain's Log boat heading, the sail trim sketch and the action-wheel shade.

**Everything else** is restyled through the shared theme alone, with no code change:
- every window, panel, button, tab, slider, scroll bar, tooltip, popup and dialog;
- harbour, boatyard and equipment, grocery, Go Ashore, the galley, sleep, the Captain's Log, the trophy board and fishing.

## 3. Theme architecture

- **One theme, changed in place.** `UiTheme` takes the project theme (`assets/ui/next_harbor_theme.tres`) at start-up.
  - It builds its style boxes and colours **once**, from **semantic roles**: `surface`, `ink`, `heading`, `border`, `accent`, `focus`, `action`, `warning`, `caution`, `success` and others.
  - Screens keep using the existing type variations (`HudPanel`, `SectionPanel`, `MutedLabel`, `HeaderLabel`, …). A screen never names a colour.
- **Mood blending without rebuilds.** A blend value runs from 0 (day) to 1 (night).
  - A change of blend recolours the existing style boxes and theme colours in place.
  - Nothing is created and no node is restyled one by one.
  - It runs only when the blend actually changes. The test checks that nothing is restyled while the mood is steady.
- **New type variations:**
  - `WarningPanel` (warnings), `KeyBar` (shortcut strip);
  - `WarningLabel`, `SuccessLabel` (status text);
  - `MapButton`, `MapToggle` (small map controls);
  - `MenuItem` (quiet big-menu items);
  - `TocButton` (contents lists).
- **Adapters for procedural drawing and status colours.**
  - `UiTheme.color(role)` gives drawing code the current colour of a role.
  - `UiTheme.tint(control, role)` gives a single control a meaning colour that follows the mood, and can be removed again. A role of `""` puts the theme's own colour back.
  - Fixed modulates such as `Color(1.0, 0.72, 0.55)` were designed for dark panels and would vanish on parchment. They are replaced this way.
- **Instruments keep their own faces.** The fishing timing dial, the chartplotter, the galley's pan drawing and the anchor-setting bar keep their dark, high-contrast faces in both moods. They are instruments, and their legibility (especially the timing indicator) comes first.
- **Typography.**
  - Headings (`HeaderLabel`, `TitleLabel`) use **Patrick Hand**, the title screen's hand-lettered face, with Barlow as fallback.
  - Body text, data and buttons stay **Barlow**.
  - Both fonts are bundled under the SIL OFL. No script font is used for body text, and no new font was added.
- **Materials.** Subtle only:
  - 1–2 px brass/amber edges, soft rounded corners and small shadows;
  - an underlined selected tab, and a bookmark rule for the selected contents entry.
  - There are no textures, so nothing is added to `assets/` or `art_replacements/`.

## 4. Final palettes

| Role | Day: Vintage Chartroom | Night: Harbor Dusk |
|---|---|---|
| surface (panels) | `#E8D8B8` parchment | `#162D40` midnight |
| surface_raised / button | `#F2E6CC` | `#233F53` slate |
| ink (body text) | `#172D30` | `#F3E4C8` ivory |
| ink_soft (muted text) | `#4F5536` | `#A9BDCB` |
| heading | `#6B4430` teak | `#E9A84D` lantern amber |
| border / accent | `#BE914B` brass | `#8E7148` / `#E9A84D` |
| focus ring | `#A4513A` rust | `#E9A84D` amber |
| action (primary button) | `#666D47` olive, text `#F6EBD5` | `#E9A84D` amber, text `#0B1C2A` |
| warning | `#A4513A` rust | `#E9965E` |
| caution | `#8A5A1E` | `#E9C46A` |
| success | `#4F6B3A` | `#A9C98B` |
| key caps | `#785039` teak, text `#F6EBD5` | `#E9A84D`, text `#0B1C2A` |
| tooltip | `#F6EBD5` ivory | `#0B1C2A` shadow |
| code / link (documents) | `#7A3E2C` / `#2F6670` | `#E6D3A8` / `#8FC7CC` |

**Contrast.** The test computes WCAG ratios for three pairs in both moods:
- body text on panels: 10.3 by day, 11.3 by night;
- button text on buttons: 11.7 by day, 8.8 by night;
- primary-button text: 4.6 by day, 8.4 by night.

All of them are at least 4.5:1.

## 5. Information removed from the default view, and where it is now

| Was always shown | Now |
|---|---|
| HUD route panel without a course ("Planned route / No route planned / Plot a course at the chart table") | Hidden. The panel shrinks to the wind and the **Menu** button. It returns as soon as a course is planned. |
| HUD route panel underway: propulsion line and wind line | On the **sailing panel** (Speed, Wind now, Sail trim), which is always shown underway. At anchor the holding line stays on the route panel. |
| Sailing panel "To go" row (distance and ETA) | The **route panel** directly above (distance to go, ETA and progress bar). |
| Long Passage panel: distance/ETA line, progress bar, speed and wind line | The route panel and the sailing panel. |
| Long Passage panel: "Boat: hull … · Sound" | Shown only when the boat wants care or the hull is at 60 % or below. Always in the top-left status line. |
| Chart: services with their explanations, and the harbour's coordinates | **Tooltip** of the destination summary. The summary keeps the services by name and the distance. |
| Chart: up to three Passage Readiness notes | The headline and the most important note are shown, coloured by level (good, note, consider). All notes are in the **tooltip**. |
| Chart: course editing help | Shown only when there is a course to edit. |
| Title, pause and other big menus: every button in the action colour | One primary button each. The others are quiet but the same size. |

**Nothing essential is hidden:**
- weather warnings (warning panel), low stores or hull (warning colour) and the hat at risk (caution colour);
- Passage Readiness "consider" notes (warning colour, first note shown), anchor holding and fishing bites (aboard badge);
- every keyboard shortcut.

The chart sidebar's fixed geometry rule from Iteration 3b still holds: Apply, Discard, Set sail, Sleep and Back always stay in place and are disabled, not hidden. The existing tests for it pass.

## 6. Automatic and manual switching

- **Settings → Display → Interface light.** The options are *Automatic (follows the day)* (the default), *Always day* and *Always night*.
  - The setting is stored in `settings.cfg` under `[interface] ui_light`.
  - It is never written to a save. A test checks both.
- **Automatic follows the game's own daylight at the boat:** `Daylight.sun_elevation(boat position, game time)`. It does not follow the computer's clock.
  - Above +4° sun elevation the interface is day; below −6° it is night.
  - In between it blends smoothly, so dawn and dusk are gradual.
  - Without a game in progress (title screen) it is day.
- **No snapping.**
  - The mood is checked four times a second, and only a change of at least 2 % is applied.
  - A full day-to-night swing takes at least 4 real seconds, even in 20× time, after sleeping or on loading a game at night. The swing is timed in real time, so slow frames do not stretch it.
- **Open windows are not touched.** A change of mood only recolours. Windows, tabs, scroll positions, the chart's draft course, fishing and equipment all stay as they are; the test checks a Settings window across a dusk-to-dawn change. The developer guide re-renders its text at the same scroll position.

## 7. Screenshots

All 46 screenshots are rendered at 1600×900, in [docs/screenshots/chartroom_ui/](../screenshots/chartroom_ui/), by day (`_day`) and by night (`_night`). They come from the harness `tests/screenshots_chartroom.tscn` (command in its header).

| Required | Files |
|---|---|
| Deck, day and night | `01_deck_moored_*`, `07_deck_underway_*` |
| Chart, day and night | `06_chart_course_*` |
| Dream map | `10_dream_map_*` (its green, white, brown and deep-blue colours are unchanged) |
| Cabin and a station, day and night | `03_cabin_*`, `05_boat_care_*`, `19_sleep_*`, `20_galley_*` |
| Fishing interaction | `08_fishing_reel_*` (timing dial unobstructed) |
| Catch and trophy | `09_fishing_result_*`, `04_trophy_board_night` (the cod's own picture; the day shot is before the first catch, an empty board) |
| Harbour, boatyard and equipment | `15_grocery_*`, `16_boatyard_*`, `17_go_ashore_*`, `05_boat_care_*` |
| Settings and main menu | `12_settings_*`, `00_main_menu_*` |
| Developer-guide viewer | `13_dev_guides_*` |
| A popup, a tooltip and a prompt | `02_action_wheel_*` (popup), `21_warning_and_tooltip_*` (warning and a real hover tooltip), `14_toast_and_prompt_*` (toast and the E prompt) |
| Extra | `11_pause_menu_*`, `18_captains_log_*`, `22_sail_trim_*` |

## 8. Tests

**New suite.** `tests/suites/test_chartroom_ui.gd` is registered in the runner and has **34 checks**:

| # | Check |
|---|---|
| 1 | Theme and roles exist. |
| 2 | Contrast in both moods. |
| 3 | Headings and body fonts. |
| 4 | Always day and Always night. |
| 5 | The setting is saved to and loaded from `settings.cfg`, and not saved in the save game. |
| 6 | Automatic follows the boat's local noon and midnight, eases in and settles. |
| 7 | No restyling while steady. |
| 8 | An open window survives a change of mood, with its scroll position. |
| 9 | HUD: compact panel without a course, the shortcut bar, the warning panel, the course shown, no duplicates underway. |
| 10 | Chart: small controls, compact summary with tooltip, plot and apply a course, waypoint labels fit. |
| 11 | Fishing: the timing dial is shown with nothing over it. |
| 12 | Boat care opens. |
| 13 | The tint adapter follows the mood and can be removed. |

**Updated tests.**
- `test_branding`: headings are now Patrick Hand by design. Body, muted and HUD data labels are still checked to be Barlow.
- `tests/test_runner.gd`: `--only` accepts a comma-separated list.

**Focused run** (headless; checkpoint `b1ebfd6` plus later fixes). **28 suites, 1864 checks passed, 0 failed:**
- branding, settings and audio, dev guides;
- chart and pause, cockpit UI, life aboard, gameplay flow, upkeep UI, long passage, boat care, navigation views, presentation;
- fishing and fishing2, anchorage and anchor life, magic anchor, galley and anchor, captain's log, hat, sail trim, harbour life;
- save manager, **Sprite Workshop** (fallback smoke), cozy patch, sailing presentation and the new chartroom suite.

After the final document-colour and easing changes, `dev_guides` and `chartroom_ui` were run again: 117 checks, 0 failed.

**Full regression run** (headless, on the final code). **4427 checks passed and 2 failed**, so it is **not** a clean pass:
- `test_lighting`: "at Long Passage pace the light swells gently, no strobe". The largest frame step was 0.140.
- `test_living_world`: "walking swings the arms". The arm swing measured 0.00–0.59.

Both suites passed in full when run again on their own straight afterwards (96 checks, 0 failed: step 0.120, swing 0.00–0.68). Both checks measure motion frame by frame under a software renderer, and both values are near their limits. Neither involves code this pass changed (world lighting and the sailor's walk). They are reported here as timing-sensitive, not as fixed.

**The twelve requested checks**

| # | Check | Covered by |
|---|---|---|
| 1 | Startup smoke | Every rendered and headless run |
| 2 | Shared component creation | Chartroom suite |
| 3 | Day/night switch | Chartroom suite |
| 4 | Open-window transition | Chartroom suite |
| 5 | HUD | Chartroom suite |
| 6 | Chart | Chartroom suite and chart_and_pause |
| 7 | Fishing | Chartroom suite and the fishing suites |
| 8 | Cabin and equipment | Boat care and upkeep_ui |
| 9 | Menus and settings | settings_and_audio and the screenshots |
| 10 | Sprite Workshop | test_sprite_workshop |
| 11 | Overflow and contrast | Contrast ratios, label-fit check and visual inspection of all 46 screenshots |
| 12 | Save and load | Settings round trip; save_manager |

**Not done.** No Windows test was run, so Windows acceptance is **not** claimed.

## 9. Limitations

**Smaller sizes.** The screenshots and checks are at the game's 1600×900 presentation. The layouts are the existing anchored ones, and the earlier interface-scale tests (100–130 %) still pass. No separate screenshots were taken at smaller window sizes.

**Visual details**
- In the compact route panel the wind text sits at the top next to the Menu button rather than centred. This is cosmetic.
- The fishing dial, chartplotter, galley pan and anchor-setting bar deliberately keep their dark instrument faces by day.
- The weather-legend and wind-time panel on the chart is themed but not resized.

**Mood changes in the middle of a window**
- Galley recipe greying and a few other one-time colour choices take the mood they had when their window opened. They update the next time the window opens.
- The main menu is always day while no game is running (Always night still applies there).

**References.** The two reference images were not available.

## 10. Screens not migrated beyond the shared theme

These pick up the new materials and colours through the theme but received no specific layout work:
- the new-game companion choice, the save and load lists, the confirm and rescue dialogs;
- the haul-out scene's own drawing, the publish menu, the anchorage prompt, the docking arrival and diagnostics.

The Dreamer's Map sidebar keeps the full harbour text, because exploring is its purpose. Its map colours are unchanged.

## 11. Gameplay and Sprite Workshop preservation

**Gameplay is unchanged.** There are no changes to:
- physics, navigation and routing, coastlines, depth, weather, anchoring or the Magic Anchor;
- fishing mechanics or timing, the fish art, Snøvs's movement or petting;
- the economy, prices or ownership;
- save semantics or format (12), the version (0.105b) or world generation.

The only text changes are display formatting (the brief services list and the shorter button labels).

**Sprite Workshop and art are unchanged:**
- no file in `art_replacements/`, `assets/` (art), `Visuals/` or `data/` changed;
- the theme adds no texture, so no essential interface art can be replaced or lost through the replacement folders;
- `test_sprite_workshop` passes.

**Earlier work is kept:**
- the guide contents and the Ship's Library links are unchanged (`test_dev_guides` passes);
- the trophy fix still shows real fish pictures (screenshot `04_trophy_board_night`, `test_cozy_patch`).

**Not started.** Iterations 19, 20 and 21 were not started.
