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
