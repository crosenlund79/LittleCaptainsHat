class_name HighlightProvider
extends Node2D
## A drawn object that a station highlights when focused (Iteration 12): its
## outline in local points, for HighlightResolver. Draws nothing itself.

var outline := PackedVector2Array()


static func create(interaction_id: StringName, local_outline: PackedVector2Array) -> HighlightProvider:
	var provider := HighlightProvider.new()
	provider.name = "Highlight_%s" % interaction_id
	provider.outline = local_outline
	provider.set_meta(HighlightResolver.META_FOR, interaction_id)
	provider.add_to_group(HighlightResolver.GROUP)
	return provider


func get_highlight_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in outline:
		points.append(to_global(p))
	return points
