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
'    10-config.vbs        ZCFG  every tunable value, in one place
'    15-options.vbs       ZOPT  VR-navigable drill selector (Table1.Option)
'    20-table-core.vbs    ZCOR  input, trough, slingshots, GI
'    30-sound.vbs         ZSND  positional playback, rolling, impacts
'    50-ball-shadows.vbs  ZSHA  flipper and ball shadows
'    90-training-input.vbs ZINP drill control keys (desktop mirror)
'    95-debug.vbs         ZDBG  debug overlay and structured logging
'    99-boot.vbs          ZBOO  init / exit wiring, runs last
'
'  Modules still to come (see TODO.md):
'    40-physics-nfozzy    nFozzy flipper corrections           (milestone 2)
'    45-physics-damping   rubber dampeners, target bouncer     (milestone 2)
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

Const DEFAULT_DIFFICULTY = DIFF_FIXED

' Which flipper a drill feeds.
Const SIDE_LEFT        = 0
Const SIDE_RIGHT       = 1
Const SIDE_ALTERNATING = 2

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

    OptDrill = CInt(Table1.Option("Drill", 0, 8, 1, 0, 0, DRILL_NAMES))

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
    OptResetDelayMs = CInt(Table1.Option("Reset Delay", 0.4, 3.0, 0.1, 1.2, 0, Empty) * 1000)

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

	If keycode = LeftFlipperKey Then
		LeftFlipper.RotateToEnd
		PlaySound SoundFX("fx_flipperup",DOFFlippers), 0, .67, AudioPan(LeftFlipper), 0.05,0,0,1,AudioFade(LeftFlipper)
	End If

	If keycode = RightFlipperKey Then
		RightFlipper.RotateToEnd
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
		LeftFlipper.RotateToStart
		PlaySound SoundFX("fx_flipperdown",DOFFlippers), 0, 1, AudioPan(LeftFlipper), 0.05,0,0,1,AudioFade(LeftFlipper)
	End If

	If keycode = RightFlipperKey Then
		RightFlipper.RotateToStart
		PlaySound SoundFX("fx_flipperdown",DOFFlippers), 0, 1, AudioPan(RightFlipper), 0.05,0,0,1,AudioFade(RightFlipper)
	End If
End Sub


Sub Drain_Hit()
	PlaySound "drain",0,1,AudioPan(Drain),0.25,0,0,1,AudioFade(Drain)
	Drain.DestroyBall
	BIP = BIP - 1
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

Sub OnBallBallCollision(ball1, ball2, velocity)
	PlaySound("fx_collide"), 0, Csng(velocity) ^2 / 2000, AudioPan(ball1), 0, Pitch(ball1), 0, 0, AudioFade(ball1)
End Sub



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

Sub LeftFlipper_Collide(parm)
 	RandomSoundFlipper()
End Sub

Sub RightFlipper_Collide(parm)
 	RandomSoundFlipper()
End Sub

Sub RandomSoundFlipper()
	Select Case Int(Rnd*3)+1
		Case 1 : PlaySound "flip_hit_1", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
		Case 2 : PlaySound "flip_hit_2", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
		Case 3 : PlaySound "flip_hit_3", 0, Vol(ActiveBall), AudioPan(ActiveBall), 0, Pitch(ActiveBall), 1, 0, AudioFade(ActiveBall)
	End Select
End Sub

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

Sub TrainingKeyDown(ByVal keycode)
    Select Case keycode
        Case KEY_D
            DebugToggle

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
    DebugLogBuf(DebugLogHead) = DebugNowMs() & "," & category & "," & message
    DebugLogHead = (DebugLogHead + 1) Mod DEBUG_LOG_CAPACITY
    DebugLogCount = DebugLogCount + 1
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

Sub Table1_Init()
    DebugLog "boot", "Tilt Lab loading"
    DebugLog "boot", "renderingMode=" & RenderingMode & ",desktop=" & CStr(DesktopMode) & ",vr=" & CStr(VRMode)
    DebugLog "boot", "table=" & Table1.Width & "x" & Table1.Height

    DebugRender

    DebugLog "boot", "ready"
End Sub

Sub Table1_Exit()
    DebugLog "boot", "exiting"
End Sub

