' ============================================================================
'  GENERATED FILE - DO NOT EDIT
'
'  Built from scripts/*.vbs by tools/build.sh.
'  Edit the module files instead; this copy is overwritten on every build.
' ============================================================================

' ---------------------------------------------------------------------------
'  module: scripts/00-header.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  TILT LAB - Pinball Training Lab
'============================================================================
'
'  A Visual Pinball X training table for drilling transferable real-world
'  pinball ball-control skills. This is a skills laboratory, not a game.
'
'  Target: VPX 10.8.1 BGFX 64-bit, PCVR (Quest 3 / Virtual Desktop / OpenXR)
'
'  This file is assembled from scripts/*.vbs by tools/build.sh.
'  Do not edit the copy embedded in the .vpx - it is overwritten on build.
'
'  Credits and licensing for reused community code: see ATTRIBUTION.md.
'
'  --- MODULE MAP -----------------------------------------------------------
'
'    00-header.vbs        this file: bootstrap, VR/desktop detection
'    05-math.vbs          ZMAT  VPW math helpers
'    10-config.vbs        ZCFG  every tunable value, in one place
'    12-physics-config.vbs ZPHY physics profile + Global Physics assertion
'    15-options.vbs       ZOPT  VR-navigable drill selector (Table1.Option)
'    20-table-core.vbs    ZCOR  input, trough, slingshots, GI
'    30-sound.vbs         ZSND  positional playback, rolling, impacts
'    40-physics-nfozzy.vbs ZNFF nFozzy flipper corrections (VPW)
'    45-physics-damping.vbs ZDMP rubber dampeners, TargetBouncer (VPW)
'    50-ball-shadows.vbs  ZSHA  flipper and ball shadows
'    90-training-input.vbs ZINP drill control keys (desktop mirror)
'    95-debug.vbs         ZDBG  debug overlay and structured logging
'    99-boot.vbs          ZBOO  init / exit wiring, runs last
'
'  Modules still to come (see TODO.md):
'    60-feeder            repeatable ball delivery subsystem   (milestone 3)
'    70-scoring           attempt evaluation                   (milestone 4)
'    80-drills            drill state machine                  (milestone 4)
'    90-ui                training display                     (milestone 4)
'
'============================================================================

Option Explicit
Randomize
SetLocale 1033

' controller.vbs ships with VPX and provides the DOF plumbing that the
' SoundFX() calls below depend on. The trainer needs no ROM, so a missing
' controller.vbs is a warning, not a hard failure.
On Error Resume Next
ExecuteGlobal GetTextFile("controller.vbs")
If Err Then MsgBox "Tilt Lab: controller.vbs not found. It ships with VPX in the scripts folder."
On Error Goto 0

' Rendering mode: 0 = desktop, 1 = cabinet/FSS, 2 = VR.
' VPX exposes this through RenderingMode; ShowDT is the older desktop flag.
Dim DesktopMode, VRMode
DesktopMode = Table1.ShowDT
VRMode = (RenderingMode = 2)

' The flat score text belongs to the desktop view only - in VR it floats in
' mid-air in front of the playfield and reads as a rendering bug.
If Not DesktopMode Then ScoreText.Visible = False

' ---------------------------------------------------------------------------
'  module: scripts/05-math.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZMAT: MATH HELPERS (VPW)
'============================================================================
'
'  Ported verbatim from the VPW release of Lord of the Rings (Stern 2003),
'  "Yahoo! Edition", whose script carries the most current nFozzy/VPW stack of
'  any reference available to this project: the polarity class is marked
'  "modified 2023 by nFozzy" and "modified 2024 by rothbauerw".
'
'  Original authorship: nFozzy (flipper corrections), rothbauerw (EOS torque
'  recommendations, ReProcessBalls, live catch), apophis and the VPW team.
'  See ATTRIBUTION.md. Comments from the original are preserved deliberately:
'  they carry the reasoning behind the constants.
'
'  DO NOT retune these values to make a drill easier. See docs/physics.md.
'
'  Assembled early because PI is initialised at global scope and the physics
'  modules evaluate against it.
'
'============================================================================

Dim PI: PI = 4*Atn(1)

Function dSin(degrees)
	dsin = sin(degrees * Pi/180)
End Function

Function dCos(degrees)
	dcos = cos(degrees * Pi/180)
End Function

Function Atn2(dy, dx)
	If dx > 0 Then
		Atn2 = Atn(dy / dx)
	ElseIf dx < 0 Then
		If dy = 0 Then 
			Atn2 = pi
		Else
			Atn2 = Sgn(dy) * (pi - Atn(Abs(dy / dx)))
		end if
	ElseIf dx = 0 Then
		if dy = 0 Then
			Atn2 = 0
		else
			Atn2 = Sgn(dy) * pi / 2
		end if
	End If
End Function

Function max(a,b)
	if a > b then 
		max = a
	Else
		max = b
	end if
end Function

Function min(a,b)
	if a > b then 
		min = b
	Else
		min = a
	end if
end Function

'*** Determines if a Points (px,py) is inside a 4 point polygon A-D in Clockwise/CCW order
Function InRect(px,py,ax,ay,bx,by,cx,cy,dx,dy)
	Dim AB, BC, CD, DA
	AB = (bx*py) - (by*px) - (ax*py) + (ay*px) + (ax*by) - (ay*bx)
	BC = (cx*py) - (cy*px) - (bx*py) + (by*px) + (bx*cy) - (by*cx)
	CD = (dx*py) - (dy*px) - (cx*py) + (cy*px) + (cx*dy) - (cy*dx)
	DA = (ax*py) - (ay*px) - (dx*py) + (dy*px) + (dx*ay) - (dy*ax)

	If (AB <= 0 AND BC <=0 AND CD <= 0 AND DA <= 0) Or (AB >= 0 AND BC >=0 AND CD >= 0 AND DA >= 0) Then
		InRect = True
	Else
		InRect = False       
	End If
End Function

'
Function RotPoint(x,y,angle)
	dim rx, ry
	rx = x*dCos(angle) - y*dSin(angle)
	ry = x*dSin(angle) + y*dCos(angle)
	RotPoint = Array(rx,ry)
End Function



'** Ball location checker

' ---------------------------------------------------------------------------
'  module: scripts/10-config.vbs
' ---------------------------------------------------------------------------
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

' Starting value for the debug overlay only. It is overridden as soon as
' options initialise (see scripts/15-options.vbs), and after that the D key
' and the "Debug Overlay" menu item both drive it.
Const DEBUG_DEFAULT_ON = False

' Mirror every log line to Debug.Print, which VPX writes into its own log file
' as "Script.Print '<line>'" when EnableLog and LogScriptOutput are both on
' (see ScriptInterpreter::DebuggerModule::Print). That is the persistent,
' file-backed CSV sink this project needs for longitudinal training data; the
' ring buffer alone dies with the table.
'
' Two caveats. VPX silently drops script output for LOCKED tables, so never
' lock a table you intend to collect data from. And it costs a file write per
' line, so it is off by default and turned on for calibration and data runs.
Const DEBUG_MIRROR_TO_VPX_LOG = True

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
' Exposed in the in-game menu as "Attempts Per Set"; this is the fallback for
' code running before options initialise.
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

' VBScript requires a Const initialiser to be a LITERAL: "Const A = B" where
' B is another Const is a compile error ("Expected literal constant"), not a
' runtime one, so it takes the whole table down at load.
Const DEFAULT_DIFFICULTY = 0    ' = DIFF_FIXED

' Which flipper a drill feeds.
Const SIDE_LEFT        = 0
Const SIDE_RIGHT       = 1
Const SIDE_ALTERNATING = 2

' ---------------------------------------------------------------------------
'  module: scripts/12-physics-config.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZPHY: PHYSICS PROFILE
'============================================================================
'
'  One profile today: MODERN_STERN. This module exists so that adding WPC or
'  System 11 later is a matter of adding a branch here, not of hunting values
'  through the script.
'
'  --- What this layer does and does not own -------------------------------
'
'  It does NOT reimplement VPW. The nFozzy/VPW stack in 40- and 45- is used
'  as shipped, and its constants stay where VPW put them, because they are
'  cross-referenced by the original comments that explain them. Moving them
'  here would duplicate the authoritative copy and let the two drift.
'
'  What this layer owns is the SELECTION: which era VPW should behave as, and
'  which of the values that genuinely are table-level (friction, slope,
'  flipper strength) apply. VPW is already parameterised by era. The relevant
'  switches, and where they actually live:
'
'    FlipperCoilRampupMode  40-physics-nfozzy.vbs   0 fast / 1 med / 2 slow
'    EOSTnew                40-physics-nfozzy.vbs   1.5 EM..late80s / 1.2 90s+
'    EOSReturn              40-physics-nfozzy.vbs   .055 EM / .045 / .035 / .025
'    playfield friction     table/src/gamedata.json
'    slope                  table/src/gamedata.json (angle_tilt_min/max)
'    flipper strength etc   table/src/gameitems/Flipper.*.json
'
'  The constants below record what the active profile expects. They are read
'  by the physics debug output so that a session log states the profile it was
'  recorded under, and they are what a future profile switch would drive.
'
'  --- CRITICAL: no VPX Global Physics Set ---------------------------------
'
'  This table must never use a Global Physics Set. A global set overrides the
'  per-part values that nFozzy's corrections are calibrated against, which
'  silently invalidates the whole stack: the polarity and velocity tables stay
'  in place but no longer describe the flipper they are correcting.
'
'  Every VPW reference inspected agrees: override_physics = 0 on the table,
'  override_physics_flipper = false, and override_physics = 0 on each flipper.
'  This table matches. AssertNoGlobalPhysics below fails loudly if that ever
'  changes. See docs/physics.md.
'
'============================================================================

' --- Profile identity ------------------------------------------------------

Const PHYS_MODERN_STERN = 0
' Reserved, deliberately not implemented yet:
'   Const PHYS_WPC       = 1
'   Const PHYS_SYSTEM_11 = 2
'   Const PHYS_CUSTOM    = 3

' Literal, not PHYS_MODERN_STERN: VBScript rejects a Const initialised from
' another Const at compile time. Keep this in step with the block above.
Const PhysicsProfile = 0        ' = PHYS_MODERN_STERN

Dim PhysicsProfileName
PhysicsProfileName = "MODERN_STERN"

' --- Values the active profile expects -------------------------------------
'
' These mirror what is set in the table data. They are not the live source of
' truth for the simulation (VPX reads the table data, not these), which is why
' AssertPhysicsProfile checks them against the running table at startup rather
' than assuming.

' Ball mass stays at the VPW standard. The flipper stack is calibrated around
' it, so changing it to alter perceived speed would invalidate every polarity
' and velocity point in 40-physics-nfozzy.vbs. If the game feels wrong, the
' responsible parameter is strength, elasticity_falloff, ramp-up or friction.
Const PHYS_BALL_MASS = 1.0

' Playfield friction. VPW references: LOTR (Stern 2003) 0.24, Medieval Madness
' 0.22, Tron Legacy 0.20. Taking the Stern value.
Const PHYS_PLAYFIELD_FRICTION = 0.24

' Slope in degrees, pinned equal at both ends so the incline cannot drift with
' a setting. Every feed velocity is calibrated against this number.
Const PHYS_TABLE_SLOPE = 6.0

' Flipper coil strength, from the LOTR reference.
Const PHYS_FLIPPER_STRENGTH = 3200.0

' End-of-stroke torque baseline held on the flipper part. The VPW script
' swaps between this and EOSTnew while the coil is at rest or at end of
' stroke; this is only the resting value.
Const PHYS_FLIPPER_EOS_TORQUE = 0.275
Const PHYS_FLIPPER_EOS_ANGLE  = 6.0
Const PHYS_FLIPPER_RETURN     = 0.055
Const PHYS_FLIPPER_RAMPUP     = 2.5

' --- Startup assertions ----------------------------------------------------

' Fails loudly rather than quietly mis-simulating. A Global Physics Set is the
' single most destructive thing that can happen to this table, and it is
' invisible from inside the script unless something checks.
Sub AssertNoGlobalPhysics()
    Dim bad : bad = ""

    If Table1.OverridePhysics <> 0 Then _
        bad = bad & "table OverridePhysics=" & Table1.OverridePhysics & "; "
    If LeftFlipper.OverridePhysics <> 0 Then _
        bad = bad & "LeftFlipper OverridePhysics=" & LeftFlipper.OverridePhysics & "; "
    If RightFlipper.OverridePhysics <> 0 Then _
        bad = bad & "RightFlipper OverridePhysics=" & RightFlipper.OverridePhysics & "; "

    If bad <> "" Then
        DebugLog "physics", "FATAL,global physics override active," & bad
        MsgBox "Tilt Lab: a VPX Global Physics Set is overriding the table." & vbNewLine & vbNewLine & _
               bad & vbNewLine & vbNewLine & _
               "The nFozzy/VPW corrections are calibrated against the per-part " & _
               "values and are not valid while this is on. See docs/physics.md."
    Else
        DebugLog "physics", "global physics override: none (correct)"
    End If
End Sub

