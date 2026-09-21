# Architecture

## What this table is

A skills laboratory. It exists to deliver the *same ball* to the *same place*
at the *same speed*, over and over, and to say something objective about what
the player did with it. Everything in the design serves repeatability and
measurement. Nothing serves scoring, theme or rules.

## Layers

```
  ┌──────────────────────────────────────────────────────────┐
  │  options         VR-navigable drill selector             │   15-options
  ├──────────────────────────────────────────────────────────┤
  │  drills          which feed, how many attempts, verdicts │   80-drills
  ├──────────────────────────────────────────────────────────┤
  │  scoring         did the player control the ball?        │   70-scoring
  ├──────────────────────────────────────────────────────────┤
  │  feeder          put a ball HERE moving THIS fast        │   60-feeder
  ├──────────────────────────────────────────────────────────┤
  │  physics         nFozzy / VPW flipper behaviour          │   40-,45-
  ├──────────────────────────────────────────────────────────┤
  │  table core      input, trough, slings, sound, shadows   │   20-,30-,50-
  └──────────────────────────────────────────────────────────┘
       config (10-)  and  debug/logging (95-)  cut across all of it
```

Each layer only calls downward. A drill asks the feeder for a feed and asks
scoring for a verdict; the feeder knows nothing about drills; physics knows
nothing about either.

## Why the script is modular

VPX holds one script per table, so the modules in `scripts/` are concatenated
into it at build time (see [vpx-workflow.md](vpx-workflow.md)). The numeric
prefixes are the concatenation order. VBScript hoists global `Dim`, `Const`,
`Sub`, `Function` and `Class` declarations across the whole script, so a
module may freely call into one assembled after it. `99-boot.vbs` is last
purely so that the startup sequence reads in one place.

The cost of this model is that two modules declaring the same global name is a
silent, load-time-only failure. `tools/check.py` exists to catch exactly that
before the file ever reaches Windows.

## Configuration

`scripts/10-config.vbs` holds every value that changes how a drill feels:
launch positions, velocities, randomisation bounds, attempt counts, reset
delays, detection thresholds. Drill code reads them and never substitutes its
own literal. Tuning a trajectory is meant to be a one-file edit followed by
`tools/build.sh`.

## Measurement

There is no console in VPX and no dependable file handle, so `DebugLog` writes
CSV-shaped lines into an in-memory ring buffer:

```
<ms since load>,<category>,<message...>
```

Every diagnostic goes through that one function. The buffer is what the debug
overlay renders today and what a CSV export drains later, so upgrading the
sink never means touching call sites. Ball snapshots go through
`DebugLogBall`, which records position, all three velocity components and
planar speed, because tuning a feed against recorded numbers beats tuning it
against impressions.

## Detection honesty

Success detection is best-effort and is designed to say so. Verdict categories
are only reported when they rest on a value the script actually measured. In
particular, EARLY and LATE are not reported unless timing is genuinely
derivable from the data, because a trainer that invents a timing critique
teaches the player to correct something that never happened. Raw values are
logged alongside every verdict so thresholds can be re-tuned against real
sessions rather than guessed.

## VR

The table inherits the blank table's VR cabinet, backbox, legs, plunger and
room geometry at correct physical scale. Correct scale and depth perception
matter more here than decoration: a drop catch is a depth-and-timing judgement,
and a mis-scaled cabinet trains the wrong one.

Anything flat and screen-space, such as the desktop score text, is hidden in
VR rather than left floating in front of the playfield.

VPX exposes no VR controller state to VBScript and has no ray-cast picking, so
a table cannot build a pointer-driven menu. The drill selector therefore rides
on `Table1.Option` and VPX's own in-game UI, which is the only menu reachable
in a headset. `scripts/15-options.vbs` documents the registration rules and
the event timing; [controls.md](controls.md) has the bindings.
