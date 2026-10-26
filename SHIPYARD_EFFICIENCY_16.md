# Shipyard Efficiency, Iteration 16: Where the Time Went

A short retrospective of how the development time of Iteration 16 (The World
Awaits, 0.103a) was spent, and how to spend less next time without cutting
safety. Reporting only: no gameplay, data or tests were changed for it.

## Sources and method

- **Measured**: the session transcript of Iteration 16. It timestamps every
  tool call and every result: 406 tool calls, 344 of them shell commands.
  Commands that timed themselves (`time`, test suites that print their own
  milliseconds) and git commit times are also measured. Times are UTC on
  2026-10-25/26.
- **Estimated**: the split of time across phases. Each command's duration,
  plus the gap before it (reading, thinking, writing), is attributed to the
  phase of that command, using its description. This is approximate: one
  command often edited code *and* ran a test.
- **Not available**: the duration of background jobs is not recorded in the
  transcript. A few are measured from their launch time to the moment their
  wait loop saw them finish. Model thinking time cannot be separated from
  writing time. There are no per-step CPU profiles for the builds, only
  wall-clock times.

## Overall timeline (measured)

| Event | Time (UTC) |
|---|---|
| Iteration 16 assignment received | 22:39:42 |
| Question to the Captain (Iteration 15 missing), answered "Authorize 16 now" | 22:40 → 23:15 (35.5 min waiting) |
| Checkpoint A (benchmark baseline) committed | 23:24 |
| Context summarized and work resumed | about 00:04 |
| Checkpoints B–F committed and pushed together | 00:50 |
| Checkpoint G committed | 02:00 |
| Checkpoint H and final report commit | 02:15 and 02:16:14 |

- Elapsed from assignment to final commit: **3 h 36 min**.
- Active development (excluding the wait for the answer): **about 3 h 01 min**.
- Foreground shell time: **110.6 min**, of which about **34 min** was spent
  waiting on runs that had already failed or hung (see §3).

## 1. Estimated time by activity

These are estimates, using the attribution method above, over the 3 h 47 min
from the assignment to the last log entry.

| Activity | Estimate | Share | Notes |
|---|---|---|---|
| Testing (suites, regression runs, waiting for them) | ~45 min | 20 % | measured parts in §2 |
| Waiting for the Captain's decision | ~36 min | 16 % | measured 35.5 min; not development work |
| Debugging and profiling (ad-hoc probes) | ~35 min | 16 % | 28 probe runs; includes hung probes |
| Geographic data processing (world build, land.res, harbours, labels) | ~33 min | 15 % | 8 world builds |
| Benchmarking (before/after, baseline worktree) | ~25 min | 11 % | about 16 benchmark executions |
| Reading code and planning | ~25 min | 11 % | |
| Coding | ~17 min | 7 % | understated: many edits were bundled with test runs |
| Documentation and delivery | ~6 min | 3 % | understated: long report writing shows up as gaps |
| Rendering screenshots and reviewing them | ~5 min | 2 % | two full renders of 20 shots, each about 45 s |

Coding and documentation are under-counted, and testing and data
processing over-counted, because one command often did both. The ranking of
the large items is reliable; the exact percentages are not.

## 2. The five most expensive identifiable operations (measured)

| # | Operation | Cost per run | Runs | Total |
|---|---|---|---|---|
| 1 | **Waiting on failed or hung runs**: the Long Passage suite hung after a parse error (600 s timeout); the baseline benchmark failed to parse and Godot stayed open (≈580 s); a probe opened the chart during a transition and waited forever (553 s); a profiling probe was killed by its timeout (300 s plus a 128 s wait) | 5–10 min | 4 | **≈ 34 min** |
| 2 | **Routing suite, European all-pairs check** (17,391 routes) | 469 s of the suite's 484 s | 3 (2 targeted, 1 final) | **≈ 24 min** |
| 3 | **Benchmark runs**, mostly rendered on software GL | 15–30 s headless, 60–130 s rendered | ≈ 16 executions in 10 commands | **≈ 19 min** foreground |
| 4 | **World data build** (`build_world.py`) | 76–80 s (measured with `time`) | 8 | **≈ 10–11 min** |
| 5 | **Regression runs** | 4 min 47 s without routing (measured twice); about 14 min for the full run (02:00:29 → 02:14:36) | 3 | **≈ 24 min** |

