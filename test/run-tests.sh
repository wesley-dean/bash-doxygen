#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

for fixture in "$ROOT_DIR"/test/expected/*.cpp; do
    name=${fixture##*/}
    name=${name%.cpp}

    awk -f "$ROOT_DIR/doxygen-bash.awk" -- --compact \
        "$ROOT_DIR/test/fixtures/$name.bash" \
        > "$TMP_DIR/$name.cpp"

    diff -u "$fixture" "$TMP_DIR/$name.cpp"
done

if awk -f "$ROOT_DIR/doxygen-bash.awk" -- --strict --compact \
    "$ROOT_DIR/test/fixtures/strict-mismatch.bash" \
    > "$TMP_DIR/strict-mismatch.cpp" 2> "$TMP_DIR/strict-mismatch.err"; then
    printf '%s\n' 'not ok - strict mode accepted mismatched @fn documentation' >&2
    exit 1
fi

printf '%s\n' 'ok - filter regressions passed'
