"""Writes build_info.json (the commit and time of a build) next to project.godot,
so an exported game can name its commit in diagnostics. Run before exporting:

    python3 tools/write_build_info.py

The file is ignored by Git (a commit cannot contain its own id). Without it,
a game run from the project reads the commit from .git directly, and an
exported game shows only its version.
"""
import datetime
import json
import os
import subprocess

ROOT = os.path.join(os.path.dirname(__file__), "..")
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
info = {"commit": commit, "built_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")}
with open(os.path.join(ROOT, "build_info.json"), "w") as f:
    json.dump(info, f, indent=1)
print("wrote build_info.json:", info)
