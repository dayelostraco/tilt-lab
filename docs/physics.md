# Physics

## Status

**Implemented, not yet validated by play.** The current VPW/nFozzy stack is
ported in and the table loads clean on VPX 10.8.1.5436 with no script error
and no audit warning. Nothing here has been judged by hitting a ball with it.
The validation drills at the end of this document are the gate.

## Why this layer gets disproportionate care

On a themed table, flipper physics being slightly off costs some realism. On a
trainer it invalidates the product: if the flipper does not return the ball
the way a real one does, the player drills a timing that does not exist, and
the practice transfers negatively.

So the rule is: **do not invent a physics model, and do not tune it to make a
drill easier.** If a real technique is hard, the trainer should be hard. The
target is plausible real-machine behaviour, not pleasant arcade behaviour.

## 0. Sources

Three different kinds of authority are used here, and it matters which is
which.

### Published documentation, shipped with VPX 10.8.1

Found in the vpinball source tree under `docs/`:

| Document | What it gives |
|---|---|
| `PhysicsPM5.txt` | The VP10 engine's own reference: parameter definitions, **1 vpu = 0.53975 mm**, 1 VPT = 10 ms, ball mass 80 g, 1000 Hz fixed timestep, gravity 1.0 = true Earth |
| `PhysicValues.txt` | Per-element recommended values (older; superseded in places) |
| `JP's VPX Physics 2026.pdf` + two `.vpp` presets | A current, shipped physics preset for EM and solid-state eras |
| `Nudge Test and Calibration.vpx` | A calibration table |

### Community reference implementation

The nFozzy/VPW stack, taken from a real VPW release. This is **empirical
community work**, not a specification: the polarity and velocity tables were
data-mined by nFozzy, and the reference's own comment on the rubber curves
says "don't take this as gospel".

### First-principles cross-check

One measurement stands outside both: a ball sliding down the playfield
reproduces textbook rolling-sphere dynamics to 1.5% (see
[tuning.md](tuning.md)). That validates gravity, slope and the rolling model
without reference to anyone's table.

### How this table's values compare to the published ones

| Property | `PhysicValues.txt` | JP's 2026 SS preset | **Tilt Lab** |
|---|---|---|---|
| Gravity constant | 0.97 to 1.0 | 0.9 | **0.97** |
| Playfield friction | 0.075+ | 0.25 | **0.24** |
| Playfield elasticity | 0.25 | 0.25 | **0.25** |
| Slope | n/a | 6 / 6 | **6 / 6** |
| Flipper mass | 1.0 | n/a | **1.0** |
| Flipper strength | 2200-2800 (modern) | 3600 | **3200** |
| Flipper elasticity | 0.8 | 0.8 | **0.88** |
| Elasticity falloff | 0.43 | 0.1 | **0.15** |
| Flipper friction | 0.5 to 0.6 | 0.9 | **0.9** |
| Return strength | 0.058 | 0.04 | **0.055** |
| Coil ramp up | 2.4 to 3.5 | 0 | **2.5** |

Every value sits inside the envelope spanned by the two published
references, and several match one of them exactly. Where `PhysicValues.txt`
and JP's 2026 preset disagree (friction 0.075 vs 0.25, strength 2200-2800 vs
3600), this table follows the newer preset, which is also what the VPW
tables do.

**The one number to treat with suspicion is flipper `elasticity` 0.88**,
which is above both published figures of 0.8. It comes from the VPW
reference and is paired with their `elasticity_falloff` of 0.15 and the
`FlippersD` dampener curve, so it should not be changed in isolation.

## 1. Reference implementation used

**Lord of the Rings (Stern 2003), VPW "Yahoo! Edition"**, read from the local
install at `D:\Visual Pinball\Tables`.

Chosen after surveying every VPW-era table available locally:

| Table | `FlipperPolarity` | polarity pts | `CheckLiveCatch` | dampeners | `FlipperCradleCollision` |
|---|---|---|---|---|---|
| **Lord of the Rings (Stern 2003)** | 6 | 18 | 5 | 33 | **4** |
| The Addams Family (Bally 1992) | 6 | 17 | 5 | 31 | 3 |
| Medieval Madness (Williams 1997) | 6 | 18 | 4 | 28 | 3 |
| Cirqus Voltaire (Bally 1997) | 6 | 18 | 3 | 29 | 2 |
| Tron Legacy (Stern 2011) | 3 | 15 | 3 | 17 | **0** |
| Star Trek LE (Stern 2013) | **0** | **0** | **0** | 3 | **0** |

