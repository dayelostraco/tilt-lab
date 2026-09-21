# Drill design

## The training hierarchy

```
CONTROL  ->  TRANSFER  ->  AIM  ->  SCORE
```

Drills are ordered by that hierarchy, not by difficulty of implementation. A
session is successful when the player *intentionally controlled the ball
repeatedly*, not when they survived or scored. Nothing in this table rewards
survival.

## Drill roster

| # | Drill | Trains | Milestone | Status |
|---|---|---|---|---|
| 1 | Drop catch, beginner | Releasing a raised flipper at contact | 4 | planned |
| 2 | Drop catch, variable | The same under realistic variation | 5 | planned |
| 3 | Live catch | Absorbing a moving ball on a rising flipper | 6 | planned |
| 4 | Dead bounce / trust | Recognising when to do nothing | 7 | planned |
| 5 | Post pass | Transferring a cradled ball across | 8 | planned |
| 6 | Cradle separation | Controlling two balls on one flipper | 8 | planned |
| 7 | Backhand / accuracy | Aiming a controlled shot | 9 | planned |
| 8 | Recovery | Handling uncontrolled feeds without reflex-flipping | 9 | planned |
| 9 | Mixed recognition | Choosing the right technique under uncertainty | 10 | planned |

## Drill 1: drop catch, beginner

The first genuinely useful version of this table, and the gate on everything
after it.

**What it trains.** Timing the release of an already-raised flipper so the
ball's energy is absorbed as the flipper drops away beneath it.

**Feed.** Highly consistent. The ball intersects the middle-to-upper region of
the raised flipper at a realistic moderate return speed. The player begins
with the receiving flipper held up and releases at contact.

**Cycle.** Feed, attempt, verdict, short delay, repeat. Ten attempts per set.

**Both sides.** Left-flipper and right-flipper variants are separate drills,
because the two hands do not learn at the same rate and a mixed set hides
that.

**Reported.** Attempt number, success count, accuracy percentage, and a
per-attempt verdict.

## Success detection

Detection is best-effort and reports only what it measured. Every verdict is
logged alongside the raw values that produced it, so thresholds are re-tuned
against real sessions instead of guessed.

### Drop catch

Signals available around the contact moment:

- ball velocity immediately before flipper contact
- ball velocity shortly after the interaction
- ball position relative to the receiving flipper
- whether the ball stayed on the receiving side
- whether speed fell below a control threshold
- whether the ball settled into a defined cradle zone

Candidate verdicts: `PERFECT`, `CONTROLLED`, `PARTIAL`, `MISS`, `DRAIN`.

`EARLY` and `LATE` are deliberately **not** in that list. They are only
reported if flipper-release timing turns out to be genuinely derivable from
the recorded data. A trainer that invents a timing critique teaches the player
to correct an error they did not make.

### Live catch

- significant velocity reduction across the interaction
- ball remains within the receiving-side control zone
- speed drops below threshold within N milliseconds
- no immediate uncontrolled rebound

### Dead bounce

- the player did not activate the relevant flipper
- the ball transferred safely to the opposite side
- the ball avoided the drain
- the ball ended in a controllable region

### Shot accuracy

Simple and objective: a target switch either registered or it did not. Hits
over attempts.

## Feed design constraints

- Repeatability outranks visual realism in the delivery mechanism. An
  invisible kicker that produces an identical feed every time beats a
  beautiful ramp that does not.
- Trajectories must stay **physically plausible**. Randomisation widens within
  bounds that a real machine could produce; it never becomes arbitrary.
- Geometry must resemble a real modern machine closely enough that the skill
  transfers. Unusual geometry that teaches behaviour a physical machine cannot
  produce is worse than no drill.
