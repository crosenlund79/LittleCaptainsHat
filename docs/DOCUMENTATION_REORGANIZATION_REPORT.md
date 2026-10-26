# Documentation reorganization: the Ship's Library

A documentation-only side quest on `claude/friendly-fermat-dey23f`, starting from `87abe4e` (version 0.105b, clean tree, equal to the remote).

- **No gameplay code, resources, version or save format changed.**
  - The game is still **0.105b** (`GameVersion.DISPLAY`, `project.godot`).
  - The save format is still **12** (`SaveManager.SAVE_VERSION`).
- The only code-file edits are path text in comments, in one test's list of document paths, and in one tool's message string. These are listed under §5.

## 1. Original root Markdown inventory

44 Markdown files were in the root at the start:

| Group | Files |
|---|---|
| Kept in the root | `README.md`, `CAPTAINS_ORDERS.md` |
| Iteration reports | `ITERATION_001_REPORT.md`, `ITERATION_002_REPORT.md`, `ITERATION_003_REPORT.md`, `ITERATION_003B_REPORT.md`, `ITERATION_003B_UI_HOTFIX_REPORT.md`, `ITERATION_004_REPORT.md`, `ITERATION_004B_REPORT.md`, `ITERATION_005A_REPORT.md`, `ITERATION_005B_REPORT.md`, `ITERATION_005C_REPORT.md`, `ITERATION_006_REPORT.md`, `ITERATION_12_REPORT.md`, `ITERATION_13_REPORT.md`, `ITERATION_14_REPORT.md`, `ITERATION_16_REPORT.md`, `ITERATION_17_REPORT.md`, `ITERATION_18_REPORT.md` |
| Iteration assignments and requirements | `ITERATION_17_ASSIGNMENT.md`, `ITERATION_17_REQUIREMENTS.md`, `ITERATION_18_ASSIGNMENT.md`, `ITERATION_18_REQUIREMENTS.md` |
| Windows checklists | `WINDOWS_ACCEPTANCE_I005.md`, `WINDOWS_ACCEPTANCE_I006.md`, `WINDOWS_ACCEPTANCE_VISUAL_V01.md`, `WINDOWS_ACCEPTANCE_12.md`, `WINDOWS_ACCEPTANCE_13.md`, `WINDOWS_ACCEPTANCE_14.md`, `WINDOWS_ACCEPTANCE_16.md`, `WINDOWS_ACCEPTANCE_17.md`, `WINDOWS_ACCEPTANCE_18.md`, `WINDOWS_SMOKE_0_102B.md`, `WINDOWS_ACCEPTANCE_0_105B.md` |
| Revisions | `VISUAL_IDENTITY_V01_REPORT.md` (0.100a), `VISUAL_POLISH_0100B_REPORT.md` (0.100b), `REVISION_0_102B_REPORT.md`, `REVISION_0_105B_ASSIGNMENT.md`, `REVISION_0_105B_REPORT.md`, `REVISION_0_105B_REQUIREMENTS.md` |
| Technical, art and process | `ARCHITECTURE.md`, `ART_PIPELINE.md`, `SPRITE_WORKSHOP_REPORT.md`, `SHIPYARD_EFFICIENCY_16.md` |

Other documentation already in folders, all left in place:

| Location | Contents |
|---|---|
| `DEV_GUIDES/` | 12 developer guides |
| `art_replacements/` | Sprite Workshop: `README_START_HERE.md`, `INDEX.md`, and a `README.md` plus `manifest.csv` in each of 34 folders |
| `assets/*/README.md` | 5 asset notes (audio placeholder, weather audio, fishing, fonts, hat) |
| `docs/benchmarks/` | Benchmark JSON results |
| `docs/screenshots/` | Screenshots by iteration and revision |
| `docs/evidence/` | Three 0.105b log files |
| `docs/.gdignore` | Already present, so Godot never imports anything under `docs/` |

