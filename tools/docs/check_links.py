#!/usr/bin/env python3
"""Checks every internal link in the repository's Markdown documents.

For each tracked .md file (git ls-files) it resolves:
  - inline links and images:  [text](target), ![alt](target)
  - reference definitions:     [label]: target
  - HTML src/href attributes:  <img src="target">, <a href="target">
and reports targets that do not exist. A `#fragment` is checked against the
headings of the target document (GitHub's anchor rules: lower case, spaces to
hyphens, punctuation removed, -1/-2 for repeats) and explicit <a name/id>.
Links inside code spans and fenced code blocks are ignored; external links
(http, https, mailto) are not fetched.

    python3 tools/docs/check_links.py            # report, exit 1 if anything is broken
    python3 tools/docs/check_links.py --json F   # also write the findings to F

Used for the Ship's Library reorganization (docs/DOCUMENTATION_REORGANIZATION_REPORT.md).
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INLINE = re.compile(r"!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REFDEF = re.compile(r"^\s{0,3}\[[^\]]+\]:\s*<?(\S+?)>?(?:\s+.*)?$", re.M)
HTML = re.compile(r"<(?:img|a)\b[^>]*?\b(?:src|href)=\"([^\"]+)\"", re.I)
ANCHOR = re.compile(r"<a\s+(?:name|id)=\"([^\"]+)\"", re.I)


def tracked_markdown():
    out = subprocess.run(["git", "ls-files", "*.md", "**/*.md"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return sorted(set(p for p in out.splitlines() if p))


def strip_code(text):
    text = re.sub(r"^(```|~~~).*?^\1[^\n]*$", "", text, flags=re.S | re.M)
    return re.sub(r"`[^`\n]*`", "", text)


def slug(heading):
    h = re.sub(r"<[^>]+>", "", heading)
    h = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", h)  # [text](url) -> text
    h = re.sub(r"[^\w\- ]", "", h.strip().lower(), flags=re.U)
    return h.replace(" ", "-")


_anchor_cache = {}


def anchors(path):
    if path not in _anchor_cache:
        found = set()
        counts = {}
        try:
            text = open(path, encoding="utf-8").read()
        except (OSError, UnicodeDecodeError):
            text = ""
        body = re.sub(r"^(```|~~~).*?^\1[^\n]*$", "", text, flags=re.S | re.M)
        for m in re.finditer(r"^#{1,6}\s+(.*?)\s*#*\s*$", body, re.M):
            s = slug(m.group(1))
            n = counts.get(s, 0)
            counts[s] = n + 1
            found.add(s if n == 0 else f"{s}-{n}")
        found.update(a.lower() for a in ANCHOR.findall(text))
        _anchor_cache[path] = found
    return _anchor_cache[path]


def check():
    problems = []
    checked = 0
    for doc in tracked_markdown():
        full = os.path.join(ROOT, doc)
        if not os.path.exists(full):
            continue
        text = strip_code(open(full, encoding="utf-8").read())
        targets = INLINE.findall(text) + REFDEF.findall(text) + HTML.findall(text)
        for target in targets:
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue  # http:, https:, mailto:, res: ...
            checked += 1
            path_part, _, fragment = target.partition("#")
            path_part = urllib.parse.unquote(path_part)
            if path_part == "":
                dest = full
            elif path_part.startswith("/"):
                dest = os.path.join(ROOT, path_part.lstrip("/"))
            else:
                dest = os.path.normpath(os.path.join(os.path.dirname(full), path_part))
            if not os.path.exists(dest):
                problems.append({"doc": doc, "target": target, "problem": "missing"})
                continue
            if fragment and dest.endswith(".md") and urllib.parse.unquote(fragment).lower() not in anchors(dest):
                problems.append({"doc": doc, "target": target, "problem": "fragment"})
    return checked, problems


def main():
    checked, problems = check()
    for p in problems:
        print(f"BROKEN ({p['problem']}): {p['doc']} -> {p['target']}")
    print(f"{checked} internal links checked in {len(tracked_markdown())} documents; {len(problems)} broken")
    if "--json" in sys.argv:
        with open(sys.argv[sys.argv.index("--json") + 1], "w") as f:
            json.dump({"checked": checked, "problems": problems}, f, indent=1)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
