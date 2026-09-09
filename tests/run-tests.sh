#!/bin/sh
## @file run-tests.sh
## @brief Runs the bash-doxygen behavior-focused regression suite.
## @details
## Exercises the maintained or generated Bash Doxygen filter supplied through
## DOXYGEN_BASH_FILTER.  Successful fixtures, diagnostic fixtures, and default
## line-preserving behavior are validated with temporary output removed on exit.
## This harness is maintained shell source and is also used to dogfood the
## selected bash-doxygen filter during generated reference documentation builds.
## @par Examples
## @code
## sh ./tests/run-tests.sh
## DOXYGEN_BASH_FILTER=dist/doxygen-bash.awk sh ./tests/run-tests.sh
## @endcode
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

FILTER=${DOXYGEN_BASH_FILTER:-"$ROOT_DIR/doxygen-bash.awk"}
case "$FILTER" in
    /*) ;;
    *) FILTER="$ROOT_DIR/$FILTER" ;;
esac

CASE_COUNT=0

## @fn fail()
## @brief Reports a failed regression assertion and terminates the harness.
## @details
## Centralizes TAP-like failure output so individual assertions stop the suite
## immediately without duplicating diagnostic formatting and exit behavior.
## @param message Human-readable assertion failure supplied as the first argument.
## @retval 1 The harness exits with failure.
## @par Examples
## @code
## fail "missing input fixture"
## @endcode
fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

## @fn normalize_warnings()
## @brief Removes source-location prefixes from filter diagnostics.
## @details
## Golden diagnostic fixtures describe stable warning text rather than temporary
## source paths and record prefixes.  This helper strips that generated prefix
## before a diagnostic result is compared with its expected file.
## @param path File containing raw filter diagnostics as the first argument.
## @returns Normalized diagnostic text on standard output.
## @retval 0 The sed transformation completed successfully.
## @par Examples
## @code
## normalize_warnings "$TMP_DIR/example.err"
## @endcode
normalize_warnings() {
    sed 's/^.*: warning: //' "$1"
}

for expected in "$ROOT_DIR"/tests/expected/*.cpp; do
    name=${expected##*/}
    name=${name%.cpp}
    input="$ROOT_DIR/tests/fixtures/$name.bash"
    actual="$TMP_DIR/$name.cpp"
    errors="$TMP_DIR/$name.err"

    test -f "$input" || fail "missing input fixture for $name"

    if ! awk -f "$FILTER" -- --compact "$input" > "$actual" 2> "$errors"; then
        fail "compact output case failed to execute: $name"
    fi
    test ! -s "$errors" || fail "compact output case emitted a diagnostic: $name"
    diff -u "$expected" "$actual" || fail "compact output mismatch: $name"

    CASE_COUNT=$((CASE_COUNT + 1))
    printf 'ok - output: %s\n' "$name"
done

for expected in "$ROOT_DIR"/tests/diagnostics/*.err; do
    name=${expected##*/}
    name=${name%.err}
    input="$ROOT_DIR/tests/diagnostics/$name.bash"
    warning_err="$TMP_DIR/$name.warning.err"
    strict_err="$TMP_DIR/$name.strict.err"
    normalized="$TMP_DIR/$name.normalized.err"

    test -f "$input" || fail "missing diagnostic fixture for $name"

    if ! awk -f "$FILTER" -- --compact "$input" \
        > "$TMP_DIR/$name.warning.cpp" 2> "$warning_err"; then
        fail "non-strict diagnostic case exited non-zero: $name"
    fi
    normalize_warnings "$warning_err" > "$normalized"
    diff -u "$expected" "$normalized" || fail "non-strict diagnostic mismatch: $name"

    if awk -f "$FILTER" -- --strict --compact "$input" \
        > "$TMP_DIR/$name.strict.cpp" 2> "$strict_err"; then
        fail "strict diagnostic case exited zero: $name"
    fi
    normalize_warnings "$strict_err" > "$normalized"
    diff -u "$expected" "$normalized" || fail "strict diagnostic mismatch: $name"

    CASE_COUNT=$((CASE_COUNT + 1))
    printf 'ok - diagnostic: %s\n' "$name"
done

# Compact mode suppresses ignored source lines. The corresponding default-mode
# behavior is intentionally tested separately so the golden fixtures can remain
# focused on translated content.
input="$ROOT_DIR/tests/fixtures/undocumented-ignored.bash"
actual="$TMP_DIR/default-blanks.cpp"
errors="$TMP_DIR/default-blanks.err"
awk -f "$FILTER" "$input" > "$actual" 2> "$errors"
test ! -s "$errors" || fail 'default mode emitted a diagnostic for ignored lines'
expected_lines=$(wc -l < "$input" | tr -d ' ')
actual_lines=$(wc -l < "$actual" | tr -d ' ')
test "$actual_lines" -eq "$expected_lines" || fail 'default mode did not preserve ignored-line placeholders'
if grep -q '[^[:space:]]' "$actual"; then
    fail 'default mode emitted non-blank content for undocumented input'
fi
CASE_COUNT=$((CASE_COUNT + 1))
printf '%s\n' 'ok - mode: default blank placeholders'

printf 'ok - %s regression cases passed\n' "$CASE_COUNT"
