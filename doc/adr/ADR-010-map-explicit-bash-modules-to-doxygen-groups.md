# ADR-010: Map explicit Bash modules to Doxygen groups

Date: 2026-09-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines the first half of the higher-level documentation organization
requested by GitHub issue #20.  It introduces an explicit Bash-facing module
abstraction and maps that abstraction to Doxygen groups/topics without claiming
that Bash provides a language-level module or package construct.

The decision is deliberately separate from the class abstraction also described
by issue #20.  Classes cross a different semantic boundary and require their own
representation and validation work.  This ADR therefore governs only module/group
definitions, module membership, the `@package` alias, conflict handling, and the
interaction between modules and already-supported namespaces.

## Context

`bash-doxygen` is documentation-led.  Existing structural metadata such as
`@fn`, `@var`, and `@namespace` exists to make documentation intent explicit
rather than to infer structure from implementation naming conventions.

ADR-009 established the distinction between a physical Bash function symbol and
a documentation namespace identity.  That decision also explicitly reserved
groups/modules and classes for separate decisions.  Issue #20 now asks for a
language-neutral module/package abstraction that can collect related Bash
functions and variables without pretending that Bash has Java packages, Python
modules, C++ namespaces, or another language-specific construct.

Doxygen groups are a good fit for that requirement.  A group is an organizational
relationship rather than a language namespace.  A function may therefore be a
member of a Doxygen group while retaining its ordinary or namespace-qualified
function identity.  Likewise, a variable can belong to the same group without
being placed into a synthetic C++ namespace or class.

The issue proposes source documentation such as:

```bash
## @module networking
## @brief Network-related functionality.
```

for the logical module itself, and:

```bash
## @module networking
## @fn download()
## @brief Downloads a resource.
download() {
  :
}
```

for membership.

The same source spelling is intentionally useful in both contexts.  The
surrounding documentation block determines whether `@module networking` defines
the logical group or assigns an explicitly documented Bash symbol to it.

The issue also raises `@package` as a possible alias.  Passing that directive
through unchanged would be undesirable because Doxygen gives `@package`
language-specific meaning in some parsing modes.  If `bash-doxygen` accepts it,
the filter must consume it as Bash-facing metadata and translate it into the same
language-neutral group model as `@module`.

## Decision Drivers

- Represent logical Bash API organization without inventing Bash language
  semantics.
- Keep module membership explicit and documentation-led.
- Use Doxygen groups/topics rather than namespaces or package constructs.
- Permit functions and variables to share one logical module.
- Permit namespaced functions governed by ADR-009 to belong to modules without
  changing their namespace identity.
- Avoid inference from filename, source relationships, prefixes, or symbol names.
- Preserve one small, inspectable parser rather than introducing persistent
  module scope or a general Bash parser.
- Make malformed or contradictory structural metadata visible through existing
  diagnostics and strict-mode behavior.
- Prove the group/member relationship through the focused Doxygen XML path
  required by ADR-004.
- Keep the later class abstraction out of this implementation slice.

## Decision

### `@module` is canonical and `@package` is an exact alias

The canonical Bash-facing spelling SHALL be:

```text
@module NAME
```

The filter SHALL also accept:

```text
@package NAME
```

as an exact structural alias for the same abstraction.

The source documentation standard and examples SHOULD prefer `@module`.  The
`@package` spelling exists for authors who naturally describe a logical Bash API
collection as a package, but it SHALL NOT imply Java package semantics or any
other language-specific package behavior.

Both directives are source-side structural metadata.  When successfully
interpreted, they SHALL be consumed by the filter and translated into Doxygen
group commands.  They SHALL NOT be forwarded to Doxygen as source `@module` or
`@package` commands.

A documentation block MAY contain redundant `@module` and/or `@package`
directives only when every occurrence names the same module.  Contradictory
module names in one block SHALL produce a diagnostic and SHALL fail in strict
mode.

### Module identifiers are intentionally flat initially

The initial module identifier grammar SHALL be:

```text
[A-Za-z_][A-Za-z0-9_]*
```

Examples include:

```text
networking
http_client
project2
```

Nested module paths, parent/child group relationships, slash-separated package
paths, `::` module paths, and other hierarchical spellings are outside the
initial contract.

This limitation is intentional.  Doxygen supports subgroup relationships, but
issue #20 explicitly identifies nested groups/modules as a possible later
extension.  The project should first establish a stable single-level source and
Doxygen representation before adding hierarchy.

Malformed explicit module identifiers SHALL produce a diagnostic.  The filter
SHALL NOT sanitize malformed module identifiers silently because doing so could
place documentation into a group the author did not explicitly name.

### A module-only block defines the Doxygen group

A documentation block that contains `@module NAME` or `@package NAME` and does
not contain `@fn` or `@var` SHALL define the logical module itself.

For example:

```bash
## @module networking
## @brief Network-related functionality.
```

shall emit a Doxygen-facing representation equivalent to:

```cpp
/**
 * @defgroup networking networking
 * @brief Network-related functionality.
 */
```

