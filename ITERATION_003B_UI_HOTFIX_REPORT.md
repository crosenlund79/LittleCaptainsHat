# Iteration 003b Final Hotfix: Chart UI Redesign & Simulation Pause (Report)

**Baseline:** I003b, commit `273e7f5`. This is a small hotfix on top of it; no I004
work.

**Engine:** Godot 4.7.2 stable, GDScript, Compatibility renderer.

**Test environment:** Linux container, Godot headless, plus Xvfb with Mesa llvmpipe
for rendered runs.

**Not tested on Windows.** All verification below is automated (checks and
screenshots from automated runs). The owner's Windows inspection is still to come.

## 1. Root causes identified

**Sidebar structure (I003b).** The whole sidebar (title, status, clock and time
controls, voyage, destination, course, buttons, weather, help, Back) was one long
column inside a single `ScrollContainer` in a `PanelContainer`.

- **Chart heading partially clipped.** The title was inside the scrolling column, so
  it scrolled off whenever the column was scrolled. That happens when the content is
  taller than the panel (always at 1080p, more so at larger interface scales) and the
  player or focus scrolls down to reach the buttons and weather near the bottom.
- **Awkward vertical spacing.** To stop text changes from moving buttons, I003b gave
  each changing label a fixed number of reserved lines. Short texts then left large
  empty gaps, such as 4 empty lines for weather or 3 for course status.
- **Overcrowded sidebar.** Everything was always shown in one column, including help
  text, attribution, projection info and a second copy of the time controls.
- **Panel size changes and unstable button positions.**
  - The `ScrollContainer` used horizontal scroll mode *disabled*, which passes the
    content's minimum width up to the panel. Any wider label or button text (clock,
    long status, "Plot course to …") could therefore widen the panel.
  - Its vertical scroll bar appeared and disappeared as the content height changed.
    That changed the width available for wrapping, so text re-wrapped and the
    buttons below moved.
  - Buttons sat in the middle of the column, below text whose length changes, so
    they moved whenever text above them changed its line count.
- **Separate time controls on the chart.** The chart had its own clock row with a
  second `TimeControls`. Its clock label was clipped next to the buttons ("17:3…").

**Pause.** There was no player pause: only 1×/5×/20× (`GameSession.time_scale`).
The scene-tree pause was used only while menus were open, and it intentionally
stops gameplay and the chart.

## 2. Sidebar structure before and after

**Before (I003b):**

```
SidePanel (PanelContainer)
└── Scroll (ScrollContainer, horizontal: disabled)
    └── VBox: Title · Region · Status · Position · [Clock + Pause/1×/5×/20×] · Voyage
              · Destination (title, details, Plot) · Course (label, status)
              · [Apply | Discard] · [Remove waypoint | Clear] · [Set sail | Sleep]
              · Weather · Help · Attribution · Back
```

**After:**

```
SidePanel (PanelContainer "SidebarPanel", fixed anchors: 496 × screen height − 48)
└── VBox
    ├── Header (always visible, fixed height)
    │     "Chart" · status ("Underway to Kiel · 8.2 kn under sail") · progress bar
    │     · "137 nm to go · ETA about …"      (single lines, ellipsis + tooltip)
    ├── Tabs (TabContainer, fills the remaining height)
    │     Course  : Destination (title, details, Plot course) · Course (summary,
    │               status) · [Remove waypoint | Clear course] · editing help
    │     Weather : Wind at the boat (wind, sail/engine, wind angle) · Along the
    │               course (areas, distance, time) · note        — title "Weather (n)"
    │     Details : Position · projection · help · attribution
    │     (each tab: its own ScrollContainer, horizontal disabled, vertical RESERVE)
    └── Footer (always visible, fixed height)
          [Apply course / Change course | Discard]
          [Set sail | Sleep]
          [Back to boat (Esc)]
```

**How it stays stable:**
- The panel's size comes only from its anchors. The header's one-line labels clip,
  so their minimum width is small and their height constant. All tab text wraps.
- The header and footer have constant heights, and the tabs take the rest.
- Each tab scrolls on its own, with the scroll-bar gutter always reserved, so the
  wrap width never changes.
- Switching tabs or receiving live data cannot change the panel, header, footer or
  any footer button.
- The Course tab shows the **course total** while sailing, not the remaining
  distance. Live values (remaining distance, ETA, speed) live in the header, so
  waypoint buttons do not move as the boat sails.
- Long texts are never cut inside tabs. They wrap and the tab scrolls.

**Behaviour:**
- Clicking a port, pressing the course line or selecting a waypoint switches to the
  **Course** tab.
- The HUD warning's **View chart** opens the **Weather** tab.
- The Weather tab title shows the number of weather areas the course meets, e.g.
  "Weather (1)".

**Theme.** The theme generator (`tools/build_theme.gd`) gained:
- Next Harbor tab styles: navy, brass underline on the selected tab, seafoam text;
- slim navy/seafoam scroll bars;
- a `SidebarPanel` variation (the dialog panel with tighter margins).

