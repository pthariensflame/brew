---
description: Export Homebrew package inventory as JSON or CSV, collect formula SBOMs and build fleet reports with your existing device-management tools.
last_review_date: "2026-10-25"
---

# Homebrew Software Inventory, SBOMs and Audit Reporting

Homebrew can report installed formulae and casks, package versions, dependencies and formula licence metadata.
Collect that information through your management system to answer which devices have a package, which need an update and which have stopped reporting.
Homebrew also records software bills of materials (SBOMs) for formula installations where available.
These are package records, not a complete device SBOM.

Run these commands as the Homebrew owner on macOS or Linux, with `brew` and any required tools on `PATH`.
For root management jobs, use the absolute path with [`as-brew-user`](Homebrew-for-Mac-Admins.md#run-management-commands-as-the-owner), for example `/opt/homebrew/bin/brew as-brew-user` in place of `brew` on Apple Silicon.

- Table of Contents
{:toc}

## Export installed software as JSON

1. Install [Homebrew](Installation.md) and assign a collection job to one pilot device.
2. Create a private report directory and collect the files below.

   ```bash
   #!/bin/bash
   set -euo pipefail
   umask 077
   cd "$(/usr/bin/mktemp -d /var/tmp/homebrew-report.XXXXXX)"
   pwd
   /bin/date -u '+%Y-%m-%dT%H:%M:%SZ' > collected-at.txt
   brew info --json=v2 --installed \
     > homebrew-inventory.json 2> homebrew-inventory.stderr
   brew outdated --json=v2 \
     > homebrew-outdated.json 2> homebrew-outdated.stderr
   brew config > homebrew-config.txt 2> homebrew-config.stderr
   ```

3. Retain the directory printed by the job, its exit status and diagnostics even if collection fails.
   Import only valid JSON from successful commands; a failed command is not an empty inventory.
   The remaining file-processing examples run from that report directory.
4. Upload the snapshot through your existing collector with device identity, Homebrew prefix and collection time.
   Remove the local copy after confirmed collection according to your retention policy.

The inventory object contains `formulae` and `casks` arrays.
For formulae, read installed versions from each formula's `installed` array, not `versions.stable`, which describes the currently available release.
Several kegs of the same formula can remain installed.
The `linked_keg` and installed runtime dependency records help distinguish the active installation from retained versions.
For casks, `installed` records the Homebrew-installed version; it does not necessarily reflect an application that has updated itself.
See [Querying `brew`](Querying-Brew.md) for the JSON interface and its compatibility policy.

Store snapshots by device identifier, Homebrew prefix and collection time, with the Homebrew version and job result.
One prefix's inventory does not include other installations on the same device.

## Export a spreadsheet inventory

1. Include `jq` in your [team Brewfile](Homebrew-for-Teams.md).
2. Convert the captured JSON from the report directory:

```sh
jq -r '
  ["type", "name", "installed_version", "tap", "licence"],
  (.formulae[] | . as $formula | .installed[] |
    ["formula", $formula.full_name, .version,
     $formula.tap, ($formula.license // "unknown")]),
  (.casks[] |
    ["cask", .full_token, .installed, .tap, "not reported"])
  | @csv
' homebrew-inventory.json > homebrew-inventory.csv
```

3. Import the CSV with spreadsheet formula interpretation disabled; CSV quoting alone does not prevent formula execution.

This emits one row for each installed formula keg and each cask record.
Keep the original JSON alongside the CSV so dependency and provenance information remains available.
Formula licence metadata describes the formula's declared licence; it is not a complete legal assessment of every bundled component.
Cask metadata does not provide an equivalent licence inventory.

## Inspect dependencies and installation intent

1. Select a package from the installed inventory.
2. Inspect its dependencies and users.

```sh
brew deps --tree git
brew uses --installed git
brew leaves
```

`brew deps` describes dependencies from current package definitions.
Use each installed formula entry's `runtime_dependencies` when you need the dependencies recorded for that installation.
`installed_on_request` distinguishes an explicitly requested formula from one brought in as a dependency.
`brew leaves` lists formulae that are not dependencies of other installed formulae; it is not a list of all user-requested software.

## Collect formula software bills of materials

Homebrew stores available SPDX JSON SBOMs as `sbom.spdx.json` inside formula kegs.

1. Start with the [captured inventory](#export-installed-software-as-json).
2. Write a manifest of installed formulae, versions and SBOM paths:

```sh
jq -r '.formulae[] | .full_name as $name | .installed[] |
  [$name, .version, (.sbom // "missing")] | @tsv' homebrew-inventory.json > homebrew-sboms.tsv
```

Each formula's `installed` entries include `sbom`: the absolute path of that keg's SPDX file, or `null` when the file is missing.
This includes retained kegs and does not substitute a document from another installed version.
Cask entries do not provide this field.
An absent field from an older Homebrew version means that path discovery is unavailable, not that the document is necessarily missing.

3. List available documents and archive them with the manifest and inventory.
   Run this while the installation is unchanged; if a file disappears during collection, repeat the snapshot:

```sh
jq -r '.formulae[].installed[] | .sbom // empty' \
  homebrew-inventory.json > homebrew-sbom-paths.txt
/usr/bin/tar -czf homebrew-sboms.tar.gz -T homebrew-sbom-paths.txt
```

4. Upload the archive, manifest and inventory together, associated with device, prefix, keg version and collection time.
   When the path list is empty, record missing coverage rather than treating an empty archive as a complete SBOM.
Missing documents are missing evidence; the current formula definition cannot replace the installed version's SBOM.
The SPDX records can include source, dependency, patch and build information, but do not provide a complete device SBOM or guarantee that every embedded component is identified.

## Use software bills of materials for security and software review

1. Import the SPDX documents into your existing SBOM or software-composition analysis system, preserving the installed-version and device mapping.
   Validate the supported SPDX format and record missing documents or unknown components.
2. For a new advisory, search affected components and versions to identify devices, responsible teams and services that need review.
   Reassess stored SBOMs against current advisories even when the installed software has not changed.
   An SBOM describes components; it is not a vulnerability verdict or a runtime usage trace.
3. For software approval or redistribution reviews, inspect component provenance and declared licences, then investigate unknown or conflicting entries.
   Use the [CSV inventory](#export-a-spreadsheet-inventory) for a review queue, keeping the underlying SPDX evidence.
4. Preview and apply approved updates, then collect fresh inventory, SBOMs and a [vulnerability scan](Homebrew-Vulnerability-Management.md).
   Preserve the earlier snapshot with the change record so incident responders can reconstruct what was installed at the time.

These workflows follow the [CISA guidance on SBOM consumption](https://www.cisa.gov/sites/default/files/2023-12/SECURING%20THE%20SOFTWARE%20SUPPLY%20CHAIN%20RECOMMENDED%20PRACTICES%20FOR%20SOFTWARE%20BILL%20OF%20MATERIALS%20CONSUMPTION%20%282%29.pdf).
For casks and other ecosystems, collect vendor SBOMs or their own inventories separately; Homebrew's formula SBOMs do not cover the whole device.

### Select updates and verify remediation

Follow the [vulnerability remediation workflow](Homebrew-Vulnerability-Management.md#select-vulnerable-upgrade-candidates): use `brew outdated --vulnerable --json=v2` to find upgrade candidates, `brew upgrade --vulnerable --dry-run` to preview and `--severity=high` to prioritise high and critical findings while retaining an unfiltered scan.
For an approved version requirement, use `--minimum-version` with `outdated` and `upgrade`; it selects packages below the threshold without pinning the target version.
After applying updates, retain a fresh scan, inventory and SBOMs even if the upgrade failed, and verify the finding before closing the ticket.

## Build fleet queries and reports

1. Store successful snapshots centrally, indexed by device, prefix and collection time.
2. Query installed versions, deprecated or disabled packages, available updates and missing team baselines.
3. Join [vulnerability findings](Homebrew-Vulnerability-Management.md) by device, prefix, formula and scanned version.
4. Publish dashboards or CSV exports with incomplete scans and stale devices visible alongside devices reporting no findings.

The public [formula and cask API](https://formulae.brew.sh/docs/api/) describes available software and contains no device records.

## Show Homebrew results in MDM inventory

Use the [MDM reporting steps](Homebrew-Fleet-Management.md#reporting-and-administrator-access) to attach small summaries and collection times to device records while retaining full JSON separately.
The [Jamf Pro](Homebrew-and-Jamf-Pro.md#show-update-needs-in-inventory), [Iru (formerly Kandji)](Homebrew-and-Iru.md#collect-inventory-and-security-reports) and [Microsoft Intune](Homebrew-and-Microsoft-Intune.md#add-inventory-fields-and-collect-reports) guides cover their reporting controls and limits.

## Keep useful audit evidence

Retain each management job's device, initiating identity, policy revision, command, timestamps, result and before-and-after inventory in central logs.
Snapshots record state at collection time and MDM logs record management jobs; neither captures every developer command.
Use operating-system auditing if that history is required.
Homebrew's [anonymous analytics](Analytics.md) is not a per-device audit log.

## Extend inventory beyond Homebrew

[Homebrew Bundle](Brew-Bundle-and-Brewfile.md#types) can capture supported software with `brew bundle dump --file=team.Brewfile`, including several language-package sources and VS Code extensions.
A Brewfile is a provisioning manifest rather than a complete versioned inventory.
Combine Homebrew records with project lockfiles, environment inventories, browser and IDE extension lists and MDM application discovery.
Collect separately inside containers, virtual machines and WSL environments.
