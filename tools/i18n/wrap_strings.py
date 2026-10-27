#!/usr/bin/env python3
"""Little Captain's Hat: wrap player-facing string literals in Loc.t() (I019).

Godot translates a control's text by itself when the whole text is a
message, but text that is built (a value inside a sentence, two sentences
joined) must be translated before it is put together. This tool rewrites
the game scripts so every player-facing phrase inside a function body is
asked for in the current language:

    "You slept %s. It is %s." % [a, b]   ->   Loc.t("You slept %s. It is %s.") % [a, b]

What it wraps: string literals inside function bodies that are phrases (a
space or a format placeholder and at least one word), not ids, keys, paths,
node names or developer text. What it leaves alone: class-level constants
and variables (constant expressions), match patterns, comparisons, default
arguments, log/diagnostic/error lines, dev tools, literals already inside
Loc.t / Loc.n. Idempotent: running it again changes nothing.

Usage: python3 tools/i18n/wrap_strings.py [--dry-run] [files...]
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKIP_FILES = ("src/dev/", "src/core/loc.gd", "src/diagnostics/")
SKIP_LINE = re.compile(r"SessionLog\.write|push_warning|push_error|print\(|printerr|print_rich|assert\(|has_method\(|"
                       r"get_node|has_node|find_child|find_children|NodePath|\^\"|preload\(|load\(|res://|user://|"
                       r"StringName\(|set_meta|get_meta|has_meta|ProjectSettings|Input\.|InputMap|is_action|"
                       r"errors\.append|_fail\(|\.name\s*=|add_theme_|theme_type_variation|get_theme|has_theme|"
                       r"\bcall\(\s*\"|callv\(|Engine\.|OS\.|FileAccess|DirAccess|JSON\.|ConfigFile|\.set_value\(|"
                       r"\.get_value\(|Time\.get_|_log\(|Diagnostics|\.has\(\s*\"|\bmatch\b|\bawait\b.*signal")
_TOKEN = re.compile(r'([&^]?)"((?:[^"\\]|\\.)*)"')


class _Lit:
    """A plain string literal found by scanning the line token by token."""
    def __init__(self, m):
        self._m = m

    def start(self):
        return self._m.start(2) - 1

    def end(self):
        return self._m.end()

    def group(self, i):
        return self._m.group(2) if i == 1 else self._m.group(0)


class LIT:
    @staticmethod
    def finditer(code):
        for m in _TOKEN.finditer(code):
            if m.group(1) == "" and not (m.start() > 0 and (code[m.start() - 1].isalnum() or code[m.start() - 1] == "_")):
                yield _Lit(m)

    @staticmethod
    def match(code, pos):
        m = _TOKEN.match(code, pos)
        return _Lit(m) if m and m.group(1) == "" else None
DECL_START = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:const|var|enum|signal)\b")


def phrase(text):
    """A player-facing phrase: words, with a space or a format placeholder."""
    if not re.search(r"[A-Za-z]{2,}", text):
        return False
    if " " not in text.strip():  # single words: node names, ids (Godot translates a control's own text)
        return False
    if text.startswith(("res://", "user://")):
        return False
    if re.search(r"%[-+0-9.]*[dfsi]\s+[a-z°]", text) or re.search(r"[a-z]\s+%[-+0-9.]*[dfsi]", text):
        return True  # a value with its unit or word ("%d nm", "%.1f kn", "%d hour%s")
    if re.fullmatch(r"[a-z0-9_./:\-|>%#=+\[\] ]+", text) and not re.search(r"[a-z]{2,} [a-z]{2,}", text):
        return False  # ids, keys, paths, format keys
    if re.fullmatch(r"[\s%dsif.0-9+\-:/,()x×·\[\]|]+(nm|kn|kg|m|h|s|min|°|%%)?\s*", text):
        return False  # pure number formats ("%.1f", "%d/%d", "%s · %s")
    if text.startswith(("res://", "user://", "ui_", "move_", "#")):
        return False
    if re.search(r"\.(png|tres|tscn|gd|json|ogg|wav|cfg|csv|md|svg|txt)\b", text):
        return False
    if "{" in text and "}" in text and ":" in text:
        return False
    if re.search(r"\[/?(b|i|color|url|font_size|center|right|img)\b", text):
        return False  # BBCode markup is handled where it is built
    return True


def paren_context(code, index):
    """The open calls around `index`: a list of the names before each '('."""
    stack = []
    in_str = False
    i = 0
    while i < index:
        c = code[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "([{":
            m = re.search(r"([\w.]+)\s*$", code[:i])
            stack.append(m.group(1) if m and c == "(" else c)
        elif c in ")]}":
            if stack:
                stack.pop()
        i += 1
    return stack


CONTROL_PROPERTY = re.compile(r"\.(text|tooltip_text|placeholder_text|title)\s*=\s*")
CONTROL_CALLS = ("add_item", "add_check_item", "add_radio_check_item", "_label", "_button", "_add_button", "_make_button",
                 "_add_text", "_cell", "_add_station", "set_tab_title", "set_item_text", "set_item_tooltip", "_build")
ENDS_PLAIN = re.compile(r"^\s*($|#|if\b|else\b|\)|,)")


def plain_control_text(code, m, context):
    """The literal is a control's whole text (alone, or a branch of a choice)."""
    after = code[m.end():]
    before = code[:m.start()].rstrip()
    if not ENDS_PLAIN.match(after) or re.match(r"^\s*(%|\+|\.)", after) or before.endswith(("+", "%")):
        return False
    prop = CONTROL_PROPERTY.search(code)
    if prop and prop.end() <= m.start() and not re.search(r"[%+]\s*$", code[prop.end():m.start()]) \
            and not re.search(r"\(", code[prop.end():m.start()].replace("Loc.t(", "")):
        return True
    if context and context[-1] in CONTROL_CALLS and before.endswith(("(", ",", " else")):
        return True
    return False


