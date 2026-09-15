#!/usr/bin/env bash
## @file integration-fixture.bash
## @brief Provides the focused bash-doxygen Doxygen integration fixture.
## @details
## Exercises file, variable, function, and parameter documentation through the
## complete Bash source to pseudo-C++ to Doxygen XML path.

## @var BASH_DOXYGEN_INTEGRATION_VALUE
## @brief Integration sentinel variable used to verify Doxygen indexing.
readonly BASH_DOXYGEN_INTEGRATION_VALUE='ready'

## @fn normalize_input()
## @brief Normalizes one value for Doxygen integration testing.
## @details
## Provides a small documented function whose generated Doxygen model can be
## checked without depending on the repository's full reference-documentation
## corpus.
##
## @param[in] input_value Value to normalize during integration testing.
##
## @par STDIN
## Nothing is read from STDIN.
## @par STDOUT
## The supplied integration value is written unchanged.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A single normalized integration value.
##
## @retval 0 The integration value was emitted successfully.
normalize_input() {
  printf '%s\n' "$1"
}
