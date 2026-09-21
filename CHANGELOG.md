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

### Notes
- No drills yet. The table boots and plays as a plain lower-playfield table.
  The full nine-drill roster is registered in the menu so the menu itself can
  be validated in VR; nothing is behind those entries until milestone 4.
- Physics is still the stock blank-table physics; the VPW/nFozzy layer lands in
  milestone 2.
