# Controls

## Principle

Trainer controls are **additive**. Flippers, plunger, nudge, tilt and start
behave exactly as they do on any other VPX table, in both desktop and VR. A
trainer that remapped the flippers would drill the wrong muscle memory.

Beyond that, the split is: **menus in VR, keys on desktop**. VR is the primary
target and has no keyboard, so the drill selector is built on the one menu
VPX can show in a headset. The keyboard bindings are the desktop mirror of
the same settings.

## What VPX VR actually supports

Worth stating plainly, because it constrains the design.

`src/input/XRInputHandler.h` defines VPX's whole OpenXR surface: boolean
buttons, analog triggers and sticks, grip poses, and haptics. **None of it is
exposed to VBScript.** The only VR-aware value a script can read is
`RenderingMode` (2 means VR).

There is also **no ray-cast picking** against table geometry anywhere in VPX,
and `InGameUI.cpp` forces button navigation whenever a VR device is present,
explicitly bypassing the mouse path:

```cpp
m_useFlipperNav = m_player->m_vrDevice || ...
```

So "point a controller at a 3D button and click it" is not available to any
VPX table, including VPX's own settings UI. Menus in VR are button-navigated.

## VR: the in-game options menu

The drill selector is registered through `Table1.Option` and appears on the
**Table Options** page of the in-game UI. See `scripts/15-options.vbs`.

Oculus Touch bindings, from VPX's default mapping in `XRInputHandler.h`:

| Control | Action |
|---|---|
| Left **X** | Open / close the in-game UI |
| Left stick up / down | Previous / next item |
| Right stick left / right | Change the selected value |
| Left **Y** | **Exit game** |
| Left / right trigger | Left / right flipper, dual-stage at 0.3 and 0.6 |
| Left / right grip | Left / right MagnaSave |
| Right stick click | Launch ball |
| Left stick click | Re-centre the VR view |
| Right **A** | Start |
| Right **B** | Add credit |

> Left **Y** exits the game and sits next to the menu button. Worth knowing
> before you reach for X mid-session.

### Menu items

| Item | Type | Values |
|---|---|---|
| Drill | enum | The nine drills from [drill-design.md](drill-design.md) |
| Side | enum | Left, Right, Alternating |
| Difficulty | enum | Fixed, Beginner, Intermediate, Advanced |
| Attempts Per Set | enum | 5, 10, 15, 20, 25, 30, 40, 50 |
| Reset Delay | float | 0.4 to 3.0 seconds, 0.1 step |
| Debug Overlay | toggle | Off / On |

Values persist between runs as table settings.

**None of the drills are implemented yet.** The full roster is registered
because the point of the current build is to confirm the menu works in a
headset; milestone 4 puts a drill behind the first entry.

## Desktop: keyboard

Matched on raw DirectInput scancodes rather than the VPX key constants,
because the constants are user-remappable and the drill controls need to stay
put.

| Key | Scancode | Action | Status |
|---|---|---|---|
| `1` | 2 | Start the drill selected in the menu | **working** |
| `2` | 3 | Next drill | milestone 4 |
| `3` | 4 | Previous drill | milestone 4 |
| `4` | 5 | Increase difficulty | milestone 5 |
| `5` | 6 | Decrease difficulty | milestone 5 |
| `R` | 19 | Restart the current drill from attempt 1 | **working** |
| `D` | 32 | Toggle debug mode | **working** |
| `F` | 33 | Feed one ball to the right flipper | **working** |
| `G` | 34 | Feed one ball to the left flipper | **working** |
| `C` | 46 | Run a 20-feed repeatability calibration | **working** |

`F`, `G` and `C` are engineering controls, not drill controls. They exist so
the ball feeder can be calibrated before any drill is built on it, and they
use the difficulty currently selected in the menu (falling back to the fully
repeatable `Fixed` feed if the options have not initialised yet).

Keys marked for a later milestone are already bound and log their press
through `DebugLog` under the `input` category, so the binding can be confirmed
on the real table before the feature behind it exists.

`F12` opens the same in-game UI on desktop, so the menu above is reachable
there too.

## Planned: in-world flipper menu

The in-game UI is a modal overlay. Opening it to change difficulty between
sets would break the practice rhythm, which is the one thing a trainer cannot
afford.

So the in-game UI stays the **setup** menu, and milestone 4 adds an in-world
panel for **in-flow** control: hold both flippers to open, flippers to move
the highlight, MagnaSave (grip) to confirm. That uses only inputs a real
cabinet has, works identically in VR and on desktop, and never pauses the
table.
