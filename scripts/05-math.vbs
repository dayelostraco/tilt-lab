'============================================================================
'  ZMAT: MATH HELPERS (VPW)
'============================================================================
'
'  Ported verbatim from the VPW release of Lord of the Rings (Stern 2003),
'  "Yahoo! Edition", whose script carries the most current nFozzy/VPW stack of
'  any reference available to this project: the polarity class is marked
'  "modified 2023 by nFozzy" and "modified 2024 by rothbauerw".
'
'  Original authorship: nFozzy (flipper corrections), rothbauerw (EOS torque
'  recommendations, ReProcessBalls, live catch), apophis and the VPW team.
'  See ATTRIBUTION.md. Comments from the original are preserved deliberately:
'  they carry the reasoning behind the constants.
'
'  DO NOT retune these values to make a drill easier. See docs/physics.md.
'
'  Assembled early because PI is initialised at global scope and the physics
'  modules evaluate against it.
'
'============================================================================

Dim PI: PI = 4*Atn(1)

Function dSin(degrees)
	dsin = sin(degrees * Pi/180)
End Function

Function dCos(degrees)
	dcos = cos(degrees * Pi/180)
End Function

Function Atn2(dy, dx)
	If dx > 0 Then
		Atn2 = Atn(dy / dx)
	ElseIf dx < 0 Then
		If dy = 0 Then 
			Atn2 = pi
		Else
			Atn2 = Sgn(dy) * (pi - Atn(Abs(dy / dx)))
		end if
	ElseIf dx = 0 Then
		if dy = 0 Then
			Atn2 = 0
		else
			Atn2 = Sgn(dy) * pi / 2
		end if
	End If
End Function

Function max(a,b)
	if a > b then 
		max = a
	Else
		max = b
	end if
end Function

Function min(a,b)
	if a > b then 
		min = b
	Else
		min = a
	end if
end Function

'*** Determines if a Points (px,py) is inside a 4 point polygon A-D in Clockwise/CCW order
Function InRect(px,py,ax,ay,bx,by,cx,cy,dx,dy)
	Dim AB, BC, CD, DA
	AB = (bx*py) - (by*px) - (ax*py) + (ay*px) + (ax*by) - (ay*bx)
	BC = (cx*py) - (cy*px) - (bx*py) + (by*px) + (bx*cy) - (by*cx)
	CD = (dx*py) - (dy*px) - (cx*py) + (cy*px) + (cx*dy) - (cy*dx)
	DA = (ax*py) - (ay*px) - (dx*py) + (dy*px) + (dx*ay) - (dy*ax)

	If (AB <= 0 AND BC <=0 AND CD <= 0 AND DA <= 0) Or (AB >= 0 AND BC >=0 AND CD >= 0 AND DA >= 0) Then
		InRect = True
	Else
		InRect = False       
	End If
End Function

'
Function RotPoint(x,y,angle)
	dim rx, ry
	rx = x*dCos(angle) - y*dSin(angle)
	ry = x*dSin(angle) + y*dCos(angle)
	RotPoint = Array(rx,ry)
End Function



'** Ball location checker