The module identifier is used as the initial Doxygen group identifier and title.
The descriptive `@brief`, `@details`, and other ordinary Doxygen documentation in
the block remain attached to the group definition.

A module-only block is complete documentation and does not require a following
Bash declaration.  Once the block terminates at a blank line, a non-documentation
line, or end of file, the filter SHALL emit the group definition rather than
warning that the documentation block lacks a recognized Bash declaration.

This rule intentionally means module membership requires an explicit symbol
identity as described below.  The filter does not treat `@module NAME` plus an
otherwise undocumented following declaration as implicit membership.

### Function membership requires explicit `@fn`

A function belongs to a module when its documentation block contains both module
metadata and an `@fn` directive.

For example:

```bash
## @module networking
## @fn download()
## @brief Downloads a resource.
download() {
  :
}
```

shall retain the existing synthesized function declaration behavior and add
Doxygen group membership equivalent to:

```cpp
/**
 * @ingroup networking
 * @brief Downloads a resource.
 */
int download();
```

`@module`/`@package` and source `@fn` are structural inputs and SHALL be
suppressed from the generated function documentation block.  The synthesized
function declaration remains the sole Doxygen-facing function signature under
ADR-002.

The physical Bash function name, qualified `@fn`, and `@namespace` behavior
continue to follow ADR-009.  Module membership SHALL NOT alter function identity.

### Variable membership requires explicit `@var`

A variable belongs to a module when its documentation block contains both module
metadata and an explicit `@var` directive.

For example:

```bash
## @module networking
## @var NETWORK_TIMEOUT
## @brief Default network timeout in seconds.
readonly NETWORK_TIMEOUT=30
```

shall retain the existing synthesized variable representation and add Doxygen
group membership equivalent to:

```cpp
/**
 * @ingroup networking
 * @brief Default network timeout in seconds.
 * @details Bash variable: readonly string
 */
ReadonlyString NETWORK_TIMEOUT;
```

The source `@module` or `@package` line SHALL be consumed.  For a successfully
resolved grouped variable, the source `@var` directive also remains a required
validation input but SHALL be consumed rather than forwarded to Doxygen.  The
synthesized variable declaration becomes the single Doxygen-facing variable
entity carrying the descriptive documentation and `@ingroup` membership.

This grouped-variable rule is intentionally narrower than changing variable
emission globally.  Ungrouped variables retain the existing `@var` behavior, and
invalid module metadata does not suppress the ordinary `@var` path.  Focused
integration testing showed that supported Doxygen versions do not handle
`@ingroup` plus an explicit emitted `@var` consistently in one block; consuming
`@var` only after successful group resolution avoids duplicate or ambiguous
variable entities while preserving source-side validation.

Requiring source `@var` still avoids changing the meaning of an otherwise
module-only block based solely on whichever assignment happens to follow it.

### Modules and namespaces are orthogonal

A function may simultaneously have a documentation namespace identity under
ADR-009 and module membership under this ADR.

For example:

```bash
## @module networking
## @namespace transport::http
## @fn get()
network_http_get() {
  :
}
```

shall be represented as a member function in namespace `transport::http` and as
a member of Doxygen group `networking`.

The module SHALL NOT become an outer C++ namespace, and the namespace SHALL NOT
be inferred as the module.  Doxygen's `@ingroup` metadata is attached to the
synthesized function documentation while the existing namespace emitter remains
responsible for namespace structure.

### No persistent or inferred module scope

Module metadata applies only to the documentation block in which it appears.
The filter SHALL NOT establish persistent module scope that automatically applies
to later declarations.

In particular, the filter SHALL NOT infer module membership from:

- Bash function or variable prefixes;
- namespace names;
- filenames or directory paths;
- source/sourcing relationships;
- proximity to a module definition block; or
- a preceding member that belonged to the same module.

Every module member must opt in explicitly through its own documentation block.
This preserves the bounded, stateless association model used by the existing
filter and avoids hidden structure.

### Conflict and misuse diagnostics

The filter SHALL diagnose:

- malformed module identifiers;
- multiple `@module`/`@package` directives in one block that name different
  modules;
- module membership metadata attached to a function block without `@fn` when the
  block would otherwise be interpreted as symbol documentation;
- module membership metadata attached to a variable block without `@var` when the
  block would otherwise be interpreted as symbol documentation; and
- any future contradictory structural evidence that would make group membership
  ambiguous.

The initial implementation avoids the last two ambiguity cases structurally by
treating a block without `@fn` or `@var` as a module definition.  Documentation
that intends membership must therefore supply the explicit member directive.

Diagnostics SHALL use the existing warning path and SHALL fail under `--strict`.
The filter SHALL NOT guess whether an ambiguous block intended a group definition
or member assignment.

### Doxygen representation and semantic validation

Module definitions SHALL use Doxygen `@defgroup` semantics.  Member declarations
SHALL use Doxygen `@ingroup` semantics.

The filter-level golden fixtures SHALL protect the exact pseudo-C++ translation.
The focused Doxygen integration fixture governed by ADR-004 SHALL additionally
prove that Doxygen creates a group compound and associates representative module
members with that group.

