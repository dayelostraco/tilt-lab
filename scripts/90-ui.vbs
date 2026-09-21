'============================================================================
'  ZUI: TRAINING DISPLAY
'============================================================================
'
'  Four text decals on the apron, below the flippers.
'
'  *** THIS DISPLAY DOES NOT WORK AND IS KNOWN TO BE BROKEN. ***
'
'  The reasoning was: a TextBox is screen-space and floats in front of the
'  playfield in VR, whereas a Decal is real playfield geometry and exposes a
'  writable Text property, so it should be legible from the player's actual
'  viewpoint.
'
'  The writable property is real. The dynamism is not. Decal::put_Text only
'  stores the string and recomputes sizing; the text TEXTURE is rasterised
'  once in Decal::RenderSetup and never regenerated. Assignments here
'  succeed and change nothing on screen.
'
'  The correct path is a Flasher in DMD mode: IFlasher exposes DMDWidth,
'  DMDHeight and DMDPixels, which a script can rewrite every frame, and a
'  flasher is playfield geometry so it survives being viewed at an angle in
'  VR. That needs a small bitmap font renderer in script, which is what VPW
'  tables do for their score displays.
'
'  Until then the drill still runs and every verdict is in the log; only the
'  on-table readout is missing. Tracked in TODO.md.
'
'============================================================================

Sub UpdateTrainingDisplay()
    If Not DrillActive Then
        UILine1.Text = "TILT LAB"
        UILine2.Text = "Press 1 to start   D for debug"
        UILine3.Text = ""
        If DrillAttempt > 0 Then
            UILine4.Text = "Last set: " & DrillSuccess & "/" & DrillAttempt & _
                           "   " & DrillAccuracy() & "%"
        Else
            UILine4.Text = ""
        End If
        Exit Sub
    End If

    UILine1.Text = DrillName(DrillId) & " - " & SideName(AttemptSide())
    UILine2.Text = DifficultyName(DrillDifficulty)
    UILine3.Text = "Attempt " & DrillAttempt & " / " & DrillTotal & _
                   "    Success " & DrillSuccess & _
                   "    " & DrillAccuracy() & "%"

    If DrillLastVerdict >= 0 Then
        UILine4.Text = VerdictName(DrillLastVerdict)
    Else
        UILine4.Text = ""
    End If
End Sub