' Reports the live table values next to what the profile expects, so a
' mismatch is visible in the log instead of being guessed at.
Sub AssertPhysicsProfile()
    DebugLog "physics", "profile=" & PhysicsProfileName
    DebugLog "physics", "slope,expected=" & PHYS_TABLE_SLOPE & _
        ",actual=" & Table1.SlopeMin & ".." & Table1.SlopeMax
    DebugLog "physics", "friction,expected=" & PHYS_PLAYFIELD_FRICTION & _
        ",actual=" & Table1.Friction
    ' Table.Gravity is NOT the stored gamedata value: PinTable::GetGravity
    ' returns m_Gravity / GRAVITYCONST, so the stored 1.7629848 reads back as
    ' about 0.97 here. Both are logged so neither looks like a discrepancy.
    DebugLog "physics", "gravityScript=" & Table1.Gravity & ",gravityStored=1.7629848" 
    DebugLog "physics", "flipperStrength,expected=" & PHYS_FLIPPER_STRENGTH & _
        ",actual=" & LeftFlipper.Strength & "/" & RightFlipper.Strength
    DebugLog "physics", "flipperMass,actual=" & LeftFlipper.Mass & _
        ",elasticity=" & LeftFlipper.Elasticity & _
        ",falloff=" & LeftFlipper.ElasticityFalloff & _
        ",friction=" & LeftFlipper.Friction
    DebugLog "physics", "eos,rest=" & LeftFlipper.EOSTorque & _
        ",angle=" & LeftFlipper.EOSTorqueAngle & _
        ",EOSTnew=" & EOSTnew & ",EOSReturn=" & EOSReturn
    DebugLog "physics", "rampup,flipper=" & LeftFlipper.RampUp & _
        ",SOSRampup=" & SOSRampup & ",mode=" & FlipperCoilRampupMode
    DebugLog "physics", "liveCatch=" & LiveCatch & _
        ",liveElasticity=" & LiveElasticity & _
        ",distMin=" & LiveDistanceMin & ",distMax=" & LiveDistanceMax & _
        ",baseDampen=" & BaseDampen
    DebugLog "physics", "cradleCollisionDamping=" & FCCDamping
    DebugLog "physics", "targetBouncer=" & TargetBouncerEnabled & _
        ",factor=" & TargetBouncerFactor
End Sub

' One-line physics snapshot for a drill log header, so a training session can
' always be traced back to the physics it was recorded under.
Function PhysicsSignature()
    PhysicsSignature = PhysicsProfileName & _
        ",slope=" & Table1.SlopeMax & _
        ",friction=" & Table1.Friction & _
        ",strength=" & LeftFlipper.Strength & _
        ",rampupMode=" & FlipperCoilRampupMode
End Function

' ---------------------------------------------------------------------------
'  module: scripts/15-options.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZOPT: TABLE OPTIONS - the VR-navigable drill selector
'============================================================================
'
'  VPX 10.8.1 lets a table register custom options through Table1.Option.
'  They appear on the Table Options page of the in-game UI, which is the only
'  menu in VPX that is reachable and navigable in VR. There is no ray-pointer
'  in VPX VR: OpenXR exposes buttons, axes, poses and haptics, nothing is
'  surfaced to VBScript, and InGameUI forces button navigation whenever a VR
'  device is present. So this is the menu, and it costs almost no code.
'
'  In VR with Oculus Touch (VPX default mapping):
'      Left X              open / close the in-game UI
'      Left stick up/down  move between items
'      Right stick L/R     change the selected value
'      Left Y              EXIT GAME - adjacent to the menu button, take care
'
'  See docs/controls.md for the full table.
'
'  --- Table1.Option registration rules, from PinTable::RegisterOption -------
'
'  The call is a property GET that registers on first read and returns the
'  live value. The option TYPE is inferred, and getting the inference wrong
'  silently drops the option (it logs and returns E_FAIL, so the item simply
'  never appears in the UI). The rules:
'
'    values array present   -> min and max must be whole numbers, step must
'                              be exactly 1, and the array must hold exactly
'                              (1 + max - min) entries.
'    array of exactly 2,
'      "Off"/"On", "Hide"/"Show", "False"/"True" (either order)
'                           -> registered as a BOOL toggle, not an enum.
'    any other array        -> ENUM, values labelled by the array.
'    no array, step = 1,
'      whole min            -> INT.
'    anything else          -> FLOAT, displayed as %4.1f.
'
'  Also: min < max strictly, step > 0, min <= default <= max. A single-entry
'  enum is therefore impossible.
'
'  Re-registering an existing option name returns the original definition and
'  does NOT update it, so changing the shape of an option below needs a table
'  reload, not just a rebuild.
'
'  --- Event timing ---------------------------------------------------------
'
'  Table1_OptionEvent fires with:
'      0  options initialise, just after Table1_Init
'      1  an option changed
'      2  legacy, no longer dispatched (a reset arrives as a change)
'      3  the player left the in-game UI
'
'  Event 1 fires on EVERY adjustment tick, and the UI auto-repeats as fast as
'  every 125 ms while a direction is held. So reading values on 1 must stay
'  cheap, and anything disruptive (restarting a drill, respawning a ball)
'  belongs on 3, once the player has actually left the menu.
'
'============================================================================

' Live option values. Read by the drill layer; never written by it.
Dim OptDrill, OptSide, OptDifficulty, OptAttempts, OptResetDelayMs, OptDebug

' Set once the first OptionEvent has populated the values above, so that code
' running earlier cannot read them uninitialised.
Dim OptionsReady
OptionsReady = False

' Drill roster. Index matches the OptDrill enum below.
' NOTE: none of these are implemented yet - milestone 4 builds the first.
' The roster is registered in full because the purpose of this module today
' is to verify that the menu itself works in VR.
Dim DRILL_NAMES
DRILL_NAMES = Array( _
    "Drop Catch", "Live Catch", "Dead Bounce", "Post Pass", "Cradle Separation", _
    "Backhand", "Shot Accuracy", "Recovery", "Mixed Recognition")

' Attempts-per-set is an enum rather than an int so that a handful of stick
' clicks covers the useful range. Index maps into this array.
Dim ATTEMPT_VALUES
ATTEMPT_VALUES = Array(5, 10, 15, 20, 25, 30, 40, 50)

' ---------------------------------------------------------------------------
'  Registration and read-back
' ---------------------------------------------------------------------------

' Reads every option, registering it on the first call. Cheap and idempotent:
' safe to call on every change tick.
Sub ReadTrainingOptions()
    Dim attemptIdx

    ' The extra parentheses around DRILL_NAMES are load-bearing. VBScript
    ' passes a variable ByRef by default, so the array arrives across the COM
    ' boundary as VT_VARIANT|VT_BYREF and fails VPX's VT_ARRAY|VT_VARIANT
    ' check: "the values argument must be omitted or an Array". Wrapping the
    ' argument in parentheses forces ByVal, which dereferences it.
    OptDrill = CInt(Table1.Option("Drill", 0, 8, 1, 0, 0, (DRILL_NAMES)))

    OptSide = CInt(Table1.Option("Side", 0, 2, 1, 0, 0, _
        Array("Left", "Right", "Alternating")))

    OptDifficulty = CInt(Table1.Option("Difficulty", 0, 3, 1, 0, 0, _
        Array("Fixed", "Beginner", "Intermediate", "Advanced")))

    attemptIdx = CInt(Table1.Option("Attempts Per Set", 0, 7, 1, 1, 0, _
        Array("5", "10", "15", "20", "25", "30", "40", "50")))
    OptAttempts = ATTEMPT_VALUES(attemptIdx)

    ' Seconds, not milliseconds: a 0.1 step keeps this on the float path and
    ' "1.2" reads better in the menu than "1200". Converted on read so the
    ' rest of the script keeps working in ms.
    ' The values argument is omitted entirely rather than passed as Empty,
    ' which is what makes this register as a Float rather than an enum.
    OptResetDelayMs = CInt(Table1.Option("Reset Delay", 0.4, 3.0, 0.1, 1.2, 0) * 1000)

    ' Off/On makes this a real toggle rather than a two-entry enum.
    OptDebug = (Table1.Option("Debug Overlay", 0, 1, 1, 0, 0, Array("Off", "On")) <> 0)

    OptionsReady = True
End Sub

' Applies option values to the systems that act on them. Only called at
' initialisation and when the player leaves the menu, never on every tick.
Sub ApplyTrainingOptions()
    If Not OptionsReady Then Exit Sub

    If DebugEnabled <> OptDebug Then
        DebugEnabled = OptDebug
        DebugRender
    End If

    DebugLog "options", "drill=" & DRILL_NAMES(OptDrill) & _
        ",side=" & OptSide & ",difficulty=" & OptDifficulty & _
        ",attempts=" & OptAttempts & ",resetDelayMs=" & OptResetDelayMs & _
        ",debug=" & CStr(OptDebug)

    ' Milestone 4 restarts the selected drill here.
End Sub

Sub Table1_OptionEvent(ByVal eventId)
    Select Case eventId
        Case 0  ' initialise, just after Table1_Init
            ReadTrainingOptions
            DebugLog "options", "registered " & (UBound(DRILL_NAMES) + 1) & " drills"
            ApplyTrainingOptions

        Case 1  ' an option changed. Fires per adjustment tick: keep this cheap.
            ReadTrainingOptions

        Case 3  ' player left the in-game UI. Safe to act.
            ApplyTrainingOptions

    End Select
End Sub

' ---------------------------------------------------------------------------
'  module: scripts/20-table-core.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZCOR: TABLE CORE - input, trough, slingshots, GI
'============================================================================
'
'  Inherited from the Visual Pinball X blank table (see ATTRIBUTION.md).
'  Only the drill-specific key handling in scripts/90-* is layered on top of
'  the standard flipper / plunger / nudge bindings kept here, so normal pinball
'  controls keep behaving exactly as they do on any other table.

Sub Table1_KeyDown(ByVal keycode)
	' Trainer controls are dispatched first but never swallow the key, so the
	' standard flipper / plunger / nudge bindings below always still run.
	TrainingKeyDown keycode

	If keycode = PlungerKey Then
        If EnableRetractPlunger Then
            Plunger.PullBackandRetract
        Else
		    Plunger.PullBack
        End If
		PlaySound "plungerpull",0,1,AudioPan(Plunger),0.25,0,0,1,AudioFade(Plunger)
	End If

	' RotateToEnd is deliberately NOT called directly. FlipperActivate is the
	' VPW entry point: it drives the EOS torque, coil ramp-up and flipper-trick
	' state that the nFozzy corrections depend on. Bypassing it silently
	' disables half the physics stack.
	If keycode = LeftFlipperKey Then
		FlipperActivate LeftFlipper, LFPress
		PlaySound SoundFX("fx_flipperup",DOFFlippers), 0, .67, AudioPan(LeftFlipper), 0.05,0,0,1,AudioFade(LeftFlipper)
	End If

	If keycode = RightFlipperKey Then
		FlipperActivate RightFlipper, RFPress
		PlaySound SoundFX("fx_flipperup",DOFFlippers), 0, .67, AudioPan(RightFlipper), 0.05,0,0,1,AudioFade(RightFlipper)
	End If

	If keycode = LeftTiltKey Then
		Nudge 90, 2
	End If

	If keycode = RightTiltKey Then
		Nudge 270, 2
	End If

	If keycode = CenterTiltKey Then
		Nudge 0, 2
	End If
End Sub

Sub Table1_KeyUp(ByVal keycode)
	TrainingKeyUp keycode

	If keycode = PlungerKey Then
		Plunger.Fire
		PlaySound "plunger",0,1,AudioPan(Plunger),0.25,0,0,1,AudioFade(Plunger)
	End If

	If keycode = LeftFlipperKey Then
		FlipperDeactivate LeftFlipper, LFPress
		PlaySound SoundFX("fx_flipperdown",DOFFlippers), 0, 1, AudioPan(LeftFlipper), 0.05,0,0,1,AudioFade(LeftFlipper)
	End If

	If keycode = RightFlipperKey Then
		FlipperDeactivate RightFlipper, RFPress
		PlaySound SoundFX("fx_flipperdown",DOFFlippers), 0, 1, AudioPan(RightFlipper), 0.05,0,0,1,AudioFade(RightFlipper)
	End If
End Sub


Sub Drain_Hit()
	PlaySound "drain",0,1,AudioPan(Drain),0.25,0,0,1,AudioFade(Drain)
	Drain.DestroyBall
	BIP = BIP - 1

	' In the trainer the feeder owns the ball lifecycle. The stock trough
	' would auto-serve a replacement the moment an attempt drained, which
	' races the next feed and leaves two balls on the playfield.
	If FeederOwnsBalls Then
		If BIP < 0 Then BIP = 0
		DebugLog "drain", "ball drained,balls=" & (UBound(GetBalls) + 1)
		Exit Sub
	End If

	If BIP = 0 then
		BallRelease.CreateBall
		BallRelease.Kick 90, 7
		PlaySound SoundFX("ballrelease",DOFContactors), 0,1,AudioPan(BallRelease),0.25,0,0,1,AudioFade(BallRelease)
		BIP = BIP + 1
	End If
End Sub


Dim BIP
BIP = 0

Sub Plunger_Init()
	PlaySound SoundFX("ballrelease",DOFContactors), 0,1,AudioPan(BallRelease),0.25,0,0,1,AudioFade(BallRelease)
	BallRelease.CreateBall
	BallRelease.Kick 90, 7
	BIP = BIP + 1
End Sub


'*****GI Lights On
dim xx

For each xx in GI:xx.State = 1: Next

'**********Sling Shot Animations
' Rstep and Lstep  are the variables that increment the animation
'****************
Dim RStep, Lstep

Sub RightSlingShot_Slingshot
    PlaySound SoundFX("right_slingshot",DOFContactors), 0,1, 0.05,0.05 '0,1, AudioPan(RightSlingShot), 0.05,0,0,1,AudioFade(RightSlingShot)
    RSling.Visible = 0
    RSling1.Visible = 1
    sling1.rotx = 20
    RStep = 0
    RightSlingShot.TimerEnabled = 1
	gi1.State = 0:Gi2.State = 0
End Sub

Sub RightSlingShot_Timer
    Select Case RStep
        Case 3:RSLing1.Visible = 0:RSLing2.Visible = 1:sling1.rotx = 10
        Case 4:RSLing2.Visible = 0:RSLing.Visible = 1:sling1.rotx = 0:RightSlingShot.TimerEnabled = 0:gi1.State = 1:Gi2.State = 1
    End Select
    RStep = RStep + 1
End Sub

Sub LeftSlingShot_Slingshot
    PlaySound SoundFX("left_slingshot",DOFContactors), 0,1, -0.05,0.05 '0,1, AudioPan(LeftSlingShot), 0.05,0,0,1,AudioFade(LeftSlingShot)
    LSling.Visible = 0
    LSling1.Visible = 1
    sling2.rotx = 20
    LStep = 0
    LeftSlingShot.TimerEnabled = 1
	gi3.State = 0:Gi4.State = 0
