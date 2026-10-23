extends Node
## Reads and writes manual save slots as JSON files under user://saves/.
##
## SaveManager only serializes SessionState objects it is given and returns
## validated SessionState objects on load. It never touches scenes or the
## active session; the application flow decides what to do with the result.
##
## Writes are made safe by writing to a temporary file, verifying it, keeping
## the previous save as a ".bak" and only then moving the new file into place.

signal slots_changed

const FORMAT_ID := "next_harbor_save"
## Bump when the save layout changes, and add a migration step in
## _migrate() for older versions that should stay loadable.
const SAVE_VERSION := 4
const SLOT_COUNT := 3
const DEFAULT_SAVE_DIR := "user://saves"

enum Status { EMPTY, VALID, CORRUPTED, UNSUPPORTED }

## Directory is a variable so tests can use a scratch location.
var save_dir := DEFAULT_SAVE_DIR


## Metadata describing one slot, for menus.
class SlotInfo:
	var slot := 0
	var status := Status.EMPTY
	var saved_at_unix := 0.0
	var area_name := ""
	var location_name := ""
	var destination_name := ""
	## In-game date and time of the save.
	var game_time := 0.0
	## Explanation for CORRUPTED / UNSUPPORTED slots.
	var problem := ""

	func is_loadable() -> bool:
		return status == Status.VALID


class LoadResult:
	var state: SessionState
	var error := ""

	func is_ok() -> bool:
		return state != null


# --- Queries -------------------------------------------------------------------

func get_slot_info(slot: int) -> SlotInfo:
	var info := SlotInfo.new()
	info.slot = slot
	var path := _resolve_readable_path(slot)
	if path.is_empty():
		return info
	var read := _read_and_validate(path)
	info.status = read.status
	info.problem = read.error
	if read.status != Status.VALID:
		return info
	var catalog := PortCatalog.get_default()
	var state: SessionState = read.state
	info.saved_at_unix = read.saved_at_unix
	info.area_name = SessionState.get_area_display_name(state.boat_area)
	info.game_time = state.game_time
	if state.voyage:
		info.location_name = "At sea"
		info.destination_name = catalog.get_display_name(state.voyage.route.destination_port_id)
	else:
		info.location_name = catalog.get_display_name(state.location_id)
		if state.planned_route:
			info.destination_name = catalog.get_display_name(state.planned_route.destination_port_id)
	return info


func get_all_slot_info() -> Array[SlotInfo]:
	var result: Array[SlotInfo] = []
	for slot in range(1, SLOT_COUNT + 1):
		result.append(get_slot_info(slot))
	return result


## Slot number of the newest valid save, or 0 if there is none.
func get_most_recent_valid_slot() -> int:
	var best_slot := 0
	var best_time := -INF
	for info in get_all_slot_info():
		if info.is_loadable() and info.saved_at_unix > best_time:
			best_time = info.saved_at_unix
			best_slot = info.slot
	return best_slot


func has_any_valid_save() -> bool:
	return get_most_recent_valid_slot() != 0


# --- Save --------------------------------------------------------------------------

func save_to_slot(slot: int, state: SessionState) -> Error:
	if not _is_valid_slot(slot) or state == null:
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		push_error("Cannot create save directory %s (error %d)" % [save_dir, err])
		return err

	var now := Time.get_unix_time_from_system()
	var data := {
		"format": FORMAT_ID,
		"version": SAVE_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at_unix": now,
		"saved_at_utc": Time.get_datetime_string_from_unix_time(int(now)) + "Z",
		"session": state.to_dict(),
	}
	# Full precision keeps positions, progress and time exact across save/load.
	var text := JSON.stringify(data, "\t", true, true)
	var final_path := _slot_path(slot)
	var temp_path := final_path + ".tmp"
	var backup_path := final_path + ".bak"

	# 1. Write the new save next to the old one and verify it reads back.
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s (error %d)" % [temp_path, FileAccess.get_open_error()])
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	if FileAccess.get_file_as_string(temp_path) != text:
		DirAccess.remove_absolute(temp_path)
		push_error("Save verification failed for slot %d" % slot)
		return ERR_FILE_CORRUPT

	# 2. Keep the previous save as a backup, then move the new one into place.
	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		err = DirAccess.rename_absolute(final_path, backup_path)
		if err != OK:
			DirAccess.remove_absolute(temp_path)
			push_error("Cannot back up previous save (error %d)" % err)
			return err
	err = DirAccess.rename_absolute(temp_path, final_path)
	if err != OK:
		# Put the previous save back so the slot is never left empty.
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, final_path)
		push_error("Cannot finalize save for slot %d (error %d)" % [slot, err])
		return err
	slots_changed.emit()
	return OK


# --- Load --------------------------------------------------------------------------

func load_from_slot(slot: int) -> LoadResult:
	var result := LoadResult.new()
	if not _is_valid_slot(slot):
		result.error = "Invalid save slot."
		return result
	var path := _resolve_readable_path(slot)
	if path.is_empty():
		result.error = "Slot %d is empty." % slot
		return result
	var read := _read_and_validate(path)
	if read.status != Status.VALID:
		result.error = read.error
		return result
	result.state = read.state
	return result