Two results worth stating plainly:

- **Star Trek LE (Stern 2013) has no nFozzy physics at all.** It is the most
  modern Stern in the collection and it is useless as a physics reference.
- **Tron Legacy (Stern 2011) carries an older, partial VPW mod**: no cradle
  collision, and `EOSTnew = 0.8`, the value rothbauerw has since superseded.

LOTR won on being both a Stern and the most complete and most current stack.
Its `FlipperPolarity` class is marked *"modified 2023 by nFozzy"* and
*"modified 2024 by rothbauerw"*, the newest revision markers found anywhere
locally.

**The VPW Example / Basic table is still not available** and would be the
better source, being published expressly for reuse. See
[`reference/README.md`](../reference/README.md). It is not blocking: LOTR
carries the same stack.

## 2. nFozzy implementation

The `FlipperPolarity` class as revised by nFozzy (2023) and rothbauerw (2024),
comprising:

- **Polarity correction**: a positional nudge that varies with where along the
  flipper the ball made contact (18 interpolation points).
- **Velocity correction**: a speed multiplier over the same axis (11 points).
- **Ycoef**: fades the correction out with distance from the flipper.
- **ReProcessBalls** (rothbauerw, 2024): handles flipper collisions and
  removes the correction for backhands taken with the flipper already raised.

The tables are byte-identical between LOTR and Medieval Madness, which is
what makes them safe to reuse: they describe VPW's standard flipper, not a
particular playfield.

## 3. Global Physics: the thing that must never be switched on

**This table must never use a VPX Global Physics Set.**

A global set overrides the per-part values that nFozzy's corrections are
calibrated against. The failure is silent and total: the polarity and velocity
tables stay in place but no longer describe the flipper they are correcting,
so every number in this document becomes fiction while remaining visible.

Every VPW reference inspected agrees, and this table matches:

| | table `override_physics` | `override_physics_flipper` | flipper `override_physics` |
|---|---|---|---|
| LOTR / MM / Tron | 0 | false | 0 |
| **Tilt Lab** | **0** | **false** | **0** |

`AssertNoGlobalPhysics` in `scripts/12-physics-config.vbs` runs at table init,
logs the result, and raises a message box if any of the three is ever
non-zero. It is deliberately loud: this is not a failure worth discovering
three drills later.

## 4. Why Modern Stern

The trainer targets one profile for now: strong modern flippers, modern
incline, relatively fast playfield, realistic catch and transfer difficulty.
That is the machine most players will next stand in front of.

This is a **generalised** modern-machine profile. It does not reproduce any
specific Stern title, and no claim is made that it does. LOTR is a 2003
Whitestar, not a Spike machine; it is the closest thing to a modern Stern with
a current VPW stack that was available.

## 5-9. The values

### Ball

| | Value | Source |
|---|---|---|
| Ball mass | **1.0** | VPW standard |
| Ball radius | 25 vpu (50 diameter) | |

Ball mass is fixed at 1.0 and is not a tuning knob. The flipper stack is
calibrated around it, so changing it to alter perceived speed would invalidate
every polarity and velocity point at once. If the game feels too fast, slow,
strong or bouncy, the responsible parameter is flipper strength, elasticity
falloff, coil ramp-up or playfield friction. Diagnose, do not shortcut.

### Table

| Property | Was (blank table) | Now | Source |
|---|---|---|---|
| `gravity` | 1.7629848 | 1.7629848 | unchanged, identical across all VPW refs |
| `friction` | 0.075 | **0.24** | LOTR. MM 0.22, Tron 0.20 |
| `elasticity` | 0.25 | 0.25 | unchanged |
| `default_scatter` | 0.0 | **2.0** | all VPW refs |
| `angle_tilt_min` / `max` | 5.0 / 10.0 | **6.0 / 6.0** | LOTR |
| `override_physics` | 0 | 0 | unchanged |

Playfield friction at 0.075 was near-frictionless and made a dead bounce
behave nothing like a real machine. Slope is pinned equal at both ends so the
incline cannot drift with a setting: every feed velocity the trainer will use
is calibrated against that one number.