End Sub

Sub LeftSlingShot_Timer
    Select Case LStep
        Case 3:LSLing1.Visible = 0:LSLing2.Visible = 1:sling2.rotx = 10
        Case 4:LSLing2.Visible = 0:LSLing.Visible = 1:sling2.rotx = 0:LeftSlingShot.TimerEnabled = 0:gi3.State = 1:Gi4.State = 1
    End Select
    LStep = LStep + 1
End Sub

' ---------------------------------------------------------------------------
'  module: scripts/30-sound.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZSND: SOUND - positional playback, rolling, material impacts
'============================================================================
'
'  Baseline sound layer from the VPX blank table: positional pan/fade helpers,
'  JP's rolling sounds, rothbauerw's drop sounds, and per-material impact subs.
'  This is deliberately NOT the full Fleep package yet - see docs/physics.md.

'*********************************************************************
'                 Positional Sound Playback Functions
'*********************************************************************

' Play a sound, depending on the X,Y position of the table element (especially cool for surround speaker setups, otherwise stereo panning only)
' parameters (defaults): loopcount (1), volume (1), randompitch (0), pitch (0), useexisting (0), restart (1))
' Note that this will not work (currently) for walls/slingshots as these do not feature a simple, single X,Y position
Sub PlayXYSound(soundname, tableobj, loopcount, volume, randompitch, pitch, useexisting, restart)
	PlaySound soundname, loopcount, volume, AudioPan(tableobj), randompitch, pitch, useexisting, restart, AudioFade(tableobj)
End Sub

' Similar subroutines that are less complicated to use (e.g. simply use standard parameters for the PlaySound call)
Sub PlaySoundAt(soundname, tableobj)
    PlaySound soundname, 1, 1, AudioPan(tableobj), 0,0,0, 1, AudioFade(tableobj)
End Sub

Sub PlaySoundAtBall(soundname)
    PlaySoundAt soundname, ActiveBall
End Sub


'*********************************************************************
'                     Supporting Ball & Sound Functions
'*********************************************************************

Function AudioFade(tableobj) ' Fades between front and back of the table (for surround systems or 2x2 speakers, etc), depending on the Y position on the table. "table1" is the name of the table
	Dim tmp
    tmp = tableobj.y * 2 / table1.height-1
    If tmp > 0 Then
		AudioFade = Csng(tmp ^10)
    Else
        AudioFade = Csng(-((- tmp) ^10) )
    End If
End Function

Function AudioPan(tableobj) ' Calculates the pan for a tableobj based on the X position on the table. "table1" is the name of the table
    Dim tmp
    tmp = tableobj.x * 2 / table1.width-1
    If tmp > 0 Then
        AudioPan = Csng(tmp ^10)
    Else
        AudioPan = Csng(-((- tmp) ^10) )
    End If
End Function

Function Vol(ball) ' Calculates the Volume of the sound based on the ball speed
    Vol = Csng(BallVel(ball) ^2 / 2000)
End Function

Function Pitch(ball) ' Calculates the pitch of the sound based on the ball speed
    Pitch = BallVel(ball) * 20
End Function

Function BallVel(ball) 'Calculates the ball speed
    BallVel = INT(SQR((ball.VelX ^2) + (ball.VelY ^2) ) )
End Function


'********************************************************************
'      JP's VP10 Rolling Sounds (+rothbauerw's Dropping Sounds)
'********************************************************************

' tnob (total number of balls) lives in scripts/10-config.vbs.
'
' Interval -1 means "once per rendered frame". The blank table shipped this
' timer at 10 ms, which VPX's own table audit flags as being below 60 FPS and
' as breaking frame pacing. That matters here more than on a normal table: a
' drop catch is a timing judgement measured in a few frames, and at 90 Hz in
' VR an 11.1 ms frame never lines up with a 10 ms tick. Modern VPW drives this
' kind of per-frame work from a -1 timer (see Medieval Madness' FrameTimer).
RollingTimer.Interval = -1
ReDim rolling(tnob)
InitRolling

Sub InitRolling
    Dim i
    For i = 0 to tnob
        rolling(i) = False
    Next
End Sub

Sub RollingTimer_Timer()
    Dim BOT, b
    BOT = GetBalls

    ' stop the sound of deleted balls
    For b = UBound(BOT) + 1 to tnob
        rolling(b) = False
        StopSound("fx_ballrolling" & b)
    Next

    ' exit the sub if no balls on the table
    If UBound(BOT) = -1 Then Exit Sub

    For b = 0 to UBound(BOT)
        ' play the rolling sound for each ball
        If BallVel(BOT(b) ) > 1 AND BOT(b).z < 30 Then
            rolling(b) = True
            PlaySound("fx_ballrolling" & b), -1, Vol(BOT(b)), AudioPan(BOT(b)), 0, Pitch(BOT(b)), 1, 0, AudioFade(BOT(b))
        Else
            If rolling(b) = True Then
                StopSound("fx_ballrolling" & b)
                rolling(b) = False
            End If
        End If

        ' play ball drop sounds
        If BOT(b).VelZ < -1 and BOT(b).z < 55 and BOT(b).z > 27 Then 'height adjust for ball drop sounds
            PlaySound "fx_ball_drop" & b, 0, ABS(BOT(b).velz)/17, AudioPan(BOT(b)), 0, Pitch(BOT(b)), 1, 0, AudioFade(BOT(b))
        End If
    Next
End Sub

'**********************
' Ball Collision Sound
'**********************

' OnBallBallCollision also moved to scripts/40-physics-nfozzy.vbs, because
' VPW's FlipperCradleCollision has to run on it. It still plays the collision
' sound.



Sub Pins_Hit (idx)
	PlaySound "pinhit_low", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 0, 0, AudioFade(ActiveBall)
End Sub

Sub Targets_Hit (idx)
	PlaySound "target", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 0, 0, AudioFade(ActiveBall)
End Sub

Sub Metals_Thin_Hit (idx)
	PlaySound "metalhit_thin", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
End Sub

Sub Metals_Medium_Hit (idx)
	PlaySound "metalhit_medium", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
End Sub

Sub Metals2_Hit (idx)
	PlaySound "metalhit2", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
End Sub

Sub Gates_Hit (idx)
	PlaySound "gate4", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
End Sub

Sub Spinner_Spin
	PlaySound "fx_spinner", 0, .25, AudioPan(Spinner), 0.25, 0, 0, 1, AudioFade(Spinner)
End Sub

Sub Rubbers_Hit(idx)
 	dim finalspeed
  	finalspeed=SQR(activeball.velx * activeball.velx + activeball.vely * activeball.vely)
 	If finalspeed > 20 then 
		PlaySound "fx_rubber2", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
	End if
	If finalspeed >= 6 AND finalspeed <= 20 then
 		RandomSoundRubber()
 	End If
End Sub

Sub Posts_Hit(idx)
 	dim finalspeed
  	finalspeed=SQR(activeball.velx * activeball.velx + activeball.vely * activeball.vely)
 	If finalspeed > 16 then 
		PlaySound "fx_rubber2", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
	End if
	If finalspeed >= 6 AND finalspeed <= 16 then
 		RandomSoundRubber()
 	End If
End Sub

Sub RandomSoundRubber()
	Select Case Int(Rnd*3)+1
		Case 1 : PlaySound "rubber_hit_1", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
		Case 2 : PlaySound "rubber_hit_2", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
		Case 3 : PlaySound "rubber_hit_3", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
	End Select
End Sub

' LeftFlipper_Collide / RightFlipper_Collide now live in
' scripts/40-physics-nfozzy.vbs: VPW requires the live-catch check and the
' polarity reprocess to run on the same event, and a VBScript event sub can
' only be declared once. They still call RandomSoundFlipper below.

Sub RandomSoundFlipper()
	Select Case Int(Rnd*3)+1
		Case 1 : PlaySound "flip_hit_1", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
		Case 2 : PlaySound "flip_hit_2", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
		Case 3 : PlaySound "flip_hit_3", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
	End Select
End Sub

' ---------------------------------------------------------------------------
'  module: scripts/40-physics-nfozzy.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZNFF: nFOZZY FLIPPER PHYSICS (VPW)
'============================================================================
'
'  Ported verbatim from the VPW release of Lord of the Rings (Stern 2003),
'  "Yahoo! Edition", whose script carries the most current nFozzy/VPW stack of
'  any reference available to this project: the polarity class is marked
'  "modified 2023 by nFozzy" and "modified 2024 by rothbauerw".
'
'  Original authorship: nFozzy (flipper corrections), rothbauerw (EOS torque
'  recommendations, ReProcessBalls, live catch), apophis and the VPW team.
'  See ATTRIBUTION.md. Comments from the original are preserved deliberately:
'  they carry the reasoning behind the constants.
'
'  DO NOT retune these values to make a drill easier. See docs/physics.md.
'
'  Contents, in assembled order:
'    - FlipperPolarity class and the polarity / velocity / Ycoef tables
'    - LinearEnvelope
'    - RightFlipper_timer, FlipperNudge, FlipperCradleCollision
'    - flipper geometry helpers (DistanceFromFlipper, FlipperTrigger, ...)
'    - flipper state, EOS constants, FlipperActivate/Deactivate/Tricks
'    - CheckLiveCatch
'
'  Table-side requirements, all satisfied in table/src:
'    - Triggers named TriggerLF and TriggerRF wrapping each flipper
'    - RightFlipper drives the 1 ms trick timer (enabled below, in script)
'    - gBOT, the live ball array, refreshed per frame (see bottom of file)
'
'============================================================================

'********************
'     FlippersPol
'********************


dim LF : Set LF = New FlipperPolarity
dim RF : Set RF = New FlipperPolarity

InitPolarity

Sub InitPolarity()
	Dim x, a
	a = Array(LF, RF)
	For Each x In a
		x.AddPt "Ycoef", 0, RightFlipper.Y-65, 1 'disabled
		x.AddPt "Ycoef", 1, RightFlipper.Y-11, 1
		x.enabled = True
		x.TimeDelay = 60
		x.DebugOn=False ' prints some info in debugger

		x.AddPt "Polarity", 0, 0, 0
		x.AddPt "Polarity", 1, 0.05, - 5.5
		x.AddPt "Polarity", 2, 0.16, - 5.5
		x.AddPt "Polarity", 3, 0.20, - 0.75
		x.AddPt "Polarity", 4, 0.25, - 1.25
		x.AddPt "Polarity", 5, 0.3, - 1.75
		x.AddPt "Polarity", 6, 0.4, - 3.5
		x.AddPt "Polarity", 7, 0.5, - 5.25
		x.AddPt "Polarity", 8, 0.7, - 4.0
		x.AddPt "Polarity", 9, 0.75, - 3.5
		x.AddPt "Polarity", 10, 0.8, - 3.0
		x.AddPt "Polarity", 11, 0.85, - 2.5
		x.AddPt "Polarity", 12, 0.9, - 2.0
		x.AddPt "Polarity", 13, 0.95, - 1.5
		x.AddPt "Polarity", 14, 1, - 1.0
		x.AddPt "Polarity", 15, 1.05, -0.5
		x.AddPt "Polarity", 16, 1.1, 0
		x.AddPt "Polarity", 17, 1.3, 0

		x.AddPt "Velocity", 0, 0, 0.85
		x.AddPt "Velocity", 1, 0.23, 0.85
		x.AddPt "Velocity", 2, 0.27, 1
		x.AddPt "Velocity", 3, 0.3, 1
		x.AddPt "Velocity", 4, 0.35, 1
		x.AddPt "Velocity", 5, 0.6, 1 '0.982
		x.AddPt "Velocity", 6, 0.62, 1.0
		x.AddPt "Velocity", 7, 0.702, 0.968
		x.AddPt "Velocity", 8, 0.95,  0.968
		x.AddPt "Velocity", 9, 1.03,  0.945
		x.AddPt "Velocity", 10, 1.5,  0.945

	Next
	
	' SetObjects arguments: 1: name of object 2: flipper object: 3: Trigger object around flipper
	LF.SetObjects "LF", LeftFlipper, TriggerLF
	RF.SetObjects "RF", RightFlipper, TriggerRF
End Sub


'******************************************************
'  FLIPPER CORRECTION FUNCTIONS
'******************************************************

' modified 2023 by nFozzy
' Removed need for 'endpoint' objects
' Added 'createvents' type thing for TriggerLF / TriggerRF triggers.
' Removed AddPt function which complicated setup imo
' made DebugOn do something (prints some stuff in debugger)
'   Otherwise it should function exactly the same as before\
' modified 2024 by rothbauerw
' Added Reprocessballs for flipper collisions (LF.Reprocessballs Activeball and RF.Reprocessballs Activeball must be added to the flipper collide subs
' Improved handling to remove correction for backhand shots when the flipper is raised

