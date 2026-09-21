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
' Geometry these were derived from, for the right flipper:
'   flipper centre   (595.87, 1803.27), length 114, raised angle -70 deg
'   raised tip       (488.7, 1764.3)
'   60% contact pt   (531.6, 1779.9)   <- the middle-to-upper region wanted
'                                         for a drop catch
' The left profile is this mirrored about the playfield centreline,
' x' = 952.94 - x, with VelX negated.

Dim FeedDropCatch(1)      ' indexed by SIDE_LEFT / SIDE_RIGHT

Sub InitFeedProfiles()
    Dim p

    Set p = New FeedProfile
    p.Name = "DropCatch.Right"
    ' Top of the right inlane, travelling down and inward toward the flipper.
    p.LaunchX = 690 : p.LaunchY = 1600
    p.VelX = -3.0   : p.VelY = 11.0
    p.JitterPos = 12    ' vpu, full width
    p.JitterVel = 2.5   ' vpu/tick, full width
    p.JitterAng = 6     ' degrees, full width
    Set FeedDropCatch(SIDE_RIGHT) = p

    Set p = New FeedProfile
    p.Name = "DropCatch.Left"
    p.LaunchX = 952.94 - 690 : p.LaunchY = 1600
    p.VelX = 3.0             : p.VelY = 11.0
    p.JitterPos = 12
    p.JitterVel = 2.5
    p.JitterAng = 6
    Set FeedDropCatch(SIDE_LEFT) = p
End Sub

InitFeedProfiles

' --- Feeder state ----------------------------------------------------------

Const FEED_IDLE     = 0
Const FEED_INFLIGHT = 1   ' launched, not yet near the flipper
Const FEED_NEAR     = 2   ' inside the measurement radius
Const FEED_SETTLING = 3   ' contact happened, waiting to read the outcome

' Distance from the flipper base, in vpu, at which the pre-contact snapshot is
' taken. Far enough out that the flipper has not touched the ball yet, close
' enough that the reading describes the actual approach.
Const FEED_MEASURE_RADIUS = 90

' How long after contact to read the outgoing state, in ms. Long enough for
' the interaction to finish, short enough that the ball has not travelled
' somewhere unrelated.
Const FEED_SETTLE_MS = 220

Dim FeedState      : FeedState = FEED_IDLE
Dim FeedSide       : FeedSide = SIDE_RIGHT
Dim FeedBallObj    : Set FeedBallObj = Nothing
Dim FeedLaunchedAt, FeedContactAt
Dim FeedInSpeed, FeedInVelX, FeedInVelY, FeedInX, FeedInY
Dim FeedSeq        : FeedSeq = 0

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
        balls(b).Destroy
    Next
    Set FeedBallObj = Nothing
    FeedState = FEED_IDLE
End Sub

' Launches one ball along the given profile.
'
' `difficulty` scales the randomisation; at DIFF_FIXED nothing is randomised
' and two calls with the same profile are identical.
Sub FeederLaunch(profile, side, difficulty)
    Dim s, jx, jy, jv, ja, vx, vy, spd, ang

    FeederClear
    FeedSide = side
    FeedSeq = FeedSeq + 1

    s = FeedJitterScale(difficulty)

    ' Rnd returns 0..1; (Rnd-0.5) gives a symmetric full-width band, so
    ' JitterPos really is the total spread rather than a one-sided offset.
    jx = (Rnd - 0.5) * profile.JitterPos * s
    jy = (Rnd - 0.5) * profile.JitterPos * s
    jv = (Rnd - 0.5) * profile.JitterVel * s
    ja = (Rnd - 0.5) * profile.JitterAng * s

    ' Speed and angle are perturbed rather than the components, so a jittered
    ' feed stays on a physically plausible trajectory family instead of
    ' drifting into directions the profile never intended.
    spd = Sqr(profile.VelX * profile.VelX + profile.VelY * profile.VelY) + jv
    ang = Atn2(profile.VelY, profile.VelX) + Radians(ja)
    vx = spd * Cos(ang)
    vy = spd * Sin(ang)

    Set FeedBallObj = CreateBallAt(profile.LaunchX + jx, profile.LaunchY + jy, profile.LaunchZ)
    FeedBallObj.VelX = vx
    FeedBallObj.VelY = vy
    FeedBallObj.VelZ = profile.VelZ

    FeedLaunchedAt = DebugNowMs()
    FeedState = FEED_INFLIGHT
    FeedInSpeed = 0

    DebugLog "feed", "launch,seq=" & FeedSeq & ",profile=" & profile.Name & _
        ",side=" & side & ",difficulty=" & difficulty & _
        ",x=" & Round(profile.LaunchX + jx, 2) & ",y=" & Round(profile.LaunchY + jy, 2) & _
        ",vx=" & Round(vx, 3) & ",vy=" & Round(vy, 3) & _
        ",speed=" & Round(spd, 3) & ",jitterScale=" & s
End Sub

