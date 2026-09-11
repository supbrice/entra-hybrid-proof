#Requires -Version 7.0
<#
.SYNOPSIS
    Leaver — disable sign-in, revoke sessions, remove group access. Does not delete.

.DESCRIPTION
    LAB ONLY. Plan-first leaver. Order is intentional:

      1. Block sign-in (accountEnabled = false)
      2. Revoke refresh tokens
      3. Remove group memberships (license + app access drop)
      4. Remind the operator of the disabled-account hold period

    Hard-delete is out of scope (legal / mailbox retention). Break-glass UPNs are refused.

.PARAMETER ConfigPath
    JSON config. Copy ../config.example.json to ../config.json.

.PARAMETER Execute
    Write to the connected tenant. Default is plan mode.

.EXAMPLE
    ./Invoke-LabLeaver.ps1 -ConfigPath ../config.json
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot ".." "common" "LabIdentity.psm1"
Import-Module $modulePath -Force

Write-LabBanner -Scenario "LEAVER"
$config = Get-LabConfig -Path $ConfigPath
$leaver = $config.leaver
Test-LabBreakGlassTarget -Config $config -UserPrincipalName $leaver.userPrincipalName
$mode = Get-LabActionMode -Execute:$Execute -WhatIfPreference:$WhatIfPreference

Write-Host "target UPN : $($leaver.userPrincipalName)"
Write-Host "mode       : $mode"
Write-Host ""

Write-LabAction -Mode $mode -Cmdlet "Update-MgUser" -Detail "accountEnabled=false (block sign-in) for '$($leaver.userPrincipalName)'"

if ($leaver.revokeSessions) {
    Write-LabAction -Mode $mode -Cmdlet "Revoke-MgUserSignInSession" -Detail "invalidate refresh tokens"
}

if ($leaver.removeGroupMemberships) {
    $known = @(
        $config.groups.allUsers,
        $config.groups.license,
        $config.groups.engineering,
        $config.groups.finance
    ) | Where-Object { $_ }
    foreach ($name in $known) {
        Write-LabAction -Mode $mode -Cmdlet "Remove-MgGroupMemberByRef" -Detail "remove from '$name' if present"
    }
}

Write-LabAction -Mode $mode -Cmdlet "Retain-DisabledAccount" -Detail "keep the account $($leaver.keepDisabledAccountDays) day(s); do not Remove-MgUser in this script"

if ($mode -ne "Execute") {
    Write-Host ""
    Write-Host "Plan complete. Re-run with -Execute against a tenant you own after Connect-MgGraph." -ForegroundColor Yellow
    return
}

Assert-LabGraphConnected
$userId = Get-LabUserId -UserPrincipalName $leaver.userPrincipalName

Update-MgUser -UserId $userId -AccountEnabled:$false
Write-LabAction -Mode Execute -Cmdlet "Update-MgUser" -Detail "id=$userId sign-in blocked"

if ($leaver.revokeSessions) {
    Revoke-MgUserSignInSession -UserId $userId | Out-Null
    Write-LabAction -Mode Execute -Cmdlet "Revoke-MgUserSignInSession" -Detail "sessions revoked"
}

if ($leaver.removeGroupMemberships) {
    $memberships = Get-MgUserMemberOf -UserId $userId -All
    $protectedNames = @($config.groups.breakGlass, $config.groups.pimApprovers)
    foreach ($object in $memberships) {
        $odataType = $object.AdditionalProperties["@odata.type"]
        if ($odataType -ne "#microsoft.graph.group") {
            continue
        }
        $displayName = $object.AdditionalProperties["displayName"]
        if ($protectedNames -contains $displayName) {
            Write-Warning "Skipping protected group '$displayName'."
            continue
        }
        Remove-LabUserFromGroup -UserId $userId -GroupId $object.Id
        Write-LabAction -Mode Execute -Cmdlet "Remove-MgGroupMemberByRef" -Detail "removed from $displayName"
    }
}

Write-Host ""
Write-Host "Leaver complete. Account remains for $($leaver.keepDisabledAccountDays) day(s) — no delete." -ForegroundColor Green