### Flippers

Both flippers, adopted wholesale from LOTR:

| Property | Was | Now |
|---|---|---|
| `flipper_radius_max` | 117.65 | **114.0** |
| `base_radius` | 20.58875 | **20.75** |
| `end_radius` | 11.765 | **11.5** |
| `start_angle` | ±120.5 | **±121.0** |
| `end_angle` | ±70.0 | ±70.0 |
| `mass` | 0.7 | **1.0** |
| `strength` | 2600 | **3200** |
| `elasticity` | 0.8 | **0.88** |
| `elasticity_falloff` | 0.001 | **0.15** |
| `friction` | 0.8 | **0.9** |
| `return` | 0.05 | **0.055** |
| `ramp_up` | 0.0 | **2.5** |
| `torque_damping` (EOS torque) | 0.25 | **0.275** |
| `torque_damping_angle` | 6.0 | 6.0 |

`elasticity_falloff` is the single most consequential change. At 0.001 the
flipper returned nearly all the energy of a fast ball, which is precisely what
makes a live catch feel impossible. `ramp_up` 2.5 gives the coil a spin-up
curve instead of instant full strength, which is the difference between a tap
and a full flip.

**Flipper positions were deliberately not adopted.** The slingshots, inlanes
and drain in this table are built around the existing flipper centres, and
moving the flippers without moving all of that would break the lower
playfield. The centres differ from LOTR's by under 5 vpu, so the correction
tables still apply.

### Script-level flipper constants

These live in `scripts/40-physics-nfozzy.vbs`, where VPW put them, next to the
comments that explain them:

```
Const FlipperCoilRampupMode = 0   '0 fast, 1 medium, 2 slow (tap passes work)
Const EOSTnew   = 1.2             '90's and later, per rothbauerw (was 0.8)
Const EOSAnew   = 1
Const EOSRampup = 0
Const EOSReturn = 0.025           'mid 90's and later
Const SOSEM     = 0.815
SOSRampup = 2.5                   'from FlipperCoilRampupMode 0
```

> **The brief's suggested starting values were checked against the reference
> and two of them are wrong.** "EOS Torque 0.375" is Medieval Madness'
> `torque_damping`, not an EOS constant, and the Stern reference uses 0.275.
> "EOS Torque Angle / Return 0.4" matches nothing in the stack; the nearest
> real values are `torque_damping_angle` 6.0, `EOSReturn` 0.025, and
> `FCCDamping` 0.4 (which is cradle-collision damping, not flipper return).
> The reference wins, per the brief's own instruction.
>
> The live-catch and ramp-up figures in the brief were **correct** and match
> the reference verbatim.

### 10. Live catch

Straight from the reference, unchanged:

```
Const LiveCatch        = 16     'flipper angle window
Const LiveElasticity   = 0.45
Const LiveDistanceMin  = 5      'vpu from flipper base
Const LiveDistanceMax  = 114    'tip protection
Const BaseDampen       = 0.55
```

`CheckLiveCatch` runs from `LeftFlipper_Collide` / `RightFlipper_Collide`. The
damping scales with where on the flipper contact happened and how the timing
landed, so good timing gives a controlled catch, imperfect timing gives
partial energy reduction, and poor timing rebounds. There is no branch that
forces a catch to succeed.

### 11. Cradle collision

`FlipperCradleCollision` with `FCCDamping = 0.4`, called from
`OnBallBallCollision`. It filters out collisions under 0.7 velocity, then
damps both balls only when one of them is sitting on a held flipper. This is
what keeps two cradled balls from behaving like billiard balls, and it matters
for the cradle-separation drill.

### Rubber and posts

VPW's `Dampener` class with the data-mined bounce curves, unchanged:

```
RubbersD: (0, 1.1) (3.77, 0.97) (5.76, 0.967) (15.84, 0.874) (56, 0.64)
SleevesD: RubbersD scaled to 0.85
FlippersD: (0, 1.1) (3.77, 0.99) (6, 0.99)
```

Driven by a `CoRTracker` on a 10 ms timer, because computing a coefficient of
restitution needs the ball's speed from the frame *before* impact.

`TargetBouncer` is enabled with factor 0.9.

