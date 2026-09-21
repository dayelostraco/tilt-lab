# Physics

## Status

**Current state: stock blank-table physics. The VPW/nFozzy layer is not in
yet.** This document records what is there now, what modern VPX physics
actually consists of, and exactly what milestone 2 has to change.

## Why this matters more here than on a normal table

On a themed table, flipper physics being slightly off costs some realism. On a
trainer it invalidates the product. If the flipper does not return the ball
the way a real one does, the player drills a timing that does not exist, and
the practice transfers negatively. Getting this layer right is the single
highest-value thing in the project.

For the same reason, the rule is: **do not invent a physics model.** Modern
VPX has a proven community implementation. Use it, credit it, and tune within
it.

## What "modern VPX physics" means in 2026

Four separable pieces, all originally from the nFozzy / Fleep / VPW lineage:

1. **nFozzy flipper corrections.** VPX's built-in flipper is geometrically
   correct but returns the ball at angles a real flipper does not. The
   correction wraps each flipper in a trigger and, on exit, applies two lookup
   tables: *polarity* (a positional nudge that varies with where along the
   flipper the ball hit) and *velocity* (a speed multiplier over the same
   axis), plus a *Ycoef* ramp that fades the correction out away from the
   flipper. Implemented as a `FlipperPolarity` class.
2. **Rubber dampeners.** Post and rubber collisions in stock VPX are too
   lively. The dampener rescales the rebound based on impact speed and angle.
3. **TargetBouncer.** Standup targets and posts otherwise return the ball with
   unrealistically clean energy.
4. **Fleep mechanical sounds.** Not physics, but the audio cue for flipper
   contact is part of how a player times a catch, so it belongs in the same
   milestone.

## Reference implementation

The project has **Medieval Madness (Williams 1997) VPW v1.0.1** available
locally as a read-only reference. Its script carries the complete current VPW
stack, tagged by section: `ZNFF` (flipper corrections), `ZDMP` (dampeners),
`ZBOU` (TargetBouncer), `ZFLE` (Fleep sounds), plus a live-catch check.

Nothing from that table is in this repository, and nothing of its artwork,
models or rules ever will be. See [ATTRIBUTION.md](../ATTRIBUTION.md).

**Still wanted:** the VPW *Example* / *Basic* table, which is published
specifically as a starting point for table authors and is the cleaner source
for these routines. It is not available locally. See
[`reference/README.md`](../reference/README.md).

## Measured baseline: what has to change

Both tables use the identical standard playfield, 952.94 x 2164.71 vpu, so
VPW's flipper coordinates and its published lookup tables transfer directly.

### Flippers

| Property | blank table (current) | VPW (target) |
|---|---|---|
| centre, left | 278.21, 1803.27 | 272.80, 1832.50 |
| centre, right | 595.87, 1803.27 | 588.73, 1832.50 |
| `flipper_radius_max` | 117.65 | 116.0 |
| `base_radius` | 20.59 | 20.5 |
| `end_radius` | 11.77 | 11.8 |
| start / end angle | ±120.5 / ±70.0 | ±124.0 / ±75.0 |
| `mass` | 0.7 | 1.0 |
| `strength` | 2600 | 3000 |
| `elasticity` | 0.8 | 0.88 |
| `elasticity_falloff` | 0.001 | 0.15 |
| `friction` | 0.8 | 0.9 |
| `return` | 0.05 | 0.055 |
| `ramp_up` | 0.0 | 2.5 |
| `torque_damping` | 0.25 | 0.375 |
| `torque_damping_angle` | 6.0 | 6.0 |

`elasticity_falloff` is the important one. At 0.001 the flipper returns nearly
all the energy of a fast ball, which is precisely what makes a live catch feel
impossible; 0.15 is what lets a hard shot be absorbed.

`ramp_up` 2.5 gives the coil a spin-up curve instead of instantaneous full
strength, which is what makes the difference between a tap and a full flip.

### Table level

| Property | blank table (current) | VPW (target) |
|---|---|---|
| `gravity` | 1.7629848 | 1.7629848 (same) |
| `friction` | 0.075 | 0.22 |
| `elasticity` | 0.25 | 0.25 (same) |
| `default_scatter` | 0.0 | 2.0 |
| `angle_tilt_min` / `max` | 5.0 / 10.0 | 6.5 / 6.5 |

Playfield `friction` at 0.075 is close to frictionless, which makes a dead
bounce behave nothing like it does on a real machine. `default_scatter` 2.0
adds the small random angular variation that real collisions have.

Fixing tilt angle to 6.5 at both ends pins the playfield slope, which matters
because every feed velocity is calibrated against it. A slope that varies with
a setting would make the whole feed table meaningless.

## Milestone 2 plan

1. Apply the flipper geometry and physics values above in
   `table/src/gameitems/Flipper.*.json`.
2. Apply the table-level values in `table/src/gamedata.json`.
3. Add flipper correction trigger objects and the `FlipperPolarity` class as
   `scripts/40-physics-nfozzy.vbs`, with the polarity / velocity / Ycoef
   tables. Credit nFozzy in the module header and in ATTRIBUTION.md.
4. Add dampeners and TargetBouncer as `scripts/45-physics-damping.vbs`.
5. Validate on Windows against the checklist in
   [test-procedures.md](test-procedures.md).

Do not skip step 5. None of these values can be judged from macOS.
