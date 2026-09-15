# ADR-006: Continuously Dogfood Current and Released Filters

Date: 2026-09-09
Last updated: 2026-09-14

## Status

Accepted

## Context

Stable documentation publication under ADR-005 intentionally uses pinned filter
versions.  That stability is desirable for Pages, but it delays discovery of
regressions introduced by newer maintained source or newly published release
artifacts.

`bash-doxygen` is positioned to detect its own integration failures early because
the repository contains maintained shell tooling that can be processed by the
Bash filter and maintained AWK implementation source that is processed by
`awk-doxygen`.  A generated documentation build therefore provides a realistic
mixed-language consumer scenario in addition to the focused parser regression
suite.

Issue #22 adds a narrower downstream semantic boundary.  A successful reference
site proves that Doxygen accepted the generated representation for a real project
corpus, but it does not make every intended entity relationship explicit.  A
small XML-only fixture can assert stable semantic content such as file, variable,
function, and parameter documentation without replacing the broader dogfood
site.

There are two materially different failure windows:

1. maintained source can become incompatible before a release is published; and
2. release packaging can produce bytes that differ from what source-level tests
   exercised or omit/misname the expected release artifact.

One canary cannot cover both windows.  A source canary provides earlier feedback,
while a release canary proves the exact artifact consumers can download.

At the same time, Pages should not silently follow the newest release.  Publication
must remain reproducible and reviewable through the pinned dependencies governed
by ADR-005.

## Decision Drivers

- Detect documentation-filter regressions before downstream consumers encounter
  them.
- Detect source-level integration failures before release publication.
- Detect packaging, release-asset, and checksum failures immediately after a
  release is published.
- Keep stable published documentation independent of automatic latest-version
  movement.
- Exercise real repository source rather than only synthetic fixtures.
- Complement broad site generation with a focused Doxygen semantic fixture.
- Keep canary failures visible in normal GitHub checks.
- Preserve the source-versus-release model established by `awk-doxygen`.

## Decision

The repository SHALL maintain three distinct documentation validation roles:

```text
stable publication
pre-release canary
post-release canary
```

The pre-release and post-release canaries SHALL each exercise both the broad
reference-documentation path and the focused Doxygen semantic path governed by
ADR-004.

### Stable publication

Stable Pages generation SHALL remain governed by ADR-005 and SHALL use the
explicit bashdeps-pinned filter versions in `dependencies-docs.txt`.

A newer `awk-doxygen` or `bash-doxygen` release SHALL NOT automatically change the
filter bytes used for published documentation.  Updating the stable pins remains
an ordinary reviewed dependency change.

### Pre-release canary

Pull-request and `main` CI SHALL generate the repository's reference documentation
using the current repository `doxygen-bash.awk` as the Bash filter.  This canary
SHALL run before release publication and SHALL fail when current Bash filter
source can no longer process the maintained shell documentation corpus or when
Doxygen cannot successfully consume its generated representation.

The pre-release canary SHALL use real maintained repository inputs, including the
shell regression harness.  It MAY reuse the stable vendored AWK filter for AWK
inputs because the purpose of this canary is to evaluate current Bash filter
source, not an unreleased AWK implementation.

After the broad reference build succeeds, the pre-release canary SHALL run the
focused `make test-doxygen` contract with current repository
`doxygen-bash.awk`.  This second assertion path verifies stable semantic content
in Doxygen XML using the dedicated integration fixture from ADR-004.

The canary SHALL NOT modify the stable dependency pin or publish Pages output.
Its generated HTML and focused XML are disposable validation output.

### Post-release canary

A GitHub `release` event for a newly published `bash-doxygen` release SHALL trigger
a second reference-generation canary.

The post-release canary SHALL:

1. identify the release tag from the release event;
2. download the release's canonical `doxygen-bash.awk` artifact and its checksum
   companion;
3. verify the downloaded filter against the released checksum before execution;
4. generate the same repository reference documentation using that exact released
   filter for Bash inputs;
5. exercise that same exact released filter through the focused
   `make test-doxygen` XML-semantic fixture; and
6. fail visibly if the artifact is missing, checksum verification fails, filter
   execution fails, the broad Doxygen build fails, or focused semantic assertions
   fail.