Collections wired: `dPosts` (Pin3, Pin4), `zCol_Rubber_LSling` (LSling),
`zCol_Rubber_RSling` (RSling). **`dSleeves` is empty**: this table has no
sleeve rubbers modelled yet. It gets populated when the lower playfield is
built out properly.

## Frame pacing

VPX's audit originally warned:

> Part 'RollingTimer' uses a timer with a very short period of 10ms, below a
> 60FPS framerate. This will likely cause stutters and the table will not
> support 'frame pacing'.

That matters more here than on a normal table: a drop catch is a timing
judgement measured in a handful of frames, and at 90 Hz in VR an 11.1 ms frame
never lines up with a 10 ms tick.

Fixed by moving `RollingTimer` to `Interval = -1`, which means *once per
rendered frame*. This is the modern VPW pattern (Medieval Madness drives its
`FrameTimer` the same way). The interval is set both in the table data and in
script, because VPX's audit reads the stored value. **The audit is now clean.**

`CorTimer` stays at 10 ms deliberately: the CoR calculation needs a fixed
sample rate, and VPW's own comment says so.

## 12. Configuration and future profiles

`scripts/12-physics-config.vbs` is the single place a profile is selected:

```
Const PhysicsProfile = PHYS_MODERN_STERN
```

`PHYS_WPC`, `PHYS_SYSTEM_11` and `PHYS_CUSTOM` are reserved and deliberately
not implemented.

The config layer **does not copy** VPW's constants out of the physics modules.
Duplicating them would let the two drift, and VPW's originals sit next to the
comments that justify them. What the layer owns is the *selection*: which era
VPW should behave as, plus the genuinely table-level values, and an assertion
that the running table matches what the profile expects. VPW is already
parameterised by era through `FlipperCoilRampupMode`, `EOSTnew` and
`EOSReturn`; a future profile switches those rather than replacing the stack.

## 13. Debugging and tuning

`AssertPhysicsProfile` logs the full physics state at init: profile, slope,
friction, gravity, flipper strength/mass/elasticity/falloff/friction, EOS rest
and `EOSTnew`/`EOSReturn`, ramp-up and mode, all five live-catch constants,
cradle damping, and target bouncer settings. Every value is reported as
*expected vs actual read from the running table*, so a mismatch shows up in
the log rather than in the feel.

`PhysicsSignature()` returns a one-line summary that goes into the drill log
header, so a training session can always be traced back to the physics it was
recorded under.

`DebugLogBall` records position, all three velocity components and planar
speed. `TBPout` is present as VPW's dampener debug readout; set
`RubbersD.debugOn = True` to use it.

Press `D` for the overlay. See [tuning.md](tuning.md).

## 14. What is approximate rather than measured

Being explicit, because the temptation to over-claim here is real:

- **The profile is generalised.** It is not a measured reproduction of any
  specific machine. It is LOTR's VPW calibration, which is itself a community
  approximation of a Stern Whitestar.
- **Playfield friction 0.24 is inherited, not measured.** It is one table
  author's number, within the plausible 0.15 to 0.25 band.
- **The polarity and velocity tables are data-mined by nFozzy**, not derived
  from first principles, and are tuned for VPW's standard flipper.
- **Rubber CoR curves are data-mined** and the reference's own comment says
  "don't take this as gospel".
- **Flipper positions are this table's, not LOTR's**, differing by under
  5 vpu. The correction tables assume VPW-standard geometry; the dimensions
  and angles now match exactly, the absolute position does not.
- **`dSleeves` is empty**, so sleeve damping is currently inactive.
- **Nothing has been validated by play.** See below.

## Validation drills: automated results, 2026-09-21

The brief allows these to be validated "manually or programmatically". They
were run programmatically: `scripts/65-validation.vbs` actuates the flippers
at an exact frame relative to launch, over a repeatable feed, and reports the
energy the ball retained. Run with `tools/attract.ps1 valid-drop|valid-live|
valid-cradle|valid-dead|valid-speed`.

### The headline: timing discriminates properly

Drop-catch sweep, releasing the raised flipper at 17 different frames either
side of contact:

| release vs contact | speed retained |
|---|---|
| -24 to -12 frames (flipper fully down by contact) | 0.29 to 0.36 |
| -10 to -2 frames (flipper mid-fall) | 0.47 to 0.78 |
| 0 frames | 0.98 |
| +2 to +8 frames (flipper still up) | 0.46 |