Configuration and tooling that reference documents:

- `tests/suites/test_dev_guides.gd` (a list of document paths it link-checks);
- `src/dev/dev_guides.gd` (the in-game guide viewer reads `res://DEV_GUIDES`);
- `tests/suites/test_sprite_workshop.gd` and `src/art/artwork_resolver.gd` (read `res://art_replacements`);
- the screenshot harnesses (write to `docs/screenshots/...`);
- `tools/art/build_index.py`;
- comments in a few GDScript files.

There are no GitHub workflows (no `.github/`) and no `CLAUDE.md`.

## 2. Final documentation hierarchy

```
README.md                      (root; links the Ship's Library)
CAPTAINS_ORDERS.md             (root; the Captain's decisions)
DEV_GUIDES/                    (unchanged location; read by the in-game guide viewer)
art_replacements/              (unchanged; Sprite Workshop manifests and image paths)
docs/
├── README.md                  The Ship's Library index (new)
├── DOCUMENTATION_REORGANIZATION_REPORT.md   (this report)
├── iterations/  i001 i002 i003 i004 i005 i006 i012 i013 i014 i016 i017 i018
├── revisions/   v0.100a v0.100b v0.102b v0.105b (with evidence/)
├── technical/   ARCHITECTURE.md
├── artwork/     ART_PIPELINE.md, SPRITE_WORKSHOP_REPORT.md
├── testing/     README.md (new: cross-iteration testing guide)
├── benchmarks/  (unchanged)
└── screenshots/ (unchanged)
```

Folders were made only for releases that have documents. Iterations 7–11 have none and Iteration 15 was skipped, so there are no `i007`–`i011` or `i015` folders. **No `design/` folder was created**: no stand-alone design document exists. The one design-principles document, `DEV_GUIDES/MODDING_FUTURE.md`, stays with the guides and is linked from the library. Benchmarks and screenshots stayed where they were: they were already in `docs/` and are written there by test harnesses.

## 3. Old path → new path

Every move was made with `git mv`. Git records all 45 as renames, and every file keeps its name.

