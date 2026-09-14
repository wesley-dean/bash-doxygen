#!/bin/sh
## @file tests/run-tests.sh
## @brief Runs the bash-doxygen behavior-focused regression suite.
## @details
## Exercises one or more Bash Doxygen filters supplied as LABEL=PATH arguments.
## Successful fixtures, diagnostic fixtures, generated-artifact contracts, and
## default line-preserving behavior are reported as one TAP stream.  The harness
## accumulates ordinary assertion failures so callers receive the complete set of
## regressions from a run while reserving TAP bail-outs for unusable test state.
##
## @par Examples
## @code
## sh ./tests/run-tests.sh source=doxygen-bash.awk
## sh ./tests/run-tests.sh source=doxygen-bash.awk ordinary=dist/doxygen-bash.awk
## @endcode
set -u

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

AWK_BIN=${AWK_BIN:-awk}
TEST_NUMBER=0
FAILURE_COUNT=0

## @fn tap_ok()
## @brief Emits one successful TAP assertion.
## @param description Human-readable assertion description.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One numbered TAP success record is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
## @returns One TAP assertion line.
## @retval 0 The TAP record was emitted.
tap_ok() {
    TEST_NUMBER=$((TEST_NUMBER + 1))
    printf 'ok %s - %s\n' "$TEST_NUMBER" "$1"
}

## @fn tap_not_ok()
## @brief Emits one failed TAP assertion and records the failure.
## @param description Human-readable assertion description.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One numbered TAP failure record is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
## @returns One TAP failure assertion line.
## @retval 0 The TAP record was emitted and the failure counter was updated.
tap_not_ok() {
    TEST_NUMBER=$((TEST_NUMBER + 1))
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    printf 'not ok %s - %s\n' "$TEST_NUMBER" "$1"
}

## @fn tap_diag()
## @brief Emits diagnostic text that remains valid inside a TAP stream.
## @param message Diagnostic text to annotate.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One TAP diagnostic line prefixed with a hash is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
## @returns One TAP diagnostic line.
## @retval 0 The diagnostic line was emitted.
tap_diag() {
    printf '# %s\n' "$1"
}

## @fn tap_file_diag()
## @brief Emits a text file as TAP diagnostic lines.
## @param path File whose contents should be annotated.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The file contents are written to STDOUT with TAP diagnostic prefixes.
## @par STDERR
## Nothing is written to STDERR.
## @returns The annotated file contents.
## @retval 0 The file was emitted successfully.
tap_file_diag() {
    sed 's/^/# /' "$1"
}

## @fn bail_out()
## @brief Terminates the harness when the test environment is unusable.
## @param message Human-readable reason the harness cannot continue.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One TAP bail-out record is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
## @returns A TAP bail-out record.
## @retval 1 The harness terminates because testing cannot continue.
bail_out() {
    printf 'Bail out! %s\n' "$1"
    exit 1
}

## @fn normalize_warnings()
## @brief Removes source-location prefixes from filter diagnostics.
## @param path File containing raw filter diagnostics.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Normalized diagnostic text is written to STDOUT.
## @par STDERR
## sed diagnostics may be written to STDERR if normalization fails.
## @returns Normalized warning text without generated source locations.
## @retval 0 The sed transformation completed successfully.
normalize_warnings() {
    sed 's/^.*: warning: //' "$1"
}

## @fn resolve_filter_path()
## @brief Resolves a filter path against the repository root when needed.
## @param path Absolute or repository-relative filter path.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The resolved absolute filter path is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
## @returns One absolute filter path.
## @retval 0 The path was rendered.
resolve_filter_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$ROOT_DIR" "$1" ;;
    esac
}

## @fn verify_checksum()
## @brief Verifies the checksum adjacent to one generated AWK artifact.
## @param path Absolute path to the generated AWK artifact.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Verification-tool diagnostics are suppressed by this helper.
## @returns Nothing is written to STDOUT.
## @retval 0 The checksum exists and verifies successfully.
## @retval 1 The checksum is missing, no supported verifier exists, or verification fails.
verify_checksum() {
    artifact=$1
    checksum=$artifact.sha256
    directory=${artifact%/*}
    filename=${artifact##*/}

    [ -f "$checksum" ] || return 1

    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$directory" && sha256sum -c "$filename.sha256" >/dev/null 2>&1)
        return $?
    fi
    if command -v shasum >/dev/null 2>&1; then
        (cd "$directory" && shasum -a 256 -c "$filename.sha256" >/dev/null 2>&1)
        return $?
    fi
    return 1
}

