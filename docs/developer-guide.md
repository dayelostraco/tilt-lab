# Developer guide

Start here if you are changing Tilt Lab. If you just want to use it, see
[player-guide.md](player-guide.md).

## The one thing that is unusual about this repo

**A `.vpx` is not source.** It is an OLE compound document with geometry in
binary BIFF records and the VBScript buried inside `GameStg/GameData`.
Committing one means a 17 MB opaque blob per change.

So the repo inverts it:

```
scripts/*.vbs  ──concat──▶  table/src/script.vbs  ──┐
                                                    ├─ vpxtool assemble ─▶  table/dist/*.vpx
table/src/gameitems/*.json ─────────────────────────┘
table/src/{gamedata,materials,collections,images,sounds}
```

- `table/src/` is the **source of truth**: JSON per game item, `.obj` meshes,
  loose media. All reviewable in a diff.
- `table/dist/*.vpx` is a **build artifact**, gitignored.
- `scripts/*.vbs` is the **script source of truth**. `table/src/script.vbs`
  is generated and carries a DO NOT EDIT banner.

Full detail, including the `.vbs` sidecar trap that will cost you an hour, is
in [vpx-workflow.md](vpx-workflow.md).

## Getting set up

Needs `bash`, `curl`, `python3`. Nothing else; the build fetches a pinned
`vpxtool` into `~/.local/bin` on first use.

```bash
tools/build.sh           # scripts/ + table/src/  ->  table/dist/*.vpx
tools/check.py           # static checks on the assembled script
tools/import.sh [vpx]    # pull VPX-editor changes back into table/src/
tools/deploy-windows.ps1 # copy to a Windows VPX host + collect log diagnostics
tools/attract.ps1 <mode> # run headlessly on Windows and read the log back
```

## Script module layout

Concatenated in filename order into one script. VBScript hoists global
declarations, so a module may call into one assembled later; the numeric
prefixes exist to make the startup sequence readable, not to satisfy the
interpreter.

| Module | Tag | Contains |
|---|---|---|
| `00-header` | | Bootstrap, VR/desktop detection, module map |
| `05-math` | ZMAT | VPW math helpers (**ported**) |
| `10-config` | ZCFG | Every tunable value, and the unit definitions |
| `12-physics-config` | ZPHY | Physics profile, Global Physics assertion |
| `15-options` | ZOPT | VR-navigable drill selector via `Table1.Option` |
| `20-table-core` | ZCOR | Input, trough, slingshots, GI |
| `30-sound` | ZSND | Positional playback, rolling, impacts |
| `40-physics-nfozzy` | ZNFF | nFozzy flipper corrections (**ported**) |
| `45-physics-damping` | ZDMP | Rubber dampeners, TargetBouncer (**ported**) |
| `50-ball-shadows` | ZSHA | Flipper and ball shadows |
| `60-feeder` | ZFED | Ball delivery and measurement |
| `65-validation` | ZVAL | Automated physics validation sweeps |
| `70-scoring` | ZSCR | Attempt evaluation |
| `80-drills` | ZDRL | Drill state machine |
| `90-ui` | ZUI | Training display |
| `90-training-input` | ZINP | Drill control keys |
| `95-debug` | ZDBG | Logging |
| `99-boot` | ZBOO | Init wiring, self-test hooks. Assembled last. |

**Ported modules are verbatim VPW/nFozzy code** and should not be
restyled or "cleaned up". Their comments carry the reasoning behind the
constants. See [ATTRIBUTION.md](../ATTRIBUTION.md).

## Things that will bite you

These are all real failures that happened here, each of which was silent.

