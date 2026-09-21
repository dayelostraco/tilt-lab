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
