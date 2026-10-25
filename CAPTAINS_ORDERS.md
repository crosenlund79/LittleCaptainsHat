# Captain's Orders

The standing decisions of the Captain (the project owner) for
**Little Captain's Hat**. Implementation follows these; when an assignment
and this file disagree, the newer, explicit instruction from the Captain wins,
and this file is updated to match.

Only decisions the Captain has actually given belong in the authoritative
section. Notes added by developers are kept apart and marked as such.

*Small boat. Wide world. Hold onto your hat.*

## Authoritative: Captain-approved decisions

### The game

- **Name and tagline.** The game is *Little Captain's Hat* (developed as *Next
  Harbor* up to Iteration 006). Tagline: *Small boat. Wide world. Hold onto
  your hat.*
- **Cozy first.** A cozy sailing adventure about making a home on the water and
  exploring the world at your own pace. Coziness is the primary design
  principle.
- **Visual direction.** Keep the illustrated direction: hand-drawn warmth,
  imperfect ink outlines, warm muted colours, the illustrated fleet and marine
  teak decking, lively water, and readable top-down gameplay. The Classic art
  stays available as a setting.
- **The Captain's artwork** is never overwritten.

### The fleet

- Official boat names, with internal ids that never change:

  | Name | Internal id | Note |
  |---|---|---|
  | Arctic Wanderer 26 | `arctic_wanderer_26` | starter boat for every new game |
  | Wing 33 | `starling_33` | formerly Starling 33 |
  | Clam 40 | `halcyon_40` | formerly Halcyon 40 |
  | Frogleap 36 | `petrel_36` | formerly Petrel 36 |

- Existing saves keep their boats, condition and progression.
- Interiors have one level only, on every boat.

### Iteration 12, A Little Harbour Life (revision build)

- **Iteration 12 is a revision build.** It makes the existing sailing and harbour
  experience more natural and inviting. It does not start the next major
  feature.
- **Revisions are the preferred rhythm** when an iteration's acceptance trial
  reveals meaningful findings.
- **Real objects instead of circles.** Real graphical interaction targets
  replace large visible activation circles: the object itself is highlighted.
  The interaction areas stay generous, and are visible only through developer
  tools.
- **Gangplank and shore access are approved.** The captain walks over a
  gangplank onto the pontoon, where the harbour's services stand.
- **Harbour facilities are data-driven and optional.** Not every harbour has
  every service. Where a harbour has no entry of its own, the existing
  behaviour (every service) remains the default.
- **Copenhagen has a boatyard** (and groceries and Go Ashore).
- **Lohals has no boatyard** in our game.
- **Go Ashore is deliberately lightweight**: small harbour events with modest
  consequences. It is not a town-exploration game: no NPC pathfinding,
  dialogue trees, quests, shop inventories, new currencies, factions,
  walkable villages, generated stories or event chains.
- **Hat loss must be clear without audio.** The loss and the risk before it
  are visible and readable with the sound muted.
- **Course-aligned boat rendering, attempted conservatively.** Technical
  stability and existing save compatibility take priority over forced visual
  changes.

### Iterations and versions

- Iteration numbers are sequential integers: no letter suffixes and no
  sub-iteration numbers. Minor correction prompts belong to their parent
  iteration. One commissioned implementation assignment is one iteration.
- Game version numbers are separate from iteration numbers. They follow
  0.<milestone><letter>: 0.100a, 0.100b (fixes and refinements within a
  milestone), 0.101a (the next feature milestone), 0.200a (a large step).
- The save format has its own version, changed only when persistent game state
  genuinely requires it.

### Working rules

- Only the repository `crosenlund79/LittleCaptainsHat` is worked on. The archived
  Next Harbor repository and unrelated projects are never edited.
- Use recoverable checkpoint commits. Never reset, force-push or discard work.
- A delivery states the version, the final commit, the branch, the report and
  the Windows checklist, and ends with the clickable branch link.
- The Captain's own workflow is: GitHub branch → Code → Download ZIP → extract →
  open `project.godot` in Godot → run. A Windows executable is not made unless
  asked.
- Testing is focused and proportionate: no inflated test counts for cosmetic
  details. A suite that was skipped is reported as skipped. Windows acceptance
  is claimed only after the Captain's own trial.

### Not now

These remain separately approved future assignments; they are not started
early:

- fishing;
- anchoring;
- maintenance and equipment expansion;
- a worldwide chart.

## Phase Two

The Captain has a locked **Phase Two distinction**. It is **not written down in
this repository yet**, so it is not restated or guessed here. It stays in force
exactly as the Captain defined it. *Developer note: please add its wording here.*

## Iteration log

- Iterations 001–006: built as *Next Harbor* (see the iteration reports).
- Visual Identity V01, version 0.100a: see `VISUAL_IDENTITY_V01_REPORT.md`.
- A Living Little World, version 0.100b: see `VISUAL_POLISH_0100B_REPORT.md`.
- **Iteration 12, A Little Harbour Life**, version 0.100c: an authorized revision
  build; see `ITERATION_12_REPORT.md` and `WINDOWS_ACCEPTANCE_12.md`.
