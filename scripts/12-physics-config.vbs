'============================================================================
'  ZPHY: PHYSICS PROFILE
'============================================================================
'
'  One profile today: MODERN_STERN. This module exists so that adding WPC or
'  System 11 later is a matter of adding a branch here, not of hunting values
'  through the script.
'
'  --- What this layer does and does not own -------------------------------
'
'  It does NOT reimplement VPW. The nFozzy/VPW stack in 40- and 45- is used
'  as shipped, and its constants stay where VPW put them, because they are
'  cross-referenced by the original comments that explain them. Moving them
'  here would duplicate the authoritative copy and let the two drift.
'
'  What this layer owns is the SELECTION: which era VPW should behave as, and
'  which of the values that genuinely are table-level (friction, slope,
'  flipper strength) apply. VPW is already parameterised by era. The relevant
'  switches, and where they actually live:
'
'    FlipperCoilRampupMode  40-physics-nfozzy.vbs   0 fast / 1 med / 2 slow
'    EOSTnew                40-physics-nfozzy.vbs   1.5 EM..late80s / 1.2 90s+
'    EOSReturn              40-physics-nfozzy.vbs   .055 EM / .045 / .035 / .025
'    playfield friction     table/src/gamedata.json
'    slope                  table/src/gamedata.json (angle_tilt_min/max)
'    flipper strength etc   table/src/gameitems/Flipper.*.json
'
'  The constants below record what the active profile expects. They are read
'  by the physics debug output so that a session log states the profile it was
'  recorded under, and they are what a future profile switch would drive.
'
'  --- CRITICAL: no VPX Global Physics Set ---------------------------------
'
'  This table must never use a Global Physics Set. A global set overrides the
'  per-part values that nFozzy's corrections are calibrated against, which
'  silently invalidates the whole stack: the polarity and velocity tables stay
'  in place but no longer describe the flipper they are correcting.
'
'  Every VPW reference inspected agrees: override_physics = 0 on the table,
'  override_physics_flipper = false, and override_physics = 0 on each flipper.
'  This table matches. AssertNoGlobalPhysics below fails loudly if that ever
'  changes. See docs/physics.md.
'
'============================================================================

' --- Profile identity ------------------------------------------------------

Const PHYS_MODERN_STERN = 0
' Reserved, deliberately not implemented yet:
'   Const PHYS_WPC       = 1
'   Const PHYS_SYSTEM_11 = 2
'   Const PHYS_CUSTOM    = 3

Const PhysicsProfile = PHYS_MODERN_STERN

Dim PhysicsProfileName
PhysicsProfileName = "MODERN_STERN"

' --- Values the active profile expects -------------------------------------
'
' These mirror what is set in the table data. They are not the live source of
' truth for the simulation (VPX reads the table data, not these), which is why
' AssertPhysicsProfile checks them against the running table at startup rather
' than assuming.

' Ball mass stays at the VPW standard. The flipper stack is calibrated around
' it, so changing it to alter perceived speed would invalidate every polarity
' and velocity point in 40-physics-nfozzy.vbs. If the game feels wrong, the
' responsible parameter is strength, elasticity_falloff, ramp-up or friction.
Const PHYS_BALL_MASS = 1.0

' Playfield friction. VPW references: LOTR (Stern 2003) 0.24, Medieval Madness
' 0.22, Tron Legacy 0.20. Taking the Stern value.
Const PHYS_PLAYFIELD_FRICTION = 0.24

' Slope in degrees, pinned equal at both ends so the incline cannot drift with
' a setting. Every feed velocity is calibrated against this number.
Const PHYS_TABLE_SLOPE = 6.0

' Flipper coil strength, from the LOTR reference.
Const PHYS_FLIPPER_STRENGTH = 3200.0