| Old path | New path |
|---|---|
| `ITERATION_001_REPORT.md` | `docs/iterations/i001/ITERATION_001_REPORT.md` |
| `ITERATION_002_REPORT.md` | `docs/iterations/i002/ITERATION_002_REPORT.md` |
| `ITERATION_003_REPORT.md` | `docs/iterations/i003/ITERATION_003_REPORT.md` |
| `ITERATION_003B_REPORT.md` | `docs/iterations/i003/ITERATION_003B_REPORT.md` |
| `ITERATION_003B_UI_HOTFIX_REPORT.md` | `docs/iterations/i003/ITERATION_003B_UI_HOTFIX_REPORT.md` |
| `ITERATION_004_REPORT.md` | `docs/iterations/i004/ITERATION_004_REPORT.md` |
| `ITERATION_004B_REPORT.md` | `docs/iterations/i004/ITERATION_004B_REPORT.md` |
| `ITERATION_005A_REPORT.md` | `docs/iterations/i005/ITERATION_005A_REPORT.md` |
| `ITERATION_005B_REPORT.md` | `docs/iterations/i005/ITERATION_005B_REPORT.md` |
| `ITERATION_005C_REPORT.md` | `docs/iterations/i005/ITERATION_005C_REPORT.md` |
| `WINDOWS_ACCEPTANCE_I005.md` | `docs/iterations/i005/WINDOWS_ACCEPTANCE_I005.md` |
| `ITERATION_006_REPORT.md` | `docs/iterations/i006/ITERATION_006_REPORT.md` |
| `WINDOWS_ACCEPTANCE_I006.md` | `docs/iterations/i006/WINDOWS_ACCEPTANCE_I006.md` |
| `ITERATION_12_REPORT.md` | `docs/iterations/i012/ITERATION_12_REPORT.md` |
| `WINDOWS_ACCEPTANCE_12.md` | `docs/iterations/i012/WINDOWS_ACCEPTANCE_12.md` |
| `ITERATION_13_REPORT.md` | `docs/iterations/i013/ITERATION_13_REPORT.md` |
| `WINDOWS_ACCEPTANCE_13.md` | `docs/iterations/i013/WINDOWS_ACCEPTANCE_13.md` |
| `ITERATION_14_REPORT.md` | `docs/iterations/i014/ITERATION_14_REPORT.md` |
| `WINDOWS_ACCEPTANCE_14.md` | `docs/iterations/i014/WINDOWS_ACCEPTANCE_14.md` |
| `ITERATION_16_REPORT.md` | `docs/iterations/i016/ITERATION_16_REPORT.md` |
| `WINDOWS_ACCEPTANCE_16.md` | `docs/iterations/i016/WINDOWS_ACCEPTANCE_16.md` |
| `SHIPYARD_EFFICIENCY_16.md` | `docs/iterations/i016/SHIPYARD_EFFICIENCY_16.md` |
| `ITERATION_17_ASSIGNMENT.md` | `docs/iterations/i017/ITERATION_17_ASSIGNMENT.md` |
| `ITERATION_17_REPORT.md` | `docs/iterations/i017/ITERATION_17_REPORT.md` |
| `ITERATION_17_REQUIREMENTS.md` | `docs/iterations/i017/ITERATION_17_REQUIREMENTS.md` |
| `WINDOWS_ACCEPTANCE_17.md` | `docs/iterations/i017/WINDOWS_ACCEPTANCE_17.md` |
| `ITERATION_18_ASSIGNMENT.md` | `docs/iterations/i018/ITERATION_18_ASSIGNMENT.md` |
| `ITERATION_18_REPORT.md` | `docs/iterations/i018/ITERATION_18_REPORT.md` |
| `ITERATION_18_REQUIREMENTS.md` | `docs/iterations/i018/ITERATION_18_REQUIREMENTS.md` |
| `WINDOWS_ACCEPTANCE_18.md` | `docs/iterations/i018/WINDOWS_ACCEPTANCE_18.md` |
| `VISUAL_IDENTITY_V01_REPORT.md` | `docs/revisions/v0.100a/VISUAL_IDENTITY_V01_REPORT.md` |
| `WINDOWS_ACCEPTANCE_VISUAL_V01.md` | `docs/revisions/v0.100a/WINDOWS_ACCEPTANCE_VISUAL_V01.md` |
| `VISUAL_POLISH_0100B_REPORT.md` | `docs/revisions/v0.100b/VISUAL_POLISH_0100B_REPORT.md` |
| `REVISION_0_102B_REPORT.md` | `docs/revisions/v0.102b/REVISION_0_102B_REPORT.md` |
| `WINDOWS_SMOKE_0_102B.md` | `docs/revisions/v0.102b/WINDOWS_SMOKE_0_102B.md` |
| `REVISION_0_105B_ASSIGNMENT.md` | `docs/revisions/v0.105b/REVISION_0_105B_ASSIGNMENT.md` |
| `REVISION_0_105B_REPORT.md` | `docs/revisions/v0.105b/REVISION_0_105B_REPORT.md` |
| `REVISION_0_105B_REQUIREMENTS.md` | `docs/revisions/v0.105b/REVISION_0_105B_REQUIREMENTS.md` |
| `WINDOWS_ACCEPTANCE_0_105B.md` | `docs/revisions/v0.105b/WINDOWS_ACCEPTANCE_0_105B.md` |
| `ARCHITECTURE.md` | `docs/technical/ARCHITECTURE.md` |
| `ART_PIPELINE.md` | `docs/artwork/ART_PIPELINE.md` |
| `SPRITE_WORKSHOP_REPORT.md` | `docs/artwork/SPRITE_WORKSHOP_REPORT.md` |
| `docs/evidence/revision_0_105b_full_regression_summary.txt` | `docs/revisions/v0.105b/evidence/revision_0_105b_full_regression_summary.txt` |
| `docs/evidence/revision_0_105b_restart_log.txt` | `docs/revisions/v0.105b/evidence/revision_0_105b_restart_log.txt` |
| `docs/evidence/revision_0_105b_screenshots_log.txt` | `docs/revisions/v0.105b/evidence/revision_0_105b_screenshots_log.txt` |

