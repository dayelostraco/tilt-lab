'============================================================================
'  ZCFG: CONFIGURATION - every tunable value lives here
'============================================================================
'
'  Rule for this project: if a number governs how a drill feels, it belongs
'  in this file. Drill logic elsewhere reads these values and never hardcodes
'  its own. That is what makes trajectory tuning a one-file edit.
'
'  Units used throughout:
'    position   VPX units (vpu). The playfield is 952.94 x 2164.71 vpu.
'               1 vpu is roughly 1/50th of a ball diameter; a 1-1/16" ball
'               is 50 vpu across, so ~2.12 vpu per real millimetre.
'    velocity   vpu per physics tick. A hard slingshot kick is ~40-50;
'               a lazy return down an inlane is ~8-15.
'    time       milliseconds.
'
'============================================================================

' --- Ball ------------------------------------------------------------------

' BallSize here is the RADIUS, matching the blank table's convention that the
' inherited shadow and rolling-sound code depends on. Note that VPW-derived
' code conventionally uses BallSize as the DIAMETER (50); when porting VPW
' routines into this project, check which one the snippet means.
Const BallSize = 25
Const BallMass = 1

' Total number of balls the table is built to track at once. The shadow rig
' and the rolling-sound arrays are both sized from this, and the cradle
' separation drill (milestone 8) needs at least 2.
Const tnob = 5

' --- Plunger ---------------------------------------------------------------

' Retracting plunger is a cabinet-button convenience; off by default so the
' manual plunger behaves the way a real one does.
Dim EnableRetractPlunger
EnableRetractPlunger = False

' --- Debug -----------------------------------------------------------------

' Master switch for the debug overlay and structured logging. Toggled at run
' time with the D key; this is only the value it starts at.
Const DEBUG_DEFAULT_ON = False

' How many log lines to keep in the in-memory ring buffer. VPX has no console,
' so the buffer is what the debug overlay renders and what a future CSV export
' would drain.
Const DEBUG_LOG_CAPACITY = 200

' --- Drill defaults --------------------------------------------------------
'
' These are the session-level defaults every drill starts from. Per-drill feed
' geometry (launch position, velocity, randomisation bounds) arrives with the
' feeder subsystem in milestone 3 and will be defined below this block.

' Attempts in one batch before the trainer reports a result and stops.
Const DEFAULT_ATTEMPTS_PER_SET = 10

' Pause between the end of one attempt and the next feed, in ms. Long enough
' to read the per-attempt verdict, short enough to keep a rhythm going.
Const DEFAULT_RESET_DELAY_MS = 1200

' Difficulty levels. Higher levels widen the randomisation bounds that the
' feeder applies; level 0 is a fixed, fully repeatable feed.
Const DIFF_FIXED        = 0
Const DIFF_BEGINNER     = 1
Const DIFF_INTERMEDIATE = 2
Const DIFF_ADVANCED     = 3

Const DEFAULT_DIFFICULTY = DIFF_FIXED

' Which flipper a drill feeds.
Const SIDE_LEFT        = 0
Const SIDE_RIGHT       = 1
Const SIDE_ALTERNATING = 2
