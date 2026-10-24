# Developer guides

Practical, step-by-step instructions for working on Next Harbor's assets and
systems. These guides are the manual for day-to-day development: replacing
artwork, adding companion poses, changing sounds. Each guide uses the real
paths in this repository.

You can also read them inside the game. In a development build (run from the
Godot editor, or with `godot --path .`), the main menu has a **Developer guides**
button in the top-right corner. It shows these same files, so there is only one
version of each guide.

## The guides

| Guide | Read it when you want to… | Applies to |
|---|---|---|
| [SPRITES.md](SPRITES.md) | replace any artwork with a PNG: formats, transparency, import settings, sizes, alignment, fallback, common mistakes | all sprites |
| [COMPANION_ANIMATION.md](COMPANION_ANIMATION.md) | change or add the ship's cat poses, adjust their placement, prepare dog artwork | `Visuals/Cat/`, `data/companions/` |
| [VESSEL_ART.md](VESSEL_ART.md) | draw a boat's deck, cabin or sails; use the art templates; understand layouts, visual profiles and slots | `assets/vessels/`, `src/vessels/`, `data/vessels/` |
| [AUDIO.md](AUDIO.md) | replace a sound (purr, engine, storm wind, thunder, ambience, clicks); understand the audio buses | `assets/audio/` |
| [WEATHER.md](WEATHER.md) | tune where gales, thunderstorms and cyclones form, hazard levels and warnings; restyle the chart's weather; test with weather fixtures | `data/weather/`, `src/weather/` |
| [MODDING_FUTURE.md](MODDING_FUTURE.md) | keep the project open for user content later (no mod support exists) | design principles |

## Where things belong

| What | Where |
|---|---|
| Your original companion drawings | `Visuals/Cat/` (a dog later: a `Dog` folder next to it) |
| Vessel sprites (deck and cabin layers) | `assets/vessels/<vessel_id>/deck/` and `.../cabin/` |
| Art templates for drawing vessels (generated) | `assets/vessels/<vessel_id>/templates/` |
| Companion pose configuration | `data/companions/cat_visuals.tres` |
| Vessel definitions and visual profiles | `data/vessels/` |
| Sounds | `assets/audio/` (the current ones are placeholders in `assets/audio/placeholder/`) |
| Weather data (zones, seasons, cyclone basins) | `data/weather/weather_events.json` |

`<vessel_id>` is `starling_33` (monohull), `halcyon_40` (catamaran) or
`petrel_36` (trimaran).

## Finding the latest implementation documentation

- [../README.md](../README.md): what the game does, controls, how to run it.
- [../ARCHITECTURE.md](../ARCHITECTURE.md): how the code fits together (autoloads,
  scenes, state, saves, weather, vessels, visuals, audio, tests).
- `ITERATION_*_REPORT.md` in the project root: what each iteration built and
  verified. The newest one is the most current.
- The scripts have doc comments (`##`) at the top of each file.

## Keeping the guides correct

**Rule:** whenever an iteration changes an asset workflow or a system described
here, the matching guide is updated **in the same iteration**. Instructions live
in one place only:
- `ART_PIPELINE.md` in the root only points here;
- the reports describe what changed, not how to do things.

The automated tests check that every repository path written in backticks in
these guides exists (`tests/suites/test_dev_guides.gd`), so a renamed file is
noticed.