## @fn check_artifact_contract()
## @brief Validates generated-artifact metadata and checksum expectations.
## @param label Logical filter label supplied by the Makefile.
## @param path Absolute path to the filter under test.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## TAP assertions and diagnostics are written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
## @returns TAP records describing the generated artifact contract.
## @retval 0 Contract assertions were emitted; failures are tracked globally.
check_artifact_contract() {
    label=$1
    path=$2

    [ "$label" != source ] || return 0

    contract_ok=1
    first_line=$(sed -n '1p' "$path" 2>/dev/null || printf '')
    [ "$first_line" = '#!/usr/bin/awk -f' ] || contract_ok=0
    grep -Fq '# Generated by make build. Do not edit directly.' "$path" 2>/dev/null || contract_ok=0
    grep -Fq '# DOXYGEN_BASH_VERSION=' "$path" 2>/dev/null || contract_ok=0
    grep -Fq '# DOXYGEN_BASH_BUILD_DATE=' "$path" 2>/dev/null || contract_ok=0
    grep -Fq '# DOXYGEN_BASH_BUILD_COMMIT=' "$path" 2>/dev/null || contract_ok=0

    case "$label" in
        development)
            grep -Fq '# Artifact: development' "$path" 2>/dev/null || contract_ok=0
            grep -Fq '# Documentation-led Doxygen preprocessor for Bash' "$path" 2>/dev/null || contract_ok=0
            ;;
        ordinary)
            grep -Fq '# Artifact: ordinary' "$path" 2>/dev/null || contract_ok=0
            if sed '1,/^# End generated header\.$/d' "$path" | grep -q '^[[:space:]]*#'; then
                contract_ok=0
            fi
            ;;
        minified)
            grep -Fq '# Artifact: minified' "$path" 2>/dev/null || contract_ok=0
            grep -Fq '# Minifier: AWK Minifier v0.2.4' "$path" 2>/dev/null || contract_ok=0
            ;;
        *)
            contract_ok=0
            ;;
    esac

    if [ "$contract_ok" -eq 1 ]; then
        tap_ok "$label artifact contract"
    else
        tap_not_ok "$label artifact contract"
        tap_diag "generated artifact metadata or representation is invalid: ${path#$ROOT_DIR/}"
    fi

    if verify_checksum "$path"; then
        tap_ok "$label artifact checksum"
    else
        tap_not_ok "$label artifact checksum"
        tap_diag "checksum verification failed: ${path#$ROOT_DIR/}.sha256"
    fi
}

## @fn run_output_cases()
## @brief Runs successful translation fixtures against the selected filter.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## TAP assertions and diagnostics are written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
## @returns TAP records for every successful translation fixture.
## @retval 0 All fixture assertions were emitted; failures are tracked globally.
run_output_cases() {
    for expected in "$ROOT_DIR"/tests/expected/*.cpp; do
        name=${expected##*/}
        name=${name%.cpp}
        input="$ROOT_DIR/tests/fixtures/$name.bash"
        actual="$TMP_DIR/$FILTER_KEY.$name.cpp"
        errors="$TMP_DIR/$FILTER_KEY.$name.err"
        description="$FILTER_LABEL output: $name"

        if [ ! -f "$input" ]; then
            tap_not_ok "$description"
            tap_diag "missing input fixture: ${input#$ROOT_DIR/}"
            continue
        fi

        if ! "$AWK_BIN" -f "$FILTER" -- --compact "$input" >"$actual" 2>"$errors"; then
            tap_not_ok "$description"
            tap_diag 'filter execution failed'
            [ ! -s "$errors" ] || tap_file_diag "$errors"
            continue
        fi
        if [ -s "$errors" ]; then
            tap_not_ok "$description"
            tap_diag 'successful fixture emitted a diagnostic'
            tap_file_diag "$errors"
            continue
        fi
        if ! diff -u "$expected" "$actual" >"$TMP_DIR/$FILTER_KEY.$name.diff" 2>&1; then
            tap_not_ok "$description"
            tap_diag 'filtered output differs from expected pseudo-C++'
            tap_file_diag "$TMP_DIR/$FILTER_KEY.$name.diff"
            continue
        fi

        tap_ok "$description"
    done
}

