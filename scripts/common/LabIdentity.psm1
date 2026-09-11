#Requires -Version 7.0
<#
.SYNOPSIS
    Shared helpers for the entra-hybrid-proof JML scripts.

.DESCRIPTION
    LAB ONLY. Load config, refuse break-glass targets, print a plan, and
    optionally call Microsoft Graph. Plan mode does not require Connect-MgGraph.
#>

Set-StrictMode -Version Latest

function Write-LabBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Scenario
    )

    Write-Host ""
    Write-Host "LAB ONLY — entra-hybrid-proof — $Scenario" -ForegroundColor Yellow
    Write-Host "Not a customer/employer tenant. Default is plan mode (no directory writes)." -ForegroundColor Yellow
    Write-Host ""
}

function Get-LabConfig {
    <#
    .SYNOPSIS
        Load a JML JSON config. Does not contact Entra.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config not found: $Path. Copy scripts/config.example.json to scripts/config.json and edit UPNs."
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $config = $raw | ConvertFrom-Json
    if (-not $config.labName) {
        throw "Config is missing labName. Use config.example.json as the template."
    }

    return $config
}

function Test-LabBreakGlassTarget {
    <#
    .SYNOPSIS
        Throw if the target UPN is a configured break-glass account.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [Parameter(Mandatory)]
        [string]$UserPrincipalName
    )

    $blocked = @($Config.breakGlassUpns) | ForEach-Object { $_.ToLowerInvariant() }
    if ($blocked -contains $UserPrincipalName.ToLowerInvariant()) {
        throw "Refusing JML on break-glass UPN '$UserPrincipalName'. Emergency accounts are out of scope for joiner/mover/leaver."
    }
}

function Get-LabActionMode {
    <#
    .SYNOPSIS
        Resolve plan vs execute. -WhatIf always wins.
    #>
    [CmdletBinding()]
    param(
        [switch]$Execute,
        [switch]$WhatIfPreference
    )

    if ($WhatIfPreference -or -not $Execute) {
        return "Plan"
    }

    return "Execute"
}

function Write-LabAction {
    <#
    .SYNOPSIS
        Print a planned or executed Graph step in a stable, greppable format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Plan", "Execute")]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$Cmdlet,

        [Parameter(Mandatory)]
        [string]$Detail
    )

    $tag = if ($Mode -eq "Plan") { "PLAN" } else { "DONE" }
    $color = if ($Mode -eq "Plan") { "Cyan" } else { "Green" }
    Write-Host ("[{0}] {1} — {2}" -f $tag, $Cmdlet, $Detail) -ForegroundColor $color
}

function Test-LabGraphConnected {
    [CmdletBinding()]
    param()

    $cmd = Get-Command Get-MgContext -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $false
    }

    try {
        $ctx = Get-MgContext
        return [bool]$ctx
    }
    catch {
        return $false
    }
}

function Assert-LabGraphConnected {
    [CmdletBinding()]
    param(
        [string[]]$RequiredScopes = @(
            "User.ReadWrite.All",
            "Group.ReadWrite.All",
            "Directory.Read.All"
        )
    )

    if (-not (Test-LabGraphConnected)) {
        throw @"
Not connected to Microsoft Graph.
Install:  Install-Module Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Users.Actions -Scope CurrentUser
Connect:  Connect-MgGraph -Scopes '$($RequiredScopes -join "','")'
Use a tenant you own. Do not point this at a customer directory.
"@
    }
}

function Resolve-LabGroupId {
    <#
    .SYNOPSIS
        Resolve a security/M365 group by display name. Execute mode only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    $matches = @(Get-MgGroup -Filter "displayName eq '$($DisplayName.Replace("'","''"))'" -ConsistencyLevel eventual -CountVariable unused)
    if ($matches.Count -eq 0) {
        throw "Group not found: $DisplayName. Create the LAB-* groups in your tenant or fix config.json."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple groups named '$DisplayName'. JML refuses to guess."
    }

    return $matches[0].Id
}

function Get-LabUserId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserPrincipalName
    )

    $user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
    return $user.Id
}

function New-LabTemporaryPassword {
    <#
    .SYNOPSIS
        Generate an in-memory one-time password. Never written to disk by this module.
    #>
    [CmdletBinding()]
    param(
        [int]$Length = 20
    )

    $alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%"
    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $chars = for ($i = 0; $i -lt $Length; $i++) {
        $alphabet[$bytes[$i] % $alphabet.Length]
    }
    return (-join $chars)
}

function Add-LabUserToGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$GroupId
    )

    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    }
    New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $body -ErrorAction Stop
}

function Remove-LabUserFromGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$GroupId
    )

    Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $UserId -ErrorAction Stop
}

Export-ModuleMember -Function @(
    "Write-LabBanner",
    "Get-LabConfig",
    "Test-LabBreakGlassTarget",
    "Get-LabActionMode",
    "Write-LabAction",
    "Test-LabGraphConnected",
    "Assert-LabGraphConnected",
    "Resolve-LabGroupId",
    "Get-LabUserId",
    "New-LabTemporaryPassword",
    "Add-LabUserToGroup",
    "Remove-LabUserFromGroup"
)
