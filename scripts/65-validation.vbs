'============================================================================
'  ZVAL: AUTOMATED PHYSICS VALIDATION
'============================================================================
'
'  The brief asks for the physics foundation to be "manually or
'  programmatically" validated. This is the programmatic half.
'
'  What makes it possible: the flippers are driven through VPW's
'  FlipperActivate / FlipperDeactivate, which the script can call, and the
'  feeder delivers a repeatable ball. So a flipper can be actuated at an
'  exact frame relative to launch, over and over, with the only thing
'  changing being the timing.
'
'  --- Why a timing SWEEP rather than a pass/fail test ----------------------
'
'  The interesting question about a catch is not "does it work". It is
'  "does timing matter". The brief is explicit that the trainer must not make
'  every attempt succeed, and a single well-timed attempt cannot tell the
'  difference between good physics and hidden assistance.
'
'  A sweep can. Vary the release frame either side of contact and read the
'  energy retained:
'
'    a smooth curve with a clear minimum   physics is discriminating properly
'    flat and low everywhere               assistance is leaking in
'    flat and high everywhere              the catch is impossible
'
'  That is a machine-checkable answer to a question that otherwise needs a
'  human with an opinion.
'
'  Run one from a Windows host with no keyboard:
'      attract.ps1 valid-drop 1500 10
'
'============================================================================

Const VAL_NONE     = 0
Const VAL_DROP     = 1   ' flipper held up, released near contact
Const VAL_LIVE     = 2   ' flipper down, raised near contact
Const VAL_CRADLE   = 3   ' flipper held up throughout, ball should settle
Const VAL_DEAD     = 4   ' flipper never touched
Const VAL_SPEED    = 5   ' flipper held up; sweep FEED SPEED, not timing

Dim ValMode      : ValMode = VAL_NONE
Dim ValSide      : ValSide = SIDE_RIGHT
Dim ValOffset, ValOffsetMin, ValOffsetMax
Dim ValResults, ValResultCount, ValDrained
Dim ValAngleAtContact

' Contact frame depends on where the flipper is, and getting this wrong makes
' a sweep look flat for the wrong reason.
'
' With the flipper DOWN the ball travels to the flipper's resting position and
' contacts at about frame 42. With it already RAISED the flipper reaches out
' and intercepts the ball eight frames earlier, at about frame 34. Measured,
' not assumed: a first sweep centred on 43 put every single release after
' contact had already happened, and reported a perfectly flat response.
' Contact times in SIMULATION milliseconds, measured from a precontact line's
' flightMs. These were frame counts until an external review pointed out that
' the counter advances per RENDERED frame, so the actuation point they
' defined moved with display rate: a "20 frame" release is 333 ms at 60 fps
' and 67 ms at 300 fps, testing a completely different part of the timing
' window on different hardware.
'
' They still move with the feed: a faster ball reaches the flipper sooner. If
' the feed speed changes, re-measure these from flightMs.
Const VAL_CONTACT_MS_UP   = 170   ' flipper raised (drop catch)
Const VAL_CONTACT_MS_DOWN = 205   ' flipper at rest (live catch, dead bounce)

' Sweep offsets, also in simulation milliseconds. The range extends well
' before contact because the flipper takes time to actually fall after
' release. 10 ms is roughly one frame at 90 Hz, which is about the finest
' control a player has.
Const VAL_SWEEP_MIN = -140
Const VAL_SWEEP_MAX = 70
Const VAL_SWEEP_STEP = 15

' Speed sweep, in vpu/frame. The inlane feed at ~9 was measured to bounce the
' ball straight off a raised flipper and away (distFromBase ~225), so the
' question is at what speed it starts to settle instead.
Const VAL_SPEED_MIN = 4.0
Const VAL_SPEED_MAX = 34.0
Const VAL_SPEED_STEP = 2.0
' That sweep produced: arrival(vpu) = 0.744 x launch(vpu) + 1.086

Dim ValContactMs

ReDim ValResults(63)
ValResultCount = 0

Sub ValidationStart(mode, side)
    ValMode = mode
    ValSide = side
    If mode = VAL_DROP Or mode = VAL_CRADLE Or mode = VAL_SPEED Then
        ValContactMs = VAL_CONTACT_MS_UP
    Else
        ValContactMs = VAL_CONTACT_MS_DOWN
    End If
    If mode = VAL_SPEED Then ValOffset = VAL_SPEED_MIN Else ValOffset = VAL_SWEEP_MIN
    ValResultCount = 0
    ValDrained = 0
    FeedOwner = "valid"

    DebugLog "valid", "start,mode=" & mode & ",side=" & side & _
        ",contactMs=" & ValContactMs & _
        ",sweep=" & VAL_SWEEP_MIN & ".." & VAL_SWEEP_MAX & " step " & VAL_SWEEP_STEP & _
        ",physics=" & PhysicsSignature()
    ValidationLaunch
End Sub

