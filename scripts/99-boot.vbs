'============================================================================
'  ZBOO: BOOT - init and exit wiring. This module is assembled last.
'============================================================================
'
'  Everything above declares; this runs. Keeping the wiring in one terminal
'  module means the startup order is readable in a single place rather than
'  scattered across whichever module happened to be concatenated first.
'
'============================================================================

Sub Table1_Init()
    DebugLog "boot", "Tilt Lab loading"
    DebugLog "boot", "renderingMode=" & RenderingMode & ",desktop=" & CStr(DesktopMode) & ",vr=" & CStr(VRMode)
    DebugLog "boot", "table=" & Table1.Width & "x" & Table1.Height

    DebugRender

    DebugLog "boot", "ready"
End Sub

Sub Table1_Exit()
    DebugLog "boot", "exiting"
End Sub
