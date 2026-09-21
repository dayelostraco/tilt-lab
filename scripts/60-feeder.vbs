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
Dim FeedCradle(1)         ' slow, short-run feed for cradle testing

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

    ' --- Cradle feed -------------------------------------------------------
    '
    ' Deliberately NOT the inlane feed. A ball launched at the top of the
    ' inlane arrives at the flipper doing 6.3 vpu/frame even when launched at
    ' 3.0, because a 6-degree slope has 200 vpu to work with. At that speed it
    ' bounces off a raised flipper and back up the playfield, which is correct
    ' physics and the wrong test.
    '
    ' A cradle needs the ball to arrive slowly, so it starts close to the
    ' flipper with almost no initial speed and lets gravity do the rest.
    Set p = New FeedProfile
    p.Name = "Cradle.Right"
    p.LaunchX = 632 : p.LaunchY = 1700
    p.VelX = 0      : p.VelY = 1.0
    Set FeedCradle(SIDE_RIGHT) = p

    Set p = New FeedProfile
    p.Name = "Cradle.Left"
    p.LaunchX = 240 : p.LaunchY = 1700
    p.VelX = 0      : p.VelY = 1.0
    Set FeedCradle(SIDE_LEFT) = p
End Sub

InitFeedProfiles

' --- Feeder state ----------------------------------------------------------

Const FEED_IDLE     = 0
Const FEED_ARMING   = 4   ' ball created, waiting for the kicker to release it
Const FEED_INFLIGHT = 1   ' launched, not yet near the flipper
Const FEED_CONTACT  = 2   ' the flipper has been hit; reading the rebound
Const FEED_CONTROL  = 5   ' rebound read; waiting to see if it settled
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

' A second, later sample. Three frames after contact measures the REBOUND:
' how much speed survived the collision itself. That is the right number for
' a dead bounce, and the wrong one for a catch.
'
' A catch is not "did the ball leave slowly", it is "did the ball end up under
' control". That needs looking well after the interaction, once the ball has
' either settled onto the flipper or run away from it. Both numbers are
' recorded because the drills need different ones.
Const FEED_CONTROL_FRAMES = 45

Dim FeedState      : FeedState = FEED_IDLE
Dim FeedSide       : FeedSide = SIDE_RIGHT
Dim FeedBallObj    : Set FeedBallObj = Nothing
Dim FeedLaunchedAt, FeedContactAt
Dim FeedInSpeed, FeedInVelX, FeedInVelY, FeedInX, FeedInY
Dim FeedReboundSpeed, FeedControlSpeed, FeedControlDist
Dim PrevX, PrevY, PrevVX, PrevVY, PrevSpeed, PrevValid
PrevValid = False
Dim FeedSeq        : FeedSeq = 0

' Who gets told when a feed finishes: "calib", "valid", or "" for nobody.
' A feed always reports to exactly one owner, so a calibration run and a
' validation sweep can never interleave and corrupt each other's samples.
Dim FeedOwner : FeedOwner = ""

' Flipper actuation scheduled relative to launch, in physics frames.
' -1 means "do nothing". This is what lets a drill or a validation sweep
' press and release the flipper at a repeatable moment without a human.
Dim FeedPressAtFrame, FeedReleaseAtFrame
FeedPressAtFrame = -1 : FeedReleaseAtFrame = -1

' Optional override of the profile's launch speed, for calibration sweeps.
' 0 means "use the profile". Kept out of the profile itself so a sweep can
' never accidentally become the committed value.
Dim FeedSpeedOverride : FeedSpeedOverride = 0
Dim FeedFrames     : FeedFrames = 0
Dim FeedArmFrames  : FeedArmFrames = 0
Dim PendX, PendY, PendZ, PendVX, PendVY, PendVZ, PendName

' Trace the ball's path while in flight, every N frames, so a feed that never
' reaches the flipper can be diagnosed from the log instead of by watching.
Const FEED_TRACE_EVERY = 30

