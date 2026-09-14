# ADR-003: Build and release versioned doxygen-bash artifacts

Date: 2026-08-18
Last updated: 2026-09-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines the boundary between the maintained `doxygen-bash.awk` source
file and the files distributed to consumers through GitHub Releases.  It records
why release files are generated, what provenance they carry, how integrity is
represented, how minification dependencies are trusted, and which behaviors the
build process must preserve.

## Context

`bash-doxygen` is maintained as a single portable AWK source file named
`doxygen-bash.awk`.  The project originally generated one consumer artifact with
version, build date, and source-commit provenance.  That contract provided a
clear release boundary, but it forced one representation to serve development,
ordinary consumption, and size-sensitive distribution simultaneously.

Related projects now use three generated representations:

1. a development artifact retaining source documentation and comments;
2. an ordinary artifact with full-line source comments removed; and
3. a minified artifact transformed by a separately released AWK Minifier.

The three representations must remain behaviorally equivalent.  Their different
sizes and comment content are distribution concerns rather than different runtime
interfaces.

The AWK Minifier is executable build tooling.  Its exact bytes therefore require
an explicit dependency boundary.  The project already bootstraps a pinned
`bashdeps.bash` release and can use a separate ordinary build manifest without
mixing build tooling into `dependencies-docs.txt`, whose role is governed by
ADR-005.

The AWK implementation also retains one language-specific provenance constraint.
Bare top-level AWK assignments can participate in record processing, so generated
build metadata must remain comments rather than runtime assignments.

## Decision Drivers

- Preserve `doxygen-bash.awk` as the maintained source filename.
- Preserve `doxygen-bash.awk` as the canonical ordinary consumer filename.
- Provide a documented development representation and a smaller minified
  representation without changing runtime semantics.
- Keep released bytes self-describing with version, date, commit, artifact role,
  and, for minified output, minifier provenance.
- Preserve an executable AWK shebang for every executable artifact.
- Avoid runtime behavior or AWK namespace solely for build metadata.
- Pin executable build tooling by immutable URL and SHA-256 digest.
- Keep dependency acquisition explicit and keep `make build` network-free.
- Generate and publish a SHA-256 checksum for every executable artifact.
- Exercise the same regression suite against maintained source and every
  generated AWK representation.
- Keep artifact generation deterministic for a fixed source revision, dependency
  state, and set of build metadata inputs.

## Decision

The project SHALL use the Makefile as the canonical build interface.

### Build dependency boundary

Ordinary build dependencies SHALL be declared in:

```text
dependencies.txt
```

The manifest SHALL be separate from the documentation-only
`dependencies-docs.txt` manifest governed by ADR-005.

The build manifest SHALL pin the released AWK Minifier artifact used to create
the minified representation.  The initial pin for this three-artifact contract
is:

```text
Repository: wesley-dean/awk-minifier
Release:    v0.2.4
Artifact:   awk-minifier.awk
Destination: vendor/awk-minifier.awk
SHA-256:    9668287c394a48e6143b63074fea8ab9fed240ef0637ac169780e08e30661803
```

`make deps` MAY use the network to synchronize ordinary build dependencies.
`make deps-check` SHALL verify prepared dependency state without network access or
repair.

`make build` SHALL NOT synchronize or repair dependencies.  It SHALL verify the
prepared build dependency state and fail visibly when the pinned minifier is
missing or has unexpected bytes.

### Development artifact

`make build` SHALL generate:

```text
dist/doxygen-bash.dev.awk
```

The development artifact SHALL preserve the maintained source body, including
source documentation and implementation comments.  It SHALL preserve
`#!/usr/bin/awk -f` as its first line and add a generated provenance header that
identifies the artifact as `development`, identifies the maintained source, and
records:

```text
DOXYGEN_BASH_VERSION=<version>
DOXYGEN_BASH_BUILD_DATE=<date>
DOXYGEN_BASH_BUILD_COMMIT=<commit>
```

### Ordinary artifact

The build SHALL derive:

```text
dist/doxygen-bash.awk
```

from the development artifact.  It SHALL preserve the executable shebang and the
build-owned provenance header while removing full-line comments from the source
body.  It SHALL identify itself as the `ordinary` artifact.

