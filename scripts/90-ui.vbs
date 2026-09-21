'============================================================================
'  ZUI: TRAINING DISPLAY (DMD)
'============================================================================
'
'  A 160x40 dot-matrix panel lying flat on the apron, below the flippers.
'
'  --- Why a Flasher in DMD mode, and not the two obvious alternatives ------
'
'  A TextBox is screen-space. In VR it floats in front of the playfield and
'  reads as a rendering fault, so it is desktop-only by nature.
'
'  A Decal looked ideal: real playfield geometry with a writable Text
'  property. It is not. Decal::put_Text stores the string and recomputes
'  sizing, but the text TEXTURE is rasterised once in Decal::RenderSetup and
'  never regenerated. Assignments succeed and change nothing on screen. Four
'  decals were wired up here and silently displayed nothing.
'
'  A Flasher in DMD mode is the one dynamic display VPX offers that is also
'  world geometry. IFlasher exposes DMDWidth, DMDHeight and DMDPixels, and
'  Flasher::put_DMDPixels rebuilds the texture on every assignment.
'
'  --- The pixel contract, from Flasher::put_DMDPixels ----------------------
'
'    - Set DMDWidth and DMDHeight FIRST, or the assignment returns E_FAIL.
'    - DMDPixels takes a 1-D array of at least Width*Height entries,
'      read as unsigned 4-byte integers.
'    - Each value is LUMINANCE ON A 0..100 SCALE, not 0..255: the engine
'      multiplies by 1/100. Values above 100 simply overdrive.
'    - Row-major, origin top-left.
'
'  The panel is only rebuilt when the text actually changes. Pushing 6400
'  array elements on every frame would be wasteful, and nothing here changes
'  faster than once per attempt.
'
'============================================================================

Const DMD_W = 160
Const DMD_H = 40
' *** These MUST be written into the buffer as 4-byte values. ***
'
' Flasher::put_DMDPixels reads each array entry with V_UI4, which takes the
' variant's 32-bit field with NO type conversion. A VBScript numeric literal
' is VT_I2, two bytes, so V_UI4 reads those two bytes plus two bytes of
' whatever happened to be next in the variant. The luminance then comes out
' enormous instead of 0..100 and the panel renders as a solid blown-out white
' blob, which is exactly what it did.
'
' CLng() produces VT_I4. For non-negative values V_UI4 reads that identically,
' so every write into DmdBuf goes through CLng.
Const DMD_ON = 100          ' full luminance (engine divides by 100)
' Unlit dots are fully off, not dimly lit. The flasher blends additively
' over the apron, so any non-zero floor renders the whole panel as a
' washed-out beige slab sitting on the playfield. At 0 only the text glows.
Const DMD_DIM = 0

' 5 wide, 7 tall, advancing 6 columns. 26 chars per line, 5 lines of 8.
Const GLYPH_W = 5
Const GLYPH_H = 7
Const GLYPH_ADV = 6
Const LINE_ADV = 8

Dim DmdBuf()
ReDim DmdBuf(DMD_W * DMD_H - 1)

Dim DmdGlyphIndex      ' character -> position in DmdGlyphs
Dim DmdGlyphs          ' array of 5-element column-bitmask arrays
Dim DmdLastText        ' so an unchanged panel is not rebuilt

' --- Font -------------------------------------------------------------------
'
' Written out as pictures rather than hex so it can actually be edited. Each
' glyph is 7 rows of 5 characters; "#" is lit. Parsed once into column masks
' at startup, which is the form the blitter wants.

Dim DmdFontRows, DmdFontChars, DmdFontCount
DmdFontCount = 0
ReDim DmdFontChars(63)
ReDim DmdGlyphs(63)

Sub Glyph(ch, r0, r1, r2, r3, r4, r5, r6)
    Dim rows, col, row, mask, cols
    rows = Array(r0, r1, r2, r3, r4, r5, r6)
    ReDim cols(GLYPH_W - 1)
    For col = 0 To GLYPH_W - 1
        mask = 0
        For row = 0 To GLYPH_H - 1
            If Mid(rows(row), col + 1, 1) = "#" Then mask = mask Or (2 ^ row)
        Next
        cols(col) = mask
    Next
    DmdFontChars(DmdFontCount) = ch
    DmdGlyphs(DmdFontCount) = cols
    DmdFontCount = DmdFontCount + 1
End Sub

