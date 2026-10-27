#!/usr/bin/env python3
"""Little Captain's Hat (I019): texts with decimal placeholders use Loc.format.

Rewrites  Loc.t("... %.1f ...") % expr       ->  Loc.format("... %.1f ...", expr)
          Loc.n("a", "b", n) % expr           ->  Loc.format_plural("a", "b", n, expr)
so Danish shows decimals with a comma (5,5 sm). Idempotent.
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CALL = re.compile(r'Loc\.(t|n)\(((?:\s*"(?:[^"\\]|\\.)*"\s*,?)+)([^()"]*)\)\s*%\s*')
DECIMAL = re.compile(r'%[-+ 0#]*\d*\.\d+f')
STOP_WORDS = (" if ", " else ", " and ", " or ", " + ")


def expression_end(src, i):
    if src[i] == "[":
        depth, j = 0, i
        while j < len(src):
            c = src[j]
            if c == '"':
                j = skip_string(src, j)
                continue
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
        raise ValueError("unbalanced")
    depth, j = 0, i
    while j < len(src):
        c = src[j]
        if c == '"':
            j = skip_string(src, j)
            continue
        if depth == 0 and (c in ",)]}\n" or any(src.startswith(w, j) for w in STOP_WORDS)):
            return j
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        j += 1
    return j


def skip_string(src, j):
    j += 1
    while src[j] != '"':
        j += 2 if src[j] == "\\" else 1
    return j + 1


def process(path):
    src = open(path, encoding="utf-8").read()
    out, last, count = [], 0, 0
    for m in CALL.finditer(src):
        if m.start() < last or not DECIMAL.search(m.group(2)):
            continue
        end = expression_end(src, m.end())
        expr = src[m.end():end].rstrip()
        end = m.end() + len(expr)
        inner = (m.group(2) + m.group(3)).rstrip()
        new = ('Loc.format(%s, %s)' if m.group(1) == "t" else 'Loc.format_plural(%s, %s)') % (inner.rstrip(", "), expr)
        out.append(src[last:m.start()])
        out.append(new)
        last = end
        count += 1
    if count:
        out.append(src[last:])
        open(path, "w", encoding="utf-8").write("".join(out))
    return count


if __name__ == "__main__":
    total = 0
    for f in sorted(glob.glob(os.path.join(ROOT, "src/**/*.gd"), recursive=True)):
        if f.endswith("src/core/loc.gd"):
            continue
        c = process(f)
        if c:
            print(f"{c:3d} {os.path.relpath(f, ROOT)}")
        total += c
    print(total, "rewritten")
