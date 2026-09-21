# Headless physics run using -CaptureAttract.
#
# VPX pauses physics when the playfield window is unfocused, which makes a
# task-launched session useless for simulation. CaptureAttract is the one mode
# where Player::IsPlaying() ignores window focus entirely (player.h:69), so the
# physics engine actually steps.
#
# It is run against OUR copy of the table in the working directory, never the
# one in D:\Visual Pinball\Tables, so the Capture folder it creates cannot
# land in the user's install.
$ErrorActionPreference = 'Continue'
$work   = 'C:\Development\GitHub\tilt-lab'
$log    = "$env:APPDATA\VPinballX\10.8\vpinball.log"
$table  = Join-Path $work 'Pinball Training Lab.vpx'
$mode   = if ($args.Count -gt 0) { $args[0] } else { 'probe' }
$frames = if ($args.Count -gt 1) { [int]$args[1] } else { 150 }
$fps    = if ($args.Count -gt 2) { [int]$args[2] } else { 10 }

if (Test-Path $log) { Remove-Item $log -Force -ErrorAction SilentlyContinue }
Get-ChildItem $work -Filter 'Capture' -Directory -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Push-Location $work
$p = Start-Process -FilePath 'D:\Visual Pinball\VPinballX_BGFX64.exe' `
     -ArgumentList @('-Ini', "`"$work\vpx-test.ini`"", '-c1', $mode,
                     '-CaptureAttract', $frames, $fps, "`"$table`"", 'noloop') `
     -PassThru -WorkingDirectory $work
if (-not $p.WaitForExit(180000)) { Write-Host '  timed out; stopping'; Stop-Process -Id $p.Id -Force }
Pop-Location
Get-Process -Name 'VPinballX*' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "=== play state ==="
if (Test-Path $log) {
    Select-String -Path $log -Pattern 'Pausing|Unpausing|Capture' | Select-Object -First 6 |
        ForEach-Object { "  " + $_.Line.Trim() }
    Write-Host "`n=== script errors ==="
    $e = Select-String -Path $log -Pattern 'Script Error|Runtime error|Compile error'
    if ($e) { $e | ForEach-Object { "  " + $_.Line.Trim() } } else { Write-Host "  none" }
    Write-Host "`n=== tiltlab ==="
    Select-String -Path $log -Pattern 'TILTLAB,' | Select-Object -Last 40 |
        ForEach-Object { "  " + ($_.Line -replace '^.*TILTLAB,', '') }
} else { Write-Host "  no log" }

$cap = Join-Path $work 'Capture'
if (Test-Path $cap) {
    Write-Host "`n=== capture output (cleaning up) ==="
    Write-Host ("  " + (Get-ChildItem $cap -Recurse -File | Measure-Object).Count + " files")
    Remove-Item $cap -Recurse -Force -ErrorAction SilentlyContinue
}