Class FlipperPolarity
	Public DebugOn, Enabled
	Private FlipAt		'Timer variable (IE 'flip at 723,530ms...)
	Public TimeDelay		'delay before trigger turns off and polarity is disabled
	Private Flipper, FlipperStart, FlipperEnd, FlipperEndY, LR, PartialFlipCoef, FlipStartAngle
	Private Balls(20), balldata(20)
	Private Name
	
	Dim PolarityIn, PolarityOut
	Dim VelocityIn, VelocityOut
	Dim YcoefIn, YcoefOut
	Public Sub Class_Initialize
		ReDim PolarityIn(0)
		ReDim PolarityOut(0)
		ReDim VelocityIn(0)
		ReDim VelocityOut(0)
		ReDim YcoefIn(0)
		ReDim YcoefOut(0)
		Enabled = True
		TimeDelay = 50
		LR = 1
		Dim x
		For x = 0 To UBound(balls)
			balls(x) = Empty
			Set Balldata(x) = new SpoofBall
		Next
	End Sub
	
	Public Sub SetObjects(aName, aFlipper, aTrigger)
		
		If TypeName(aName) <> "String" Then MsgBox "FlipperPolarity: .SetObjects error: first argument must be a String (And name of Object). Found:" & TypeName(aName) End If
		If TypeName(aFlipper) <> "Flipper" Then MsgBox "FlipperPolarity: .SetObjects error: Second argument must be a flipper. Found:" & TypeName(aFlipper) End If
		If TypeName(aTrigger) <> "Trigger" Then MsgBox "FlipperPolarity: .SetObjects error: third argument must be a trigger. Found:" & TypeName(aTrigger) End If
		If aFlipper.EndAngle > aFlipper.StartAngle Then LR = -1 Else LR = 1 End If
		Name = aName
		Set Flipper = aFlipper
		FlipperStart = aFlipper.x
		FlipperEnd = Flipper.Length * Sin((Flipper.StartAngle / 57.295779513082320876798154814105)) + Flipper.X ' big floats for degree to rad conversion
		FlipperEndY = Flipper.Length * Cos(Flipper.StartAngle / 57.295779513082320876798154814105)*-1 + Flipper.Y
		
		Dim str
		str = "Sub " & aTrigger.name & "_Hit() : " & aName & ".AddBall ActiveBall : End Sub'"
		ExecuteGlobal(str)
		str = "Sub " & aTrigger.name & "_UnHit() : " & aName & ".PolarityCorrect ActiveBall : End Sub'"
		ExecuteGlobal(str)
		
	End Sub
	
	' Legacy: just no op
	Public Property Let EndPoint(aInput)
		
	End Property
	
	Public Sub AddPt(aChooseArray, aIDX, aX, aY) 'Index #, X position, (in) y Position (out)
		Select Case aChooseArray
			Case "Polarity"
				ShuffleArrays PolarityIn, PolarityOut, 1
				PolarityIn(aIDX) = aX
				PolarityOut(aIDX) = aY
				ShuffleArrays PolarityIn, PolarityOut, 0
			Case "Velocity"
				ShuffleArrays VelocityIn, VelocityOut, 1
				VelocityIn(aIDX) = aX
				VelocityOut(aIDX) = aY
				ShuffleArrays VelocityIn, VelocityOut, 0
			Case "Ycoef"
				ShuffleArrays YcoefIn, YcoefOut, 1
				YcoefIn(aIDX) = aX
				YcoefOut(aIDX) = aY
				ShuffleArrays YcoefIn, YcoefOut, 0
		End Select
	End Sub
	
	Public Sub AddBall(aBall)
		Dim x
		For x = 0 To UBound(balls)
			If IsEmpty(balls(x)) Then
				Set balls(x) = aBall
				Exit Sub
			End If
		Next
	End Sub
	
	Private Sub RemoveBall(aBall)
		Dim x
		For x = 0 To UBound(balls)
			If TypeName(balls(x) ) = "IBall" Then
				If aBall.ID = Balls(x).ID Then
					balls(x) = Empty
					Balldata(x).Reset
				End If
			End If
		Next
	End Sub
	
	Public Sub Fire()
		Flipper.RotateToEnd
		processballs
	End Sub
	
	Public Property Get Pos 'returns % position a ball. For debug stuff.
		Dim x
		For x = 0 To UBound(balls)
			If Not IsEmpty(balls(x)) Then
				pos = pSlope(Balls(x).x, FlipperStart, 0, FlipperEnd, 1)
			End If
		Next
	End Property
	
	Public Sub ProcessBalls() 'save data of balls in flipper range
		FlipAt = GameTime
		Dim x
		For x = 0 To UBound(balls)
			If Not IsEmpty(balls(x)) Then
				balldata(x).Data = balls(x)
			End If
		Next
		FlipStartAngle = Flipper.currentangle
		PartialFlipCoef = ((Flipper.StartAngle - Flipper.CurrentAngle) / (Flipper.StartAngle - Flipper.EndAngle))
		PartialFlipCoef = abs(PartialFlipCoef-1)
	End Sub

	Public Sub ReProcessBalls(aBall) 'save data of balls in flipper range
		If FlipperOn() Then
			Dim x
			For x = 0 To UBound(balls)
				If Not IsEmpty(balls(x)) Then
					if balls(x).ID = aBall.ID Then
						If isempty(balldata(x).ID) Then
							balldata(x).Data = balls(x)
						End If
					End If
				End If
			Next
		End If
	End Sub

	'Timer shutoff for polaritycorrect
	Private Function FlipperOn()
		If GameTime < FlipAt+TimeDelay Then
			FlipperOn = True
		End If
	End Function
	
	Public Sub PolarityCorrect(aBall)
		If FlipperOn() Then
			Dim tmp, BallPos, x, IDX, Ycoef, BalltoFlip, BalltoBase, NoCorrection, checkHit
			Ycoef = 1
			
			'y safety Exit
			If aBall.VelY > -8 Then 'ball going down
				RemoveBall aBall
				Exit Sub
			End If
			
			'Find balldata. BallPos = % on Flipper
			For x = 0 To UBound(Balls)
				If aBall.id = BallData(x).id And Not IsEmpty(BallData(x).id) Then
					idx = x
					BallPos = PSlope(BallData(x).x, FlipperStart, 0, FlipperEnd, 1)
					BalltoFlip = DistanceFromFlipperAngle(BallData(x).x, BallData(x).y, Flipper, FlipStartAngle)
					If ballpos > 0.65 Then  Ycoef = LinearEnvelope(BallData(x).Y, YcoefIn, YcoefOut)								'find safety coefficient 'ycoef' data
				End If
			Next
			
			If BallPos = 0 Then 'no ball data meaning the ball is entering and exiting pretty close to the same position, use current values.
				BallPos = PSlope(aBall.x, FlipperStart, 0, FlipperEnd, 1)
				If ballpos > 0.65 Then  Ycoef = LinearEnvelope(aBall.Y, YcoefIn, YcoefOut)												'find safety coefficient 'ycoef' data
				NoCorrection = 1
			Else
				checkHit = 50 + (20 * BallPos) 

				If BalltoFlip > checkHit or (PartialFlipCoef < 0.5 and BallPos > 0.22) Then
					NoCorrection = 1
				Else
					NoCorrection = 0
				End If
			End If
			
			'Velocity correction
			If Not IsEmpty(VelocityIn(0) ) Then
				Dim VelCoef
				VelCoef = LinearEnvelope(BallPos, VelocityIn, VelocityOut)
				
				'If partialflipcoef < 1 Then VelCoef = PSlope(partialflipcoef, 0, 1, 1, VelCoef)
				
				If Enabled Then aBall.Velx = aBall.Velx*VelCoef
				If Enabled Then aBall.Vely = aBall.Vely*VelCoef
			End If
			
			'Polarity Correction (optional now)
			If Not IsEmpty(PolarityIn(0) ) Then
				Dim AddX
				AddX = LinearEnvelope(BallPos, PolarityIn, PolarityOut) * LR
				
				If Enabled and NoCorrection = 0 Then aBall.VelX = aBall.VelX + 1 * (AddX*ycoef*PartialFlipcoef*VelCoef)
			End If
			If DebugOn Then debug.print "PolarityCorrect" & " " & Name & " @ " & GameTime & " " & Round(BallPos*100) & "%" & " AddX:" & Round(AddX,2) & " Vel%:" & Round(VelCoef*100)
		End If
		RemoveBall aBall
	End Sub
End Class

'******************************************************
'  FLIPPER POLARITY AND RUBBER DAMPENER SUPPORTING FUNCTIONS
'******************************************************

' Used for flipper correction and rubber dampeners
Sub ShuffleArray(ByRef aArray, byVal offset) 'shuffle 1d array
	Dim x, aCount
	aCount = 0
	ReDim a(UBound(aArray) )
	For x = 0 To UBound(aArray)		'Shuffle objects in a temp array
		If Not IsEmpty(aArray(x) ) Then
			If IsObject(aArray(x)) Then
				Set a(aCount) = aArray(x)
			Else
				a(aCount) = aArray(x)
			End If
			aCount = aCount + 1
		End If
	Next
	If offset < 0 Then offset = 0
	ReDim aArray(aCount-1+offset)		'Resize original array
	For x = 0 To aCount-1				'set objects back into original array
		If IsObject(a(x)) Then
			Set aArray(x) = a(x)
		Else
			aArray(x) = a(x)
		End If
	Next
End Sub

' Used for flipper correction and rubber dampeners
Sub ShuffleArrays(aArray1, aArray2, offset)
	ShuffleArray aArray1, offset
	ShuffleArray aArray2, offset
End Sub

' Used for flipper correction, rubber dampeners, and drop targets
Function BallSpeed(ball) 'Calculates the ball speed
	BallSpeed = Sqr(ball.VelX^2 + ball.VelY^2 + ball.VelZ^2)
End Function

' Used for flipper correction and rubber dampeners
Function PSlope(Input, X1, Y1, X2, Y2)		'Set up line via two points, no clamping. Input X, output Y
	Dim x, y, b, m
	x = input
	m = (Y2 - Y1) / (X2 - X1)
	b = Y2 - m*X2
	Y = M*x+b
	PSlope = Y
End Function

' Used for flipper correction
Class spoofball
	Public X, Y, Z, VelX, VelY, VelZ, ID, Mass, Radius
	Public Property Let Data(aBall)
		With aBall
			x = .x
			y = .y
			z = .z
			velx = .velx
			vely = .vely
			velz = .velz
			id = .ID
			mass = .mass
			radius = .radius
		End With
	End Property
	Public Sub Reset()
		x = Empty
		y = Empty
		z = Empty
		velx = Empty
		vely = Empty
		velz = Empty
		id = Empty
		mass = Empty
		radius = Empty
	End Sub
End Class

' Used for flipper correction and rubber dampeners
Function LinearEnvelope(xInput, xKeyFrame, yLvl)
	Dim y 'Y output
	Dim L 'Line
	'find active line
	Dim ii
	For ii = 1 To UBound(xKeyFrame)
		If xInput <= xKeyFrame(ii) Then
			L = ii
			Exit For
		End If
	Next
	If xInput > xKeyFrame(UBound(xKeyFrame) ) Then L = UBound(xKeyFrame)		'catch line overrun
	Y = pSlope(xInput, xKeyFrame(L-1), yLvl(L-1), xKeyFrame(L), yLvl(L) )
	
	If xInput <= xKeyFrame(LBound(xKeyFrame) ) Then Y = yLvl(LBound(xKeyFrame) )		 'Clamp lower
	If xInput >= xKeyFrame(UBound(xKeyFrame) ) Then Y = yLvl(UBound(xKeyFrame) )		'Clamp upper
	
	LinearEnvelope = Y
End Function

'******************************************************
'  FLIPPER TRICKS
'******************************************************
' To add the flipper tricks you must
'	 - Include a call to FlipperCradleCollision from within OnBallBallCollision subroutine
'	 - Include a call the CheckLiveCatch from the LeftFlipper_Collide and RightFlipper_Collide subroutines
'	 - Include FlipperActivate and FlipperDeactivate in the Flipper solenoid subs

RightFlipper.timerinterval = 1
Rightflipper.timerenabled = True

Sub RightFlipper_timer()
	FlipperTricks LeftFlipper, LFPress, LFCount, LFEndAngle, LFState
	FlipperTricks RightFlipper, RFPress, RFCount, RFEndAngle, RFState
	FlipperNudge RightFlipper, RFEndAngle, RFEOSNudge, LeftFlipper, LFEndAngle
	FlipperNudge LeftFlipper, LFEndAngle, LFEOSNudge,  RightFlipper, RFEndAngle
End Sub

Dim LFEOSNudge, RFEOSNudge

Sub FlipperNudge(Flipper1, Endangle1, EOSNudge1, Flipper2, EndAngle2)
	Dim b
	'   Dim BOT
	'   BOT = GetBalls
	
	If Flipper1.currentangle = Endangle1 And EOSNudge1 <> 1 Then
		EOSNudge1 = 1
		'   debug.print Flipper1.currentangle &" = "& Endangle1 &"--"& Flipper2.currentangle &" = "& EndAngle2
		If Flipper2.currentangle = EndAngle2 Then
			For b = 0 To UBound(gBOT)
				If FlipperTrigger(gBOT(b).x, gBOT(b).y, Flipper1) Then
					'Debug.Print "ball in flip1. exit"
					Exit Sub
				End If
			Next
			For b = 0 To UBound(gBOT)
				If FlipperTrigger(gBOT(b).x, gBOT(b).y, Flipper2) Then
					gBOT(b).velx = gBOT(b).velx / 1.3
					gBOT(b).vely = gBOT(b).vely - 0.5
				End If
			Next
		End If
	Else
		If Abs(Flipper1.currentangle) > Abs(EndAngle1) + 30 Then EOSNudge1 = 0
	End If
End Sub


Dim FCCDamping: FCCDamping = 0.4

Sub FlipperCradleCollision(ball1, ball2, velocity)
	if velocity < 0.7 then exit sub		'filter out gentle collisions
    Dim DoDamping, coef
    DoDamping = false
    'Check left flipper
    If LeftFlipper.currentangle = LFEndAngle Then
		If FlipperTrigger(ball1.x, ball1.y, LeftFlipper) OR FlipperTrigger(ball2.x, ball2.y, LeftFlipper) Then DoDamping = true
    End If
    'Check right flipper
    If RightFlipper.currentangle = RFEndAngle Then
		If FlipperTrigger(ball1.x, ball1.y, RightFlipper) OR FlipperTrigger(ball2.x, ball2.y, RightFlipper) Then DoDamping = true
    End If
    If DoDamping Then
		coef = FCCDamping
        ball1.velx = ball1.velx * coef: ball1.vely = ball1.vely * coef: ball1.velz = ball1.velz * coef
        ball2.velx = ball2.velx * coef: ball2.vely = ball2.vely * coef: ball2.velz = ball2.velz * coef
    End If
End Sub
	


'*************************************************
'  Check ball distance from Flipper for Rem
'*************************************************