' Soft-contact fallback.
'
' Contact is normally taken from the flipper's Collide event, which is exact.
' But a slow ball rolling gently onto a flipper may never generate a
' collision at all: the cradle drill recorded five attempts with every
' measurement zero because nothing ever fired.
'
' So if the ball gets within touching distance of the flipper's SURFACE and
' is moving slowly, that counts as contact too.
'
' It has to be distance to the flipper's line segment, not to its pivot. A
' pivot-based radius of 140 (length plus a ball) is satisfied by the cradle
' feed's own launch point, which sits 109 vpu from the pivot: every attempt
' registered contact on frame 2, before the ball had moved.
Const FEED_SOFT_RADIUS = 42     ' ball radius 25 + flipper end radius ~12
Const FEED_SOFT_SPEED  = 2.5
Const FEED_SOFT_MIN_FRAMES = 10 ' never in the first frames after launch

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
    If FeedSpeedOverride > 0 Then spd = FeedSpeedOverride
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

' Schedules flipper actuation for the feed about to be launched.
'   pressAt   frame (from launch) to raise the target flipper, -1 for never
'   releaseAt frame to drop it again, -1 for never
' A drop catch is press at 0 (already up before the ball arrives) and release
' at contact; a live catch is press at contact with no release.
Sub FeedScheduleFlipper(pressAt, releaseAt)
    FeedPressAtFrame = pressAt
    FeedReleaseAtFrame = releaseAt
End Sub

Sub FeedActuate()
    Dim flip
    Set flip = FeedTargetFlipper()
    If FeedFrames = FeedPressAtFrame Then
        FlipperUp FeedSide
        DebugLog "act", "press,seq=" & FeedSeq & ",f=" & FeedFrames
    End If
    If FeedFrames = FeedReleaseAtFrame Then
        FlipperDown FeedSide
        DebugLog "act", "release,seq=" & FeedSeq & ",f=" & FeedFrames & _
            ",angle=" & Round(flip.CurrentAngle, 2)
    End If
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

Sub FeedCradleTo(side, difficulty)
    FeederLaunch FeedCradle(side), side, difficulty
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
            FeedActuate

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
                FeedNotifyComplete
                Exit Sub
            End If

            If FeedFrames > FEED_TIMEOUT_FRAMES Then
                DebugLog "feed", "TIMEOUT,seq=" & FeedSeq & _
                    ",lastX=" & Round(FeedBallObj.X, 1) & ",lastY=" & Round(FeedBallObj.Y, 1) & _
                    ",speed=" & Round(spd, 2) & ",balls=" & (UBound(GetBalls) + 1)
                FeedState = FEED_SETTLING
                FeedNotifyComplete
                Exit Sub
            End If

            ' Soft contact: close to the flipper and barely moving. Checked
            ' before the sample rolls forward so the reading describes the
            ' approach rather than the already-stopped ball.
            If spd <= FEED_SOFT_SPEED And PrevValid And FeedFrames >= FEED_SOFT_MIN_FRAMES Then
                If DistanceToFlipperSurface(FeedBallObj.X, FeedBallObj.Y, flip) <= FEED_SOFT_RADIUS Then
                    DebugLog "feed", "softcontact,seq=" & FeedSeq & ",f=" & FeedFrames
                    FeederNoteFlipperContact flip
                    Exit Sub
                End If
            End If

            ' Roll the one-frame-old sample forward. This is what becomes the
            ' pre-contact reading the instant the flipper reports a hit.
            PrevX = FeedBallObj.X       : PrevY = FeedBallObj.Y
            PrevVX = FeedBallObj.VelX   : PrevVY = FeedBallObj.VelY
            PrevSpeed = spd             : PrevValid = True

        Case FEED_CONTACT
            FeedFrames = FeedFrames + 1
            FeedActuate
            If FeedFrames - FeedContactAt >= FEED_SETTLE_FRAMES Then
                FeedReboundSpeed = spd
                FeedState = FEED_CONTROL
                DebugLog "feed", "rebound,seq=" & FeedSeq & _
                    ",x=" & Round(FeedBallObj.X, 2) & ",y=" & Round(FeedBallObj.Y, 2) & _
                    ",vx=" & Round(FeedBallObj.VelX, 3) & ",vy=" & Round(FeedBallObj.VelY, 3) & _
                    ",speed=" & Round(spd, 3) & _
                    ",inSpeed=" & Round(FeedInSpeed, 3) & _
                    ",retained=" & Round(SafeRatio(spd, FeedInSpeed), 4) & _
                    ",flipperAngle=" & Round(flip.CurrentAngle, 2)
            End If

        Case FEED_CONTROL
            FeedFrames = FeedFrames + 1
            FeedActuate

            ' The ball drained while we waited: an uncontrolled outcome, and
            ' a legitimate result for the drill to record.
            If UBound(GetBalls) < 0 Then
                FeedControlSpeed = -1 : FeedControlDist = -1
                DebugLog "feed", "control,seq=" & FeedSeq & ",DRAINED"
                FeedState = FEED_SETTLING
                FeedNotifyComplete
                Exit Sub
            End If

            If FeedFrames - FeedContactAt >= FEED_CONTROL_FRAMES Then
                FeedControlSpeed = spd
                FeedControlDist = Distance(FeedBallObj.X, FeedBallObj.Y, flip.X, flip.Y)
                FeedState = FEED_SETTLING
                DebugLog "feed", "control,seq=" & FeedSeq & _
                    ",x=" & Round(FeedBallObj.X, 1) & ",y=" & Round(FeedBallObj.Y, 1) & _
                    ",speed=" & Round(FeedControlSpeed, 3) & _
                    ",distFromFlipperBase=" & Round(FeedControlDist, 1) & _
                    ",inSpeed=" & Round(FeedInSpeed, 3) & _
                    ",killed=" & Round(1 - SafeRatio(FeedControlSpeed, FeedInSpeed), 4)
                FeedNotifyComplete
            End If

    End Select
