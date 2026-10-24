class_name MarkdownLite
extends RefCounted
## A small Markdown to BBCode converter for RichTextLabel: enough for the
## developer guides (headings, paragraphs, lists, bold, italics, inline code,
## code blocks, links, tables and rules), not a full Markdown implementation.
## Wrapped lines of a paragraph or list item are joined, as in Markdown.

const HEADING_SIZES := [30, 24, 20, 18]
const CODE_COLOR := "#E6D3A8"
const LINK_COLOR := "#8FC7CC"
const MUTED := "#6F8F95"
const RULE := "────────────────────────────"
## Code spans (the viewer turns font ligatures off, so "--" stays two hyphens).
const CODE_OPEN := "[color=%s][code]"
const CODE_CLOSE := "[/code][/color]"
## Marks code spans while emphasis is converted (never in guide text).
const CODE_MARK := "\u0001%d\u0002"


static func to_bbcode(markdown: String) -> String:
	var out := PackedStringArray()
	var block := ""      # the paragraph or list item being collected
	var prefix := ""     # its bullet and indent
	var in_code := false
	for raw in markdown.replace("\r", "").split("\n"):
		var line: String = raw
		var stripped := line.strip_edges()
		if stripped.begins_with("```"):
			_flush(out, prefix, block)
			block = ""
			in_code = not in_code
			continue
		if in_code:
			out.append((CODE_OPEN % CODE_COLOR) + _escape(line) + CODE_CLOSE)
			continue
		var new_item := _list_prefix(line)
		var starts_block := stripped.is_empty() or stripped.begins_with("#") or stripped.begins_with("|") \
			or stripped == "---" or stripped == "***" or stripped.begins_with(">") or not new_item.is_empty()
		if not starts_block and not block.is_empty():
			block += " " + stripped  # continuation of a wrapped line
			continue
		_flush(out, prefix, block)
		block = ""
		prefix = ""
		if stripped.is_empty():
			out.append("")
		elif stripped.begins_with("|"):
			if not stripped.replace("|", "").replace("-", "").replace(":", "").strip_edges().is_empty():
				var cells := PackedStringArray()
				for cell in stripped.trim_prefix("|").trim_suffix("|").split("|"):
					cells.append(_inline(cell.strip_edges()))
				out.append("  " + ("  [color=%s]│[/color]  " % MUTED).join(cells))
		elif stripped == "---" or stripped == "***":
			out.append("[color=%s]%s[/color]" % [MUTED, RULE])
		elif stripped.begins_with("#") and _heading_level(stripped) > 0:
			var level := _heading_level(stripped)
			var size: int = HEADING_SIZES[mini(level - 1, HEADING_SIZES.size() - 1)]
			out.append("[font_size=%d][b]%s[/b][/font_size]" % [size, _inline(stripped.substr(level + 1).strip_edges())])
		elif stripped.begins_with(">"):
			out.append("[i]%s[/i]" % _inline(stripped.trim_prefix(">").strip_edges()))
		elif not new_item.is_empty():
			prefix = new_item
			block = _item_text(stripped)
		else:
			block = stripped
	_flush(out, prefix, block)
	return "\n".join(out)


static func _flush(out: PackedStringArray, prefix: String, block: String) -> void:
	if not block.is_empty():
		out.append(prefix + _inline(block))


static func _heading_level(stripped: String) -> int:
	var level := 0
	while level < stripped.length() and stripped[level] == "#":
		level += 1
	return level if level < stripped.length() and stripped[level] == " " else 0


## The bullet to show for a list item line ("" when the line is not one).
static func _list_prefix(line: String) -> String:
	var stripped := line.strip_edges()
	var pad := "    ".repeat((line.length() - line.lstrip(" ").length()) / 2)
	if stripped.begins_with("- [ ] ") or stripped.begins_with("- [x] "):
		return pad + "  ☐  "
	if stripped.begins_with("- ") or stripped.begins_with("* "):
		return pad + "  •  "
	var number := RegEx.create_from_string("^(\\d+)\\. ").search(stripped)
	if number:
		return pad + "  %s.  " % number.get_string(1)
	return ""


static func _item_text(stripped: String) -> String:
	if stripped.begins_with("- [ ] ") or stripped.begins_with("- [x] "):
		return stripped.substr(6)
	if stripped.begins_with("- ") or stripped.begins_with("* "):
		return stripped.substr(2)
	return RegEx.create_from_string("^\\d+\\. ").sub(stripped, "")


## Inline markup: `code`, **bold**, *italic* / _italic_, [text](link).
static func _inline(text: String) -> String:
	var codes := PackedStringArray()
	var parts := text.split("`")
	var marked := ""
	for i in parts.size():
		if i % 2 == 1 and i < parts.size() - 1:
			marked += CODE_MARK % codes.size()
			codes.append((CODE_OPEN % CODE_COLOR) + _escape(parts[i]) + CODE_CLOSE)
		else:
			marked += _escape(parts[i]) if i % 2 == 0 else "`" + _escape(parts[i])
	for m in RegEx.create_from_string("\\[lb\\]([^\\]]*?)\\]\\(([^)]*)\\)").search_all(marked):
		var label := m.get_string(1)
		var target := m.get_string(2)
		var shown := "[color=%s]%s[/color]" % [LINK_COLOR, label]
		if target != label and not target.ends_with("/" + label):
			shown += " (%s)" % target
		marked = marked.replace(m.get_string(), shown)
	marked = RegEx.create_from_string("\\*\\*(.+?)\\*\\*").sub(marked, "[b]$1[/b]", true)
	marked = RegEx.create_from_string("(?<![\\w*])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![\\w*])").sub(marked, "[i]$1[/i]", true)
	marked = RegEx.create_from_string("(?<![\\w])_(?!\\s)(.+?)(?<!\\s)_(?![\\w])").sub(marked, "[i]$1[/i]", true)
	for i in codes.size():
		marked = marked.replace(CODE_MARK % i, codes[i])
	return marked


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