Also measured:
- The Copenhagen-to-Paradise suite took 94 s on its first run and 56 s in the
  final regression, after the weather optimization.
- A `--import` pass takes a few seconds.
- Each `land.res` conversion takes a few seconds (4 runs).
- Each push takes a few seconds.

## 3. Expensive steps that were repeated

| Step | How often | Why (from the log) |
|---|---|---|
| World data build | 8 | Three fixes to GeoJSON parsing and land loading. Three rounds of tuning the drawn layers (tile repair, slivers, simplification floor). One fix to the graph (validating the stitch edges). One coarser overview for speed. **In the last two rebuilds the raster and graph MD5s were identical**: only the drawn land changed, yet the whole build (≈ 80 s) ran each time. One labels-only change was patched without a rebuild. |
| Benchmark executions | ≈ 16 | The benchmark harness itself had bugs, found only when results looked wrong: <ul><li>it measured the international routes with the Europe-only router;</li><li>it opened the chart during the new-game transition, so the open was ignored (a bogus 34 s "chart ready");</li><li>the baseline build could not parse the newer harness.</li></ul> Each fix meant re-running both the baseline and the current build. The rest were re-measurements after each optimization (weather culling, tile batching, harbour lookup, islet redraw). |
| Ad-hoc profiling probes | 28 runs, ≈ 24.5 min | Each question (polygon errors, opening cost, frame cost by layer, process vs render time, pan cost) got a new throw-away scene. Two probes hung. |
| Routing suite | 2 targeted runs plus the final one | The all-pairs check alone is 7.8 min. The second targeted run was needed for two one-line test fixes. The first full regression was stopped after ~1.5 min once it was clear the all-pairs check had grown to ~25,000 world pairs; it was restructured to European pairs plus each international harbour from Copenhagen. |
| Regression without routing | 2 (+ the final full run) | Found 41 and then 2 failures, mostly test expectations tied to Europe-only assumptions (chart bounds, regions, version, ocean weather zones). |
| Screenshot render | 2 full renders (≈ 45 s each), plus 3 quick 5-shot renders earlier | The review found real problems: overlapping labels, unreadable island names, and screenshot-script mistakes. |

## 4. Which checks to run when

**After every change** (seconds to about two minutes):
- the project still parses: a `--import` pass, or the suite of the touched
  system, with the output checked for `SCRIPT ERROR`;
- the targeted suite for the system changed, e.g. `--only=long_passage`,
  `--only=test_regions`, `--only=test_harbours`;
- for drawing changes, one quick render of the affected view, checked for
  "triangulation failed" errors.

**At checkpoints** (minutes):
- after any rebuild of the navigation data: the graph check (every edge
  against the runtime land check, measured at about 7 s) and the routing suite's
  representative and international routes;
- the regression without the all-pairs check (`--skip=routing` plus a routing
  run that skips the pairs): about 5 min;
- a headless benchmark, as a CPU gate (≈ 20 s);
- the Copenhagen-to-Paradise suite when simulation, stores, weather or saves
  change (≈ 1 min).

**Final regression only**:
- the full suite, including the European all-pairs check (≈ 14 min);
- before/after benchmarks, headless and rendered;
- all 20 screenshots, reviewed by eye;
- the Windows checklist, which only the Captain can do.

## 5. Opportunities for caching and avoiding rebuilds

