@tool
class_name HarbourLandmark
extends Resource
## One local landmark illustration for a harbour (art only, no collision):
## an image placed on the quay beyond the guest pontoon.

## What it shows (for documentation and tests), e.g. "Nyhavn".
@export var title := ""
## The illustration. Drawn centred at `offset`, scaled to `width` scene units.
@export var texture: Texture2D
## Centre of the image relative to the quay anchor: the middle of the
## pontoon's far (landward) edge. +y is further from the boat.
@export var offset := Vector2(0, 60)
## Drawn width in scene units (the height follows the image).
@export var width := 600.0
