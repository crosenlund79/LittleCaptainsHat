# Testing across iterations

How Little Captain's Hat is tested, from Iteration 001 to today. Each release's own results are in its report in the [Ship's Library](../README.md). This page describes the tools they all share.

## The automated test runner

```sh
godot --headless --path . res://tests/test_runner.tscn                      # every suite
godot --headless --path . res://tests/test_runner.tscn -- --only=anchorage  # suites whose file name contains "anchorage"
godot --path . res://tests/test_runner.tscn -- --screenshots=/some/dir      # rendered, saving screenshots (e.g. under Xvfb)
```

- The suites are in `tests/suites/` and listed in `tests/test_runner.gd`. Shared helpers are in `tests/helpers/`: walkability flood fill, the reel helper, and the Sprite Workshop art fixtures.
- Tests use scratch saves and settings (`user://test_saves`, `user://test_settings.cfg`) and never touch the player's own.
- The exit code is 0 only if every check passed. The latest full results (check counts, run time) are in the newest release report.

## Harnesses that run outside the runner

Each is a scene in `tests/` with the exact command in its header comment.

| Kind | Scenes | What they show |
|---|---|---|
| Restart (two separate processes) | `restart_check`, `restart_17`, `restart_18`, `restart_105b` | Saves and settings survive quitting and starting again. Run `--phase=write`, then `--phase=read` (0.105b adds the art install/import/remove phases). |
| Screenshots | `screenshots_16`, `screenshots_17`, `screenshots_18`, `screenshots_105b` | Rendered evidence for each release, written to `docs/screenshots/…` or a given folder. |
| Benchmarks | `benchmark`, `benchmark_17`, `benchmark_18`, `benchmark_105b` | Frame times under a software renderer, for before/after comparison only. Results are in [docs/benchmarks](../benchmarks/). |
| Measurements | `pacing_18`, `cabin_light_18` | Long Passage stop counts; cabin light and shadow figures. |

## Windows acceptance

Every release has a checklist for the Captain's own Windows trial, kept in that release's folder (for example [0.105b](../revisions/v0.105b/WINDOWS_ACCEPTANCE_0_105B.md) and [Iteration 18](../iterations/i018/WINDOWS_ACCEPTANCE_18.md)). Acceptance is never claimed before the Captain's own results come back.

## Documentation checks

```sh
python3 tools/docs/check_links.py   # every internal Markdown link and #heading anchor resolves
```

`test_dev_guides` also checks every link and repository path in the developer guides and in a set of linked documents.
