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

**Milestones 1 to 4 built; none played by a human yet.**

Everything below was measured by the table testing itself, headlessly, with
no player input. That is a real limitation and it is stated everywhere it
applies.

| | |
|---|---|
| Physics | Current nFozzy/VPW stack, "Modern Stern" profile. Loads clean on VPX 10.8.1.5436, no script error, no audit warning. |
| Feed repeatability | 20 of 20 feeds reach the flipper, arrival speed varies **0.42%** |
| Feed realism | Arrives at **0.808 m/s**, derived from VPX's documented scale, not chosen by feel |
| Drop catch timing | Discrimination **1.44**: timing changes the outcome a lot |
| Live catch timing | Discrimination **1.91**: a ~2-frame window between a clean catch and firing the ball up the table |
| Cradle | Ball settles at 81 vpu from the flipper base, speed 0.03 m/s, repeatable to 1.2 vpu |
| Drills | Drop catch, live catch and cradle; sets, scoring, stats and a VR display all run |

An independent check that does not rely on any reference table: a ball
rolling down the playfield reproduces textbook rolling-sphere dynamics to
**1.5%**. See [`docs/tuning.md`](docs/tuning.md).

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

**Two starting points, depending on why you are here.**

### If you want to train with it

**[docs/player-guide.md](docs/player-guide.md)** covers everything: what you
need, installing, the controls in VR and on desktop, choosing a drill,
reading the verdicts, and what to do when something looks wrong.

### If you want to change it

**[docs/developer-guide.md](docs/developer-guide.md)** is the entry point:
repo layout, the script module map, the build and test loop, and a table of
the traps in this codebase that fail silently.

| Then | Covers |
|---|---|
| [architecture.md](docs/architecture.md) | Layering, configuration, measurement, VR |
| [physics.md](docs/physics.md) | Sources for every value, and the validation results |
| [tuning.md](docs/tuning.md) | Units, the calibration loop, reading the log |
| [drill-design.md](docs/drill-design.md) | The drills and how success is detected |
| [controls.md](docs/controls.md) | Full binding table |
| [vpx-workflow.md](docs/vpx-workflow.md) | Source-controlling a `.vpx` |
| [test-procedures.md](docs/test-procedures.md) | Manual test steps for Windows |

## Credits and licence

Tilt Lab descends from the Visual Pinball X blank table and reuses community
routines from the VPX ecosystem. Every borrowing is recorded in
[`ATTRIBUTION.md`](ATTRIBUTION.md). The table is distributed under
[GPL-3.0](LICENSE).