| Trap | Symptom | Guard |
|---|---|---|
| `Const A = B` where B is another Const | **Compile** error; the table never loads | `tools/check.py` |
| Parameter shares a global's name (VBScript is case-**insensitive**) | Local shadows global; assignment is a silent no-op | `tools/check.py` |
| A referenced table object does not exist | Runtime error, only on Windows | `tools/check.py` |
| `Sub X() : ... : End Sub` on one line | Naive brace counting reports it unbalanced | `tools/check.py` |
| VPW's `FlipperActivate` does not rotate the flipper | Flippers simply never move; there is no ROM here to do it | Always use `FlipperUp`/`FlipperDown` |
| A `.vbs` next to the `.vpx` | VPX loads it *instead of* the built script | `.gitignore`, `deploy-windows.ps1` |
| Kicker `Kick` with strength 0 | Ball stays captured and silently ignores velocity writes | Non-zero strength |
| Teleporting a ball onto a kicker | Same: captured, frozen, reports the velocity you set | Park the spawn kicker away |
| VPX pauses physics when unfocused | Everything renders, nothing simulates | `-CaptureAttract` for headless runs |
| `Decal.Text` is writable but **not dynamic** | Assignment succeeds, screen never changes | Use a Flasher in DMD mode |
| `DMDPixels` values written as VBScript literals | Whole panel blows out to white | `CLng()`: it is read with `V_UI4`, and a literal is VT_I2 |
| `Interval = -1` used for anything timed | Window means a different duration at every frame rate | Positive interval = simulation time |

## Testing without a human

The table can test itself. `tools/attract.ps1 <mode>` launches VPX in
`-CaptureAttract`, which is the only play mode where `Player::IsPlaying()`
ignores window focus, and passes `-c1 <mode>` through to `GetCustomParam(1)`.

| Mode | Does |
|---|---|
| `probe` | Drops a ball in open playfield to prove physics is stepping |
| `feed` | One feed |
| `calib` | 20 fixed feeds, reports mean / sd / spread |
| `valid-drop` | Drop-catch timing sweep |
| `valid-live` | Live-catch timing sweep |
| `valid-cradle` | Cradle test |
| `valid-speed` | Launch-speed sweep |
| `drill` | Runs a full drill set |

`tools/capture-frame.ps1 <mode>` renders real frames and keeps one;
`tools/qoi-to-png.py` decodes it (VPX writes QOI, whatever extension it
uses). That is how the display above was verified from macOS with no
headset: a successful property assignment proves nothing about rendering.

Everything the script logs also goes to VPX's log file via `Debug.Print`,
prefixed `TILTLAB,`. To pull a session out as CSV:

```bash
grep "TILTLAB," vpinball.log | sed 's/.*TILTLAB,//' > session.csv
```

That needs `EnableLog` and `LogScriptOutput` on, and **the table must not be
locked**: VPX silently discards script output for locked tables.

## Adding a drill

1. Add a `FeedProfile` in `60-feeder.vbs` if the feed differs.
2. Add a `DRILL_*` constant and a `DrillName` case in `80-drills.vbs`.
3. Handle it in `NextAttempt` to pick the right feed.
4. Map the menu index in `OptDrillToDrillId()` (`90-training-input.vbs`).
5. If the verdict needs different criteria, extend `70-scoring.vbs` rather
   than special-casing inside the drill.

**Do not give a drill its own physics.** Every drill runs the same
simulation; only the feed changes. That is what makes results comparable,
and it is the rule that keeps the trainer honest.

## Where the numbers come from

Every physics value is sourced and cross-checked. Read
[physics.md](physics.md) section 0 before changing any of them, and
[tuning.md](tuning.md) for the units and the calibration loop.

The short version: **1 vpu = 0.53975 mm, 1 VPT = 10 ms, so 1 vpu of velocity
is 0.053975 m/s.** Every speed in the logs is also reported in m/s.

## Document map

| Document | Audience | Covers |
|---|---|---|
| [player-guide.md](player-guide.md) | **Players** | Install, controls, drills, reading verdicts |
| developer-guide.md | Developers | This file: layout, traps, workflow |
| [architecture.md](architecture.md) | Developers | Layering, configuration, measurement |
| [physics.md](physics.md) | Developers | Sources, values, validation results |
| [tuning.md](tuning.md) | Developers | Units, calibration loop, reading the log |
| [drill-design.md](drill-design.md) | Both | The drills and how success is detected |
| [controls.md](controls.md) | Both | Full binding table, VR and desktop |
| [vpx-workflow.md](vpx-workflow.md) | Developers | Source-controlling a `.vpx` |
| [test-procedures.md](test-procedures.md) | Developers | Manual test steps for Windows |
