# Controls

## Principle

Trainer controls are **additive**. Flippers, plunger, nudge, tilt and start
behave exactly as they do on any other VPX table, in both desktop and VR. A
trainer that remapped the flippers would drill the wrong muscle memory.

The drill keys are dispatched from `TrainingKeyDown` before the standard
bindings run, and never consume a key.

## Standard bindings (inherited, unchanged)

| Action | Binding |
|---|---|
| Left flipper | `LeftFlipperKey` (VPX setting, default Left Shift) |
| Right flipper | `RightFlipperKey` (VPX setting, default Right Shift) |
| Plunger | `PlungerKey` (default Enter) |
| Nudge left / right / centre | `LeftTiltKey` / `RightTiltKey` / `CenterTiltKey` |
| Start | `StartGameKey` |

In VR these map to the usual cabinet buttons through your VPX input config;
nothing table-specific is required.

## Trainer bindings

Matched on raw DirectInput scancodes rather than the VPX key constants,
because the constants are user-remappable and the drill controls need to stay
put.

| Key | Scancode | Action | Status |
|---|---|---|---|
| `1` | 2 | Start / restart the current drill | milestone 4 |
| `2` | 3 | Next drill | milestone 4 |
| `3` | 4 | Previous drill | milestone 4 |
| `4` | 5 | Increase difficulty | milestone 5 |
| `5` | 6 | Decrease difficulty | milestone 5 |
| `R` | 19 | Reset the current drill | milestone 4 |
| `D` | 32 | Toggle debug mode | **working** |

Keys marked for a later milestone are already bound and log their press
through `DebugLog` under the `input` category, so the binding can be confirmed
on the real table before the feature behind it exists.

## Debug overlay

`D` toggles debug mode. In **desktop mode** the most recent log lines are
painted onto the score text. In **VR** the buffer is collected but not yet
displayed, because a flat text box renders in front of the playfield and reads
as a rendering fault. The VR-safe readout arrives with the training display in
milestone 4.
