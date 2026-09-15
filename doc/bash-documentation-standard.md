# Bash Documentation Standard

This document defines the normative source-documentation standard for maintained
Bash files in this project.  The standard deliberately prefers verbose,
explanatory documentation.  Source brevity is not a goal when brevity would
force a future maintainer to infer intent, contracts, assumptions, failure
semantics, security boundaries, or architectural relationships from executable
code alone.

This is the same documentation model used across related projects such as
bashdeps, Bootstrap, mktext, adrctl, and template-bash.  It is intentionally
compatible with the `bash-doxygen` tooling.  The syntax and structure described
here are requirements, not examples of a general style that may be replaced with
something merely similar.

The distribution pipeline separates maintenance representation from consumer
representation.  The `.dev.bash` artifact retains documentation.  Full-line
comments are removed from the ordinary `.bash` artifact, and Bash-Minifier
produces the `.min.bash` artifact.  Maintainers therefore should not reduce
source documentation merely to optimize release size.  Prefer thorough,
detailed, in-depth commentary over brevity.  The goal is for the work to be
accessible, readable, and maintainable while targeting developers with basic
Bash competence.  Pay special attention to the assumptions and preconditions
associated with the work that's being done.  Consider that the reader may be
a human new to the project or an AI/LLM that may have a focused context and may
not retain a full view of the project or the consequences of decisions made and
documented here.

## Comment Syntax

Doxygen documentation lines begin with exactly two hash characters:

```bash
## @file lib/example.bash
## @brief Provides an example capability.
## @details
## This module exists to preserve a specific contract.  The details explain why
## the capability belongs here, how callers should use it, and what assumptions
## future changes must preserve.
```

Use ordinary single-hash comments for narrow implementation annotations that are
not intended to become part of generated reference documentation.  Prefer
Doxygen comments whenever the material helps explain an interface, invariant,
module responsibility, non-obvious decision, maintenance constraint, portability
assumption, or security boundary.

The project does not use another Doxygen comment dialect in maintained Bash
source.  Do not replace these blocks with `#**`, `##<`, or another convention
without an architectural decision that explicitly changes the `bash-doxygen`
integration.

Lines in the commentary should be limited to 80 characters or less, except for
unbreakable content such as long URLs.

## Relationship to bash-doxygen

`bash-doxygen` converts documented Bash declarations into a Doxygen-friendly
intermediate representation.  It intentionally emits declarations only when they
are decorated with a Doxygen block.

Documentation blocks for symbols must remain contiguous and associated with the
function or variable declaration they document.  Standalone module-definition
blocks are complete documentation blocks and do not require a following Bash
declaration.

The filter structurally understands `@file`, `@fn`, `@namespace`, `@module`,
`@package`, `@var`, and `@param` names and preserves ordinary Doxygen commands
such as `@brief`, `@details`, `@returns`, `@retval`, `@note`, `@warning`, `@see`,
`@par`, `@code`, and `@endcode`.

For ordinary unqualified functions, `@fn` continues to validate the physical
Bash declaration that follows.  `@var` likewise must agree with the following
variable declaration.  Namespace-oriented function documentation is a distinct
case: a literal Bash function name containing `::`, a qualified `@fn`, or an
explicit `@namespace` combined with `@fn` may establish a qualified documentation
identity according to ADR-009.  The tooling must not infer namespace membership
from implementation prefixes such as `config_` or `network_http_`.

`@module` defines the canonical logical-module vocabulary.  `@package` is an
exact alias that maps to the same Doxygen group abstraction rather than a
language-specific package model.  A module-only block defines a group; function
and variable membership requires explicit `@fn` or `@var` metadata in the same
block.  Module membership is local and must never be inferred from prefixes,
filenames, source relationships, namespaces, or neighboring declarations.

Maintainers should prefer explicit structural commands because they allow tooling
to catch documentation drift.  When multiple namespace- or module-related
sources are present, they must agree rather than relying on precedence to hide a
conflict.

## File Blocks

Every maintained Bash source file must begin with:

```bash
#!/usr/bin/env bash
# shellcheck shell=bash
## @file <path relative to project root>
## @brief <one-sentence purpose>
## @details
## <substantive prose>
```

For example:

