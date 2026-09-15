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
	@check_xml() { \
		label="$$1"; \
		needle="$$2"; \
		if ! grep -R -Fq "$$needle" "$(INTEGRATION_OUT)/xml"; then \
			printf 'Missing Doxygen XML semantic: %s\n' "$$label" >&2; \
			grep -R -n -E 'normalize_input|normalized|return|integration::nested|namespaced' "$(INTEGRATION_OUT)/xml" >&2 || true; \
			return 1; \
		fi; \
	}; \
	check_xml 'file brief' 'Provides the focused bash-doxygen Doxygen integration fixture.'; \
	check_xml 'integration variable name' '<name>BASH_DOXYGEN_INTEGRATION_VALUE</name>'; \
	check_xml 'integration variable brief' 'Integration sentinel variable used to verify Doxygen indexing.'; \
	check_xml 'normalize_input function name' '<name>normalize_input</name>'; \
	check_xml 'normalize_input parameter declaration' '<declname>input_value</declname>'; \
	check_xml 'normalize_input parameter direction' '<parametername direction="in">input_value</parametername>'; \
	check_xml 'normalize_input parameter documentation' 'Value to normalize during integration testing.'; \
	check_xml 'normalize_input return documentation' 'A single normalized integration value.'; \
	check_xml 'nested namespace compound' '<compoundname>integration::nested</compoundname>'; \
	check_xml 'namespaced qualified function' '<definition>int integration::nested::namespaced</definition>'; \
	check_xml 'namespaced function brief' 'Provides a documentation-only namespace integration sentinel.'

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