`dist/doxygen-bash.awk` remains the canonical default consumer artifact.  Existing
downstream dependency declarations and ADR-006's exact-release documentation
canary may therefore continue using this filename unless they intentionally opt
into another representation.

### Minified artifact

The build SHALL derive:

```text
dist/doxygen-bash.min.awk
```

from the ordinary artifact body using the bashdeps-pinned
`vendor/awk-minifier.awk` artifact.

The build-owned provenance header SHALL remain outside AWK Minifier's transform
input.  The generated minified header SHALL record the ordinary provenance fields
plus:

```text
Minifier: AWK Minifier v0.2.4
```

The minified representation SHALL remain an executable AWK program with the same
observable filter behavior as maintained source and the other generated
representations.

### Integrity artifacts

The build SHALL produce one standard `sha256sum`-format checksum beside each AWK
artifact:

```text
dist/doxygen-bash.dev.awk.sha256
dist/doxygen-bash.awk.sha256
dist/doxygen-bash.min.awk.sha256
```

The complete release contract is therefore six files: three executable AWK
artifacts and three adjacent SHA-256 files.

### Validation and release

`VERSION`, `BUILD_DATE`, and `BUILD_COMMIT` SHALL remain Make inputs.  Release
automation MAY override `VERSION` with the calculated semantic version while
retaining commit-derived defaults for build date and commit.

The regression harness SHALL accept explicit filter paths so one semantic suite
can validate maintained source and all generated AWK artifacts.  Generated
artifact validation SHALL also cover provenance expectations and adjacent
checksum verification.

The semantic-versioning workflow SHALL prepare and verify build dependencies,
build and test all three exact release artifacts, verify all three checksums, and
attach all six files to the GitHub Release.

Generated `dist/` and `vendor/` state remains untracked repository state.

## Considered Alternatives

### Continue publishing only dist/doxygen-bash.awk

One artifact minimizes release assets, but it makes source documentation size and
consumer size the same concern.  This was rejected because separate development,
ordinary, and minified representations provide clearer purposes while the test
suite can prove one runtime contract across all three.

### Remove provenance comments from ordinary and minified output

This would reduce the files slightly further, but it would make downloaded bytes
less inspectable and would weaken the established source-to-release boundary.
Build-owned provenance is therefore preserved even though source-body comments are
removed.

### Minify the development artifact directly

The minifier could consume the fully documented development body.  This was
rejected because the ordinary artifact is the intended intermediate consumer
representation.  Making minification derive from ordinary output gives the build
a straightforward development -> ordinary -> minified pipeline.

### Use the current repository copy of AWK Minifier or a moving latest release

This would avoid one pinned dependency declaration, but the output of an
executable transformer would then depend on unreviewed moving bytes.  A reviewed
immutable release URL and digest are required instead.

### Synchronize dependencies automatically from make build

This would hide network and repair behavior inside an apparently deterministic
build target.  It was rejected in favor of explicit `make deps` acquisition and
no-network verification during `make build`.

### Add bare AWK assignments for build metadata

Top-level AWK expressions can participate in record processing and trigger the
default action.  Provenance metadata remains comments so it cannot alter filter
behavior.

## Consequences

Consumers can choose a fully documented development artifact, the canonical
ordinary artifact, or a minified artifact while retaining one behavioral
contract.  Every executable artifact is independently verifiable with its
adjacent checksum.

The release contains six assets rather than two.  Build preparation gains one
pinned executable dependency and therefore requires explicit `make deps` on a
fresh checkout before the complete distribution can be built.

Once dependencies are prepared, build and verification remain offline with
respect to repository dependency acquisition.  The generated files remain
self-identifying, and the exact minifier version is observable in both the
committed manifest and minified artifact header.

Downstream projects that already consume `doxygen-bash.awk` need no filename
migration.  They may adopt `.dev.awk` or `.min.awk` deliberately when those
representations better fit their use case.

## Related Decisions

- ADR-000 requires evidence-oriented reasoning and explicit capability
  boundaries.
- ADR-001 preserves consistency in generated Doxygen-facing output.
- ADR-002 defines the synthesized function-signature boundary within the filter.
- ADR-004 defines the regression strategy used to prove equivalent behavior
  across maintained and generated representations.
- ADR-005 keeps documentation-only dependency state separate from ordinary build
  dependencies.
- ADR-006 intentionally continues to canary the canonical released
  `doxygen-bash.awk` artifact.
