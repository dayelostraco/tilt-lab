# Tuning

## Frame rate, and why it no longer affects the numbers

**Reference setup: 90 fps.** It should not matter, and that is now testable.

VPX has two timer clocks, and the difference is the whole story:

| Timer | Fires | Driven by |
|---|---|---|
| `Interval = -1` | once per **rendered frame** | the render loop |
| `Interval > 0` | on **simulation time**, up to 1000 Hz | the physics loop (`PhysicsEngine.cpp` calls `FireTimers(0)` per physics step) |

Everything whose timing is part of a measurement runs on a 1 ms
simulation-time timer, `FeedSampleTimer`. Only visual bookkeeping is left on
the frame timer. This is the same split VPW uses: it drives `FlipperTricks`
from a 1 ms timer and the CoR tracker from a 10 ms one.

### The evidence

The same 20-feed calibration, run at two different render rates:

| | 10 fps capture | 30 fps capture |
|---|---|---|
| mean arrival | 14.9982 | 14.9982 |
| sd | 0.0683 | 0.0683 |
| contact X mean | 495.6886 | 495.6886 |
| contact Y mean | 1818.767 | 1818.767 |

**Identical to every decimal place.** Before the change, when sampling
happened per rendered frame, the same test gave 14.9494 against 14.9738.

This also fixes sample staleness, which is separate from window duration. A
reading taken on the frame timer could be a whole frame old: at 90 fps and
0.81 m/s that is 11.1 ms and about 16 vpu of travel, a third of a ball. At
1 ms it is 1.5 vpu.

### One caveat that is not in our control

`PhysicsEngine.cpp` skips the simulation-time timers when the script is
taking too long in a frame, unless the vsync mode is **Frame Pacing**:

```cpp
if (GetVideoSyncMode() == VideoSyncMode::VSM_FRAME_PACING
    || m_logicProfiler.Get(PROFILE_SCRIPT) <= 1000 * MAX_TIMERS_MSEC_OVERALL)
    FireTimers(0);
```

So **use the Frame Pacing vsync setting**. VPX's own changelog recommends it
for BGFX anyway. On any other setting a heavy frame can silently drop timer
ticks, which would put jitter back into the measurements.

## The loop

```
edit scripts/10-config.vbs   ->   tools/build.sh   ->   load in VPX   ->   read the log   ->   repeat
```

Every value that changes how a feed behaves lives in `scripts/10-config.vbs`.
If tuning a trajectory ever requires editing two files, that is a bug in the
configuration layer, not a fact about the trajectory.

## Units

These are VPX's documented scale, not estimates. Sources:
`docs/PhysicsPM5.txt` and `src/physics/physconst.h` in the vpinball source.

| Quantity | Unit | Conversion |
|---|---|---|
| Length | vpu | **1 vpu = 0.53975 mm** exactly (1 mm = 1.8527 vpu). Playfield 952.94 x 2164.71 vpu = 514 x 1169 mm. Ball 50 vpu = 26.99 mm = 1-1/16 in. |
| Time | VPT | **1 VPT = 10 ms.** The physics engine steps at 1000 Hz, fixed timestep. |
| Velocity | vpu per VPT | **1 vpu = 0.053975 m/s** |
| Gravity | vpu per VPT² | Earth's 9.81 m/s² = 1.81751. This table's 1.7629848 = 0.97 g. |
| Angle | degrees | |

> An earlier version of this table said "roughly 2.12 vpu per real
> millimetre". That was wrong; the correct figure is 1.8527. Speeds and
> distances in the log are now reported in m/s and mm alongside vpu so the
> conversion does not have to be done by hand.

### What the measured numbers mean in the real world

| Measurement | vpu | m/s |
|---|---|---|
| Feed speed at flipper contact | 9.16 | **0.49** |
| Live-catch rebound (missed window) | 54.7 | **2.95** |
| Clean live catch, outgoing | 2.0 | 0.11 |
| Ball resting in a cradle | 0.61 | 0.03 |

### Independent check that the simulation is physically right

A ball released with zero velocity slid 817 vpu (0.441 m) down the 6-degree
playfield and reached 14.66 vpu, which is 0.791 m/s.

A *sliding* frictionless block would reach 0.951 m/s. A **solid sphere
rolling without slipping** reaches √(5/7) = 0.845 of that, which is
0.803 m/s.

Measured 0.791 against a predicted 0.803: **1.5% low**, the remainder being
rolling resistance and the energy spent spinning the ball up.

This is worth more than any single tuned constant. It says gravity, the
slope, the playfield friction and VPX's rolling-ball model together
reproduce textbook rigid-body dynamics, independently of anything copied
from a reference table.

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