Sub ValidationLaunch()
    Dim pressAt, releaseAt, contactAt   ' all in simulation ms from launch
    contactAt = ValContactMs + ValOffset

    Select Case ValMode
        Case VAL_DROP
            ' Flipper already up before the ball arrives, dropped at contact.
            pressAt = 10 : releaseAt = contactAt
        Case VAL_LIVE
            ' Flipper down, raised into the ball.
            pressAt = contactAt : releaseAt = -1
        Case VAL_CRADLE
            ' Up and stays up. Offset is irrelevant; the ball should settle.
            pressAt = 10 : releaseAt = -1
        Case VAL_SPEED
            ' Up and stays up; the sweep axis is launch speed.
            pressAt = 10 : releaseAt = -1
            FeedSpeedOverride = ValOffset
        Case Else   ' VAL_DEAD
            pressAt = -1 : releaseAt = -1
    End Select

    FeedScheduleFlipper pressAt, releaseAt
    If ValMode = VAL_CRADLE Then
        FeedCradleTo ValSide, DIFF_FIXED
    Else
        FeedDropCatchTo ValSide, DIFF_FIXED
    End If
End Sub

' Called when a feed finishes. Records the outcome and advances the sweep.
Sub ValidationStep()
    Dim retained, outSpeed

    ' A drained attempt has no meaningful retained ratio: the feeder reports
    ' control speed -1, which averaged into the statistics as a NEGATIVE
    ' retained value and dragged the reported minimum below zero. Count it
    ' separately instead of pretending it is a measurement.
    If FeedControlSpeed < 0 Then
        ValDrained = ValDrained + 1
        DebugLog "valid", "sample,mode=" & ValMode & ",offset=" & ValOffset & ",DRAINED"
    ElseIf FeedInSpeed > 0 And Not (FeedBallObj Is Nothing) Then
        ' Judge on the CONTROL sample, not the rebound. A catch is measured by
        ' how little speed the ball has once things have settled, not by how
        ' it left the collision.
        outSpeed = FeedControlSpeed
        retained = SafeRatio(outSpeed, FeedInSpeed)
        DebugLog "valid", "sample,mode=" & ValMode & ",offset=" & ValOffset & _
            ",inSpeed=" & Round(FeedInSpeed, 3) & _
            ",reboundSpeed=" & Round(FeedReboundSpeed, 3) & _
            ",controlSpeed=" & Round(outSpeed, 3) & _
            ",distFromBase=" & Round(FeedControlDist, 1) & _
            ",retained=" & Round(retained, 4) & _
            ",contactX=" & Round(FeedInX, 1) & ",contactY=" & Round(FeedInY, 1) & _
            ",angleAtContact=" & Round(ValAngleAtContact, 2) & _
            ",angleNow=" & Round(FeedTargetFlipper().CurrentAngle, 2) & _
            ",flightFrames=" & FeedContactAt
        If ValResultCount <= UBound(ValResults) Then
            ValResults(ValResultCount) = retained
            ValResultCount = ValResultCount + 1
        End If
    Else
        DebugLog "valid", "sample,mode=" & ValMode & ",offset=" & ValOffset & ",NO CONTACT"
    End If

    ' Release the flipper between attempts so the next one starts clean.
    FlipperDown SIDE_LEFT
    FlipperDown SIDE_RIGHT

    If ValMode = VAL_SPEED Then
        ValOffset = ValOffset + VAL_SPEED_STEP
        If ValOffset > VAL_SPEED_MAX Then
            FeedSpeedOverride = 0
            ValidationReport
            Exit Sub
        End If
        ValidationLaunch
        Exit Sub
    End If

    ValOffset = ValOffset + VAL_SWEEP_STEP
    If ValOffset > VAL_SWEEP_MAX Or ValMode = VAL_CRADLE Or ValMode = VAL_DEAD Then
        If ValMode = VAL_CRADLE Or ValMode = VAL_DEAD Then
            If ValResultCount >= 5 Then
                ValidationReport
                Exit Sub
            End If
            ValOffset = VAL_SWEEP_MIN     ' repeat, these have no sweep axis
        Else
            ValidationReport
            Exit Sub
        End If
    End If
    ValidationLaunch
End Sub

Sub ValidationReport()
    Dim i, lo, hi, sum, mean
    FeedOwner = ""

    If ValResultCount = 0 Then
        DebugLog "valid", "report,NO SAMPLES,drained=" & ValDrained
        Exit Sub
    End If

    lo = ValResults(0) : hi = ValResults(0) : sum = 0
    For i = 0 To ValResultCount - 1
        sum = sum + ValResults(i)
        If ValResults(i) < lo Then lo = ValResults(i)
        If ValResults(i) > hi Then hi = ValResults(i)
    Next
    mean = sum / ValResultCount

    ' The discriminating number. If the best and worst timing produce nearly
    ' the same retained energy, timing does not matter, and the drill this
    ' would feed is not training anything.
    DebugLog "valid", "report,mode=" & ValMode & ",n=" & ValResultCount & _
        ",drained=" & ValDrained & _
        ",retainedMin=" & Round(lo, 4) & ",retainedMax=" & Round(hi, 4) & _
        ",retainedMean=" & Round(mean, 4) & _
        ",discrimination=" & Round(hi - lo, 4)
End Sub