## 4. Files relocated

**45** files were relocated: 42 root Markdown documents and the 3 files of `docs/evidence/`, which now sit with their release in `docs/revisions/v0.105b/evidence/`.

Three files are new:

| File | Purpose |
|---|---|
| `docs/README.md` | The Ship's Library index |
| `docs/testing/README.md` | Cross-iteration testing guide |
| `tools/docs/check_links.py` | Link checker |

This report is also new. Nothing was deleted, merged or overwritten.

## 5. References updated

**138 references** were updated in 37 files:

| Kind of reference | Count | How |
|---|---|---|
| Markdown links (inline, reference-style, HTML `src`/`href`) | 60 | A script: each target was resolved from the referring document's old location, mapped through the table above, and the relative path recomputed from the document's new location. Links in moved documents that point to unmoved places (for example `DEV_GUIDES/...` from `ARCHITECTURE.md`, now `../../DEV_GUIDES/...`) were recomputed too. |
| Plain path mentions | 63 | Root-relative names written as text or in code spans, rewritten to their new repository paths, in `README.md`, `CAPTAINS_ORDERS.md`, `DEV_GUIDES/`, `art_replacements/` (`README_START_HERE.md`, `INDEX.md` through its generator `tools/art/build_index.py`), moved reports, GDScript comments, `tests/benchmark_105b.gd`, `tests/suites/test_dev_guides.gd` and `tools/vessels/render_art_templates.gd`. A bare name that now sits **in the same folder** as the document mentioning it was left alone, because it still resolves (for example `WINDOWS_ACCEPTANCE_18.md` inside `ITERATION_18_REPORT.md`). |
| By hand | 15 | `tests/suites/test_dev_guides.gd`: 12 entries in `LINKED_DOCS` (now `res://docs/...`, plus `res://docs/README.md` added), and the "ARCHITECTURE.md points to DEV_GUIDES" check. `art_replacements/README_START_HERE.md`: the Sprite Workshop report pointer turned into a working link. `README.md`: a new link to the Ship's Library. |

**Left as written, on purpose: the Captain's verbatim assignments.** `ITERATION_17_ASSIGNMENT.md`, `ITERATION_18_ASSIGNMENT.md` and `REVISION_0_105B_ASSIGNMENT.md` are Captain-authored and not edited. Their file names (for example "create `REVISION_0_105B_REPORT.md`") name deliverables; they are not links. All of those documents exist under the same names in the library.

## 6. Link validation: method and results

**Tool.** `tools/docs/check_links.py` checks every tracked Markdown file:

- inline links and images, reference definitions, and HTML `src`/`href`;
- code spans and fenced code are skipped;
- `#fragments` are checked against the target's headings using GitHub's anchor rules and explicit anchors.

It was sanity-tested on real headings of the 0.105b report: valid anchors found, an invalid one rejected.

| | Documents | Internal links | Broken |
|---|---|---|---|
| Before the move | 97 | 124 | **0** |
| After (with the new index, testing guide and this report) | 100 | 205 | **0** (see §11) |

**Fragments.** No existing link used a `#fragment` before or after; the check is in place for future ones.

**Images and resources.** Links to screenshots, benchmark folders, SVG logos and `art_replacements/` files are included in the check and resolve.

**Dynamic paths (not visible to a text search) checked by reading the code:**