Function Distance(ax,ay,bx,by)
	Distance = Sqr((ax - bx) ^ 2 + (ay - by) ^ 2)
End Function

Function DistancePL(px,py,ax,ay,bx,by) 'Distance between a point and a line where point Is px,py
	DistancePL = Abs((by - ay) * px - (bx - ax) * py + bx * ay - by * ax) / Distance(ax,ay,bx,by)
End Function

Function Radians(Degrees)
	Radians = Degrees * PI / 180
End Function

Function AnglePP(ax,ay,bx,by)
	AnglePP = Atn2((by - ay),(bx - ax)) * 180 / PI
End Function

Function DistanceFromFlipper(ballx, bally, Flipper)
	DistanceFromFlipper = DistancePL(ballx, bally, Flipper.x, Flipper.y, Cos(Radians(Flipper.currentangle + 90)) + Flipper.x, Sin(Radians(Flipper.currentangle + 90)) + Flipper.y)
End Function

Function DistanceFromFlipperAngle(ballx, bally, Flipper, Angle)
	DistanceFromFlipperAngle = DistancePL(ballx, bally, Flipper.x, Flipper.y, Cos(Radians(Angle + 90)) + Flipper.x, Sin(Radians(angle + 90)) + Flipper.y)
End Function

Function FlipperTrigger(ballx, bally, Flipper)
	Dim DiffAngle
	DiffAngle = Abs(Flipper.currentangle - AnglePP(Flipper.x, Flipper.y, ballx, bally) - 90)
	If DiffAngle > 180 Then DiffAngle = DiffAngle - 360
	
	If DistanceFromFlipper(ballx,bally,Flipper) < 48 And DiffAngle <= 90 And Distance(ballx,bally,Flipper.x,Flipper.y) < Flipper.Length Then
		FlipperTrigger = True
	Else
		FlipperTrigger = False
	End If
End Function

'*************************************************
'  End - Check ball distance from Flipper for Rem
'*************************************************

Dim LFPress, RFPress, LFCount, RFCount
Dim LFState, RFState
Dim EOST, EOSA,Frampup, FElasticity,FReturn
Dim RFEndAngle, LFEndAngle

Const FlipperCoilRampupMode = 0 '0 = fast, 1 = medium, 2 = slow (tap passes should work)

LFState = 1
RFState = 1
EOST = leftflipper.eostorque
EOSA = leftflipper.eostorqueangle
Frampup = LeftFlipper.rampup
FElasticity = LeftFlipper.elasticity
FReturn = LeftFlipper.return
'Const EOSTnew = 1.5 'EM's to late 80's - new recommendation by rothbauerw (previously 1)
Const EOSTnew = 1.2 '90's and later - new recommendation by rothbauerw (previously 0.8)
Const EOSAnew = 1
Const EOSRampup = 0
Dim SOSRampup
Select Case FlipperCoilRampupMode
	Case 0
		SOSRampup = 2.5
	Case 1
		SOSRampup = 6
	Case 2
		SOSRampup = 8.5
End Select

Const LiveCatch = 16
Const LiveElasticity = 0.45
Const SOSEM = 0.815
'Const EOSReturn = 0.055  'EM's
'Const EOSReturn = 0.045  'late 70's to mid 80's
'Const EOSReturn = 0.035  'mid 80's to early 90's
Const EOSReturn = 0.025  'mid 90's and later

LFEndAngle = Leftflipper.endangle
RFEndAngle = RightFlipper.endangle

Sub FlipperActivate(Flipper, FlipperPress)
	FlipperPress = 1
	Flipper.Elasticity = FElasticity
	
	Flipper.eostorque = EOST
	Flipper.eostorqueangle = EOSA
End Sub

Sub FlipperDeactivate(Flipper, FlipperPress)
	FlipperPress = 0
	Flipper.eostorqueangle = EOSA
	Flipper.eostorque = EOST * EOSReturn / FReturn
	
	If Abs(Flipper.currentangle) <= Abs(Flipper.endangle) + 0.1 Then
		Dim b', BOT
		'		BOT = GetBalls
		
		For b = 0 To UBound(gBOT)
			If Distance(gBOT(b).x, gBOT(b).y, Flipper.x, Flipper.y) < 55 Then 'check for cradle
				If gBOT(b).vely >= - 0.4 Then gBOT(b).vely =  - 0.4
			End If
		Next
	End If
End Sub

Sub FlipperTricks (Flipper, FlipperPress, FCount, FEndAngle, FState)
	Dim Dir
	Dir = Flipper.startangle / Abs(Flipper.startangle) '-1 for Right Flipper
	
	If Abs(Flipper.currentangle) > Abs(Flipper.startangle) - 0.05 Then
		If FState <> 1 Then
			Flipper.rampup = SOSRampup
			Flipper.endangle = FEndAngle - 3 * Dir
			Flipper.Elasticity = FElasticity * SOSEM
			FCount = 0
			FState = 1
		End If
	ElseIf Abs(Flipper.currentangle) <= Abs(Flipper.endangle) And FlipperPress = 1 Then
		If FCount = 0 Then FCount = GameTime
		
		If FState <> 2 Then
			Flipper.eostorqueangle = EOSAnew
			Flipper.eostorque = EOSTnew
			Flipper.rampup = EOSRampup
			Flipper.endangle = FEndAngle
			FState = 2
		End If
	ElseIf Abs(Flipper.currentangle) > Abs(Flipper.endangle) + 0.01 And FlipperPress = 1 Then
		If FState <> 3 Then
			Flipper.eostorque = EOST
			Flipper.eostorqueangle = EOSA
			Flipper.rampup = Frampup
			Flipper.Elasticity = FElasticity
			FState = 3
		End If
	End If
End Sub

Const LiveDistanceMin = 5  'minimum distance In vp units from flipper base live catch dampening will occur
Const LiveDistanceMax = 114 'maximum distance in vp units from flipper base live catch dampening will occur (tip protection)
Const BaseDampen = 0.55

Sub CheckLiveCatch(ball, Flipper, FCount, parm) 'Experimental new live catch
    Dim Dir, LiveDist
    Dir = Flipper.startangle / Abs(Flipper.startangle)    '-1 for Right Flipper
    Dim LiveCatchBounce   'If live catch is not perfect, it won't freeze ball totally
    Dim CatchTime
    CatchTime = GameTime - FCount
    LiveDist = Abs(Flipper.x - ball.x)

    If CatchTime <= LiveCatch And parm > 3 And LiveDist > LiveDistanceMin And LiveDist < LiveDistanceMax Then
        If CatchTime <= LiveCatch * 0.5 Then   'Perfect catch only when catch time happens in the beginning of the window
            LiveCatchBounce = 0
        Else
            LiveCatchBounce = Abs((LiveCatch / 2) - CatchTime)  'Partial catch when catch happens a bit late
        End If
        
        If LiveCatchBounce = 0 And ball.velx * Dir > 0 And LiveDist > 30 Then ball.velx = 0

        If ball.velx * Dir > 0 And LiveDist < 30 Then
            ball.velx = BaseDampen * ball.velx
            ball.vely = BaseDampen * ball.vely
            ball.angmomx = BaseDampen * ball.angmomx
            ball.angmomy = BaseDampen * ball.angmomy
            ball.angmomz = BaseDampen * ball.angmomz
        Elseif LiveDist > 30 Then
            ball.vely = LiveCatchBounce * (32 / LiveCatch) ' Multiplier for inaccuracy bounce
            ball.angmomx = 0
            ball.angmomy = 0
            ball.angmomz = 0
        End If
    Else
        If Abs(Flipper.currentangle) <= Abs(Flipper.endangle) + 1 Then FlippersD.Dampenf ActiveBall, parm
    End If
End Sub

'******************************************************
'****  END FLIPPER CORRECTIONS
'******************************************************





'******************************************************


'============================================================================
'  TRAINER WIRING
'============================================================================
'
'  Everything below is this project's own glue, not ported VPW code.

' The VPW stack needs a current ball array. LOTR keeps a fixed four-ball
' trough array; the trainer creates and destroys balls on demand, so gBOT is
' refreshed every frame instead.
'
' Interval -1 means "once per rendered frame", which is the modern VPX way to
' drive per-frame work. A fixed short interval would fight frame pacing.
Dim gBOT
gBOT = Array()
PhysicsFrameTimer.Interval = -1
PhysicsFrameTimer.Enabled = True

Sub PhysicsFrameTimer_Timer()
    gBOT = GetBalls
    FeederUpdate
    SelfTestTick
    ProbeTick
End Sub

' VPW requires these three call sites. Keeping them here, next to the code
' that needs them, rather than buried in the sound or input modules.

Sub LeftFlipper_Collide(parm)
    FeederNoteFlipperContact LeftFlipper
    CheckLiveCatch ActiveBall, LeftFlipper, LFCount, parm
    LF.ReProcessBalls ActiveBall
    FlippersD.Dampen ActiveBall
    RandomSoundFlipper
End Sub

Sub RightFlipper_Collide(parm)
    FeederNoteFlipperContact RightFlipper
    CheckLiveCatch ActiveBall, RightFlipper, RFCount, parm
    RF.ReProcessBalls ActiveBall
    FlippersD.Dampen ActiveBall
    RandomSoundFlipper
End Sub

Sub OnBallBallCollision(ball1, ball2, velocity)
    FlipperCradleCollision ball1, ball2, velocity
    PlaySound "fx_collide", 0, Csng(velocity) ^ 2 / 2000, AudioPan(ball1), 0, Pitch(ball1), 0, 0, AudioFade(ball1)
End Sub

' ---------------------------------------------------------------------------
'  module: scripts/45-physics-damping.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZDMP / ZBOU: RUBBER DAMPENERS AND TARGET BOUNCER (VPW)
'============================================================================
'
'  Ported verbatim from the VPW release of Lord of the Rings (Stern 2003),
'  "Yahoo! Edition", whose script carries the most current nFozzy/VPW stack of
'  any reference available to this project: the polarity class is marked
'  "modified 2023 by nFozzy" and "modified 2024 by rothbauerw".
'
'  Original authorship: nFozzy (flipper corrections), rothbauerw (EOS torque
'  recommendations, ReProcessBalls, live catch), apophis and the VPW team.
'  See ATTRIBUTION.md. Comments from the original are preserved deliberately:
'  they carry the reasoning behind the constants.
'
'  DO NOT retune these values to make a drill easier. See docs/physics.md.
'
'  Table-side requirements:
'    - Collections dPosts and dSleeves, with "fire events" enabled
'    - Collections zCol_Rubber_LSling and zCol_Rubber_RSling
'    - A timer named CorTimer at 10 ms, which drives the CoR tracker
'
'  The dampener needs the ball's speed from the frame BEFORE impact to compute
'  a coefficient of restitution, which is why CoRTracker runs on its own short
'  timer rather than per frame.
'
'============================================================================

' 	ZDMP:  RUBBER  DAMPENERS
'******************************************************
' These are data mined bounce curves,
' dialed in with the in-game elasticity as much as possible to prevent angle / spin issues.
' Requires tracking ballspeed to calculate COR

Sub dPosts_Hit(idx)
	RubbersD.dampen ActiveBall
	TargetBouncer ActiveBall, 1
End Sub

Sub dSleeves_Hit(idx)
	SleevesD.Dampen ActiveBall
	TargetBouncer ActiveBall, 0.7
End Sub

Sub zCol_Rubber_LSling_Hit
	RubbersD.dampen ActiveBall
End Sub

Sub zCol_Rubber_RSling_Hit
	RubbersD.dampen ActiveBall
End Sub

Dim RubbersD				'frubber
Set RubbersD = New Dampener
RubbersD.name = "Rubbers"
RubbersD.debugOn = False	'shows info in textbox "TBPout"
RubbersD.Print = False	  'debug, reports In debugger (In vel, out cor); cor bounce curve (linear)

'for best results, try to match in-game velocity as closely as possible to the desired curve
'   RubbersD.addpoint 0, 0, 0.935   'point# (keep sequential), ballspeed, CoR (elasticity)
RubbersD.addpoint 0, 0, 1.1		 'point# (keep sequential), ballspeed, CoR (elasticity)
RubbersD.addpoint 1, 3.77, 0.97
RubbersD.addpoint 2, 5.76, 0.967	'dont take this as gospel. if you can data mine rubber elasticitiy, please help!
RubbersD.addpoint 3, 15.84, 0.874
RubbersD.addpoint 4, 56, 0.64	   'there's clamping so interpolate up to 56 at least

Dim SleevesD	'this is just rubber but cut down to 85%...
Set SleevesD = New Dampener
SleevesD.name = "Sleeves"
SleevesD.debugOn = False	'shows info in textbox "TBPout"
SleevesD.Print = False	  'debug, reports In debugger (In vel, out cor)
SleevesD.CopyCoef RubbersD, 0.85

'######################### Add new FlippersD Profile
'######################### Adjust these values to increase or lessen the elasticity

Dim FlippersD
Set FlippersD = New Dampener
FlippersD.name = "Flippers"
FlippersD.debugOn = False
FlippersD.Print = False
FlippersD.addpoint 0, 0, 1.1
FlippersD.addpoint 1, 3.77, 0.99
FlippersD.addpoint 2, 6, 0.99