```bash
#!/usr/bin/env bash
# shellcheck shell=bash
## @file lib/redaction.bash
## @brief Provides the core redaction pipeline.
## @details
## Explain the module's responsibility, state ownership, security boundary,
## interactions with formatting/emission, and assumptions future changes must
## preserve.
```

The details must explain the module's responsibility, its relationship to
neighboring modules, important state it owns, and assumptions that affect safe
modification.  A useful file block answers "why does this module exist?" as well
as "what functions are in it?"

Security-sensitive modules must explicitly identify the boundary they enforce
and link to governing ADRs when that context materially improves review.

## Function Blocks

All functions must use the following vocabulary as applicable:

```bash
## @fn example_lookup()
## @brief Looks up a named example.
## @details
## Explain the contract, assumptions, side effects, and why the function exists.
## Describe non-obvious behavior and interactions with other modules.
##
## @param name Logical name to look up.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The matching value when one exists.
## @par STDERR
## A diagnostic when the request is invalid or the lookup cannot be completed.
##
## @returns A single line of text containing the matching string.
##
## @retval 0 A matching value was found.
## @retval 64 The caller supplied invalid input.
## @retval 69 No matching value exists.
##
## @par Examples
## @code
## value="$(example_lookup demo)"
## @endcode
example_lookup() {
  # implementation
}
```

Document parameters in call order.  Document standard input, standard output
and standard error.  Document exit statuses semantically rather than merely
saying "success" or "failure" when distinct outcomes matter.

When a function may propagate exit statuses from another command without
translating them into a defined function-level status, do not attempt to
enumerate those values with `@retval`.

Document the function's defined exit statuses with `@retval`, and use `@note` to
identify any additional statuses that may be propagated unchanged from another
command.

```bash
## @retval 0 The operation completed successfully.
## @note Non-zero exit statuses from grep may be propagated unchanged.
```

If the propagated command is conditional or only applies to a particular failure
path, describe that condition explicitly.

```bash
## @retval 0 The requested file was processed successfully.
## @retval 64 The caller supplied invalid input.
## @note If validation succeeds but awk fails, its non-zero exit status may be
## propagated unchanged.
```

Do not invent or normalize propagated exit statuses solely for documentation.
Use `@retval` only for exit statuses that form part of the function's defined
contract.

Examples are strongly preferred for public, plugin, parsing, transformation,
redaction, formatting, emission, or otherwise non-trivial interfaces.  Examples
should demonstrate intended use, not manufacture a second test suite inside
comments.

For security-sensitive functions, `@details` must explain the important
preconditions, failure behavior, ordering assumptions, and what the function
must never emit or expose.

Material side effects must be documented in `@details` or, when useful, in a
dedicated `@par Side Effects` section.  This includes changes to caller-visible
variables, shell options, traps, files, directories, or other state outside the
function's local scope.

### Function Namespaces

Function namespaces are an optional documentation abstraction.  They do not
change the runtime Bash symbol and must not be described as a Bash language
namespace facility.

A function whose physical Bash name already contains a valid qualified identity
may document that literal name directly:

```bash
## @fn config::load()
## @brief Loads configuration.
config::load() {
  :
}
```

A differently named implementation may request the same documentation identity
with a qualified `@fn`:

```bash
## @fn config::load()
## @brief Loads configuration.
config_load() {
  :
}
```

Alternatively, use an explicit `@namespace` together with an unqualified `@fn`:

```bash
## @namespace config
## @fn load()
## @brief Loads configuration.
config_load() {
  :
}
```

Nested documentation namespaces use `::` separators:

```bash
## @namespace network::http
## @fn get()
network_http_get() {
  :
}
```

Each namespace segment must be a valid documentation identifier beginning with a
letter or underscore and continuing with letters, digits, or underscores.
`@namespace` alone must not be used to infer a member name from an unqualified
implementation symbol.  Documentation-only remapping requires an explicit
member identity through `@fn`.

The physical Bash declaration, qualified `@fn`, and `@namespace` metadata may be
redundant when they agree.  Contradictory evidence is a documentation defect and
must be corrected rather than relying on the filter to choose one source
silently.

Do not infer namespace membership from underscore prefixes, filename placement,
sourcing relationships, or similar conventions.  For example, the physical
symbol `config_load` remains an ordinary flat function unless the source also
contains explicit namespace documentation.

