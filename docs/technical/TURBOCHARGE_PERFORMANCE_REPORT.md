# Turbocharge: performance pass (Operation Three Watches, Stage 1)

A performance-only build: no new features, no balance changes, no save changes.

| | |
|---|---|
| Branch | `claude/friendly-fermat-dey23f` |
| Start commit | `08b4628` (Injection 2, The Well-Run Ship) |
| Final commit | the commit that adds this report; its full SHA is recorded in Recovery Checkpoint A (`checkpoint/post-turbocharge-pre-i019`, `backup/post-turbocharge-pre-i019`) |
| Version / save format | 0.105b / 12, both unchanged |
| Engine | Godot 4.7.2 (Linux) |
| Frame times | OpenGL 3 (Compatibility) on **llvmpipe** (Mesa software rendering) under xvfb, 1600×900, vsync off, no frame cap. For before/after comparison only; Windows performance is **not measured** |
| Script and simulation costs | headless timings (no rendering) |

**Method:**
- `tests/benchmark_wrs.gd` was extended with `--turbo`: sleep underway, sailing with the floating debris, chart zoom and pan, the Dream World map, the fishing rod, and a 10-round session with save/load and Long Passage.
- Baseline: **2 runs on the untouched start commit**, in a separate git worktree with only the probe copied in.
- After: **2 runs on the final code**.
- Results: `docs/benchmarks/turbocharge_*_rendered.json`.
- Script costs were profiled headless by timing every node's `_process`, and the weather work piece by piece (scratch probes, not committed).

## Confirmed bottlenecks (and non-bottlenecks)

