# Changelog

All notable changes to Tilt Lab are recorded here.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions track the training capability of the table, not the tooling around it.

## [Unreleased]

### Added
- Milestone 1: project bootstrap.
  - Source-controlled VPX workflow built on `vpxtool` extract/assemble, with
    the extracted table directory as the source of truth and the `.vpx` as a
    build artifact.
  - Modular VBScript: `scripts/*.vbs` are concatenated into the table script
    at build time.
  - Static script checker (`tools/check.py`) for duplicate globals, unbalanced
    blocks and `Option Explicit` placement.
  - Debug and structured-logging core (`scripts/95-debug.vbs`) with a CSV-shaped
    ring buffer.
  - Trainer key hooks that layer on top of, and never replace, the standard
    flipper / plunger / nudge bindings.
  - VR-navigable drill selector built on `Table1.Option`, appearing on the
    in-game UI's Table Options page: drill, side, difficulty, attempts per
    set, reset delay and debug overlay. This is the only menu VPX can show in
    a headset, since it exposes no controller state to table scripts and has
    no ray-cast picking.

- Milestone 2: physics foundation.
  - Current nFozzy/VPW stack ported verbatim from the VPW Lord of the Rings
    (Stern 2003) reference, chosen by surveying six local VPW-era tables.
    Polarity class marked "modified 2023 by nFozzy" / "2024 by rothbauerw".
  - Modern Stern profile: playfield friction 0.24, slope pinned 6.0, flipper
    strength 3200, elasticity falloff 0.15, coil ramp-up 2.5, ball mass 1.0.
  - Global Physics assertion that fails loudly at init, since a Global
    Physics Set silently invalidates the whole correction stack.
  - Rolling sound moved to a per-frame timer, clearing VPX's frame-pacing
    audit warning.
  - `tools/check.py` now verifies every table object the script references
    actually exists, and understands one-line subs and sub parameters.

### Notes
- No drills yet. The table boots and plays as a plain lower-playfield table.
  The full nine-drill roster is registered in the menu so the menu itself can
  be validated in VR; nothing is behind those entries until milestone 4.
- The physics is in but **unvalidated by play**. Seven validation drills are
  written up at the end of `docs/physics.md` and are the gate on milestone 2.
