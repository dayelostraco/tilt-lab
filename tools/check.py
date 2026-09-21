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

    # --- a parameter must not shadow a global ------------------------------
    # VBScript identifiers are case-insensitive, so `Sub S(drillId)` shadows a
    # global `DrillId`. `DrillId = drillId` then assigns the local to itself
    # and the global is silently never set. No error, no warning, wrong
    # behaviour a long way from the cause.
    PARAMS = re.compile(
        r"^\s*(?:Public\s+|Private\s+)?(?:Sub|Function|Property\s+(?:Get|Let|Set))\s+\w+\s*\(([^)]*)\)",
        re.I)
    globals_lc = {n for n, hits in seen.items()
                  if any(k in ("dim", "const") for _, k in hits)}
    for n, raw in enumerate(lines, 1):
        m = PARAMS.match(strip_comment(raw))
        if not m:
            continue
        for a in m.group(1).split(","):
            a = a.strip().removeprefix("ByVal ").removeprefix("ByRef ").strip()
            if a and a.lower() in globals_lc:
                errors.append(f"line {n}: parameter '{a}' shadows the global of the "
                              f"same name (VBScript is case-insensitive); rename it")

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

    # --- Option Explicit: every identifier must be declared ----------------
    # With Option Explicit, using an undeclared name is a RUNTIME error, and
    # only when that line executes. Deleting a Const while keeping its uses
    # therefore builds, passes every other check, and dies on the table.
    # That happened here.
    KEYWORDS = {
        "if","then","else","elseif","end","sub","function","class","dim","const","set",
        "for","each","next","to","step","while","wend","do","loop","until","select","case",
        "exit","and","or","not","xor","mod","is","new","nothing","true","false","empty","null",
        "byval","byref","public","private","option","explicit","on","error","resume","goto",
        "call","redim","preserve","with","property","get","let","me","in","randomize","stop",
        "erase","execute","executeglobal","eval",
    }
    # VBScript intrinsics and VPX globals that are never declared in script.
    BUILTIN_IDS = {
        "abs","asc","atn","cbool","cbyte","ccur","cdate","cdbl","chr","cint","clng","cos","csng",
        "cstr","date","dateadd","datediff","datepart","dateserial","datevalue","day","escape",
        "filter","fix","formatcurrency","formatdatetime","formatnumber","formatpercent","getlocale",
        "getobject","getref","hex","hour","inputbox","instr","instrrev","int","isarray","isdate",
        "isempty","isnull","isnumeric","isobject","join","lbound","lcase","left","len","loadpicture",
        "log","ltrim","mid","minute","month","monthname","msgbox","now","oct","replace","rgb","right",
        "rnd","round","rtrim","scriptengine","second","setlocale","sgn","sin","space","split","sqr",
        "strcomp","string","strreverse","tan","time","timer","timeserial","timevalue","trim","typename",
        "ubound","ucase","unescape","vartype","weekday","weekdayname","year","array","createobject",
        "err","vbnewline","vbcrlf","vbcr","vblf","vbtab","vbobjecterror","pi",
        # VPX script globals
        "gametime","activeball","getballs","getplayerhwnd","playsound","stopsound","playmusic",
        "endmusic","musicvolume","nudge","nudgegetcalibration","nudgesetcalibration","renderingmode",
        "getcustomparam","gettextfile","getballsize","debug","table1","controller","userdirectory",
        "tabledirectory","vbsdirectory","musicdirectory","showdt","enablestaticprerendering",
        "playsoundat","updatematerial","updatematerialphysics","getmaterial","getmaterialphysics",
        "leftflipperkey","rightflipperkey","lefttiltkey","righttiltkey","centertiltkey","plungerkey",
        "startgamekey","addcreditkey","mechanicaltilt","leftmagnasave","rightmagnasave",
        "keyinsertcoin1","keyinsertcoin2","keyinsertcoin3","keyinsertcoin4","exitgame","soundfx",
        "dofflippers","dofcontactors","dofgear","dofchimes","dofknocker","dofbell","dofshaker",
        "dofoff","dofon","dofpulse","dofsync",
    }
    IDENT = re.compile(r"\b([A-Za-z_]\w*)\b")
    declared = set(defined) | set(parts) | BUILTIN_IDS | KEYWORDS
    # anything declared anywhere, at any indent level, counts
    # Declarations may be comma lists: "Private PolarityIn, PolarityOut" and
    # "Dim a, b(3), c" all declare several names at once, and class members
    # use Public/Private rather than Dim.
    DECL_LIST = re.compile(r"\b(?:Dim|Const|ReDim|Public|Private)\s+((?:[A-Za-z_]\w*\s*(?:\([^)]*\))?\s*,\s*)*[A-Za-z_]\w*\s*(?:\([^)]*\))?)", re.I)
    for l in lines:
        c = strip_comment(l)
        # Public/Private Sub|Function declare a routine, not variables.
        if re.match(r"\s*(?:Public|Private)\s+(?:Sub|Function|Property)\b", c, re.I):
            m = re.match(r"\s*(?:Public|Private)\s+(?:Sub|Function|Property\s+\w+)\s+([A-Za-z_]\w*)", c, re.I)
            if m:
                declared.add(m.group(1).lower())
            continue
        for m in DECL_LIST.finditer(c):
            for nm in m.group(1).split(","):
                nm = nm.strip().split("(")[0].strip()
                if nm:
                    declared.add(nm.lower())
        for m in re.finditer(r"\bSet\s+([A-Za-z_]\w*)", c, re.I):
            declared.add(m.group(1).lower())
        for m in re.finditer(r"\bFor\s+Each\s+([A-Za-z_]\w*)|\bFor\s+([A-Za-z_]\w*)\s*=", c, re.I):
            declared.add((m.group(1) or m.group(2)).lower())
        # Class_Initialize members assigned via Me are declared elsewhere.

    undeclared = defaultdict(list)
    original_case = {}
    for n, raw in enumerate(lines, 1):
        code = STR.sub('""', strip_comment(raw))
        # skip member access: only the head of a dotted chain is a real name
        code = re.sub(r"\.\s*[A-Za-z_]\w*", "", code)
        for m in IDENT.finditer(code):
            nm = m.group(1)
            if nm == "_":          # line-continuation character
                continue
            if nm.lower() not in declared and not nm.isdigit():
                undeclared[nm.lower()].append(n)
                original_case.setdefault(nm.lower(), nm)
    for nm, where in sorted(undeclared.items()):
        # A SCREAMING_SNAKE name is almost certainly a Const whose
        # declaration has been lost; that is an error, not a warning.
        orig = original_case.get(nm, nm)
        kind = "error" if orig.isupper() and "_" in orig else "warn"
        msg = (f"line {where[0]}: '{nm}' is used but never declared "
               f"(Option Explicit makes this a runtime error)")
        if kind == "error":
            errors.append(msg)
        else:
            warnings.append(msg)

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
