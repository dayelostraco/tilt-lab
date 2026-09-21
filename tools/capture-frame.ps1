# Captures real rendered frames so the DMD can actually be looked at.
$ErrorActionPreference='Continue'
$work='C:\Development\GitHub\tilt-lab'
$table=Join-Path $work 'Pinball Training Lab.vpx'
$mode = if ($args.Count -gt 0) { $args[0] } else { 'drill' }
$cap = Join-Path $work 'Capture'
if (Test-Path $cap) { Remove-Item $cap -Recurse -Force -ErrorAction SilentlyContinue }
Push-Location $work
$p = Start-Process -FilePath 'D:\Visual Pinball\VPinballX_BGFX64.exe' `
     -ArgumentList @('-Ini',"`"$work\vpx-test.ini`"",'-c1',$mode,
                     '-CaptureAttract',400,4,"`"$table`"",'noloop') -PassThru -WorkingDirectory $work
if (-not $p.WaitForExit(180000)) { Stop-Process -Id $p.Id -Force }
Pop-Location
Get-Process -Name 'VPinballX*' -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path $cap) {
    $f = Get-ChildItem $cap -Recurse -File | Sort-Object Name
    "captured $($f.Count) frames"
    # keep a late frame, by which point a drill has produced a verdict
    $pick = $f[[Math]::Min($f.Count-1, [int]($f.Count*0.16))]
    Copy-Item $pick.FullName (Join-Path $work 'dmd-shot.png') -Force
    "picked $($pick.Name) -> dmd-shot.png"
    Remove-Item $cap -Recurse -Force -ErrorAction SilentlyContinue
} else { "no capture folder" }