The semantic integration should include at least one function member and one
variable member.  A namespaced module member SHOULD also be represented so the
orthogonality between ADR-009 namespaces and group membership remains protected.

Assertions SHALL target stable semantic XML rather than complete XML snapshots.
Compatibility with the Doxygen versions already exercised by repository CI SHALL
be preserved.

## Considered Alternatives

### Support only `@module`

This would create the smallest source vocabulary.  It was rejected because
`@package` is a natural term for a logical collection in some Bash projects and
can be supported safely when it is consumed and translated to exactly the same
Doxygen group abstraction.  Keeping `@module` canonical prevents the two
spellings from becoming separate semantics.

### Pass `@package` through to Doxygen

This was rejected because it could expose language-specific Doxygen package
semantics and would violate the requirement that Bash-facing modules/packages
map to language-neutral groups.

### Use namespaces for modules

This would reuse ADR-009's emitter, but a module is an organizational topic, not
necessarily a function-identity scope.  Variables, functions, namespaced
functions, and future classes may all belong to the same module.  Groups model
that relationship more accurately.

### Infer module membership from prefixes or files

A function named `network_download` or a file named `networking.bash` might
suggest module membership, but those conventions are not unambiguous language
semantics.  This was rejected for the same evidence-oriented reasons that ADR-009
rejects inferred namespaces.

### Let a module definition establish persistent scope

The filter could treat all following documented declarations as group members
until another module marker appears.  This was rejected because it would create
hidden state across otherwise independent documentation blocks and make source
movement or insertion change membership implicitly.

### Support nested modules immediately

Doxygen can represent subgroup relationships, but adding parent/child syntax now
would enlarge the source grammar and conflict surface before the flat group model
has been validated across supported Doxygen versions.  Nested groups are deferred.

### Forward `@var` for grouped variables

This would preserve the ordinary generated variable documentation form exactly.
It was rejected after semantic integration testing because Doxygen 1.9.1 and
1.9.8 do not compose an explicit emitted `@var` and `@ingroup` consistently in
the same block.  Keeping source `@var` as validation metadata while letting the
synthesized declaration be the Doxygen-facing variable preserves the intended
identity, descriptive documentation, and group membership across the supported
CI versions.

### Implement classes in the same change

Issue #20 contains both groups/modules and documentation-only classes, but the two
features solve different problems.  Groups organize existing symbols; classes
construct a stronger documentation abstraction with method relationships that
Bash does not provide natively.  Combining them would make representation,
conflict handling, and review harder to isolate.  Class support is therefore a
separate follow-on decision and pull request.

## Consequences

Bash projects can define logical documentation modules and explicitly assign
functions and variables to them without changing runtime names or inventing a
language package construct.

Authors may use `@package` when desired, but generated documentation will expose
the same Doxygen group model as `@module` and will not preserve package-specific
semantics.

Every member repeats its module metadata.  This adds source verbosity, but the
redundancy is intentional: membership remains local, visible, movable, and easy
to reason about without parser state.

Namespaced functions may be grouped without changing their namespace identity.
This composes ADR-009 with the new module abstraction rather than superseding it.

Successfully grouped variables consume source `@var` after using it for name
validation so that one synthesized Doxygen variable owns both documentation and
group membership.  Ordinary ungrouped variable emission remains unchanged.

The filter gains small per-block module state and an additional structural
translation path, but it does not gain a general module parser, persistent scope,
or source-layout inference.

The regression suite gains module definition, function membership, variable
membership, alias, namespace interaction, malformed identifier, and conflict
fixtures.  The focused Doxygen fixture gains explicit group/member assertions as
required by ADR-004.

## Compatibility and Migration

Existing source that does not use `@module` or `@package` retains its current
behavior.

A source `@package` directive that previously passed through as ordinary Doxygen
text will now be consumed as Bash module metadata when it matches the supported
structural form.  This is an intentional feature expansion that prevents the
filter from implying language-specific package semantics.

No existing function, variable, or namespace naming convention gains automatic
module behavior.

The feature is additive and does not change the generated identity of existing
symbols.  It adds organizational group relationships only when source
documentation explicitly requests them.  For grouped variables, source `@var`
continues to validate identity but is no longer emitted to Doxygen after module
resolution succeeds.

## Expected Outcomes

- `@module networking` can define a Doxygen group named `networking`;
- `@package networking` behaves as an exact alias without Java package semantics;
- explicitly documented functions and variables can belong to the group;
- a namespaced function can retain its namespace identity while belonging to a
  module;
- malformed or conflicting module metadata is diagnosed;
- nested module relationships are not implied or guessed;
- implementation prefixes and file layout create no module membership; and
- class support remains outside this implementation slice.

## Related Decisions

- ADR-000 requires evidence-oriented behavior and explicit capability boundaries.
- ADR-002 establishes synthesized declarations as the Doxygen-facing function
  signatures.
- ADR-004 requires focused Doxygen semantic assertions for implemented
  group/module relationships.
- ADR-008 keeps declaration association bounded and explicit.
- ADR-009 governs function documentation namespaces independently of groups.
- GitHub issue #20 requests the module/group and later class abstractions split by
  this decision.
