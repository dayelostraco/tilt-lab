# Runs the table for real, in the interactive console session, so the script
# actually executes. Cleans up after itself: the scheduled task is deleted and
# any VPX process is stopped regardless of outcome.
$ErrorActionPreference = 'Continue'
$work = 'C:\Development\GitHub\tilt-lab'
$log  = "$env:APPDATA\VPinballX\10.8\vpinball.log"
$task = 'TiltLabSmokeTest'
$cmd  = Join-Path $work 'run-vpx.cmd'
$secs = if ($args.Count -gt 0) { [int]$args[0] } else { 30 }
$mode = if ($args.Count -gt 1) { $args[1] } else { '' }
$c1   = if ($mode) { "-c1 $mode " } else { '' }

# A .cmd wrapper avoids nesting quotes inside schtasks /TR.
@"
@echo off
"D:\Visual Pinball\VPinballX_BGFX64.exe" -Ini "$work\vpx-test.ini" $c1-Play "D:\Visual Pinball\Tables\Pinball Training Lab.vpx"
"@ | Set-Content -Path $cmd -Encoding ASCII

if (Test-Path $log) { Remove-Item $log -Force -ErrorAction SilentlyContinue }

# /IT = interactive: runs in the logged-on user's session, which is the only
# place a GPU renderer can create a window.
& schtasks /create /F /TN $task /TR "`"$cmd`"" /SC ONCE /ST 23:59 /IT /RL LIMITED 2>&1 | Out-String | Write-Host
& schtasks /run /TN $task 2>&1 | Out-String | Write-Host

# VPX pauses the physics engine whenever the playfield window is not focused
# (Player::OnFocusChanged -> SetPlayState). A task-launched window starts
# unfocused, so without this the table renders and runs timers but never steps
# physics: balls sit motionless and every feed looks broken.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Fg {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
}
"@
Start-Sleep -Seconds 6
$vp = Get-Process -Name 'VPinballX*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($vp) {
    $i = 0
    while ($vp.MainWindowHandle -eq 0 -and $i -lt 20) { Start-Sleep -Milliseconds 500; $vp.Refresh(); $i++ }
    if ($vp.MainWindowHandle -ne 0) {
        [void][Fg]::ShowWindow($vp.MainWindowHandle, 9)   # SW_RESTORE
        [void][Fg]::BringWindowToTop($vp.MainWindowHandle)
        [void][Fg]::SetForegroundWindow($vp.MainWindowHandle)
        Write-Host "  focused window 0x$($vp.MainWindowHandle.ToString('X')) of pid $($vp.Id)"
    } else { Write-Host "  WARNING: no main window handle; physics will stay paused" }
} else { Write-Host "  WARNING: no VPX process found" }

Write-Host "running for $secs seconds..."
Start-Sleep -Seconds $secs

Get-Process -Name 'VPinballX*' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  stopping pid $($_.Id)"; Stop-Process -Id $_.Id -Force
}
Start-Sleep -Seconds 2
& schtasks /delete /F /TN $task 2>&1 | Out-String | Write-Host
Remove-Item $cmd -Force -ErrorAction SilentlyContinue

Write-Host "`n================ SCRIPT ERRORS ================"
if (Test-Path $log) {
    $e = Select-String -Path $log -Pattern 'Script Error|Runtime error|Type mismatch|Object required|Syntax error|Variable is undefined|Subscript out of range'
    if ($e) { $e | ForEach-Object { "  " + $_.Line.Trim() } } else { Write-Host "  none" }

    Write-Host "`n================ TILTLAB LOG ================"
    $t = Select-String -Path $log -Pattern 'TILTLAB,'
    if ($t) {
        Write-Host "  $($t.Count) lines"
        $t | Select-Object -Last 60 | ForEach-Object {
            "  " + ($_.Line -replace '^.*TILTLAB,', '')
        }
    } else { Write-Host "  NONE - script did not run, or logging is off" }

    Write-Host "`n================ OTHER ERRORS ================"
    Select-String -Path $log -Pattern 'ERROR' | Where-Object { $_.Line -notmatch 'BGLS' } |
        Select-Object -First 15 | ForEach-Object { "  " + $_.Line.Trim() }
} else { Write-Host "  no log produced" }