`@namespace` and `@fn` are source-side structural directives.  For a successfully
resolved function, `bash-doxygen` consumes them while generating the Doxygen
namespace structure and synthesized member declaration.  Their absence from the
generated comment block does not remove their source-level documentation role.

### Documentation Modules and Groups

Documentation modules are an optional organizational abstraction that maps to
Doxygen groups.  They do not create Bash language modules, change runtime symbol
names, or establish source scope.

Use `@module` as the canonical spelling when defining a logical module:

```bash
## @module networking
## @brief Network-related functionality.
```

`@package` is accepted as an exact alias when that vocabulary is preferable:

```bash
## @package networking
## @brief Network-related functionality.
```

The two spellings have identical behavior.  `@package` must not be interpreted as
Java package semantics or another language-specific package construct.

Initial module identifiers are flat and must begin with a letter or underscore,
followed by letters, digits, or underscores.  Nested module paths and parent/child
group relationships are not part of the current standard.

To assign a function to a module, repeat the module marker in the function's own
block and include the required explicit `@fn`:

```bash
## @module networking
## @fn download()
## @brief Downloads a resource.
download() {
  :
}
```

To assign a variable, include the module marker with an explicit `@var`:

```bash
## @module networking
## @var NETWORK_TIMEOUT
## @brief Default network timeout in seconds.
readonly NETWORK_TIMEOUT=30
```

The source `@var` remains required and is used to validate the following variable
name.  Once valid module membership is resolved, `bash-doxygen` consumes that
structural directive and attaches the descriptive documentation plus `@ingroup`
to the synthesized variable declaration.  Ungrouped variables retain the normal
emitted `@var` behavior.

The module definition does not establish persistent membership for later
symbols.  Every member repeats its module metadata so membership remains local,
visible, and stable when source is moved.

Function namespaces and module membership are independent.  A namespaced function
may also belong to a module:

```bash
## @module networking
## @namespace transport::http
## @fn get()
network_http_get() {
  :
}
```

The generated documentation keeps `transport::http::get` as the function's
namespace identity while also assigning it to the Doxygen group `networking`.

Do not infer module membership from naming prefixes, namespace names, filenames,
directories, sourcing relationships, adjacency to a module definition, or a
previous module member.  A module marker followed directly by a function or
variable without explicit `@fn` or `@var` is incomplete membership metadata and
must be corrected.

`@module` and `@package` are source-side structural directives.  `bash-doxygen`
consumes them and emits Doxygen `@defgroup` or `@ingroup` metadata as appropriate.

### Paragraphs for STDIN, STDOUT, and STDERR

Individual `@par` (paragraphs) must be included that describe the contracts
of what a function expects from STDIN and writes to STDOUT and STDERR.

```bash
## @par STDIN
## The content to be searched.
## @par STDOUT
## The lines that match the provided pattern.
## @par STDERR
## Nothing is written to STDERR.
```

Exactly one `@par STDIN`, one `@par STDOUT`, and one `@par STDERR` are required
per function.

### Using @returns and @retval

Use `@retval` to document function exit statuses.  Use `@returns` to document
the structural form of the function's STDOUT.

These directives describe two separate aspects of a Bash function's behavior:

* `@retval` documents one possible numeric exit status and what that status means.
* `@returns` documents the structural form of what, if anything, the function
  writes to STDOUT.

Use one `@retval` line for each documented exit status.

```bash
## @retval 0 A matching value was found.
## @retval 1 No matching value was found.
## @retval 2 The supplied pattern was invalid.
```

Use `@returns` to describe the function's STDOUT contract.

```bash
## @returns A list of matching strings, one per line.
```

When a function intentionally writes nothing to STDOUT, state that explicitly.

```bash
## @returns Nothing is written to STDOUT.
```

All functions must have exactly one `@returns` statement and may have zero or
more `@retval` statements.

A function may both write data to STDOUT and produce a meaningful exit status.
Document both behaviors independently.

