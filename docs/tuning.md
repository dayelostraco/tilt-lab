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

Categories in use today: `boot`, `debug`, `input`, `ball`, `physics`, `feed`,
`calib`, `options`.

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

The order matters. **Repeatability is a measurement; realism is a judgement.**
Establish the measurement first, because a feed that is not repeatable cannot
be judged at all.

### Step 1: prove repeatability (no judgement required)

Press `C`. That fires twenty `DIFF_FIXED` feeds at the right flipper and
prints one line:

```
<ms>,calib,report,n=20,meanInSpeed=..,sd=..,min=..,max=..,spread=..
```

`sd` is the whole test. If the standard deviation of the pre-contact speed is
not small relative to the mean, the delivery mechanism is wrong and no amount
of velocity tuning will fix it. Only the feeder is being measured here, so
this tells you nothing about whether the feed is *realistic*, which is the
point: it isolates one question at a time.

A useful way to read it: if `spread` approaches the difference between a feed
you can catch and one you cannot, the drill is measuring the feeder rather
than the player.

### Step 2: make it realistic (judgement required)

Only once step 1 passes. Press `F` (right) or `G` (left) for single feeds and
read the `precontact` line:

```
<ms>,feed,precontact,seq=..,dist=..,x=..,y=..,vx=..,vy=..,speed=..,flipperAngle=..,flightMs=..
```

Adjust `LaunchX/Y` and `VelX/VelY` in the profile until the ball arrives in
the middle-to-upper region of the raised flipper at a speed that looks like a
real return. The `postcontact` line reports `retained`, the fraction of speed
the ball kept through the interaction, which is the number a drop-catch
verdict will eventually be built on.

**The shipped values are geometrically derived, not measured.** They put the
ball on a line that reaches the 60% point of the raised flipper, and they
have never been observed in VPX.

### Step 3: widen the difficulty bands

One level at a time, re-checking that the extremes are still trajectories a
real machine could produce. Jitter is applied to speed and angle rather than
to the velocity components, so a jittered feed stays in the same trajectory
family instead of drifting somewhere the profile never intended.

## What cannot be tuned from macOS

All of it. The build, the static checks and the JSON edits are reproducible
anywhere, but every physics value has to be judged by playing the table in
VPX on Windows. Treat macOS work as producing a candidate, never a result.
