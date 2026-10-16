---
last_review_date: "2026-10-25"
description: Deploy and manage Homebrew with MDM, non-admin accounts and central configuration.
---

# Homebrew for Mac Admins: MDM and Non-Admin Accounts

This guide covers provisioning Homebrew through MDM and running it as a standard account or a dedicated Homebrew account.
For dashboard setup, follow the [Jamf Pro](Homebrew-and-Jamf-Pro.md), [Iru (formerly Kandji)](Homebrew-and-Iru.md), [Microsoft Intune](Homebrew-and-Microsoft-Intune.md) or [other provider instructions](Homebrew-Fleet-Management.md#other-management-systems).
The examples use the Apple Silicon prefix `/opt/homebrew`; see [Installation](Installation.md) for platform requirements.

## Choose the managing account

Choose one existing account to own and manage the Homebrew prefix.
It can be the Mac user's standard account or a dedicated account used by your management agent.
Give it a writable home directory for caches, logs and configuration, plus write access to Homebrew's directories.
Non-admin installations use the account's primary group, including a custom group, without requiring `admin` or `staff` membership.
When the primary group is `staff`, installation and reinstallation remove group and other write permissions from the prefix and cache.
Homebrew restricts its umask for these accounts, including subprocesses, while preserving stricter existing umasks.
Administrator accounts and custom primary groups retain their existing permissions; other group members may have write access where directories are group-writable.

Other accounts can read and execute installed software when filesystem permissions allow it.
Avoid having independent users manage the same installation concurrently.
Homebrew provides no security guarantees for installations where users with write access to the prefix are considered untrusted.

## Initial provisioning

The following example provisions a new Apple Silicon Mac for a dedicated standard account named `brewadmin`.
For a user-owned installation, substitute the existing user's short name and home directory throughout.
Run preparation commands as root through your management system; do not change the ownership of an existing installation without reviewing its packages and services first.

1. Create the account through your organisation's account-provisioning workflow before assigning the Homebrew package.
   For a local pilot, an administrator can use **System Settings > Users & Groups > Add User**.
   Use these example values, with a unique password supplied through your normal credential-management system:

   | Setting      | Example value          |
   | ------------ | ---------------------- |
   | Account type | Standard               |
   | Full name    | Homebrew Management    |
   | Short name   | `brewadmin`            |
   | Home         | `/Users/brewadmin`     |
   | Login shell  | `/bin/zsh`             |

   Do not embed a shared password in a deployment script or job log.
   The account needs no administrator privileges, sudo access or interactive login session.
2. Verify the account exists and its configured home is correct, then create that directory if your provisioning workflow has not already done so:

   ```bash
   /usr/bin/id brewadmin
   /usr/bin/dscl . -read /Users/brewadmin NFSHomeDirectory UserShell
   /usr/bin/install -d -o brewadmin -g "$(/usr/bin/id -gn brewadmin)" \
     -m 0750 /Users/brewadmin
   /usr/bin/sudo -H -u brewadmin /bin/test -w /Users/brewadmin
   ```

   Expect `NFSHomeDirectory: /Users/brewadmin` and a successful writable-directory check.
   Stop deployment if either check fails; a directory alone does not create an account.
3. Select that account for the installer, then set the required ownership, mode and ACL state:

   ```sh
   /usr/bin/defaults write /var/tmp/.homebrew_pkg_user HOMEBREW_PKG_USER brewadmin
   /usr/sbin/chown root:wheel /var/tmp/.homebrew_pkg_user.plist
   /bin/chmod 600 /var/tmp/.homebrew_pkg_user.plist
   /bin/chmod -N /var/tmp/.homebrew_pkg_user.plist
   /usr/bin/defaults read /var/tmp/.homebrew_pkg_user HOMEBREW_PKG_USER
   /bin/ls -le /var/tmp/.homebrew_pkg_user.plist
   ```

   Expect `brewadmin`, owner `root`, group `wheel` and permissions `-rw-------` without a `+` or ACL entries.
   The file must be a regular file, not a symbolic link.
   The [installer configuration requirements](Installation.md#installation) explain validation and fallback behaviour: an invalid file can select the console user instead.
4. Download the official `.pkg` from [Homebrew's releases](https://github.com/Homebrew/brew/releases/latest), approve that version and upload it to your management system's package delivery workflow.
   Assign it only after steps 1–3 have succeeded.
   For a local pilot with the approved package saved as `/Library/Management/Homebrew/Homebrew.pkg`, run:

   ```sh
   /usr/sbin/installer -pkg /Library/Management/Homebrew/Homebrew.pkg -target /
   ```

   The selected account can own the installation at the login window; nobody needs to be logged in.
   The package does not require an existing Git installation for basic bottle and cask use.
   [Install Git for management jobs](#install-git-for-management-jobs) before running the baseline or updates; developer tools are also needed when building formulae from source.
5. Verify the prefix owner, then use [`as-brew-user`](#run-management-commands-as-the-owner) to run Homebrew as that account with its home and environment:

   ```sh
   /usr/bin/stat -f '%Su' /opt/homebrew
   /opt/homebrew/bin/brew as-brew-user --version
   /opt/homebrew/bin/brew as-brew-user config
   ```

   Expect `brewadmin` as owner and a successful Homebrew version report.
   Retain the installer output and these checks before expanding the deployment.
   Continue with [central configuration](#set-central-configuration-with-brewenv) and a [team Brewfile](Homebrew-Fleet-Management.md#install-default-software-for-each-team).

### Install Git for management jobs

Install Apple's Command Line Tools (CLT) to provide Git before running `brew update`, baseline jobs or the shell installer.
A working Git from an existing Xcode installation also suffices.
The presence of `/usr/bin/git` alone is insufficient: without developer tools, it can be a macOS installation prompt stub that Homebrew deliberately avoids.

1. Choose an installation method:
   - **Interactive setup:** run `/usr/bin/xcode-select --install` in Terminal, accept the dialogue and wait for installation to finish.
     This selects a compatible release without maintaining a package, but requires user interaction and does not let you choose a specific version.
   - **Unattended MDM deployment:** sign in to [Apple Developer downloads](https://developer.apple.com/download/all/?q=command%20line%20tools), download an approved CLT release compatible with the target macOS and mount its disk image to obtain the `.pkg`.
     Deploy that package through your MDM as root.
     This supports deployment without a logged-in user and staged rollout of a tested version, but you must maintain the package and its macOS compatibility.
2. For a local package test, save the approved installer as `/Library/Management/Homebrew/CommandLineTools.pkg` and run as root:

   ```sh
   /usr/sbin/installer -pkg /Library/Management/Homebrew/CommandLineTools.pkg -target /
   ```

3. After either installation method, verify the selected developer directory and execute Git:

   ```sh
   /usr/bin/xcode-select --print-path
   /usr/bin/xcrun git --version
   ```

   Require successful verification before assigning Homebrew jobs.
   Recheck compatibility after macOS upgrades and keep CLT updated through Software Update or your managed package workflow; see [Apple's installation and update instructions](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/).

### Alternative shell installer

Alternatively, an MDM agent running as root can use the shell installer to provision Homebrew for an existing standard account.
The shell installer requires an existing usable Git; use the `.pkg` installer on hosts without one.
The prefix must be dedicated to this account; an existing installation must already be owned by and writable by it.
Save the [Homebrew installer](https://github.com/Homebrew/install/blob/HEAD/install.sh) to `/path/to/install.sh`, then run the following as root, replacing `penny` with the target account:

```bash
install_user="penny"
/usr/bin/install -d -o "${install_user}" -g "$(id -gn "${install_user}")" -m 0755 /opt/homebrew
/usr/bin/sudo -i -u "${install_user}" /usr/bin/env NONINTERACTIVE=1 \
  /bin/bash -s -- < /path/to/install.sh
```

The installer uses the target account's login environment and starts in its home directory, avoiding an inaccessible working directory inherited from the MDM agent.
Its files and cache belong to that user.
The account does not need administrator privileges, sudo access or an active login session.
Here, root invokes sudo to switch accounts; the target account does not invoke it.
`NONINTERACTIVE=1` prevents the shell installer from requesting input.

Provision only the directories needed by Homebrew.
When adopting an existing installation, review its ownership and permissions before assigning it to another account.
Use the installer's printed `brew shellenv` instructions for interactive shells and absolute command paths in MDM scripts.

## Run management commands as the owner

Management agents normally execute scripts as root, but Homebrew package operations must run as the non-root account that owns the prefix.
`as-brew-user` selects that owner, switches accounts when necessary and supplies its home directory and a clean environment.
It also works when the caller is already the owner, so the management examples use it consistently.
An unrelated standard account still needs permission to switch users.

A root job executes the Homebrew launcher before switching accounts, so only use this workflow when the prefix owner is trusted with that execution.
Use a dedicated managing account when end users must not control code run by the root job.

1. Use the absolute path `/opt/homebrew/bin/brew` on Apple Silicon: a management job may not have Homebrew on `PATH`.
2. Put `as-brew-user` before the Homebrew command and its arguments.
   For example, refresh metadata, then install an approved tool without interactive prompts:

   ```sh
   /opt/homebrew/bin/brew as-brew-user update
   /opt/homebrew/bin/brew as-brew-user install --yes wget
   ```

3. Retain standard output, standard error and the exit status in the management job.
   Extra account-switching diagnostics go to standard error; JSON remains on standard output.
   Shell redirection such as `> report.json` runs as the calling account, so a root job can save reports outside the managing account's home.

`as-brew-user` works without an active console login and rejects a root-owned prefix.
It uses the owner's home directory and a clean environment.
When sudo is available, the command retains its usual sudo behaviour.
When sudo is disabled or unavailable, an already-root caller switches through macOS `login` instead.
The target account's primary and supplementary groups are used.

Use `as-console-user` when the active console user is the intended managing account:

```sh
/opt/homebrew/bin/brew as-console-user install --yes wget
```

It uses the same root-only fallback but fails if no supported console user is logged in.
Neither command changes directory ownership or grants a standard account permission to switch to another account.

Both commands discard inherited environment settings except `HOMEBREW_NO_SUDO` and the identity settings they initialise.
The nested `brew` command then loads its environment files for the selected account.
Use those files for persistent management settings; exporting a variable in the MDM agent's environment generally does not pass it through the switch.

## Set central configuration with `brew.env`

Follow the [central configuration steps](Homebrew-Package-Policies.md#set-central-configuration-with-brewenv) to deploy `/etc/homebrew/brew.env` and verify settings as the managing account.
The same configuration format supports Macs and Linux systems; system settings can take priority over prefix and user defaults.

## Restrict software and package sources

Use [package policies](Homebrew-Package-Policies.md) to restrict packages, taps, local definitions and formula licences, with a named contact for exceptions.
The guide explains tap trust, group policy conflicts and the limits of controls enforced by the package manager.

## Manage software and updates

Keep [shared team Brewfiles](Homebrew-for-Teams.md) in version control, then use the [fleet deployment and maintenance jobs](Homebrew-Fleet-Management.md) for installation, self-service and staged updates.
For security work, follow [vulnerability scanning and verified remediation](Homebrew-Vulnerability-Management.md), including `--vulnerable` and `--minimum-version` selection.
Serialise jobs on each prefix and retain their output and exit status; a successful upgrade alone does not verify remediation.

## Casks, services and shared destinations

With `HOMEBREW_NO_SUDO=1`, casks requiring privileged installers, keyboard-layout cache changes or privileged install steps fail before installation.
Set it in `brew.env` when you explicitly want to [disable Homebrew's sudo calls](Installation.md#running-without-sudo); Homebrew also detects when sudo is unavailable.
Optional filesystem operations attempt to run without sudo.
Homebrew does not extract `.pkg` payloads as a substitute for running their installers.
Deploy applications requiring privileged installation separately through your MDM.

For compatible app casks, choose a destination writable by the managing account with `--appdir` or `HOMEBREW_CASK_OPTS`.
In `brew.env`, specify the destination as an absolute path to that account's Applications directory; shell variables are not expanded.
A shared destination such as `/Applications` needs suitable permissions provisioned separately.
For casks that must supply checksums, `HOMEBREW_CASK_OPTS=--require-sha` rejects casks without them.

Use `brew outdated --cask --greedy` to assess self-updating casks and those using `version :latest`.
The Homebrew installation record can differ from an application's running version after it updates itself.

Caches, logs, configuration and user services belong to the managing account.
A dedicated account's user service is not another user's service; plan its login requirements and lifecycle separately from package installation.
Use the [`brew services` reference](Manpage.md#services-subcommand) when choosing user services or system services.

## Network configuration and reporting

Follow the [mirror and network guidance](Homebrew-Package-Policies.md#use-mirrors-without-weakening-verification) and [private-tap authentication steps](Homebrew-Fleet-Management.md#publish-internal-tools-through-private-taps) when preparing unattended jobs.
Use the [inventory and SBOM guide](Homebrew-Inventory-and-SBOM.md) for reports and audit evidence, and your MDM's [administrator roles](Homebrew-Fleet-Management.md#reporting-and-administrator-access) for access control.
For build failures, retain diagnostics from the managing account's `~/Library/Logs/Homebrew` directory.

## Apply operating-system execution rules

Homebrew package restrictions govern Homebrew operations; they do not prevent execution of a binary downloaded by another tool.
If you enforce execution rules through your MDM, account for Homebrew's shell scripts, portable Ruby, build tools and the software being installed.
Allowing an interpreter does not by itself restrict the scripts it can execute.

On supported supervised Macs, Apple's [`com.apple.configuration.app.settings` declaration](https://github.com/apple/device-management/blob/release/declarative/declarations/configurations/app.settings.yaml) provides `AllowedBinaries` and `DeniedBinaries` from macOS 27.
Confirm support in your MDM before using it.
Apple requires a code directory hash or Team ID for an allowed binary; a path prefix alone is insufficient.
Inspect the actual installed executable with `codesign -dvvv /path/to/binary`, then maintain the rule as software changes.
Do not assume all Homebrew packages share a signing identity, and do not broadly trust a user-writable prefix as a substitute for reviewing executable code.
