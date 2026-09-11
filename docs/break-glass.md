# Break-glass account design

**LAB ONLY.** Pattern for a disposable Entra tenant. Not an employer emergency-access procedure.

**AZ-104:** protect admin access, understand lockout risk from Conditional Access.  
**AZ-305:** design privileged access and identity governance so a CA mistake is recoverable.

## Why this exists

Conditional Access is a lockout engine. A policy that requires MFA for **All users** on **All cloud apps**, with no exclusion, can lock out every admin — including the person who could disable the policy — if MFA or the authenticator service is unavailable.

Break-glass (emergency access) accounts are the recovery path. They are created **before** you enable the CA baseline in [conditional-access.md](conditional-access.md).

## Lab design (what I would build)

| Control | Lab choice | Why |
| --- | --- | --- |
| Count | **Two** cloud-only accounts | One secret can be sealed; the second is a second person / location |
| Source | Cloud-only (`onPremisesSyncEnabled = false`) | Sync outage or AD compromise must not be the only admin path |
| Roles | Standing **Global Administrator** (exception) | PIM cannot be the only way in if PIM / Graph is the thing that is down |
| MFA | Excluded from the “MFA On for users” policy | The point is to survive MFA / CA failure. Use a long stored password + offline procedure |
| Mailbox | None, or a shared mailbox you do not use for daily mail | Reduces phishing surface; alerts go to a SOC / admin list instead |
| Naming | `breakglass01@<lab-tenant>` style — obvious, not a stealth user | Hiding the name does not help; detection does |
| Daily use | **Never** | Any sign-in is an incident until proven otherwise |

Config placeholders live in `scripts/config.example.json` (`breakGlassUpns`). JML scripts **refuse** to treat those UPNs as joiner / mover / leaver targets.

## What I would do in production (not evidenced here)

1. Create the two accounts in the tenant; store passwords in a **physical** safe / split knowledge — not in Key Vault that itself depends on Entra admin.
2. Exclude them from every CA policy that can block sign-in (MFA, device, location, risk). Prefer a dedicated exclusion group, not a one-off user list on each policy.
3. Alert on **any** interactive or non-interactive sign-in for those UPNs (Log Analytics / Entra diagnostic settings / Sentinel).
4. Recertify passwords and role membership on a calendar (for example quarterly).
5. Tabletop: “CA locked us out” — who opens the safe, who signs in, who sets the policy to report-only.

I would **not** put break-glass in Entra Connect scope, and I would not use a synced Domain Admin as Global Administrator.

## Tradeoffs

| Choice | Upside | Downside |
| --- | --- | --- |
| Exclude from all CA | You can always get in | A stolen break-glass password is a golden key — compensate with monitoring + offline storage |
| Standing Global Admin | Works when PIM is unavailable | Violates “no standing privilege” — call it an **explicit exception** with owners |
| Password-only (lab) | Simple | Production should evaluate FIDO2 / hardware keys stored offline; do not invent a phishing-resistant story you have not tested |
| One account | Less to manage | Single point of failure (lost password, one person on PTO) |

## Lab checklist (portal)

- [ ] Two cloud-only users exist; they are **not** in the JML demo UPN list
- [ ] Both are Global Administrator (lab exception) or the documented emergency role
- [ ] A security group `LAB-Break-Glass` contains only those two UPNs
- [ ] The MFA-On CA policy excludes that group
- [ ] You have a written “if I lock myself out” step before flipping CA from report-only to on

## Honest limit

This repo does not create the accounts for you and does not include tenant screenshots. The design is the proof. Creating them is five minutes in **your** lab tenant.
