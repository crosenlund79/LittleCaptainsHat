class_name LegacySaves
extends RefCounted
## Saves from Next Harbor, the game's name until Iteration 006.
##
## Godot keeps a project's files in a folder named after the project. Under
## its old name the game saved to (Windows)
##   %APPDATA%\Godot\app_userdata\Next Harbor\saves\
## Little Captain's Hat uses its own fixed folder instead (project setting
## application/config/custom_user_dir_name = "Little Captains Hat"):
##   %APPDATA%\Little Captains Hat\saves\
## so the new game can never change or delete the old game's files, and a
## future rename cannot move the saves again.
##
## Importing is explicit (the main menu offers it when old saves exist) and
## only copies: each old save goes into the slot with the same number if it is
## free, otherwise into the first free slot left, otherwise it is skipped. A save
## already imported (the same bytes in some slot) is skipped. The old files
## are only read, never moved, changed or deleted. Saves are copied as they
## are; loading one upgrades it in memory (SaveManager migrations).

## The project name the game had before the rename (the old folder's name).
const LEGACY_PROJECT_NAME := "Next Harbor"

const RESULT_IMPORTED := &"imported"
const RESULT_ALREADY := &"already_imported"
const RESULT_NO_FREE_SLOT := &"no_free_slot"
const RESULT_INVALID := &"invalid"

## Tests point this at a scratch folder (an absolute path or user://...).
static var legacy_dir_override := ""


## Where Next Harbor kept its files on this computer.
static func get_legacy_user_dir() -> String:
	if not legacy_dir_override.is_empty():
		return legacy_dir_override
	# Godot's default per-project folder: <data dir>/Godot/app_userdata/<name>
	# ("godot" in lower case on Linux and the BSDs).
	var godot_dir := "godot" if OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"] else "Godot"
	return OS.get_data_dir().path_join(godot_dir).path_join("app_userdata").path_join(LEGACY_PROJECT_NAME)


static func get_legacy_saves_dir() -> String:
	return get_legacy_user_dir().path_join("saves")


## Old saves found: [{"slot", "path", "status" (SaveManager.Status), "error",
## "saved_at_unix", "already": true when its bytes are already in a slot}].
static func find() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var dir := get_legacy_saves_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var path := dir.path_join("slot_%d.json" % slot)
		if not FileAccess.file_exists(path):
			path += ".bak"  # an interrupted write left only the backup
			if not FileAccess.file_exists(path):
				continue
		var check := SaveManager.check_file(path)
		found.append({"slot": slot, "path": path, "status": check.status, "error": check.error,
			"saved_at_unix": check.saved_at_unix, "already": _already_imported(path)})
	return found


## Old saves that a click on Import would copy (valid, not imported yet).
static func count_importable() -> int:
	var count := 0
	for entry in find():
		if entry.status == SaveManager.Status.VALID and not entry.already:
			count += 1
	return count


## Copies every valid old save that is not imported yet into a free slot.
## Returns one entry per old save: {"slot", "path", "result", "target"}.
static func import_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	# First every old save whose own slot number is free goes there, then the
	# rest fill the remaining free slots in order.
	for entry in find():
		var result := {"slot": entry.slot, "path": entry.path, "result": RESULT_INVALID, "target": 0}
		results.append(result)
		if entry.status != SaveManager.Status.VALID:
			continue
		if entry.already:
			result.result = RESULT_ALREADY
		elif SaveManager.is_slot_free(int(entry.slot)):
			_copy(result, int(entry.slot))
		else:
			waiting.append(result)
	for result in waiting:
		_copy(result, _free_slot_for(int(result.slot)))
	return results


static func _copy(result: Dictionary, target: int) -> void:
	if target != 0 and SaveManager.import_file(result.path, target) == OK:
		result.result = RESULT_IMPORTED
		result.target = target
	else:
		result.result = RESULT_NO_FREE_SLOT


## One line for the player about an import's results.
static func describe(results: Array[Dictionary]) -> String:
	var imported: Array[String] = []
	var skipped := 0
	for r in results:
		if r.result == RESULT_IMPORTED:
			imported.append("slot %d" % r.target)
		elif r.result == RESULT_NO_FREE_SLOT:
			skipped += 1
	var text := ""
	if imported.is_empty():
		text = "No Next Harbor saves were imported."
	else:
		text = "Imported %d Next Harbor save%s into %s. The originals are unchanged." % [imported.size(),
			"" if imported.size() == 1 else "s", ", ".join(imported)]
	if skipped > 0:
		text += " %d could not be imported: no free slot (nothing was overwritten)." % skipped
	return text


static func _free_slot_for(preferred: int) -> int:
	if SaveManager.is_slot_free(preferred):
		return preferred
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if SaveManager.is_slot_free(slot):
			return slot
	return 0


static func _already_imported(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if not bytes.is_empty() and SaveManager.get_slot_bytes(slot) == bytes:
			return true
	return false
