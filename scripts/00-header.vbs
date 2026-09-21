'============================================================================
'  TILT LAB - Pinball Training Lab
'============================================================================
'
'  A Visual Pinball X training table for drilling transferable real-world
'  pinball ball-control skills. This is a skills laboratory, not a game.
'
'  Target: VPX 10.8.1 BGFX 64-bit, PCVR (Quest 3 / Virtual Desktop / OpenXR)
'
'  This file is assembled from scripts/*.vbs by tools/build.sh.
'  Do not edit the copy embedded in the .vpx - it is overwritten on build.
'
'  Credits and licensing for reused community code: see ATTRIBUTION.md.
'
'  --- MODULE MAP -----------------------------------------------------------
'
'    00-header.vbs        this file: bootstrap, VR/desktop detection
'    10-config.vbs        ZCFG  every tunable value, in one place
'    15-options.vbs       ZOPT  VR-navigable drill selector (Table1.Option)
'    20-table-core.vbs    ZCOR  input, trough, slingshots, GI
'    30-sound.vbs         ZSND  positional playback, rolling, impacts
'    50-ball-shadows.vbs  ZSHA  flipper and ball shadows
'    90-training-input.vbs ZINP drill control keys (desktop mirror)
'    95-debug.vbs         ZDBG  debug overlay and structured logging
'    99-boot.vbs          ZBOO  init / exit wiring, runs last
'
'  Modules still to come (see TODO.md):
'    40-physics-nfozzy    nFozzy flipper corrections           (milestone 2)
'    45-physics-damping   rubber dampeners, target bouncer     (milestone 2)
'    60-feeder            repeatable ball delivery subsystem   (milestone 3)
'    70-scoring           attempt evaluation                   (milestone 4)
'    80-drills            drill state machine                  (milestone 4)
'    90-ui                training display                     (milestone 4)
'
'============================================================================

Option Explicit
Randomize
SetLocale 1033

' controller.vbs ships with VPX and provides the DOF plumbing that the
' SoundFX() calls below depend on. The trainer needs no ROM, so a missing
' controller.vbs is a warning, not a hard failure.
On Error Resume Next
ExecuteGlobal GetTextFile("controller.vbs")
If Err Then MsgBox "Tilt Lab: controller.vbs not found. It ships with VPX in the scripts folder."
On Error Goto 0

' Rendering mode: 0 = desktop, 1 = cabinet/FSS, 2 = VR.
' VPX exposes this through RenderingMode; ShowDT is the older desktop flag.
Dim DesktopMode, VRMode
DesktopMode = Table1.ShowDT
VRMode = (RenderingMode = 2)

' The flat score text belongs to the desktop view only - in VR it floats in
' mid-air in front of the playfield and reads as a rendering bug.
If Not DesktopMode Then ScoreText.Visible = False
