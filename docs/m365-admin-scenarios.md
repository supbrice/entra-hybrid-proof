# M365 admin scenario notes

**LAB ONLY.** Conceptual Microsoft 365 admin patterns plus the Graph the JML scripts actually call. Not a tenant screenshot pack and not a license reseller runbook.

**AZ-104:** assign licenses, manage users and groups.  
**AZ-305:** choose group-based assignment so movers do not require a license ticket each time.

## Scenario A — Joiner needs mail, Teams, and Office

**Wrong:** click the user → Licenses → tick Microsoft 365 E3. That does not scale and movers/leavers miss a checkbox.

**Day 1 pattern:**

1. Set **usage location** (required before a license applies). Lab config uses `US`.
2. Add the user to `LAB-LIC-M365-E3` (group-based licensing).
3. Add the user to `LAB-All-Users` and the department `LAB-APP-*` group.

The joiner script does (1) as a user property and (2)/(3) as group membership. It does **not** call `Set-MgUserLicense` by default. Direct SKU assignment is the escape hatch when group-based licensing is not available in a tiny developer tenant.

```powershell
# Plan-first (no tenant write)
./scripts/joiner/New-LabJoiner.ps1 -ConfigPath ./scripts/config.json

# What you should see in the plan:
# - New-MgUser (cloud-only lab user) OR skip-create if hybrid/sync
# - usageLocation = US
# - Add to LAB-All-Users, LAB-LIC-M365-E3, LAB-APP-Engineering
```

## Scenario B — Mover changes department, keeps the same SKU

License group stays. App group swaps. That is the whole mover.

| Attribute | Before | After |
| --- | --- | --- |
| Department | Engineering | Finance |
| `LAB-LIC-M365-E3` | keep | keep |
| `LAB-APP-Engineering` | member | removed |
| `LAB-APP-Finance` | — | member |

If Finance required a different SKU (E3 → F3, or an add-on), that is a **second** license-group swap, not a direct SKU edit on the user. See [Set-LabMover.ps1](../scripts/mover/README.md).

## Scenario C — Leaver: stop paying and stop signing in

Order matters more than cmdlets:

1. **Block sign-in** (`accountEnabled = false`) — stops token issuance for new sessions.
2. **Revoke sessions** (`Revoke-MgUserSignInSession`) — existing refresh tokens drop.
3. **Remove license and app groups** — mailbox / Teams / Azure access follow the groups.
4. **Keep the disabled account** for a hold period (lab config: 30 days). Hard-delete is a separate, ticketed step (legal / mailbox retention).

The leaver script does 1–3 and prints 4 as an operator reminder. It will not delete the user.

## Graph vs portal vs Graph PowerShell

| Task | Portal | Graph PowerShell (this repo) |
| --- | --- | --- |
| Usage location | User → Properties | `Update-MgUser -UsageLocation` |
| Group-based license | Groups → Licenses | Membership in `LAB-LIC-*` |
| Direct license | User → Licenses | `Set-MgUserLicense` (opt-in only) |
| Sign-in block | User → Block | `Update-MgUser -AccountEnabled:$false` |
| Session revoke | User → Revoke sessions | `Revoke-MgUserSignInSession` |

## Hybrid / license collision notes

- Synced users: create the AD account in the [configure-ad](https://github.com/supbrice/configure-ad) forest, wait for sync, then run **cloud** JML (groups + usage location). The joiner script has `identitySource: HybridSync` for that path — it will not `New-MgUser`.
- Do not assign the same SKU twice (direct + group). Group-based licensing wins as the source of truth in this design.
- `usageLocation` must match a country Microsoft can bill. Empty usage location is the usual “license failed” ticket.

## What this pack does not cover (Day 2+)

- Exchange Online mailbox litigation hold / eDiscovery (name the ticket; do not script legal hold from a portfolio repo)
- Teams / SharePoint site provisioning
- Intune enrollment or Autopilot profiles
- Shared mailbox conversion as an automatic leaver step (call it out in the talk track if asked)

## Honest limit

`skuId` in `config.example.json` is a **zero GUID placeholder**. Put a real SKU ID only in your untracked `config.json` if you `-Execute` group-based licensing in a tenant that has that SKU.
