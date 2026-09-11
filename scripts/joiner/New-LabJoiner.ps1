#Requires -Version 7.0
<#
.SYNOPSIS
    Joiner — create (or wait for) a lab user and add license / app groups.

.DESCRIPTION
    LAB ONLY. Plan-first Microsoft Graph joiner for entra-hybrid-proof.

    CloudOnly: New-MgUser + usageLocation + group memberships.
    HybridSync: does not create the AD account; expects the user to exist
    after Connect / Cloud Sync, then applies cloud groups.

    Does not assign Entra directory roles. Does not touch break-glass UPNs.

.PARAMETER ConfigPath
    JSON config. Copy ../config.example.json to ../config.json.

.PARAMETER Execute
    Write to the connected tenant. Default is plan mode.

.EXAMPLE
    ./New-LabJoiner.ps1 -ConfigPath ../config.json

.EXAMPLE
    Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.Read.All"
    ./New-LabJoiner.ps1 -ConfigPath ../config.json -Execute
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

Write-LabBanner -Scenario "JOINER"
$config = Get-LabConfig -Path $ConfigPath
$joiner = $config.joiner
Test-LabBreakGlassTarget -Config $config -UserPrincipalName $joiner.userPrincipalName
$mode = Get-LabActionMode -Execute:$Execute -WhatIfPreference:$WhatIfPreference

Write-Host "identitySource : $($config.identitySource)"
Write-Host "target UPN     : $($joiner.userPrincipalName)"
Write-Host "mode           : $mode"
Write-Host ""

if ($config.identitySource -eq "HybridSync") {
    Write-LabAction -Mode $mode -Cmdlet "Wait-HybridSync" -Detail "User is created in on-prem AD (sibling configure-ad lab), then synced. This script will not New-MgUser."
}
else {
    Write-LabAction -Mode $mode -Cmdlet "New-MgUser" -Detail "displayName='$($joiner.displayName)' upn='$($joiner.userPrincipalName)' mailNickname='$($joiner.mailNickname)' accountEnabled=true (one-time password printed, not saved)"
}

Write-LabAction -Mode $mode -Cmdlet "Update-MgUser" -Detail "usageLocation='$($config.usageLocation)' department='$($joiner.department)' jobTitle='$($joiner.jobTitle)'"

if ($joiner.managerUpn) {
    Write-LabAction -Mode $mode -Cmdlet "Set-MgUserManagerByRef" -Detail "manager='$($joiner.managerUpn)'"
}

foreach ($name in @($joiner.groupNames)) {
    Write-LabAction -Mode $mode -Cmdlet "New-MgGroupMemberByRef" -Detail "add '$($joiner.userPrincipalName)' to group '$name'"
}

if ($config.assignDirectLicense) {
    Write-LabAction -Mode $mode -Cmdlet "Set-MgUserLicense" -Detail "direct SKU '$($config.skuPartNumber)' skuId='$($config.skuId)' (escape hatch — prefer LAB-LIC-* group)"
}
else {
    Write-LabAction -Mode $mode -Cmdlet "GroupBasedLicensing" -Detail "license is expected from membership in '$($config.groups.license)' — no Set-MgUserLicense"
}

if ($mode -ne "Execute") {
    Write-Host ""
    Write-Host "Plan complete. Re-run with -Execute against a tenant you own after Connect-MgGraph." -ForegroundColor Yellow
    return
}

Assert-LabGraphConnected

if ($config.identitySource -eq "HybridSync") {
    $userId = Get-LabUserId -UserPrincipalName $joiner.userPrincipalName
    Write-LabAction -Mode Execute -Cmdlet "Get-MgUser" -Detail "synced user id=$userId"
}
else {
    $password = New-LabTemporaryPassword
    $body = @{
        AccountEnabled    = $true
        DisplayName       = $joiner.displayName
        MailNickname      = $joiner.mailNickname
        UserPrincipalName = $joiner.userPrincipalName
        UsageLocation     = $config.usageLocation
        Department        = $joiner.department
        JobTitle          = $joiner.jobTitle
        PasswordProfile   = @{
            ForceChangePasswordNextSignIn = $true
            Password                      = $password
        }
    }
    $created = New-MgUser -BodyParameter $body
    $userId = $created.Id
    Write-LabAction -Mode Execute -Cmdlet "New-MgUser" -Detail "id=$userId"
    Write-Host "One-time password (not written to disk): $password" -ForegroundColor Magenta
}

Update-MgUser -UserId $userId -UsageLocation $config.usageLocation -Department $joiner.department -JobTitle $joiner.jobTitle
Write-LabAction -Mode Execute -Cmdlet "Update-MgUser" -Detail "usageLocation/department/title set"

if ($joiner.managerUpn) {
    try {
        $managerId = Get-LabUserId -UserPrincipalName $joiner.managerUpn
        $ref = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/users/$managerId" }
        Set-MgUserManagerByRef -UserId $userId -BodyParameter $ref
        Write-LabAction -Mode Execute -Cmdlet "Set-MgUserManagerByRef" -Detail "manager id=$managerId"
    }
    catch {
        Write-Warning "Manager '$($joiner.managerUpn)' not set: $($_.Exception.Message)"
    }
}

foreach ($name in @($joiner.groupNames)) {
    $groupId = Resolve-LabGroupId -DisplayName $name
    Add-LabUserToGroup -UserId $userId -GroupId $groupId
    Write-LabAction -Mode Execute -Cmdlet "New-MgGroupMemberByRef" -Detail "added to $name ($groupId)"
}

if ($config.assignDirectLicense) {
    if ($config.skuId -eq "00000000-0000-0000-0000-000000000000") {
        throw "assignDirectLicense is true but skuId is still the placeholder GUID. Set a real SKU in config.json."
    }
    Set-MgUserLicense -UserId $userId -AddLicenses @{ SkuId = $config.skuId } -RemoveLicenses @()
    Write-LabAction -Mode Execute -Cmdlet "Set-MgUserLicense" -Detail $config.skuPartNumber
}

Write-Host ""
Write-Host "Joiner complete for $($joiner.userPrincipalName)." -ForegroundColor Green
