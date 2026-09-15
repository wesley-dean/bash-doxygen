# ADR-008: Bound declaration association with explicit lexical rules

Date: 2026-09-14

## Status

Accepted

## Intent and Documentation Posture

This ADR defines how `bash-doxygen` associates a documentation block with several
common Bash declaration forms without expanding the filter into a general Bash
parser.  The decision covers explicit uninitialized variable declarations,
recognized tooling annotations between documentation and a declaration, and
multi-name declaration handling.

The project remains documentation-led and evidence-oriented.  Association rules
must therefore be explicit, narrow, testable, and honest about syntax the filter
does not model.

## Context

The filter originally associated a Doxygen block with the next recognized Bash
function or variable declaration.  That model worked well for initialized
variables such as:

```bash
## @var CACHE_DIR
local CACHE_DIR=/tmp/cache
```

and for uninitialized `declare NAME` or `typeset NAME`, because those commands
already placed the variable classifier into explicit declaration mode.

Three gaps remained.

First, Bash also permits uninitialized declarations using `local`, `readonly`,
and `export`:

```bash
local CACHE_DIR
readonly VERSION
export PATH_VALUE
```

The existing classifier retained their storage, read-only, and export metadata,
but rejected them when no `=` followed the name.

Second, a narrow tooling annotation may legitimately sit between documentation
and the declaration it qualifies:

```bash
## @fn load_config()
## @brief Loads configuration.
# shellcheck disable=SC2155
load_config() {
  :
}
```

Treating every comment as transparent would make declaration association too
permissive and could silently connect documentation with a declaration farther
down the file.  Treating every comment as a hard barrier prevents a common,
well-defined ShellCheck annotation from coexisting with documentation.

Third, explicit Bash declaration commands can declare more than one name on one
line:

```bash
declare -r FOO=one BAR=two
```

The previous line-oriented classifier found the first assignment and could
silently emit documentation for `FOO` while ignoring `BAR`.  That partial
interpretation is especially problematic for a documentation compiler because
its output appears authoritative even though the source declaration contains
additional state that was not modeled.

## Decision Drivers

- Preserve the documentation-led, bounded parser architecture established by
  ADR-000.
- Recognize common explicit Bash declaration forms when their intent is clear.
- Avoid silent partial interpretation of one declaration as though it described
  only one symbol.
- Keep tooling-comment transparency opt-in and evidence-based.
- Preserve existing strict-mode behavior for diagnostics.
- Avoid executing Bash or introducing a general shell parser.
- Keep new behavior observable through small regression fixtures under ADR-004.

## Decision

### Explicit uninitialized declarations

`local`, `readonly`, `export`, `declare`, and `typeset` SHALL place the variable
classifier into explicit declaration mode once the command itself is recognized.
A single valid variable name is therefore a supported declaration even when no
initializer is present.

Examples include:

```bash
local CACHE_DIR
readonly VERSION
export PATH_VALUE
declare DECLARED
typeset TYPESET_VALUE
```

Existing metadata inference continues to apply.  An uninitialized `local` value
is emitted as local, an uninitialized `readonly` value as read-only, and an
uninitialized `export` value as exported.  Absence of an initializer does not
invent a value or type beyond the classifier's existing default scalar string
representation.

A bare identifier without an explicit declaration command remains outside this
rule.  The filter SHALL NOT infer that an arbitrary line containing only `NAME`
is a variable declaration.

### Recognized annotation transparency

The initial transparent annotation contract is intentionally limited to
ShellCheck disable directives of the form:

```text
# shellcheck disable=SC2155
# shellcheck disable=SC2034,SC2155
```

Optional indentation, spacing after `#`, and spacing around comma separators may
be tolerated, but the directive must remain a ShellCheck `disable=` directive
containing ShellCheck rule identifiers.

A recognized directive preserves the pending documentation-to-declaration
association.  In line-preserving output mode it contributes a blank placeholder;
in compact mode it contributes no output.

Arbitrary comments remain association barriers.  Other ShellCheck directives,
other tooling annotations, and other comment forms SHALL NOT become transparent
merely because they resemble metadata.  Each additional transparent annotation
family requires an explicit implementation change and regression coverage.

### Multi-name declaration policy

A documented explicit declaration command that contains more than one top-level
declaration word is unsupported.

When the filter identifies such a declaration, it SHALL:

1. emit a specific diagnostic;
2. emit no synthesized variable declaration for any name on that line;
3. avoid selecting the first name as though it were the whole declaration; and
4. fail under `--strict` according to the existing diagnostic contract.

The current diagnostic is:

```text
documented multi-name variable declarations are unsupported
```

This rule applies to explicit declaration commands such as `local`, `readonly`,
`export`, `declare`, and `typeset` after their supported option flags have been
removed.

### Bounded lexical detection