End Sub

' One exit point for a finished feed, whatever ended it.
Sub FeedNotifyComplete()
    Select Case FeedOwner
        Case "calib" : FeederCalibrateStep
        Case "valid" : ValidationStep
        Case "drill" : DrillAttemptComplete
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
    ValAngleAtContact = flipper.CurrentAngle

    DebugLog "feed", "precontact,seq=" & FeedSeq & _
        ",x=" & Round(FeedInX, 2) & ",y=" & Round(FeedInY, 2) & _
        ",vx=" & Round(FeedInVelX, 3) & ",vy=" & Round(FeedInVelY, 3) & _
        ",speed=" & Round(FeedInSpeed, 3) & _
        ",flipperAngle=" & Round(flipper.CurrentAngle, 2) & _
        ",flightFrames=" & FeedFrames
End Sub

' Perpendicular distance from a point to the flipper's line SEGMENT, from
' pivot to tip at its current angle, clamped at both ends.
'
' VPW's DistanceFromFlipper is not this: it measures to the infinite axis
' line, so a ball anywhere along that line reads as touching.
Function DistanceToFlipperSurface(px, py, flip)
    Dim ax, ay, bx, by, dx, dy, t, len2
    ax = flip.X : ay = flip.Y
    bx = ax + flip.Length * Sin(Radians(flip.CurrentAngle))
    by = ay - flip.Length * Cos(Radians(flip.CurrentAngle))

    dx = bx - ax : dy = by - ay
    len2 = dx * dx + dy * dy
    If len2 = 0 Then
        DistanceToFlipperSurface = Distance(px, py, ax, ay)
        Exit Function
    End If

    t = ((px - ax) * dx + (py - ay) * dy) / len2
    If t < 0 Then t = 0
    If t > 1 Then t = 1
    DistanceToFlipperSurface = Distance(px, py, ax + t * dx, ay + t * dy)
End Function

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
    FeedOwner = "calib"
    FeedScheduleFlipper -1, -1
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
