# ADR-009: Separate Bash symbols from documentation namespaces

Date: 2026-09-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines how `bash-doxygen` represents namespace-oriented function
identities while preserving the distinction between literal Bash symbol names and
documentation-only structure.

The filter remains documentation-led.  It SHALL preserve source evidence when a
Bash function is literally qualified with `::`, and it MAY introduce a separate
Doxygen namespace identity only when the source documentation makes that
abstraction explicit.  It SHALL NOT infer namespaces from naming conventions
such as `config_load`, `network_http_get`, or other prefixes.

This decision governs literal qualified Bash functions, qualified `@fn`
directives, the new `@namespace` structural directive, conflict handling, nested
namespace paths, and the pseudo-C++ representation emitted for Doxygen.

## Context

Bash does not provide a language-level namespace construct comparable to C++.
Projects nevertheless use naming conventions to organize shell functions, and
Bash permits function names that contain characters such as `:` when written in
supported function declaration forms.  `bash-doxygen` already recognizes
function names containing colons because its documented-function classifier
accepts names matching:

```text
[A-Za-z_][A-Za-z0-9_:]*
```

A function such as:

```bash
## @fn config::load()
config::load() {
  :
}
```

therefore contains direct source evidence that the Bash symbol itself is named
`config::load`.  Treating that form as documentation namespace structure does
not require guessing from a naming convention; the source symbol already carries
an explicit qualified identity.

A different use case is documentation abstraction.  A project may have an
implementation symbol such as:

```bash
config_load() {
  :
}
```

while wishing the generated documentation to present that function as
`config::load`.  The filter cannot infer this safely from the `config_` prefix.
The same implementation name could equally mean a flat function called
`config_load`, a private helper, or an unrelated convention.

Issue #19 therefore introduces explicit documentation namespace metadata:

```bash
## @namespace config
## @fn load()
config_load() {
  :
}
```

The source now distinguishes two identities:

- the physical Bash declaration is `config_load`; and
- the requested documentation identity is `config::load`.

This distinction must remain visible in the architecture.  A documentation
abstraction must not rewrite history by implying that Bash itself provides
namespace semantics or that the physical symbol has a different runtime name.

The existing function pipeline also creates an important representation
constraint.  ADR-002 makes the synthesized pseudo-C++ declaration the sole
emitted function signature, while source `@fn` metadata is consumed for
validation and suppressed from the generated documentation block.  Namespace
support must extend that principle without reintroducing a second structural
signature through `@namespace`.

ADR-004 adds a second requirement: the chosen pseudo-C++ representation must not
be accepted merely because a golden file looks plausible.  It must also survive
the focused Bash-to-filter-to-Doxygen XML integration path and produce the
intended namespace and function model in Doxygen.

## Decision Drivers

- Preserve literal Bash symbol names as authoritative source evidence.
- Permit documentation-only namespaces only through explicit documentation
  metadata.
- Never infer namespace membership from underscores, prefixes, or other naming
  conventions.
- Preserve ordinary unqualified function behavior.
- Permit nested namespace paths such as `network::http`.
- Make redundant evidence legal when it agrees.
- Diagnose contradictory explicit evidence rather than silently choosing one
  source according to precedence.
- Preserve the synthesized-declaration principle established by ADR-002.
- Emit a Doxygen representation that is proven through XML integration tests.
- Keep the implementation bounded and independent of a general Bash parser.

## Decision

### Two identities are modeled explicitly

For every documented function, the filter SHALL distinguish:

1. the **physical Bash symbol**, derived only from the following recognized Bash
   function declaration; and
2. the **documentation identity**, derived from explicit namespace evidence or,
   when no such evidence exists, from the physical symbol.

The physical Bash symbol remains the identity used for source association and
for explaining runtime reality.  The documentation identity controls the
pseudo-C++ namespace and member name emitted for Doxygen.

