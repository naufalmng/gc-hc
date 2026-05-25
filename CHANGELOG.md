# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Refactored from a single 1930-line script into a modular source tree under
  `src/tool/` (15 files) and `src/installer/` (9 files), assembled into a
  self-contained installer by `scripts/build.sh`. Behaviour is preserved;
  the on-the-wire experience (`curl ... | sudo bash`) is unchanged.
- Installer gains a banner, `[N/M]` step indicators, and ANSI colors. Colors
  auto-disable when stdout is not a TTY, when `NO_COLOR=1` is set, or when
  `TERM=dumb`.
- `apt-get install` invocation now records `Maintainer:` and `Homepage:`
  fields in the generated `.deb` control file.

### Added
- Build pipeline (`scripts/build.sh`, `Makefile`).
- Bats unit tests for pure functions (`tests/bats/`).
- Smoke + parity test scripts that verify the assembled artifact retains
  every contract of the original single-file version.
- GitHub Actions: `ci.yml` (build, lint, test on every PR) and `release.yml`
  (publishes `dist/gc-chkr.sh`, `dist/gc-chkr`, and `SHA256SUMS` on tag push).
- `.shellcheckrc`, `.editorconfig`, `.pre-commit-config.yaml`, `.gitattributes`.

### Fixed
- The original used hard-coded line endings; new source ships with
  `.gitattributes` enforcing LF on shell sources to prevent CRLF breakage
  on `bash -n` from Windows checkouts.

## [1.7.0] - 2025-11-15

### Added
- Initial public release. Single-file installer + tool runtime.
- Configures Grafana Cloud node-side healthcheck:
  Prometheus `remote_write` push, Prometheus query, Loki write,
  optional Fleet Management endpoint, plus DNS/TLS sanity checks.
- Ships a systemd timer for periodic execution.
- Provides `standalone` mode for hosts without `apt`.
- `gc-chkr` and `gchk` aliases.

[Unreleased]: https://github.com/naufalmng/gc-chkr/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/naufalmng/gc-chkr/releases/tag/v1.7.0
