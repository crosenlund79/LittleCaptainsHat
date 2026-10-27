#!/usr/bin/env python3
"""Little Captain's Hat: check the Danish catalogue against the template (I019).

    python3 tools/i18n/check.py [--warn-length]

Errors (exit code 1):
  - a message of locale/messages.pot missing from locale/da.po, or empty;
  - placeholders (%s, %d, %.1f, %02d, %%, ...) not the same, in the same order;
  - leading or trailing spaces, or the number of line breaks, not the same.
Warnings (with --warn-length): a Danish text much longer than the English
(a rough overflow guard; the in-game check is tests/suites/test_localization.gd).
Messages in da.po that the template no longer has are reported (obsolete).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLACEHOLDER = re.compile(r"%(?:[-+ 0#]*\d*(?:\.\d+)?[sdifxXc]|%)")


def unquote(s):
    s = s.strip()
    assert s.startswith('"') and s.endswith('"'), s
    out, i = [], 1
    while i < len(s) - 1:
        c = s[i]
        if c == "\\":
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, "\\" + n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def parse(path):
    """{(context, msgid): {"plural": str|None, "str": [str, ...]}} (header skipped)."""
    entries = {}
    cur, field = None, None

    def flush():
        if cur and cur.get("msgid", "") != "":
            entries[(cur.get("msgctxt", ""), cur["msgid"])] = {"plural": cur.get("msgid_plural"), "str": [cur.get(k, "") for k in sorted(k for k in cur if k.startswith("msgstr"))]}

    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            if not line.strip():
                flush()
                cur, field = None, None
            continue
        m = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[\d\])?)\s+(".*")$', line)
        if m:
            if m.group(1) == "msgctxt" or (m.group(1) == "msgid" and cur and "msgid" in cur):
                flush()
                cur = None
            cur = cur or {}
            field = m.group(1)
            cur[field] = unquote(m.group(2))
        elif line.startswith('"') and cur is not None and field:
            cur[field] += unquote(line)
    flush()
    return entries


def edges(s):
    return (len(s) - len(s.lstrip(" ")), len(s) - len(s.rstrip(" ")), s.count("\n"))


def main():
    pot = parse(os.path.join(ROOT, "locale/messages.pot"))
    po = parse(os.path.join(ROOT, "locale/da.po"))
    errors, warnings = [], []
    for key, e in pot.items():
        context, msgid = key
        label = f"[{context}] {msgid!r}" if context else repr(msgid)
        t = po.get(key)
        if t is None or not any(t["str"]) or "" in t["str"]:
            errors.append(f"missing: {label}")
            continue
        sources = [msgid, e["plural"] or msgid] if e["plural"] else [msgid]
        for i, s in enumerate(t["str"][:len(sources)] if e["plural"] else t["str"][:1]):
            src = sources[min(i, len(sources) - 1)]
            if PLACEHOLDER.findall(src) != PLACEHOLDER.findall(s):
                errors.append(f"placeholders differ: {label} -> {s!r}")
            if edges(src) != edges(s):
                errors.append(f"spaces or line breaks differ: {label} -> {s!r}")
            if "--warn-length" in sys.argv and len(src) >= 12 and len(s) > len(src) * 1.45 + 6:
                warnings.append(f"long ({len(s)} vs {len(src)}): {label} -> {s!r}")
    obsolete = [k for k in po if k not in pot]
    for w in warnings:
        print("warning:", w)
    for err in errors:
        print("error:", err)
    print(f"{len(pot)} messages, {len(pot) - sum(1 for e in errors if e.startswith('missing'))} translated, "
          f"{len(errors)} errors, {len(warnings)} warnings, {len(obsolete)} obsolete in da.po")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