Class Dampener
	Public Print, debugOn   'tbpOut.text
	Public name, Threshold  'Minimum threshold. Useful for Flippers, which don't have a hit threshold.
	Public ModIn, ModOut
	Private Sub Class_Initialize
		ReDim ModIn(0)
		ReDim Modout(0)
	End Sub
	
	Public Sub AddPoint(aIdx, aX, aY)
		ShuffleArrays ModIn, ModOut, 1
		ModIn(aIDX) = aX
		ModOut(aIDX) = aY
		ShuffleArrays ModIn, ModOut, 0
		If GameTime > 100 Then Report
	End Sub
	
	Public Sub Dampen(aBall)
		If threshold Then
			If BallSpeed(aBall) < threshold Then Exit Sub
		End If
		Dim RealCOR, DesiredCOR, str, coef
		DesiredCor = LinearEnvelope(cor.ballvel(aBall.id), ModIn, ModOut )
		RealCOR = BallSpeed(aBall) / (cor.ballvel(aBall.id) + 0.0001)
		coef = desiredcor / realcor
		If debugOn Then str = name & " In vel:" & Round(cor.ballvel(aBall.id),2 ) & vbNewLine & "desired cor: " & Round(desiredcor,4) & vbNewLine & _
		"actual cor: " & Round(realCOR,4) & vbNewLine & "ballspeed coef: " & Round(coef, 3) & vbNewLine
		If Print Then Debug.print Round(cor.ballvel(aBall.id),2) & ", " & Round(desiredcor,3)
		
		aBall.velx = aBall.velx * coef
		aBall.vely = aBall.vely * coef
		aBall.velz = aBall.velz * coef
		If debugOn Then TBPout.text = str
	End Sub
	
	Public Sub Dampenf(aBall, parm) 'Rubberizer is handle here
		Dim RealCOR, DesiredCOR, str, coef
		DesiredCor = LinearEnvelope(cor.ballvel(aBall.id), ModIn, ModOut )
		RealCOR = BallSpeed(aBall) / (cor.ballvel(aBall.id) + 0.0001)
		coef = desiredcor / realcor
		If Abs(aball.velx) < 2 And aball.vely < 0 And aball.vely >  - 3.75 Then
			aBall.velx = aBall.velx * coef
			aBall.vely = aBall.vely * coef
		End If
	End Sub
	
	Public Sub CopyCoef(aObj, aCoef) 'alternative addpoints, copy with coef
		Dim x
		For x = 0 To UBound(aObj.ModIn)
			addpoint x, aObj.ModIn(x), aObj.ModOut(x) * aCoef
		Next
	End Sub
	
	Public Sub Report() 'debug, reports all coords in tbPL.text
		If Not debugOn Then Exit Sub
		Dim a1, a2
		a1 = ModIn
		a2 = ModOut
		Dim str, x
		For x = 0 To UBound(a1)
			str = str & x & ": " & Round(a1(x),4) & ", " & Round(a2(x),4) & vbNewLine
		Next
		TBPout.text = str
	End Sub
End Class

'******************************************************
'  TRACK ALL BALL VELOCITIES
'  FOR RUBBER DAMPENER AND DROP TARGETS
'******************************************************

Dim cor
Set cor = New CoRTracker

Class CoRTracker
	Public ballvel, ballvelx, ballvely
	
	Private Sub Class_Initialize
		ReDim ballvel(0)
		ReDim ballvelx(0)
		ReDim ballvely(0)
	End Sub
	
	Public Sub Update()	'tracks in-ball-velocity
		Dim str, b, AllBalls, highestID
		allBalls = GetBalls
		
		For Each b In allballs
			If b.id >= HighestID Then highestID = b.id
		Next
		
		If UBound(ballvel) < highestID Then ReDim ballvel(highestID)	'set bounds
		If UBound(ballvelx) < highestID Then ReDim ballvelx(highestID)	'set bounds
		If UBound(ballvely) < highestID Then ReDim ballvely(highestID)	'set bounds
		
		For Each b In allballs
			ballvel(b.id) = BallSpeed(b)
			ballvelx(b.id) = b.velx
			ballvely(b.id) = b.vely
		Next
	End Sub
End Class

Sub RDampen
	Cor.Update
End Sub


'******************************************************
'****  END PHYSICS DAMPENERS
'******************************************************



'******************************************************
' 	ZBOU: VPW TargetBouncer for targets and posts by Iaakki, Wrd1972, Apophis
'******************************************************

Const TargetBouncerEnabled = 1	  '0 = normal standup targets, 1 = bouncy targets
Const TargetBouncerFactor = 0.9	 'Level of bounces. Recommmended value of 0.7-1

Sub TargetBouncer(aBall,defvalue)
	Dim zMultiplier, vel, vratio
	If TargetBouncerEnabled = 1 And aball.z < 30 Then
		'   debug.print "velx: " & aball.velx & " vely: " & aball.vely & " velz: " & aball.velz
		vel = BallSpeed(aBall)
		If aBall.velx = 0 Then vratio = 1 Else vratio = aBall.vely / aBall.velx
		Select Case Int(Rnd * 6) + 1
			Case 1
				zMultiplier = 0.2 * defvalue
			Case 2
				zMultiplier = 0.25 * defvalue
			Case 3
				zMultiplier = 0.3 * defvalue
			Case 4
				zMultiplier = 0.4 * defvalue
			Case 5
				zMultiplier = 0.45 * defvalue
			Case 6
				zMultiplier = 0.5 * defvalue
		End Select
		aBall.velz = Abs(vel * zMultiplier * TargetBouncerFactor)
		aBall.velx = Sgn(aBall.velx) * Sqr(Abs((vel ^ 2 - aBall.velz ^ 2) / (1 + vratio ^ 2)))
		aBall.vely = aBall.velx * vratio
		'   debug.print "---> velx: " & aball.velx & " vely: " & aball.vely & " velz: " & aball.velz
		'   debug.print "conservation check: " & BallSpeed(aBall)/vel
	End If
End Sub



'*****************
' Maths
'*****************


' VPW drives the CoR tracker from a dedicated 10 ms timer. Per the comment in
' the reference table: "The CorTimer interval should be 10. Its sole purpose
' is to update the Cor (physics) calculations."
CorTimer.Interval = 10
CorTimer.Enabled = True
Sub CorTimer_Timer() : Cor.Update : End Sub

' ---------------------------------------------------------------------------
'  module: scripts/50-ball-shadows.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZSHA: SHADOWS - flipper and ball shadows
'============================================================================
'
'  ninuzzu's flipper shadow v3 and ball shadow rig, as shipped with the blank
'  table. Kept because the shadow under the ball is a real depth cue when
'  judging a drop catch in VR.

'*****************************************
'	ninuzzu's	FLIPPER SHADOWS v3 (VPX 10.8)
'*****************************************

Sub LeftFlipper_Animate()
    FlipperLSh.RotZ = LeftFlipper.CurrentAngle
End Sub

Sub RightFlipper_Animate()
    FlipperRSh.RotZ = RightFlipper.CurrentAngle
End Sub

'*****************************************
'	ninuzzu's	BALL SHADOW
'*****************************************
Dim BallShadow
BallShadow = Array (BallShadow1,BallShadow2,BallShadow3,BallShadow4,BallShadow5)

Sub BallShadowUpdate_timer()
    Dim BOT, b
    BOT = GetBalls
    ' hide shadow of deleted balls
    If UBound(BOT)<(tnob-1) Then
        For b = (UBound(BOT) + 1) to (tnob-1)
            BallShadow(b).visible = 0
        Next
    End If
    ' exit the Sub if no balls on the table
    If UBound(BOT) = -1 Then Exit Sub
    ' render the shadow for each ball
    For b = 0 to UBound(BOT)
        'If BOT(b).X < Table1.Width/2 Then
        '    BallShadow(b).X = ((BOT(b).X) - (Ballsize/6) + ((BOT(b).X - (Table1.Width/2))/7)) + 6
        'Else
        '    BallShadow(b).X = ((BOT(b).X) + (Ballsize/6) + ((BOT(b).X - (Table1.Width/2))/7)) - 6
        'End If
		BallShadow(b).X = BOT(b).X + (BOT(b).X - (Table1.Width/2)) * 1.25 / BallSize
        BallShadow(b).Y = BOT(b).Y + 12
		BallShadow(b).Size_X = 5
		BallShadow(b).Size_Y = 5
        If BOT(b).Z > 20 Then
            BallShadow(b).visible = 1
        Else
            BallShadow(b).visible = 0
        End If
    Next
End Sub

' ---------------------------------------------------------------------------
'  module: scripts/60-feeder.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZFED: BALL DELIVERY SUBSYSTEM
'============================================================================
'
'  The single most important piece of engineering in the trainer. If the same
'  launch parameters do not produce the same pre-contact ball state, then
'  every drill above this layer is measuring the feeder instead of the player.
'
'  --- Why direct velocity, not a kicker ------------------------------------
'
'  Three delivery mechanisms were considered:
'
'    kicker      A kicker's exit carries its own angle and strength scatter,
'                and the ball settles into the kicker differently each time.
'                Visually honest, measurably worse.
'    chute/ramp  Every collision on the way down adds variance, and VPW's
'                default_scatter of 2.0 deliberately adds angular noise to
'                each one. Good realism, wrong tool.
'    direct      Create the ball at a fixed point and set its velocity
'                components explicitly. No intermediate collision, so the
'                only variance is whatever the config asks for.
'
'  Direct wins because the brief's priority is explicit: repeatability
'  outranks how the delivery looks. The ball still travels a real trajectory
'  under real physics from the launch point onward; only its birth is
'  synthetic, and the launch points are placed where a ball would plausibly
'  be travelling anyway (top of the inlane), not in mid-air over the
'  playfield.
'
'  --- What is NOT calibrated yet -------------------------------------------
'
'  The launch positions and velocities below are geometrically derived
'  starting points, not measured ones. They put the ball on a line that
'  reaches the middle-to-upper region of the raised flipper at a plausible
'  return speed. They have never been observed in VPX.
'
'  Calibrating them is the documented procedure in docs/tuning.md, and it is
'  deliberately a measurement, not a judgement: run a set at DIFF_FIXED, read
'  the pre-contact snapshots out of the log, and confirm the spread before
'  worrying about whether the numbers are realistic.
'
'============================================================================

' --- Feed profile ----------------------------------------------------------
'
' VBScript has no structs, so a small class carries a profile. One instance
' per (drill, side); difficulty scales the jitter rather than selecting a
' different profile, so every difficulty level shares one trajectory family.

Class FeedProfile
    Public Name
    Public LaunchX, LaunchY, LaunchZ      ' spawn point, vpu
    Public VelX, VelY, VelZ               ' initial velocity, vpu/tick
    Public JitterPos, JitterVel, JitterAng ' full-width bounds at difficulty 1

    Private Sub Class_Initialize()
        LaunchZ = BallSize          ' resting on the playfield, not dropped onto it
        VelZ = 0
        JitterPos = 0 : JitterVel = 0 : JitterAng = 0
    End Sub
End Class

' Difficulty scales the jitter bounds. Level 0 is exactly repeatable, which is
' what calibration and the beginner drop-catch drill both need.
Function FeedJitterScale(difficulty)
    Select Case difficulty
        Case DIFF_FIXED        : FeedJitterScale = 0.0
        Case DIFF_BEGINNER     : FeedJitterScale = 0.35
        Case DIFF_INTERMEDIATE : FeedJitterScale = 0.7
        Case DIFF_ADVANCED     : FeedJitterScale = 1.0
        Case Else              : FeedJitterScale = 0.0
    End Select
End Function

' --- Profiles --------------------------------------------------------------
'
' Launch points are taken from the table's own inlane triggers, which is
' where a returning ball actually travels:
'
'   LeftInlane   x 104..154   (centre 129)   y 1551..1589
'   RightInlane  x 718..768   (centre 743)   y 1552..1590
'
' Note these are NOT mirrored: the blank table's left inlane sits about 80 vpu
' further out than the mirror of the right one. Using each trigger's own
' centre rather than reflecting one about the centreline matters, and an
' earlier guess of x=690 for the right feed put the ball inside the slingshot,
' where it wedged and never reached the flipper.
'
' Target geometry for the right flipper:
'   flipper centre   (595.87, 1803.27), length 114, raised angle -70 deg
'   raised tip       (488.7, 1764.3)
'   60% contact pt   (531.6, 1779.9)   <- the middle-to-upper region wanted
'                                         for a drop catch

Dim FeedDropCatch(1)      ' indexed by SIDE_LEFT / SIDE_RIGHT

Sub InitFeedProfiles()
    Dim p

    Set p = New FeedProfile
    p.Name = "DropCatch.Right"
    ' In the right inlane, just below the trigger, rolling down it.
    p.LaunchX = 743 : p.LaunchY = 1600
    p.VelX = -1.0   : p.VelY = 10.0
    p.JitterPos = 12    ' vpu, full width
    p.JitterVel = 2.5   ' vpu/tick, full width
    p.JitterAng = 6     ' degrees, full width
    Set FeedDropCatch(SIDE_RIGHT) = p

    Set p = New FeedProfile
    p.Name = "DropCatch.Left"
    ' In the left inlane. Its own centre, not the mirror of the right one.
    p.LaunchX = 129 : p.LaunchY = 1600
    p.VelX = 1.0    : p.VelY = 10.0
    p.JitterPos = 12
    p.JitterVel = 2.5
    p.JitterAng = 6
    Set FeedDropCatch(SIDE_LEFT) = p
End Sub

InitFeedProfiles

' --- Feeder state ----------------------------------------------------------

Const FEED_IDLE     = 0
Const FEED_ARMING   = 4   ' ball created, waiting for the kicker to release it
Const FEED_INFLIGHT = 1   ' launched, not yet near the flipper
Const FEED_CONTACT  = 2   ' the flipper has been hit; reading the outcome
Const FEED_SETTLING = 3   ' contact happened, waiting to read the outcome

' The trainer, not the table's trough, decides when a ball exists. Without
' this the stock Drain_Hit auto-serves a replacement that races the next feed.
Dim FeederOwnsBalls : FeederOwnsBalls = True

' Physics frames to wait between creating a ball and teleporting it into
' position. A kicker's Kick is queued, not immediate: the ball is not free
' until the next physics step, and anything written to its position or
' velocity before then is silently discarded.
Const FEED_ARM_FRAMES = 8

' Contact is detected from the flipper's own Collide event, not from a
' proximity radius.
'
' The obvious-looking DistanceFromFlipper is NOT a proximity test: it returns
' the perpendicular distance to the flipper's infinite axis line, so a ball
' sitting far up the inlane reads as 85 vpu away and would trip any radius
' check immediately. Using it here produced a "pre-contact" snapshot two
' frames after launch, describing the launch rather than the approach.
'
' Instead the previous frame's state is kept continuously, and when the
' flipper reports a collision that stored sample IS the state immediately
' before contact, which is exactly what the drop-catch verdict needs.

