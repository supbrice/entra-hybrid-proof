#Requires -Version 7.0
<#
.SYNOPSIS
    Mover — change department/title and swap app-group memberships.

.DESCRIPTION
    LAB ONLY. Plan-first mover. Keeps license groups unless you list them
    in add/remove. Does not delete the user. Refuses break-glass UPNs.

.PARAMETER ConfigPath
    JSON config. Copy ../config.example.json to ../config.json.

.PARAMETER Execute
    Write to the connected tenant. Default is plan mode.

.EXAMPLE
    ./Set-LabMover.ps1 -ConfigPath ../config.json
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

Write-LabBanner -Scenario "MOVER"
$config = Get-LabConfig -Path $ConfigPath
$mover = $config.mover
Test-LabBreakGlassTarget -Config $config -UserPrincipalName $mover.userPrincipalName
$mode = Get-LabActionMode -Execute:$Execute -WhatIfPreference:$WhatIfPreference

Write-Host "target UPN : $($mover.userPrincipalName)"
Write-Host "mode       : $mode"
Write-Host ""

Write-LabAction -Mode $mode -Cmdlet "Update-MgUser" -Detail "department='$($mover.newDepartment)' jobTitle='$($mover.newJobTitle)'"

foreach ($name in @($mover.removeGroupNames)) {
    Write-LabAction -Mode $mode -Cmdlet "Remove-MgGroupMemberByRef" -Detail "remove '$($mover.userPrincipalName)' from '$name'"
}

foreach ($name in @($mover.addGroupNames)) {
    Write-LabAction -Mode $mode -Cmdlet "New-MgGroupMemberByRef" -Detail "add '$($mover.userPrincipalName)' to '$name'"
}

Write-LabAction -Mode $mode -Cmdlet "Keep-LicenseGroup" -Detail "license group '$($config.groups.license)' is not in the swap list — SKU stays unless you add it to removeGroupNames"

if ($mode -ne "Execute") {
    Write-Host ""
    Write-Host "Plan complete. Re-run with -Execute against a tenant you own after Connect-MgGraph." -ForegroundColor Yellow
    return
}

Assert-LabGraphConnected
$userId = Get-LabUserId -UserPrincipalName $mover.userPrincipalName
Update-MgUser -UserId $userId -Department $mover.newDepartment -JobTitle $mover.newJobTitle
Write-LabAction -Mode Execute -Cmdlet "Update-MgUser" -Detail "id=$userId department/title updated"

foreach ($name in @($mover.removeGroupNames)) {
    $groupId = Resolve-LabGroupId -DisplayName $name
    Remove-LabUserFromGroup -UserId $userId -GroupId $groupId
    Write-LabAction -Mode Execute -Cmdlet "Remove-MgGroupMemberByRef" -Detail "removed from $name"
}

foreach ($name in @($mover.addGroupNames)) {
    $groupId = Resolve-LabGroupId -DisplayName $name
    Add-LabUserToGroup -UserId $userId -GroupId $groupId
    Write-LabAction -Mode Execute -Cmdlet "New-MgGroupMemberByRef" -Detail "added to $name"
}

Write-Host ""
Write-Host "Mover complete for $($mover.userPrincipalName)." -ForegroundColor Green
