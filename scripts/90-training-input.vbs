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
