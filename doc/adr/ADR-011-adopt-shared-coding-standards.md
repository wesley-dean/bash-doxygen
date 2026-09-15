# ADR-011: Adopt Shared Coding Standards

Date: 2026-09-15

## Status

Accepted

## Context

Related repositories share reusable coding, documentation, architecture, release,
and development-workflow standards through `wesley-dean/coding_standards`.
Maintaining independent copies would invite drift, while dynamic retrieval would
make repository governance depend on moving network state.

The repository needs an inspectable, reproducible way to adopt those standards
without weakening its existing ADR hierarchy or repository-specific contracts.

The repository-local documentation-standard files removed by this decision are:

- `doc/bash-documentation-standard.md`
- `doc/awk-documentation-standard.md`

Their live references are redirected to the corresponding managed files under `doc/standards/`, leaving one authoritative path for each shared documentation standard.

## Decision Drivers

- Keep reusable engineering standards consistent across related repositories.
- Preserve accepted repository ADRs as the authority for local architecture.
- Record the exact adopted release and verified archive digest.
- Keep governing standards readable from an ordinary offline checkout.
- Remove duplicate live documentation-standard paths where they exist.
- Avoid permanent standards downloaders or automatic synchronization machinery.

## Decision

The repository SHALL commit the complete released `coding_standards@v1.0.9`
snapshot beneath `doc/standards/`.  `.codingstandardrc` SHALL record the upstream
source, resolved release, verified archive SHA-256
`86e91725f30dc5d91a3c7f7158e17d6a8538519b3be10709440e179027c37a03`, and
managed destination.  The release tag resolves to commit
`22e42d2583cc98d4a7db8c48e1ab0c459f76946e`.

Applicable imported standards are governing requirements.  Accepted local ADRs
and explicit repository policy take precedence when they intentionally refine or
supersede a shared standard.  Presence does not imply applicability, and imported
examples remain illustrative unless a governing standard explicitly says
otherwise.

Imported standards SHALL NOT be edited locally.  Future standards upgrades SHALL
replace the complete managed snapshot, update `.codingstandardrc`, and be reviewed
through the normal pull-request process.  No permanent updater, Make target,
dependency-manifest entry, or synchronization workflow is introduced.

## Alternatives Considered

### Maintain independent local copies

Rejected because parallel copies create ambiguous authority and predictable drift.

### Import only currently applicable files

Rejected because partial snapshots weaken provenance and can omit newly introduced
cross-cutting governance.

### Fetch standards dynamically

Rejected because ordinary development and governance should not depend on moving
network state.

## Consequences

A normal checkout contains the exact shared standards snapshot.  Standards updates
produce explicit reviewable diffs, while project-specific exceptions remain in the
repository's own governance.  The repository accepts the storage cost of the full
snapshot in exchange for deterministic, inspectable standards.

## Compatibility

This decision changes governance and maintained documentation only.  It does not
intentionally change runtime behavior, public interfaces, compatibility promises,
build products, or release semantics.

## Relationships

Existing accepted ADRs remain authoritative for repository-specific architecture
and behavior.  This ADR establishes the shared-standards layer beneath those
decisions.
