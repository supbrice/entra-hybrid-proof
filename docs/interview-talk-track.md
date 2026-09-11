# Interview talk track (about 8 minutes)

**LAB ONLY.** What I would say. Not a claim that a customer tenant looks like this.

Use this with the root [README](../README.md) open. Run `scripts/Invoke-LabJmlDemo.ps1` when you get to JML so the reviewer sees a plan, not a story about a screenshot.

## 30-second open

> I treat Entra as the policy plane and groups as the assignment unit. Day 1 of this pack is Conditional Access with MFA on, two cloud-only break-glass accounts excluded, PIM-eligible User Administrator so JML is time-boxed, and Graph scripts for joiner / mover / leaver. It is a lab I own — not an nVent or customer tenant.

## Minute 1–2 — Break-glass, then CA

- I do not enable MFA-for-all until two cloud-only emergency accounts exist and are excluded.
- Policy: All users, All cloud apps, grant MFA, exclude `LAB-Break-Glass`, **report-only first**.
- Day 1 has no device compliance. Intune / Autopilot is Day 2 on purpose.

**If they ask “what if CA locks you out?”**  
Break-glass is standing Global Admin (the documented exception), password offline, every sign-in alerted. Then set the policy back to report-only.

## Minute 3 — PIM

- Daily account is **eligible** User Administrator, 4-hour activation, justification, MFA.
- Standing User Admin on a helpdesk account is a finding.
- Break-glass stays standing so PIM itself is not a single point of failure.

**Tradeoff they may poke:** eligible vs app-only Graph. Humans + PIM for ticketed changes; app registration with tight scopes for HR-driven automation. A standing secret with `Directory.ReadWrite.All` is worse than PIM.

## Minute 4 — Groups and M365

- Three families: `LAB-LIC-*`, `LAB-APP-*`, `LAB-ROLE-*`.
- Joiner: usage location + license group + dept app group.
- Mover: swap app groups; keep the SKU unless the role actually changes the license.
- I assign Azure RBAC to groups, not to named users.

## Minute 5–6 — JML demo

```powershell
./scripts/Invoke-LabJmlDemo.ps1 -ConfigPath ./scripts/config.json
```

Walk the plan:

1. **Joiner** creates a cloud user *or* waits for hybrid sync, then adds groups.
2. **Mover** updates department/title and swaps `LAB-APP-Engineering` → `LAB-APP-Finance`.
3. **Leaver** disables, revokes sessions, removes group memberships, keeps the account 30 days. No delete.

Scripts default to plan mode. `-Execute` is opt-in and refused for break-glass UPNs.

## Minute 7 — Hybrid (if they are hiring for hybrid)

- On-prem AD remains source of authority for synced people ([configure-ad](https://github.com/supbrice/configure-ad)).
- Cloud Sync or Connect with OU filter; do not sync Domain Admins or break-glass.
- Password hash sync is the lab-default sign-in model; PTA if password policy must stay on-prem.
- Cloud access (Azure RBAC, M365, CA) is granted to **cloud or synced groups**, enforced in Entra.

## Minute 8 — What I would do in production that this repo does not fake

| Prod practice | Why it is not in the repo |
| --- | --- |
| ServiceNow / ticket ID on every `-Execute` | No customer ITSM to attach |
| Sentinel alert on break-glass sign-in | Needs a live workspace |
| Access reviews on privileged groups | P2 + tenant policy, not a markdown file |
| Named locations + risk + auth strength | Day 1 is MFA + exclusion only |
| Intune compliant device grant | Day 2 — Professor guidance |

## Questions I want them to ask

- “Why is break-glass standing Global Admin?” — Because PIM can be down. It is an exception with owners and alerts.
- “Why not device compliance on Day 1?” — No inventory, no Intune. CA that requires a compliant device before Intune exists is a lockout.
- “Why plan-first scripts?” — JML is destructive. I want the reviewer to see I default to WhatIf.

## What I will not say

- That these are production nVent screenshots or a tenant I still administer.
- That I have Autopilot / Intune evidence in this repo.
- That `config.example.json` is a real customer domain.
