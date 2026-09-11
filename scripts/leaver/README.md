# Leaver

**LAB ONLY.** Blocks sign-in, revokes sessions, removes group access. **Never deletes** the user.

| Mode | Command |
| --- | --- |
| Plan (default, no Graph) | `./Invoke-LabLeaver.ps1 -ConfigPath ../config.json` |
| Execute | `Connect-MgGraph ...` then `./Invoke-LabLeaver.ps1 -ConfigPath ../config.json -Execute` |

## What it does (order is the design)

1. Refuses break-glass UPNs.
2. `Update-MgUser -AccountEnabled:$false`.
3. `Revoke-MgUserSignInSession` when `revokeSessions` is true.
4. Removes group memberships (skips `LAB-Break-Glass` and PIM approver groups if the user somehow landed there).
5. Prints the hold period (`keepDisabledAccountDays`, default 30). No `Remove-MgUser`.

## Graph scopes

`User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.Read.All`

## Honest limit

Does not convert a mailbox to shared, place a litigation hold, or close a ServiceNow ticket. Those are production runbook steps you name in [docs/interview-talk-track.md](../../docs/interview-talk-track.md).
