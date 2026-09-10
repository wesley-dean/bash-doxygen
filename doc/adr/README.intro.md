# bash-doxygen Architecture and Reference Documentation

`bash-doxygen` is a documentation-led Doxygen filter for Bash.  It translates
intentionally documented Bash declarations into a Doxygen-friendly intermediate
representation while keeping source-side intent, generated signatures,
diagnostics, release boundaries, and unsupported parser scope explicit.

The repository separates documentation by responsibility:

- [`README.md`](../../README.md) provides project orientation, supported behavior,
  usage, build, release, and testing guidance.
- [`doc/bash-documentation-standard.md`](../bash-documentation-standard.md)
  defines the Bash source-documentation standard consumed by this filter.
- [`doc/awk-documentation-standard.md`](../awk-documentation-standard.md)
  documents the companion AWK source standard used for the filter implementation.
- [`doc/decisions.md`](../decisions.md) provides concise summaries of the
  architecture decisions represented below.
- ADRs preserve the context, rationale, alternatives, constraints, and
  consequences behind durable project decisions.
- Generated Doxygen pages document the maintained AWK filter and shell test
  harness through the same released-filter integration used by downstream
  consumers.

The ADRs remain authoritative for architectural intent.  Generated navigation
and generated Doxygen output are derivative documentation state.

## Architecture Decision Records
