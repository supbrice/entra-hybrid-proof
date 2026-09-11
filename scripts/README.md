# JML scripts (joiner / mover / leaver)

**LAB ONLY.** Microsoft Graph PowerShell for a tenant **you** own. Config-driven. Plan-first.

These are starters, not a full IGA product. They print the Graph cmdlets they would call. They do not write to Entra unless you pass `-Execute`.

## Quick start

```powershell
# PowerShell 7
Copy-Item ./config.example.json ./config.json
# edit tenantDomain / UPNs / group names to YOUR lab

./Invoke-LabJmlDemo.ps1 -ConfigPath ./config.json
```

You should see `[PLAN]` lines for create user, group adds, department swap, disable + revoke. No Graph login required for that path.

## Layout

| Path | Role |
| --- | --- |
| [config.example.json](config.example.json) | Safe placeholders (`contoso.onmicrosoft.com`, zero SKU GUID) |
| [common/LabIdentity.psm1](common/LabIdentity.psm1) | Config load, break-glass guard, plan/execute helpers |
| [joiner/](joiner/) | New cloud user or wait-for-sync + groups |
| [mover/](mover/) | Title/department + app-group swap |
| [leaver/](leaver/) | Disable, revoke sessions, remove groups — no delete |
| [Invoke-LabJmlDemo.ps1](Invoke-LabJmlDemo.ps1) | Interview walk-through |

`config.json` is gitignored. Never commit a real tenant.

## Execute path (optional)

```powershell
Install-Module Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Users.Actions -Scope CurrentUser
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.Read.All"
./joiner/New-LabJoiner.ps1 -ConfigPath ./config.json -Execute
```

Prerequisites in the lab tenant: the `LAB-*` groups already exist, and (for HybridSync) the user already synced. Scripts resolve groups by **display name** and refuse to guess if the name is ambiguous.

## Safety rails

- Default mode is **plan** (`-Execute` is opt-in).
- Break-glass UPNs in config cannot be joiner/mover/leaver targets.
- Leaver never calls `Remove-MgUser`.
- Direct license assignment is off unless you set `assignDirectLicense` and a real `skuId`.
- One-time joiner password is printed once; it is not written to disk.

## Graph modules

| Script | Cmdlets (execute path) |
| --- | --- |
| Joiner | `New-MgUser`, `Update-MgUser`, `Set-MgUserManagerByRef`, `New-MgGroupMemberByRef` |
| Mover | `Update-MgUser`, `Remove-MgGroupMemberByRef`, `New-MgGroupMemberByRef` |
| Leaver | `Update-MgUser`, `Revoke-MgUserSignInSession`, `Get-MgUserMemberOf`, `Remove-MgGroupMemberByRef` |

## Honest limit

No ServiceNow connector, no PIM activation API, no Intune. Pair with [docs/interview-talk-track.md](../docs/interview-talk-track.md) for the production story.