' End-of-stroke torque baseline held on the flipper part. The VPW script
' swaps between this and EOSTnew while the coil is at rest or at end of
' stroke; this is only the resting value.
Const PHYS_FLIPPER_EOS_TORQUE = 0.275
Const PHYS_FLIPPER_EOS_ANGLE  = 6.0
Const PHYS_FLIPPER_RETURN     = 0.055
Const PHYS_FLIPPER_RAMPUP     = 2.5

' --- Startup assertions ----------------------------------------------------

' Fails loudly rather than quietly mis-simulating. A Global Physics Set is the
' single most destructive thing that can happen to this table, and it is
' invisible from inside the script unless something checks.
Sub AssertNoGlobalPhysics()
    Dim bad : bad = ""

    If Table1.OverridePhysics <> 0 Then _
        bad = bad & "table OverridePhysics=" & Table1.OverridePhysics & "; "
    If LeftFlipper.OverridePhysics <> 0 Then _
        bad = bad & "LeftFlipper OverridePhysics=" & LeftFlipper.OverridePhysics & "; "
    If RightFlipper.OverridePhysics <> 0 Then _
        bad = bad & "RightFlipper OverridePhysics=" & RightFlipper.OverridePhysics & "; "

    If bad <> "" Then
        DebugLog "physics", "FATAL,global physics override active," & bad
        MsgBox "Tilt Lab: a VPX Global Physics Set is overriding the table." & vbNewLine & vbNewLine & _
               bad & vbNewLine & vbNewLine & _
               "The nFozzy/VPW corrections are calibrated against the per-part " & _
               "values and are not valid while this is on. See docs/physics.md."
    Else
        DebugLog "physics", "global physics override: none (correct)"
    End If
End Sub

' Reports the live table values next to what the profile expects, so a
' mismatch is visible in the log instead of being guessed at.
Sub AssertPhysicsProfile()
    DebugLog "physics", "profile=" & PhysicsProfileName
    DebugLog "physics", "slope,expected=" & PHYS_TABLE_SLOPE & _
        ",actual=" & Table1.SlopeMin & ".." & Table1.SlopeMax
    DebugLog "physics", "friction,expected=" & PHYS_PLAYFIELD_FRICTION & _
        ",actual=" & Table1.Friction
    DebugLog "physics", "gravity,actual=" & Table1.Gravity
    DebugLog "physics", "flipperStrength,expected=" & PHYS_FLIPPER_STRENGTH & _
        ",actual=" & LeftFlipper.Strength & "/" & RightFlipper.Strength
    DebugLog "physics", "flipperMass,actual=" & LeftFlipper.Mass & _
        ",elasticity=" & LeftFlipper.Elasticity & _
        ",falloff=" & LeftFlipper.ElasticityFalloff & _
        ",friction=" & LeftFlipper.Friction
    DebugLog "physics", "eos,rest=" & LeftFlipper.EOSTorque & _
        ",angle=" & LeftFlipper.EOSTorqueAngle & _
        ",EOSTnew=" & EOSTnew & ",EOSReturn=" & EOSReturn
    DebugLog "physics", "rampup,flipper=" & LeftFlipper.RampUp & _
        ",SOSRampup=" & SOSRampup & ",mode=" & FlipperCoilRampupMode
    DebugLog "physics", "liveCatch=" & LiveCatch & _
        ",liveElasticity=" & LiveElasticity & _
        ",distMin=" & LiveDistanceMin & ",distMax=" & LiveDistanceMax & _
        ",baseDampen=" & BaseDampen
    DebugLog "physics", "cradleCollisionDamping=" & FCCDamping
    DebugLog "physics", "targetBouncer=" & TargetBouncerEnabled & _
        ",factor=" & TargetBouncerFactor
End Sub

' One-line physics snapshot for a drill log header, so a training session can
' always be traced back to the physics it was recorded under.
Function PhysicsSignature()
    PhysicsSignature = PhysicsProfileName & _
        ",slope=" & Table1.SlopeMax & _
        ",friction=" & Table1.Friction & _
        ",strength=" & LeftFlipper.Strength & _
        ",rampupMode=" & FlipperCoilRampupMode
End Function
