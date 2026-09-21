<#
.SYNOPSIS
    Deploys a Tilt Lab build to a Windows Visual Pinball host and collects
    the diagnostics needed for test procedure T1a.

.DESCRIPTION
    Written as a script file rather than an inline command on purpose:
    PowerShell 5.1 wraps native stderr into NativeCommandError records, so
    ordinary tool output reads as failure through three layers of quoting.

    Run it with:
        powershell -ExecutionPolicy Bypass -File deploy-windows.ps1

.PARAMETER VpxRoot
    Visual Pinball installation root. Defaults to D:\Visual Pinball.

.PARAMETER TablePath
    The .vpx to deploy. Defaults to the copy dropped next to this script.

.PARAMETER LogOnly
    Skip deployment and just report the diagnostics from the last VPX run.
#>
param(
    [string] $VpxRoot   = 'D:\Visual Pinball',
    [string] $TablePath = (Join-Path $PSScriptRoot 'Pinball Training Lab.vpx'),
    [switch] $LogOnly
)

$ErrorActionPreference = 'Stop'

function Section($text) { Write-Host "`n=== $text ===" }

$tablesDir = Join-Path $VpxRoot 'Tables'
$tableName = [IO.Path]::GetFileNameWithoutExtension($TablePath)
$dest      = Join-Path $tablesDir "$tableName.vpx"

Section 'VPX installation'
if (-not (Test-Path $VpxRoot)) { throw "VPX root not found: $VpxRoot" }
Get-ChildItem $VpxRoot -Filter 'VPinballX*.exe' | ForEach-Object {
    $v = $_.VersionInfo
    Write-Host ("  {0}  {1}" -f $_.Name, $v.ProductVersion)
}

if (-not $LogOnly) {
    Section 'Deploy'
    if (-not (Test-Path $TablePath)) { throw "Table not found: $TablePath" }
    if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir | Out-Null }

    # A .vbs sidecar next to the .vpx SHADOWS the embedded script: Visual
    # Pinball loads the sidecar instead. Leaving one in place makes a deploy
    # look like it had no effect.
    $sidecar = Join-Path $tablesDir "$tableName.vbs"
    if (Test-Path $sidecar) {
        $parked = "$sidecar.shadowed"
        Move-Item $sidecar $parked -Force
        Write-Host "  WARNING: moved a shadowing script sidecar aside -> $parked"
    }

    Copy-Item $TablePath $dest -Force
    $info = Get-Item $dest
    Write-Host ("  deployed {0:N1} MB -> {1}" -f ($info.Length / 1MB), $dest)
}

Section 'Log diagnostics'
# VPX writes its log beside the executable or under the user profile,
# depending on the logging settings; check both.
$logCandidates = @(
    (Join-Path $VpxRoot 'VPinballX.log'),
    (Join-Path $env:APPDATA 'VPinballX\VPinballX.log'),
    (Join-Path $env:USERPROFILE 'VPinballX.log')
) | Where-Object { Test-Path $_ }

if (-not $logCandidates) {
    Write-Host '  no VPX log found yet (run the table once, with logging enabled in the in-game UI)'
} else {
    foreach ($log in $logCandidates) {
        $age = (Get-Item $log).LastWriteTime
        Write-Host "  $log  (last written $age)"

        # Any rejected table option is reported here, NOT as a script error,
        # so a missing menu item is only diagnosable from the log.
        $opts = Select-String -Path $log -Pattern 'Table\.Option' -SimpleMatch
        if ($opts) {
            Write-Host '  -- Table.Option messages (each one is a DROPPED menu item) --'
            $opts | ForEach-Object { Write-Host "     $($_.Line.Trim())" }
        } else {
            Write-Host '  -- no Table.Option complaints --'
        }

        $errs = Select-String -Path $log -Pattern 'ERROR|Script Error|Exception'
        if ($errs) {
            Write-Host '  -- errors --'
            $errs | Select-Object -Last 20 | ForEach-Object { Write-Host "     $($_.Line.Trim())" }
        } else {
            Write-Host '  -- no errors --'
        }
    }
}

Section 'Done'
Write-Host "Next: open '$tableName' in VPX and run T1a from docs/test-procedures.md"
