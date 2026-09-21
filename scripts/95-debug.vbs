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
' vpu-per-VPT to metres per second, for log lines that a human has to judge.
Function ToMS(v)
    ToMS = Round(v * MS_PER_VPU, 3)
End Function

Sub DebugLogBall(tag, b)
    If b Is Nothing Then Exit Sub
    DebugLog "ball", tag & _
        ",x=" & Round(b.X, 2) & ",y=" & Round(b.Y, 2) & ",z=" & Round(b.Z, 2) & _
        ",vx=" & Round(b.VelX, 3) & ",vy=" & Round(b.VelY, 3) & ",vz=" & Round(b.VelZ, 3) & _
        ",speed=" & Round(Sqr(b.VelX * b.VelX + b.VelY * b.VelY), 3)
End Sub
