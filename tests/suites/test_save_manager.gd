extends RefCounted
## Save slots: writing, metadata, loading, and every failure mode.


func run(t: Node) -> void:
	var dir: String = t.TEST_SAVE_DIR
	t.check(not SaveManager.has_any_valid_save(), "no valid save in an empty save directory")
	t.check_eq(SaveManager.get_slot_info(1).status, SaveManager.Status.EMPTY, "missing slot reports EMPTY")
	t.check(not SaveManager.load_from_slot(1).is_ok(), "loading an empty slot fails cleanly")
	t.check(not SaveManager.load_from_slot(0).is_ok() and not SaveManager.load_from_slot(4).is_ok(),
		"out-of-range slots are rejected")

	var state := SessionState.create_new(&"copenhagen", SessionState.AREA_EXTERIOR, &"start")
	state.player_position = Vector2(-120, 33)
	state.has_player_position = true
	state.planned_route = t.make_route(&"copenhagen", &"kiel")
	t.check_eq(SaveManager.save_to_slot(1, state), OK, "saving to slot 1 succeeds")
	t.check(FileAccess.file_exists(dir.path_join("slot_1.json")), "slot file is written under user://")
	t.check(not FileAccess.file_exists(dir.path_join("slot_1.json.tmp")), "temporary file is cleaned up")

	var info := SaveManager.get_slot_info(1)
	t.check_eq(info.status, SaveManager.Status.VALID, "saved slot is VALID")
	t.check_eq(info.area_name, "Deck", "metadata: area")
	t.check_eq(info.location_name, "Copenhagen", "metadata: location")
	t.check_eq(info.destination_name, "Kiel", "metadata: route destination")
	t.check(absf(info.saved_at_unix - Time.get_unix_time_from_system()) < 60.0, "metadata: timestamp")

	var loaded := SaveManager.load_from_slot(1)
	t.check(loaded.is_ok(), "slot 1 loads")
	if loaded.is_ok():
		t.check_eq(loaded.state.to_dict(), state.to_dict(), "loaded state equals saved state")

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("slot_1.json")))
	t.check_eq(int(raw.get("version", 0)), SaveManager.SAVE_VERSION, "save file records the format version")

	# Most recent valid slot wins for Continue.
	await t.get_tree().create_timer(1.1).timeout
	state.boat_area = SessionState.AREA_INTERIOR
	SaveManager.save_to_slot(2, state)
	t.check_eq(SaveManager.get_most_recent_valid_slot(), 2, "most recent valid slot is slot 2")

	# Overwriting keeps the previous file as a backup.
	SaveManager.save_to_slot(1, state)
	t.check(FileAccess.file_exists(dir.path_join("slot_1.json.bak")), "overwrite keeps a .bak of the previous save")
	t.check_eq(SaveManager.get_slot_info(1).area_name, "Cabin", "overwritten slot has the new data")

	# Interrupted write: only the backup exists -> it is still loadable.
	DirAccess.rename_absolute(dir.path_join("slot_1.json"), dir.path_join("slot_1.json.moved"))
	t.check(SaveManager.load_from_slot(1).is_ok(), "slot falls back to .bak if the main file is missing")
	DirAccess.rename_absolute(dir.path_join("slot_1.json.moved"), dir.path_join("slot_1.json"))

	# Corrupted, unsupported and invalid saves.
	_write(dir.path_join("slot_3.json"), "{ this is not json")
	t.check_eq(SaveManager.get_slot_info(3).status, SaveManager.Status.CORRUPTED, "garbage file is CORRUPTED")
	var bad := SaveManager.load_from_slot(3)
	t.check(not bad.is_ok() and not bad.error.is_empty(), "loading a corrupted slot fails with a reason")

	raw["version"] = 99
	_write(dir.path_join("slot_3.json"), JSON.stringify(raw))
	t.check_eq(SaveManager.get_slot_info(3).status, SaveManager.Status.UNSUPPORTED, "future version is UNSUPPORTED")

	raw["version"] = 1
	raw["session"]["boat"]["area"] = "crow's nest"
	_write(dir.path_join("slot_3.json"), JSON.stringify(raw))
	t.check_eq(SaveManager.get_slot_info(3).status, SaveManager.Status.CORRUPTED, "invalid content is CORRUPTED")

	raw.erase("session")
	_write(dir.path_join("slot_3.json"), JSON.stringify(raw))
	t.check(not SaveManager.load_from_slot(3).is_ok(), "incomplete save (no session) is rejected")

	_write(dir.path_join("slot_3.json"), "")
	t.check_eq(SaveManager.get_slot_info(3).status, SaveManager.Status.CORRUPTED, "empty file is CORRUPTED")
	t.check_eq(SaveManager.get_most_recent_valid_slot(), 1, "invalid slots are ignored by Continue (newest valid is the overwritten slot 1)")
	SaveManager.delete_slot(3)

	# Failed write: the save directory cannot be created (a file is in the way).
	var before := FileAccess.get_file_as_string(dir.path_join("slot_2.json"))
	_write(dir.path_join("blocked"), "file in the way")
	SaveManager.save_dir = dir.path_join("blocked")
	var err := SaveManager.save_to_slot(2, state)
	SaveManager.save_dir = dir
	t.check(err != OK, "write failure is reported (error %s)" % error_string(err))
	t.check_eq(FileAccess.get_file_as_string(dir.path_join("slot_2.json")), before, "failed write leaves the existing save intact")
	DirAccess.remove_absolute(dir.path_join("blocked"))

	for slot in [1, 2, 3]:
		SaveManager.delete_slot(slot)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
