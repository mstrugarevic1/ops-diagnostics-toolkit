SCRIPTS := scripts/*.sh
TESTS := tests/*.bats
VERSION := $(shell cat VERSION)
PACKAGE := ops-diagnostics-toolkit
DEB_ROOT := build/$(PACKAGE)_$(VERSION)_all
DEB := dist/$(PACKAGE)_$(VERSION)_all.deb

.PHONY: install-dev format format-check lint test validate package-deb clean

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

validate: format-check lint test

package-deb: validate
	rm -rf build dist
	mkdir -p dist $(DEB_ROOT)/DEBIAN $(DEB_ROOT)/usr/bin $(DEB_ROOT)/usr/share/doc/$(PACKAGE) $(DEB_ROOT)/usr/share/doc/$(PACKAGE)/examples
	install -m 0755 scripts/*.sh $(DEB_ROOT)/usr/bin/
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
		' Small Bash scripts for filesystem, systemd, socket, DNS, and TLS diagnostics.' \
		' This is an unofficial convenience package, not affiliated with Debian, Ubuntu, or any Linux distribution vendor.' \
		>$(DEB_ROOT)/DEBIAN/control
	dpkg-deb --build --root-owner-group $(DEB_ROOT) $(DEB)

clean:
	rm -rf build dist
