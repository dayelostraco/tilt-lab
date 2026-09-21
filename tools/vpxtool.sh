#!/usr/bin/env bash
# Locates (or installs) the vpxtool binary used for all VPX pack/unpack operations.
# vpxtool is the only supported way this project reads and writes .vpx files, so
# builds stay reproducible from a plain checkout without opening the VPX editor.
set -euo pipefail

VPXTOOL_VERSION="v0.34.5"
VPXTOOL_BIN="${VPXTOOL_BIN:-$HOME/.local/bin/vpxtool}"

vpxtool_install() {
  local os arch asset tmp
  case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux)  os=linux ;;
    *) echo "unsupported OS: $(uname -s) (on Windows use the .zip release)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64 ;;
    x86_64)        arch=x86_64 ;;
    *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
  esac
  asset="vpxtool-${os}-${arch}-${VPXTOOL_VERSION}.tar.gz"
  tmp="$(mktemp -d)"
  echo "installing vpxtool ${VPXTOOL_VERSION} (${os}-${arch}) -> ${VPXTOOL_BIN}" >&2
  curl -fsSL -o "$tmp/$asset" \
    "https://github.com/francisdb/vpxtool/releases/download/${VPXTOOL_VERSION}/${asset}"
  tar xzf "$tmp/$asset" -C "$tmp"
  mkdir -p "$(dirname "$VPXTOOL_BIN")"
  mv "$tmp/vpxtool" "$VPXTOOL_BIN"
  chmod +x "$VPXTOOL_BIN"
  # Gatekeeper quarantines curl downloads on macOS; strip it or exec fails silently.
  xattr -d com.apple.quarantine "$VPXTOOL_BIN" 2>/dev/null || true
  rm -rf "$tmp"
}

vpxtool_path() {
  if [[ ! -x "$VPXTOOL_BIN" ]]; then
    if command -v vpxtool >/dev/null 2>&1; then
      command -v vpxtool
      return
    fi
    vpxtool_install >&2
  fi
  echo "$VPXTOOL_BIN"
}

# When sourced, expose $VPXTOOL. When run directly, just proxy the arguments.
VPXTOOL="$(vpxtool_path)"
export VPXTOOL
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  exec "$VPXTOOL" "$@"
fi
