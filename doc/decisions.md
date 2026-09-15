# Architecture Decisions

This document provides concise summaries of the architecture decisions governing
`bash-doxygen`.  The ADRs themselves remain authoritative; these summaries are
navigation aids rather than substitutes for the full decisions.

## ADR-000: Capability scope and epistemic honesty

The project prioritizes accuracy, explicit capability boundaries, evidence,
separation of concerns, and resistance to over-commitment or performative
agreement.  Claims about supported syntax, portability, validation, or generated
behavior must therefore match what the implementation and tests actually prove.
See
[`ADR-000`](adr/ADR-000-capability-scope-and-epistemic-honesty.md).

## ADR-001: Keep documented and synthesized parameter names aligned

Source-side Bash parameter names are resolved once into canonical Doxygen-safe
identifiers, including deterministic collision handling, and the same resolved
names are used in both emitted `@param` directives and synthesized declarations.
Standard `[in]`, `[out]`, and `[in,out]` qualifiers are preserved as Doxygen
metadata while only the following parameter token participates in sanitization
and uniqueness resolution.  This preserves natural Bash documentation and
parameter direction semantics without allowing the documentation and generated
signature to disagree.  See
[`ADR-001`](adr/ADR-001-keep-documented-and-synthesized-parameter-names-aligned.md).

## ADR-002: Use synthesized declarations as the emitted function signature

Source `@fn` metadata remains useful for intent and mismatch validation, but a
successfully recognized function suppresses that directive from generated output.
The synthesized pseudo-C++ declaration is the sole emitted function signature,
preventing a source-side zero-argument `@fn` form from contradicting generated
parameters.  See
[`ADR-002`](adr/ADR-002-use-synthesized-declarations-as-the-emitted-function-signature.md).

## ADR-003: Build and release versioned doxygen-bash artifacts

The maintained filter remains `doxygen-bash.awk`, while `make build` produces
three behaviorally equivalent release representations: documented
`doxygen-bash.dev.awk`, canonical ordinary `doxygen-bash.awk`, and
`doxygen-bash.min.awk`.  The minified form is produced with a SHA-256-pinned AWK
Minifier declared separately in `dependencies.txt`; build stays offline after
explicit dependency preparation.  All three artifacts preserve build provenance
and publish adjacent `.sha256` files, creating a six-file release contract.  See
[`ADR-003`](adr/ADR-003-build-and-release-a-versioned-doxygen-bash-artifact.md).

## ADR-004: Use small behavior-focused regression fixtures and TAP reporting

Regression coverage remains organized around small named source fixtures and
matching golden pseudo-C++ output so each failure identifies a narrow observable
contract.  One POSIX shell harness exercises maintained source plus all three
generated AWK artifacts as standards-compliant TAP, while a separate XML-only
Doxygen fixture verifies selected downstream file, variable, function, parameter,
and return semantics for maintained and generated filters.  GNU awk lint remains
a separate `make check` boundary rather than becoming part of either semantic
test path.  See
[`ADR-004`](adr/ADR-004-use-small-behavior-focused-regression-fixtures.md).

## ADR-005: Publish ephemeral reference documentation with pinned filters

Generated Doxygen HTML is disposable output under `doc/reference/` and is never
committed merely to support GitHub Pages.  Documentation dependencies are
isolated in `dependencies-docs.txt`, synchronized through a directly bootstrapped
and SHA-256-pinned bashdeps release, and consumed from `vendor/`; stable Pages
publication uses pinned released `awk-doxygen` and `bash-doxygen` artifacts rather
than repository-local filter source.  Dependency synchronization may use the
network, while verification and `make docs` remain non-repairing after state is
prepared.  See
[`ADR-005`](adr/ADR-005-publish-ephemeral-reference-documentation-with-pinned-filters.md).

## ADR-006: Continuously dogfood current and released filters

Stable Pages publication stays pinned, while two separate canaries detect
regressions earlier.  Pull-request and `main` CI exercise current repository
`doxygen-bash.awk` through both the broad project-reference corpus and the focused
XML semantic fixture, while the release-published canary repeats those checks
with the exact checksum-verified canonical released `doxygen-bash.awk` artifact.
Neither canary mutates the stable dependency pin, and both complement rather than
replace the filter-level regression suite.  See
[`ADR-006`](adr/ADR-006-continuously-dogfood-current-and-released-filters.md).

## ADR-007: Publish ephemeral ADR navigation across documentation paths

Stable publication and both ADR-006 canaries generate the same ignored
`doc/adr/README.md` landing page from maintained intro/outro framing and a linked
TOC produced by a pinned released adrctl artifact.  The new tool remains in the
existing documentation-only dependency manifest, while `make adr-index`,
`make docs`, and `make docs-canary` preserve the offline-after-preparation
boundary.  Doxygen uses the generated composite as its main page, and routine
documentation generation remains free of automatic ADR relationship graphs.  See
[`ADR-007`](adr/ADR-007-publish-ephemeral-adr-navigation-across-documentation-paths.md).

## ADR-008: Bound declaration association with explicit lexical rules

Explicit `local`, `readonly`, `export`, `declare`, and `typeset` commands may
document a single uninitialized variable while preserving their existing
metadata.  Only explicitly recognized ShellCheck `disable=` comments are
transparent between a Doxygen block and its declaration; arbitrary comments
remain association barriers.  Documented multi-name explicit declarations are
rejected with a diagnostic and no partial first-symbol output, using a small
lexical word counter rather than a general Bash parser.  See
[`ADR-008`](adr/ADR-008-bound-declaration-association-with-explicit-lexical-rules.md).

## ADR-009: Separate Bash symbols from documentation namespaces

Literal qualified Bash function names remain authoritative source identities,
while qualified `@fn` directives or explicit `@namespace` plus `@fn` may define
a separate documentation identity for a differently named implementation.
Namespace evidence is never inferred from prefixes, redundant evidence must
agree, and conflicts are diagnostics rather than silently resolved by precedence.
Qualified documentation identities are emitted as nested C++ namespace blocks
and must pass the focused Doxygen XML semantic test.  See
[`ADR-009`](adr/ADR-009-separate-bash-symbols-from-documentation-namespaces.md).

## ADR-010: Map explicit Bash modules to Doxygen groups

`@module` defines the canonical Bash-facing module vocabulary, while `@package`
is accepted as an exact alias and is translated to the same language-neutral
Doxygen group model rather than package semantics.  Module-only blocks create
flat Doxygen groups; explicit `@fn` and `@var` blocks may opt individual symbols
into a group with `@ingroup`, including namespaced functions governed by ADR-009.
For successfully grouped variables, source `@var` remains required for identity
validation but is consumed so the synthesized declaration is the single
Doxygen-facing grouped variable.  Membership is local to each documentation
block, is never inferred from names or files, and nested groups plus class
abstractions remain separate future work.  See
[`ADR-010`](adr/ADR-010-map-explicit-bash-modules-to-doxygen-groups.md).

## ADR-011: Adopt shared coding standards

**Status:** Accepted

The repository adopts the complete verified `coding_standards@v1.0.9` snapshot
beneath `doc/standards/` with provenance in `.codingstandardrc`.  Applicable
imported standards govern where relevant, subject to accepted local ADRs and
explicit policy; presence does not imply applicability, and imported examples are
illustrative.  Duplicate live documentation-standard files are removed where
present so shared documentation rules have one authoritative managed path.  See
[ADR-011](adr/ADR-011-adopt-shared-coding-standards.md).
