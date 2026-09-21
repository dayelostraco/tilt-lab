'============================================================================
'  ZSCR: ATTEMPT EVALUATION
'============================================================================
'
'  Turns the feeder's measurements into a verdict. It reads; it never writes.
'  Nothing in this file touches the ball, the flippers or any physics value,
'  because a trainer that nudges an attempt toward success teaches a timing
'  that will not survive contact with a real machine.
'
'  --- Where the thresholds come from ---------------------------------------
'
'  Measured, not guessed, from the automated validation sweeps on
'  2026-09-21 (see docs/physics.md):
'
'    a settled cradle      control speed 0.605..0.740, 81 vpu from the base
'    a clean live catch    retained 0.233, ball killed to speed 2.0
'    a partial catch       retained 0.354
'    a plain bounce        retained 0.46
'    a dead bounce         retained 0.33, but 288 vpu away and still moving
'    a flipped shot        retained 1.1 to 3.8
'
'  The two numbers that separate a catch from a bounce are speed AND
'  distance. Either alone is ambiguous: a dead bounce also loses most of its
'  speed by the time it is measured, but it is 288 vpu away by then. Control
'  means slow AND still there.
'
'  --- On verdict honesty ----------------------------------------------------
'
'  There is deliberately no EARLY or LATE. The trainer measures what the ball
'  did, not what the player intended, and it cannot presently distinguish
'  "released too early" from "released too late" without inferring intent.
'  Reporting a timing critique it cannot support would train the player to
'  correct an error they may not have made.
'
'============================================================================

Const VERDICT_PERFECT    = 0
Const VERDICT_CONTROLLED = 1
Const VERDICT_PARTIAL    = 2
Const VERDICT_MISS       = 3
Const VERDICT_SHOT       = 4
Const VERDICT_DRAIN      = 5

' Ball is "under control" when it is both slow and still at the flipper.
' Cradle measured at speed 0.6 / 81 vpu; these sit just outside that.
Const CTRL_SPEED_PERFECT = 1.2
Const CTRL_DIST_PERFECT  = 110
Const CTRL_SPEED_OK      = 3.0
Const CTRL_DIST_OK       = 160

' Below this fraction of incoming speed, real energy was absorbed even if the
' ball did not end up controlled. Measured partial catch was 0.354.
Const RETAINED_PARTIAL   = 0.60

' ...but retained energy ALONE over-credits doing nothing. A ball that simply
' dead-bounces off a lowered flipper and travels away also arrives at the
' measurement slow, and scored PARTIAL on the first run of the drill loop
' with no player input at all. It was 287 vpu away by then.
'
' So a partial catch must also still be somewhere near the flipper. Measured:
' a real partial catch sat at 199.8 vpu, an untouched dead bounce at 287.
Const CTRL_DIST_PARTIAL  = 240

' Above this the player did not catch anything, they hit it. A flipped shot
' measured 1.1 to 3.8.
Const RETAINED_SHOT      = 1.05

Function VerdictName(v)
    Select Case v
        Case VERDICT_PERFECT    : VerdictName = "PERFECT"
        Case VERDICT_CONTROLLED : VerdictName = "CONTROLLED"
        Case VERDICT_PARTIAL    : VerdictName = "PARTIAL"
        Case VERDICT_MISS       : VerdictName = "MISS"
        Case VERDICT_SHOT       : VerdictName = "SHOT"
        Case VERDICT_DRAIN      : VerdictName = "DRAIN"
        Case Else               : VerdictName = "?"
    End Select
End Function

' PERFECT and CONTROLLED count as success; everything else does not.
Function VerdictIsSuccess(v)
    VerdictIsSuccess = (v = VERDICT_PERFECT Or v = VERDICT_CONTROLLED)
End Function

' Evaluates the attempt the feeder has just finished measuring.
' Reads FeedInSpeed, FeedControlSpeed and FeedControlDist; writes nothing.
Function EvaluateAttempt()
    Dim retained

    ' The feeder sets these to -1 when the ball drained before it could be
    ' measured. A drain is an outcome, not a missing reading.
    If FeedControlSpeed < 0 Then
        EvaluateAttempt = VERDICT_DRAIN
        Exit Function
    End If

    If FeedInSpeed <= 0 Then
        ' No contact was ever recorded: the ball never reached the flipper.
        EvaluateAttempt = VERDICT_MISS
        Exit Function
    End If

    retained = SafeRatio(FeedControlSpeed, FeedInSpeed)

    If FeedControlSpeed <= CTRL_SPEED_PERFECT And FeedControlDist <= CTRL_DIST_PERFECT Then
        EvaluateAttempt = VERDICT_PERFECT
    ElseIf FeedControlSpeed <= CTRL_SPEED_OK And FeedControlDist <= CTRL_DIST_OK Then
        EvaluateAttempt = VERDICT_CONTROLLED
    ElseIf retained >= RETAINED_SHOT Then
        EvaluateAttempt = VERDICT_SHOT
    ElseIf retained <= RETAINED_PARTIAL And FeedControlDist <= CTRL_DIST_PARTIAL Then
        EvaluateAttempt = VERDICT_PARTIAL
    Else
        EvaluateAttempt = VERDICT_MISS
    End If
End Function

' The full raw record behind a verdict, so thresholds can be re-tuned against
' real sessions instead of re-guessed. This is the CSV row the brief asks for.
Function AttemptRecord(drill, side, difficulty, attempt, verdict)
    AttemptRecord = "drill=" & drill & ",side=" & side & _
        ",difficulty=" & difficulty & ",attempt=" & attempt & _
        ",inSpeed=" & Round(FeedInSpeed, 3) & _
        ",inVx=" & Round(FeedInVelX, 3) & ",inVy=" & Round(FeedInVelY, 3) & _
        ",contactX=" & Round(FeedInX, 1) & ",contactY=" & Round(FeedInY, 1) & _
        ",reboundSpeed=" & Round(FeedReboundSpeed, 3) & _
        ",controlSpeed=" & Round(FeedControlSpeed, 3) & _
        ",controlDist=" & Round(FeedControlDist, 1) & _
        ",retained=" & Round(SafeRatio(FeedControlSpeed, FeedInSpeed), 4) & _
        ",outcome=" & VerdictName(verdict)
End Function