' VPX has no "create a ball at an arbitrary point" call; a ball is born from a
' kicker. BallSpawn is an invisible, zero-strength kicker that is moved to the
' launch point first, so the ball appears exactly where the profile says.
Function CreateBallAt(x, y, z)
    BallSpawn.X = x
    BallSpawn.Y = y
    Set CreateBallAt = BallSpawn.CreateBall
    BallSpawn.Kick 0, 0          ' release without imparting anything
    CreateBallAt.Z = z
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
    Dim d, spd, flip

    If FeedState = FEED_IDLE Then Exit Sub
    If FeedBallObj Is Nothing Then Exit Sub

    Set flip = FeedTargetFlipper()
    d = DistanceFromFlipper(FeedBallObj.X, FeedBallObj.Y, flip)
    spd = Sqr(FeedBallObj.VelX * FeedBallObj.VelX + FeedBallObj.VelY * FeedBallObj.VelY)

    Select Case FeedState

        Case FEED_INFLIGHT
            If d <= FEED_MEASURE_RADIUS Then
                FeedInSpeed = spd
                FeedInVelX = FeedBallObj.VelX : FeedInVelY = FeedBallObj.VelY
                FeedInX = FeedBallObj.X       : FeedInY = FeedBallObj.Y
                FeedContactAt = DebugNowMs()
                FeedState = FEED_NEAR
                DebugLog "feed", "precontact,seq=" & FeedSeq & _
                    ",dist=" & Round(d, 2) & _
                    ",x=" & Round(FeedInX, 2) & ",y=" & Round(FeedInY, 2) & _
                    ",vx=" & Round(FeedInVelX, 3) & ",vy=" & Round(FeedInVelY, 3) & _
                    ",speed=" & Round(spd, 3) & _
                    ",flipperAngle=" & Round(flip.CurrentAngle, 2) & _
                    ",flightMs=" & (FeedContactAt - FeedLaunchedAt)
            End If

        Case FEED_NEAR
            If DebugNowMs() - FeedContactAt >= FEED_SETTLE_MS Then
                FeedState = FEED_SETTLING
                DebugLog "feed", "postcontact,seq=" & FeedSeq & _
                    ",dist=" & Round(d, 2) & _
                    ",x=" & Round(FeedBallObj.X, 2) & ",y=" & Round(FeedBallObj.Y, 2) & _
                    ",vx=" & Round(FeedBallObj.VelX, 3) & ",vy=" & Round(FeedBallObj.VelY, 3) & _
                    ",speed=" & Round(spd, 3) & _
                    ",inSpeed=" & Round(FeedInSpeed, 3) & _
                    ",retained=" & Round(SafeRatio(spd, FeedInSpeed), 4) & _
                    ",flipperAngle=" & Round(flip.CurrentAngle, 2)
                ' Advance a calibration run, if one is in progress. This is
                ' last so the sample is logged before the next feed clears it.
                FeederCalibrateStep
            End If

    End Select
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

Dim CalRunsLeft, CalSide, CalSamples, CalCount
CalRunsLeft = 0 : CalCount = 0
ReDim CalSamples(63)

Sub FeederCalibrate(side, runs)
    CalSide = side
    CalRunsLeft = runs
    CalCount = 0
    DebugLog "calib", "start,side=" & side & ",runs=" & runs & ",physics=" & PhysicsSignature()
    FeedDropCatchTo CalSide, DIFF_FIXED
End Sub

' Advances the calibration run. Called when a fed ball has finished settling.
Sub FeederCalibrateStep()
    If CalRunsLeft <= 0 Then Exit Sub

    If FeedInSpeed > 0 And CalCount <= UBound(CalSamples) Then
        CalSamples(CalCount) = FeedInSpeed
        CalCount = CalCount + 1
    End If

    CalRunsLeft = CalRunsLeft - 1
    If CalRunsLeft > 0 Then
        FeedDropCatchTo CalSide, DIFF_FIXED
    Else
        FeederCalibrateReport
    End If
End Sub

Sub FeederCalibrateReport()
    Dim i, sum, mean, sd, lo, hi
    If CalCount = 0 Then
        DebugLog "calib", "report,no samples"
        Exit Sub
    End If

    sum = 0 : lo = CalSamples(0) : hi = CalSamples(0)
    For i = 0 To CalCount - 1
        sum = sum + CalSamples(i)
        If CalSamples(i) < lo Then lo = CalSamples(i)
        If CalSamples(i) > hi Then hi = CalSamples(i)
    Next
    mean = sum / CalCount

    sum = 0
    For i = 0 To CalCount - 1
        sum = sum + (CalSamples(i) - mean) * (CalSamples(i) - mean)
    Next
    sd = Sqr(sum / CalCount)

    DebugLog "calib", "report,n=" & CalCount & _
        ",meanInSpeed=" & Round(mean, 4) & _
        ",sd=" & Round(sd, 4) & _
        ",min=" & Round(lo, 4) & ",max=" & Round(hi, 4) & _
        ",spread=" & Round(hi - lo, 4)
End Sub
