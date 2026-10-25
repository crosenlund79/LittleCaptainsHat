class_name TrophyMenu
extends SimplePanel
## The trophy board (Iteration 13): the five most notable catches, ranked by
## FishingCatalog.score (rarity, then size within the species, plus a little
## for a new species or a personal best at the time), and the captain's
## fishing record.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var _list: Label
var _record: Label


func _ready() -> void:
	_build("Trophy board", 640.0)
	_label("Info", "The five most notable catches: rare fish rank above common ones, and a big fish above a small one of its kind.",
		&"MutedLabel")
	_list = _label("List", "")
	_box.add_child(HSeparator.new())
	_record = _label("Record", "", &"MutedLabel")
	_button("CloseButton", "Close", close)
	refresh()


func refresh() -> void:
	_list.text = describe_trophies()
	_record.text = describe_record()


static func describe_trophies() -> String:
	var catalog := FishingCatalog.get_default()
	var fishing := GameSession.get_fishing()
	if fishing.trophies.is_empty():
		return "No catches yet. The rod is on the stern rail."
	var lines := PackedStringArray()
	for i in fishing.trophies.size():
		var fish: Dictionary = fishing.trophies[i]
		var day := Time.get_datetime_dict_from_unix_time(int(fish.caught_at))
		lines.append("%d.  %s, %.1f kg  ·  %s  ·  %d %s%s" % [i + 1, catalog.get_species_name(fish.species), float(fish.kg),
			catalog.rarity_name(fish.species), day.day, MONTHS[day.month - 1],
			(", " + String(fish.where)) if String(fish.get("where", "")) != "" else ""])
	return "\n".join(lines)


static func describe_record() -> String:
	var catalog := FishingCatalog.get_default()
	var fishing := GameSession.get_fishing()
	var species := PackedStringArray()
	for id: String in fishing.records:
		species.append("%s %d (best %.1f kg)" % [catalog.get_species_name(id), int(fishing.records[id].count), float(fishing.records[id].best_kg)])
	return "Caught %d fish of %d species  ·  released %d  ·  sold %d.%s" % [fishing.total_caught, fishing.records.size(),
		fishing.released, fishing.sold, ("\n" + ", ".join(species)) if not species.is_empty() else ""]
