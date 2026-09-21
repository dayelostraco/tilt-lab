# Player guide

This is for using Tilt Lab. If you want to change it, see
[developer-guide.md](developer-guide.md).

## What this is, and what it is not

Tilt Lab is a practice facility, not a pinball game. There is no score, no
theme and nothing to beat. It exists to put the same ball in the same place
over and over so you can work on one technique at a time, and to tell you
objectively whether you controlled it.

It is built to be **as hard as a real machine**. If a technique is difficult
on a physical table it is difficult here, deliberately. Nothing is tuned to
make a drill feel good, and nothing quietly helps an attempt succeed. A
trainer that flattered you would teach you a timing that fails the moment you
stand in front of a real game.

The skills are ordered:

```
CONTROL  ->  TRANSFER  ->  AIM  ->  SCORE
```

A good session is one where you deliberately controlled the ball many times.
Not one where you survived.

## What you need

- **Visual Pinball X 10.8.1 BGFX 64-bit**, Windows
- **Set vsync to "Frame Pacing"** in VPX's video settings. On other settings
  a heavy frame can cause VPX to skip script timer ticks, which is what the
  trainer measures your timing with. Any frame rate is fine; 90 fps is the
  reference.
- For VR: any headset VPX supports. Developed against Quest 3 over Virtual
  Desktop with OpenXR.
- Desktop mode works too.

**No ROM. No PinMAME. No PUP pack. No media pack.** Nothing to download
beyond the table itself.

## Installing

1. Copy `Pinball Training Lab.vpx` into your VPX `Tables` folder.
2. Check there is **no** `Pinball Training Lab.vbs` file sitting next to it.
   If there is, delete it. Visual Pinball loads that file *instead of* the
   table's own script, and you will be playing a stale version without any
   warning.
3. Open the table in VPX and press **F6** to play.

That is the whole installation.

## Controls

Flippers, plunger, nudge and tilt are **exactly the standard VPX controls**.
Nothing is remapped. Retraining those would be the opposite of the point.

### Choosing what to train (VR)

Press **X on the left Touch controller** to open VPX's in-game menu, then go
to **Table Options**.

| Control | Does |
|---|---|
| Left stick up / down | Move between settings |
| Right stick left / right | Change the highlighted setting |
| Left **X** again | Close the menu |

> Careful: **left Y exits the game**, and it sits right next to the menu
> button.

On desktop the same menu is on **F12**.

### Settings

| Setting | Choices |
|---|---|
| Drill | Which technique to practise |
| Side | Left, Right or Alternating |
| Difficulty | Fixed, Beginner, Intermediate, Advanced |
| Attempts Per Set | 5 to 50 |
| Reset Delay | How long between attempts, 0.4 to 3.0 seconds |
| Debug Overlay | Off / On |

Your choices are remembered between sessions.

### Running a set

| Key | Does |
|---|---|
| `1` | Start a set |
| `R` | Restart the current set from attempt 1 |
| `D` | Toggle the debug readout |

## Reading the display

Four lines sit on the apron, below the flippers:

```
DROP CATCH - RIGHT
Intermediate
Attempt 7 / 10    Success 5    71%
CONTROLLED
```

The bottom line is the verdict for the attempt you just made.

| Verdict | What happened |
|---|---|
| **PERFECT** | The ball came to rest on the flipper. A real cradle. |
| **CONTROLLED** | Slow and still at the flipper. Not a dead cradle, but you owned it. |
| **PARTIAL** | You took real energy out of the ball but did not keep it. |
| **MISS** | The ball carried on much as it arrived. |
| **SHOT** | You hit it rather than caught it. The ball left faster than it came in. |
| **DRAIN** | It went down. |

**PERFECT** and **CONTROLLED** count as success; the percentage is those two
over attempts.

`SHOT` is worth dwelling on. It is not a bad outcome in pinball, but in a
catching drill it means you flipped instead of caught, which is a different
error from being late. The trainer separates them because you should too.

There is deliberately **no EARLY or LATE verdict.** The trainer measures what
the ball did, not what you meant to do, and it cannot presently tell a
too-early release from a too-late one. Rather than guess and have you correct
an error you did not make, it says nothing.

## Difficulty

| Level | What varies |
|---|---|
| **Fixed** | Nothing. Every feed identical. Start here. |
| Beginner | Slight variation in speed, angle and contact point |
| Intermediate | Moderate |
| Advanced | Wide, but always trajectories a real machine could produce |

Variation is applied to the ball's **speed and angle**, never to raw
direction, so a harder feed is still the same kind of shot rather than
something arbitrary.

Work at **Fixed** until you can repeat a technique before adding variation.
The point of Fixed is that any inconsistency you see is yours.

## The drills

Three work today. The menu lists the full planned roster; picking an
unimplemented one falls back to the drop catch and says so in the log.

### Drop catch

Hold the receiving flipper **up** before the ball arrives, then **release**
it as the ball makes contact so the flipper drops away underneath.

The ball is fed down the inlane and reaches the flipper at about 0.8 m/s,
which is what a ball returning from mid-playfield does on a real machine.

### Live catch

Flipper **down**. Raise it into the arriving ball at exactly the right
moment to absorb the impact.

This one is genuinely unforgiving, and the measurements show why: **about two
frames separate a clean catch from launching the ball up the playfield at
nearly 3 m/s.** That is not a flaw in the trainer. That is what a live catch
is.

### Cradle

Hold the flipper up and let a slow ball settle onto it. The gentlest of the
three, and the right place to start if catches are not working yet.

## If something looks wrong

**The ball does not move.** VPX pauses the physics engine whenever the
playfield window loses focus. Click the table window.

**Nothing happens when I press 1.** Make sure the table window has focus and
that you are pressing the number row, not the numpad.

**The menu will not open in VR.** Your VPX input profile may not be on the
OpenXR defaults. Check Input Settings in the in-game UI for what left X is
bound to.

**Every attempt says MISS.** Check the drill matches what you are doing: the
cradle drill needs the flipper held up, the live catch needs it down.

**It feels too hard.** That is the intended design and it will not be
softened. Drop to the Cradle drill at Fixed difficulty and build up.