func delete_slot(slot: int) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _slot_path(slot) + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	slots_changed.emit()


# --- Internals ---------------------------------------------------------------------

class _ReadResult:
	var status := Status.CORRUPTED
	var error := ""
	var state: SessionState
	var saved_at_unix := 0.0


func _read_and_validate(path: String) -> _ReadResult:
	var read := _ReadResult.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		read.error = "The save file is empty or unreadable."
		return read
	var json := JSON.new()
	if json.parse(text) != OK:
		read.error = "The save file is damaged (line %d: %s)." % [json.get_error_line(), json.get_error_message()]
		return read
	var data: Variant = json.data
	if not data is Dictionary or data.get("format") != FORMAT_ID:
		read.error = "This is not a Next Harbor save file."
		return read
	var version: Variant = data.get("version")
	if not (version is int or version is float):
		read.error = "The save file has no version."
		return read
	if int(version) > SAVE_VERSION or int(version) < 1:
		read.status = Status.UNSUPPORTED
		read.error = "Save version %d is not supported by this version of the game." % int(version)
		return read
	data = _migrate(data, int(version))
	var saved_at: Variant = data.get("saved_at_unix")
	if not (saved_at is int or saved_at is float):
		read.error = "The save file has no timestamp."
		return read
	var errors: Array[String] = []
	var state := SessionState.from_dict(data.get("session"), errors)
	if state == null:
		read.error = "The save data is invalid: %s." % ", ".join(errors)
		return read
	read.status = Status.VALID
	read.state = state
	read.saved_at_unix = float(saved_at)
	return read


## Upgrades older save layouts to the current one, one version at a time.
## Each step only adds safe defaults; validation happens afterwards as usual.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < 2:
		data = _migrate_1_to_2(data)
	if from_version < 3:
		data = _migrate_2_to_3(data)
	if from_version < 4:
		data = _migrate_3_to_4(data)
	return data


## Version 1 (Iteration 001) had no clock, vessel state or voyages, and its
## planned route was only origin/destination/waypoints. The vessel is placed
## in its port at the default start time; the route keeps its destination and
## waypoints and is recalculated as a sea route when the game is loaded.
func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var session: Variant = data.get("session")
	if not session is Dictionary or not session.get("navigation") is Dictionary:
		return data  # Invalid anyway; validation reports it.
	var catalog := PortCatalog.get_default()
	var navigation: Dictionary = session.navigation
	var port := catalog.get_port(StringName(str(navigation.get("location_id", ""))))
	var position := port.get_geo_position() if port else Vector2.ZERO
	session["clock"] = {"game_time": SessionState.get_start_time(), "time_scale": 1}
	session["vessel"] = {
		"status": String(SessionState.STATUS_MOORED),
		"position": {"lon": position.x, "lat": position.y},
		"speed_kn": 5.0,  # version 2 stored the constant cruising speed
	}
	navigation["voyage"] = null
	var route: Variant = navigation.get("planned_route")
	if route is Dictionary:
		var origin := catalog.get_port(StringName(str(route.get("origin", ""))))
		var origin_position := origin.get_geo_position() if origin else position
		route["origin_position"] = {"lon": origin_position.x, "lat": origin_position.y}
		route["path"] = []
		route["waypoint_path_indices"] = []
	data["version"] = 2
	return data


## Version 2 (Iteration 002) had a constant 5 kn speed and no wind. Version 3
## adds the wind seed (default 1) and the propulsion state. Migrated voyages
## get an uninitialised controller: at the first simulation step it starts
## from the current wind at the saved position (sail, or engine if the
## potential sailing speed is below the start threshold), so loading never
## inherits a stale mode.
func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	var session: Variant = data.get("session")
	if not session is Dictionary or not session.get("vessel") is Dictionary:
		return data
	session["wind"] = {"seed": 1}
	var vessel: Dictionary = session.vessel
	vessel.erase("speed_kn")
	vessel["propulsion"] = PropulsionState.new().to_dict()
	data["version"] = 3
	return data


## Version 3 (Iteration 003) had no ship's companion. Version 4 adds one:
## older games get the default companion (a cat, CompanionState.DEFAULT_KIND)
## resting in its first spot, with its schedule starting at the saved time.
func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	var session: Variant = data.get("session")
	if not session is Dictionary or not session.get("clock") is Dictionary:
		return data
	var game_time: Variant = session.clock.get("game_time")
	var now := float(game_time) if game_time is float or game_time is int else SessionState.get_start_time()
	session["companion"] = CompanionState.create(CompanionState.DEFAULT_KIND, now).to_dict()
	data["version"] = 4
	return data


## The slot file, or its backup if a previous write was interrupted between
## moving the old save aside and putting the new one in place.
func _resolve_readable_path(slot: int) -> String:
	if not _is_valid_slot(slot):
		return ""
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		return path
	if FileAccess.file_exists(path + ".bak"):
		return path + ".bak"
	return ""


func _slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT
