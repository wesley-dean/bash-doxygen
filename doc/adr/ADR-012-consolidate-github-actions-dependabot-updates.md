# ADR-012: Consolidate Scheduled GitHub Actions Dependabot Updates

Date: 2026-11-12

## Status

Accepted

## Decision

The repository SHALL retain a weekly GitHub Actions Dependabot version-update
schedule and a seven-day cooldown.  One group named `actions-version-updates`
SHALL use `applies-to: version-updates` with the wildcard pattern `"*"`,
without restricting SemVer `update-types`.  Eligible routine major, minor,
and patch updates can therefore be proposed together.

Security updates SHALL remain outside this routine group and SHALL NOT be
delayed by its schedule or cooldown.  The existing Dependabot auto-merge
workflow SHALL retain its non-major-only guard; a group containing any major
version update must receive the normal review and authorization process.
Existing required checks, CODEOWNERS, protections, and dependency pinning
remain in effect.

This implements the applicable shared
`doc/standards/general/dependabot-maintenance-standard.md` policy introduced
with `coding_standards@v3.2.0`, while retaining repository-specific authority
over CI, release publishing, and mandatory review.  It is a separately
reviewable change to active `.github/dependabot.yml`, not an automatic
effect of adopting a standards release.

## Context and Constraints

The previous configuration already checked GitHub Actions on a weekly
schedule and delayed eligible routine updates for seven days.  However, its
`minor-and-patch` group excluded major releases, so Dependabot could propose
a grouped minor/patch PR plus individual major-release PRs in the same
maintenance cycle.  Repeating this pattern across repositories produces
unnecessary review and merge operations.

The `template-bash` pilot and subsequent adoption in related Bash projects
demonstrated a grouped routine version-update configuration.  A specific
observed pilot PR consolidated six non-major updates and passed its available
checks.  That observation does not establish how mixed-major groups behave
in every future run or guarantee a fixed reduction in review workload.

The repository has an existing Dependabot auto-merge workflow that checks
`dependabot/fetch-metadata` and excludes
`version-update:semver-major`.  Its intended semantics are to keep
major-containing PRs outside automatic merge requests, including groups
whose highest SemVer update is major.  GitHub ruleset/branch protection
must independently enforce required CODEOWNER approval; a CODEOWNERS file
alone is insufficient.

The repository publishes security-sensitive executable filters, versioned
release assets, and documentation canaries.  Some GitHub Actions can
exercise broader authority than ordinary test jobs.  A passing linter does
not establish behavior of an unexercised release or publishing workflow.

## Decision Drivers

- Reduce repetitive Dependabot PR review across maintained projects.
- Retain the existing weekly schedule and seven-day cooldown.
- Group major, minor, and patch routine version updates consistently.
- Keep security-response timing independent of routine version maintenance.
- Preserve the existing non-major auto-merge boundary.
- Avoid weakening independent GitHub required checks or code-owner review.
- Maintain provenance, pinned actions, and relevant release-path evidence.
- Avoid suppressing fresh updates behind a restrictive new open-PR limit.
- Keep the scope to GitHub Actions dependency update configuration.

## Policy and Operational Details

### Routine version-update grouping

Use one wildcard version-update group per configured GitHub Actions ecosystem.
Do not use `update-types` restrictions in the broad group.  Existing
commit-message conventions, ecosystem directory, and weekly schedule remain
unchanged.  Do not introduce an artificially low
`open-pull-requests-limit` during backlog cleanup.

Dependabot may still generate multiple PRs due to resolution constraints,
timing, and unsupported updates.  The group does not batch changes across
different repositories or retroactively replace previously created PRs.

### Security updates

The `applies-to: version-updates` selector intentionally excludes security
updates.  Dependabot alerts, dependency graph, and security update automation
are configured separately in GitHub and must be independently verified.
Changing the routine group does not establish that those features are enabled.

### Review and merge authority

Every dependency within a group remains subject to review.  Inspect the
highest-risk update, including breaking changes, write-capable actions,
tagging, signing, artifact publishing, and registry credentials.  The existing
non-major auto-merge condition is unchanged.  A major-containing group is
expected to remain outside that path based on the metadata action's
highest-SemVer classification; this behavior must be verified against the
actual active workflow and resulting PRs.

Do not loosen CODEOWNERS review, branch protections, required security
checks, or test obligations.  Relevant release-path checks are preferable
to declaring a group safe merely because unrelated unit tests pass.

### Exceptions and reconciliation

A specific high-authority or migration-sensitive dependency MAY be
isolated in a separate version-update group when the reason is documented
and periodically reviewed.  Do not use a global `ignore` rule to hide an
update that needs a separate review.

Leave existing Dependabot PRs open until a subsequent observed group is
verified to cover their updates.  Record baseline and subsequent PR volume,
CI outcomes, and review effort before claiming a sustained improvement.

## Threats and Residual Risks

A compromised or incompatible upstream dependency can be hidden within a
large group.  A major upgrade can break compatibility.  A green check can
miss an untested release path.  A restrictive PR limit can block fresh
updates behind stale PRs.  Misconfigured security-update settings can
leave known vulnerabilities unaddressed.  An agent requesting auto-merge
might not have evidence that required CODEOWNER review is enforced.

Risks are mitigated by review of individual dependencies, retained
full-commit-SHA action pinning, independent security configuration,
relevant CI evidence, existing non-major auto-merge boundaries, and
effective branch protection.  None proves the safety of upstream code
or of release paths that were not exercised.

## Alternatives Considered

### Keep the minor/patch-only group

Preserves isolation of major changes, but generates additional individual
major PRs and repeated review overhead.  Rejected as the default; narrow
exceptions remain available.

### Auto-merge all grouped PRs

Reduces review actions but expands automated merge authority to potentially
breaking updates.  Rejected.

### Include security updates in the weekly group

Could delay advisory-driven fixes and obscure their urgency.  Rejected in
favor of independent security triggering.

### Limit outstanding PRs to one or two

May suppress new proposals while old PRs occupy the limit.  Deferred pending
measured backlog reconciliation.

### Change to monthly scheduling or group across ecosystems

Could reduce further PR churn, but introduces unrelated maintenance timing
and test-surface changes.  Not adopted for this single-ecosystem project.

## Compatibility, Consequences, and Expected Outcomes

Only the active Dependabot version-update configuration and associated
documentation are changed.  No Bash filter behavior, public interface,
Make targets, build formats, reference documentation generation, release
contracts, or branch protections are modified.

A new scheduled run may produce fewer routine GitHub Actions version-update
PRs, but larger grouped PRs may require more focused validation or a
narrow exception.  Existing outstanding PRs are not automatically closed.
The actual reduction in review workload remains to be measured after
Dependabot executes the configuration.

## Relationships

- ADR-003 governs build/release artifact compatibility.
- ADR-004 governs behavior-focused testing evidence.
- ADR-005/006 govern pinned documentation and release canary workflows.
- ADR-007 governs ephemeral generated documentation and ADR navigation.
- ADR-011 establishes the pinned shared coding standards layer.
