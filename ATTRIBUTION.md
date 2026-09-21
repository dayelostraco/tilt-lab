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

## Physics reference (inspected, not yet copied)

**Medieval Madness (Williams 1997) VPW v1.0.1** by the Visual Pinball Workshop

- Used as a **read-only reference** for modern VPX physics conventions while
  planning milestone 2. Its script contains the current VPW stack: nFozzy
  flipper corrections (`FlipperPolarity`), Fleep mechanical sounds, rubber
  dampeners, `TargetBouncer`, and the live-catch check.
- VPW credits from its script header: Sixtoe, Tomate, Apophis, DaRDog, Mcarter,
  ClarkKent, Bord, CainArg, Freezy, HauntFreaks, MajorDrain, Tyson171, Niwak,
  Gedankekojote97, PinStratsDan, and testers Studlygoorite, Iaakki, Unsavory,
  Superhac.
- **Nothing from this table is in the repository.** Medieval Madness is
  licensed IP; its playfield scan, models, sounds and rules are not reusable.
  Only the physics *approach* and the published nFozzy/VPW tuning constants are
  of interest, and those are credited individually when they land.

> When physics code is ported in milestone 2, each ported block gets its own
> entry here naming the original author (nFozzy, Fleep, rothbauerw, apophis,
> and so on) and the section tag it came from.

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