Palette and fonts are unchanged.

## 3. Controls moved and why

| Control | Before | After | Why |
|---|---|---|---|
| Pause / 1× / 5× / 20× | duplicated in the chart sidebar (and in the HUD elsewhere) | **only the HUD's shared time bar**, also shown on the chart (centred over the map) | one global time control in one place, as asked; the sidebar copy was cramped and clipped its clock |
| Apply/Change course, Discard | middle of the column | **footer** | essential route actions, available from every tab, never moving |
| Set sail, Sleep | middle of the column | **footer** | Sleep must be available from every tab; Set sail stays discoverable (disabled at sea, not hidden) |
| Back to boat | bottom of the scrolled column | **footer** | always reachable without scrolling |
| Remove waypoint, Clear course | middle of the column | **Course tab** | waypoint tools belong with the course; selecting a waypoint switches to this tab |
| Position, projection, help, attribution | always visible | **Details tab** | less frequently used |
| Weather along the course | bottom of the column | **Weather tab** (with wind at the boat) | weather information grouped together |
| Zoom, All Europe, Find boat, Wind | map toolbar | map toolbar (unchanged) | map manipulation stays on the map |
| Notifications on the chart | centred on the screen (could cover the sidebar at 130 %) | centred over the map | keep the sidebar header readable |

## 4. How the shared pause state is handled

- **State.** `SessionState.paused` (bool) sits next to `time_scale`; `time_scale`
  keeps the selected speed while paused.
  - It is set only through `GameSession.set_paused()`, which emits `pause_changed`.
    `is_paused()` reads it.
  - `GameSession.set_time_scale(scale)` always resumes, including when the same
    speed is chosen again.
- **Effect.** `Simulation.tick()` returns immediately while paused, and it is the
  only frame-driven advance of time. So the game clock, voyage progress, wind (a
  function of game time), propulsion evaluation, weather-warning checks and the
  companion's resting schedule all stand still. Nothing is implemented per scene.
- **Not a scene-tree pause.** The tree keeps running, so the chart (planning,
  editing, applying a course), on-board movement and menus stay interactive. The
  tree pause remains reserved for open menus, as before.
- **Control.** `TimeControls` (Pause, 1×, 5×, 20×) is one shared bar in the HUD's
  clock panel.
  - The pause button shows the standard two-bar icon. While paused it is lit, no
    speed is lit, and a brass **PAUSED** badge is shown next to the game time.
  - Pressing Pause again resumes at the kept speed; pressing a speed resumes at
    that speed.
  - The HUD layer is visible in the cabin, on deck and on the chart. On the chart,
    `Hud.set_chart_mode(true)` shows only the clock bar, centred over the map.
- **Scene transitions** do not touch the flag, so they cannot resume time. A new
  game starts running.
- **Saves.** The flag is saved as optional `clock.paused`, with no save-version
  change. Saves without it (all older saves) load running; a non-boolean value is
  rejected. A game saved while paused loads paused.
- **Sleep while paused.** Sleep is an explicit `Simulation.sleep()`.
  - It moves time on by exactly the chosen hours, stopping early on arrival or a
    warning as before.
  - It leaves the game paused, so continuous time does not start on waking.
  - The sleep dialog and the wake-up message say "Time is still paused".
- **Warnings.** A weather warning that arrives while the chart is open is kept and
  shown on returning to the boat.

## 5. Files changed

- **Chart:**
  - `src/navigation/world_map.tscn`: sidebar rebuilt as header / tabs / footer; the
    duplicate time controls removed.
  - `src/navigation/world_map.gd`: tab handling and the Weather tab's wind section.
    The I003b line-reservation code was removed; the course summary underway is
    now static.
- **Time bar and HUD:**
  - `src/ui/time_controls.gd`: Pause button and paused state display.
  - `src/ui/hud.gd`, `src/ui/hud.tscn`:
    - PAUSED badge and chart mode;
    - a warning kept while on the chart;
    - the warning panel now placed below the route panel, which also fixes an
      overlap on deck seen in the screenshots.
- **Core:** `src/core/session_state.gd`, `game_session.gd`, `simulation.gd`: pause
  state, API and tick guard.
- **App and UI:**
  - `src/app/app.gd`: HUD shown on the chart, notifications centred over the map,
    View chart opens the Weather tab, sleep message while paused;
  - `src/ui/sleep_menu.gd`: notes that the game stays paused.
- **Theme:** `tools/build_theme.gd` and the regenerated
  `assets/ui/next_harbor_theme.tres`: tab, scroll bar and `SidebarPanel` styles.
- **Tests:**
  - new: `tests/suites/test_chart_and_pause.gd`;
  - updated: `tests/test_runner.gd`, `tests/suites/test_life_aboard.gd` (chart
    geometry adapted to the new structure), `tests/suites/test_gameplay_flow.gd`
    (on the chart only the HUD clock bar is shown).