```bash
## @fn find_matches()
## @brief Finds values matching a supplied pattern.
## @details
## Searches the provided input values using the supplied pattern and writes each
## matching value to STDOUT.  The function distinguishes between successful
## matches, no matches, and invalid patterns through its exit status.
##
## @param pattern The pattern to match.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Each line contains a value that matched the supplied pattern.  No output is
## produced when no values match.
## @par STDERR
## A diagnostic is written when the supplied pattern is invalid.
##
## @returns Zero or more newline-delimited strings.
##
## @retval 0 One or more matching values were found.
## @retval 1 No matching values were found.
## @retval 2 The supplied pattern was invalid.
##
## @par Examples
## @code
## find_matches '^[[:alpha:]]+$'
## matches="$(find_matches '^[[:alpha:]]+$')"
## @endcode
find_matches() {
```

Predicate-style functions commonly write nothing to STDOUT and communicate
their result entirely through the exit status.

```bash
## @fn is_valid()
## @brief Determines whether a value is valid.
## @details
## Evaluates the supplied value against the function's validation rules.  The
## validation result is communicated exclusively through the exit status; the
## function does not emit a value to STDOUT.
##
## @param value The value to inspect.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns Nothing is written to STDOUT.
##
## @retval 0 The value is valid.
## @retval 1 The value is invalid.
##
## @par Examples
## @code
## if is_valid "${value}"; then
##   printf '%s\n' 'The value is valid.'
## fi
## @endcode
is_valid() {
```

Do not use `@returns` to describe an exit status, and do not use `@retval` to
describe text or other data written to STDOUT.  Treat STDOUT and the function's
exit status as independent interfaces.

#### Relationship Between @returns and @par STDOUT

`@par STDOUT` describes the semantic meaning of that output and the conditions
under which it is produced.

`@returns` describes the structural form of the function's STDOUT, such as
whether it emits a single string, zero or more newline-delimited values, or
nothing.

```bash
## @par STDOUT
## Each line is a value that matched the supplied regular expression.
## No output is produced when no values match.
##
## @returns Zero or more newline-delimited strings.
```

## Variables and Constants

Document exported variables, configuration knobs, registry structures,
security-sensitive arrays, and constants whose meaning is not self-evident.
Explain units, allowed values, mutability, ownership, lifecycle, and whether the
value participates in public API compatibility when those details matter.

Use `@var` for significant documented variables where appropriate:

```bash
## @var BASHLOG_DEFAULT_LEVEL
## @brief Default logging threshold used when no caller override exists.
readonly BASHLOG_DEFAULT_LEVEL='info'
```

Using `@var` allows `bash-doxygen` to verify that the documentation name matches
the following declaration.  A variable that belongs to a documentation module
must use explicit `@var` metadata in the same block as `@module` or `@package`.
For successfully grouped variables, `@var` remains source-level validation
metadata even though the filter consumes it before emitting the synthesized
Doxygen variable declaration.

Do not document every local loop variable.  Documentation volume should preserve
reasoning, not create noise that obscures it.

## Internal Helpers

A function beginning with `__bashlog_` is internal by project convention.  That
prefix is not a privacy mechanism and is not a reason to omit documentation from
a security-critical helper.

## Security-Sensitive Documentation

For redaction, final rendering, and emission code, comments should make it
possible for a reviewer to answer questions such as:

* what sensitive state the function receives or accesses;
* whether the value is plaintext in the current Bash process;
* whether data can reach a sink from this function;
* whether failure suppresses or emits the original message;
* what matcher semantics apply;
* whether replacement text is interpreted;
* whether locale or multibyte behavior matters;
* what assumptions depend on the Bash compatibility floor;
* and which ADR establishes the relevant security promise.

Do not use comments to imply stronger runtime protection than Bash provides.
Terms such as "private," "secure memory," or "isolated" must not be used for
ordinary same-process variables unless a real mechanism supports the claim.

## Document Intent, Not Syntax

Avoid comments such as "increment the counter" immediately above
`((counter++))`.  Prefer comments that explain why the counter exists, why an
operation occurs at that point, or why a seemingly unusual implementation is
necessary.

If code and documentation disagree, treat the disagreement as a defect to
investigate.  Do not automatically rewrite the comment to match current code;
the code may be the part that drifted from the intended contract.

## Relationship to ADRs

Doxygen documentation owns implementation-level intent.  ADRs own durable
architectural reasoning, promises, non-promises, adversary/failure models,
rejected alternatives, and accepted tradeoffs.  Source comments may link to an
ADR when a local implementation exists specifically to satisfy an architectural
constraint.