Sub InitDmdFont()
    Glyph " ", ".....", ".....", ".....", ".....", ".....", ".....", "....."
    Glyph "A", ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"
    Glyph "B", "####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."
    Glyph "C", ".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."
    Glyph "D", "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."
    Glyph "E", "#####", "#....", "#....", "####.", "#....", "#....", "#####"
    Glyph "F", "#####", "#....", "#....", "####.", "#....", "#....", "#...."
    Glyph "G", ".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."
    Glyph "H", "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"
    Glyph "I", ".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."
    Glyph "J", "..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."
    Glyph "K", "#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"
    Glyph "L", "#....", "#....", "#....", "#....", "#....", "#....", "#####"
    Glyph "M", "#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"
    Glyph "N", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"
    Glyph "O", ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."
    Glyph "P", "####.", "#...#", "#...#", "####.", "#....", "#....", "#...."
    Glyph "Q", ".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"
    Glyph "R", "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"
    Glyph "S", ".####", "#....", "#....", ".###.", "....#", "....#", "####."
    Glyph "T", "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."
    Glyph "U", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."
    Glyph "V", "#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."
    Glyph "W", "#...#", "#...#", "#...#", "#...#", "#.#.#", "##.##", "#...#"
    Glyph "X", "#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"
    Glyph "Y", "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."
    Glyph "Z", "#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"
    Glyph "0", ".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."
    Glyph "1", "..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."
    Glyph "2", ".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"
    Glyph "3", "#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."
    Glyph "4", "...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."
    Glyph "5", "#####", "#....", "####.", "....#", "....#", "#...#", ".###."
    Glyph "6", "..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."
    Glyph "7", "#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."
    Glyph "8", ".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."
    Glyph "9", ".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."
    Glyph "-", ".....", ".....", ".....", "#####", ".....", ".....", "....."
    Glyph "/", "....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."
    Glyph "%", "##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"
    Glyph ".", ".....", ".....", ".....", ".....", ".....", ".##..", ".##.."
    Glyph ":", ".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."
    Glyph "(", "...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."
    Glyph ")", ".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."
    Glyph "!", "..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."
    Glyph "+", ".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."
End Sub

InitDmdFont

' --- Blitting ---------------------------------------------------------------

Sub DmdClear()
    Dim i
    For i = 0 To DMD_W * DMD_H - 1
        DmdBuf(i) = CLng(DMD_DIM)
    Next
End Sub

Function DmdGlyphFor(ch)
    Dim i
    For i = 0 To DmdFontCount - 1
        If DmdFontChars(i) = ch Then
            DmdGlyphFor = DmdGlyphs(i)
            Exit Function
        End If
    Next
    DmdGlyphFor = DmdGlyphs(0)      ' unknown characters render as a space
End Function

Sub DmdDrawChar(ch, px, py)
    Dim cols, col, row, x, y
    cols = DmdGlyphFor(ch)
    For col = 0 To GLYPH_W - 1
        x = px + col
        If x >= 0 And x < DMD_W Then
            For row = 0 To GLYPH_H - 1
                If (cols(col) And (2 ^ row)) <> 0 Then
                    y = py + row
                    If y >= 0 And y < DMD_H Then DmdBuf(y * DMD_W + x) = CLng(DMD_ON)
                End If
            Next
        End If
    Next
End Sub

' Draws one line of text. `line` is 0-based; 5 fit on the panel.
Sub DmdDrawLine(line, text)
    Dim i, s
    s = UCase(text)
    For i = 1 To Len(s)
        DmdDrawChar Mid(s, i, 1), (i - 1) * GLYPH_ADV, line * LINE_ADV
    Next
End Sub

' Centres a line, which matters for the verdict: a left-aligned word that
' changes length jitters and is harder to read at a glance.
Sub DmdDrawCentered(line, text)
    Dim s, pad
    s = UCase(text)
    pad = (DMD_W \ GLYPH_ADV - Len(s)) \ 2
    If pad < 0 Then pad = 0
    DmdDrawLine line, Space(pad) & s
End Sub

Sub DmdFlush()
    TrainingDMD.DMDPixels = DmdBuf
End Sub

' --- The display -------------------------------------------------------------

Sub InitTrainingDisplay()
    TrainingDMD.DMDWidth = DMD_W       ' size must be set before any pixel push
    TrainingDMD.DMDHeight = DMD_H
    TrainingDMD.DMD = True             ' switch the flasher into DMD render mode
    DmdLastText = ""
    UpdateTrainingDisplay
End Sub

Sub UpdateTrainingDisplay()
    Dim l0, l1, l2, l3, key

    If DrillActive Then
        l0 = DrillName(DrillId) & " - " & SideName(AttemptSide())
        l1 = DifficultyName(DrillDifficulty)
        l2 = "ATTEMPT " & DrillAttempt & "/" & DrillTotal & _
             "  OK " & DrillSuccess & "  " & DrillAccuracy() & "%"
        If DrillLastVerdict >= 0 Then l3 = VerdictName(DrillLastVerdict) Else l3 = ""
    Else
        l0 = "TILT LAB"
        l1 = "PRESS 1 TO START"
        If DrillAttempt > 0 Then
            l2 = "LAST SET " & DrillSuccess & "/" & DrillAttempt & "  " & DrillAccuracy() & "%"
        Else
            l2 = "D FOR DEBUG"
        End If
        l3 = ""
    End If

    ' Rebuilding 6400 pixels is only worth doing when something changed.
    key = l0 & "|" & l1 & "|" & l2 & "|" & l3
    If key = DmdLastText Then Exit Sub
    DmdLastText = key

    DmdClear
    DmdDrawLine 0, l0
    DmdDrawLine 1, l1
    DmdDrawLine 2, l2
    DmdDrawCentered 4, l3
    DmdFlush
End Sub
