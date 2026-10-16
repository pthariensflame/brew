---
description: Manage Homebrew at work with a shared team Brewfile in Git. Set up colleagues, review package changes and coordinate updates on macOS and Linux without an MDM.
last_review_date: "2026-10-25"
---

# Homebrew for Teams: Manage a Shared Brewfile

A shared Brewfile gives a team one reviewed list of tools and repeatable setup instructions for using Homebrew at work.
Keep it in Git, review changes through pull requests and have colleagues apply the agreed configuration to their own machines.
This workflow uses Homebrew and your existing Git host; it needs no MDM or central management service.

Each colleague needs [Homebrew](Installation.md) and Git, and runs the commands as the owner of their own Homebrew installation.
The examples use formulae available on macOS and Linux.
The team shares a manifest, not a Homebrew installation or account.

## Create the shared `Brewfile`

1. Choose a repository everyone on the team can read.
   Keep common tools in a small repository such as `team-tools`, and project-specific dependencies in each project's own Brewfile.
   Choose who can approve changes and merge pull requests.
2. Save the agreed tools in a file named `Brewfile` at the repository root:

```ruby
brew "git"
brew "jq"
brew "shellcheck"
```

3. Test it using the installation commands below, then commit and publish it through your usual Git review process.
   Include those setup commands in the repository's README so new colleagues can find them.

To start from an existing machine, use [`brew bundle dump`](Brew-Bundle-and-Brewfile.md#brew-bundle-dump), then remove personal and unrelated entries before committing.
See [supported Brewfile entries](Brew-Bundle-and-Brewfile.md#types) for applications and other package sources; check their platform requirements before adding them to a mixed-platform team's file.

## Set up a colleague's machine

1. Clone the repository and enter its directory, replacing this example URL with your team's repository:

   ```sh
   git clone https://github.com/example/team-tools.git
   cd team-tools
   ```

2. Install missing tools and check that the Brewfile's requirements are satisfied:

   ```sh
   brew bundle install --no-upgrade --file=Brewfile
   brew bundle check --no-upgrade --file=Brewfile
   ```

   `--no-upgrade` skips routine upgrades of entries already installed; installing missing tools can still require dependency changes.
   Add `--verbose` to a failed check to see unmet requirements.
3. Run the project's normal build or tests to verify the tools work together.
   A successful Bundle check verifies package requirements, not application compatibility.

## Give projects familiar setup commands

Follow GitHub's [Scripts To Rule Them All](https://github.com/github/scripts-to-rule-them-all) convention so colleagues can use the same command names across projects.
Keep each wrapper small and let Homebrew manage the packages declared in that repository's Brewfile.

1. Create a `script` directory and save this as `script/bootstrap`:

   ```bash
   #!/bin/bash
   set -euo pipefail

   cd "$(dirname "$0")/.."
   brew bundle check --no-upgrade --file=Brewfile ||
     brew bundle install --no-upgrade --file=Brewfile
   ```

2. Make it executable, run it and commit it alongside the Brewfile:

   ```sh
   chmod +x script/bootstrap
   script/bootstrap
   ```

3. Document `script/bootstrap` as the dependency setup command.
   Add `script/setup` for initial application state, `script/update` for changes needed after pulling and `script/test` for project tests where needed.
   Setup and update scripts can call `script/bootstrap`; CI can use the same scripts once Homebrew is installed.

Keep machine provisioning separate from project setup, and make bootstrap safe to repeat without resetting databases or overwriting personal configuration.
Leave command output and failures visible so colleagues can identify the failed step and retry after resolving the cause.
Keep package upgrades an explicit [team update](#coordinate-package-updates), separate from installing missing dependencies.

## Review and share changes

1. Create a branch in the repository and edit the Brewfile, or use [`brew bundle add`](Brew-Bundle-and-Brewfile.md#brew-bundle-add-and-brew-bundle-remove):

   ```sh
   git switch -c add-ripgrep
   brew bundle add --file=Brewfile ripgrep
   git diff -- Brewfile
   ```

2. Apply the [installation and check steps](#set-up-a-colleagues-machine), then test the affected projects on the supported platforms.
3. Commit the change and open a pull request explaining why the team needs it.
   Brewfiles execute Ruby, so review changes as code and keep credentials out of them.
4. After merging, tell colleagues to update their checkout on the repository's default branch and apply the shared file:

   ```sh
   git pull --ff-only
   brew bundle install --no-upgrade --file=Brewfile
   brew bundle check --no-upgrade --file=Brewfile
   ```

Merging a pull request does not change anyone's installed packages until they run the commands.
Agree when the team should pull and apply changes, for example when starting a project or after a dependency change is announced.

## Coordinate package updates

1. Choose a colleague or CI environment to test updates before asking everyone to apply them.
2. Refresh Homebrew's metadata, then install the Brewfile without `--no-upgrade` to include available upgrades:

   ```sh
   brew update
   brew bundle install --file=Brewfile
   brew bundle check --file=Brewfile
   ```

3. Run project tests and share the result, including any migration or restart steps, before the rest of the team repeats the update.
   Use [vulnerability scanning and remediation](Homebrew-Vulnerability-Management.md) when responding to security findings.

A Brewfile records package choices, not locked versions: the same Git revision can install different versions on different days.
Reverting a Brewfile commit does not restore historical package versions or application data.
See [versioned formulae](Versions.md) when a project needs a supported major-version line.

## Keep personal tools and remove retired entries

Keep personal tools in a separate Brewfile or install them directly; colleagues can also apply project-specific Brewfiles alongside the team's file.
All of them affect the same local Homebrew installation, so removing an entry from one file does not uninstall it or establish that nobody still needs it.
Before using [`brew bundle cleanup`](Brew-Bundle-and-Brewfile.md#brew-bundle-cleanup), review the combined requirements of the team, projects and personal tools, and preview removals without `--force`.
Personal shell and editor settings can live in a separate dotfiles repository that team setup scripts leave untouched.

If you later need centrally assigned installation jobs, reuse the reviewed Brewfile with the [MDM deployment guide](Homebrew-Fleet-Management.md#install-default-software-for-each-team).