Do not copy an entire ADR into source comments.  Do not invent historical
rationale when no source supports it.  State uncertainty or add an ADR when a
new consequential decision is required.

`doc/decisions.md` provides only concise ADR summaries and does not replace
either the full ADR or local Doxygen contract.

Once created, `doc/bashlog-spec.md` will own current public behavior.  Doxygen
comments should agree with that specification for public functions while adding
implementation-level context that would be inappropriate in a consumer-facing
specification.

## Generated Reference Documentation

`make docs` generates reference documentation from maintained source using the
prepared `bash-doxygen` dependency.  Generated output is derivative and is not a
maintained source of truth.

The `.dev.bash` artifact intentionally retains Doxygen comments so reviewers can
inspect the fully assembled source in consumer order.  The stripped and minified
artifacts intentionally allow that source documentation to remain verbose
without forcing all consumers to receive the same comment volume.

## General File Structure Pattern

1. shebang
2. shellcheck language identifier
3. `@file`
4. `@brief` for the file
5. `@details` for the file
6. `@author`, `@copyright`, `@see`, `@note`, `@warning` as-needed
7. global variables
8. functions

## General Function Structure Pattern

1. optional `@module` or `@package` when the function belongs to a documentation
   group
2. optional `@namespace` when an explicit documentation namespace is required
3. `@fn`
4. `@brief`
5. `@details`
6. additional `@note`, `@warning`, `@see`, and `@par Side Effects` directives
   as needed; directives that qualify a specific section may appear adjacent to
   that section
7. blank line
8. zero or more `@param` directives
9. blank line
10. exactly one `@par STDIN`
11. exactly one `@par STDOUT`
12. exactly one `@par STDERR`
13. blank line
14. exactly one `@returns`
15. zero or more `@retval` directives
16. `@par Examples`
17. `@code`
18. example lines
19. `@endcode`

A qualified `@fn` may establish the documentation namespace without a separate
`@namespace`.  Do not add redundant `@namespace` metadata unless the redundancy
improves source clarity and all explicit identity sources agree.  Module metadata
is independent of namespace metadata and must be repeated in each member block.

## Review Standard

Review documentation with the same seriousness as executable code.  Ask whether
a maintainer unfamiliar with the current implementation could understand:

* the responsibility of each module;
* the contract of each function;
* important inputs, outputs, and exit-status semantics;
* invariants and ordering requirements;
* meaningful edge cases and failure modes;
* security-sensitive state and output boundaries;
* why non-obvious implementation choices exist;
* which architectural decisions constrain future changes;
* and what the implementation explicitly does not guarantee.

There is no target comment-to-code ratio.  The desired amount is "enough to
preserve the reasoning."  In this project that may often be more prose than
teams accustomed to sparse Bash comments expect, and that is intentional.

## Structural Checklist

Before considering a maintained Bash file adequately documented, verify as
applicable:

* the file starts with `#!/usr/bin/env bash`;
* the file has `# shellcheck shell=bash`;
* the file has `## @file`, `## @brief`, and substantive `## @details`;
* all functions have `@fn`, `@brief`, and `@details`;
* namespaced function documentation uses a literal qualified Bash name, a
  qualified `@fn`, or explicit `@namespace` plus `@fn`, and does not rely on
  inferred implementation prefixes;
* redundant namespace evidence agrees when more than one explicit source is
  present;
* module definitions prefer `@module`; `@package` is only an exact alias for the
  same Doxygen group abstraction;
* module identifiers use the supported flat identifier grammar;
* module members repeat explicit block-local module metadata and use `@fn` or
  `@var` rather than relying on proximity or inferred naming conventions;
* parameters are documented in call order;
* every function contains exactly one `@par STDIN`, one `@par STDOUT`, one
  `@par STDERR`, and one `@returns`;
* meaningful exit statuses are documented with `@retval` or equivalent
  Doxygen vocabulary;
* significant variables use `@var` where useful;
* public or non-trivial functions contain an example when an example improves
  understanding;
* documentation blocks remain adjacent to the declarations consumed by
  `bash-doxygen`;
* and security-sensitive code documents the assumptions a future reviewer would
  otherwise have to infer.