- **Stage the world build.**
  - The raster and graph depend only on the land polygons, the canal and
    the European raster. How the 80 s splits between the stages was not
    measured; the build script prints stage messages but no stage timings.
  - The drawn layers depend on the polygons and simplification settings.
  - The labels depend on one small JSON file.
  - Keying each stage on a hash of its inputs would have saved most of the
    last two rebuilds, and the deterministic MD5s already show when nothing
    changed.
- **Cache the parsed source.** Re-reading and fixing the 27 MB GeoJSON on
  every build could be replaced by a cached intermediate (e.g. a pickle of
  the fixed polygons), invalidated by the source's SHA-1.
- **Cache the all-pairs result.** The 17,391-pair result could be stored,
  keyed on the graph MD5, the harbour catalogue and the router code. It would
  re-run in full only when one of those changes; otherwise a sample would
  run.
- **Tier the tests.** Suites could be tagged fast or slow, with several
  `--only` filters per run. `--skip` was added during Iteration 16.
- **Freeze the benchmark harness at Checkpoint A** and validate it on the
  baseline immediately. Then the baseline numbers are measured once and kept,
  instead of re-run after each harness fix.
- **Make the profiling probe reusable.** One profiling scene could report:
  - frame time per chart layer;
  - Performance monitors (objects, primitives, draw calls);
  - chart open and reopen times, waiting for transitions correctly.
  It would replace most of the 28 throw-away probes.
- **Runtime caching** (already done, and worth keeping): static caches for the
  world land, Europe and Denmark shapes; per-bucket weather reach boxes; the
  binary `land.res` instead of JSON.

## 6. Recommended efficiency improvements (ranked)

| # | Improvement | Likely benefit | Risk |
|---|---|---|---|
| 1 | **Fail fast on errors.** <ul><li>The test runner quits with an error code on a script compile error instead of hanging.</li><li>Long runs always go in the background with a poll that also watches for `SCRIPT ERROR` and a hard timeout.</li><li>Probes wait for the screen router to be idle before acting.</li></ul> | ≈ 30 min (the measured waste in §2 #1) | Low |
| 2 | **Tier the routing suite.** The all-pairs check runs only at final regression, or when the navigation data or router changes (keyed on the graph MD5). Checkpoints run representative, international and Date Line routes plus the edge check. | ≈ 15 min per iteration | Low–medium: the full check must stay mandatory before delivery |
| 3 | **Stage and cache the world build** by input hash; check the MD5s after a rebuild. | ≈ 5–8 min, more when tuning visuals | Low (the output is deterministic and verifiable) |
| 4 | **Freeze and validate the benchmark at the first checkpoint**, including on the baseline build, with a "results look sane" check (e.g. chart ready under 10 s, routes OK). | ≈ 10 min of reruns | Low |
| 5 | **A reusable profiling scene** in place of ad-hoc probes. | ≈ 10 min, and faster diagnosis | Low |

## 7. Safety-critical checks: never skip these to save time

- **Every graph edge passes the runtime land check** after any change to the
  navigation data or router. This is what guarantees routes never cross land.
- **Route validation and land-crossing checks** against the drawn land,
  including the Date Line routes. There must never be a straight line over
  land.
- **Save and load compatibility.** Old saves load. A mid-ocean save and a
  save across the Date Line reload in place, with no duplicated progress or
  rewards. Two Date Line bugs were found only by this test.
- **Every harbour has a bounded approach**, and every international harbour
  is reachable.
- **The full regression before delivery**, including the all-pairs check, and
  a reviewed set of screenshots.
- **Deterministic build output** (MD5 comparison) and recorded data
  provenance and licences. No fabricated geometry; no depth claims.
- **Verify the remote HEAD after pushing.** Report a failed tag push as
  failed.
- **Windows acceptance is the Captain's trial.** Linux results are never
  presented as Windows acceptance.

Measured facts in this report come from the Iteration 16 session log and git
history. Everything marked as an estimate is an estimate. No timing
information was invented.
