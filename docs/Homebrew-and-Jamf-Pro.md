---
description: Deploy Homebrew with Jamf Pro policies, report package updates with extension attributes and offer approved tools through Self Service.
last_review_date: "2026-10-25"
---

# Manage Homebrew with Jamf Pro

Use Jamf Pro's package delivery, policies and inventory to manage Homebrew on enrolled Apple Silicon Macs.
Start with one computer in a `Homebrew Pilot` group and a reviewed [team Brewfile](Homebrew-Fleet-Management.md#install-default-software-for-each-team).

## Deploy Homebrew and the baseline

1. Complete [account provisioning and installer configuration](Homebrew-for-Mac-Admins.md#initial-provisioning) in a prerequisite policy.
   Verify the account, writable home and `HOMEBREW_PKG_USER` configuration before assigning the package policy.
2. Upload the approved Homebrew `.pkg` under **Settings > Computer management > Packages**.
   Create a package policy scoped only to pilot devices whose prerequisite checks succeeded.
   Script priority controls ordering; use policy scope to gate deployment on the prerequisite results.
   Follow [Jamf's package policy instructions](https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Deploying_a_Package_Using_a_Policy).
3. Deliver [central configuration](Homebrew-Package-Policies.md#set-central-configuration-with-brewenv) and the Brewfile.
   Use an **After** script for the [Brewfile installation job](Homebrew-Fleet-Management.md#install-default-software-for-each-team) once the files are present.
4. Review the policy log and [verify the installed owner and version](Homebrew-for-Mac-Admins.md#initial-provisioning).
   Require these checks before expanding the policy scope; a package receipt alone is insufficient.

## Show update needs in inventory

1. Deploy `jq` in the baseline and refresh Homebrew metadata in the maintenance policy.
2. Add a script [computer extension attribute](https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Computer_Extension_Attributes) named `Homebrew outdated formulae`, with data type **String**.
   The script below uses [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) to query the prefix owner's installation from Jamf's root job:

   ```bash
   #!/bin/bash
   set -o pipefail

   if count=$(/opt/homebrew/bin/brew as-brew-user outdated --json=v2 |
     /opt/homebrew/bin/jq -er '.formulae | arrays | length'); then
     printf '<result>%s</result>\n' "${count}"
   else
     printf '<result>unknown</result>\n'
   fi
   ```

3. Run an inventory update and inspect the device's attribute.
   Expect a count such as `3`; a failed command must produce `unknown`, not `0`.
4. Create a Smart Computer Group where the attribute is neither `0` nor `unknown`, and a separate group for `unknown`.
   Check last inventory time to distinguish current results from stale devices.
   Retain full [inventory, SBOM and vulnerability reports](Homebrew-Inventory-and-SBOM.md) separately; an outdated count is not a security finding.
   For these shared collection examples, use the same absolute paths and `as-brew-user` wrapper from Jamf's root jobs.

## Schedule updates and offer approved installations

1. Under **Computers > Policies**, create a policy with the [reviewed update job](Homebrew-Fleet-Management.md#schedule-updates-and-staged-rollouts) in its **Scripts** payload.
   Choose a recurring check-in trigger, execution frequency and pilot scope using [Jamf's script policy controls](https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Running_Scripts_Using_a_Policy).
2. Add an inventory update after maintenance, inspect failures and expand to the affected group after the pilot succeeds.
   For security work, follow the [scan, select, upgrade and rescan workflow](Homebrew-Vulnerability-Management.md); retain the final scan even when upgrading fails.
3. Create a separate policy with a fixed [approved installation action](Homebrew-Fleet-Management.md#provide-self-service-software-and-approvals) and enable **Self Service**.
   Test it with a standard user, then refresh inventory.
4. Collect large report files through your existing log collection system; Jamf policy logs truncate at 25 KB.

## Limit administrator access

1. Configure [Jamf accounts, groups and privilege sets](https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Jamf_Pro_User_Accounts_and_Groups) for inventory readers, deployment operators and script maintainers.
2. Test each role with a restricted account, including access to reports and policy scope.
3. For multiple customers, use supported site or tenant boundaries and test cross-customer isolation.
   A Smart Computer Group is not an access-control boundary; see [shared administration guidance](Homebrew-Fleet-Management.md#reporting-and-administrator-access).
