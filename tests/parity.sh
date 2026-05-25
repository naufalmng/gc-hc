#!/usr/bin/env bash
# tests/parity.sh — verify the built dist artifact preserves all critical
# behaviors of the original single-file gc-chkr.sh.
#
# Approach: we do NOT byte-compare (the new file is reorganized + colored).
# Instead we assert presence of every meaningful contract:
#   - All systemd unit lines
#   - All env var names
#   - All HTTP status code branches
#   - All maintainer script effects
#   - All public commands

set -e

ROOT="$(cd -- "$(dirname -- "$0")/.." >/dev/null && pwd -P)"
cd "$ROOT"

ORIG="gc-chkr.sh"
NEW="dist/gc-chkr.sh"
TOOL="dist/gc-chkr"

if [[ ! -f "$ORIG" ]]; then
  echo "  skip  $ORIG missing — run from repo root"
  exit 0
fi

PASS=0
FAIL=0

assert_in() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -qF -- "$needle" "$file"; then
    printf '  ok    %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s  (missing %q in %s)\n' "$label" "$needle" "$file"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Built artifacts parse cleanly ==="
bash -n "$ORIG" && { echo "  ok    original parses"; PASS=$((PASS+1)); }
bash -n "$NEW"  && { echo "  ok    installer parses"; PASS=$((PASS+1)); }
bash -n "$TOOL" && { echo "  ok    tool parses"; PASS=$((PASS+1)); }

echo
echo "=== Tool exposes all original commands ==="
for cmd in onboard config show-config check status logs remove enable disable help version; do
  if grep -Eq "^[[:space:]]*${cmd}\)" "$TOOL"; then
    printf '  ok    command: %s\n' "$cmd"
    PASS=$((PASS+1))
  else
    printf '  FAIL  command: %s missing in dispatch\n' "$cmd"
    FAIL=$((FAIL+1))
  fi
done

echo
echo "=== All Grafana env names preserved ==="
for v in GCLOUD_HOSTED_METRICS_URL GCLOUD_HOSTED_METRICS_ID \
         GCLOUD_HOSTED_LOGS_URL    GCLOUD_HOSTED_LOGS_ID \
         GCLOUD_FM_URL             GCLOUD_RW_API_KEY \
         GC_CHKR_TIMEOUT GC_CHKR_RETRIES GC_CHKR_RETRY_DELAY \
         GC_CHKR_DNS GC_CHKR_TLS GC_CHKR_LOKI_WRITE \
         GC_CHKR_PROM_QUERY GC_CHKR_FLEET; do
  assert_in "$TOOL" "$v" "env: $v"
done

echo
echo "=== HTTP status branches preserved ==="
for code in 200 202 204 301 302 307 308 400 401 403 404 405; do
  assert_in "$TOOL" "$code" "http status: $code"
done

echo
echo "=== systemd unit content embedded ==="
for line in 'Type=oneshot' 'ProtectSystem=full' 'NoNewPrivileges=true' \
            'ReadWritePaths=/var/lib/gc-chkr /var/log/gc-chkr' \
            'OnBootSec=1m' 'OnCalendar=*:0/5:00' \
            'Persistent=true' 'WantedBy=timers.target'; do
  assert_in "$NEW" "$line" "unit: $line"
done

echo
echo "=== dpkg maintainer effects embedded ==="
assert_in "$NEW" 'systemctl daemon-reload'                   "postinst: daemon-reload"
assert_in "$NEW" 'systemctl disable --now gc-chkr.timer'     "prerm: disable timer"
assert_in "$NEW" 'rm -rf /etc/gc-chkr /var/lib/gc-chkr'      "postrm: data wipe"
assert_in "$NEW" 'systemctl reset-failed gc-chkr.service gc-chkr.timer' "postrm: reset-failed"

echo
echo "=== Pipe-install one-liners still documented ==="
assert_in "$NEW" 'curl -fsSL'  "pipe install example"
assert_in "$NEW" 'sudo bash -s -- install --yes' "non-interactive flag"

echo
echo "=== API key validator still requires glc_ prefix ==="
assert_in "$TOOL" 'glc_*'                  "validator: glc_ guard"
assert_in "$TOOL" 'GCLOUD_RW_API_KEY must' "validator: error msg"

echo
echo "=== Alloy config fallback preserved ==="
assert_in "$TOOL" '/etc/default/alloy'    "alloy default"
assert_in "$TOOL" '/etc/sysconfig/alloy'  "alloy sysconfig"

echo
echo "=== Standalone mode preserved ==="
assert_in "$NEW"  'standalone'             "standalone action"
assert_in "$TOOL" '.gc-chkr'               "standalone home"

echo
printf '\nTotal: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
