# Tilt Lab

A Visual Pinball X table built as a **training facility**, not a game.

Tilt Lab exists to deliver the same ball to the same place at the same speed,
over and over, and to say something objective about what you did with it. It
drills the ball-control techniques that transfer to a physical machine: drop
catches, live catches, dead bounces, post passes, cradle separation,
controlled backhands, shot accuracy, recovery from bad feeds, and knowing
which of those a given incoming ball calls for.

Success here is measured by **control**, not by survival or score.

```
CONTROL  ->  TRANSFER  ->  AIM  ->  SCORE
```

## Status

**Milestone 1 of 10: project bootstrap.** The table builds, boots and plays as
a plain lower-playfield table. There are no drills yet, and the physics is
still stock blank-table physics, which does not feel like a real machine. That
is the next milestone and it is the highest-value work in the project.

See [`TODO.md`](TODO.md) for the current task list and
[`CHANGELOG.md`](CHANGELOG.md) for what has landed.

## Target environment

- Windows, **Visual Pinball X 10.8.1 BGFX 64-bit**
- PCVR: Meta Quest 3 over Virtual Desktop, OpenXR
- Desktop mode usable where practical
- **No ROM, no PUP pack, no licensed assets required**

## Build

Requires `bash`, `curl` and `python3`. The build downloads a pinned `vpxtool`
release into `~/.local/bin` on first use.

```bash
tools/build.sh
```

That concatenates `scripts/*.vbs` into the table script, static-checks it,
assembles `table/dist/Pinball Training Lab.vpx`, and verifies the result.

Then copy the built `.vpx` to your VPX tables folder on Windows and load it.
Full steps, including what should happen and what to report if it does not,
are in [`docs/test-procedures.md`](docs/test-procedures.md).

## How the repository is laid out

```
scripts/        VBScript modules, concatenated into the table script at build
table/src/      the extracted table: source of truth for all geometry
table/dist/     built .vpx (gitignored, it is an artifact)
tools/          build, import, static check, vpxtool bootstrap
docs/           architecture, physics, drill design, controls, tuning, tests
reference/      provenance of the base table and notes on external references
```

A `.vpx` is an opaque 17 MB OLE blob, so this project never treats one as
source. `table/src/` is the fully extracted table: JSON per game item, `.obj`
meshes and loose media, all of it reviewable in a diff. The `.vpx` is built
from it. See [`docs/vpx-workflow.md`](docs/vpx-workflow.md), including the
`.vbs` sidecar trap that will otherwise cost you an hour.

## Controls

Flippers, plunger, nudge and tilt are **unchanged** from any other VPX table.
Retraining those would drill the wrong reflexes. Everything else is additive.

**In VR**, the drill selector is VPX's in-game Table Options page. Press
**X** on the left Touch controller to open it, left stick to move, right
stick to change a value. VPX exposes no controller state to table scripts and
has no ray-cast picking, so this is the only menu any table can show in a
headset. Drill, side, difficulty, attempts per set, reset delay and the debug
overlay are all selectable there, and the choices persist.

**On desktop**, the same menu is on `F12`, plus keyboard shortcuts:

| Key | Action |
|---|---|
| `1` / `2` / `3` | Start-restart drill / next drill / previous drill |
| `4` / `5` | Increase / decrease difficulty |
| `R` | Reset the current drill |
| `D` | Toggle debug mode |

Only `D` and the menu do anything today; the rest are bound and log their
press so the bindings can be confirmed early. Details in
[`docs/controls.md`](docs/controls.md).

## Documentation

| Document | What it covers |
|---|---|
| [architecture.md](docs/architecture.md) | Layering, configuration, measurement, VR |
| [physics.md](docs/physics.md) | What modern VPX physics is, measured baseline, milestone 2 plan |
| [drill-design.md](docs/drill-design.md) | The nine drills and how success is detected |
| [controls.md](docs/controls.md) | Full key binding table |
| [tuning.md](docs/tuning.md) | Units, the tuning loop, reading the log |
| [vpx-workflow.md](docs/vpx-workflow.md) | Source-controlling a `.vpx` |
| [test-procedures.md](docs/test-procedures.md) | Exact manual test steps for Windows |

## Credits and licence

Tilt Lab descends from the Visual Pinball X blank table and reuses community
routines from the VPX ecosystem. Every borrowing is recorded in
[`ATTRIBUTION.md`](ATTRIBUTION.md). The table is distributed under
[GPL-3.0](LICENSE).
