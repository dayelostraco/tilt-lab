'============================================================================
'  ZOPT: TABLE OPTIONS - the VR-navigable drill selector
'============================================================================
'
'  VPX 10.8.1 lets a table register custom options through Table1.Option.
'  They appear on the Table Options page of the in-game UI, which is the only
'  menu in VPX that is reachable and navigable in VR. There is no ray-pointer
'  in VPX VR: OpenXR exposes buttons, axes, poses and haptics, nothing is
'  surfaced to VBScript, and InGameUI forces button navigation whenever a VR
'  device is present. So this is the menu, and it costs almost no code.
'
'  In VR with Oculus Touch (VPX default mapping):
'      Left X              open / close the in-game UI
'      Left stick up/down  move between items
'      Right stick L/R     change the selected value
'      Left Y              EXIT GAME - adjacent to the menu button, take care
'
'  See docs/controls.md for the full table.
'
'  --- Table1.Option registration rules, from PinTable::RegisterOption -------
'
'  The call is a property GET that registers on first read and returns the
'  live value. The option TYPE is inferred, and getting the inference wrong
'  silently drops the option (it logs and returns E_FAIL, so the item simply
'  never appears in the UI). The rules:
'
'    values array present   -> min and max must be whole numbers, step must
'                              be exactly 1, and the array must hold exactly
'                              (1 + max - min) entries.
'    array of exactly 2,
'      "Off"/"On", "Hide"/"Show", "False"/"True" (either order)
'                           -> registered as a BOOL toggle, not an enum.
'    any other array        -> ENUM, values labelled by the array.
'    no array, step = 1,
'      whole min            -> INT.
'    anything else          -> FLOAT, displayed as %4.1f.
'
'  Also: min < max strictly, step > 0, min <= default <= max. A single-entry
'  enum is therefore impossible.
'
'  Re-registering an existing option name returns the original definition and
'  does NOT update it, so changing the shape of an option below needs a table
'  reload, not just a rebuild.
'
'  --- Event timing ---------------------------------------------------------
'
'  Table1_OptionEvent fires with:
'      0  options initialise, just after Table1_Init
'      1  an option changed
'      2  legacy, no longer dispatched (a reset arrives as a change)
'      3  the player left the in-game UI
'
'  Event 1 fires on EVERY adjustment tick, and the UI auto-repeats as fast as
'  every 125 ms while a direction is held. So reading values on 1 must stay
'  cheap, and anything disruptive (restarting a drill, respawning a ball)
'  belongs on 3, once the player has actually left the menu.
'
'============================================================================

' Live option values. Read by the drill layer; never written by it.
Dim OptDrill, OptSide, OptDifficulty, OptAttempts, OptResetDelayMs, OptDebug

' Set once the first OptionEvent has populated the values above, so that code
' running earlier cannot read them uninitialised.
Dim OptionsReady
OptionsReady = False

' Drill roster. Index matches the OptDrill enum below.
' NOTE: none of these are implemented yet - milestone 4 builds the first.
' The roster is registered in full because the purpose of this module today
' is to verify that the menu itself works in VR.
Dim DRILL_NAMES
DRILL_NAMES = Array( _
    "Drop Catch", "Live Catch", "Dead Bounce", "Post Pass", "Cradle Separation", _
    "Backhand", "Shot Accuracy", "Recovery", "Mixed Recognition")

' Attempts-per-set is an enum rather than an int so that a handful of stick
' clicks covers the useful range. Index maps into this array.
Dim ATTEMPT_VALUES
ATTEMPT_VALUES = Array(5, 10, 15, 20, 25, 30, 40, 50)

' ---------------------------------------------------------------------------
'  Registration and read-back
' ---------------------------------------------------------------------------

' Reads every option, registering it on the first call. Cheap and idempotent:
' safe to call on every change tick.
Sub ReadTrainingOptions()
    Dim attemptIdx

    OptDrill = CInt(Table1.Option("Drill", 0, 8, 1, 0, 0, DRILL_NAMES))

    OptSide = CInt(Table1.Option("Side", 0, 2, 1, 0, 0, _
        Array("Left", "Right", "Alternating")))

    OptDifficulty = CInt(Table1.Option("Difficulty", 0, 3, 1, 0, 0, _
        Array("Fixed", "Beginner", "Intermediate", "Advanced")))

    attemptIdx = CInt(Table1.Option("Attempts Per Set", 0, 7, 1, 1, 0, _
        Array("5", "10", "15", "20", "25", "30", "40", "50")))
    OptAttempts = ATTEMPT_VALUES(attemptIdx)

    ' Seconds, not milliseconds: a 0.1 step keeps this on the float path and
    ' "1.2" reads better in the menu than "1200". Converted on read so the
    ' rest of the script keeps working in ms.
    OptResetDelayMs = CInt(Table1.Option("Reset Delay", 0.4, 3.0, 0.1, 1.2, 0, Empty) * 1000)

    ' Off/On makes this a real toggle rather than a two-entry enum.
    OptDebug = (Table1.Option("Debug Overlay", 0, 1, 1, 0, 0, Array("Off", "On")) <> 0)

    OptionsReady = True
End Sub

' Applies option values to the systems that act on them. Only called at
' initialisation and when the player leaves the menu, never on every tick.
Sub ApplyTrainingOptions()
    If Not OptionsReady Then Exit Sub

    If DebugEnabled <> OptDebug Then
        DebugEnabled = OptDebug
        DebugRender
    End If

    DebugLog "options", "drill=" & DRILL_NAMES(OptDrill) & _
        ",side=" & OptSide & ",difficulty=" & OptDifficulty & _
        ",attempts=" & OptAttempts & ",resetDelayMs=" & OptResetDelayMs & _
        ",debug=" & CStr(OptDebug)

    ' Milestone 4 restarts the selected drill here.
End Sub

Sub Table1_OptionEvent(ByVal eventId)
    Select Case eventId
        Case 0  ' initialise, just after Table1_Init
            ReadTrainingOptions
            DebugLog "options", "registered " & (UBound(DRILL_NAMES) + 1) & " drills"
            ApplyTrainingOptions

        Case 1  ' an option changed. Fires per adjustment tick: keep this cheap.
            ReadTrainingOptions

        Case 3  ' player left the in-game UI. Safe to act.
            ApplyTrainingOptions

    End Select
End Sub