' How long after contact to read the outgoing state, counted in PHYSICS
' FRAMES rather than milliseconds.
'
' Frames, not wall-clock, because the measurement has to mean the same thing
' at 60 Hz desktop, 90 Hz VR, and in VPX's -CaptureAttract mode, which runs
' the simulation as fast as the machine allows. A wall-clock window would
' cover a different amount of simulated travel in each.
' Three frames, not twenty. At twenty the ball has already fallen ~90 vpu
' further down a 6-degree playfield and gravity has re-accelerated it, so the
' "retained" ratio came out above 1.0 and looked like the flipper was adding
' energy. Three frames is enough for the collision to resolve and short
' enough that the reading is still about the interaction.
Const FEED_SETTLE_FRAMES = 3

Dim FeedState      : FeedState = FEED_IDLE
Dim FeedSide       : FeedSide = SIDE_RIGHT
Dim FeedBallObj    : Set FeedBallObj = Nothing
Dim FeedLaunchedAt, FeedContactAt
Dim FeedInSpeed, FeedInVelX, FeedInVelY, FeedInX, FeedInY
Dim PrevX, PrevY, PrevVX, PrevVY, PrevSpeed, PrevValid
PrevValid = False
Dim FeedSeq        : FeedSeq = 0
Dim FeedFrames     : FeedFrames = 0
Dim FeedArmFrames  : FeedArmFrames = 0
Dim PendX, PendY, PendZ, PendVX, PendVY, PendVZ, PendName

' Trace the ball's path while in flight, every N frames, so a feed that never
' reaches the flipper can be diagnosed from the log instead of by watching.
Const FEED_TRACE_EVERY = 30

' Give up on a feed that never arrives, so a calibration run cannot hang.
' Also in frames, for the same reason.
Const FEED_TIMEOUT_FRAMES = 600

Function FeedTargetFlipper()
    If FeedSide = SIDE_LEFT Then
        Set FeedTargetFlipper = LeftFlipper
    Else
        Set FeedTargetFlipper = RightFlipper
    End If
End Function

' --- Delivery --------------------------------------------------------------

' Removes any ball currently on the playfield. The trainer is single-ball
' except in the cradle-separation drill, so a feed always starts from a clean
' table rather than accumulating strays.
Sub FeederClear()
    Dim b, balls
    balls = GetBalls
    For b = 0 To UBound(balls)
        balls(b).DestroyBall   ' IBall exposes DestroyBall, not Destroy
    Next
    Set FeedBallObj = Nothing
    FeedState = FEED_IDLE
End Sub

' Launches one ball along the given profile.
'
' `difficulty` scales the randomisation; at DIFF_FIXED nothing is randomised
' and two calls with the same profile are identical.
Sub FeederLaunch(profile, side, difficulty)
    Dim s2, jx, jy, jv, ja, vx, vy, spd, ang

    FeedSide = side
    FeedSeq = FeedSeq + 1
    s2 = FeedJitterScale(difficulty)

    ' Rnd returns 0..1; (Rnd-0.5) gives a symmetric full-width band, so
    ' JitterPos really is the total spread rather than a one-sided offset.
    jx = (Rnd - 0.5) * profile.JitterPos * s2
    jy = (Rnd - 0.5) * profile.JitterPos * s2
    jv = (Rnd - 0.5) * profile.JitterVel * s2
    ja = (Rnd - 0.5) * profile.JitterAng * s2

    ' Speed and angle are perturbed rather than the components, so a jittered
    ' feed stays on a physically plausible trajectory family instead of
    ' drifting into directions the profile never intended.
    spd = Sqr(profile.VelX * profile.VelX + profile.VelY * profile.VelY) + jv
    ang = Atn2(profile.VelY, profile.VelX) + Radians(ja)

    PendName = profile.Name
    PendX = profile.LaunchX + jx : PendY = profile.LaunchY + jy : PendZ = profile.LaunchZ
    PendVX = spd * Cos(ang)      : PendVY = spd * Sin(ang)      : PendVZ = profile.VelZ

    FeederEnsureBall
    FeedArmFrames = 0
    FeedState = FEED_ARMING

    DebugLog "feed", "launch,seq=" & FeedSeq & ",profile=" & PendName & _
        ",side=" & side & ",difficulty=" & difficulty & _
        ",x=" & Round(PendX, 2) & ",y=" & Round(PendY, 2) & _
        ",vx=" & Round(PendVX, 3) & ",vy=" & Round(PendVY, 3) & _
        ",speed=" & Round(spd, 3) & ",jitterScale=" & s2
End Sub

' Guarantees exactly one ball exists, creating it only when there is none.
' Reusing a ball avoids the create/release dance on every single feed.
Sub FeederEnsureBall()
    Dim balls, i
    balls = GetBalls
    If UBound(balls) < 0 Then
        Set FeedBallObj = CreateBallAt()
    Else
        ' Keep the first, drop any strays so a feed is never ambiguous.
        For i = 1 To UBound(balls)
            balls(i).DestroyBall
        Next
        Set FeedBallObj = balls(0)
    End If
End Sub

' Teleports the (now free) ball onto the launch point and sets its velocity.
' This is the actual delivery: setting X/Y/Z and Vel* on a free ball is exact
' and repeatable in a way no kicker or chute can be.
Sub FeederPlaceAndRelease()
    ' Safe to disable now: the ball is free and nowhere near the kicker.
    BallSpawn.Enabled = False

    FeedBallObj.X = PendX   : FeedBallObj.Y = PendY   : FeedBallObj.Z = PendZ
    FeedBallObj.VelX = PendVX : FeedBallObj.VelY = PendVY : FeedBallObj.VelZ = PendVZ
    ' Angular velocity would otherwise carry over from the previous attempt.
    FeedBallObj.AngMomX = 0 : FeedBallObj.AngMomY = 0 : FeedBallObj.AngMomZ = 0

    FeedLaunchedAt = DebugNowMs()
    FeedFrames = 0
    FeedInSpeed = 0
    PrevValid = False
    FeedState = FEED_INFLIGHT
End Sub

' VPX has no "create a ball at an arbitrary point" call; a ball is born from a
' kicker. BallSpawn is an invisible kicker moved to the launch point first, so
' the ball appears exactly where the profile says.
'
' Two things here are easy to get wrong and both look identical from outside:
' the ball simply never moves.
'
'   1. Kick with strength 0 does NOT release the ball. The kicker keeps
'      holding it, and every subsequent VelX/VelY assignment is discarded
'      silently. The kick needs a non-zero strength purely to eject; the
'      velocity it imparts is overwritten on the next line, so its direction
'      and magnitude do not matter.
'   2. The kicker stays sitting at the launch point afterwards, so a later
'      ball rolling over it would be captured. It is disabled once the ball
'      is away and re-enabled only to create the next one.
' Creates a ball at BallSpawn's PARKED position, wherever that is. It does
' not move the kicker.
'
' Moving the kicker onto the launch point and then teleporting the ball to
' the same coordinates drops the ball straight back into the kicker's capture
' volume, where it is held forever. Velocity assignments on a captured ball
' are accepted and then ignored by physics, so the symptom is a ball frozen
' in place that nonetheless reports exactly the velocity you asked for.
'
' So: the kicker stays parked out of the way, and the ball is teleported to
' the launch point only once it is free.
Function CreateBallAt()
    BallSpawn.Enabled = True
    Set CreateBallAt = BallSpawn.CreateBall
    BallSpawn.Kick 0, 5          ' non-zero strength is what ejects it; Kick is
                                 ' queued for the next physics step, so the
                                 ' kicker must stay enabled until then.
End Function

' Convenience entry point used by the drills and by the debug keys.
Sub FeedDropCatchTo(side, difficulty)
    FeederLaunch FeedDropCatch(side), side, difficulty
End Sub

' --- Measurement -----------------------------------------------------------
'
' Called once per rendered frame from PhysicsFrameTimer. Watches the fed ball
' and records the two snapshots that every drop-catch and live-catch verdict
' will be built from.
'
' This is deliberately observation only. Nothing here alters the ball: the
' trainer must never make an attempt succeed. See docs/drill-design.md.

Sub FeederUpdate()
    Dim spd, flip

    If FeedState = FEED_IDLE Then Exit Sub
    If FeedState = FEED_SETTLING Then Exit Sub
    If FeedBallObj Is Nothing Then Exit Sub

    Set flip = FeedTargetFlipper()
    spd = Sqr(FeedBallObj.VelX * FeedBallObj.VelX + FeedBallObj.VelY * FeedBallObj.VelY)

    Select Case FeedState

        Case FEED_ARMING
            FeedArmFrames = FeedArmFrames + 1
            If FeedArmFrames >= FEED_ARM_FRAMES Then FeederPlaceAndRelease

        Case FEED_INFLIGHT
            FeedFrames = FeedFrames + 1

            If (FeedFrames Mod FEED_TRACE_EVERY) = 0 Then
                DebugLog "feed", "trace,seq=" & FeedSeq & ",f=" & FeedFrames & _
                    ",x=" & Round(FeedBallObj.X, 1) & ",y=" & Round(FeedBallObj.Y, 1) & _
                    ",z=" & Round(FeedBallObj.Z, 1) & _
                    ",vx=" & Round(FeedBallObj.VelX, 2) & ",vy=" & Round(FeedBallObj.VelY, 2) & _
                    ",speed=" & Round(spd, 2)
            End If

            ' The ball drained without ever reaching the flipper. That is a
            ' legitimate outcome of an attempt, not an error.
            If UBound(GetBalls) < 0 Then
                DebugLog "feed", "drained,seq=" & FeedSeq & ",noContact,f=" & FeedFrames
                FeedState = FEED_SETTLING
                FeederCalibrateStep
                Exit Sub
            End If

            If FeedFrames > FEED_TIMEOUT_FRAMES Then
                DebugLog "feed", "TIMEOUT,seq=" & FeedSeq & _
                    ",lastX=" & Round(FeedBallObj.X, 1) & ",lastY=" & Round(FeedBallObj.Y, 1) & _
                    ",speed=" & Round(spd, 2) & ",balls=" & (UBound(GetBalls) + 1)
                FeedState = FEED_SETTLING
                FeederCalibrateStep
                Exit Sub
            End If

            ' Roll the one-frame-old sample forward. This is what becomes the
            ' pre-contact reading the instant the flipper reports a hit.
            PrevX = FeedBallObj.X       : PrevY = FeedBallObj.Y
            PrevVX = FeedBallObj.VelX   : PrevVY = FeedBallObj.VelY
            PrevSpeed = spd             : PrevValid = True

        Case FEED_CONTACT
            FeedFrames = FeedFrames + 1
            If FeedFrames - FeedContactAt >= FEED_SETTLE_FRAMES Then
                FeedState = FEED_SETTLING
                DebugLog "feed", "postcontact,seq=" & FeedSeq & _
                    ",x=" & Round(FeedBallObj.X, 2) & ",y=" & Round(FeedBallObj.Y, 2) & _
                    ",vx=" & Round(FeedBallObj.VelX, 3) & ",vy=" & Round(FeedBallObj.VelY, 3) & _
                    ",speed=" & Round(spd, 3) & _
                    ",inSpeed=" & Round(FeedInSpeed, 3) & _
                    ",retained=" & Round(SafeRatio(spd, FeedInSpeed), 4) & _
                    ",flipperAngle=" & Round(flip.CurrentAngle, 2)
                FeederCalibrateStep
            End If

    End Select
End Sub

' Called from LeftFlipper_Collide / RightFlipper_Collide. The stored previous
' frame is the state immediately before the flipper touched the ball.
Sub FeederNoteFlipperContact(flipper)
    If FeedState <> FEED_INFLIGHT Then Exit Sub
    If Not PrevValid Then Exit Sub

    FeedInX = PrevX     : FeedInY = PrevY
    FeedInVelX = PrevVX : FeedInVelY = PrevVY
    FeedInSpeed = PrevSpeed
    FeedContactAt = FeedFrames
    FeedState = FEED_CONTACT

    DebugLog "feed", "precontact,seq=" & FeedSeq & _
        ",x=" & Round(FeedInX, 2) & ",y=" & Round(FeedInY, 2) & _
        ",vx=" & Round(FeedInVelX, 3) & ",vy=" & Round(FeedInVelY, 3) & _
        ",speed=" & Round(FeedInSpeed, 3) & _
        ",flipperAngle=" & Round(flipper.CurrentAngle, 2) & _
        ",flightFrames=" & FeedFrames
End Sub

Function SafeRatio(a, b)
    If b = 0 Then SafeRatio = 0 Else SafeRatio = a / b
End Function

' --- Calibration harness ---------------------------------------------------
'
' Runs N fixed feeds back to back and reports the spread. This is the
' objective test that the feeder is repeatable, and it needs no human
' judgement: if the standard deviation of the pre-contact speed is not small,
' the delivery mechanism is wrong and no amount of velocity tuning will help.

Dim CalRunsLeft, CalSide, CalSamples, CalCount, CalX, CalY, CalOut, CalMiss
CalRunsLeft = 0 : CalCount = 0 : CalMiss = 0
ReDim CalSamples(63) : ReDim CalX(63) : ReDim CalY(63) : ReDim CalOut(63)

Sub FeederCalibrate(side, runs)
    CalSide = side
    CalRunsLeft = runs
    CalCount = 0
    CalMiss = 0
    DebugLog "calib", "start,side=" & side & ",runs=" & runs & ",physics=" & PhysicsSignature()
    FeedDropCatchTo CalSide, DIFF_FIXED
End Sub