UNWRAP = re.compile(r'Loc\.t\(("(?:[^"\\]|\\.)*")\)')


def unwrap_line(code):
    """Undo a wrap that plain_control_text() would not make (idempotent)."""
    out = code
    for m in list(UNWRAP.finditer(code))[::-1]:
        lit = re.match(r'"((?:[^"\\]|\\.)*)"', m.group(1))
        fake = code[:m.start()] + m.group(1) + code[m.end():]
        fm = LIT.match(fake, m.start())
        if fm and plain_control_text(fake, fm, paren_context(fake, m.start())):
            out = out[:m.start()] + m.group(1) + out[m.end():]
    return out


def wrap_line(code):
    out = []
    last = 0
    changed = False
    for m in LIT.finditer(code):
        text = m.group(1)
        before = code[:m.start()].rstrip()
        after = code[m.end():].lstrip()
        if not phrase(text):
            # A single word that is shown (returned, assigned, a value or a
            # branch of a choice): "Gale", "Moored", "Close".
            if not (re.fullmatch(r"[A-Z][a-z’']{2,}", text) and (re.search(r"(\breturn|[^=!<>]=|\belse|:)$", before)
                    or re.match(r"if\b", after))):
                continue
        context = paren_context(code, m.start())
        if any(name in ("Loc.t", "Loc.n", "tr", "tr_n") for name in context):
            continue
        if plain_control_text(code, m, context):
            continue  # Godot translates a control's own text, and again when the language changes
        if before.endswith(("==", "!=", " in", "not in")) or re.match(r"(==|!=|in\b|not in\b)", after):
            continue
        if before.endswith(("begins_with(", "ends_with(", "contains(", "find(", "replace(", "split(", "trim_prefix(",
                            "trim_suffix(", "has(", "erase(", "get(", "count(")):
            continue
        if re.match(r"\.\s*(begins_with|ends_with|contains|find|split|replace)\b", after) and False:
            continue
        if after.startswith(":") and not before.endswith(("(", ",", "[", "=", "return", "+")):
            continue  # a dictionary key or a match pattern
        out.append(code[last:m.start()])
        out.append('Loc.t("%s")' % text)
        last = m.end()
        changed = True
    if not changed:
        return code, False
    out.append(code[last:])
    return "".join(out), True


def process(path, dry_run):
    rel = os.path.relpath(path, ROOT)
    lines = open(path, encoding="utf-8").read().split("\n")
    in_decl = False
    depth = 0
    in_func_sig = False
    count = 0
    for n, line in enumerate(lines):
        stripped = line.strip()
        # Class-level declarations (const/var/enum at column 0) and their
        # continuation lines are constant expressions: left alone.
        if not in_decl and DECL_START.match(line):
            in_decl = True
            depth = 0
        if in_decl:
            depth += line.count("(") + line.count("[") + line.count("{") - line.count(")") - line.count("]") - line.count("}")
            if depth <= 0 and not line.rstrip().endswith("\\"):
                in_decl = False
            continue
        if re.match(r"^(static\s+)?func\b", line):
            in_func_sig = not line.rstrip().endswith(":")
            continue  # default arguments
        if in_func_sig:
            in_func_sig = not line.rstrip().endswith(":")
            continue
        if not line.startswith("\t") or stripped.startswith("#") or SKIP_LINE.search(line):
            continue
        if re.match(r'^"(?:[^"\\]|\\.)*"(\s*,\s*"(?:[^"\\]|\\.)*")*\s*:\s*$', stripped):
            continue  # a match arm
        # Leave trailing comments as they are.
        code, comment = line, ""
        cm = re.search(r'\s#(?=(?:[^"]*"[^"]*")*[^"]*$)', line)
        if cm:
            code, comment = line[:cm.start()], line[cm.start():]
        new, changed = wrap_line(code)
        unwrapped = unwrap_line(new)
        if unwrapped != new or (unwrapped != code and not changed):
            new, changed = unwrapped, unwrapped != code
        if changed:
            lines[n] = new + comment
            count += 1
    if count and not dry_run:
        open(path, "w", encoding="utf-8").write("\n".join(lines))
    return count


if __name__ == "__main__":
    dry = "--dry-run" in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not files:
        files = sorted(glob.glob(os.path.join(ROOT, "src/**/*.gd"), recursive=True))
    total = 0
    for f in files:
        rel = os.path.relpath(os.path.abspath(f), ROOT)
        if rel.startswith(SKIP_FILES):
            continue
        c = process(os.path.abspath(f), dry)
        if c:
            print(f"{c:4d}  {rel}")
        total += c
    print(f"{total} lines {'would change' if dry else 'changed'}")