- **Docs:**
  - `README.md`, `ARCHITECTURE.md`, this report;
  - screenshots 33–38 added and existing ones refreshed.

Unchanged, as required:
- wind, polar and speed, engine switching, helm re-evaluation;
- sail animation and spinnaker;
- companion, sleep-duration selection, V-berth wake-up;
- routing, save slots.

## 6. Tests performed and results

| Run | Result |
|---|---|
| Headless suite (`godot --headless --path . res://tests/test_runner.tscn`) | **842 checks passed, 0 failed**, exit 0, no leaks |
| Rendered suite under Xvfb (`--rendering-driver opengl3`, screenshots) | **849 checks passed, 0 failed**, exit 0 (includes the 1366×768 window checks). This run was made before the last check was added to the gameplay flow ("View chart opens the Weather tab"); that check passes in the headless run above. |
| Restart check (two processes) | **15/15 passed** |

**New suite `test_chart_and_pause`** (80 checks headless). Per acceptance item:

1. **Title visible.** The "Chart" title lies fully inside the sidebar and on screen
   at full height, at 100 %, 80 % and 130 % scale, and in a 1366×768 window
   (rendered run).
2. **Same size on every tab.** Switching between Course, Weather and Details
   leaves the sidebar, header, tabs, footer, title and the five footer buttons
   identical (to 0.5 px).
3. **Live values move nothing.** Twelve 20-minute steps at 20× with changing wind
   and sail/engine left the sidebar, header, footer and the Course tab's buttons
   unmoved. The header shows status, distance and ETA.
4. **Route editing works.**
   - Clicking a port switches to Course.
   - Plot course, then add and remove a waypoint.
   - "Change course" in the footer applies the new course.
   - Unusable actions are disabled, not hidden.
5. **Weather warnings accessible.** The Weather tab title shows "Weather (1)" and
   the list shows "Strong winds (caution)". The wind at the boat is shown. View
   chart opens this tab (checked in the gameplay flow).
6. **Sleep accessible.** Sleep is visible in the footer on every tab. Sleeping from
   the chart is covered by `test_life_aboard`.
7. **Map controls work.** Zoom in and out, Find boat, drag to pan and the Wind
   toggle all work. Each map control sits outside the sidebar.
8. **Pause from cabin, deck and chart.** Clicking Pause in the HUD time bar pauses;
   it is lit, no speed is lit, and the PAUSED badge shows.
9. **Nothing moves while paused.** With the clock running per frame, game time,
   voyage progress, wind at the boat and the companion state stay identical.
10. **Chart interactive while paused.** Plotting and applying a new course works
    and no time passes.
11. **Resume restores speed.** Pause again resumes at 20×. Choosing 5×, or the same
    5× again, resumes at 5×.
12. **Scene changes keep the pause.** It holds across deck → cabin → chart → boat.
13. **Sleep while paused.** It moves time on by exactly 2 h, the game is still
    paused afterwards (and says so), and no time passes in later frames.
14. **Save and load.** A game saved paused loads paused, with the time bar showing
    it. Saves without the flag load running; an invalid flag is rejected; a new
    game starts running.
15. **Existing tests pass.** All earlier suites pass. Two existing checks were
    adapted to intended changes: the chart now shows the HUD's clock bar; the I003b
    chart geometry test uses the new parts.

**Visual verification** (screenshots from the rendered run, reviewed):
- `33_chart_sidebar_course`, `34_chart_sidebar_weather`, `35_chart_sidebar_details`:
  the three tabs at 1920×1080, title fully visible, footer fixed;
- `36_chart_sidebar_scale_130`: 130 % scale; the Course tab scrolls inside, the
  footer and header stay complete;
- `37_deck_paused`, `38_chart_paused`: the PAUSED badge and lit Pause button on deck
  and on the chart.

## 7. Remaining limitations

- **Not tested on Windows.** I have not seen the layout on a real Windows display,
  at real DPI settings or on a real GPU. Smaller windows were checked only at
  1366×768 under Xvfb, and only with the default "canvas items / expand" stretch.
- **Scrolling at 130 %.** The Course tab needs a little scrolling to reach its
  editing help text. The waypoint buttons stay visible at 1080p.
- **Header text can be cut.** Very long status texts (e.g. a long destination name
  combined with "under engine") are cut with "…" in the header; the full text is in
  the tooltip.
- **Sail motion while paused.** Sail "breathing" is cosmetic and runs on real time,
  so it continues while paused, as does the engine sound if motoring. Simulation
  state does not change.
- **No keyboard shortcut for Pause.** None was requested.

## 8. Commit and push status

See the summary given with this delivery. The commit message is
"Iteration 003b - chart UI redesign and simulation pause", pushed to
`claude/determined-brahmagupta-3v95mx`.