| Area | Evidence | Verdict |
|---|---|---|
| **Underway sleep and Long Passage weather** | Per 5-minute evaluation point underway: route-ahead hazard scan 1.2–1.6 ms, damage grid 0.18–0.26 ms, propulsion 0.14 ms. One full weather sample costs 0.044–0.051 ms, of which object building, classification and cyclone risk are about a quarter | **Confirmed**, fixed (below) |
| Chart: 7,560 nodes | Almost all are land: three copies of 1,199 tiles for the Date Line wrap, plus the Europe and Denmark polygons. Idle chart frames cost the same as idle cabin frames (6.7 ms headless). Opening costs about 65 ms | Not a per-frame cost; opening is measurable. **Deferred** (register #4: a land-rendering rework) |
| Chart zoom and pan | Headless zoom frames 13.9 ms, against 8.3 ms without the wind layer and 6.7 ms idle | The wind arrows are rebuilt on every view change. **Deferred** (register #3: small, but changes how the arrows follow) |
| Night lighting | Night deck frames about 125 ms against about 55 ms by day, on software rendering only; the same with time stopped | Rendering under llvmpipe. **Not changed** (Harbor Dusk kept); needs a Windows measurement |
| Per-frame UI refreshes | Every script's `_process` timed headless: **0.09–0.63 ms per frame for all scripts together**, the largest the sailing panel (0.18 ms) | **Rejected**: nothing worth gaining |
| Floating debris | A fixed pool of 16; sailing with debris at 35 ms median before and after | Not a cost |
| Lifecycle and growth | 20 rounds (deck, cabin, chart, sleep) plus 10 rounds (walk, cabin, chart, sleep, save/load, Long Passage), plus repeated day/night: nodes, objects, autoload connections, orphans, audio players, tweens and static memory **flat** | No leak shown. This does not prove none exists; the probe keeps watching |

## Changes implemented

**`WeatherModel.sample_hazard()`**, a quick weather sample.

It runs exactly the code `sample()` uses for wind, gusts and hazard, but skips building the `WeatherSample` object, classifying it and computing the cyclone risk. It returns 64-bit floats: an early draft used a `Vector4`, which would have rounded the values to 32 bits and broken exactness.

Two hot paths use it:
1. `Simulation.route_hazards()` scans every step with it, and asks `sample()` only for the hazardous samples it keeps.
2. `WeatherDamage.damage_between()` uses it for speed and gusts.

**Correctness.** Results are **identical** to before. `tests/suites/test_turbocharge.gd` compares:
- 5,760 samples (474 hazardous) across seas, seasons, seeds and forecast times: all equal;
- 90 route scans (8 with hazards) on Baltic, Suez, Panama, Pacific and Kiel Canal routes, against the previous scan kept as a reference: all equal;
- 288 hours of weather damage: all equal;
- three October nights asleep underway, run twice: the same end state.

The same state, route and time therefore give the same warnings, damage and voyage as before.

## Before → after

Medians of two runs each, in milliseconds.

| Measure | Before | After |
|---|---|---|
| **8-hour sleep underway, one simulation call** | 78–93 | **56–61** (about −30 %) |
| **Long Passage simulation per frame at 12 h/s** | 8.3–9.1 | **5.8–6.3** (about −30 %) |
| Long Passage frame (on deck, median / p99 / worst) | 72 / 108 / 121 | 68 / 103 / 113 |
| Route-ahead scan, same inputs, headless | 257 (90 scans × 2) | 204 (about −20 %) |
| Sailing at 1× (median) | 36 | 35 |
| Sailing with floating debris (median) | 35 | 35 |
| Chart idle / zoom-and-pan (median) | 46 / 59 | 47 / 59 |
| Dream World map idle (median) | 101 | 100 |
| Fishing rod (median) | 61 | 63 |
| Sleep frames afterwards (8 h across midnight, median / p99) | 85 / 108 | 83 / 112 |
| Dawn and dusk in harbour (median / p99) | 61 / 151 | 58 / 151 |
| Opening the chart | 65–66 per open | 64–65 per open |
| Startup, probe start to loading done | 916–1,003 | 939–1,017 |

Rendered scenarios not touched by the change are unchanged within run-to-run noise on this renderer (±10 ms on some medians, more on single worst frames). The probe's first scenario (`walk_deck_harbour_day`) is measured while the first screen is still changing in both builds. It is comparable between builds, but it is not a clean deck walk.

## Long-session stability

Session rounds (walk on deck, cabin, chart, a 2-hour sleep, save to a test slot and load it back, a short Long Passage), two runs:

| Round | 1 | 2–4 | 5–9 | 10 |
|---|---|---|---|---|
| Walk median (ms) | 55–59 | 124–133 (night) | 55–60 | 125–131 (night) |
| Nodes | 572 | 572 (once 574, transient) | 572 | 572 |
| Objects | 3,420 | 3,420 | 3,420 | 3,420 |
| Autoload connections | 90 | 90 | 90 | 90 |
| Static memory (MB) | 230.8 | 230.8–230.9 | 230.9 | 230.9 |

The slower rounds are night, not growth: the 2-hour sleeps move the clock into the night, and night lighting is slow under software rendering. Earlier 20-round sessions and six repeated day/night cycles were flat too.

## Regression tests

Run headless on Linux: **1,872 checks in 23 suites, 0 failed.**

- `test_turbocharge` (new): 5/5.
- The 22 related suites: routing (Kiel, Suez, Panama), wind overlay, navigation views, boat care, save manager, voyage persistence, life aboard, weather, weather UI, hat, fishing, fishing 2, anchorage, joy of the journey, anchorage overlay, Magic Anchor, cozy polish, Well-Run Ship, galley and anchor, Long Passage, world voyage, gameplay flow.

The full historical suite was not run (the change is confined to the weather sampling these suites exercise).

## Unresolved issues

- Night rendering cost on software rendering (it is unknown whether it exists on a GPU).
- Chart zoom and pan rebuild the wind arrows on every view change.
- The chart rebuilds its land nodes on each open.

All are recorded in the register with their next action. Windows acceptance is pending.

## Five highest-value future opportunities

Details are in `PERFORMANCE_OPPORTUNITIES.md`.

1. **Measure on Windows first** (night lights, chart, the presentations). Everything below depends on what a real GPU shows.
2. **Chart zoom and pan:** refresh the wind arrows when the view settles (#3). Small effort, about 5 ms per moving frame.
3. **Chart land as batched canvas items instead of 7,560 nodes**, kept between opens (#4). Faster opening and fewer nodes for whole-tree work. Medium–large effort.
4. **Incremental route-hazard forecast** (#6). Could cut sleep and Long Passage weather work several-fold more, but warnings must stay identical however time is chopped. High correctness risk; needs the Captain's decision.
5. **Night lighting:** fewer shadow-casting lights, or baked shading for static fixtures, at the same look. Only if Windows shows a cost (#5).

- **Best quick optimization:** the wind-arrow refresh on chart movement (#3).
- **Best larger rework candidate:** the chart land layer as batched canvas items, persistent between opens (#4).

## Benchmark commands for future developers

```
# Before/after probe (rendered; --turbo adds this stage's scenarios):
xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
  --resolution 1600x900 res://tests/benchmark_wrs.tscn -- \
  --out=/tmp/run.json --label=after --no-time-passage --turbo
# The presentations as seen (sleep card, dawn card, voyage map):
#   ... res://tests/benchmark_wrs.tscn -- --out=/tmp/p.json --presented
# Correctness and cost guard for the quick weather path (headless):
godot --headless --path . res://tests/test_runner.tscn -- --only=turbocharge
```

Compare builds with the same probe on the same machine; for a baseline, use a git worktree of the older commit with the current probe copied in. Take at least two runs: single frames vary by tens of milliseconds on software rendering.

## Documentation

- `docs/technical/PERFORMANCE_OPPORTUNITIES.md`: the new permanent register.
- `CAPTAINS_ORDERS.md`: a working rule to keep the register current.
- `docs/technical/ARCHITECTURE.md`: *Quick samples (Turbocharge)*.
- The three GDScript guides (`GDSCRIPT_GUIDE_EN.md`, `GDSCRIPT_GUIDE_DA.md`, `GDSCRIPT_ARCHITECTURE.md`) do not exist in this repository, so the architecture document carries the update.
