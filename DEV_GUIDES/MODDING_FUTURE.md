# Future modding: compatibility notes

**There is no mod support in Next Harbor**, and none is planned for now. This
short note lists the habits that keep the option open, so that a later
decision is not blocked by avoidable choices made today.

## Principles we follow now

1. **Stable content identifiers.** Content is referred to by ids that never
   change once released. Saves store ids, never display names or file paths:
   - vessels: `starling_33`, `halcyon_40`, `petrel_36`;
   - ports;
   - companion kinds (`cat`, `dog`) and resting spots (`settee`, `nav_station`,
     ...);
   - pose names (`resting`, `sleeping`, `alert`, `stretching`).

   A new piece of content gets a new id. Renaming an id needs a save migration.
2. **Data-driven asset references.** Which art or scene something uses is written
   in data, not in code:
   - vessel definitions and visual profiles in `data/vessels/`;
   - companion pose sets in `data/companions/`;
   - ports in `data/navigation/`.

   Scripts look these up through a small number of documented conventions:
   - `VesselCatalog.DEFAULT_PATH`;
   - `PortCatalog.DEFAULT_PATH`;
   - `CompanionVisualSet.PATH_PATTERN`;
   - the conventional sprite paths in `VesselVisualProfile`.
3. **Presentation separate from gameplay.** Art never decides gameplay:
   collision, stations and markers are in each scene's `Layout`, and art is in
   `Visual` or in companion pose images. Pose and sail animation are never saved.
   Replacement art therefore cannot break saves or walkability.
4. **No hardcoded asset paths in behaviour code** where it is avoidable. New code
   should export a resource or read it from a data file instead of `preload`ing a
   specific asset.
   - Known exceptions:
     - default sounds in `ShipCompanion` and `App` (overridable in the
       Inspector);
     - the placeholder audio paths in boat scenes.
   - Gameplay never depends on them.
5. **Versioned saves.** `SaveManager.SAVE_VERSION` with step-by-step migrations.
   Unknown content ids load safely: an unknown vessel falls back to the starter
   boat, and the player is told.

## Things to decide before any mod support

- **Where content would come from.** Godot resource packs (`.pck`) can add or
  replace `res://` files. That is the simplest route and keeps the conventions
  above working. Loading content from arbitrary folders would need its own
  importer, because exported games cannot import PNGs.
- **Catalog merging.** Today each catalog is one `.tres`. Mods adding vessels
  would need several catalogs merged, with id conflicts reported.
- **Save compatibility.** A save using content from a removed mod must still
  load. The vessel fallback already does this; ports, companions and future
  systems should do the same.
- **Trust.** Mods must never run scripts. Data and images only. Godot resources
  can embed scripts, so a mod loader would have to restrict resource types.
- **Versioning.** Mods would declare the game and save version they target.

## What we deliberately do not do

There are no mod folders, runtime package loading, script execution, mod API,
dependency management, Workshop integration, user-content discovery or
compatibility database. Add none of these without an explicit decision.
