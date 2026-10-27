#!/usr/bin/env python3
"""Little Captain's Hat: keeps the three GDScript guides honest.

The guides inventory every GDScript file, one entry each:
  docs/technical/GDSCRIPT_GUIDE_EN.md     (for the Captain, English)
  docs/technical/GDSCRIPT_GUIDE_DA.md     (for the Captain, Danish)
  docs/technical/GDSCRIPT_ARCHITECTURE.md (for developers and Claude)
An entry is a heading line of exactly this form:  ### `src/core/loc.gd`

This checker (no Godot, no network; Python 3.8+, Windows or Linux):
  1. lists the project's .gd files (tracked, plus new untracked ones);
  2. checks each appears exactly once in each guide (no missing entries,
     no duplicates, no entries for scripts that no longer exist);
  3. compares each script's fingerprint (SHA-256 of its text, line endings
     normalised) with the one recorded in the manifest when its entries
     were last REVIEWED (docs/technical/gdscript_guides_manifest.json).
A changed fingerprint means "review this script's three entries", not that
they are wrong. The checker never writes descriptions.

Usage:
  python tools/docs/check_gdscript_guides.py
      Check. Exit code 0 when everything is complete and reviewed, 1 when
      something needs attention (each item is explained).

  python tools/docs/check_gdscript_guides.py --acknowledge PATH [PATH ...] --note "what you reviewed"
      After you have READ the listed scripts and their entries in all three
      guides (and edited the entries where needed), record the review: the
      manifest takes the scripts' current fingerprints, today's date and
      your note. Works for new scripts (their entries must exist) and for
      removed ones (their entries must be gone; the manifest forgets them).
      There is deliberately no "acknowledge everything" switch: each script
      is named, so a review is never just a regenerated hash.

  python tools/docs/check_gdscript_guides.py --init --note "..."
      Only when the manifest does not exist yet: records every script once
      (after a complete first review of all three guides).
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GUIDES = {
    "EN": "docs/technical/GDSCRIPT_GUIDE_EN.md",
    "DA": "docs/technical/GDSCRIPT_GUIDE_DA.md",
    "ARCH": "docs/technical/GDSCRIPT_ARCHITECTURE.md",
}
MANIFEST = "docs/technical/gdscript_guides_manifest.json"
ENTRY = re.compile(r"^### `([^`]+\.gd)`[ \t]*$", re.M)
SKIP_PREFIXES = (".godot/", "addons/")


def _out(text=""):
    try:
        print(text)
    except UnicodeEncodeError:  # an old Windows console
        print(text.encode("ascii", "replace").decode("ascii"))


def project_scripts():
    """The .gd files: tracked by git, plus new ones not yet added (and not ignored)."""
    found = set()
    try:
        for args in (["ls-files", "*.gd"], ["ls-files", "--others", "--exclude-standard", "*.gd"]):
            out = subprocess.run(["git"] + args, cwd=ROOT, capture_output=True, text=True, check=True).stdout
            found.update(p.strip() for p in out.splitlines() if p.strip())
        # A tracked file deleted in the working tree is gone.
        found = {p for p in found if os.path.isfile(os.path.join(ROOT, p))}
    except (OSError, subprocess.CalledProcessError):
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in files:
                if name.endswith(".gd"):
                    found.add(os.path.relpath(os.path.join(base, name), ROOT).replace(os.sep, "/"))
    return sorted(p for p in found if not p.startswith(SKIP_PREFIXES))


def fingerprint(path):
    data = open(os.path.join(ROOT, path), "rb").read().replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()[:16]


def guide_entries(key):
    path = os.path.join(ROOT, GUIDES[key])
    if not os.path.isfile(path):
        return None
    counts = {}
    for match in ENTRY.finditer(open(path, encoding="utf-8").read()):
        counts[match.group(1)] = counts.get(match.group(1), 0) + 1
    return counts


def load_manifest():
    path = os.path.join(ROOT, MANIFEST)
    if not os.path.isfile(path):
        return None
    return json.load(open(path, encoding="utf-8"))


def save_manifest(manifest):
    manifest["scripts"] = dict(sorted(manifest["scripts"].items()))
    with open(os.path.join(ROOT, MANIFEST), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")


def inventory_problems(scripts):
    """Missing, duplicate and orphan entries, per guide: [(guide, kind, path)]."""
    problems = []
    existing = set(scripts)
    for key in GUIDES:
        entries = guide_entries(key)
        if entries is None:
            problems.append((key, "guide file missing", GUIDES[key]))
            continue
        for path in scripts:
            if entries.get(path, 0) == 0:
                problems.append((key, "no entry", path))
            elif entries[path] > 1:
                problems.append((key, "%d entries (duplicate)" % entries[path], path))
        for path in sorted(entries):
            if path not in existing:
                problems.append((key, "entry for a script that does not exist", path))
    return problems


def review_problems(scripts, manifest):
    """[(kind, path)]: scripts whose entries need a review."""
    problems = []
    recorded = manifest.get("scripts", {})
    for path in scripts:
        if path not in recorded:
            problems.append(("new script, never reviewed", path))
        elif recorded[path].get("sha") != fingerprint(path):
            problems.append(("changed since its entries were reviewed (%s)" % recorded[path].get("reviewed", "?"), path))
    for path in sorted(recorded):
        if path not in scripts:
            problems.append(("removed script still in the manifest", path))
    return problems


def check():
    scripts = project_scripts()
    inventory = inventory_problems(scripts)
    manifest = load_manifest()
    reviews = review_problems(scripts, manifest) if manifest else []
    _out("GDScript guides: %d scripts; guides: %s" % (len(scripts), ", ".join(GUIDES.values())))
    if inventory:
        _out("")
        _out("Inventory problems (fix the guides; every script needs exactly one entry in each):")
        for key, kind, path in inventory:
            _out("  [%s] %s: %s" % (key, kind, path))
    if manifest is None:
        _out("")
        _out("No manifest yet (%s). After a complete review, run with --init --note \"...\"." % MANIFEST)
    elif reviews:
        _out("")
        _out("Needs a documentation review (read the script, check its entry in all three guides, edit")
        _out("what is out of date, then acknowledge it with --acknowledge PATH --note \"...\"):")
        for kind, path in reviews:
            _out("  %s: %s" % (path, kind))
    if not inventory and manifest is not None and not reviews:
        _out("All %d scripts have exactly one reviewed entry in each guide." % len(scripts))
        return 0
    return 1


def acknowledge(paths, note):
    manifest = load_manifest()
    if manifest is None:
        _out("No manifest yet: use --init.")
        return 1
    scripts = set(project_scripts())
    entries = {key: guide_entries(key) or {} for key in GUIDES}
    today = datetime.date.today().isoformat()
    failed = False
    for raw in paths:
        path = raw.replace("\\", "/")
        if path.startswith("./"):
            path = path[2:]
        counts = {key: entries[key].get(path, 0) for key in GUIDES}
        if path in scripts:
            if any(n != 1 for n in counts.values()):
                _out("Not acknowledged: %s must have exactly one entry in each guide first (%s)." % (path, counts))
                failed = True
                continue
            manifest["scripts"][path] = {"sha": fingerprint(path), "reviewed": today, "note": note}
            _out("Reviewed: %s" % path)
        else:
            if any(n != 0 for n in counts.values()):
                _out("Not acknowledged: %s no longer exists; remove its entries from the guides first (%s)." % (path, counts))
                failed = True
                continue
            if manifest["scripts"].pop(path, None) is not None:
                _out("Forgotten (removed script): %s" % path)
            else:
                _out("Unknown path, nothing to do: %s" % path)
    save_manifest(manifest)
    return 1 if failed else 0


def init(note):
    if load_manifest() is not None:
        _out("The manifest already exists: acknowledge individual scripts with --acknowledge.")
        return 1
    scripts = project_scripts()
    problems = inventory_problems(scripts)
    if problems:
        _out("Cannot initialise: the guides are incomplete (%d problems). Run without arguments to see them." % len(problems))
        return 1
    today = datetime.date.today().isoformat()
    save_manifest({"version": 1, "about": "Fingerprints of each .gd file when its entries in the three GDScript guides were last reviewed. "
                   "Update only with tools/docs/check_gdscript_guides.py --acknowledge after a review.",
                   "scripts": {p: {"sha": fingerprint(p), "reviewed": today, "note": note} for p in scripts}})
    _out("Manifest created for %d scripts." % len(scripts))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Check the GDScript guides against the code.")
    parser.add_argument("--acknowledge", nargs="+", metavar="PATH", help="record a completed review of these scripts")
    parser.add_argument("--init", action="store_true", help="create the manifest (first complete review only)")
    parser.add_argument("--note", default="", help="what was reviewed (required with --acknowledge and --init)")
    args = parser.parse_args()
    if (args.acknowledge or args.init) and not args.note.strip():
        _out("--note is required: say what you reviewed.")
        return 2
    if args.init:
        return init(args.note.strip())
    if args.acknowledge:
        return acknowledge(args.acknowledge, args.note.strip())
    return check()


if __name__ == "__main__":
    sys.exit(main())