The post-release canary SHALL test the exact downloadable artifact rather than a
checkout path corresponding to the same tag.  This distinction is intentional:
release packaging is part of the consumer contract.

The released filter SHALL be staged in a temporary or generated location and
SHALL NOT replace the stable bashdeps-pinned `vendor/doxygen-bash.awk`
declaration.

ADR-003 also defines development and minified release representations.  Their
focused Doxygen semantic equivalence is exercised before release by
`make test-doxygen-dist`; ADR-006's post-release canary remains centered on the
canonical ordinary artifact that downstream consumers use by default.

### Common validation expectations

The broad canaries SHOULD exercise the same root Doxyfile and maintained
documentation corpus used by stable publication wherever filter-path substitution
permits it.  Divergence between publication and broad canary configuration should
be minimized so passing canaries predict real consumer behavior.

The focused integration path intentionally uses a separate XML-only Doxyfile and
small fixture.  That divergence is purposeful because it isolates semantic
assertions from Pages presentation and from unrelated repository content.

Canary validation complements, rather than replaces, focused filter-level
regression tests.  The parser regression suite remains responsible for narrow
translation contracts; the focused Doxygen fixture proves selected downstream
semantics; and the broad canaries detect integration failures across real filter
output, maintained source, and Doxygen site generation.

A canary failure SHALL block or visibly fail its associated CI run.  The project
SHALL NOT silently ignore a failing dogfood build merely because ordinary parser
fixtures still pass.

## Considered Alternatives

### Always publish Pages with the latest release

This would provide rapid feedback but would make stable documentation change
without a reviewed dependency update.  A bad release could break publication for
an otherwise unchanged repository.  It was rejected in favor of stable pins plus
separate canaries.

### Test only the repository-local filter

This detects many implementation regressions early but cannot detect a malformed,
missing, incorrectly named, or otherwise defective release artifact.  It was
rejected as incomplete.

### Test only the newest release on a schedule

A scheduled latest-release probe would eventually detect release problems but
would provide slower feedback and would not cover failures before release.  A
release-event canary is more direct.  A future scheduled probe MAY be added as
additional defense if external release state warrants it.

### Rely only on parser fixtures

Focused filter-level fixtures are necessary but cannot prove Doxygen integration,
mixed-language filter configuration, Pages-oriented source selection, or release
packaging.  They remain complementary rather than sufficient.

### Rely only on the broad project documentation canary

The project reference corpus is valuable because it resembles real downstream
usage, but a successful site build does not state which semantic entities must be
present.  This was rejected as the sole Doxygen contract.  The focused XML fixture
adds explicit semantic assertions while keeping the broad site canary intact.

### Replace the broad canary with the focused XML fixture

This would make failures easier to localize, but it would stop exercising the
real mixed-language project corpus, shared Doxyfile, ADR navigation, and Pages
configuration.  The two tests protect different boundaries and therefore remain
separate.

### Update the stable pin automatically after a successful release canary

This would conflate validation with dependency-policy mutation.  It was rejected;
stable pin changes remain explicit reviewed commits.

## Consequences

A current-source regression should appear in PR or `main` CI before the code is
released.  A packaging or release-artifact regression should appear immediately
when the release is published, before normal consumers have much opportunity to
adopt it.

The repository intentionally executes more than one documentation path: stable
pinned publication, current-source broad validation, current-source focused
semantic validation, exact-release broad validation, and exact-release focused
semantic validation.  That duplication is accepted because each path protects a
different failure boundary.

Pages remains predictable even if the newest release is broken.  Conversely, a
stable Pages site does not create false confidence that the newest source or
release artifact is healthy.

The focused fixture also provides a controlled place to validate future
namespace, group/module, and class relationships before those representations are
relied upon by the broader repository corpus.

This model intentionally mirrors the sibling Doxygen-filter projects: maintained
source and release artifacts are primary canary targets while stable publication
pins and source-versus-release separation remain unchanged.

## Related Decisions

- ADR-000 requires evidence-backed capability claims.
- ADR-003 defines the release artifacts and canonical ordinary consumer artifact.
- ADR-004 defines focused filter-level regression fixtures, TAP reporting, and
  the XML-only Doxygen semantic integration fixture.
- ADR-005 defines stable pinned documentation publication and the shared broad
  Doxygen corpus used by the canaries.
