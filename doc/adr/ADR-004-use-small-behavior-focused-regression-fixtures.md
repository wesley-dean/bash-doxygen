# ADR-004: Use small behavior-focused regression fixtures and TAP reporting

Date: 2026-08-19
Last updated: 2026-09-14

## Status

Accepted

## Intent and Documentation Posture

This ADR records how `bash-doxygen` structures regression tests for its
source-to-pseudo-C++ translation behavior and how those results are reported.
The decision favors many small cases that establish narrow observable contracts,
uses one semantic suite for every maintained/generated representation, and emits
standards-compliant TAP so local and automated callers receive a machine-readable
test stream.  A separate focused Doxygen integration path verifies that selected
intermediate representations also produce the intended downstream documentation
model.

## Context

The regression suite uses small Bash fixtures, matching pseudo-C++ golden files,
and normalized diagnostic expectations.  That model has made parser regressions
easy to localize while avoiding a test-framework dependency.

The original harness printed lines resembling TAP, but it did not emit numbered
test points, a TAP version, or a test plan.  It also stopped at the first failed
assertion.  Issue #30 requires actual TAP output without making lint part of the
`test` target.

ADR-003 now defines three generated distribution representations in addition to
the maintained source.  Issue #31 requires each generated AWK artifact to execute
the same semantic suite.  Running several independent TAP documents and merely
concatenating them would create an ambiguous top-level stream, so the harness
needs to understand multiple explicitly labeled filters in one invocation.

Issue #22 identifies a separate gap.  Golden pseudo-C++ output can prove the
translation contract owned directly by this repository, but it cannot prove that
Doxygen interprets that representation as the intended file, variable, function,
and parameter model.  The sibling `python-doxygen` project already uses a small,
XML-only Doxygen fixture for this boundary.  Reusing that pattern keeps the
integration test narrow and avoids coupling regression expectations to generated
HTML presentation details.

## Decision Drivers

- Make a failing test identify the affected behavior and representation quickly.
- Cover the declaration forms and diagnostics documented as supported behavior.
- Preserve the existing fixture-and-golden-output testing model.
- Keep individual inputs and expected outputs short enough to inspect directly.
- Avoid adding a test framework dependency for a portable AWK project.
- Exercise maintained source and every generated distribution artifact with the
  same semantic suite.
- Report `make test` as one valid TAP stream.
- Keep GNU awk linting separate from runtime regression testing.
- Test generated-artifact provenance and checksum boundaries without snapshotting
  complete generated files.
- Prove selected Doxygen-facing semantics without snapshotting generated HTML.
- Reuse a dedicated integration fixture rather than overloading the repository's
  full reference-documentation corpus with narrow semantic assertions.

## Decision

Regression coverage SHALL primarily use small, behavior-focused fixtures.

Successful translation cases SHALL live in `tests/fixtures/` and use matching
pseudo-C++ golden files in `tests/expected/`.  Diagnostic cases SHALL live in
`tests/diagnostics/` and SHALL verify both ordinary warning behavior and
`--strict` non-zero behavior after source-location prefixes are normalized.

The suite SHALL include direct coverage for both `--compact` output and default
blank-placeholder behavior.

### One harness, multiple filter representations

`tests/run-tests.sh` SHALL accept one or more explicitly labeled filter paths and
run the same observable behavior suite against each path.  The default invocation
MAY continue to select maintained source for developer convenience.

The Make targets SHALL expose these boundaries:

```text
make test-source  # maintained doxygen-bash.awk only
make test-dist    # development, ordinary, and minified dist artifacts
make test         # maintained source plus all three dist artifacts
```

`make test` SHALL emit one TAP stream rather than concatenating independently
planned TAP streams.

### TAP contract

The harness SHALL emit a TAP version declaration, numbered test points, TAP
comment diagnostics, and a test plan.  Ordinary assertion failures SHOULD be
accumulated so a run can report multiple regressions before exiting non-zero.
A TAP bail-out SHALL be reserved for test state that prevents meaningful
continuation, such as a malformed filter specification.

Diffs and filter diagnostics included in test output SHALL be rendered as TAP
comment diagnostics so they do not become accidental test points or corrupt the
stream grammar.

### Generated-artifact contract

In addition to semantic fixtures, generated artifacts SHALL be checked for their
build boundary.  The suite SHALL verify the executable AWK shebang, generated
provenance fields, expected artifact role, representation-specific expectations,
and the adjacent checksum.

The development artifact SHALL retain maintained source commentary.  The ordinary
artifact SHALL retain build-owned provenance while omitting full-line comments
from its source body.  The minified artifact SHALL identify the pinned AWK
Minifier used to transform the ordinary body.

### Focused Doxygen semantic integration

The repository SHALL maintain a dedicated Doxygen integration fixture and
configuration beneath:

```text
tests/doxygen/
```

This fixture SHALL remain intentionally small.  It exists to verify the semantic
contract between Bash documentation, `bash-doxygen`'s generated pseudo-C++, and
Doxygen rather than to reproduce the repository's full reference site.

