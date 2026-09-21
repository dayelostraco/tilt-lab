# Attribution

Tilt Lab is built on top of community work. This file records what was reused,
where it came from, and what it obliges us to do. Keep it current: anything
copied into `scripts/` or `table/src/` from another project gets an entry here
in the same commit.

## Base table

**Visual Pinball X blank table** (`blankTable.vpx`)

- Source: the [vpinball/vpinball](https://github.com/vpinball/vpinball)
  repository, `src/assets/blankTable.vpx`
- Local path used: `~/Development/GitHub/vpx/vpinball/src/assets/blankTable.vpx`
- SHA-256 of the exact file used: see [`reference/base-table.sha256`](reference/base-table.sha256)
- Licence: GPL-3.0, as part of the Visual Pinball X distribution

Everything in `table/src/` descends from this file: the playfield dimensions,
the flipper / slingshot / inlane geometry, the VR cabinet and backbox
primitives, the ball-shadow rig, the apron and rails, and the stock asset
library.

Its script header credits:

> Initial table created by fuzzel, jimmyfingers, jpsalas, toxie & unclewilly
> (in alphabetical order). Flipper primitives by zany. Ball rolling sound
> script by jpsalas. Ball shadow by ninuzzu. Ball control & ball dropping sound
> by rothbauerw. DOF by arngrim. Positional sound helper functions by djrobx.
> Plus a lot of input from the whole community.

Those routines survive, reorganised, in `scripts/20-table-core.vbs`,
`scripts/30-sound.vbs` and `scripts/50-ball-shadows.vbs`.

## Physics: nFozzy / VPW stack

**Source: Lord of the Rings (Stern 2003), VPW "Yahoo! Edition"**, by the
Visual Pinball Workshop. Chosen as the reference because it carries the most
current and most complete nFozzy stack of any table available locally. See
[`docs/physics.md`](docs/physics.md) for the survey that led to that choice.

The following are ported **verbatim**, with the original comments preserved
because they carry the reasoning behind the constants:

| Ported into | VPW section | Original authorship |
|---|---|---|
| `scripts/05-math.vbs` | math helpers | VPW |
| `scripts/40-physics-nfozzy.vbs` | `FlipperPolarity` class, polarity / velocity / Ycoef tables | **nFozzy**, modified 2023 by nFozzy, 2024 by **rothbauerw** (`ReProcessBalls`, raised-flipper backhand handling) |
| `scripts/40-physics-nfozzy.vbs` | `FlipperTricks`, `FlipperActivate`, `FlipperDeactivate`, EOS and coil ramp-up constants | **nFozzy**, EOS torque recommendations by **rothbauerw** |
| `scripts/40-physics-nfozzy.vbs` | `CheckLiveCatch`, `FlipperNudge`, `FlipperCradleCollision` | **rothbauerw** / VPW |
| `scripts/40-physics-nfozzy.vbs` | flipper geometry helpers | VPW |
| `scripts/45-physics-damping.vbs` | `Dampener`, `CoRTracker`, `RDampen`, data-mined rubber CoR curves | **nFozzy** / VPW |
| `scripts/45-physics-damping.vbs` | `TargetBouncer` | VPW |

This physics code was **not** authored for this project. It is the Visual
Pinball Workshop's work, reused under the community's normal terms with
credit. Tilt Lab's own contribution at this layer is limited to the profile
selection in `scripts/12-physics-config.vbs`, the Global Physics assertion,
the trigger placement, and the debug reporting.

VPW team credits from the reference tables' script headers: Sixtoe, Tomate,
Apophis, DaRDog, Mcarter, ClarkKent, Bord, CainArg, Freezy, HauntFreaks,
MajorDrain, Tyson171, Niwak, Gedankekojote97, PinStratsDan, and testers
Studlygoorite, Iaakki, Unsavory and Superhac.

**No artwork, model, sound, playfield scan or rule from any reference table is
in this repository.** Those tables are licensed IP. Only the physics code,
which the community publishes for reuse, was taken.

Also inspected as references, nothing taken: Medieval Madness (Williams 1997)
VPW v1.0.1, The Addams Family (Bally 1992), Cirqus Voltaire (Bally 1997),
Tron Legacy (Stern 2011), Star Trek LE (Stern 2013).

## Tooling

**vpxtool** by francisdb: <https://github.com/francisdb/vpxtool>

- Used to extract and assemble `.vpx` files. Not redistributed; `tools/vpxtool.sh`
  downloads the official release binary on demand.
- Licence: MIT

## This project's own work

The training architecture, drill design, ball-delivery subsystem, success
detection, configuration layer, debug/logging core and build tooling are
original to this repository and are covered by [`LICENSE`](LICENSE).

Because the table descends from the GPL-3.0 licensed VPX blank table, the
assembled `.vpx` is distributed under GPL-3.0.
