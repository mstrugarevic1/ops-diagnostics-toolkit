SCRIPTS := scripts/*.sh
TESTS := tests/*.bats
VERSION := $(shell cat VERSION)
PACKAGE := ops-diagnostics-toolkit
DEB_ROOT := build/$(PACKAGE)_$(VERSION)_all
DEB := dist/$(PACKAGE)_$(VERSION)_all.deb

.PHONY: install-dev format format-check lint test smoke version-check validate package-deb clean

install-dev:
	@printf '%s\n' 'Install shellcheck, shfmt, bats, and dpkg-deb with your OS package manager.'

format:
	shfmt -w -i 4 $(SCRIPTS) $(TESTS) tests/helpers/*.bash tests/fixtures/bin/*

format-check:
	shfmt -d -i 4 $(SCRIPTS) $(TESTS) tests/helpers/*.bash tests/fixtures/bin/*

lint:
	shellcheck $(SCRIPTS) tests/helpers/*.bash tests/fixtures/bin/*

test:
	bats $(TESTS)

smoke:
	./scripts/system-pressure-report.sh --version >/dev/null
	./scripts/system-pressure-report.sh >/dev/null

version-check:
	@for script in $(SCRIPTS); do \
		grep -q 'VERSION="$(VERSION)"' "$$script" || { printf '%s\n' "$$script version does not match VERSION"; exit 1; }; \
	done

validate: format-check lint test smoke version-check

package-deb: validate
	rm -rf build dist
	mkdir -p dist $(DEB_ROOT)/DEBIAN $(DEB_ROOT)/usr/bin $(DEB_ROOT)/usr/share/doc/$(PACKAGE) $(DEB_ROOT)/usr/share/doc/$(PACKAGE)/examples
	install -m 0755 scripts/*.sh $(DEB_ROOT)/usr/bin/
	for script in scripts/*.sh; do ln -s "$$(basename "$$script")" "$(DEB_ROOT)/usr/bin/$$(basename "$$script" .sh)"; done
	install -m 0644 README.md LICENSE VERSION $(DEB_ROOT)/usr/share/doc/$(PACKAGE)/
	install -m 0644 config/*.example.txt $(DEB_ROOT)/usr/share/doc/$(PACKAGE)/examples/
	printf '%s\n' \
		'Package: $(PACKAGE)' \
		'Version: $(VERSION)' \
		'Section: admin' \
		'Priority: optional' \
		'Architecture: all' \
		'Maintainer: Ops Diagnostics Toolkit <noreply@example.invalid>' \
		'Depends: bash (>= 4.2), coreutils' \
		'Recommends: dnsutils, iproute2, openssl, systemd' \
		'Homepage: https://github.com/mstrugarevic1/ops-diagnostics-toolkit' \
		'Description: Read-only Linux operations diagnostics toolkit' \
		' Small Bash scripts for filesystem, systemd, socket, DNS, TLS, and host pressure diagnostics.' \
		' This is an unofficial convenience package, not affiliated with Debian, Ubuntu, or any Linux distribution vendor.' \
		>$(DEB_ROOT)/DEBIAN/control
	printf '%s\n' \
		'#!/bin/sh' \
		'set -e' \
		'if ! command -v bash >/dev/null 2>&1; then' \
		'    printf "%s\n" "ERROR: ops-diagnostics-toolkit requires Bash 4.2 or newer." >&2' \
		'    exit 1' \
		'fi' \
		'if ! bash -c '"'"'(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) ))'"'"'; then' \
		'    printf "%s\n" "ERROR: ops-diagnostics-toolkit requires Bash 4.2 or newer." >&2' \
		'    exit 1' \
		'fi' \
		'exit 0' \
		>$(DEB_ROOT)/DEBIAN/preinst
	chmod 0755 $(DEB_ROOT)/DEBIAN/preinst
	dpkg-deb --build --root-owner-group $(DEB_ROOT) $(DEB)

clean:
	rm -rf build dist
