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


def split_statements(code: str):
    """Split a VBScript line on top-level colons.

    `Sub X() : DoThing : End Sub` is a legal one-line sub, and treating the
    whole line as a single statement makes the block counter think the Sub was
    never closed. Colons inside string literals are left alone.
    """
    parts, buf, in_str = [], [], False
    for ch in code:
        if ch == '"':
            in_str = not in_str
        if ch == ":" and not in_str:
            parts.append("".join(buf)); buf = []
            continue
        buf.append(ch)
    parts.append("".join(buf))
    return [p.strip() for p in parts if p.strip()]


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
        for st in split_statements(code):
            if re.match(r"^(?:Public\s+|Private\s+)?(Sub|Function|Class|Property)\b", st, re.I):
                depth += 1
            elif re.match(r"^End\s+(Sub|Function|Class|Property)\b", st, re.I):
                depth = max(0, depth - 1)

    for name, hits in sorted(seen.items()):
        if len(hits) > 1:
            where = ", ".join(f"line {n} ({k})" for n, k in hits)
            errors.append(f"duplicate global declaration '{name}': {where}")

    # --- block balance -----------------------------------------------------
    counts = defaultdict(int)
    for raw in lines:
        for code in split_statements(strip_comment(raw).lower()):
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

    # --- Const initialisers must be literals -------------------------------
    # VBScript rejects "Const A = B" when B is another Const, with a COMPILE
    # error, so the whole table fails to load. It is invisible until the
    # script is actually parsed on Windows, which makes it worth catching here.
    CONST_RE = re.compile(r"^\s*(?:Public\s+|Private\s+)?Const\s+(\w+)\s*=\s*(.+?)\s*$", re.I)
    LITERAL = re.compile(
        r"^(?:"
        r"[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?"   # number
        r"|&[hH][0-9a-fA-F]+"                       # hex
        r'|"[^"]*"'                                 # string
        r"|True|False|Empty|Nothing|Null"           # keyword literal
        r")$", re.I)
    for n, raw in enumerate(lines, 1):
        m = CONST_RE.match(strip_comment(raw))
        if m and not LITERAL.match(m.group(2).strip()):
            errors.append(f"line {n}: Const {m.group(1)} = {m.group(2).strip()!r} "
                          f"is not a literal; VBScript rejects this at COMPILE time")

    # --- every referenced table object must exist --------------------------
    # The ported VPW code addresses table parts by name. A missing part is a
    # runtime error that only appears once the table is played on Windows,
    # which is the slowest possible way to find out.
    import json
    gi_dir = ROOT / "table/src/gameitems"
    parts = set()
    if gi_dir.is_dir():
        for f in gi_dir.glob("*.json"):
            try:
                for v in json.loads(f.read_text()).values():
                    if isinstance(v, dict) and v.get("name"):
                        parts.add(v["name"].lower())
            except Exception:
                pass
    col_file = ROOT / "table/src/collections.json"
    if col_file.is_file():
        for c in json.loads(col_file.read_text()):
            if c.get("name"):
                parts.add(c["name"].lower())

    # Names the script defines itself, plus VPX globals, are not table parts.
    defined = {m.group(2).lower() for l in lines
               for m in [DECL.match(strip_comment(l))] if m}
    # Sub/Function parameters are locals, and VPW passes flippers and table
    # objects into subs constantly, so without these the check is all noise.
    PARAMS = re.compile(r"^\s*(?:Public\s+|Private\s+)?(?:Sub|Function)\s+\w+\s*\(([^)]*)\)", re.I)
    for l in lines:
        m = PARAMS.match(strip_comment(l))
        if m:
            for a in m.group(1).split(","):
                a = a.strip().removeprefix("ByVal ").removeprefix("ByRef ").strip()
                if a:
                    defined.add(a.lower())
    # Debug.Print is VBScript's own debugger object, not a table part.
    BUILTIN = {"table1", "activeball", "controller", "vpmtimer", "err", "rnd",
               "gbot", "me", "nothing", "true", "false", "empty", "null", "debug"}

    OBJ = re.compile(r"\b([A-Za-z_]\w*)\s*\.\s*(?:[A-Za-z_]\w*)")
    STR = re.compile(r'"[^"]*"')
    referenced = defaultdict(list)
    for n, raw in enumerate(lines, 1):
        # Message text is full of things like "docs/physics.md" that look like
        # object access. Strings cannot contain a real reference, so drop them.
        code = STR.sub('""', strip_comment(raw))
        for m in OBJ.finditer(code):
            referenced[m.group(1).lower()].append(n)

    for name, where in sorted(referenced.items()):
        if name in parts or name in defined or name in BUILTIN:
            continue
        # Locals and class members dominate the rest; only flag names that
        # look like table parts, i.e. that are never declared anywhere.
        if re.search(rf"\b(?:Dim|Set|Const|Public|Private|Function|Sub|Class|For Each)\s+{re.escape(name)}\b",
                     "\n".join(lines), re.I):
            continue
        warnings.append(f"line {where[0]}: '{name}' used as an object but is not "
                        f"a table part or a declared variable")

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