## @fn run_diagnostic_cases()
## @brief Runs warning and strict-mode diagnostic fixtures.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## TAP assertions and diagnostics are written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
## @returns TAP records for every diagnostic fixture.
## @retval 0 All diagnostic assertions were emitted; failures are tracked globally.
run_diagnostic_cases() {
    for expected in "$ROOT_DIR"/tests/diagnostics/*.err; do
        name=${expected##*/}
        name=${name%.err}
        input="$ROOT_DIR/tests/diagnostics/$name.bash"
        warning_err="$TMP_DIR/$FILTER_KEY.$name.warning.err"
        strict_err="$TMP_DIR/$FILTER_KEY.$name.strict.err"
        normalized="$TMP_DIR/$FILTER_KEY.$name.normalized.err"
        description="$FILTER_LABEL diagnostic: $name"
        case_ok=1

        if [ ! -f "$input" ]; then
            tap_not_ok "$description"
            tap_diag "missing diagnostic fixture: ${input#$ROOT_DIR/}"
            continue
        fi

        if ! "$AWK_BIN" -f "$FILTER" -- --compact "$input" \
            >"$TMP_DIR/$FILTER_KEY.$name.warning.cpp" 2>"$warning_err"; then
            case_ok=0
            tap_diag 'non-strict diagnostic case exited non-zero'
        fi
        normalize_warnings "$warning_err" >"$normalized"
        if ! diff -u "$expected" "$normalized" >"$TMP_DIR/$FILTER_KEY.$name.warning.diff" 2>&1; then
            case_ok=0
            tap_diag 'non-strict diagnostic differs from expected output'
            tap_file_diag "$TMP_DIR/$FILTER_KEY.$name.warning.diff"
        fi

        if "$AWK_BIN" -f "$FILTER" -- --strict --compact "$input" \
            >"$TMP_DIR/$FILTER_KEY.$name.strict.cpp" 2>"$strict_err"; then
            case_ok=0
            tap_diag 'strict diagnostic case exited zero'
        fi
        normalize_warnings "$strict_err" >"$normalized"
        if ! diff -u "$expected" "$normalized" >"$TMP_DIR/$FILTER_KEY.$name.strict.diff" 2>&1; then
            case_ok=0
            tap_diag 'strict diagnostic differs from expected output'
            tap_file_diag "$TMP_DIR/$FILTER_KEY.$name.strict.diff"
        fi

        if [ "$case_ok" -eq 1 ]; then
            tap_ok "$description"
        else
            tap_not_ok "$description"
        fi
    done
}

## @fn run_default_mode_case()
## @brief Verifies default blank-placeholder line preservation.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## One TAP assertion and any diagnostics are written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
## @returns One TAP record for the default output mode.
## @retval 0 The assertion was emitted; failure is tracked globally.
run_default_mode_case() {
    input="$ROOT_DIR/tests/fixtures/undocumented-ignored.bash"
    actual="$TMP_DIR/$FILTER_KEY.default-blanks.cpp"
    errors="$TMP_DIR/$FILTER_KEY.default-blanks.err"
    description="$FILTER_LABEL mode: default blank placeholders"
    case_ok=1

    if ! "$AWK_BIN" -f "$FILTER" "$input" >"$actual" 2>"$errors"; then
        case_ok=0
        tap_diag 'default-mode filter execution failed'
    fi
    if [ -s "$errors" ]; then
        case_ok=0
        tap_diag 'default mode emitted a diagnostic for ignored lines'
        tap_file_diag "$errors"
    fi

    expected_lines=$(wc -l <"$input" | tr -d ' ')
    actual_lines=$(wc -l <"$actual" | tr -d ' ')
    if [ "$actual_lines" -ne "$expected_lines" ]; then
        case_ok=0
        tap_diag "expected $expected_lines placeholder lines, found $actual_lines"
    fi
    if grep -q '[^[:space:]]' "$actual"; then
        case_ok=0
        tap_diag 'default mode emitted non-blank content for undocumented input'
    fi

    if [ "$case_ok" -eq 1 ]; then
        tap_ok "$description"
    else
        tap_not_ok "$description"
    fi
}

## @fn run_filter_suite()
## @brief Runs the complete regression contract against one filter.
## @param label Logical name used in TAP assertion descriptions.
## @param path Absolute or repository-relative filter path.
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## TAP assertions and diagnostics are written to STDOUT.
## @par STDERR
## Nothing is intentionally written to STDERR.
## @returns TAP records for the selected filter.
## @retval 0 The suite assertions were emitted; failures are tracked globally.
run_filter_suite() {
    FILTER_LABEL=$1
    FILTER=$(resolve_filter_path "$2")
    FILTER_KEY=$(printf '%s' "$FILTER_LABEL" | tr -c 'A-Za-z0-9_.-' '_')

    if [ ! -f "$FILTER" ]; then
        tap_not_ok "$FILTER_LABEL filter availability"
        tap_diag "missing filter: ${FILTER#$ROOT_DIR/}"
        return 0
    fi

    check_artifact_contract "$FILTER_LABEL" "$FILTER"
    run_output_cases
    run_diagnostic_cases
    run_default_mode_case
}

printf 'TAP version 13\n'
printf '# AWK_BIN: %s\n' "$AWK_BIN"

[ "$#" -gt 0 ] || set -- "source=doxygen-bash.awk"

for filter_spec do
    case "$filter_spec" in
        *=*) ;;
        *) bail_out "invalid filter specification: $filter_spec" ;;
    esac

    filter_label=${filter_spec%%=*}
    filter_path=${filter_spec#*=}
    [ -n "$filter_label" ] || bail_out 'filter label must not be empty'
    [ -n "$filter_path" ] || bail_out "filter path must not be empty: $filter_label"
    run_filter_suite "$filter_label" "$filter_path"
done

printf '1..%s\n' "$TEST_NUMBER"

[ "$FAILURE_COUNT" -eq 0 ]
