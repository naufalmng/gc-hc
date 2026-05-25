<div align="center">

```
   ▄████   ▄████        ▄████ ██   ██ ██  ██ ██████
  ██       ██           ██    ██   ██ ██ ██  ██   ██
  ██  ▄▄   ██           ██    ███████ ████   ██████
  ██  ██   ██           ██    ██   ██ ██ ██  ██  ██
   ▀████    ▀████  ▄    ██▄▄  ██   ██ ██  ██ ██   ██
```

# gc-chkr

**A node-side healthcheck for Grafana Cloud — find the actual reason metrics or logs aren't showing up.**

[![CI](https://github.com/naufalmng/gc-chkr/actions/workflows/ci.yml/badge.svg)](https://github.com/naufalmng/gc-chkr/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/naufalmng/gc-chkr?display_name=tag&sort=semver)](https://github.com/naufalmng/gc-chkr/releases)
[![License](https://img.shields.io/github/license/naufalmng/gc-chkr)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-debian%20%7C%20ubuntu-d70a53)](#install)

</div>

---

## What this is

When Grafana Cloud says *"no data"* for a host, the symptom is on the dashboard but the cause is almost always on the node: DNS, TLS, auth, an outbound firewall, a typo in the remote_write URL, or a Loki rate limit. `gc-chkr` runs from the node and tells you, in seconds, which of those it is.

It probes — from the host that's actually shipping the data:

- **DNS** resolution for every Grafana Cloud endpoint you've configured
- **TLS** handshake, with certificate verification
- **Prometheus `remote_write`** reachability and credentials (POSTs to your `/api/prom/push`)
- **Prometheus query** API health (`/api/prom/api/v1/status/buildinfo`)
- **Loki push** with a real, well-formed payload (catches 400 vs 401 vs 403 cleanly)
- **Fleet Management** endpoint (optional, for hosts using `agent.com`)

Result is a single JSON document, persisted, and re-emitted on every systemd-timer run so you can ship it back to Grafana Cloud as another data source.

## Install

One-liner, the way you'd expect:

```bash
curl -fsSL https://github.com/naufalmng/gc-chkr/releases/latest/download/gc-chkr.sh | sudo bash
```

The script builds a real `.deb` on the fly and hands it to `apt-get install`, so removal is the standard `sudo apt-get remove gc-chkr`. No untracked files in `/usr/local`, no surprise systemd units, nothing apt doesn't know about.

Non-interactive:

```bash
curl -fsSL https://github.com/naufalmng/gc-chkr/releases/latest/download/gc-chkr.sh | sudo bash -s -- install --yes
```

Standalone (no apt, no systemd, just a binary in `$PWD`):

```bash
curl -fsSL https://github.com/naufalmng/gc-chkr/releases/latest/download/gc-chkr.sh | bash -s -- standalone
./gc-chkr config
./gc-chkr check
```

## Quick start

```bash
# Configure once, enable the timer, run the first check.
sudo gc-chkr onboard

# Re-run on demand.
gchk check

# See current state, last result, next scheduled run.
gc-chkr status

# Tail the unit logs.
gc-chkr logs

# Remove cleanly when you're done.
sudo apt-get remove gc-chkr
```

## What you'll see

```
────────────────────────────────────────────────────────
  gc-chkr status
────────────────────────────────────────────────────────
  status       : ✓ enabled
  timer        : ✓ active
  service      : ✓ inactive
  last check   : ✓ pass
  next run     : Mon 2025-11-17 14:35:00 UTC
────────────────────────────────────────────────────────
  tool         : gc-chkr 1.7.0
  mode         : system
  binary       : /usr/bin/gc-chkr
  config       : /etc/gc-chkr/env
  state        : /var/lib/gc-chkr/last.json
  log          : /var/log/gc-chkr/gc-chkr.log
────────────────────────────────────────────────────────
```

A failed run writes a discriminated reason — not just "fail":

| Check        | State | Message                |
| ------------ | ----- | ---------------------- |
| `prom.dns`   | pass  | resolved               |
| `prom.tls`   | pass  | handshake_ok           |
| `prom.push`  | pass  | reachable_http_400     |
| `prom.query` | pass  | http_200               |
| `loki.write` | fail  | auth_http_401          |
| `fleet`      | skip  | disabled               |

`loki.write: auth_http_401` is the point — you immediately know it's the API key, not DNS, not the firewall.

## How it's wired

```
                ┌─────────────────────────────────────┐
                │  curl ... | sudo bash               │
                │  (single self-contained script)     │
                └──────────────┬──────────────────────┘
                               │
                               ▼
                ┌─────────────────────────────────────┐
                │  installer (gc-chkr.sh)             │
                │   • builds .deb in /var/tmp         │
                │   • apt-get install ./*.deb         │
                └──────────────┬──────────────────────┘
                               │
              ┌────────────────┴────────────────────┐
              ▼                                     ▼
   /usr/bin/gc-chkr                  /lib/systemd/system/
   /usr/bin/gchk                       gc-chkr.service
                                       gc-chkr.timer
              │                                     │
              └────────────────┬────────────────────┘
                               ▼
                ┌─────────────────────────────────────┐
                │  gc-chkr check  (every 5m default)  │
                │    DNS → TLS → prom → loki → fleet  │
                └──────────────┬──────────────────────┘
                               ▼
                /var/lib/gc-chkr/last.json
                /var/log/gc-chkr/gc-chkr.log
```

The installer is one file. The runtime tool is a separate script embedded inside it. Service and timer units, plus `postinst`/`prerm`/`postrm` maintainer scripts, are also embedded — at install time we materialize them onto disk and let `dpkg` track them.

That's how `apt-get remove` knows about everything we put down: every file is owned by the `gc-chkr` package, by design.

## Configuration

Configured via `/etc/gc-chkr/env` (system mode) or `./.gc-chkr/env` (standalone). The `onboard` flow walks you through every field:

| Variable                         | Required | What it is                                              |
| -------------------------------- | :------: | ------------------------------------------------------- |
| `GCLOUD_HOSTED_METRICS_URL`      | yes      | Prometheus `remote_write` URL (`/api/prom/push`)        |
| `GCLOUD_HOSTED_METRICS_ID`       | yes      | Numeric Prometheus instance ID                          |
| `GCLOUD_HOSTED_LOGS_URL`         | yes      | Loki push URL                                           |
| `GCLOUD_HOSTED_LOGS_ID`          | yes      | Numeric Loki instance ID                                |
| `GCLOUD_RW_API_KEY`              | yes      | Grafana Cloud API key (must start with `glc_`)          |
| `GCLOUD_FM_URL`                  | optional | Fleet Management endpoint                               |
| `GC_CHKR_TIMEOUT`                | optional | curl timeout, seconds (1–300, default 10)               |
| `GC_CHKR_RETRIES`                | optional | curl retries (default 2)                                |
| `GC_CHKR_DNS` / `_TLS`           | optional | `false` to disable that probe                           |
| `GC_CHKR_LOKI_WRITE`             | optional | `false` to skip the Loki write probe                    |
| `GC_CHKR_PROM_QUERY`             | optional | `false` to skip the Prometheus query probe              |
| `GC_CHKR_FLEET`                  | optional | `false` to skip the Fleet probe                         |

If you're already running [Grafana Alloy](https://grafana.com/docs/alloy/latest/) and the same vars are set in `/etc/default/alloy` or `/etc/sysconfig/alloy`, `gc-chkr` will pick them up automatically.

## Build it yourself

```bash
git clone https://github.com/naufalmng/gc-chkr
cd gc-chkr
make build           # → dist/gc-chkr.sh, dist/gc-chkr
make test            # smoke + bats
make install         # local install via apt-get
```

Source layout:

```
gc-chkr/
├── src/
│   ├── tool/         # 15 modules — runtime healthcheck
│   └── installer/    # 9 modules — .deb builder + apt installer
├── assets/
│   ├── systemd/      # service + timer units
│   ├── debian/       # postinst, prerm, postrm, control template
│   └── banner/       # ASCII banner
├── scripts/build.sh  # assembles dist artifacts
├── tests/
│   ├── bats/         # unit tests (pure functions)
│   ├── smoke.sh      # quick assertions, no external deps
│   └── parity.sh     # verifies built artifact == original behaviour
└── .github/workflows/  ci.yml + release.yml
```

The build pipeline concatenates source modules in lexical order, embeds asset files via heredoc placeholders, and substitutes `__PACKAGE_VERSION__`, `__PACKAGE_MAINTAINER__`, `__PACKAGE_HOMEPAGE__` from `VERSION` + git config. The output is a single 53 KB script — small enough to read, large enough to be useful.

## Design choices worth flagging

- **No jq dependency.** Result JSON is hand-assembled with a pure-bash `json_escape`. The healthcheck must keep working even on minimal Debian images.
- **`/dev/tty` for prompts.** That's what makes `curl ... | sudo bash` interactive — stdin is the pipe, but the user's terminal is still attached.
- **API key masking by default.** `show-config` and `status` print `glc_xx...yyyy`; the unredacted value never leaves `/etc/gc-chkr/env` (mode `0600`).
- **400 is a pass for `remote_write` empty bodies.** Mimir/Cortex respond 400 to an empty protobuf POST when auth is good, which is genuinely the cheapest reachable+authed probe — annotated explicitly in the result.
- **Verdict precedence is FAIL > WARN > PASS.** Exit codes mirror that: `0/1/2`. Hook it into your alerting.

## License

Apache License 2.0. See [LICENSE](LICENSE).

## Author

[Muhammad Naufal Hanif](https://github.com/naufalmng) — built this for myself to stop guessing why Grafana Cloud was silent on certain hosts. Now the guess is replaced by a 30-second JSON answer.

Issues and PRs welcome.
