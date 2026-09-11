# Joiner

**LAB ONLY.** Creates (or locates) a user and attaches license / app groups.

| Mode | Command |
| --- | --- |
| Plan (default, no Graph) | `./New-LabJoiner.ps1 -ConfigPath ../config.json` |
| Execute | `Connect-MgGraph ...` then `./New-LabJoiner.ps1 -ConfigPath ../config.json -Execute` |

## What it does

1. Refuses if the UPN is in `breakGlassUpns`.
2. **CloudOnly:** `New-MgUser` with a one-time password (console only, force-change on sign-in).
3. **HybridSync:** does not create the person — waits for the synced object, then continues.
4. Sets `usageLocation`, department, job title, optional manager.
5. Adds configured groups (`LAB-All-Users`, `LAB-LIC-M365-E3`, `LAB-APP-Engineering` in the example).
6. Direct `Set-MgUserLicense` only if `assignDirectLicense` is true **and** `skuId` is not the zero GUID.

## Graph scopes

`User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.Read.All`

## Honest limit

Does not create the Entra groups, assign PIM roles, or provision an Exchange mailbox beyond whatever the license group grants.