The filter SHALL NOT mutate or reinterpret the physical symbol in source.  It
only chooses an indexing representation for Doxygen.

### Valid namespace syntax

A documentation namespace path SHALL contain one or more identifier segments
separated by exactly `::`.

Each segment SHALL match:

```text
[A-Za-z_][A-Za-z0-9_]*
```

Examples of valid namespace paths include:

```text
config
network::http
project_2::transport
```

Examples outside the supported namespace model include empty segments, leading
or trailing `::`, single-colon separators, or segments beginning with a digit.
Unsupported explicit namespace metadata SHALL produce a diagnostic and SHALL
fail under `--strict` according to the existing diagnostic contract.

This syntax rule applies to the namespace interpretation introduced by this ADR.
It does not retroactively claim that every character sequence previously
accepted by the broad Bash function-name recognizer is valid C++ namespace
syntax.

### Literal qualified Bash declarations

A recognized Bash function declaration whose name is a valid qualified identity
containing `::` SHALL provide authoritative namespace evidence.

For example:

```bash
## @brief Loads configuration.
config::load() {
  :
}
```

has:

```text
physical Bash symbol:     config::load
documentation namespace: config
documentation member:    load
documentation identity:  config::load
```

No `@namespace` or `@fn` directive is required for the filter to preserve that
literal qualification.

Nested literal names are supported when every segment is valid:

```bash
network::http::get() {
  :
}
```

which maps to namespace path `network::http` and member `get`.

### Qualified @fn directives

A qualified source `@fn` directive provides explicit documentation identity.
For example:

```bash
## @fn config::load()
config_load() {
  :
}
```

requests documentation identity `config::load` while preserving physical Bash
symbol `config_load`.

This is a deliberate exception to the ordinary unqualified `@fn` mismatch rule.
A qualified `@fn` is not required to equal an unqualified physical declaration
because its qualification explicitly requests a documentation abstraction.

When the physical Bash symbol is itself qualified, the qualified `@fn` SHALL
agree with that literal identity.  A mismatch SHALL produce a diagnostic rather
than allowing documentation metadata to rename a literal qualified source
symbol.

### Explicit @namespace with @fn

`@namespace` is a source-side structural directive.  Its intended documentation
abstraction is formed together with `@fn`.

For example:

```bash
## @namespace config
## @fn load()
config_load() {
  :
}
```

requests documentation identity `config::load`.

The implementation symbol does not need to match `load` because the explicit
namespace metadata establishes that documentation identity independently of the
physical Bash name.

An explicit namespace may itself be nested:

```bash
## @namespace network::http
## @fn get()
network_http_get() {
  :
}
```

which requests `network::http::get`.

`@namespace` without an accompanying `@fn` SHALL NOT invent a member name from an
unqualified implementation symbol.  Such a block lacks enough explicit evidence
for a documentation-only remapping and SHALL produce a diagnostic.  A literal
qualified Bash declaration is the exception: when the declaration already
provides a complete qualified identity, a matching `@namespace` may be used as
redundant validation metadata even without `@fn`.

This rule avoids creating an implicit convention in which `@namespace config`
automatically converts `config_load` or `load` into `config::load`.

### Redundant evidence

Multiple explicit namespace sources MAY appear together when they agree.

This is valid:

```bash
## @namespace config
## @fn config::load()
config::load() {
  :
}
```

The literal declaration, qualified `@fn`, and explicit `@namespace` all identify
the same namespace path.

This is also valid:

```bash
## @namespace config
## @fn load()
config::load() {
  :
}
```

because `@namespace config` plus unqualified `@fn load()` resolves to the same
identity as the literal declaration.

Redundancy is treated as corroborating evidence rather than as an error.

### Conflicts are diagnostics, not silent precedence

Evidence may be considered in the following conceptual order when selecting a
candidate identity:

1. literal qualified Bash declaration;
2. explicit qualified `@fn`;
3. explicit `@namespace` plus unqualified `@fn`;
4. ordinary unqualified declaration.