The filter SHALL NOT invoke a Bash parser or execute source to detect multi-name
declarations.  It uses a small lexical scanner whose sole purpose is to count
top-level declaration words after a recognized explicit declaration command.

The scanner treats whitespace as a separator only when it is outside recognized
single quotes, double quotes, backticks, escaped characters, parentheses,
braces, and brackets.  This is sufficient to avoid treating common grouped
initializers and expansions as additional declared names, for example:

```bash
declare VALUE="one two"
declare -a VALUES=(one two three)
declare VALUE=$(printf '%s %s' one two)
```

The scanner is not a promise to understand arbitrary Bash grammar.  Its scope is
limited to distinguishing one top-level declaration word from multiple
top-level declaration words within the declaration forms this filter already
recognizes.  Syntax whose structure cannot be represented honestly by this
bounded model remains unsupported rather than being generalized implicitly.

## Considered Alternatives

### Document only the first name in a multi-name declaration

This would preserve the previous implementation tendency and require less code.
It was rejected because the resulting documentation would silently omit other
names in the same declaration while presenting the emitted first symbol as a
complete interpretation of the source line.

### Emit one documented symbol and warn about the remainder

This would make the partial interpretation visible, but it would still create a
synthesized symbol from a declaration the filter admits it does not model fully.
A diagnostic with no partial declaration provides a cleaner and more auditable
boundary.

### Parse arbitrary Bash declarations completely

A shell parser could model quoting, expansions, arrays, assignments, command
substitution, and every multi-name form more completely.  This was rejected
because it would substantially expand project scope, portability obligations,
security considerations, implementation complexity, and maintenance burden.
The project is a documentation compiler, not a Bash parser.

### Make all comments transparent between documentation and declarations

This would solve the ShellCheck case with little pattern-specific logic.  It was
rejected because ordinary comments may intentionally separate concepts or may
indicate that the following declaration is unrelated to the preceding Doxygen
block.  Broad transparency would weaken the project's evidence requirement.

### Keep all comments as hard barriers

This is the simplest association rule.  It was rejected for the narrowly defined
ShellCheck `disable=` case because the annotation directly qualifies the
following source construct and is common enough to support explicitly without
weakening the general boundary.

### Support only initialized explicit declarations

This would preserve previous behavior for `local`, `readonly`, and `export`.
It was rejected because these commands explicitly declare Bash variables even
when no initializer is present; rejecting them loses clear source intent without
providing a compensating safety or simplicity benefit.

## Consequences

Documented uninitialized variables declared with `local`, `readonly`, `export`,
`declare`, or `typeset` are now represented consistently with their initialized
counterparts.

A supported ShellCheck disable annotation may appear between a Doxygen block and
the declaration it qualifies without severing association.  Ordinary comments
continue to sever that association, preventing a broad comment-skipping rule.

Documented multi-name explicit declarations now fail visibly instead of
producing a plausible but incomplete first-symbol representation.  Authors who
want those names documented must place them in separate supported declaration
statements.

The implementation gains a small lexical helper for top-level word counting.
That helper is deliberately narrower than a shell tokenizer and must not become
a staging ground for unbounded Bash parsing.  Future syntax expansions should
be justified independently against ADR-000 and this decision.

Regression coverage includes each supported uninitialized declaration command,
a recognized ShellCheck annotation, an arbitrary comment that remains a barrier,
and the explicit multi-name diagnostic.  The ordinary test harness exercises
maintained source and all generated filter representations under ADR-004.

## Compatibility and Migration

Existing supported single-name declarations retain their behavior.

Previously unsupported uninitialized `local`, `readonly`, and `export`
declarations become supported.  Existing uninitialized `declare` and `typeset`
behavior remains supported.

A documented multi-name declaration that was previously interpreted partially
will now produce a diagnostic and, under strict mode, a non-zero exit status.
This is an intentional tightening of an ambiguous behavior rather than a promise
to preserve silent partial output.

Source containing arbitrary comments between a Doxygen block and declaration
continues to behave as before.  Only the explicitly recognized ShellCheck
`disable=` form becomes transparent.

## Expected Outcomes

- common explicit uninitialized declarations are documented correctly;
- ShellCheck suppression annotations can coexist with immediately preceding
  Doxygen documentation;
- arbitrary comments do not unexpectedly widen documentation association;
- multi-name declarations cannot silently produce incomplete documentation; and
- the parser boundary remains small enough to inspect, test, and explain.

## Related Decisions

- ADR-000 establishes capability honesty, bounded scope, and evidence-oriented
  reasoning.
- ADR-004 governs behavior-focused regression fixtures and generated-artifact
  equivalence testing.
- ADR-008 does not change ADR-001 parameter-name normalization or ADR-002
  synthesized function-signature behavior.
- GitHub issue #21 requested the declaration-association behavior governed here.
