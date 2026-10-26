---
last_review_date: "2026-10-25"
---

# Advisory Matching

`brew advisory-match` prepares candidate records for the [Homebrew advisory database](https://github.com/Homebrew/advisory-database).
It is an authoring tool, not the installed-package scanner provided by `brew vulns`.
Candidates still need [human review](https://github.com/Homebrew/advisory-database/blob/HEAD/CONTRIBUTING.md#reviewing-matched-candidates) before publication.

For operational scanning and remediation, see [Homebrew vulnerability management](Homebrew-Vulnerability-Management.md).

## Range accuracy and coverage

With history enabled, a candidate with a comparable current state and no reviewed range must have its complete affected intervals established from formula history on the latest supported macOS and Linux for both ARM and Intel.
This applies even when the current formula is known to be affected: knowing today's state does not establish when the affected range began.
An `introduced: "0"` boundary asserts that every earlier version is affected; it is not a marker for an unknown introduction.

Automatic matching deliberately favours range accuracy over coverage.
Unreadable or uncomparable history can prevent a new record from being emitted.
Disjoint affected runs produce separate introduced/fixed pairs, including an open final interval when the package is still affected.
Known intervals are unioned across platforms; a history or provenance failure on any platform holds the whole candidate.
Additional platform views are queried once per formula for its new candidates, and a held candidate stops visiting further platforms.
For a resource-only hit absent from another platform's current formula, the original upstream constraints are checked against that platform's complete history.
Absence today alone does not establish historical absence; unreadable history, unknown resource identities and missing query results for present resources still require review.
The command warns and counts these as history-unavailable skips instead of inventing a boundary.
This includes a historical subject whose prerelease suffix changes its `SEMVER` range state compared with its release version.
A skip does not mean the formula is unaffected, so an ingest run can omit a currently affected formula and is not evidence of complete vulnerability coverage.
Reviewers must establish the ranges and matching provenance together from upstream evidence and formula build history, then contribute the record manually.

For a new record, a `pkg_version` shared by affected and unaffected builds is conservatively included in the affected interval, because the advisory cannot distinguish those builds by version.
This can happen when a resource changes without a formula revision bump.
For the same reason, a fix that shares its `pkg_version` with affected builds is recorded at the next version with only fixed builds, and a range stays unchanged while the current version also has an affected build.
A distinct unaffected label closes the preceding interval; a later affected label opens another.
Complete-history reconciliation applies the same any-affected-build rule.
Unknown builds, conflicting upstream constraints and rollbacks with no representable fix still require review.
Existing daily boundary-transition checks retain their conservative guards.

Current-version prerelease ambiguity produces an uncomparable review lead with no `range_state`, reduced confidence and `database_specific.review_reason: "prerelease_boundary"`.
Ingest drops these leads and lists their IDs by reason in its run summary.
An explicit `range_state` override for the formula and advisory resolves the current-state ambiguity; an `upstream_fixed_in` override alone does not.
Without a reviewed state override, existing reviewed records stay unchanged.

A reviewed state override does not establish historical boundaries.
When its state disagrees with comparable upstream evidence, or the upstream evidence cannot be checked, a new range needs manual review.
Existing reviewed ranges are preserved rather than replaced with guessed introductions; range transitions and changed provenance still require their own checks.

## History options

`--new-history` requires `--output` and reuses existing reviewed ranges where possible; a successful replay does not independently verify those boundaries.
`--json` without `--output` has no existing reviewed records to reuse, so history checks still apply to new comparable candidates.
`--no-history` explicitly uses unverified zero/current-version boundaries for new ranges and cannot be combined with `--new-history`.
It is an unchecked authoring mode, not a way to validate a skipped candidate.

New-record history can reuse a revision's loaded matching metadata across platforms when parsing that revision proves that its declarations are platform-independent.
A conservative allowlist accepts literal source, resource and patch metadata; unknown DSL, helper-derived values and platform conditionals retain separate platform loads.
The current formula is checked separately before reusing its advisory queries, and older revisions are always classified individually.
Shared historical observations remain bound to the same upstream evidence and alias family.
This optimisation does not change existing-record reconciliation or the early stop for candidates requiring review.

`--rejected-candidates=<file>` requires `--output` and reads an explicit local rejection list; it never fetches one.
The file contains exact, case-sensitive record IDs, one per line, with `#` comments, surrounding whitespace and blank lines ignored.
With history enabled, listed new comparable candidates are skipped before additional platform queries or history walks, and their count and IDs are reported.
Alias preparation still sees all actionable hits, and a listed non-canonical alias does not reject the canonical ID.
Existing records, including unreviewed aliases, are processed normally so downstream validation can still reject listed records on disk.
This option does not change `--no-history` or `--reconcile-history`; an unreadable rejection file fails the command.

## Reconciling existing ranges

`--reconcile-history --output advisories --overrides data/overrides.yml` explicitly revisits existing `source: matched`, bump-fixed records with terminal introduced/fixed intervals.
It requires complete formula history and matching provenance, on the latest supported macOS and Linux for both ARM and Intel.
Known affected intervals are unioned across those platforms; an unaffected platform cannot cancel another platform’s affected builds.
These simulations check declared formula and resource versions; they do not rebuild historical bottles or verify installation steps.
It can narrow or split affected intervals or delete a record proven never affected on every platform; it preserves other fields and updates `modified` only for a range change.
Generated records, patch fixes, open intervals and unsupported range shapes are left unchanged.
Reviewed closed multi-interval records can be narrowed, but a proposed interval must remain entirely inside the reviewed affected set.
Reconciliation cannot fill reviewed safe gaps, expand coverage or reopen a terminal range.
Initial repairs preserve complete split histories in unreviewed ranges without replacing reviewed intervals.
For records missed by current matching, complete registry-resource evidence can supply versionless upstream queries even after a resource has been removed.
The fresh results must reproduce the stored upstream family and range basis, and every resource identity must occur in formula history on every platform.
Stored subject versions only reproduce the range basis; historical decisions use versions from the formula sources.
A missing historical resource holds the record as `resource_not_found`; a stored family absent from the fresh query results is `resource_not_rediscovered`.
Mixed, incomplete or non-resource provenance still requires current discovery.
These fallback queries cannot create records and respect formula skips and preserved Homebrew ranges.
When a prerelease suffix changes a subject’s `SEMVER` range state compared with its release version, `prerelease_boundary` holds the record for review.
The command reports skip reasons and the number of matched records it did not revisit; success does not establish complete coverage.

Before running this mode, protect hand-reviewed Homebrew boundaries with `preserve_homebrew_ranges: true` under the formula and advisory in `overrides.yml`.
The pin applies across advisory aliases and is separate from `upstream_fixed_in`, which describes the upstream fix.
Unavailable history or upstream records, changed subjects, unresolved platform results and advisory-specific patches require review.
A failed upstream lookup holds every record for that formula with `upstream_unavailable`; a failed batch query holds its entire formula batch.
A confirmed HTTP 404 while following an upstream link is cached as a missing target; a record with no resolved targets keeps its original evidence.
A 404 for a supplemental CPANSA CVE lookup uses the CPANSA evidence for that CVE, including on subsequent platform passes.
A 404 for an ID returned directly by a query still holds the formula, as do other request failures.
Reconciliation continues with the remaining formulae, so a successful command can include these holds.
Complete history includes earlier lifetimes of deleted and re-added formulae, skipping revisions where Git proves the formula path was absent.
A rename into the current formula name starts that name’s history; the old formula name’s builds are excluded.
Historical loading ignores obsolete `devel` blocks and uses the stable build.
It also accepts legacy `sha1` and `md5` declarations, `bottle :unneeded` and `plist_options` without fetching or building historical sources.
This compatibility applies to all `FormulaVersions` callers, including daily matching; ordinary current-formula loading is unchanged.
Any remaining unreadable build still holds the record, even when it appears before or after the affected interval.
A historical formula's `odie` option check becomes a failed load rather than terminating the command.
The reconciliation summary counts failed formula revisions and affected formulae separately from revision/platform failures and per-record hold reasons.
Reason counts, such as `history_unavailable`, count held records and may overlap.
With `--verbose`, each failed load includes its formula, revision, path, platform and original error, once per revision/path/platform for that formula.
Proven absent paths are not load failures; failed Git absence checks remain failures.
Unattributed patches and `inreplace` alone do not block reconciliation.
This mode cannot be combined with `--new-history`, `--no-history`, `--json` or `--index` and does not enable reconciliation in ordinary ingest runs.

For bounded daily or reconciliation runs, `--formula-list=<file>` selects newline-separated core formula names instead of `--all` or named arguments.
It requires `--new-history` or `--reconcile-history`, retains bulk queries and uses the Repology index without live per-formula fallbacks.
Only listed names still present in core are loaded; removed names are reported and their records remain unchanged.
An empty list performs no matching, and the unvisited-record summary is scoped to the list.
The advisory database partitions these lists by formula so each execution shard can be saved and retried independently.