This ordering SHALL NOT silently override contradictions.

Every explicit source that can be resolved to a namespace path or complete
qualified identity SHALL be checked for agreement with the selected identity.
Conflicts SHALL produce diagnostics and SHALL fail in strict mode.

For example:

```bash
## @namespace config
## @fn network::load()
config_load() {
  :
}
```

is conflicting because the explicit namespace says `config` while the qualified
`@fn` says `network`.

Likewise:

```bash
## @fn network::load()
config::load() {
  :
}
```

conflicts with the literal Bash symbol `config::load`.

The filter SHALL NOT "fix" either form by choosing whichever source has higher
precedence and ignoring the other.

### Ordinary unqualified @fn behavior remains

When no namespace abstraction is present, existing behavior remains in force.

For example:

```bash
## @fn load()
load() {
  :
}
```

is valid, while:

```bash
## @fn documented_name()
actual_name() {
  :
}
```

continues to produce the existing mismatch diagnostic.

An unqualified `@fn` therefore remains physical-symbol validation unless it is
combined with explicit `@namespace` metadata.

### Source structural directives are suppressed after resolution

For successfully recognized functions, source `@fn` and `@namespace` directives
are structural input to the filter and SHALL NOT be emitted into the generated
function documentation block.

This extends the principle established by ADR-002: the synthesized declaration
and namespace structure are the sole Doxygen-facing structural representation.
Descriptive commands such as `@brief`, `@details`, `@param`, `@returns`, and
`@retval` remain attached to the synthesized member declaration.

Unmatched documentation blocks continue to preserve their source text according
to the existing unmatched-documentation behavior; this ADR changes suppression
only for successfully resolved functions.

### Pseudo-C++ representation

A qualified documentation identity SHALL be emitted as nested C++ namespace
blocks containing an unqualified synthesized function declaration.

For example, documentation identity:

```text
network::http::get
```

shall be represented equivalently to:

```cpp
namespace network {
namespace http {
/**
 * descriptive documentation
 */
int get(...);
}
}
```

The exact whitespace and line arrangement are filter-output details protected by
regression fixtures.  The architectural requirement is that Doxygen sees real
namespace compounds and the documented function as a member of the innermost
namespace.

Qualified declarations such as `int network::http::get(...);` outside namespace
blocks were considered, but namespace blocks are preferred because they do not
require a prior namespace/member declaration to be valid C++ structure and are
more directly represented by Doxygen's namespace model.

The chosen representation SHALL be verified through the XML-only integration
suite before the feature is considered complete.

## Considered Alternatives

### Infer namespaces from implementation prefixes

The filter could map `config_load` to `config::load` or
`network_http_get` to `network::http::get` automatically.

This was rejected because underscore naming does not carry an unambiguous
namespace contract.  Inference would create documentation structure from a
convention the source never declared and would violate ADR-000's requirement for
capability honesty and evidence-oriented behavior.

### Treat @namespace as sufficient by itself for arbitrary implementation names

The filter could combine `@namespace config` with the following physical symbol
and derive `config::config_load` or attempt to strip a prefix.

This was rejected because neither behavior is clearly implied by the source.
For documentation-only remapping, `@fn` supplies the member identity explicitly.

### Always require @namespace

Literal `config::load` functions or qualified `@fn config::load()` directives
could be rejected unless a separate `@namespace config` is present.

This was rejected because those forms already contain explicit complete
qualification.  Requiring duplicate metadata would add ceremony without adding
evidence.

### Let precedence silently resolve conflicts

The filter could always trust literal declarations over `@fn`, and qualified
`@fn` over `@namespace` plus unqualified `@fn`.

This was rejected because contradictory documentation would remain in source and
could mislead maintainers even if the generated output happened to be
consistent.  Conflicts are documentation defects and must remain visible.

### Emit Doxygen @namespace commands in function comments

