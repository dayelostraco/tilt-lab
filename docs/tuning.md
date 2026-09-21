# Tuning

## The loop

```
edit scripts/10-config.vbs   ->   tools/build.sh   ->   load in VPX   ->   read the log   ->   repeat
```

Every value that changes how a feed behaves lives in `scripts/10-config.vbs`.
If tuning a trajectory ever requires editing two files, that is a bug in the
configuration layer, not a fact about the trajectory.

## Units

| Quantity | Unit | Feel for the scale |
|---|---|---|
| Position | VPX units (vpu) | Playfield is 952.94 wide by 2164.71 tall. A 1-1/16" ball is 50 vpu across, so roughly 2.12 vpu per real millimetre. |
| Velocity | vpu per physics tick | Hard slingshot kick ~40 to 50. Lazy inlane return ~8 to 15. |
| Time | milliseconds | |
| Angle | degrees | |

Playfield slope is pinned at 6.5 degrees (see [physics.md](physics.md)).
Every feed velocity is calibrated against that slope, so changing it
invalidates the whole feed table.

## Reading the log

`DebugLog` emits CSV-shaped lines into a ring buffer:

```
<ms since load>,<category>,<message...>
```

Categories in use today: `boot`, `debug`, `input`, `ball`.

`DebugLogBall` records a full ball snapshot:

```
<ms>,ball,<tag>,x=..,y=..,z=..,vx=..,vy=..,vz=..,speed=..
```

`speed` is planar (x and y only), which is the number that matters for a
catch; `vz` is kept separately because a ball that is airborne at contact is a
different event from one rolling into the flipper.

Press `D` in desktop mode to see the tail of the buffer on the score text. In
VR the buffer is collected but not yet rendered.

## Intended log schema

The drill layer will extend the same buffer to the full training record:

```
timestamp,drill,side,difficulty,attempt,vx,vy,incoming_speed,outgoing_speed,outcome
```

This is CSV from the first line written, specifically so that longitudinal
analysis later needs an export step and not a reformat. `DebugLog` is the
single sink, so swapping the in-memory buffer for real file output is a
one-function change.

## Calibrating a feed

1. Set the drill to `DIFF_FIXED` so nothing is randomised.
2. Turn debug on.
3. Run a set and read the `ball` snapshots at the pre-contact tag. Consistency
   comes first: if the same launch parameters do not produce the same
   pre-contact numbers, the delivery mechanism is wrong and no amount of
   velocity tuning will fix it.
4. Only once the feed is repeatable, adjust launch velocity and position until
   the pre-contact numbers match what a real return looks like.
5. Widen the randomisation bounds one difficulty level at a time, re-checking
   that the extremes are still trajectories a real machine could produce.

## What cannot be tuned from macOS

All of it. The build, the static checks and the JSON edits are reproducible
anywhere, but every physics value has to be judged by playing the table in
VPX on Windows. Treat macOS work as producing a candidate, never a result.
