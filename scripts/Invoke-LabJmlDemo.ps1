#Requires -Version 7.0
<#
.SYNOPSIS
    Interview demo — run joiner, mover, and leaver in plan mode.

.DESCRIPTION
    LAB ONLY. Default is three plans against the same config. Pass -Execute
    only in a disposable tenant you own, and only after reading each script README.

.EXAMPLE
    ./Invoke-LabJmlDemo.ps1 -ConfigPath ./config.json
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$common = Join-Path $root "common" "LabIdentity.psm1"
Import-Module $common -Force

Write-LabBanner -Scenario "JML DEMO (joiner → mover → leaver)"
$null = Get-LabConfig -Path $ConfigPath

$extra = @{}
if ($Execute) { $extra["Execute"] = $true }
if ($WhatIfPreference) { $extra["WhatIf"] = $true }

& (Join-Path $root "joiner" "New-LabJoiner.ps1") -ConfigPath $ConfigPath @extra
& (Join-Path $root "mover" "Set-LabMover.ps1") -ConfigPath $ConfigPath @extra
& (Join-Path $root "leaver" "Invoke-LabLeaver.ps1") -ConfigPath $ConfigPath @extra

Write-Host ""
Write-Host "Demo finished. Review [PLAN] lines with a hiring manager; use -Execute only on a tenant you own." -ForegroundColor Yellow
