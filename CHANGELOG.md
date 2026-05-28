# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Auto-traceroute on probe failure. When DNS, TLS, push, query, Loki, or Fleet
  checks fail, `gc-hc` now fires a single traceroute against the affected host,
  summarizes the path into the JSON record (`hops=N last=X rtt=Yms`), and
  appends raw output to a per-probe rolling log under `${LOG_DIR}/trace/`.
  Suppressed while a failure persists (state-backed backoff); re-arms once the
  probe recovers, so a 1-hour outage = 1 traceroute, not 12.
- `--trace` / `--no-trace` flags to force-run or disable traceroute for a single
  invocation.
- New env knobs: `GC_HC_TRACE` (auto|always|never), `GC_HC_TRACE_TOOL`
  (auto|traceroute|tracepath), `GC_HC_TRACE_TIMEOUT`, `GC_HC_TRACE_MAX_HOPS`,
  `GC_HC_TRACE_LOG_KEEP`.
- `gc-hc status` shows pending traceroute captures via `trace:` rows when any
  probe is in fail-state. Stays silent during steady-state.

### Changed
- Tool detection prefers `traceroute` (richer output, widely available via
  `apt install traceroute`) and falls back to `tracepath` (UDP, no root, often
  preinstalled via iputils). Skips cleanly when neither is installed. No
  `apt install` at runtime — preserves the zero-dependency contract.

## [2.1.1] - 2026-05-26

### Changed
- `gc-hc check` now renders a human-readable result table when stdout is a TTY. The raw JSON document is still written verbatim to the result file and to the rolling log, and is still returned on stdout when `--json` is passed or when stdout is piped/redirected — so existing automation and dashboards keep working untouched.
- `gc-hc status` removes the redundant `service` row. For a timer-driven unit, the service is `inactive` between runs by design, and the row was duplicating the badge that the `timer` and `last check` rows already carry. The new layout shows `status / timer / last check / interval / next run`.

### Added
- Timer interval is now a first-class config key. `GC_HC_INTERVAL` (default `5m`) joins the rest of the `GC_HC_*` family — read from the environment, persisted to `/etc/gc-hc/env` (or `.gc-hc/env` in standalone mode) by `gc-hc config`, and surfaced by `gc-hc show-config`. The existing `-i` / `--interval` flag still works and now writes into the same variable.
- `gc-hc status` shows the active interval as a friendly token, e.g. `interval: 5m  (every 5 minutes)`, so you no longer have to `systemctl cat gc-hc.timer` to check the schedule.
- `gc-hc help` lists the full set of `GC_HC_*` environment overrides with their defaults.

## [2.0.1] - 2026-05-25

### Fixed
- Product name spelled correctly as **"Grafana Cloud Health Checker"** (with the trailing "er") in the installer banner, README hero, CHANGELOG, and the GitHub repository description. The 2.0.0 release accidentally rendered it as "Health Check" without the "-er" in three user-facing places.

## [2.0.0] - 2026-05-25

### ⚠️ BREAKING CHANGES

The project has been **rebranded from `gc-chkr` to `gc-hc`** (Grafana Cloud Health Checker).
Every user-facing identifier changes. There is **no in-place upgrade path** from 1.x —
remove the old package first, then install 2.0.0 cleanly.

| Old (1.x)              | New (2.0.0)            |
| ---------------------- | ---------------------- |
| `gc-chkr` binary       | `gc-hc`                |
| `gchk` short alias     | `gchc`                 |
| `/etc/gc-chkr/env`     | `/etc/gc-hc/env`       |
| `/var/lib/gc-chkr/`    | `/var/lib/gc-hc/`      |
| `/var/log/gc-chkr/`    | `/var/log/gc-hc/`      |
| `gc-chkr.service`      | `gc-hc.service`        |
| `gc-chkr.timer`        | `gc-hc.timer`          |
| `GC_CHKR_*` env vars   | `GC_HC_*`              |
| `apt-get remove gc-chkr` | `apt-get remove gc-hc` |
| repo: `naufalmng/gc-chkr` | `naufalmng/gc-hc` (auto-redirects) |

#### Migrating from 1.x

```bash
# 1. save the old config
sudo cp /etc/gc-chkr/env ~/gc-chkr-backup.env
sudo apt-get remove gc-chkr

# 2. install 2.0.0 fresh
curl -fsSL https://github.com/naufalmng/gc-hc/releases/latest/download/gc-hc.sh | sudo bash

# 3. reuse the old config (the GCLOUD_* names did not change, only GC_CHKR_* -> GC_HC_*)
sudo install -d -m 0750 /etc/gc-hc
sudo sed 's/GC_CHKR_/GC_HC_/g' ~/gc-chkr-backup.env | sudo tee /etc/gc-hc/env > /dev/null
sudo chmod 0600 /etc/gc-hc/env
sudo gc-hc check
```

The `GCLOUD_*` variables (URLs, IDs, API key) keep their original names — only the
`GC_CHKR_*` tunables were renamed to `GC_HC_*`.

### Changed
- All identifiers renamed for the rebrand: binaries, package, paths, env var prefix, systemd unit names, repo URL.
- Banner ASCII art redrawn for "GC HC" instead of "GC CHKR".
- README simplified to a bilingual EN/ID quick-start. Detailed reference moved to `documentation.md` (also bilingual).

### Added
- `documentation.md` — full reference: install variants, all commands, config schema, architecture diagram, design notes, and troubleshooting cookbook. Bilingual EN + ID.

## [1.8.0] - 2026-05-25

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
  (publishes `dist/gc-hc.sh`, `dist/gc-hc`, and `SHA256SUMS` on tag push).
- `--no-color` flag for the installer.
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
- `gc-hc` and `gchc` aliases.

[Unreleased]: https://github.com/naufalmng/gc-hc/compare/v2.0.1...HEAD
[2.0.1]: https://github.com/naufalmng/gc-hc/releases/tag/v2.0.1
[2.0.0]: https://github.com/naufalmng/gc-hc/releases/tag/v2.0.0
[1.8.0]: https://github.com/naufalmng/gc-hc/releases/tag/v1.8.0
[1.7.0]: https://github.com/naufalmng/gc-hc/releases/tag/v1.7.0
