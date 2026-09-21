# Reference material

Nothing copyrighted is committed here. This file records what was used, what
is still wanted, and where to put local copies.

## Committed

- **`base-table.sha256`** pins the exact `blankTable.vpx` that `table/src/`
  was seeded from, so the provenance of the tracked table stays checkable
  without committing the original 17 MB file.

## Used locally, not committed

**Medieval Madness (Williams 1997) VPW v1.0.1**

Read-only physics reference for milestone 2. Its script carries the current
VPW stack tagged by section: `ZNFF` flipper corrections, `ZDMP` dampeners,
`ZBOU` TargetBouncer, `ZFLE` Fleep sounds. Licensed IP; none of its artwork,
models, sounds or rules are reusable, and none are in this repository.

To extract its script for reading:

```bash
tools/vpxtool.sh extractvbs "/path/to/Medieval Madness (Williams 1997) VPW v1.0.1.vpx"
```

That writes a `.vbs` **next to the `.vpx`**, and Visual Pinball will then load
that sidecar instead of the table's embedded script. Move it somewhere else or
delete it when you are done reading.

## Wanted

**The VPW Example / Basic table.**

This is the cleaner source for the nFozzy / VPW physics routines: it is
published specifically as a starting point for table authors, so its physics
code is meant to be reused, and it carries none of the licensed-IP baggage of
a themed table. It is not available on this machine.

It is normally distributed through VPUniverse, which requires an account, so
it cannot be fetched automatically. If you download it, drop it in
`reference/local/` (gitignored) and note the version here.

Milestone 2 is written so it does not block on this: the physics layer plugs
into a defined seam, and the values needed are already measured and recorded
in [`docs/physics.md`](../docs/physics.md). Having the canonical table would
make the port cleaner and the attribution more precise.
