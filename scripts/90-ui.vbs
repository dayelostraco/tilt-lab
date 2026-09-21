'============================================================================
'  ZUI: TRAINING DISPLAY
'============================================================================
'
'  Four text decals on the apron, below the flippers.
'
'  Decals are used rather than a TextBox because a TextBox is screen-space:
'  in VR it floats in front of the playfield and reads as a rendering fault.
'  A decal is real playfield geometry with a scriptable Text property, so it
'  sits on the apron and is legible from the player's actual viewpoint in
'  both VR and desktop. It is the only dynamic text VPX offers that survives
'  being looked at from an angle.
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
