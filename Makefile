SCRIPTS := scripts/*.sh
TESTS := tests/*.bats

.PHONY: install-dev format format-check lint test validate

install-dev:
	@printf '%s\n' 'Install shellcheck, shfmt, and bats with your OS package manager.'

format:
	shfmt -w -i 4 $(SCRIPTS) $(TESTS) tests/helpers/*.bash tests/fixtures/bin/*

format-check:
	shfmt -d -i 4 $(SCRIPTS) $(TESTS) tests/helpers/*.bash tests/fixtures/bin/*

lint:
	shellcheck $(SCRIPTS) tests/helpers/*.bash tests/fixtures/bin/*

test:
	bats $(TESTS)

validate: format-check lint test
