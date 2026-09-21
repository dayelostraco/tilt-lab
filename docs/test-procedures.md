# Test procedures

Nothing in this project can be validated on macOS. The build, the static
checks and the JSON edits are reproducible anywhere; every behavioural claim
has to be confirmed by loading the table in Visual Pinball X on Windows.

Each procedure below states the exact file, the exact keys, what should
happen, and what to send back if it does not.

---

## T1a: Desktop smoke test

**Goal:** confirm the table loads with no script error, plays, and that the
options menu and debug toggle work. Everything here is desktop-only, so a
Parallels Windows 11 VM is enough. This catches script errors cheaply, before
anyone powers on a headset.

### Setup

1. Build on macOS:

   ```bash
   cd ~/Development/GitHub/tilt-lab
   tools/build.sh
   ```

   Expect the last line to read `built: .../Pinball Training Lab.vpx (17M)`
   and the line above it to be a green tick from `vpxtool verify`.

2. Copy `table/dist/Pinball Training Lab.vpx` to the VPX tables folder on the
   Windows machine, normally:

   ```
   C:\Visual Pinball\Tables\Pinball Training Lab.vpx
   ```

3. Confirm there is **no** `Pinball Training Lab.vbs` sitting next to it. If
   one is there, Visual Pinball loads that file instead of the table's script
   and the test is meaningless. Delete it.

### Steps

| # | Do this | Expect |
|---|---|---|
| 1 | Open the file in **VPX 10.8.1 BGFX 64-bit**. | The editor opens with no dialog box. A script-error popup here is a failure: copy its full text. |
| 2 | Press **F6** (or Table, Play). | Table loads. One ball is released into the plunger lane. No error popup. |
| 3 | Pull and release the plunger. | Ball is launched, rolls down the playfield, drains, and a new ball is served. |
| 4 | Flip both flippers a few times. | Both respond. Flipper sounds play. Shadows under the flippers rotate with them. |
| 5 | Let a ball roll and watch the shadow beneath it. | A ball shadow tracks the ball across the playfield. |
| 6 | Press **D**. | The score text turns on and shows recent log lines, oldest first, each starting with a millisecond count and a category. At minimum: `boot,Tilt Lab loading`, a `boot,renderingMode=...` line, `boot,ready`, and an `options,registered 9 drills` line. |
| 7 | Press **1**, **2**, **3**, **4**, **5**, **R** one at a time. | Each adds a line reading `input,unbound drill key scancode=N` with N being 2, 3, 4, 5, 6 and 19 respectively. |
| 8 | Press **F12** to open the in-game UI, and go to **Table Options**. | **This is the new part.** Six items are present: Drill, Side, Difficulty, Attempts Per Set, Reset Delay, Debug Overlay. |
| 9 | Check each item's type. | Drill cycles nine named drills starting at "Drop Catch". Side has Left / Right / Alternating. Difficulty has Fixed / Beginner / Intermediate / Advanced. Attempts Per Set shows 5 through 50. Reset Delay is a decimal around 1.2. Debug Overlay is an **Off/On toggle**, not a two-value list. |
| 10 | Change Drill and Difficulty, then close the UI. | On closing, a new `options,drill=...` line appears in the debug log reflecting your choices. |
| 11 | Toggle Debug Overlay in the menu and close the UI. | The overlay turns on or off to match, without needing the D key. |
| 12 | Exit and reload the table, then reopen Table Options. | Your earlier selections persisted. |

### What is explicitly NOT being tested here

Flipper *feel*. The table is still on stock blank-table physics: the flippers
are too elastic and the playfield nearly frictionless. It will not play like a
real machine yet, and it is not supposed to. That is milestone 2.

### If it fails, send back

- The full text of any error dialog, including the reported line number.
- For a script error: the output of `python3 tools/check.py`, and the line at
  that number from `table/src/script.vbs` (the generated file, since VPX line
  numbers refer to it, not to the modules).
- **If an option is missing from the Table Options page**, that means
  `RegisterOption` rejected it and logged the reason rather than raising a
  script error. Send the VPX log (`Visual Pinball\VPinballX.log`, or enable
  logging in the in-game UI) and grep it for `Table.Option`.
- For steps 6 or 7: whether the score text appeared at all, and what it showed.

---

## T1b: VR validation

**Goal:** confirm the table works in a headset and that the options menu is
actually navigable with Touch controllers. **Requires the Windows gaming PC
and a Quest 3.** A VM cannot do this: there is no OpenXR runtime, no headset
and no real GPU.

Run T1a first. There is no point putting on a headset to discover a script
error.

### Steps

| # | Do this | Expect |
|---|---|---|
| 1 | Launch the table in VR (Quest 3 over Virtual Desktop, OpenXR). | Table loads in VR. Cabinet, legs, backbox and plunger are present at plausible physical scale. |
| 2 | Look around. | No flat text box floats in front of the playfield. |
| 3 | Pull the trigger on each controller. | Left and right flippers respond. |
| 4 | Let a ball drain. | A new ball is served, same as desktop. |
| 5 | Press **X** on the left controller. | The in-game UI opens in the headset. |
| 6 | Navigate to **Table Options** using the **left thumbstick up/down**. | The highlight moves between items. |
| 7 | Change a value with the **right thumbstick left/right**. | The value changes. Drill cycles through the nine drill names. |
| 8 | Press **X** again to close. | The UI closes and you are back in the game. |
| 9 | Confirm the choice took. | Reopen the menu; the value you set is still there. |

### If it fails, send back

- Which step, and what happened instead.
- If the menu opens but will not navigate: whether the **left** stick moves
  the highlight and the **right** stick changes values. VPX splits them that
  way deliberately, and it is easy to assume one stick does both.
- If the menu does not open at all: your VPX input profile may not be on the
  OpenXR defaults. Check Input Settings in the in-game UI for what the left X
  button is bound to.
- The `boot,renderingMode=` line from the debug log; it should read `2` in VR.

## T2: Milestone 2 physics validation

Written when milestone 2 lands. It will compare flipper feel and dead-bounce
behaviour against the values recorded in [physics.md](physics.md).

## T3: Milestone 3 feed repeatability

Written when the feeder lands. The core check is objective: run twenty fixed
feeds, read the pre-contact `ball` snapshots out of the debug log, and confirm
the spread in position and speed is small enough that the drill is measuring
the player rather than the feeder.