' Advances the calibration run. Called when a fed ball has finished settling.
Sub FeederCalibrateStep()
    If CalRunsLeft <= 0 Then Exit Sub

    If FeedInSpeed > 0 And CalCount <= UBound(CalSamples) Then
        CalSamples(CalCount) = FeedInSpeed
        CalX(CalCount) = FeedInX
        CalY(CalCount) = FeedInY
        CalOut(CalCount) = SafeRatio(Sqr(FeedBallObj.VelX * FeedBallObj.VelX + _
                                          FeedBallObj.VelY * FeedBallObj.VelY), FeedInSpeed)
        CalCount = CalCount + 1
    Else
        ' Feeds that never reached the flipper are counted, not silently
        ' dropped: a feed that misses half the time is not a usable feed.
        CalMiss = CalMiss + 1
    End If

    CalRunsLeft = CalRunsLeft - 1
    If CalRunsLeft > 0 Then
        FeedDropCatchTo CalSide, DIFF_FIXED
    Else
        FeederCalibrateReport
    End If
End Sub

Sub FeederCalibrateReport()
    If CalCount = 0 Then
        DebugLog "calib", "report,NO SAMPLES,misses=" & CalMiss
        Exit Sub
    End If

    DebugLog "calib", "report,n=" & CalCount & ",misses=" & CalMiss & _
        "," & StatLine("inSpeed", CalSamples, CalCount) & _
        "," & StatLine("contactX", CalX, CalCount) & _
        "," & StatLine("contactY", CalY, CalCount) & _
        "," & StatLine("retained", CalOut, CalCount)
End Sub

' mean / sd / spread for one sampled quantity, as one CSV fragment.
Function StatLine(name, arr, n)
    Dim i, sum, mean, sd, lo, hi
    sum = 0 : lo = arr(0) : hi = arr(0)
    For i = 0 To n - 1
        sum = sum + arr(i)
        If arr(i) < lo Then lo = arr(i)
        If arr(i) > hi Then hi = arr(i)
    Next
    mean = sum / n

    sum = 0
    For i = 0 To n - 1
        sum = sum + (arr(i) - mean) * (arr(i) - mean)
    Next
    sd = Sqr(sum / n)

    StatLine = name & "Mean=" & Round(mean, 4) & _
               "," & name & "Sd=" & Round(sd, 4) & _
               "," & name & "Spread=" & Round(hi - lo, 4)
End Function

' ---------------------------------------------------------------------------
'  module: scripts/90-training-input.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZINP: TRAINING INPUT - drill control keys
'============================================================================
'
'  These handlers are called from Table1_KeyDown / Table1_KeyUp in
'  20-table-core.vbs BEFORE the standard bindings, and they never consume a
'  key. Flippers, plunger, nudge and tilt keep working exactly as they do on
'  any other table - a trainer that changed the controls would train the
'  wrong reflexes.
'
'  Keys are matched on raw DirectInput scancodes rather than on the VPX key
'  constants, because the constants (StartGameKey and friends) are
'  user-remappable and the drill controls need to be stable.
'
'  See docs/controls.md for the full binding table.
'
'============================================================================

Const KEY_1 = 2    ' start / restart the current drill
Const KEY_2 = 3    ' next drill
Const KEY_3 = 4    ' previous drill
Const KEY_4 = 5    ' increase difficulty
Const KEY_5 = 6    ' decrease difficulty
Const KEY_R = 19   ' reset the current drill
Const KEY_D = 32   ' toggle debug mode
Const KEY_F = 33   ' feed one ball to the right flipper
Const KEY_G = 34   ' feed one ball to the left flipper
Const KEY_C = 46   ' run a 20-feed repeatability calibration

Sub TrainingKeyDown(ByVal keycode)
    Select Case keycode
        Case KEY_D
            DebugToggle

        ' Feeder keys. These exist so the delivery system can be calibrated
        ' before any drill is built on it; the drill layer will drive the same
        ' entry points. See docs/tuning.md.
        Case KEY_F
            FeedDropCatchTo SIDE_RIGHT, CurrentDifficulty()

        Case KEY_G
            FeedDropCatchTo SIDE_LEFT, CurrentDifficulty()

        Case KEY_C
            FeederCalibrate SIDE_RIGHT, 20

        Case KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_R
            ' Drill selection, difficulty and reset arrive with the drill
            ' state machine in milestone 4. Logging the press now means the
            ' binding can be confirmed on the real table before then.
            DebugLog "input", "unbound drill key scancode=" & keycode

    End Select
End Sub

Sub TrainingKeyUp(ByVal keycode)
    ' No trainer control needs key-up yet. The hook exists so that drills
    ' needing a held key (for example a cradle-hold check) have somewhere to
    ' live without editing the core input module again.
End Sub

' Difficulty, falling back to the fully repeatable feed if the options have
' not initialised yet. A key press before OptionEvent(0) would otherwise read
' an empty variant and silently jitter the feed.
Function CurrentDifficulty()
    If OptionsReady Then
        CurrentDifficulty = OptDifficulty
    Else
        CurrentDifficulty = DIFF_FIXED
    End If
End Function

' ---------------------------------------------------------------------------
'  module: scripts/95-debug.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZDBG: DEBUG AND LOGGING
'============================================================================
'
'  VPX gives a script no console and no reliable file handle, so "logging"
'  here means an in-memory ring buffer that the debug overlay renders and
'  that an export step can later drain. Every diagnostic in this project goes
'  through DebugLog so that swapping the sink for real CSV output is a
'  one-function change rather than a search-and-replace.
'
'  Log lines are CSV-shaped from the start:
'    <ms since load>,<category>,<message>
'  Drill code appends its own comma-separated fields to <message>, which is
'  what makes the buffer directly exportable as the training log described in
'  docs/tuning.md.
'
'============================================================================

Dim DebugEnabled
DebugEnabled = DEBUG_DEFAULT_ON

Dim DebugLogBuf      ' ring buffer of formatted lines
Dim DebugLogHead     ' index of the next slot to write
Dim DebugLogCount    ' total lines ever written (not the buffer length)
ReDim DebugLogBuf(DEBUG_LOG_CAPACITY - 1)
DebugLogHead = 0
DebugLogCount = 0

' Milliseconds since the table was loaded. GetTickCount is not exposed to
' VPX script, so the baseline is captured once at load and subtracted.
Dim DebugEpochMs
DebugEpochMs = Timer * 1000

Function DebugNowMs()
    Dim t : t = Timer * 1000 - DebugEpochMs
    ' Timer resets at midnight; a negative delta means we rolled over, so
    ' add a day's worth of milliseconds rather than logging a negative time.
    If t < 0 Then t = t + 86400000
    DebugNowMs = Int(t)
End Function

' Record one diagnostic line. Always records, even when the overlay is off,
' so that turning debug on mid-session still shows recent history.
Sub DebugLog(category, message)
    Dim line
    line = DebugNowMs() & "," & category & "," & message

    DebugLogBuf(DebugLogHead) = line
    DebugLogHead = (DebugLogHead + 1) Mod DEBUG_LOG_CAPACITY
    DebugLogCount = DebugLogCount + 1

    ' Persist to the VPX log file. Prefixed so a session can be pulled back
    ' out of a log that also contains VPX's own chatter:
    '   grep "TILTLAB," vpinball.log | sed 's/.*TILTLAB,//' > session.csv
    If DEBUG_MIRROR_TO_VPX_LOG Then Debug.Print "TILTLAB," & line
End Sub

' Returns the buffered lines oldest-first, newline separated.
' `maxLines` caps the result; pass 0 for everything still buffered.
Function DebugLogDump(maxLines)
    Dim have, i, idx, out, startAt
    If DebugLogCount < DEBUG_LOG_CAPACITY Then have = DebugLogCount Else have = DEBUG_LOG_CAPACITY
    If maxLines > 0 And maxLines < have Then startAt = have - maxLines Else startAt = 0

    out = ""
    For i = startAt To have - 1
        ' Oldest live entry sits just past the head once the buffer has wrapped.
        idx = (DebugLogHead - have + i + DEBUG_LOG_CAPACITY) Mod DEBUG_LOG_CAPACITY
        out = out & DebugLogBuf(idx) & vbNewLine
    Next
    DebugLogDump = out
End Function

Sub DebugToggle()
    DebugEnabled = Not DebugEnabled
    DebugLog "debug", "enabled=" & CStr(DebugEnabled)
    DebugRender
End Sub

' Paints the most recent lines onto the desktop score text.
'
' LIMITATION: this is a desktop-only view. A flat TextBox renders in front of
' the playfield in VR and reads as a rendering artefact, so in VR the buffer
' is currently collected but not displayed. The VR-safe overlay lands with the
' training display in milestone 4.
Sub DebugRender()
    If Not DesktopMode Then Exit Sub
    If DebugEnabled Then
        ScoreText.Visible = True
        ScoreText.Text = DebugLogDump(12)
    Else
        ScoreText.Text = ""
        ScoreText.Visible = False
    End If
End Sub

' Snapshot of one ball's state. Called from drill code around the moments
' that matter (just before flipper contact, just after) so that trajectories
' can be tuned against recorded numbers instead of impressions.
Sub DebugLogBall(tag, b)
    If b Is Nothing Then Exit Sub
    DebugLog "ball", tag & _
        ",x=" & Round(b.X, 2) & ",y=" & Round(b.Y, 2) & ",z=" & Round(b.Z, 2) & _
        ",vx=" & Round(b.VelX, 3) & ",vy=" & Round(b.VelY, 3) & ",vz=" & Round(b.VelZ, 3) & _
        ",speed=" & Round(Sqr(b.VelX * b.VelX + b.VelY * b.VelY), 3)
End Sub

' ---------------------------------------------------------------------------
'  module: scripts/99-boot.vbs
' ---------------------------------------------------------------------------
'============================================================================
'  ZBOO: BOOT - init and exit wiring. This module is assembled last.
'============================================================================
'
'  Everything above declares; this runs. Keeping the wiring in one terminal
'  module means the startup order is readable in a single place rather than
'  scattered across whichever module happened to be concatenated first.
'
'============================================================================

' --- Self-test hook --------------------------------------------------------
'
' VPX passes -c1..-c9 through to GetCustomParam(n). Launching with
'
'     VPinballX_BGFX64.exe -c1 calib -Play "Pinball Training Lab.vpx"
'
' makes the table run its own feeder repeatability check and write the result
' to the log, with no keyboard and no human. That is what lets T3 be verified
' from a script rather than from a chair.
Dim SelfTest
SelfTest = ""
On Error Resume Next
SelfTest = LCase(CStr(GetCustomParam(1)))
On Error Goto 0

Dim SelfTestArmed
SelfTestArmed = (SelfTest <> "")

' Frames to wait before firing. The first frames are busy with table setup,
' and a ball created during them behaves unrepresentatively.
Const SELFTEST_DELAY_FRAMES = 120
Dim SelfTestFrames
SelfTestFrames = 0

Sub SelfTestTick()
    If Not SelfTestArmed Then Exit Sub
    SelfTestFrames = SelfTestFrames + 1
    If SelfTestFrames < SELFTEST_DELAY_FRAMES Then Exit Sub

    SelfTestArmed = False
    DebugLog "selftest", "mode=" & SelfTest

    Select Case SelfTest
        Case "calib"
            FeederCalibrate SIDE_RIGHT, 20
        Case "calibleft"
            FeederCalibrate SIDE_LEFT, 20
        Case "feed"
            FeedDropCatchTo SIDE_RIGHT, DIFF_FIXED

        ' Discriminating probe: drop a ball in open playfield with zero
        ' velocity. If it falls, physics is live and any stuck feed is a
        ' geometry problem at the launch point. If it does not, physics is
        ' not stepping and nothing about the feeder is to blame.
        Case "probe"
            ProbeDropBall
        Case Else
            DebugLog "selftest", "unknown mode,ignored"
    End Select
End Sub

Sub Table1_Init()
    DebugLog "boot", "Tilt Lab loading"
    DebugLog "boot", "renderingMode=" & RenderingMode & ",desktop=" & CStr(DesktopMode) & ",vr=" & CStr(VRMode)
    DebugLog "boot", "table=" & Table1.Width & "x" & Table1.Height

    ' Physics integrity first: a Global Physics Set silently invalidates the
    ' whole nFozzy stack, and everything after this point assumes it is off.
    AssertNoGlobalPhysics
    AssertPhysicsProfile

    DebugRender

    DebugLog "boot", "ready,physics=" & PhysicsSignature()
End Sub

Sub Table1_Exit()
    DebugLog "boot", "exiting"
End Sub


' --- Physics liveness probe ------------------------------------------------

Dim ProbeBall, ProbeFrames, ProbeActive
ProbeActive = False : ProbeFrames = 0

Sub ProbeDropBall()
    Dim balls, i
    balls = GetBalls
    For i = 0 To UBound(balls)
        balls(i).DestroyBall
    Next

    BallSpawn.Enabled = True
    Set ProbeBall = BallSpawn.CreateBall
    BallSpawn.Kick 0, 5
    ProbeFrames = 0
    ProbeActive = True
    DebugLog "probe", "created at kicker park point (" & BallSpawn.X & "," & BallSpawn.Y & ")"
End Sub

Sub ProbeTick()
    If Not ProbeActive Then Exit Sub
    ProbeFrames = ProbeFrames + 1

    ' Let it leave the kicker, then teleport to dead centre of an empty area
    ' of playfield with NO velocity at all, and watch whether gravity works.
    If ProbeFrames = 10 Then
        BallSpawn.Enabled = False
        ProbeBall.X = 476 : ProbeBall.Y = 900 : ProbeBall.Z = BallSize
        ProbeBall.VelX = 0 : ProbeBall.VelY = 0 : ProbeBall.VelZ = 0
        DebugLog "probe", "placed at 476,900 with zero velocity"
    End If

    If ProbeFrames > 10 And (ProbeFrames Mod 30) = 0 And ProbeFrames < 700 Then
        DebugLog "probe", "f=" & ProbeFrames & _
            ",x=" & Round(ProbeBall.X, 1) & ",y=" & Round(ProbeBall.Y, 1) & _
            ",z=" & Round(ProbeBall.Z, 1) & _
            ",vx=" & Round(ProbeBall.VelX, 2) & ",vy=" & Round(ProbeBall.VelY, 2)
    End If
End Sub