`make test-doxygen` SHALL run the selected `DOXYGEN_BASH_FILTER` against that
fixture through Doxygen.  The dedicated Doxyfile SHALL generate XML and SHALL NOT
generate HTML.  Assertions SHALL inspect the generated XML for stable semantic
content representing, at minimum:

- file-level documentation;
- one documented variable;
- one documented function;
- the function's parameter identity and documentation; and
- the function's return documentation.

The integration test SHALL assert meaningful names and documentation content
rather than snapshotting Doxygen's complete XML tree.  This keeps the test strong
enough to detect a representation that Doxygen no longer understands while
avoiding unnecessary coupling to Doxygen formatting or identifier churn.

`make test-doxygen-dist` SHALL build the development, ordinary, and minified
artifacts and run the same focused Doxygen contract against each exact generated
filter.  The maintained source path and generated-artifact paths therefore share
one downstream semantic fixture just as they share one filter-level regression
suite.

Focused Doxygen integration is an adjacent validation target rather than part of
the TAP stream emitted by `make test`.  Doxygen availability is an environment
requirement for `make test-doxygen` and `make test-doxygen-dist`, while ordinary
filter-level regressions remain runnable without Doxygen.

### Lint boundary

GNU awk lint is a source-validation concern, not a regression-test concern.
`make check` SHALL run `gawk --lint=fatal` against maintained root AWK source.
The `test`, `test-source`, and `test-dist` targets SHALL NOT invoke linting.
Automation MAY invoke `make check` as a separate validation step adjacent to the
regression suite.

## Considered Alternatives

### Keep TAP-like output

Human-readable `ok - description` lines were adequate for visual inspection, but
they did not form a complete TAP document.  This was rejected because callers
should not need repository-specific parsing to distinguish assertions from
summaries or diagnostics.

### Run one independent TAP document per artifact

Each filter representation could invoke the harness separately.  This is useful
for `test-source` and `test-dist` as independent entry points, but concatenating
four complete documents for `make test` would make the aggregate output unclear.
The harness therefore accepts multiple labeled filters and emits one plan for the
complete invocation.

### Add Bats or another test framework

A framework could provide richer assertion APIs, but the POSIX shell harness
already has the primitives required for deterministic fixture comparison,
diagnostics, TAP serialization, and exit-status checks.  Adding a dependency
would increase setup cost without materially strengthening these contracts.

### Put make check inside make test

This would make one command appear comprehensive, but it would conflate a
GNU-awk-specific lint policy with behavior tests that should remain runnable with
a selected AWK interpreter.  Lint remains a separate explicit target.

### Test internal AWK functions directly

Helpers such as identifier sanitization and variable classification are
implementation details.  The suite continues to protect observable filter
behavior so internals can be refactored without unnecessary fixture churn.

### Snapshot generated Doxygen HTML

The focused integration test could generate HTML and compare complete pages or
file trees.  This was rejected because presentation markup, filenames, and other
rendering details can change independently of the semantic documentation model.
XML provides a smaller and more direct assertion surface for Doxygen entities and
documentation content.

### Use the full project reference corpus for every semantic assertion

The existing documentation canary already proves that real maintained repository
source can flow through Doxygen.  Adding narrow entity assertions to that large
corpus would make failures harder to localize and would mix site-generation
concerns with parser semantics.  The focused fixture remains separate while the
broader canary continues independently under ADR-006.

## Consequences

A `make test` failure identifies both the behavior and the filter representation
that failed.  CI systems and developer tooling can consume the output as TAP
without interpreting repository-specific summary lines.

The suite performs more work because every fixture runs against four filter
representations in the complete path.  That cost is accepted because it proves
that stripping comments and minification do not change the public translation
contract.

Generated artifact checks protect build metadata and checksums without accepting
large generated files as golden source.  Golden pseudo-C++ files remain focused
on the translation behavior this project owns directly.

Focused Doxygen integration adds a second semantic boundary.  A generated
pseudo-C++ representation can now fail validation even when it still matches its
golden file if Doxygen no longer creates the intended documentation model from
that representation.

The XML-only integration output is generated under ignored temporary state and is
removed by `make integration-clean` or the ordinary clean path.  No generated
Doxygen output becomes maintained source.

Lint failures remain independently actionable through `make check` and cannot be
mistaken for runtime fixture failures.

## Open Questions and Follow-Ups

Namespace, group/module, and class assertions SHALL be added to the focused
Doxygen fixture when the corresponding source-language features are implemented.
The integration harness should establish the semantic assertion pattern first;
it should not pre-commit those future features to an unverified pseudo-C++
representation.

Coverage measurement for AWK is not introduced by this decision.  If the project
later adopts coverage tooling, it should be evaluated separately rather than
using a percentage target as a substitute for behavior-oriented cases.

## Related Decisions

- ADR-000 requires evidence-oriented reasoning and explicit scope boundaries.
- ADR-001 and ADR-002 define parameter and synthesized-signature invariants that
  the fixture corpus exercises.
- ADR-003 defines maintained, development, ordinary, and minified
  representations that share both filter-level and focused Doxygen validation.
- ADR-006 defines broader current-source and exact-release Doxygen canaries that
  also exercise this focused semantic boundary.