**Discrimination: 0.6945.** Best timing kills 71% of the ball's energy, worst
kills almost none. That is the answer to the question the brief actually
cares about: the outcome depends strongly on timing, and nothing in the stack
is forcing an attempt to succeed.

For contrast, the first version of this sweep reported a discrimination of
**0.0048**, a perfectly flat line. That was not the physics. It was three
separate measurement faults, each of which would have been invisible to a
human playtester forming an impression:

1. **The flippers were not moving at all.** VPW's `FlipperActivate` only sets
   physics parameters; on a ROM table PinMAME's solenoid does the rotating.
   This table has no ROM, so nothing called `RotateToEnd`, from the keyboard
   or anywhere else. Fixed by `FlipperUp` / `FlipperDown`.
2. **The sweep was centred on the wrong frame.** Contact happens at frame 42
   with the flipper down but frame 34 with it raised, because a raised
   flipper reaches out and intercepts the ball earlier. Centred on 43, every
   release in the sweep landed after contact had already happened.
3. **The measurement was taken at the wrong moment.** Sampling 3 frames after
   contact measures the rebound, not the outcome. Sampling at 45 frames
   measures whether the ball ended up under control, which is what a catch
   actually means.

### Feed speed, derived rather than chosen

The original feed arrived at the flipper at 0.49 m/s. Grounding that against
VPX's documented scale showed it was too slow: it is what a ball that entered
the inlane essentially at rest would do.

A ball rolling from rest down this 6-degree playfield arrives at the flipper
at (validated rolling model, see [tuning.md](tuning.md)):

| Released from | arrival |
|---|---|
| inlane entrance | 0.42 m/s (7.7 vpu) |
| slingshot top | 0.50 m/s (9.3 vpu) |
| lower playfield | 0.68 m/s (12.7 vpu) |
| mid playfield | 0.79 m/s (14.6 vpu) |
| upper playfield | 0.97 m/s (18.0 vpu) |
| full table length | 1.12 m/s (20.8 vpu) |

For the fast end: the slingshots on the VPW reference tables are set to
forces of 42 (LOTR), 45 (Addams), 51 (Medieval Madness) and 66 (Tron), and
`LineSegSlingshot::Collide` applies at most half of that as velocity, so a
sling kick alone adds **1.1 to 1.8 m/s**.

A launch-speed sweep measured the actual relationship on this table over 16
points:

```
arrival(vpu) = 0.744 x launch(vpu) + 1.086
```

The ball loses about a quarter of its launch speed to the inlane wall on the
way down. Solving for 0.80 m/s at contact, roughly a mid-playfield return,
gives a launch of 21 vpu.

**Measured after the change: 0.808 m/s, 20 of 20 feeds, sd 0.42%.** The
target was 0.80.

The contact point spreads more at the higher speed (sd 9.3 vpu against 5.2
before, total spread 31 vpu, about 0.6 of a ball). That is expected: more
energy gives VPW's `default_scatter` more to work with. It is a cost of
realism, not a defect.

Both timing sweeps discriminate far better on the realistic feed:

| Sweep | at 0.49 m/s | at 0.808 m/s |
|---|---|---|
| Drop catch | 0.69 | **1.44** |
| Live catch | 3.62* | **1.91** |

\* the earlier live-catch figure was inflated by a full flip shot at one end
of the sweep; the current sweep window is narrower.

### Live catch: a narrow window with a dramatic penalty

Flipper down, raised into the ball at 17 different frames. This is the most
informative result in the project so far:

| flip vs contact | rebound speed | retained | what happened |
|---|---|---|---|
| -24 to -16 frames | 7.4 to 7.9 | 0.46 | Flipped far too early, flipper already back down; plain bounce |
| **-14 frames** | 7.4 | **0.354** | Partial catch |
| **-12 frames** | 7.5 | **0.233** | **Clean live catch.** Ball killed to speed 2.0, stays at the flipper |
| -10 frames | 19.5 | 1.11 | Missed the window; ball launched |
| -8 to -4 | 33 to 54 | 2.26 to 3.85 | Full flip shot, ball fired up the table |
| -2 to +8 | 9 to 55 | 1.42 to 3.53 | Late flip, still a shot |

