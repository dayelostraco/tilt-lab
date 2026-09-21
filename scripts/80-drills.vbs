'============================================================================
'  ZDRL: DRILL STATE MACHINE
'============================================================================
'
'  A drill is: deliver a repeatable feed, let the player respond, evaluate
'  what the ball did, record it, pause briefly, repeat. After a set number of
'  attempts, report.
'
'  The drill layer chooses WHICH feed and counts the results. It does not
'  touch physics, and it does not vary anything between attempts except what
'  the difficulty setting asks the feeder to vary. Every drill runs on the
'  same simulation; only the feed changes. That is what makes results from
'  different drills comparable.
'
'============================================================================

Const DRILL_DROP_CATCH = 0
Const DRILL_LIVE_CATCH = 1
Const DRILL_CRADLE     = 2

Dim DrillActive, DrillId, DrillSide, DrillDifficulty
Dim DrillAttempt, DrillTotal, DrillSuccess, DrillLastVerdict
Dim DrillWaitUntil
DrillActive = False : DrillAttempt = 0 : DrillSuccess = 0
DrillLastVerdict = -1 : DrillWaitUntil = -1

Function DrillName(d)
    Select Case d
        Case DRILL_DROP_CATCH : DrillName = "DROP CATCH"
        Case DRILL_LIVE_CATCH : DrillName = "LIVE CATCH"
        Case DRILL_CRADLE     : DrillName = "CRADLE"
        Case Else             : DrillName = "DRILL " & d
    End Select
End Function

Function SideName(s)
    Select Case s
        Case SIDE_LEFT        : SideName = "LEFT"
        Case SIDE_RIGHT       : SideName = "RIGHT"
        Case SIDE_ALTERNATING : SideName = "ALTERNATING"
        Case Else             : SideName = "?"
    End Select
End Function

Function DifficultyName(d)
    Select Case d
        Case DIFF_FIXED        : DifficultyName = "Fixed"
        Case DIFF_BEGINNER     : DifficultyName = "Beginner"
        Case DIFF_INTERMEDIATE : DifficultyName = "Intermediate"
        Case DIFF_ADVANCED     : DifficultyName = "Advanced"
        Case Else              : DifficultyName = "?"
    End Select
End Function

Function DrillAccuracy()
    If DrillAttempt = 0 Then
        DrillAccuracy = 0
    Else
        DrillAccuracy = Int((DrillSuccess / DrillAttempt) * 100 + 0.5)
    End If
End Function

' --- Lifecycle -------------------------------------------------------------

' NOTE the parameter names. VBScript identifiers are case-INSENSITIVE, so a
' parameter called drillId is the same name as the global DrillId: it shadows
' it, and "DrillId = drillId" quietly assigns the local to itself while the
' global stays empty. That produced a drill whose start line said CRADLE and
' whose every feed was a drop catch. Parameters here are prefixed to keep
' them distinct from the globals they set.
Sub StartDrill(aDrill, aSide, aDifficulty, aAttempts)
    DrillId = aDrill
    DrillSide = aSide
    DrillDifficulty = aDifficulty
    DrillTotal = aAttempts
    DrillAttempt = 0
    DrillSuccess = 0
    DrillLastVerdict = -1
    DrillActive = True
    ' Cancel any countdown left over from a previous set, or pressing R late
    ' in a reset delay starts attempt 1 and then immediately replaces it.
    DrillWaitUntil = -1
    FeedOwner = "drill"

    ' Header row, so a session log can always be traced back to the physics
    ' and the settings it was recorded under.
    DebugLog "drill", "start," & DrillName(DrillId) & ",side=" & SideName(DrillSide) & _
        ",difficulty=" & DifficultyName(DrillDifficulty) & ",attempts=" & DrillTotal & _
        ",physics=" & PhysicsSignature()

    UpdateTrainingDisplay
    NextAttempt
End Sub

Sub EndDrill()
    DrillActive = False
    FeedOwner = ""
    DrillWaitUntil = -1
    DebugLog "drill", "end," & DrillName(DrillId) & ",side=" & SideName(DrillSide) & _
        ",attempts=" & DrillAttempt & ",success=" & DrillSuccess & _
        ",accuracy=" & DrillAccuracy() & "%"
    UpdateTrainingDisplay
End Sub

Sub ResetDrill()
    If Not DrillActive Then Exit Sub
    DebugLog "drill", "reset"
    StartDrill DrillId, DrillSide, DrillDifficulty, DrillTotal
End Sub

' Which physical side this attempt uses. Alternating flips each attempt so
' both hands get equal work inside one set.
Function AttemptSide()
    If DrillSide = SIDE_ALTERNATING Then
        If (DrillAttempt Mod 2) = 0 Then AttemptSide = SIDE_RIGHT Else AttemptSide = SIDE_LEFT
    Else
        AttemptSide = DrillSide
    End If
End Function

Sub NextAttempt()
    If Not DrillActive Then Exit Sub

    If DrillAttempt >= DrillTotal Then
        EndDrill
        Exit Sub
    End If

    DrillAttempt = DrillAttempt + 1

    ' The player supplies the flipper input; the drill never actuates it.
    ' (The validation harness in 65- does, but that is a test rig, not a
    ' drill, and it never runs while a drill is active.)
    FeedScheduleFlipper -1, -1

    Select Case DrillId
        Case DRILL_CRADLE
            FeedCradleTo AttemptSide(), DrillDifficulty
        Case Else
            FeedDropCatchTo AttemptSide(), DrillDifficulty
    End Select

    UpdateTrainingDisplay
End Sub

' Called by the feeder when an attempt's measurements are complete.
Sub DrillAttemptComplete()
    Dim v
    If Not DrillActive Then Exit Sub

    v = EvaluateAttempt()
    DrillLastVerdict = v
    If VerdictIsSuccess(v) Then DrillSuccess = DrillSuccess + 1

    DebugLog "attempt", AttemptRecord(DrillName(DrillId), SideName(AttemptSide()), _
        DifficultyName(DrillDifficulty), DrillAttempt, v)

    UpdateTrainingDisplay

    ' Pause long enough to read the verdict, then go again, in simulation ms.
    DrillWaitUntil = GameTime + OptResetDelayMsValue()
End Sub

Function OptResetDelayMsValue()
    If OptionsReady Then
        OptResetDelayMsValue = OptResetDelayMs
    Else
        OptResetDelayMsValue = DEFAULT_RESET_DELAY_MS
    End If
End Function

' Ticked once per rendered frame from the physics timer.
Sub DrillTick()
    If Not DrillActive Then Exit Sub
    If DrillWaitUntil < 0 Then Exit Sub

    If GameTime >= DrillWaitUntil Then
        DrillWaitUntil = -1
        NextAttempt
    End If
End Sub
