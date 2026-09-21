# Test procedures

Nothing in this project can be validated on macOS. The build, the static
checks and the JSON edits are reproducible anywhere; every behavioural claim
has to be confirmed by loading the table in Visual Pinball X on Windows.

Each procedure below states the exact file, the exact keys, what should
happen, and what to send back if it does not.

---

## T1: Milestone 1 smoke test

**Goal:** confirm the trainer table loads, plays, and that the debug toggle
works. This is the gate on milestone 1.

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
| 2 | Press **F6** (or Table, Play) to launch in desktop mode. | Table loads. One ball is released into the plunger lane. No error popup. |
| 3 | Pull and release the plunger. | Ball is launched, rolls down the playfield, drains, and a new ball is served. |
| 4 | Flip both flippers a few times. | Both respond. Flipper sounds play. Shadows under the flippers rotate with them. |
| 5 | Let a ball roll and watch the shadow beneath it. | A ball shadow tracks the ball across the playfield. |
| 6 | Press **D**. | The score text turns on and shows recent log lines, oldest first, each starting with a millisecond count and a category. At minimum you should see `boot,Tilt Lab loading`, a `boot,renderingMode=...` line, and `boot,ready`. |
| 7 | Press **1**, **2**, **3**, **4**, **5**, **R** one at a time. | Each adds a line reading `input,unbound drill key scancode=N` with N being 2, 3, 4, 5, 6 and 19 respectively. This confirms the bindings before the features behind them exist. |
| 8 | Press **D** again. | The score text clears and hides. |
| 9 | Exit. Relaunch in **VR** (Quest 3 over Virtual Desktop, OpenXR). | Table loads in VR. Cabinet, legs, backbox and plunger are present at plausible physical scale. No flat text box floats in front of the playfield. |
| 10 | In VR, flip both flippers and let a ball drain and re-serve. | Same behaviour as desktop. Frame rate is stable. |

### What is explicitly NOT being tested here

Flipper *feel*. The table is still on stock blank-table physics: the flippers
are too weak, too elastic and the playfield is nearly frictionless. It will
not play like a real machine yet, and it is not supposed to. That is
milestone 2.

### If it fails, send back

- The full text of any error dialog, including the reported line number.
- For a script error: the output of `python3 tools/check.py`, and the line at
  that number from `table/src/script.vbs` (the generated file, since VPX line
  numbers refer to it, not to the modules).
- For step 6 or 7: whether the score text appeared at all, and what it showed.
- For step 9 or 10: a note on what is missing or mis-scaled, and the VPX
  rendering mode reported in the `boot,renderingMode=` log line.

---

## T2: Milestone 2 physics validation

Written when milestone 2 lands. It will compare flipper feel and dead-bounce
behaviour against the values recorded in [physics.md](physics.md).

## T3: Milestone 3 feed repeatability

Written when the feeder lands. The core check is objective: run twenty fixed
feeds, read the pre-contact `ball` snapshots out of the debug log, and confirm
the spread in position and speed is small enough that the drill is measuring
the player rather than the feeder.
