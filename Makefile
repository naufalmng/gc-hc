# gc-chkr — Makefile
#
# Targets are deliberately thin wrappers around scripts/. The shell scripts
# are the source of truth; make is just an ergonomic surface.

VERSION    := $(shell cat VERSION | tr -d '[:space:]')
ROOT       := $(shell pwd)
DIST       := $(ROOT)/dist
SHELL      := bash

.PHONY: help build clean test lint format install uninstall standalone deb release version

help:                    ## show this help
	@awk 'BEGIN{FS=":.*##"; printf "\n  \033[1mgc-chkr v$(VERSION)\033[0m\n\n"} \
	      /^[a-zA-Z_-]+:.*##/{ printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo

version:                 ## print version
	@echo $(VERSION)

build:                   ## assemble dist/gc-chkr.sh and dist/gc-chkr
	@bash scripts/build.sh

clean:                   ## remove build artifacts
	@rm -rf $(DIST)
	@echo "  cleaned $(DIST)"

lint:                    ## run shellcheck on all shell sources
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }
	@shellcheck \
	    src/tool/*.sh \
	    src/installer/*.sh \
	    scripts/*.sh \
	    tests/bats/*.bash 2>/dev/null || true

format:                  ## format with shfmt (2-space, indent=2)
	@command -v shfmt >/dev/null || { echo "shfmt not installed"; exit 1; }
	@shfmt -w -i 2 -ci -bn src/ scripts/ tests/

test: build              ## run bats unit tests against dist artifacts
	@command -v bats >/dev/null || { echo "bats not installed"; exit 1; }
	@bats tests/bats

install: build           ## build + install via apt (requires root)
	@sudo bash $(DIST)/gc-chkr.sh install --yes

uninstall:               ## remove via apt
	@sudo apt-get remove -y gc-chkr

standalone: build        ## drop dist/gc-chkr at $PWD as standalone binary
	@bash $(DIST)/gc-chkr.sh standalone --yes --force

deb: build               ## build a .deb in dist/
	@sudo bash $(DIST)/gc-chkr.sh install --yes --keep-deb || true
	@ls -la $(ROOT)/*.deb 2>/dev/null || true

release:                 ## tag the current VERSION and push (requires gh)
	@git tag -a v$(VERSION) -m "Release v$(VERSION)"
	@git push origin v$(VERSION)
	@echo "tagged v$(VERSION); GitHub Actions will publish the release"
