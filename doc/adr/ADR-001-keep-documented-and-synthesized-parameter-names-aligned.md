# ADR-001: Keep documented and synthesized parameter names aligned

Date: 2026-08-15
Last updated: 2026-09-14

## Status

Accepted

## Intent and Documentation Posture

This ADR records the invariant used when Bash-oriented parameter names must be
translated into identifiers that Doxygen can associate with a synthesized
pseudo-C++ declaration.  The decision is deliberately narrow: it governs the
relationship between documented `@param` names and emitted declaration names;
it does not expand the filter into a Bash parser.

## Context

`bash-doxygen` accepts natural Bash documentation and converts documented Bash
declarations into a Doxygen-friendly pseudo-C++ representation.  Bash authors
may describe positional parameters using names such as `$1` and `$2`, while
those strings are not suitable parameter identifiers in the synthesized
pseudo-C++ declaration.

The filter already sanitizes parameter names while constructing a declaration.
For example, `$1` becomes `_1`.  Before this decision, the documentation block
was emitted unchanged, so Doxygen received `@param $1` alongside a declaration
containing `String _1`.  Doxygen validates parameter documentation against the
associated declaration, making that disagreement observable downstream.

The same problem can occur when distinct source names sanitize to the same
identifier.  For example, `--foo` and `foo` both initially sanitize to `foo`;
the declaration generator disambiguates the second occurrence as `foo_2`.
Documentation must use that same resolved name rather than repeating the
sanitization independently.

Doxygen also permits direction metadata on parameter commands:

```text
@param[in] name Input value.
@param[out] name Output value.
@param[in,out] name Value read and modified by the function.
```

That bracketed direction is metadata associated with the parameter; it is not
part of the parameter name.  The original recognition rule required whitespace
immediately after `@param`, so these forms were preserved as ordinary text but
were not included in the synthesized parameter list.  Treating the qualifier as
part of the name would be equally incorrect because sanitization and collision
handling apply only to the source-side parameter token.

## Decision Drivers

- Preserve natural Bash documentation such as `@param $1` in source files.
- Preserve standard Doxygen parameter direction metadata when authors use it.
- Emit a representation that Doxygen can associate reliably with the generated
  declaration.
- Keep declaration generation and documentation rewriting deterministic.
- Avoid duplicated sanitization logic that could diverge when names collide.
- Preserve parameter qualifiers, descriptions, and ordering while changing only
  the emitted parameter identifier.
- Keep the filter small and inspectable rather than introducing a general Bash
  parser.

## Decision

For each documented function, the filter SHALL resolve every recognized source
`@param` name to one canonical emitted identifier before emitting either the
documentation block or the pseudo-C++ declaration.

The filter SHALL recognize these parameter directive forms:

```text
@param NAME Description.
@param[in] NAME Description.
@param[out] NAME Description.
@param[in,out] NAME Description.
```

The optional direction qualifier is Doxygen metadata and SHALL be preserved
verbatim in generated documentation.  It SHALL NOT participate in identifier
sanitization, uniqueness resolution, or synthesized declaration generation.
Only the parameter-name token that follows the directive and optional qualifier
is subject to those operations.

The canonical mapping SHALL apply the existing identifier sanitization rules and
the existing uniqueness rules in source order.  Both outputs SHALL consume the
same resolved name:

```text
Source:
@param[in] $1 First value.

Filtered representation:
@param[in] _1 First value.
int example(String _1);
```

The filter SHALL rewrite only the parameter-name token in the emitted `@param`
line.  The source file is not modified.  The directive spelling, supported
direction qualifier, whitespace before the name, and remainder of the parameter
documentation are preserved.

When multiple source names sanitize to the same identifier, the documentation
and declaration SHALL use the same deterministic unique names regardless of
their direction qualifiers.  For example, `@param[in] --foo` followed by
`@param[out] foo` becomes `foo` followed by `foo_2` in both the documentation
and synthesized declaration while retaining `[in]` and `[out]` on their
respective documentation lines.

Bracketed `@param` forms other than `[in]`, `[out]`, and `[in,out]` are outside
the structural recognition contract.  They MAY still pass through as ordinary
Doxygen text, but the filter SHALL NOT guess at their meaning or synthesize a
parameter from an unrecognized qualifier.

## Considered Alternatives

### Require Doxygen-safe names in Bash source documentation

Downstream projects could write `@param _1` instead of `@param $1`.  This was
rejected because it exposes an implementation detail of the filter and makes
Bash documentation less natural to its authors and readers.

### Rewrite positional parameters only

The immediate defect was observed with `$N` names, so the filter could special
case only positional parameters.  This was rejected because any source name
that requires sanitization or uniqueness can create the same documentation to
declaration mismatch.

### Sanitize documentation independently during emission

The documentation emitter could run the sanitization algorithm again.  This was
rejected because collision handling is order-dependent; resolving names twice
creates an unnecessary opportunity for the declaration and documentation paths
to diverge.

### Treat the direction qualifier as part of the parameter name

This would allow the old whitespace-based parser to remain largely unchanged,
but it would feed strings such as `[in]` into identifier normalization and would
conflate Doxygen metadata with Bash-oriented naming.  It was rejected because
the qualifier must survive unchanged while only the following name token is
normalized.

### Strip direction qualifiers from generated documentation

Removing `[in]`, `[out]`, or `[in,out]` would make name parsing easier, but would
discard structured documentation supplied intentionally by the author.  The
filter should preserve Doxygen metadata it can represent faithfully.

### Suppress parameter names in generated documentation

Removing `@param` directives would avoid name validation, but would discard
useful structured documentation and reduce the value of the generated reference.

## Consequences

Bash authors can continue to document positional parameters, option-like names,
variadic-style names, array-style names, assignment-style names, and
numeric-leading names using vocabulary natural to the source code.  They may
also attach standard Doxygen input/output direction metadata without changing
how those names are normalized.

The generated representation remains internally consistent: direction metadata
stays on the documentation command while the rewritten parameter token exactly
matches the identifier in the synthesized declaration.

The filter maintains a small amount of per-documentation-block mapping state:
source parameter names, their documentation-line positions, and their resolved
emitted names.  Direction qualifiers do not require separate state because they
remain in the original documentation line during name rewriting.

Regression coverage compares both sides of the invariant.  Filter-level fixtures
exercise all three supported direction qualifiers, sanitization categories, and
a collision after normalization.  The focused Doxygen integration fixture also
asserts that a preserved direction qualifier reaches Doxygen as parameter
direction metadata.  Maintained source and all generated distribution artifacts
run through the same semantic contracts under ADR-004.

## Open Questions and Follow-Ups

If Doxygen adds additional standardized direction spellings that this project
wants to support structurally, they should be added explicitly rather than
broadening recognition to arbitrary bracket contents.

If future Doxygen versions support a representation that preserves Bash-native
parameter spelling without a synthesized identifier, this decision may be
revisited.

## Related Decisions

- ADR-000 requires capability honesty and evidence-oriented reasoning.
- ADR-004 governs the filter-level and focused Doxygen semantic regression
  boundaries that exercise this invariant.
- GitHub issue #12 introduced canonical parameter-name alignment for positional
  and sanitized parameter names.
- GitHub issue #18 extends that same invariant to standard Doxygen parameter
  direction qualifiers.
