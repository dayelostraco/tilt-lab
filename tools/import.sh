#!/usr/bin/env bash
# Pulls a .vpx that was edited in the Visual Pinball editor back into table/src.
#
# Geometry edits made in the editor land in table/src/gameitems/*.json and show
# up as a reviewable diff. Script edits do NOT round-trip: scripts/*.vbs stays
# the source of truth, so this refuses to clobber it silently and tells you what
# changed instead.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/vpxtool.sh"

VPX="${1:-$ROOT/table/dist/Pinball Training Lab.vpx}"
SRC="$ROOT/table/src"

[[ -f "$VPX" ]] || { echo "error: no such file: $VPX" >&2; exit 1; }

GENERATED_BEFORE="$(mktemp)"
cp "$SRC/script.vbs" "$GENERATED_BEFORE" 2>/dev/null || : > "$GENERATED_BEFORE"

"$VPXTOOL" extract -f "$VPX" -o "$SRC"

if ! diff -q "$GENERATED_BEFORE" "$SRC/script.vbs" >/dev/null 2>&1; then
  echo
  echo "WARNING: the script inside the .vpx differs from the generated script.vbs."
  echo "Those edits were made in the VPX editor and will be LOST on the next build."
  echo "Port them into scripts/*.vbs, then re-run tools/build.sh."
  echo
  diff -u "$GENERATED_BEFORE" "$SRC/script.vbs" | head -60 || true
fi
rm -f "$GENERATED_BEFORE"

echo "imported: $VPX -> $SRC"
echo "review with: git diff --stat table/src"
