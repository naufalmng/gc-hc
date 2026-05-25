# gc-hc

**Grafana Cloud Health Checker** — node-side healthcheck CLI for diagnosing why metrics or logs aren't reaching Grafana Cloud.

[![CI](https://github.com/naufalmng/gc-hc/actions/workflows/ci.yml/badge.svg)](https://github.com/naufalmng/gc-hc/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/naufalmng/gc-hc?display_name=tag&sort=semver)](https://github.com/naufalmng/gc-hc/releases)
[![License](https://img.shields.io/github/license/naufalmng/gc-hc)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-debian%20%7C%20ubuntu-d70a53)](#install)

</div>

---

## English

When Grafana Cloud says *"no data"*, the cause is almost always on the node — DNS, TLS, auth, a firewall rule, a typo. `gc-hc` runs from the node and tells you which one in seconds.

### Install

```bash
curl -fsSL https://github.com/naufalmng/gc-hc/releases/latest/download/gc-hc.sh | sudo bash
```

### Quick start

```bash
sudo gc-hc onboard       # configure + enable timer + first check
gchc check               # run a check on demand
gchc status              # see current state and last result
sudo apt-get remove gc-hc
```

`gchc` is a short alias for `gc-hc` — same command, fewer keystrokes.

For full usage, configuration reference, architecture, and design notes, see **[documentation.md](documentation.md)**.

---

## Bahasa Indonesia

Kalau Grafana Cloud bilang *"no data"*, penyebabnya hampir selalu di node — DNS, TLS, auth, firewall, salah ketik URL. `gc-hc` jalan dari node dan langsung kasih tahu masalahnya yang mana, dalam hitungan detik.

### Instalasi

```bash
curl -fsSL https://github.com/naufalmng/gc-hc/releases/latest/download/gc-hc.sh | sudo bash
```

### Mulai cepat

```bash
sudo gc-hc onboard       # konfigurasi + aktifkan timer + jalankan check pertama
gchc check               # jalankan check kapan saja
gchc status              # lihat state dan hasil terakhir
sudo apt-get remove gc-hc
```

`gchc` adalah alias pendek untuk `gc-hc` — perintah sama, lebih ringkas.

Untuk panduan lengkap, referensi konfigurasi, arsitektur, dan catatan desain, lihat **[documentation.md](documentation.md)**.

---

## License / Lisensi

Apache License 2.0. See [LICENSE](LICENSE).

## Author / Penulis

[Muhammad Naufal Hanif](https://github.com/naufalmng) — built this to stop guessing why Grafana Cloud was silent on certain hosts.
