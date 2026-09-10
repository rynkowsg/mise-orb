.DEFAULT_GOAL := help

# Lists every target that carries a `## ` description, in the order they appear.
# Targets without one stay out of the listing, which is how the `_` ones hide.
.PHONY: help
help:  ## Print this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z0-9_\/-]+:.*##/ {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: orb/validate
orb/validate:  ## Pack the orb and validate it (needs a CircleCI token)
	mkdir -p dist
	circleci orb pack ./src > dist/orb.yml
	circleci orb validate dist/orb.yml

.PHONY: format/check
format/check: format-shell/check format-yaml/check  ## Check shell and YAML formatting

.PHONY: format/fix
format/fix: format-shell/fix format-yaml/fix  ## Format shell and YAML

.PHONY: _format-shell/deps
_format-shell/deps:
	sosh fetch @bin/format.bash

.PHONY: format-shell/check
format-shell/check: _format-shell/deps  ## Check shell formatting
	./@bin/format.bash check

.PHONY: format-shell/fix
format-shell/fix: _format-shell/deps  ## Format shell scripts
	./@bin/format.bash apply

.PHONY: format-yaml/check
format-yaml/check:  ## Check YAML formatting
	yamlfmt --lint .

.PHONY: format-yaml/fix
format-yaml/fix:  ## Format YAML files
	yamlfmt .

.PHONY: lint/check
lint/check: lint-shell/check lint-yaml/check  ## Lint shell and YAML

.PHONY: _lint-shell/deps
_lint-shell/deps:
	sosh fetch @bin/lint.bash

# lint.bash runs shellcheck with --external-sources, so shellcheck follows the
# `# shellcheck source=` directive in @bin/format.bash, which is one of the files
# it lints. The library that directive points at has to be fetched as well,
# otherwise shellcheck reports SC1091 and the lint fails.
.PHONY: lint-shell/check
lint-shell/check: _format-shell/deps _lint-shell/deps  ## Lint shell scripts
	./@bin/lint.bash

.PHONY: lint-yaml/check
lint-yaml/check:  ## Lint YAML files
	yamllint .

.PHONY: test
test:  ## Run the bats tests
	bats test/scripts

.PHONY: check
check: format/check lint/check test orb/validate  ## Run every check and the tests
