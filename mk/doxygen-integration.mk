# Focused Doxygen semantic integration testing for bash-doxygen.

INTEGRATION_CONFIG ?= tests/doxygen/Doxyfile
INTEGRATION_OUT ?= tmp/doxygen-integration
DOXYGEN_BASH_FILTER ?= $(SOURCE_FILTER)

.PHONY: integration-clean test-doxygen test-doxygen-dist

## Exercise the selected Bash filter through Doxygen and verify semantic XML.
##
## This intentionally uses a focused fixture and a dedicated XML-only Doxyfile.
## It complements the golden pseudo-C++ suite and the broader project-reference
## documentation canary without coupling either of those paths to Doxygen's HTML
## presentation details.
test-doxygen:
	@test -f "$(DOXYGEN_BASH_FILTER)" || { printf '%s\n' 'Missing Bash Doxygen filter' >&2; exit 1; }
	@command -v doxygen >/dev/null 2>&1 || { printf '%s\n' 'doxygen is required for make test-doxygen' >&2; exit 1; }
	$(MAKE) --no-print-directory integration-clean
	@mkdir -p "$(INTEGRATION_OUT)"
	AWK_BIN="$(AWK_BIN)" \
	DOXYGEN_BASH_FILTER="$(abspath $(DOXYGEN_BASH_FILTER))" \
		doxygen "$(INTEGRATION_CONFIG)"
	@test -f "$(INTEGRATION_OUT)/xml/index.xml"
	@grep -R -Fq 'Provides the focused bash-doxygen Doxygen integration fixture.' "$(INTEGRATION_OUT)/xml"
	@grep -R -Fq '<name>BASH_DOXYGEN_INTEGRATION_VALUE</name>' "$(INTEGRATION_OUT)/xml"
	@grep -R -Fq 'Integration sentinel variable used to verify Doxygen indexing.' "$(INTEGRATION_OUT)/xml"
	@grep -R -Fq '<name>normalize_input</name>' "$(INTEGRATION_OUT)/xml"
	@grep -R -Fq '<declname>input_value</declname>' "$(INTEGRATION_OUT)/xml"
	@grep -R -Fq 'Value to normalize during integration testing.' "$(INTEGRATION_OUT)/xml"
	@grep -R -Fq 'A single normalized integration value.' "$(INTEGRATION_OUT)/xml"

## Exercise every generated release candidate through the same Doxygen contract.
test-doxygen-dist: build
	@for artifact in $(DIST_FILTERS); do \
		printf '%s\n' "Doxygen integration: $$artifact"; \
		$(MAKE) --no-print-directory test-doxygen \
			AWK_BIN="$(AWK_BIN)" \
			DOXYGEN_BASH_FILTER="$$artifact"; \
	done

## Remove generated focused Doxygen integration output.
integration-clean:
	rm -rf "$(INTEGRATION_OUT)"