| Code | Path | Moved? |
|---|---|---|
| `DevGuides.DEFAULT_DIR` | `res://DEV_GUIDES` | Not moved |
| `ArtworkResolver.ROOT` | `res://art_replacements` | Not moved; manifests and image paths unchanged |
| `screenshots_16/17.OUT` | `res://docs/screenshots/...` | Not moved |
| `test_dev_guides` path roots | Include `docs/` | — |
| Other `res://` document reads | `res://assets/fonts/README.md`, `res://assets/audio/weather/README.md` | Not moved |

## 7. Obsolete paths

A repository-wide search for every old root name and `docs/evidence/` (`git ls-files`; `.md`, `.gd`, `.py`, `.json`, `.tscn`, `.tres`, `.cfg`, `.txt`, `.csv`) found **no obsolete path references**. The only remaining occurrences are of three kinds:

1. **Link labels**, the visible text of links whose targets were updated, for example `[ITERATION_18_REPORT.md](docs/iterations/i018/ITERATION_18_REPORT.md)` in `README.md`.
2. **Bare names of documents in the same folder**, which still resolve.
3. **The Captain's verbatim assignments** (§5), which name deliverables.

Benchmark JSON data was not touched.

## 8. Tooling and startup smoke tests

All run headless with Godot 4.7.2 on the reorganized tree:

| Check | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors |
| Startup smoke test (`godot --headless --path . --quit-after 120`) | exit 0, no script or parse errors |
| `test_dev_guides`: guide files, index links, every link in the listed documents and guides, repository paths in guides, in-game viewer | **83 passed, 0 failed** (§11) |
| `test_sprite_workshop`: manifests, resolver, every READY entry, three replacement examples | **35 passed, 0 failed** |
| `test_branding` (version 0.105b shown, asset READMEs) | **63 passed, 0 failed** |
| `test_diagnostics` (version 0.105b, save format 12 in the log) | **24 passed, 0 failed** |
| `python3 tools/art/build_index.py --check` (34 manifests) | valid |
| `python3 tools/docs/check_links.py` | 0 broken |

## 9. Files deliberately kept in the root, and why

| File or folder | Reason |
|---|---|
| `README.md` | GitHub's landing page; now links the library |
| `CAPTAINS_ORDERS.md` | The authoritative record of the Captain's decisions, as ordered |
| `project.godot`, `.gitignore`, `.gitattributes`, `.editorconfig` | Required by Godot, Git and editors |
| `DEV_GUIDES/` | The game's in-game developer-guide viewer reads `res://DEV_GUIDES` (`src/dev/dev_guides.gd`). Moving it would mean changing game code, so it stays and is linked from the library. |
| `art_replacements/`, `Visuals/`, `assets/` | Sprite Workshop paths, the Captain's own drawings and game resources: not documentation to move |
| `tools/`, `tests/` | Code |

**No compatibility pointer files** were left at the old root paths. A pointer file at an old path, added in the same commit as the move, makes Git see a copy instead of a rename and breaks `git log --follow` history for that document. Keeping history intact and the root tidy was judged more valuable. Anyone with an old link finds the document by its unchanged file name in the library index or the table in §3.

## 10. Pre-existing broken links

**None.** The baseline check (§6) found 0 broken internal links in 97 documents before anything moved.

## 11. No new broken references

**Confirmed: zero new broken internal references.**

- `tools/docs/check_links.py` reports 0 broken after the move.
- The one link that pointed to this report while it was being written (from `docs/README.md`) resolves now that the report exists; the final run of `test_dev_guides` passes in full.
- The obsolete-path search (§7) found nothing to repair.

## 12. Commit and push

All of this is one documentation-maintenance commit on `claude/friendly-fermat-dey23f`, separate from any gameplay work: ordinary renames and edits, no reset or force-push. Its hash, and the check that the remote branch equals the local HEAD after the push, are given in the delivery message. A commit cannot record its own hash.