The source `@namespace` line could be preserved and left for Doxygen to
interpret.

This was rejected because it would create a second structural representation
beside the synthesized namespace blocks and could cause the function comment to
be interpreted as namespace documentation.  Structural source metadata is
consumed and translated instead.

### Emit a flat function whose name contains ::

The filter could continue emitting:

```cpp
int config::load(...);
```

without namespace blocks.

This was rejected as the primary representation because qualified member
function declarations outside their namespace generally rely on prior
declarations and provide a weaker, less explicit Doxygen namespace model.  The
focused Doxygen integration test should validate actual namespace compounds.

### Introduce a general Bash namespace parser

The filter could attempt to discover namespace relationships from wrappers,
associative tables, sourcing layout, prefixes, or other project conventions.

This was rejected as outside scope.  Bash does not provide one language-level
namespace construct for the filter to parse, and such inference would conflict
with the bounded parser architecture established by ADR-000 and ADR-008.

## Consequences

Literal qualified Bash function names can be documented without losing their
source identity.

Projects may create a documentation namespace abstraction for differently named
implementation functions, but they must state that abstraction explicitly with
a qualified `@fn` or with `@namespace` plus `@fn`.

Nested namespaces become a supported documentation structure rather than a flat
string convention.

The function parser must retain additional per-block metadata: explicit
namespace path, source `@fn` identity, physical declaration identity, and the
resolved documentation identity.

The emitter must split qualified identities into namespace path and member name,
emit nested namespace blocks, and suppress source `@namespace` structural lines
for successfully recognized functions.

Namespace output necessarily introduces generated lines around a function
relative to a flat declaration.  Exact source-line preservation is therefore
secondary to representing the documentation model correctly for this feature.
The filter should avoid unnecessary expansion beyond the namespace structure
required by Doxygen.

The focused Doxygen integration fixture gains namespace assertions so that
future refactors cannot preserve a plausible golden pseudo-C++ file while
silently breaking Doxygen's namespace/member model.

No namespace behavior is inferred for variables by this ADR.  The decision is
limited to documented Bash functions requested by issue #19.  Variable
namespacing, groups/modules, and class abstractions require separate decisions if
introduced later.

## Compatibility and Migration

Existing ordinary unqualified documented functions retain their current output
and mismatch behavior.

Existing literal names containing valid `::` qualification gain a stronger
Doxygen representation: the generated function is placed inside corresponding
namespace blocks rather than emitted as a flat qualified declaration.

A qualified `@fn` paired with an unqualified implementation symbol now becomes an
explicit documentation abstraction instead of an ordinary name mismatch.  This
is an intentional feature expansion.

Source that contains contradictory explicit namespace evidence will now produce
a diagnostic.  Under strict mode this becomes a non-zero exit status, consistent
with existing documentation-drift behavior.

Projects that currently rely on inferred underscore prefixes receive no new
namespace behavior.  They must opt in explicitly.

## Expected Outcomes

- literal `config::load` functions appear as `load` within Doxygen namespace
  `config`;
- `@fn config::load()` can document a differently named Bash implementation
  without pretending the runtime symbol changed;
- `@namespace config` plus `@fn load()` produces the same documentation identity;
- nested namespace paths remain deterministic and inspectable;
- redundant explicit evidence is accepted when consistent;
- contradictory evidence is diagnosed;
- ordinary unqualified function documentation remains unchanged; and
- no naming-prefix heuristic becomes part of the parser contract.

## Related Decisions

- ADR-000 requires evidence-oriented behavior and explicit capability boundaries.
- ADR-002 establishes the synthesized declaration as the sole emitted function
  signature and motivates suppression of structural source directives.
- ADR-004 requires behavior-focused golden fixtures and focused Doxygen semantic
  integration.
- ADR-008 constrains parser growth and rejects unbounded source inference.
- GitHub issue #19 requests the namespace behavior governed by this decision.
