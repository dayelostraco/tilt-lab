#!/usr/bin/env python3
"""Static sanity checks on the assembled VBScript.

VPX only reports a script error once the table is loaded on Windows, and the
modular build makes duplicate global declarations the most likely way to break
it. These checks catch that class of mistake from a plain checkout.

This is a structural linter, not a VBScript parser: it will not catch a typo
inside an expression. Loading the table in VPX remains the real test.
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "table/src/script.vbs"

OPENERS = {"sub": "end sub", "function": "end function", "class": "end class",
           "with": "end with", "select": "end select", "property": "end property"}

DECL = re.compile(r"^\s*(?:Public\s+|Private\s+)?(Sub|Function|Class|Const|Dim)\s+([A-Za-z_]\w*)", re.I)


def strip_comment(line: str) -> str:
    """Drop a trailing VBScript comment, honouring quoted strings."""
    out, in_str = [], False
    for ch in line:
        if ch == '"':
            in_str = not in_str
        elif ch == "'" and not in_str:
            break
        out.append(ch)
    return "".join(out)


def main() -> int:
    if not SCRIPT.exists():
        print(f"error: {SCRIPT} not found - run tools/build.sh first", file=sys.stderr)
        return 1

    lines = SCRIPT.read_text(errors="replace").splitlines()
    errors, warnings = [], []

    # --- duplicate global declarations ------------------------------------
    # Only column-0 declarations are global; anything indented is inside a
    # Sub, Function or Class and may legitimately repeat.
    seen = defaultdict(list)
    depth = 0
    for n, raw in enumerate(lines, 1):
        code = strip_comment(raw)
        low = code.strip().lower()
        if not low:
            continue
        m = DECL.match(code)
        if m and depth == 0 and not raw[:1].isspace():
            kind, name = m.group(1).lower(), m.group(2)
            seen[name.lower()].append((n, kind))
        # track Sub/Function/Class nesting so members are not read as globals
        if re.match(r"^\s*(?:Public\s+|Private\s+)?(Sub|Function|Class|Property)\b", code, re.I):
            depth += 1
        elif re.match(r"^\s*End\s+(Sub|Function|Class|Property)\b", code, re.I):
            depth = max(0, depth - 1)

    for name, hits in sorted(seen.items()):
        if len(hits) > 1:
            where = ", ".join(f"line {n} ({k})" for n, k in hits)
            errors.append(f"duplicate global declaration '{name}': {where}")

    # --- block balance -----------------------------------------------------
    counts = defaultdict(int)
    for raw in lines:
        code = strip_comment(raw).strip().lower()
        if not code:
            continue
        for opener, closer in OPENERS.items():
            if re.match(rf"^(?:public\s+|private\s+)?{opener}\b", code) and not code.startswith("end "):
                # "Select Case" opens; a bare "select" does not occur otherwise
                counts[opener] += 1
            if code.startswith(closer):
                counts[opener] -= 1
        # A block If is the only If that needs an End If: "If x Then" with
        # nothing after Then. "If x Then y" is a one-liner and is skipped.
        if re.match(r"^if\b.*\bthen$", code):
            counts["if"] += 1
        if code.startswith("end if"):
            counts["if"] -= 1

    for block, n in sorted(counts.items()):
        if n != 0:
            errors.append(f"unbalanced {block.title()} blocks: {n:+d} unclosed")

    # --- Option Explicit ---------------------------------------------------
    opts = [n for n, l in enumerate(lines, 1) if strip_comment(l).strip().lower() == "option explicit"]
    if len(opts) != 1:
        errors.append(f"expected exactly one 'Option Explicit', found {len(opts)}")
    else:
        before = [n for n, l in enumerate(lines[:opts[0] - 1], 1) if strip_comment(l).strip()]
        if before:
            errors.append(f"'Option Explicit' at line {opts[0]} is preceded by code at line {before[0]}")

    # --- tabs/spaces mix is only cosmetic, but flag stray non-ASCII ---------
    for n, raw in enumerate(lines, 1):
        if any(ord(c) > 127 for c in raw):
            warnings.append(f"line {n}: non-ASCII character (VPX script editor is ANSI)")

    for w in warnings:
        print(f"warn:  {w}")
    for e in errors:
        print(f"ERROR: {e}")

    print(f"\n{SCRIPT.relative_to(ROOT)}: {len(lines)} lines, "
          f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
