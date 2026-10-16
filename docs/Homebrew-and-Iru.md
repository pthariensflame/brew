---
description: Deploy Homebrew with Iru, formerly Kandji, using Custom Apps, Brewfile audit and remediation scripts, scheduled updates and Self Service.
last_review_date: "2026-10-25"
---

# Manage Homebrew with Iru (formerly Kandji)

Use Iru's macOS Library Items to install Homebrew, check team software and run approved maintenance.
Start with an Apple Silicon Mac in a `Homebrew Pilot` Blueprint or Assignment Map.

## Deploy Homebrew and its configuration

1. Provision the managing account using your account workflow or Iru's [Create User Accounts parameter](https://docs.iru.com/en/endpoint/blueprints/parameters/create-user-accounts).
   Follow the [shared account and home-directory checks](Homebrew-for-Mac-Admins.md#initial-provisioning); the account must exist before installation.
2. Add the approved Homebrew `.pkg` as a **Mac Custom App** Library Item.
   Use a pre-install script for the account checks and `HOMEBREW_PKG_USER` configuration, stopping on failure.
   Follow [Iru's Custom App configuration](https://docs.iru.com/en/endpoint/library/library-items-profiles/configure-the-custom-apps-library-item) and assign the pilot Blueprint.
3. Deliver [central configuration](Homebrew-Package-Policies.md#set-central-configuration-with-brewenv) and the [team Brewfile](Homebrew-Fleet-Management.md#install-default-software-for-each-team).
4. Verify the owner and working Homebrew command using the [post-install checks](Homebrew-for-Mac-Admins.md#initial-provisioning), then inspect the Custom App's device status before expanding assignments.

## Check and install the team baseline

1. Create a **Custom Script** Library Item named `Homebrew baseline` and choose **Run daily** for a recurring baseline check.
   In **Audit Script**, use the following check after deploying the Brewfile.
   [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) switches Iru's root script to the prefix owner and its home directory:

   ```bash
   #!/bin/bash
   set -euo pipefail

   test -x /opt/homebrew/bin/brew
   test -r /Library/Management/Homebrew/Brewfile
   /opt/homebrew/bin/brew as-brew-user bundle check \
     --no-upgrade --file=/Library/Management/Homebrew/Brewfile
   ```

2. Set **Remediation Script** to the [Brewfile installation job](Homebrew-Fleet-Management.md#install-default-software-for-each-team).
   Keep its prerequisite checks: a failed audit can mean missing Homebrew or an unreadable file, not just missing packages.
3. Assign the pilot Blueprint and inspect the item's status and recorded output.
   A non-zero audit result triggers remediation; investigate failures before expanding deployment.
   See [Iru's Custom Scripts reference](https://docs.iru.com/en/endpoint/library/library-items-profiles/custom-scripts-overview).

## Collect inventory and security reports

1. Add a **Custom Script** Library Item for the [inventory collection job](Homebrew-Inventory-and-SBOM.md#export-installed-software-as-json), with daily execution and pilot assignment.
   Replace `brew` in shared examples with `/opt/homebrew/bin/brew as-brew-user`: [this wrapper](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) runs Homebrew as its owner from Iru's root script.
   Use `/opt/homebrew/bin/jq` when processing JSON and include `jq` in the baseline.
2. Collect a [vulnerability scan with its diagnostics and status](Homebrew-Vulnerability-Management.md#capture-findings-without-losing-errors) and inspect the item's recorded output.
   A non-zero scan status can indicate findings or an operational failure; inspect both the report and its coverage.
3. Upload full JSON and available [SBOMs](Homebrew-Inventory-and-SBOM.md#collect-formula-software-bills-of-materials) through your organisation's collector with device identity and collection time.
   Custom Script output does not automatically populate Iru's built-in vulnerability views.
   Track stale devices and collection failures separately from successful scans without findings.

## Schedule updates and offer approved tools

1. Add a separate Custom Script for the [reviewed maintenance job](Homebrew-Fleet-Management.md#schedule-updates-and-staged-rollouts), with daily execution and pilot assignment.
   Avoid concurrent update and baseline jobs on the same prefix.
2. Review script output and fresh [inventory and security reports](#collect-inventory-and-security-reports) before assigning more devices.
   A successful remediation status alone does not establish that security findings are resolved.
3. For an approved installation action, create a Custom Script with **Run on-demand from Self Service**, using the [fixed installation example](Homebrew-Fleet-Management.md#provide-self-service-software-and-approvals).
4. Test Self Service as a standard user and confirm the new package appears in inventory.

## Limit administrator access

1. Assign [Iru team roles](https://docs.iru.com/en/iru/access/team-member-role-permissions) for report readers, operators and Library Item maintainers.
2. Verify a restricted account can perform its intended tasks without editing root scripts or expanding their assignment.
3. For multiple customers, use separate supported tenant boundaries and test report isolation as described in [shared administration guidance](Homebrew-Fleet-Management.md#reporting-and-administrator-access).
