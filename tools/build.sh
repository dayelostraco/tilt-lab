#!/usr/bin/env bash
# Builds table/dist/Pinball Training Lab.vpx from the tracked sources.
#
#   scripts/*.vbs        -> concatenated into table/src/script.vbs  (generated)
#   table/src/           -> assembled into the .vpx                 (vpxtool)
#
# The extracted directory is the source of truth; the .vpx is a build artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/vpxtool.sh"

SRC="$ROOT/table/src"
OUT="$ROOT/table/dist/Pinball Training Lab.vpx"
GENERATED="$SRC/script.vbs"

mkdir -p "$ROOT/table/dist"

# --- 1. Assemble the VBScript from its modules -------------------------------
# Modules are concatenated in filename order; the numeric prefixes define it.
# Portable read-into-array: macOS ships bash 3.2, which has no `mapfile`.
MODULES=()
while IFS= read -r m; do MODULES+=("$m"); done \
  < <(find "$ROOT/scripts" -maxdepth 1 -name '*.vbs' | sort)
if [[ ${#MODULES[@]} -eq 0 ]]; then
  echo "error: no modules found in scripts/" >&2
  exit 1
fi

{
  echo "' ============================================================================"
  echo "'  GENERATED FILE - DO NOT EDIT"
  echo "'"
  echo "'  Built from scripts/*.vbs by tools/build.sh."
  echo "'  Edit the module files instead; this copy is overwritten on every build."
  echo "' ============================================================================"
  echo
  for m in "${MODULES[@]}"; do
    echo "' ---------------------------------------------------------------------------"
    echo "'  module: scripts/$(basename "$m")"
    echo "' ---------------------------------------------------------------------------"
    cat "$m"
    echo
  done
} > "$GENERATED"

echo "script: $(wc -l < "$GENERATED" | tr -d ' ') lines from ${#MODULES[@]} module(s)"

# --- 2. Static-check the assembled script ------------------------------------
python3 "$ROOT/tools/check.py"

# --- 3. Assemble the .vpx ----------------------------------------------------
"$VPXTOOL" assemble -f "$SRC" "$OUT"

# --- 4. Sanity-check the result ----------------------------------------------
"$VPXTOOL" verify "$OUT"

echo "built: $OUT ($(du -h "$OUT" | cut -f1))"