**Discrimination: 3.6166.**

Two frames separate a clean catch from firing the ball up the playfield at
55 vpu. The window is narrow, missing it is spectacular, and there is no
sign of a "magnetic" catch anywhere in the range. That is exactly the
behaviour the brief asks for: *good timing produces a controlled catch,
imperfect timing produces partial energy reduction, poor timing produces a
rebound*, and nothing makes every attempt succeed.

It is also the clearest evidence that the nFozzy stack is live and working.
A stock VPX flipper would not produce this shape.

> The frame counts here are rendered-frame ticks under `-CaptureAttract`,
> which does not run at wall-clock rate. Do not convert them to milliseconds
> without re-measuring at a known frame rate.

### Cradle

With a slow feed starting close to the flipper:

| | Value |
|---|---|
| resting speed | 0.605 to 0.740 |
| distance from flipper base | 81.1 to 82.3 vpu |
| energy killed | 77% to 81% |
| spread across 5 runs | 1.2 vpu |

**The ball settles on the raised flipper and stays there.** The cradle works.

### Dead bounce

Flipper down, inlane feed: retained 0.332 to 0.339 across five runs, spread
0.0078. Very consistent, and the ball leaves toward the opposite side rather
than draining.

### A wrong conclusion, corrected

An earlier version of this document claimed the lower playfield geometry was
missing the inlane guides needed to form a cradle, and that geometry rather
than physics was the next blocker. **That was wrong**, and it is worth
recording why, because the mistake is an easy one to repeat.

The cradle test fed the ball from the top of the inlane. A ball launched
there arrives at the flipper doing 6.3 vpu/frame *even when launched at 3.0*,
because a 6-degree slope has 200 vpu of runway to work with. At that speed it
bounces off a raised flipper and travels back up the playfield, and the
telltale was in the data all along: the rebound sample reads `vy=-7.148`,
negative, meaning the ball is heading **up** the table, not failing to settle.

That is correct physics. You cannot cradle a fast inlane ball by holding the
flipper up; a real machine does the same thing. The feed-speed sweep looked
like it ruled speed out only because the slowest launch available still
arrived fast.

The fix was to the *test*, not the table: a cradle feed that starts close to
the flipper with almost no initial velocity. It cradles immediately. There is
a dedicated `Cradle.Right` / `Cradle.Left` profile for this, kept separate
from the inlane feed precisely so the two questions stay separate.

The lesson for the rest of this project: when a drill will not work, check
what the feed is actually delivering at the moment of contact before
concluding anything about the table.

### Still requiring a human

- Whether a pre-contact speed of ~9.16 vpu/frame *feels* like a realistic
  return. Repeatability is settled; realism is a judgement.
- Post pass and multiball cradle collision, which need the cradle to work
  first.
- Everything in VR: scale, depth perception, comfort.

## Validation drills: the manual procedure

None of these can be run from macOS. Each states what to do and what would
count as a failure.

| # | Drill | Do | Pass | Fail |
|---|---|---|---|---|
| 1 | **Cradle** | Let a slow ball roll onto a held flipper | Settles and stays still | Vibrates, creeps, accelerates, or sticks unnaturally |
| 2 | **Live catch** | Flip into an incoming ball with good timing, then repeat deliberately early and late | Good timing kills most energy; mistimed is partial; badly timed rebounds | Every attempt succeeds (assistance leaking in), or none can |
| 3 | **Drop catch** | Hold the flipper up, release as the ball lands | Well-timed absorbs most energy | Ball snaps to the flipper, or timing seems not to matter |
| 4 | **Dead bounce** | Let a ball from the opposite inlane hit a lowered flipper | Bounces across plausibly; outcome varies with speed, angle and contact point | Always drains, or always bounces regardless of input |
| 5 | **Post pass** | Cradle, then tap to transfer across | Possible with real timing, not trivial | Impossible, or works every time |
| 6 | **Slingshot recovery** | Drive a ball into a sling | Lively and a bit unpredictable | Violent and arcade-like, or dead |
| 7 | **Cradle collision** | With two balls, roll one into a cradled one | Plausible, damped | Billiard-ball energy |

Log what actually happens with debug on. Adjustments must be justified against
the reference or against observed data, never against "this drill feels hard".
