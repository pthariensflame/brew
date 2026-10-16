---
description: Manage Homebrew from Jamf Pro, Iru (formerly Kandji), Microsoft Intune and other MDM dashboards. Deploy Brewfiles, report inventory and schedule package updates.
last_review_date: "2026-10-25"
---

# Homebrew Fleet Management with MDM and Brewfiles

You can manage Homebrew across a Mac fleet using an MDM that deploys packages and executes scripts.
Homebrew handles software installation and updates; the MDM handles device enrolment, group membership, scheduling and job results.

- Table of Contents
{:toc}

## Integrate with your management system

Each provider guide takes you through provisioning, deployment, reporting, updates and administrator access:

- [Jamf Pro](Homebrew-and-Jamf-Pro.md)
- [Iru (formerly Kandji)](Homebrew-and-Iru.md)
- [Microsoft Intune](Homebrew-and-Microsoft-Intune.md)
- [Other management systems](#other-management-systems)

Start with a pilot device group and collect command output, exit status and inventory before expanding deployment.
These workflows use the MDM's existing agent or script runner; Apple MDM enrolment alone does not provide arbitrary shell execution.
Check your provider's plan, agent requirements, execution timeouts and output limits.

| Task in your MDM dashboard      | Homebrew operation                                                    | What to retain or display                           |
| ------------------------------- | --------------------------------------------------------------------- | --------------------------------------------------- |
| Inspect a device's software     | `brew info --json=v2 --installed`                                     | Installed versions, sources and collection time     |
| Find devices needing updates    | `brew outdated --json=v2`                                             | Package details and a searchable summary field      |
| Check the assigned baseline     | `brew bundle check --no-upgrade --file=…`                             | Pass, needs attention or collection failure         |
| Install approved software       | `brew bundle install --no-upgrade --file=…` or a fixed `brew install` | Assigned group, reviewed arguments and job result   |
| Review and apply security fixes | `brew vulns --json` and `brew upgrade --vulnerable`                   | Findings, scan coverage and a fresh scan afterwards |
| Apply package restrictions      | Distribute `/etc/homebrew/brew.env`                                   | Configuration revision and deployment result        |

Use [inventory fields](#reporting-and-administrator-access) for filtering and retain full JSON separately when job logs would truncate it.
An arbitrary JSON export does not automatically become an MDM's built-in software or vulnerability dashboard.
Use the shared deployment and maintenance jobs below after configuring your provider.

For Linux, follow [Homebrew on Linux](Homebrew-on-Linux.md) and run jobs as the prefix owner through your configuration-management tool.

### Other management systems

Use the same jobs with any management system that can deliver packages and run scripts as root:

1. Complete [account and installer provisioning](Homebrew-for-Mac-Admins.md#initial-provisioning), [central configuration](Homebrew-Package-Policies.md#set-central-configuration-with-brewenv) and [Brewfile deployment](#install-default-software-for-each-team).
2. Assign the baseline and maintenance scripts to a pilot device group, using `as-brew-user` for Homebrew commands.
3. Store short results in custom inventory fields and retain full reports separately.
   Keep failed collection and offline devices visible.
4. Schedule approved updates and refresh inventory afterwards.
   Check execution timeouts, retries, log retention and whether recurring jobs report every result.
5. Where supported, publish fixed installation actions through self-service and restrict who can edit or run them using the provider's roles.

Consult your provider's documentation for its script runner, inventory fields and reporting limits.

## Install default software for each team

1. [Install Git through Apple's Command Line Tools](Homebrew-for-Mac-Admins.md#install-git-for-management-jobs) before assigning this job; its first Homebrew command is `brew update`, which requires Git.
2. Prepare and review a [shared Brewfile in Git](Homebrew-for-Teams.md).
3. Deliver it to `/Library/Management/Homebrew/Brewfile` through your management system.
   Make the file readable by the managing account and writable only by administrators, including its parent directories.
4. Run the installation job below, then retain its check result before assigning more devices.

The job uses [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) to execute Homebrew as the prefix owner from a root management job:

```bash
#!/bin/bash
set -euo pipefail

test -x /opt/homebrew/bin/brew
test -r /Library/Management/Homebrew/Brewfile
/opt/homebrew/bin/brew as-brew-user update
/opt/homebrew/bin/brew as-brew-user bundle install \
  --no-upgrade --file=/Library/Management/Homebrew/Brewfile
/opt/homebrew/bin/brew as-brew-user bundle check \
  --no-upgrade --file=/Library/Management/Homebrew/Brewfile
```

`--no-upgrade` separates initial installation from scheduled updates; see the [shared Brewfile workflow](Homebrew-for-Teams.md) for version behaviour, review and cleanup when several teams share a device.

## Provide self-service software and approvals

1. Review a requested package and its source using the following commands.
   [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) selects the managing account, including from a root job:

```sh
/opt/homebrew/bin/brew as-brew-user search shellcheck
/opt/homebrew/bin/brew as-brew-user info shellcheck
```

2. Publish a fixed action in your MDM's self-service catalogue.
   [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) runs the approved installation as the prefix owner:

```sh
/opt/homebrew/bin/brew as-brew-user install --yes shellcheck
```

The MDM authorises the action and runs it as root; `as-brew-user` switches to the prefix owner.
It does not grant standard users the ability to impersonate that account.
Use reviewed package arguments rather than passing arbitrary user input to a privileged script.

3. Test the action on a pilot device and refresh its inventory.
4. Handle new software requests through your help desk or a Brewfile pull request, then update the device group's policy and catalogue.

See [package policies](Homebrew-Package-Policies.md) for the distinction between an approved baseline and an enforced allowlist.

## Schedule updates and staged rollouts

`brew update` refreshes Homebrew and package metadata.
`brew upgrade` updates installed packages.
Homebrew's automatic metadata refresh does not schedule unattended package upgrades.

1. Preview the intended upgrade and review services, pins and exceptions.
2. Assign this job to a pilot group.
   [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) switches the root job to the prefix owner for each operation:

```bash
#!/bin/bash
set -euo pipefail

/opt/homebrew/bin/brew as-brew-user update
/opt/homebrew/bin/brew as-brew-user upgrade --yes --formula
/opt/homebrew/bin/brew as-brew-user info --json=v2 --installed
```

3. Review the new inventory and application checks before assigning the wider group.
4. Retain failures and retry offline devices at their next check-in.

Assign one job at a time to each prefix.
Use separate pilot and general deployment groups; available versions can change between runs because Homebrew is a rolling-release package manager.

For a preview, run `/opt/homebrew/bin/brew as-brew-user upgrade --dry-run --formula`.
Use `/opt/homebrew/bin/brew as-brew-user upgrade --vulnerable --severity=high --dry-run` to preview updates for formulae with high or critical findings.
For an approved version threshold, use `--minimum-version`; see [vulnerability selection and remediation](Homebrew-Vulnerability-Management.md#select-vulnerable-upgrade-candidates).
Pins, services and packages without an available fix need explicit exception handling.

Without MDM, schedule the same commands as the owner using launchd on macOS or systemd timers or cron on Linux.

## Manage applications and services separately

Follow the [Mac application and service guidance](Homebrew-for-Mac-Admins.md#casks-services-and-shared-destinations) for privileged installers, self-updating applications, service accounts and unattended execution.
Choose one update mechanism per application and schedule closures or restarts with the people affected; avoid routine `--zap` removals because they can remove user data.

## Publish internal tools through private taps

1. Create a repository following [How to Create and Maintain a Tap](How-to-Create-and-Maintain-a-Tap.md), with formulae in `Formula/` and casks in `Casks/`.

Use reviewed pull requests, checksummed releases and [bottle builds](Bottles.md) for the platforms you support.
Your organisation maintains the internal packages and their hosting.

2. Provision read access for the managing account, then replace the example repository and package names below.
   [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) selects that account and its credentials:

```sh
/opt/homebrew/bin/brew as-brew-user tap example/tools git@github.com:example/homebrew-tools.git
/opt/homebrew/bin/brew as-brew-user trust --formula example/tools/internal-cli
/opt/homebrew/bin/brew as-brew-user install --yes example/tools/internal-cli
```

Git credentials must be available to the selected account; another user's SSH agent or login keychain may be unavailable during unattended execution.
Repository authentication and access to private release downloads are separate requirements.
See the [private Git download guidance](FAQ.md#how-do-i-authenticate-private-git-source-downloads).

Use a credential helper or managed SSH credentials; `brew.env`, Brewfiles and command URLs are not secret stores.
Provision read-only credentials for the managing account through your existing credential-management system, including host verification for SSH.
`as-brew-user` starts with a clean environment, so do not assume a token exported by the root job reaches Homebrew.
Keep tokens out of script output and disable shell tracing around secret retrieval; credentials used on a device are accessible to the account that uses them and to root.

3. Test repository access and artefact downloads separately.
   [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) reproduces the account used by unattended jobs:

```sh
/opt/homebrew/bin/brew as-brew-user update
/opt/homebrew/bin/brew as-brew-user fetch --formula example/tools/internal-cli
```

A token that authenticates Git or the GitHub API does not automatically authenticate arbitrary release URLs.
The formula or cask's download method must support the host's authentication requirements.
Prefer a supported download method or an [internal mirror](Homebrew-Package-Policies.md#use-mirrors-without-weakening-verification) with suitable authentication over a custom download strategy tied to Homebrew internals.
When retiring a tap, remove it from the deployed Brewfile and review its installed packages before running `brew untap`; removing a tap does not uninstall its packages.

## Reporting and administrator access

1. Collect [inventory and audit evidence](Homebrew-Inventory-and-SBOM.md) through your MDM.
   Run linked collection examples with the absolute `brew` path and [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner) from root jobs.
   Store short summaries in custom fields and full JSON or SBOMs through your existing collector.
   Keep failed collection, incomplete scans and stale devices separate from successful zero-result checks, recording the last successful collection time.
   Use reporting tools for fleet searches, exports and notifications, keeping notification credentials on the reporting service.

2. Use MDM and Git roles and single sign-on to control who can approve changes, deploy jobs and view reports.

Separate permission to view inventory, run approved jobs and edit scripts or their scope.
An MDM administrator who can edit a root script can execute arbitrary code; Homebrew package restrictions do not reduce that authority.

3. For managed service providers, use the MDM's customer tenants or supported administrative boundaries and keep each customer's credentials, configuration and reports separate.

A device group or a saved dashboard filter is not by itself an access-control boundary.
Test a restricted operator account against another customer's devices and reports before granting access.
