# Mover

**LAB ONLY.** Department / title update and app-group swap. License group stays unless you list it.

| Mode | Command |
| --- | --- |
| Plan (default, no Graph) | `./Set-LabMover.ps1 -ConfigPath ../config.json` |
| Execute | `Connect-MgGraph ...` then `./Set-LabMover.ps1 -ConfigPath ../config.json -Execute` |

## What it does

1. Refuses break-glass UPNs.
2. `Update-MgUser` for `newDepartment` / `newJobTitle`.
3. Removes `removeGroupNames` (example: `LAB-APP-Engineering`).
4. Adds `addGroupNames` (example: `LAB-APP-Finance`).
5. Prints that `LAB-LIC-M365-E3` is unchanged.

## Graph scopes

`User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.Read.All`

## Honest limit

Does not move on-prem OU membership. For hybrid users, pair this with an AD group/OU change in the source forest, then let sync catch up — or treat cloud groups as the only Azure/M365 access plane (preferred).
