class_name DevGuides
extends RefCounted
## The developer guides in DEV_GUIDES/ (Markdown), for the in-game viewer.
## The Markdown files are the only source: the viewer reads them as they are.
##
## Available only in debug builds run from the project (the editor, or
## `godot --path .`): exported games do not contain the .md files, and
## release builds never show developer tools.

const DEFAULT_DIR := "res://DEV_GUIDES"
const INDEX_FILE := "README.md"

## Folder the guides are read from (tests point it elsewhere).
static var guides_dir := DEFAULT_DIR


## True when the guides can be shown (debug build and the files are present).
static func is_available() -> bool:
	return OS.is_debug_build() and not list_guides().is_empty()


## The guides, index (README.md) first, then by file name:
## [{path, file, title}].
static func list_guides() -> Array[Dictionary]:
	var guides: Array[Dictionary] = []
	var dir := DirAccess.open(guides_dir)
	if dir == null:
		return guides
	var files := Array(dir.get_files()).filter(func(f: String) -> bool: return f.get_extension().to_lower() == "md")
	files.sort_custom(func(a: String, b: String) -> bool:
		if a == INDEX_FILE or b == INDEX_FILE:
			return a == INDEX_FILE
		return a.naturalnocasecmp_to(b) < 0)
	for file: String in files:
		var path := guides_dir.path_join(file)
		guides.append({"path": path, "file": file, "title": title_of(read(path), file.get_basename().capitalize())})
	return guides


## The text of a guide, or "" when it cannot be read.
static func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## The first "# " heading, or `fallback`.
static func title_of(markdown: String, fallback: String) -> String:
	for line in markdown.split("\n"):
		if line.begins_with("# "):
			return line.trim_prefix("# ").strip_edges()
	return fallback
